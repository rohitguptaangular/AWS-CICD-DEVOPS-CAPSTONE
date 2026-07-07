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
