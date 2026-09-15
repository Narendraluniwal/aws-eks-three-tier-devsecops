terraform {
  backend "s3" {
    bucket = "beabucket9799"
    key    = "state"
    region = "us-east-1"
    dynamodb_table = "kira"
  }
}
