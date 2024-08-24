# terraform {
#   required_providers {
#     null = {
#       source = "hashicorp/null"
#       version = "~> 3.0"
#     }
#     azurerm = {
#       source  = "hashicorp/azurerm"
#       version = "~> 3.0"
#     }
#   }
# }

# provider "azurerm" {
#   features {}
# }

# resource "null_resource" "test" {
#   provisioner "local-exec" {
#     command = "echo 'Test null_resource is executing'"
#   }
# }