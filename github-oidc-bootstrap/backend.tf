terraform {
  backend "s3" {
    bucket = "sctp-tfstate-ce13"
    key    = "group2-coaching16-bootstrap-terraform.tfstate"
    #use_lockfile = true
    region = "us-east-1"
  }
}