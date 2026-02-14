terraform {
  backend "s3" {
    bucket         = "116527261062-bookstore-terraform-state"
    key            = "environments/dev/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "bookstore-terraform-locks"
  }
}
