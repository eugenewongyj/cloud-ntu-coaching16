output "custom_domain_url" {
  description = "Public custom endpoint for URL Shortener"
  value       = "https://${aws_api_gateway_domain_name.custom_domain.domain_name}"
}

output "waf_log_group_name" {
  description = "CloudWatch log group recording blocked requests"
  value       = aws_cloudwatch_log_group.waf_logs.name
}