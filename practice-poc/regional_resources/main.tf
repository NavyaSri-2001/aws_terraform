# resource "aws_iam_role" "lambda_exec_role" {
#   name = "${var.lambda_name}_role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Action = "sts:AssumeRole",
#       Effect = "Allow",
#       Principal = {
#         Service = "lambda.amazonaws.com"
#       }
#     }]
#   })
# }

# resource "aws_iam_role_policy" "dynamodb_access" {
#   name = "${var.lambda_name}_dynamodb_policy"
#   role = aws_iam_role.lambda_exec_role.id

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Action = [
#         "dynamodb:GetItem",
#         "dynamodb:PutItem",
#         "dynamodb:DeleteItem",
#         "dynamodb:Scan",
#         "dynamodb:UpdateItem"
#       ],
#       Effect   = "Allow",
#       Resource = "arn:aws:dynamodb:${var.region}:*:table/${var.table_name}"
#     }]
#   })
# }

# resource "aws_lambda_function" "lambda" {
#   function_name = var.lambda_name
#   role          = aws_iam_role.lambda_exec_role.arn
#   handler       = "lambda_function.lambda_handler"
#   runtime       = "python3.9"
#   filename      = var.zip_file
#   source_code_hash = filebase64sha256(var.zip_file)
# }
