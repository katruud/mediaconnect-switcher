terraform {
  required_version = "~> 1.4.4"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
  backend "s3" {
    bucket = "omf-dev-terraform"
    key    = "terraform/omf-dev-mediaconnect.tfstate"
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

# We can't use count on providers, so we need to define every region we want to use
provider "aws" {
  region = "us-east-2"
  alias  = "us-east-2"
  default_tags {
    tags = {
      createdby = "terraform"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
  alias  = "eu-west-2"
  default_tags {
    tags = {
      createdby = "terraform"
    }
  }
}