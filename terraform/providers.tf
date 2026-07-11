# Configures the AWS provider. default_tags stamps EVERY resource with these
# tags automatically — great for cost tracking and knowing what Terraform owns.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "herovire-capstone"
      ManagedBy = "terraform"
      Sprint    = "2"
    }
  }
}
