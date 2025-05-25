resource "aws_dynamodb_table" "crud_table" {
  name           = "demo_table"  # Replace with your desired table name
  billing_mode   = "PROVISIONED"  # On-demand pricing
  hash_key       = "id"
  read_capacity  = 1
  write_capacity = 1

  attribute {
    name = "id"
    type = "S"
  }

#   attribute{
#     name = "value"
#     type = "N"
#   }

  tags = {
    Environment = "dev"
    Project     = "lambda-crud"
  }
}

resource "aws_dynamodb_table" "crud_table_west" {
  provider       = aws.west
  name           = "demo_table"  # Replace with your desired table name
  billing_mode   = "PROVISIONED"  # On-demand pricing
  hash_key       = "id"
  read_capacity  = 1
  write_capacity = 1

  attribute {
    name = "id"
    type = "S"
  }

#   attribute{
#     name = "value"
#     type = "N"
#   }

  tags = {
    Environment = "dev"
    Project     = "lambda-crud"
  }
}
