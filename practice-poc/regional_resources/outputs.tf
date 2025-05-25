output "lambda_arn" {
  value = aws_lambda_function.lambda.arn
}

output "stage_arn"{
  value = aws_api_gateway_stage.demo_stage.arn
}
