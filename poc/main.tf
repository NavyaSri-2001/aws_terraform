provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      hashicorp-learn = "restapi-poc"
    }
  }
}

#DynamoDB table
resource "aws_dynamodb_table" "basic-dynamodb-table" {
  name           = "GameScores"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "UserId"
  range_key      = "TopScore"

  attribute {
    name = "UserId"
    type = "S"
  }

  attribute {
    name = "TopScore"
    type = "N"
  }
  
}

#Lambda function set up
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}
#Attached a policy in console
/*
resource "aws_iam_policy_attachment" "lambda_dynamodb_policy_attachment" {
  name       = "example_lambda_dynamodb_policy_attachment"
  roles      = [aws_iam_role.iam_for_lambda.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}
*/
# Attach AWSLambdaBasicExecutionRole managed policy to the IAM Role
resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_policy" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda.py"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "test_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "lambda_function_payload.zip"
  function_name = "lambda_function_name2"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda.lambda_handler"
  publish =   true
  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "python3.12"

  environment {
    variables = {
      foo = "bar"
    }
  }
}

#Versioning of lambda function using alias
resource "aws_lambda_alias" "production" {
  function_name    = aws_lambda_function.test_lambda.function_name
  name             = "Production"
  description      = "Production environment"
  function_version = "2"
}

resource "aws_lambda_alias" "staging" {
  function_name    = aws_lambda_function.test_lambda.function_name
  name             = "Staging"
  description      = "Staging environment"
  function_version = "1"
}

#LambdaAUthorizer
data "aws_iam_policy_document" "invocation_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "invocation_role" {
  name               = "api_gateway_auth_invocation"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.invocation_assume_role.json
}

data "aws_iam_policy_document" "invocation_policy" {
  statement {
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.authorizer.arn]
  }
}

resource "aws_iam_role_policy" "invocation_policy" {
  name   = "default"
  role   = aws_iam_role.invocation_role.id
  policy = data.aws_iam_policy_document.invocation_policy.json
}

resource "aws_api_gateway_authorizer" "demo" {
  name                   = "demo"
  rest_api_id            = aws_api_gateway_rest_api.example_api_2.id
  type          = "TOKEN"
  authorizer_uri         = aws_lambda_function.authorizer.invoke_arn
  authorizer_credentials = aws_iam_role.invocation_role.arn
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "demo-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Attach AWSLambdaBasicExecutionRole managed policy to the IAM Role
resource "aws_iam_role_policy_attachment" "lambda_auth_cloudwatch_policy" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "lambda_auth_func" {
  type        = "zip"
  source_file = "lambda_auth.py"
  output_path = "lambda_auth_function_payload.zip"
}

resource "aws_lambda_function" "authorizer" {
  filename      = "lambda_auth_function_payload.zip"
  function_name = "api_gateway_authorizer"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_auth.lambda_handler"

  source_code_hash = data.archive_file.lambda_auth_func.output_base64sha256
  #source_code_hash = filebase64sha256("lambda-function.zip")
  runtime = "python3.12"
}


#api gateway setup
data "aws_iam_policy_document" "assume_role_api_gateway" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_api_gateway" {
  name               = "iam_for_api_gateway"
  assume_role_policy = data.aws_iam_policy_document.assume_role_api_gateway.json
}

resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name        = "api_gateway_cloudwatch_logs_policy"
  description = "Policy allowing API Gateway to write logs to CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
            "Effect": "Allow",
            "Action": [
                "apigateway:UpdateStage"
            ],
            "Resource": "*"
        },
      {
        "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:PutLogEvents",
                "logs:GetLogEvents",
                "logs:FilterLogEvents"
            ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_cloudwatch_logs_policy" {
  role       = aws_iam_role.iam_for_api_gateway.name
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
}

