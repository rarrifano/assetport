terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment and fill in once you have an S3 bucket for Terraform state.
  # For free-tier testing, local state is fine.
  #
  # backend "s3" {
  #   bucket         = "assetport-tfstate"
  #   key            = "assetport/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "assetport-tfstate-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "assetport"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# CloudFront requires ACM certificates in us-east-1 regardless of the app region
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "assetport"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
