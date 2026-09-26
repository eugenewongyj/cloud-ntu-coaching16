variable "aws_region" {
  description = "Target deployment region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "tk-tf-coaching16"
}

variable "root_domain" {
  description = "Hosted zone domain in Route 53"
  type        = string
  default     = "sctp-sandbox.com"
}

variable "subdomain" {
  description = "Custom subdomain assigned to the group"
  type        = string
  default     = "tk-tf-coaching16"
}

variable "stage_name" {
  description = "API Gateway deployment stage name"
  type        = string
  default     = "prod"
}

variable "my_allowed_ip_cidr" {
  description = "Allowed developer public IPv4 CIDR for WAF allowlist"
  type        = string
  default     = "210.10.77.168/32" # Replace with your current public IP
}