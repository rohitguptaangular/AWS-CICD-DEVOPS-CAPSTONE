output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "jenkins_public_ip" {
  value = aws_eip.jenkins.public_ip
}

# The infra pipeline's Ansible stage targets this, not the public IP: an instance
# reaching its own public IP goes out through the IGW and comes back with its
# public address as the source, which the admin-IP rule does not match.
output "jenkins_private_ip" {
  value = aws_instance.jenkins.private_ip
}

output "jenkins_url" {
  value = "http://${aws_eip.jenkins.public_ip}:8080"
}

# Consumed by the platform module through terraform_remote_state.
output "jenkins_sg_id" {
  value = aws_security_group.jenkins.id
}

output "jenkins_role_arn" {
  value = aws_iam_role.jenkins.arn
}
