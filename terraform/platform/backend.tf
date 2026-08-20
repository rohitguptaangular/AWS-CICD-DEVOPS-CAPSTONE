terraform {
  backend "s3" {
    bucket       = "herovire-capstone-tfstate-376129434099"
    key          = "platform/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
