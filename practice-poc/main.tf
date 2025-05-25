module "lambda_archive"{
    source= "./lambda_archive"
}

module "east" {
  source     = "./regional_resources"
  providers  = { aws = aws.east }
  region     = "us-east-1"
  lambda_name = "crudLambda-east"
  table_name  = "demo_table"
  zip_file    = module.lambda_archive.zip_file
}

module "west" {
  source     = "./regional_resources"
  providers  = { aws = aws.west }
  region     = "us-west-2"
  lambda_name = "crudLambda-west"
  table_name  = "demo_table"
  zip_file    = module.lambda_archive.zip_file
}
