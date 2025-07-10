terraform {
  required_providers {
    aws = {
      # The AWS provider comes from the official HashiCorp registry
      source = "hashicorp/aws"

      # Use version 4.16 or any compatible newer patch version (e.g., 4.16.x)
      version = ">= 5.0"
    }
  }

  # Specify the minimum Terraform CLI version required
  required_version = ">= 1.2.0"

  cloud {
    organization = "NCI-Training-Team"

    workspaces {
      name = "Cluster"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