resource "aws_iam_policy_attachment" "api_gateway_policy_attachment" {
  name       = "api_gateway_policy_attachment"
  roles      = [aws_iam_role.iam_for_api_gateway.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonAPIGatewayInvokeFullAccess"
}

resource "aws_iam_policy_attachment" "api_gateway_sfn_policy_attachment" {
  name       = "api_gateway_sfn_policy_attachment"
  roles      = [aws_iam_role.iam_for_api_gateway.name]
  policy_arn = "arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess"
}


#IAM authentication setup
# Create an IAM user
resource "aws_iam_user" "api_user" {
  name = "api_user"
}

# Attach the role to the IAM user
resource "aws_iam_policy_attachment" "example_attachment" {
  name       = "example-attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonAPIGatewayInvokeFullAccess"
  users      = [aws_iam_user.api_user.name]
  roles =[aws_iam_role.iam_for_api_gateway.name]
}

resource "aws_iam_role_policy" "api_gateway_policy_auth" {
  name   = "api_gateway_access_policy_auth"
  role   = aws_iam_role.iam_for_api_gateway.id
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Action    = [
          "execute-api:Invoke"
        ],
        Resource  = "arn:aws:execute-api:us-east-1:891377146519:yn0dj5aghb/*/POST/example_2"
      }
    ]
  })
}


