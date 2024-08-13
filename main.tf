provider "null" {}

# Resource to validate the TFC_CONFIGURATION_VERSION_REPO_ID environment variable
resource "null_resource" "validate_repo_name" {
  provisioner "local-exec" {
    command = <<EOT
      if [ -z "$TFC_CONFIGURATION_VERSION_REPO_ID" ]; then
        echo "TFC_CONFIGURATION_VERSION_REPO_ID is not set."
        exit 1
      else
        echo "TFC_CONFIGURATION_VERSION_REPO_ID is set to: $TFC_CONFIGURATION_VERSION_REPO_ID"
        # Optionally, you can add a regex check to validate the format
        if [[ "$TFC_CONFIGURATION_VERSION_REPO_ID" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$ ]]; then
          echo "The repository name format is valid."
        else
          echo "The repository name format is invalid."
          exit 1
        fi
      fi
    EOT
  }
}

# Output the repository name for reference
output "repository_name" {
  value = "TFC_CONFIGURATION_VERSION_REPO_ID: ${var.repo_name}"
}
