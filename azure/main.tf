terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.15.0"
    }
  }
}
variable "language_service_name" {
  default = "saurabh-launguage-service"
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "my-function-rg"
  location = "East US"
}

# Create a storage account
resource "azurerm_storage_account" "sa" {
  name                     = "myfunctionsaurabh"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create a storage container for function deployment
resource "azurerm_storage_container" "sc" {
  name                  = "functionappcode"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

# Create a zip file from the local directory
data "archive_file" "function_app_zip" {
  type        = "zip"
  source_dir  = "${path.module}/MyFunctionProject"
  output_path = "${path.module}/function_app.zip"
}

# Upload the zip file to the storage account
resource "azurerm_storage_blob" "function_app_blob" {
  name                   = "function_app.zip"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.sc.name
  type                   = "Block"
  source                 = data.archive_file.function_app_zip.output_path
}

# Create an App Service Plan
resource "azurerm_service_plan" "asp" {
  name                = "my-function-asp"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

# Create Application Insights
resource "azurerm_application_insights" "ai" {
  name                = "my-function-insights"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
}

# Create Azure OpenAI Service
resource "azurerm_cognitive_account" "openai" {
  name                = "my-openai-service"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "OpenAI"
  sku_name            = "S0"
}

# Deploy gpt-4o-mini model
resource "azurerm_cognitive_deployment" "gpt4o_mini" {
  name                 = "gpt-4o-mini"
  cognitive_account_id = azurerm_cognitive_account.openai.id
  model {
    format  = "OpenAI"
    name    = "gpt-4o-mini"  # Make sure this matches your actual model name
  }
  scale {
    type = "Standard"
    capacity = 8
  }
}

# Create a storage account for search data
resource "azurerm_storage_account" "search_data" {
  name                     = "mysearchdatasaurabh"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create a container in the storage account for search data
resource "azurerm_storage_container" "search_data" {
  name                  = "searchdata"
  storage_account_name  = azurerm_storage_account.search_data.name
  container_access_type = "private"
}


resource "azurerm_search_service" "search" {
  name                = "saurabh-ai-search-service"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "standard"
}

# Create and delete data source
resource "null_resource" "search_datasource" {
  triggers = {
    search_service_name = azurerm_search_service.search.name
    storage_account_name = azurerm_storage_account.search_data.name
    container_name = azurerm_storage_container.search_data.name
  }

  provisioner "local-exec" {
    command = <<EOT
      echo "Creating search datasource"
      API_KEY=$(az search admin-key show --resource-group ${azurerm_resource_group.rg.name} --service-name ${azurerm_search_service.search.name} --query primaryKey -o tsv)
      CONN_STRING=$(az storage account show-connection-string --name ${azurerm_storage_account.search_data.name} --resource-group ${azurerm_resource_group.rg.name} --query connectionString -o tsv)
      RESPONSE=$(curl -X POST \
        "https://${azurerm_search_service.search.name}.search.windows.net/datasources?api-version=2021-04-30-Preview" \
        -H "Content-Type: application/json" \
        -H "api-key: $API_KEY" \
        -d '{
          "name": "my-search-datasource",
          "type": "azureblob",
          "credentials": {
            "connectionString": "'"$CONN_STRING"'"
          },
          "container": {
            "name": "${azurerm_storage_container.search_data.name}"
          }
        }')
      echo $RESPONSE
      if [[ $RESPONSE == *"error"* ]]; then
        echo "Error creating datasource"
        exit 1
      fi
    EOT
  }
}

# Create and delete search index
resource "null_resource" "search_index" {
  triggers = {
    search_service_name = azurerm_search_service.search.name
    datasource_creation = null_resource.search_datasource.id
  }

  provisioner "local-exec" {
    command = <<EOT
      echo "Creating search index"
      API_KEY=$(az search admin-key show --resource-group ${azurerm_resource_group.rg.name} --service-name ${azurerm_search_service.search.name} --query primaryKey -o tsv)
      RESPONSE=$(curl -X POST \
        "https://${azurerm_search_service.search.name}.search.windows.net/indexes?api-version=2021-04-30-Preview" \
        -H "Content-Type: application/json" \
        -H "api-key: $API_KEY" \
        -d '{
          "name": "my-search-index",
          "fields": [
            {"name": "id", "type": "Edm.String", "key": true, "searchable": true, "filterable": true, "sortable": true, "facetable": false},
            {"name": "content", "type": "Edm.String", "searchable": true, "filterable": false, "sortable": false, "facetable": false}
          ]
        }')
      echo $RESPONSE
      if [[ $RESPONSE == *"error"* ]]; then
        echo "Error creating index"
        exit 1
      fi
    EOT
  }

  depends_on = [null_resource.search_datasource]
}

# Create and delete search indexer
resource "null_resource" "search_indexer" {
  triggers = {
    search_service_name = azurerm_search_service.search.name
    index_creation = null_resource.search_index.id
  }

  provisioner "local-exec" {
    command = <<EOT
      echo "Creating search indexer"
      API_KEY=$(az search admin-key show --resource-group ${azurerm_resource_group.rg.name} --service-name ${azurerm_search_service.search.name} --query primaryKey -o tsv)
      RESPONSE=$(curl -X POST \
        "https://${azurerm_search_service.search.name}.search.windows.net/indexers?api-version=2021-04-30-Preview" \
        -H "Content-Type: application/json" \
        -H "api-key: $API_KEY" \
        -d '{
          "name": "my-search-indexer",
          "dataSourceName": "my-search-datasource",
          "targetIndexName": "my-search-index",
          "schedule": {
            "interval": "PT5M"
          },
          "parameters": {
            "batchSize": 100,
            "maxFailedItems": 10,
            "maxFailedItemsPerBatch": 5
          }
        }')
      echo $RESPONSE
      if [[ $RESPONSE == *"error"* ]]; then
        echo "Error creating indexer"
        exit 1
      fi
    EOT
  }

  depends_on = [null_resource.search_index]
}

data "azurerm_cognitive_account" "language" {
  name                = var.language_service_name
  resource_group_name = azurerm_resource_group.rg.name
}


# Create a Function App
resource "azurerm_linux_function_app" "fa" {
  name                       = "my-function-saurabh-linux"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  service_plan_id            = azurerm_service_plan.asp.id
  storage_account_name       = azurerm_storage_account.sa.name
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key

  site_config {
    http2_enabled = true
    application_insights_connection_string = azurerm_application_insights.ai.connection_string
    application_insights_key               = azurerm_application_insights.ai.instrumentation_key
    
    application_stack {
      python_version = "3.9"  # Adjust based on your Python version
    }
  }

  app_settings = {
    WEBSITE_RUN_FROM_PACKAGE       = azurerm_storage_blob.function_app_blob.url
    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.ai.instrumentation_key
    FUNCTIONS_WORKER_RUNTIME       = "python"
    WEBSITE_USE_ZIP                = "1"
    FUNCTION_APP_EDIT_MODE         = "readwrite"
    AzureFunctionsJobHost__logging__logLevel__default = "Information"
    OPENAI_API_TYPE     = "azure"
    OPENAI_API_BASE     = azurerm_cognitive_account.openai.endpoint
    OPENAI_API_VERSION  = "2023-05-15"
    OPENAI_API_KEY      = azurerm_cognitive_account.openai.primary_access_key
    OPENAI_DEPLOYMENT_NAME = azurerm_cognitive_deployment.gpt4o_mini.name
    # AI Search settings
    AZURE_SEARCH_SERVICE = azurerm_search_service.search.name
    AZURE_SEARCH_KEY     = azurerm_search_service.search.primary_key
    AZURE_SEARCH_INDEX   = "my-search-index"

    LANGUAGE_KEY      = data.azurerm_cognitive_account.language.primary_access_key
    LANGUAGE_ENDPOINT = data.azurerm_cognitive_account.language.endpoint
  }
}


# Add diagnostic settings for function app logs
resource "azurerm_monitor_diagnostic_setting" "function_app_logs" {
  name                       = "function-app-logs"
  target_resource_id         = azurerm_linux_function_app.fa.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category_group = "allLogs"
    retention_policy {
      enabled = false
    }
  }

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }
}

# Create Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "law" {
  name                = "my-function-law"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "function_app_name" {
  value = azurerm_linux_function_app.fa.name
}


# New outputs
output "openai_api_type" {
  value = "azure"
}

output "openai_api_base" {
  value = azurerm_cognitive_account.openai.endpoint
}

output "openai_api_version" {
  value = "2023-05-15"
}

output "openai_api_key" {
  value     = azurerm_cognitive_account.openai.primary_access_key
  sensitive = true
}

output "openai_deployment_name" {
  value = azurerm_cognitive_deployment.gpt4o_mini.name
}

# Update outputs to include AI Search and storage information
output "ai_search_service_name" {
  value = azurerm_search_service.search.name
}

output "ai_search_service_endpoint" {
  value = "https://${azurerm_search_service.search.name}.search.windows.net"
}

output "ai_search_primary_key" {
  value     = azurerm_search_service.search.primary_key
  sensitive = true
}


# Output the Azure Search primary key (sensitive)
output "azure_search_primary_key" {
  value     = azurerm_search_service.search.primary_key
  sensitive = true
}

# Add these to your outputs
output "language_key" {
  value     = data.azurerm_cognitive_account.language.primary_access_key
  sensitive = true
}

output "language_endpoint" {
  value = data.azurerm_cognitive_account.language.endpoint
}