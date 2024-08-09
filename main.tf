terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1"
    }
  }
}

provider "null" {}

locals {
  # Access the environment variable using the input variable
  repo_display_identifier = lookup(var.env, "TF_VCS_REPO_DISPLAY_IDENTIFIER", "")
  
  # Check if the repo_display_identifier is not empty and contains a "/"
  repo_name = length(split("/", local.repo_display_identifier)) > 1 ? split("/", local.repo_display_identifier)[1] : "unknown_repo"
}

resource "null_resource" "example" {
  provisioner "local-exec" {
    command = "echo The repository name is: ${local.repo_name}"
  }

  triggers = {
    repo_name = local.repo_name
  }
}

output "repository_name" {
  value = local.repo_name
}
