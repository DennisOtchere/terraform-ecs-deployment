terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">6.0"
    }
  }
  required_version = ">= 1.2"


 
  backend "s3" {
    bucket = "my-unique-devops-project-state-storage"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
  }

}