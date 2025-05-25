output "lambda_east_arn" {
  value = module.east.lambda_arn
}

output "lambda_west_arn" {
  value = module.west.lambda_arn
}

output "east_stage_arn"{
    value = module.east.stage_arn
}

output "west_stage_arn"{
    value = module.west.stage_arn
}
