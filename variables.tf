variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "grp2-coaching16"
}

variable "my_allowed_ip_cidr" {
  description = "Allowed developer public IPv4 CIDR for WAF allowlist"
  type        = string
  default     = "210.10.77.168/32" # Replace with your current public IP
}

# variable "aws_region" {
#   type        = string
#   default     = "us-east-1"
#   description = "AWS Region"
# }

variable "domain_name" {
  type        = string
  default     = "sctp-sandbox.com"
  description = "Parent Hosted Zone domain name"
}

variable "subdomain_name" {
  type        = string
  default     = "grp2-urlshortener.sctp-sandbox.com"
  description = "Custom subdomain for API Gateway"
}