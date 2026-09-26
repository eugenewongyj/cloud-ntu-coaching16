# IP Set allowlisting developer IP
resource "aws_wafv2_ip_set" "allowed_ips" {
  name               = "${var.project_name}-allow-my-ips-only"
  description        = "Allowlist for authorized developer IPs"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = [var.my_allowed_ip_cidr]
}

# Web ACL with default block action
resource "aws_wafv2_web_acl" "api_gw_waf" {
  name        = "${var.project_name}-api-gateway-waf"
  description = "Block all requests outside allowed IP range"
  scope       = "REGIONAL"

  default_action {
    block {}
  }

  rule {
    name     = "AllowOnlyMyIPs"
    priority = 1

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.allowed_ips.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowOnlyMyIPs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf-metrics"
    sampled_requests_enabled   = true
  }
}

# Attach WAF directly to the API Gateway Stage
resource "aws_wafv2_web_acl_association" "waf_assoc" {
  resource_arn = aws_api_gateway_stage.prod.arn
  web_acl_arn  = aws_wafv2_web_acl.api_gw_waf.arn
}

# CloudWatch Log Group for WAF (prefixed aws-waf-logs-)
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "aws-waf-logs-${var.project_name}-api"
  retention_in_days = 14
}

# Logging configuration to record ONLY blocked requests
resource "aws_wafv2_web_acl_logging_configuration" "api_gw_waf_logging" {
  resource_arn            = aws_wafv2_web_acl.api_gw_waf.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]

  logging_filter {
    default_behavior = "DROP"

    filter {
      behavior    = "KEEP"
      requirement = "MEETS_ANY"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }
    }
  }
}