# 1. ACM Certificate (Must be REGIONAL for Regional API Gateway endpoint)
resource "aws_acm_certificate" "cert" {
  domain_name       = "grp2.sctp-sandbox.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# 2. API Gateway REST API & Deployment
resource "aws_api_gateway_rest_api" "api" {
  name        = "grp2-api"
  description = "CE13, coach16, grp2 API Gateway"
}

resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "v1"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.method.http_method
  type        = "MOCK"
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  depends_on = [
    aws_api_gateway_integration.integration
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "prod"
}

# 3. API Gateway Custom Domain Name
resource "aws_api_gateway_domain_name" "shortener" {
  domain_name              = "grp2.sctp-sandbox.com"
  regional_certificate_arn = aws_acm_certificate.cert.arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# 4. Map the Domain Name to the API Stage
resource "aws_api_gateway_base_path_mapping" "shortener" {
  api_id      = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  domain_name = aws_api_gateway_domain_name.shortener.domain_name
}

# 5. Route 53 DNS Record pointing to the Custom Domain
data "aws_route53_zone" "primary" {
  name         = "sctp-sandbox.com"
  private_zone = false
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = aws_api_gateway_domain_name.shortener.domain_name
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.shortener.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.shortener.regional_zone_id
    evaluate_target_health = false
  }
}