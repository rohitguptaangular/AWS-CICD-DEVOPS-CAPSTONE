variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Prefix for resource names"
  type        = string
  default     = "herovire"
}

variable "admin_ip_cidr" {
  description = "IP (CIDR) allowed to SSH and reach the Jenkins UI"
  type        = string
  default     = "171.61.116.174/32"
}

variable "github_webhook_cidrs" {
  description = "GitHub webhook source IP ranges (port 8080)"
  type        = list(string)
  default     = ["192.30.252.0/22", "185.199.108.0/22", "140.82.112.0/20", "143.55.64.0/20"]
}

variable "key_name" {
  description = "Existing EC2 key pair for SSH access to Jenkins"
  type        = string
  default     = "jenkins-key"
}

variable "jenkins_instance_type" {
  description = "Instance type for the Jenkins server"
  type        = string
  default     = "t3.medium"
}

variable "eks_version" {
  description = "Kubernetes version (must be in standard support)"
  type        = string
  default     = "1.33"
}

variable "node_instance_type" {
  description = "Instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}
