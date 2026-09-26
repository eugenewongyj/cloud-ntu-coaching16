resource "aws_dynamodb_table" "url_table" {
  name         = "grp2_shortener"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "grp2_short_id"

  attribute {
    name = "grp2_short_id"
    type = "S"
  }

  tags = {
    Project = "URLShortener"
    Owner   = "Group2"
  }
}
