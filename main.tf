terraform { 
  cloud { 
    hostname = "ramit-docker.tf-support.hashicorpdemo.com" 
    organization = "testSupportBundle" 
    workspaces { 
      name = "test-ws" 
    } 
  } 
  required_providers {
    random = {
      source = "hashicorp/random"
      version = "3.6.3"
    }
  }  
}

terraform {
  required_version = ">= 1.3.0"
  backend "remote" {
    hostname     = "tfe-01"
    organization = "yuzhao-terraform"
    workspaces {
      name = "demo-workspace"
    }
  }
}

resource "null_resource" "example" {
  provisioner "local-exec" {
    command = "echo Hello from TFE!"
  }
}

provider "random" {
  # Configuration options
}

resource "random_password" "password" {
  length           = 29
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
