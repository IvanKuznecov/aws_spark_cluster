resource aws_efs_file_system main_efs  {
  creation_token = "${var.name_prefix}-main-efs"
  encrypted = true

  tags = {
    Name = "${var.name_prefix}-main-efs"
  }
}

resource aws_efs_mount_target main_efs_mount_target  {
    count = length(var.private_subnet_ids)

    file_system_id  = aws_efs_file_system.main_efs.id
    subnet_id       = var.private_subnet_ids[count.index]
    security_groups = [aws_security_group.efs_security_group.id]
}

resource aws_security_group efs_security_group  {
  vpc_id = var.vpc_id

  # Allow inbound access from any IP on specified ports
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-efs-sg"
  }
}