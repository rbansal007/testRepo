terraform { 
  required_providers {
    random = {
      source = "hashicorp/random"
      version = "3.6.3"
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
  length           = 30
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
