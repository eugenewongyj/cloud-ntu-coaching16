#Creates a DynamoDB table named url_table in Terraform
resource "aws_dynamodb_table" "url_table" {
  name         = "grp2_shortener" #Actual DynamoDB table name
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "grp2_short_id" #primary key

  attribute {
    name = "short_id"
    type = "S" #Defines the key as a string
  }

  tags = {
    Project = "URLShortener"
    Owner   = "Group2"
  }
}
