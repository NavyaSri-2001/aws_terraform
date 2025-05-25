resource "aws_api_gateway_rest_api" "demo_api" {
  name        = "First api demo"
  description = "Example REST API"

  endpoint_configuration {
    types= ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "claims"{
    rest_api_id = aws_api_gateway_rest_api.demo_api.id
    parent_id = aws_api_gateway_rest_api.demo_api.root_resource_id
    path_part = "claims"
}

resource "aws_api_gateway_resource" "v1" {
  rest_api_id = aws_api_gateway_rest_api.demo_api.id
  parent_id   = aws_api_gateway_resource.claims.id
  path_part   = "v1"
}

resource "aws_api_gateway_resource" "create"{
    rest_api_id = aws_api_gateway_rest_api.demo_api.id
    parent_id = aws_api_gateway_resource.v1.id
    path_part = "create"
}

resource "aws_api_gateway_resource" "fetch"{
    rest_api_id = aws_api_gateway_rest_api.demo_api.id
    parent_id = aws_api_gateway_resource.v1.id
    path_part = "fetch"
}

resource "aws_api_gateway_method" "create_event" {
  rest_api_id   = aws_api_gateway_rest_api.demo_api.id
  resource_id   = aws_api_gateway_resource.create.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "fetch_event" {
  rest_api_id   = aws_api_gateway_rest_api.demo_api.id
  resource_id   = aws_api_gateway_resource.fetch.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration_create" {
  rest_api_id             = aws_api_gateway_rest_api.demo_api.id
  resource_id             = aws_api_gateway_resource.create.id
  http_method             = aws_api_gateway_method.create_event.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda.invoke_arn
}

resource "aws_api_gateway_integration" "lambda_integration_fetch" {
  rest_api_id             = aws_api_gateway_rest_api.demo_api.id
  resource_id             = aws_api_gateway_resource.fetch.id
  http_method             = aws_api_gateway_method.fetch_event.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "demo_deployment" {
  depends_on = [aws_api_gateway_integration.lambda_integration_create, aws_api_gateway_integration.lambda_integration_fetch]
  rest_api_id = aws_api_gateway_rest_api.demo_api.id
}

resource "aws_api_gateway_stage" "demo_stage"{
    rest_api_id =  aws_api_gateway_rest_api.demo_api.id
    deployment_id = aws_api_gateway_deployment.demo_deployment.id
    stage_name = "dev"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.demo_api.execution_arn}/dev/*"
}
