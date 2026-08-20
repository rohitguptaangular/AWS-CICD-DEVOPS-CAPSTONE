# The network and the Jenkins host live in the bootstrap state, which this
# module only ever reads. That one-way dependency is the whole point of the
# split: applying platform/ cannot replace the machine Jenkins runs on.
data "terraform_remote_state" "bootstrap" {
  backend = "s3"

  config = {
    bucket = "herovire-capstone-tfstate-376129434099"
    key    = "bootstrap/terraform.tfstate"
    region = "ap-south-1"
  }
}

locals {
  public_subnet_ids  = data.terraform_remote_state.bootstrap.outputs.public_subnet_ids
  private_subnet_ids = data.terraform_remote_state.bootstrap.outputs.private_subnet_ids
  jenkins_role_arn   = data.terraform_remote_state.bootstrap.outputs.jenkins_role_arn
  jenkins_sg_id      = data.terraform_remote_state.bootstrap.outputs.jenkins_sg_id
}
