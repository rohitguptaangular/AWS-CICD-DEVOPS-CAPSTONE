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

resource "aws_vpc_security_group_egress_rule" "jenkins_all" {
  security_group_id = aws_security_group.jenkins.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Jenkins is inside the VPC, so the cluster endpoint resolves to the private
# ENIs and the cluster SG decides access. Without this the deploy stage's
# kubectl calls just time out.
resource "aws_vpc_security_group_ingress_rule" "eks_api_from_jenkins" {
  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  description                  = "Jenkins to EKS API server"
  referenced_security_group_id = aws_security_group.jenkins.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}
