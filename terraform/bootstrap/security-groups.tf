resource "aws_security_group" "jenkins" {
  name        = "${var.project_name}-jenkins-sg"
  description = "Jenkins: SSH + UI from admin IP, webhook from GitHub ranges"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.project_name}-jenkins-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_ssh" {
  security_group_id = aws_security_group.jenkins.id
  description       = "SSH from admin IP"
  cidr_ipv4         = var.admin_ip_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_ui_admin" {
  security_group_id = aws_security_group.jenkins.id
  description       = "Jenkins UI from admin IP"
  cidr_ipv4         = var.admin_ip_cidr
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_webhook" {
  for_each          = toset(var.github_webhook_cidrs)
  security_group_id = aws_security_group.jenkins.id
  description       = "GitHub webhook"
  cidr_ipv4         = each.value
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

# The infra pipeline runs Ansible from Jenkins against the Jenkins host itself
# over its private address, so SSH has to be allowed within the group.
resource "aws_vpc_security_group_ingress_rule" "jenkins_ssh_self" {
  security_group_id            = aws_security_group.jenkins.id
  description                  = "SSH within the group, for the Ansible stage"
  referenced_security_group_id = aws_security_group.jenkins.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

# Prometheus runs on the EKS nodes in the private subnets and scrapes Jenkins
# at :8080/prometheus. The nodes have no public IPs, so they reach Jenkins on
# its private address and the admin-IP rules above do not cover them.
resource "aws_vpc_security_group_ingress_rule" "jenkins_metrics_from_vpc" {
  security_group_id = aws_security_group.jenkins.id
  description       = "Prometheus scrape of Jenkins metrics, from inside the VPC"
  cidr_ipv4         = local.vpc_cidr
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "jenkins_all" {
  security_group_id = aws_security_group.jenkins.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
