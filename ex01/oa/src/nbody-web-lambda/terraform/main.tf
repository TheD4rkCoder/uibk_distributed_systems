provider "aws" {
  region = "us-east-1"
}

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/build/lambda_acceleration.zip"
  source {
    content  = file("${path.module}/../lambda_acceleration.py")
    filename = "lambda_acceleration.py"
  }
  source {
    content  = file("${path.module}/../compute_acceleration.py")
    filename = "compute_acceleration.py"
  }
}

// So the lambda function can use the AWS SDK for Python and Numpy
locals {
  layer_arn = "arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python312:31"
}

resource "aws_lambda_function" "acceleration" {
    function_name = "lambda_acceleration"
    role = data.aws_iam_role.lab_role.arn
    filename = data.archive_file.lambda_zip.output_path
    source_code_hash = data.archive_file.lambda_zip.output_base64sha256
    handler = "lambda_acceleration.lambda_handler"
    runtime = "python3.12"
    timeout = 30
    layers = [local.layer_arn]
    memory_size = 512
}

output "function_name" {
  value = aws_lambda_function.acceleration.function_name
}

