terraform {
  required_version = "~> 1.4.4"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
  backend "s3" {
    bucket = "omf-dev-terraform"
    key    = "terraform/omf-dev-flask.tfstate"
    region = "us-east-2"
  }
}

# Base provider
provider "aws" {
  region = "us-east-2"
  default_tags {
    tags = {
      createdby = "terraform"
    }
  }
}