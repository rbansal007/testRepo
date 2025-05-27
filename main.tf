terraform {
  required_providers {
    random = {
      source = "hashicorp/random"
      version = "3.6.3"
    }
  }  
}

provider "random" {
  # Configuration options
}

resource "random_password" "password" {
  length           = 28
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
