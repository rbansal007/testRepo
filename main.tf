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
  repo_display_identifier = lookup(var.env, "TFC_CONFIGURATION_VERSION_GIT_REPO", "")
  
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

output "vcs_repo_display_identifier" {
  value = lookup(var.env, "TFC_CONFIGURATION_VERSION_GIT_REPO", "not set")
}
