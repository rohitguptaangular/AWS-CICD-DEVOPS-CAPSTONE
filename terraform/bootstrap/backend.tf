terraform {
  backend "s3" {
    bucket       = "herovire-capstone-tfstate-376129434099"
    key          = "bootstrap/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
