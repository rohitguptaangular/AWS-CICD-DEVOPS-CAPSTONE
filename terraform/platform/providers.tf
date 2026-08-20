provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "herovire-capstone"
      ManagedBy = "terraform"
      Layer     = "platform"
    }
  }
}