resource "aws_api_gateway_rest_api" "example_api_2" {
  name = "example_api_2"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "example_resource_2" {
  parent_id   = aws_api_gateway_rest_api.example_api_2.root_resource_id
  path_part   = "example_2"
  rest_api_id = aws_api_gateway_rest_api.example_api_2.id
}

resource "aws_api_gateway_resource" "v1" {
  parent_id   = aws_api_gateway_resource.example_resource_2.id
  path_part   = "v1"
  rest_api_id = aws_api_gateway_rest_api.example_api_2.id
}

resource "aws_api_gateway_resource" "v2" {
  parent_id   = aws_api_gateway_resource.example_resource_2.id
  path_part   = "v2"
  rest_api_id = aws_api_gateway_rest_api.example_api_2.id
}

resource "aws_api_gateway_method" "example_method_1" {
  #authorization = "AWS_IAM"
  authorization = "CUSTOM"  
  authorizer_id = aws_api_gateway_authorizer.demo.id
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.v1.id
  rest_api_id   = aws_api_gateway_rest_api.example_api_2.id
}

resource "aws_api_gateway_method" "example_method_2" {
  #authorization = "AWS_IAM"
  authorization = "CUSTOM"  
  authorizer_id = aws_api_gateway_authorizer.demo.id
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.v2.id
  rest_api_id   = aws_api_gateway_rest_api.example_api_2.id
}

resource "aws_api_gateway_integration" "example_integration_step_function_1" {
  rest_api_id = aws_api_gateway_rest_api.example_api_2.id
  resource_id = aws_api_gateway_resource.v1.id
  http_method = aws_api_gateway_method.example_method_1.http_method
  integration_http_method = "POST"
  type = "AWS"
  uri                     = "arn:aws:apigateway:${var.aws_region}:states:action/StartExecution"
  credentials             = aws_iam_role.iam_for_api_gateway.arn

request_templates = {
    "application/json" = <<EOF
  #set($inputRoot = $input.path('$'))
{
  "input": "{\"resource_path_v1\":\"v1\",\"operation\":\"$inputRoot.input.operation\",\"payload\":{\"Item\":{\"UserId\":\"$inputRoot.input.payload.Item.UserId\",\"TopScore\":$inputRoot.input.payload.Item.TopScore}}}",
  "name": "$inputRoot.name",
  "stateMachineArn": "$inputRoot.stateMachineArn"
}
EOF
  }

  depends_on =[aws_cloudwatch_log_group.api_gateway_logs]

}

resource "aws_api_gateway_integration" "example_integration_step_function_2" {
  rest_api_id = aws_api_gateway_rest_api.example_api_2.id
  resource_id = aws_api_gateway_resource.v2.id
  http_method = aws_api_gateway_method.example_method_2.http_method
  integration_http_method = "POST"
  type = "AWS"
  uri                     = "arn:aws:apigateway:${var.aws_region}:states:action/StartExecution"
  credentials             = aws_iam_role.iam_for_api_gateway.arn

request_templates = {
    "application/json" = <<EOF
  #set($inputRoot = $input.path('$'))
{
  "input": "{\"resource_path_v2\":\"v2\",\"operation\":\"$inputRoot.input.operation\",\"payload\":{\"Item\":{\"UserId\":\"$inputRoot.input.payload.Item.UserId\",\"TopScore\":$inputRoot.input.payload.Item.TopScore}}}",
  "name": "$inputRoot.name",
  "stateMachineArn": "$inputRoot.stateMachineArn"
}
EOF
  }

  depends_on =[aws_cloudwatch_log_group.api_gateway_logs]

}

resource "aws_api_gateway_method_response" "response_200_1" {
  rest_api_id = aws_api_gateway_rest_api.example_api_2.id
  resource_id = aws_api_gateway_resource.v1.id
  http_method = aws_api_gateway_method.example_method_1.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}
resource "aws_api_gateway_method_response" "response_200_2" {
  rest_api_id = aws_api_gateway_rest_api.example_api_2.id
  resource_id = aws_api_gateway_resource.v2.id
  http_method = aws_api_gateway_method.example_method_2.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "IntegrationResponse_1" {
  rest_api_id = aws_api_gateway_rest_api.example_api_2.id
  resource_id = aws_api_gateway_resource.v1.id
  http_method = aws_api_gateway_method.example_method_1.http_method
  status_code = "200"

depends_on = [
    aws_api_gateway_method.example_method_1,
    aws_api_gateway_integration.example_integration_step_function_1
  ]/*
  response_templates = {
    "application/json" = <<EOF
#set($response = $input.path('$'))
#set($outputObj = $util.parseJson($response))
{
  "body":"$outputObj"
}
EOF
  }*/
}

resource "aws_api_gateway_integration_response" "IntegrationResponse_2" {
  rest_api_id = aws_api_gateway_rest_api.example_api_2.id
  resource_id = aws_api_gateway_resource.v2.id
  http_method = aws_api_gateway_method.example_method_2.http_method
  status_code = "200"

depends_on = [
    aws_api_gateway_method.example_method_2,
    aws_api_gateway_integration.example_integration_step_function_2
  ]

}


resource "aws_api_gateway_deployment" "example_1" {
  depends_on = [
    aws_api_gateway_integration.example_integration_step_function_1,
    aws_api_gateway_authorizer.demo
  ]

  rest_api_id = aws_api_gateway_rest_api.example_api_2.id

  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.v1.id,
      aws_api_gateway_method.example_method_1.id,
      aws_api_gateway_integration.example_integration_step_function_1.id,
      aws_api_gateway_authorizer.demo.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_api_gateway_stage" "Stage1" {
  deployment_id = aws_api_gateway_deployment.example_1.id
  rest_api_id   = aws_api_gateway_rest_api.example_api_2.id
  stage_name    = "Stage1"

  access_log_settings {
    destination_arn = "arn:aws:logs:us-east-1:891377146519:log-group:/aws/api_gateway"
    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
  depends_on = [aws_cloudwatch_log_group.api_gateway_logs, aws_iam_role_policy_attachment.attach_cloudwatch_logs_policy]
}

#Step function setup
data "aws_iam_policy_document" "sfn_assume_policy" {
  statement {
    sid    = ""
    effect = "Allow"

    principals {
      identifiers = ["states.us-east-1.amazonaws.com"]
      type        = "Service"
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_sfn" {
  name               = "iam_for_sfn"
  assume_role_policy = "${data.aws_iam_policy_document.sfn_assume_policy.json}"
}


resource "aws_iam_role_policy_attachment" "sfn_lambda_invoke_policy_attachment" {
  role       = aws_iam_role.iam_for_sfn.name
  policy_arn = "arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess" 
}

resource "aws_iam_role_policy_attachment" "lambda-invocation" {
  role       = "${aws_iam_role.iam_for_sfn.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
}

resource "aws_iam_policy" "step_function_lambda_policy" {
  name        = "step_function_lambda_policy"
  description = "IAM policy to allow Step Function to invoke Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "lambda:InvokeFunction"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "step_function_lambda_policy_attachment" {
  role       = aws_iam_role.iam_for_sfn.name
  policy_arn = aws_iam_policy.step_function_lambda_policy.arn
}

resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = "my-state-machine"
  role_arn = aws_iam_role.iam_for_sfn.arn
/*
  definition = <<EOF
{
  "Comment": "A description of my state machine",
  "StartAt": "Lambda Invoke",
  "States": {
    "Lambda Invoke": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:891377146519:function:lambda_function_name2:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 1,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "End": true
    }
  }
}
EOF
*/

definition = <<EOF
{
  "Comment": "A description of my state machine",
  "StartAt": "Check Path Variable",
  "States": {
    "Check Path Variable": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.resource_path_v1",
          "IsPresent": true,
          "Next": "Invoke Lambda 1"
        },
        {
          "Variable": "$.resource_path_v2",
          "IsPresent": true,
          "Next": "Invoke Lambda 2"
        }
      ],
      "Default": "Default State"
    },
    "Invoke Lambda 1": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:891377146519:function:lambda_function_name2:1"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 1,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "End": true
    },
    "Invoke Lambda 2": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:891377146519:function:lambda_function_name2:2"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 1,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "End": true
    },
    "Default State": {
      "Type": "Fail",
      "Cause": "No valid path variable found",
      "Error": "InvalidPath"
    }
  }
}
EOF
}


