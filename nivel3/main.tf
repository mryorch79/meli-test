terraform {
backend "s3" {
    bucket="jv-093670503449"
    key="meli/test/cache"
    region="us-east-1"
}
  required_providers {
    aws = {
        source = "hashicorp/aws"
    }
  }
}