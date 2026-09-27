# ==========================================
# 1. ROUTE 53 (HOSTED ZONE DATA SOURCE)
# ==========================================

# Lookup existing Route 53 Hosted Zone
data "aws_route53_zone" "primary" {
  name         = var.domain_name
  private_zone = false
}

# ==========================================
# 2. AWS CERTIFICATE MANAGER (ACM)
# ==========================================

# Request Public Certificate
resource "aws_acm_certificate" "api_cert" {
  domain_name       = var.subdomain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "api-gateway-cert"
  }
}

# Create Route 53 DNS Validation Record
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.primary.zone_id
}

# Validate Certificate
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.api_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# # ==========================================
# # 3. AWS WAFv2 (WEB ACL & IP SET)
# # ==========================================

# # Create IP Set for IP Whitelisting
# resource "aws_wafv2_ip_set" "allowed_ips" {
#   name               = "allowed-ip-set"
#   description        = "IP set for allowed client IPs"
#   scope              = "REGIONAL"
#   ip_address_version = "IPV4"
#   addresses          = var.my_allowed_ip_cidr

#   tags = {
#     Name = "allowed-ip-set"
#   }
# }

# # Create Web ACL
# resource "aws_wafv2_web_acl" "api_waf" {
#   name        = "api-gateway-waf"
#   description = "WAF for API Gateway with IP restriction"
#   scope       = "REGIONAL"

#   default_action {
#     block {} # Block all traffic by default
#   }

#   # Allow rule for IP Set
#   rule {
#     name     = "AllowWhitelistedIPs"
#     priority = 1

#     action {
#       allow {}
#     }

#     statement {
#       ip_set_reference_statement {
#         arn = aws_wafv2_ip_set.allowed_ips.arn
#       }
#     }

#     visibility_config {
#       cloudwatch_metrics_enabled = true
#       metric_name                = "AllowWhitelistedIPsMetric"
#       sampled_requests_enabled   = true
#     }
#   }

#   visibility_config {
#     cloudwatch_metrics_enabled = true
#     metric_name                = "ApiGatewayWAFMetric"
#     sampled_requests_enabled   = true
#   }

#   tags = {
#     Name = "api-gateway-waf"
#   }
# }

# # CloudWatch Log Group for WAF Blocked Requests
# resource "aws_cloudwatch_log_group" "waf_logs" {
#   name              = "aws-waf-logs-api-gateway" # Must start with 'aws-waf-logs-'
#   retention_in_days = 14
# }

# # Configure WAF Logging to log ONLY blocked requests
# resource "aws_wafv2_web_acl_logging_configuration" "waf_logging" {
#   log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]
#   resource_arn            = aws_wafv2_web_acl.api_waf.arn

#   logging_filter {
#     default_behavior = "DROP"

#     filter {
#       behavior    = "KEEP"
#       requirement = "MEETS_ANY"

#       condition {
#         action_condition {
#           action = "BLOCK"
#         }
#       }
#     }
#   }
# }

# ==========================================
# 4. AMAZON API GATEWAY (REST API v1)
# ==========================================

# 1. Create REST API
resource "aws_api_gateway_rest_api" "api" {
  name        = "url-shortener-api"
  description = "URL Shortener REST API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# 2. Setup Custom Domain in API Gateway
resource "aws_api_gateway_domain_name" "custom_domain" {
  domain_name              = var.subdomain_name
  regional_certificate_arn = aws_acm_certificate_validation.cert_validation.certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# 3. Create Deployment & Stage
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha256(jsonencode([
      aws_api_gateway_rest_api.api.body,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "prod"
}

# 4. Map the Domain Name to the API Stage
resource "aws_api_gateway_base_path_mapping" "mapping" {
  api_id      = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  domain_name = aws_api_gateway_domain_name.custom_domain.domain_name
}

# # 5. Associate WAF Web ACL with REST API Stage
# resource "aws_wafv2_web_acl_association" "waf_assoc" {
#   resource_arn = aws_api_gateway_stage.prod.arn
#   web_acl_arn  = aws_wafv2_web_acl.api_waf.arn
# }

#==========================================
# 5. ROUTE 53 ALIAS RECORD TO CUSTOM DOMAIN
# ==========================================

# Alias record pointing subdomain to API Gateway Custom Domain Endpoint
resource "aws_route53_record" "api_subdomain" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = var.subdomain_name
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.custom_domain.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.custom_domain.regional_zone_id
    evaluate_target_health = false
  }
}



