terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "depi-team-1-tfstate"
    key          = "person4/terraform.tfstate" # state مستقل عشان ما يتعارضش مع باقي الفريق
    region       = "us-east-1"
    profile      = "depi-team-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "depi-team-1"

  default_tags {
    tags = {
      Project   = "depi-team-1"
      ManagedBy = "terraform"
      Owner     = "person4"
    }
  }
}

# CloudFront WAF/ACM لازم us-east-1 وده نفس الريجن، فمش محتاجين provider تاني.
