resource "aws_dynamodb_table" "url_table" {
  name         = "${var.project_name}-url-shortener-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "short_id" # Strictly matches python code expectation

  attribute {
    name = "short_id"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}