# Define CloudWatch log groups
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name = "/aws/api_gateway"
}

# Attach IAM Policy to IAM Role
resource "aws_iam_role_policy_attachment" "api_log_policy_attachment" {
  role       = aws_iam_role.iam_for_api_gateway.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"  
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name = "/aws/lambda/lambda_function_name2"
}

resource "aws_cloudwatch_log_group" "lambda_auth_logs" {
  name = "/aws/lambda/authorizer"
}

resource "aws_cloudwatch_log_group" "step_function_logs" {
  name = "/aws/states"
}

data "aws_iam_policy_document" "step_function_logs_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "${aws_cloudwatch_log_group.step_function_logs.arn}",
      "${aws_cloudwatch_log_group.step_function_logs.arn}:*"  # Include all log streams
    ]
  }
}

resource "aws_iam_policy" "step_function_logs_policy" {
  name   = "step_function_logs_policy"
  policy = data.aws_iam_policy_document.step_function_logs_policy.json
}

resource "aws_iam_role_policy_attachment" "step_function_logs_policy_attachment" {
  role       = aws_iam_role.iam_for_sfn.name
  policy_arn = aws_iam_policy.step_function_logs_policy.arn
}
/*
resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx_errors_alarm" {
  alarm_name          = "api_gateway_5xx_errors_alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alarm on 5xx errors in API Gateway"
  
  dimensions = {
    ApiName = aws_api_gateway_rest_api.example_api.name
  }
}
*//*
resource "aws_cloudwatch_metric_alarm" "lambda_errors_alarm" {
  alarm_name          = "lambda_errors_alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alarm on errors in Lambda function"

  dimensions = {
    FunctionName = aws_lambda_function.test_lambda.function_name
  }


}*/
/*
resource "aws_cloudwatch_metric_alarm" "step_function_errors_alarm" {
  alarm_name          = "step_function_errors_alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "FailedExecutions"
  namespace           = "AWS/States"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alarm on failed executions in Step Function"

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.sfn_state_machine.arn
  }
}*/