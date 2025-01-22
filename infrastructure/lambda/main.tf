resource aws_iam_role lambda_execution_role {
  name = "${var.name_prefix}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource aws_iam_policy lambda_logging_policy {
  name   = "${var.name_prefix}-lambda-logging-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource aws_iam_policy s3_readonly_policy {
  name        = "${var.name_prefix}-s3-readonly-policy"
  description = "Policy for Lambda to access S3 with read-only permissions"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${var.lambda_bucket_name}",
          "arn:aws:s3:::${var.lambda_bucket_name}/*"
        ]
      }
    ]
  })
}

resource aws_iam_role_policy_attachment logging_policy_attachment {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
}

resource aws_iam_role_policy_attachment basic_execution_policy {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource aws_iam_role_policy_attachment attach_s3_readonly_policy {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.s3_readonly_policy.arn
}


resource aws_s3_bucket lambda_bucket {
  bucket = "${var.name_prefix}-lambda-bucket"

  tags = {
    Name        = "${var.name_prefix}-lambda-bucket"
    Environment = "production"
  }
}

resource aws_s3_bucket_ownership_controls lambda_bucket_ownership {
  bucket = aws_s3_bucket.lambda_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource aws_s3_bucket_versioning lambda_bucket_versioning {
  bucket = aws_s3_bucket.lambda_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource aws_s3_object lambda_code_file {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "scripts/lambda_spark_submit_api.zip"
  source = "${var.data_path}/lambda_spark_submit_api/lambda_spark_submit_api.zip"
  content_type = "application/zip"
}

resource aws_lambda_function submit_spark_job_lambda {
  function_name = "${var.name_prefix}-submit-spark-job-lambda"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "submit_spark_job.lambda_handler"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_code_file.key

  environment {
    variables = {
      LOAD_BALANCER_DNS_NAME = "${var.load_balancer_dns_name}",
      S3_BUCKET_NAME = "${var.lambda_bucket_name}"
    }
  }

  timeout      = 30
  memory_size  = 128

  tags = {
    Name = "${var.name_prefix}-submit-spark-job-lambda"
  }
}
