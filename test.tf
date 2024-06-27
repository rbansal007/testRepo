terraform {
  cloud {
    hostname = "ramit-eks.tf-support.hashicorpdemo.com"
    organization = "30thMay"

    workspaces {
      name = "testWorkspace_30thMay"
    }
  }
}

  resource "null_resource" "null2" {}

