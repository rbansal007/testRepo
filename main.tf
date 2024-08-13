provider "null" {}

# Define a variable to hold the repo name from the environment variable
variable "repo_name" {
  description = "The name of the GitHub repository"
  type        = string
  default     = ""
}

# Use a local-exec provisioner to print the repo name
resource "null_resource" "print_repo_name" {
  provisioner "local-exec" {
    command = "echo Repository Name: ${var.repo_name}"
    environment = {
      repo_name = getenv("TFC_CONFIGURATION_VERSION_REPO_ID")
    }
  }
}

# Optionally, you can set a default value if the environment variable is not set
locals {
  repo_name = getenv("TFC_CONFIGURATION_VERSION_REPO_ID") != "" ? getenv("TFC_CONFIGURATION_VERSION_REPO_ID") : "default-repo-name"
}

output "repository_name" {
  value = local.repo_name
}
