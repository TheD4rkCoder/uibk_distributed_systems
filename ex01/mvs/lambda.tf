#AWS Academy does not allow creating IAM roles, so use the pre-made LabRole
data "aws_iam_role" "lab" {
  name = "LabRole"
}

data "archive_file" "threshold_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/threshold_lambda.py"
  output_path = "${path.module}/lambda/threshold_lambda.zip"
}

resource "aws_lambda_function" "threshold" {
  function_name    = "threshold-recommendation"
  role             = data.aws_iam_role.lab.arn
  runtime          = "python3.13"
  handler          = "threshold_lambda.lambda_handler"
  filename         = data.archive_file.threshold_lambda.output_path
  source_code_hash = data.archive_file.threshold_lambda.output_base64sha256
  memory_size      = 128
  timeout          = 10
}

#public HTTPS endpoint so the app can call the function with a plain HTTP POST
resource "aws_lambda_function_url" "threshold" {
  function_name      = aws_lambda_function.threshold.function_name
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "url_invoke" {
  statement_id           = "AllowPublicFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.threshold.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "public_invoke" {
  statement_id  = "AllowPublicInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.threshold.function_name
  principal     = "*"
}

output "lambda_url" {
  value = aws_lambda_function_url.threshold.function_url
}
