terraform {
  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.56.0"
    }
  }
}

# Configuring AWS as the provider
provider "aws" {
  region  = var.aws_region
  profile = "edge-pov-profile"
}

