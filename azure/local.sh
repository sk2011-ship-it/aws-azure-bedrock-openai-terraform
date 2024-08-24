#!/bin/bash

# Function to extract Terraform output and set as environment variable
set_env_from_terraform() {
    local output_name=$1
    local env_var_name=$2
    local value

    # Use -raw to get the value without quotes
    value=$(terraform output -raw "$output_name")
    
    if [ $? -eq 0 ]; then
        export "$env_var_name"="$value"
        echo "Set $env_var_name=$value"
    else
        echo "Failed to get Terraform output for $output_name" >&2
    fi
}

# Ensure we're in the correct directory
if [ ! -f "main.tf" ]; then
    echo "Error: main.tf not found. Please run this script from your Terraform project directory." >&2
    exit 1
fi

# # Set environment variables from Terraform outputs
# set_env_from_terraform "openai_api_type" "OPENAI_API_TYPE"
# set_env_from_terraform "openai_api_base" "OPENAI_API_BASE"
# set_env_from_terraform "openai_api_version" "OPENAI_API_VERSION"
# set_env_from_terraform "openai_api_key" "OPENAI_API_KEY"
# set_env_from_terraform "openai_deployment_name" "OPENAI_DEPLOYMENT_NAME"

# echo "Environment variables have been set based on Terraform outputs."
# echo "You can now run your Azure Function or other scripts that require these environment variables."

curl --request POST http://localhost:7071/api/MyHttpTrigger --data '{"query":"Azure Rocks"}'