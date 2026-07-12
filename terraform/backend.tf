terraform {
  backend "s3" {
    bucket       = "herovire-capstone-tfstate-859666866036"
    key          = "sprint2/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
