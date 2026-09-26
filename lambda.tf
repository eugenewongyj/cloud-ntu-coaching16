locals {
  full_domain_url = "https://${var.subdomain}.${var.root_domain}/"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# --- Create Lambda ---
resource "aws_iam_role" "create_lambda_role" {
  name               = "${var.project_name}-create-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "create_lambda_policy" {
  name = "${var.project_name}-create-lambda-policy"
  role = aws_iam_role.create_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem"]
        Resource = aws_dynamodb_table.url_table.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
        Resource = "*"
      }
    ]
  })
}

data "archive_file" "create_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/create_url/lambda_function.py"
  output_path = "${path.module}/lambda/create_url.zip"
}

resource "aws_lambda_function" "create_url" {
  filename         = data.archive_file.create_zip.output_path
  function_name    = "${var.project_name}-shortener-url-create"
  role             = aws_iam_role.create_lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.create_zip.output_base64sha256

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      REGION_AWS = var.aws_region
      DB_NAME    = aws_dynamodb_table.url_table.name
      APP_URL    = local.full_domain_url # Has trailing slash as required
      MIN_CHAR   = "12"
      MAX_CHAR   = "16"
    }
  }
}

# --- Retrieve Lambda ---
resource "aws_iam_role" "retrieve_lambda_role" {
  name               = "${var.project_name}-retrieve-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "retrieve_lambda_policy" {
  name = "${var.project_name}-retrieve-lambda-policy"
  role = aws_iam_role.retrieve_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.url_table.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
        Resource = "*"
      }
    ]
  })
}

data "archive_file" "retrieve_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/retrieve_url/lambda_function.py"
  output_path = "${path.module}/lambda/retrieve_url.zip"
}

resource "aws_lambda_function" "retrieve_url" {
  filename         = data.archive_file.retrieve_zip.output_path
  function_name    = "${var.project_name}-shortener-url-retrieve"
  role             = aws_iam_role.retrieve_lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.retrieve_zip.output_base64sha256

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      REGION_AWS = var.aws_region
      DB_NAME    = aws_dynamodb_table.url_table.name
    }
  }
}