


terraform {
  backend "s3" {
    bucket = "e5statefiles"
    key    = "resume-s3/terraform.tfstate"

    region = "us-west-2" # <--- MAKE SURE THIS MATCHES YOUR BUCKET REGION

    dynamodb_table = "e5statefiles-locks" # This tells Terraform where to find the lock
    encrypt        = true
  }
} 