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

variable "admin_principal_arn" {
  description = "IAM principal that administers the cluster from a workstation"
  type        = string
  default     = "arn:aws:iam::376129434099:user/anjaliiam"
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
