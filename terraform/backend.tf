# Stores Terraform state remotely in the S3 bucket we bootstrapped.
# use_lockfile = true uses S3-native state locking (no DynamoDB needed),
# preventing two people/jobs from applying at the same time.
terraform {
  backend "s3" {
    bucket       = "herovire-capstone-tfstate-859666866036"
    key          = "sprint2/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
