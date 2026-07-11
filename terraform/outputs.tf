# Outputs — values we'll reference later (EKS, EC2) or just want to see.
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "ecr_repository_url" {
  description = "URL of the ECR repository (used by the Jenkins pipeline)"
  value       = aws_ecr_repository.app.repository_url
}

output "jenkins_public_ip" {
  description = "Static (Elastic) IP of the Jenkins server"
  value       = aws_eip.jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins UI URL"
  value       = "http://${aws_eip.jenkins.public_ip}:8080"
}
