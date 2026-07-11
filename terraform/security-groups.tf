# =====================================================================
# Security Groups — virtual firewalls.
# Same idea as the Sprint 1 jenkins-sg, now as code. Uses the modern
# aws_vpc_security_group_*_rule resources (one rule = one resource,
# cleaner than inline rules).
# =====================================================================

resource "aws_security_group" "jenkins" {
  name        = "${var.project_name}-jenkins-sg"
  description = "Jenkins: SSH + UI from admin IP, webhook from GitHub ranges"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.project_name}-jenkins-sg" }
}

# --- SSH (22) from your IP only ---
resource "aws_vpc_security_group_ingress_rule" "jenkins_ssh" {
  security_group_id = aws_security_group.jenkins.id
  description       = "SSH from admin IP"
  cidr_ipv4         = var.admin_ip_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# --- Jenkins UI (8080) from your IP ---
resource "aws_vpc_security_group_ingress_rule" "jenkins_ui_admin" {
  security_group_id = aws_security_group.jenkins.id
  description       = "Jenkins UI from admin IP"
  cidr_ipv4         = var.admin_ip_cidr
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

# --- Jenkins UI (8080) from GitHub's webhook ranges (one rule per CIDR) ---
resource "aws_vpc_security_group_ingress_rule" "jenkins_webhook" {
  for_each          = toset(var.github_webhook_cidrs)
  security_group_id = aws_security_group.jenkins.id
  description       = "GitHub webhook"
  cidr_ipv4         = each.value
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

# --- Allow all outbound (so Jenkins can reach GitHub, ECR, the internet) ---
resource "aws_vpc_security_group_egress_rule" "jenkins_all" {
  security_group_id = aws_security_group.jenkins.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # -1 = all protocols
}

# Note: EKS creates and manages its own cluster/node security groups
# automatically, so we don't hand-write those here. If we need Jenkins
# to reach the EKS API, we'll add a targeted rule in the EKS config (2.5).
