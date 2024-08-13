resource "null_resource" "print_repo_id" {
  provisioner "local-exec" {
    command = "echo Repository ID: $TFC_CONFIGURATION_VERSION_REPO_ID"
  }
}

output "repo_id" {
  value = terraform.workspace
  
}
