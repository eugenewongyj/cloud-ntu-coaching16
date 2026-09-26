variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "tk-tf-coaching16"
}

variable "my_allowed_ip_cidr" {
  description = "Allowed developer public IPv4 CIDR for WAF allowlist"
  type        = string
  default     = "210.10.77.168/32" # Replace with your current public IP
}