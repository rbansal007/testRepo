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
  # Directly access the environment variable
  repo_display_identifier = "${lookup(var.env, "TF_VCS_REPO_DISPLAY_IDENTIFIER", "")}"
  repo_name = split("/", local.repo_display_identifier)[1] # Extracting the repo name
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
