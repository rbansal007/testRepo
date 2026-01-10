terraform {
  required_version = ">= 1.0"
  
  cloud {
    hostname     = "rbtfe.tf-support.hashicorpdemo.com"
    organization = "test"
    
    workspaces {
      name = "testRepo"
    }
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

variable "s3_uri_artifact_custom_settings_yaml" {
  description = "S3 URI for custom settings YAML"
  type        = string
  default     = ""
}

variable "cluster_identifier" {
  description = "Database cluster identifier"
  type        = string
  default     = "demo-db-cluster-ap-south-1"
}

variable "sns_warning_email" {
  description = "SNS topic ARN for warning alerts"
  type        = string
  default     = "arn:aws:sns:ap-south-1:123456789012:warning-topic"
}

variable "sns_critical_email" {
  description = "SNS topic ARN for critical alerts"
  type        = string
  default     = "arn:aws:sns:ap-south-1:123456789012:critical-topic"
}

# Simulating the data source behavior using local_file
# In real scenario, this would be cpaws_s3_object_download
# Removed count to ensure stable evaluation in TFE
data "local_file" "custom_settings_yaml" {
  filename = "${path.module}/custom-settings.yaml"
}

locals {
  # Decode YAML from file content - more stable evaluation for TFE
  # Read file content first, then decode - avoid array indexing with try()
  yaml_file_content = data.local_file.custom_settings_yaml.content
  
  # Decode YAML with explicit null handling for TFE stability
  custom_settings_yaml = var.s3_uri_artifact_custom_settings_yaml != "" ? (
    yamldecode(local.yaml_file_content)
  ) : {}
}

module "aurora_cluster" {
  source = "./modules/cluster"

  cluster_identifier   = var.cluster_identifier
  sns_warning_email    = var.sns_warning_email
  sns_critical_email   = var.sns_critical_email
  custom_settings_yaml = local.custom_settings_yaml
}

output "custom_settings_loaded" {
  value = local.custom_settings_yaml
}
