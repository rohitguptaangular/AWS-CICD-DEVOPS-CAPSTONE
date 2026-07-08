# Input variables — central place to tweak values without editing every file.
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Short name used as a prefix for resource names"
  type        = string
  default     = "herovire"
}

variable "admin_ip_cidr" {
  description = "Your IP (as CIDR) allowed to SSH and reach the Jenkins UI. Update when your home IP changes."
  type        = string
  default     = "171.61.116.174/32"
}

variable "github_webhook_cidrs" {
  description = "GitHub's official webhook source IP ranges (for port 8080)"
  type        = list(string)
  default     = ["192.30.252.0/22", "185.199.108.0/22", "140.82.112.0/20", "143.55.64.0/20"]
}
