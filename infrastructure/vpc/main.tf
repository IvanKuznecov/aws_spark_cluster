resource aws_vpc main_vpc  {
  cidr_block         = var.base_cidr
  
  enable_dns_support = "true"
  enable_dns_hostnames = "true"

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource aws_internet_gateway internet_gateway  {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.name_prefix}-internet-gateway"
  }
}

resource aws_eip nat_eip  {
  for_each = toset(var.availability_zones)  # Use availability zones as keys

  tags = {
    Name = "${var.name_prefix}-nat-eip-${each.key}"
  }
}

resource aws_nat_gateway nat_gateway  {
  for_each = tomap({ for az in var.availability_zones : az => aws_subnet.public_subnet[az].id })

  allocation_id = aws_eip.nat_eip[each.key].id
  subnet_id     = each.value

  tags = {
    Name = "${var.name_prefix}-nat-gw-${each.key}"
  }
}

#
# Generated ip blocks take AAA.BBB.0.0/16 --> AAA.BBB.CCC.0/24 in which CCC = first_private_subnet or first_public_subnet
#
resource aws_subnet private_subnet  {
  for_each = zipmap(var.availability_zones, var.private_subnet_cidr)

  vpc_id = aws_vpc.main_vpc.id
  availability_zone = each.key
  cidr_block = each.value

  tags = {
    Name = "${var.name_prefix}-private-subnet-${each.key}"
  }
}

resource aws_route_table private_route_table  {
  for_each = aws_nat_gateway.nat_gateway

  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = each.value.id
  }

  tags = {
    Name = "${var.name_prefix}-private-rt-${each.key}"
  }
}

resource aws_route_table_association private_route_table_association  {
  for_each = aws_subnet.private_subnet

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_route_table[each.key].id
}

resource aws_security_group private_security_group  {
  vpc_id = aws_vpc.main_vpc.id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-private-security-group"
  }
}

resource aws_subnet public_subnet  {
  vpc_id = aws_vpc.main_vpc.id

  for_each = toset(var.availability_zones)
  cidr_block              = cidrsubnet(aws_vpc.main_vpc.cidr_block, 8, index(var.availability_zones, each.value))
  availability_zone       = each.value
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-pub-subnet-${each.key}"
  }
}

resource aws_route_table public_route_table  {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource aws_route_table_association public_route_table_association  {
  for_each       = aws_subnet.public_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_route_table.id
}


resource aws_security_group public_security_group  {
  vpc_id = aws_vpc.main_vpc.id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-public-sg"
  }
}