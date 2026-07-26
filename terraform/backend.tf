# Fill in with the bucket/table names created by ../bootstrap, then run
# `terraform init` (Terraform cannot interpolate variables in this block).
terraform {
  backend "s3" {
    bucket         = "CHANGEME-example-react-app-tfstate"
    key            = "example-react-app/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "example-react-app-tf-locks"
    encrypt         = true
  }
}
