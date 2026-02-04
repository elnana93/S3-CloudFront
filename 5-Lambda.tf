

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}

resource "aws_lambda_function" "visitor_counter" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "visitor_counter_function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
} 



# The "Assume Role" policy allows the Lambda service to use this role
resource "aws_iam_role" "lambda_role" {
  name = "visitor_counter_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}


resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "lambda_dynamodb_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.visitor_counter.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
