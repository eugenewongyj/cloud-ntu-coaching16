locals {
  full_domain_name = "${var.subdomain}.${var.root_domain}"
}

# 1. Query pre-existing wildcard ACM certificate
data "aws_acm_certificate" "wildcard" {
  domain      = "*.${var.root_domain}"
  statuses    = ["ISSUED"]
  most_recent = true
}

# 2. Query Route 53 Hosted Zone
data "aws_route53_zone" "primary" {
  name         = var.root_domain
  private_zone = false
}

# 3. REST API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.project_name}-api"
  description = "URL Shortener REST API"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# ---------------------------------------------
# POST /newurl
# ---------------------------------------------
resource "aws_api_gateway_resource" "newurl" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "newurl"
}

resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.newurl.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.newurl.id
  http_method             = aws_api_gateway_method.post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.create_url.invoke_arn
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.newurl.id
  http_method = aws_api_gateway_method.post_method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

# ---------------------------------------------
# GET /{shortid}
# ---------------------------------------------
resource "aws_api_gateway_resource" "geturl" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{shortid}"
}

resource "aws_api_gateway_method" "get_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.geturl.id
  http_method   = "GET"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.shortid" = true
  }
}

resource "aws_api_gateway_integration" "get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.geturl.id
  http_method             = aws_api_gateway_method.get_method.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.retrieve_url.invoke_arn
  request_templates = {
    "application/json" = <<EOF
{
  "short_id": "$input.params('shortid')"
}
EOF
  }
}

resource "aws_api_gateway_method_response" "response_302" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.geturl.id
  http_method = aws_api_gateway_method.get_method.http_method
  status_code = "302"
  response_parameters = {
    "method.response.header.Location" = true
  }
}

resource "aws_api_gateway_integration_response" "get_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.geturl.id
  http_method = aws_api_gateway_method.get_method.http_method
  status_code = aws_api_gateway_method_response.response_302.status_code
  response_parameters = {
    "method.response.header.Location" = "integration.response.body.location"
  }
  depends_on = [
    aws_api_gateway_integration.get_integration
  ]
}

# ---------------------------------------------
# Lambda Execution Permissions for API Gateway
# ---------------------------------------------
resource "aws_lambda_permission" "apigw_create" {
  statement_id  = "AllowAPIGatewayInvokeCreate"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_retrieve" {
  statement_id  = "AllowAPIGatewayInvokeRetrieve"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.retrieve_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# ---------------------------------------------
# Deployment & Stage (X-Ray Enabled)
# ---------------------------------------------
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.newurl.id,
      aws_api_gateway_method.post_method.id,
      aws_api_gateway_integration.post_integration.id,
      aws_api_gateway_resource.geturl.id,
      aws_api_gateway_method.get_method.id,
      aws_api_gateway_integration.get_integration.id,
      aws_api_gateway_integration_response.get_integration_response.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.post_integration,
    aws_api_gateway_integration.get_integration
  ]
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id        = aws_api_gateway_deployment.deployment.id
  rest_api_id          = aws_api_gateway_rest_api.api.id
  stage_name           = var.stage_name
  xray_tracing_enabled = true
}

# ---------------------------------------------
# Custom Domain, Base Path Mapping & Route 53
# ---------------------------------------------
resource "aws_api_gateway_domain_name" "custom_domain" {
  domain_name              = local.full_domain_name
  regional_certificate_arn = data.aws_acm_certificate.wildcard.arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_base_path_mapping" "mapping" {
  api_id      = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.stage.stage_name
  domain_name = aws_api_gateway_domain_name.custom_domain.domain_name
}

resource "aws_route53_record" "alias" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = aws_api_gateway_domain_name.custom_domain.domain_name
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.custom_domain.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.custom_domain.regional_zone_id
    evaluate_target_health = false
  }
}