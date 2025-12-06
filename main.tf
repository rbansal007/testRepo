terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

resource "null_resource" "test_agent_vars" {
  triggers = {
    run_id = timestamp()
  }

  provisioner "local-exec" {
    command = "echo '✅ AGENT SUCCESS: SN_USER=$SN_USER | PATH=$BB_SSH_PRIVATE_KEY_PATH'"
  }
}

# These should come from agent hooks
variable "SN_USER" { default = "NOT_FROM_AGENT" }
variable "BB_SSH_PRIVATE_KEY_PATH" { default = "NOT_FROM_AGENT" }
