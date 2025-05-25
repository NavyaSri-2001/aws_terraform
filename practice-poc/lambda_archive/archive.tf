data "archive_file" "zip_lambda_code"{
    type = "zip"
    source_dir = "./controller"
    output_path = "./controller/zip_lambda_code.zip"

}