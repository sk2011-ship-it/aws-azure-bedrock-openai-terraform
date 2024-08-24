#!/bin/bash

# Extract keys from Terraform output
OPENAI_API_KEY=$(terraform output -raw openai_api_key)
AZURE_SEARCH_KEY=$(terraform output -raw azure_search_primary_key)

# Construct the JSON payload
JSON_PAYLOAD=$(cat << EOF
{
  "query": "name of candidate",
  "openai_api_key": "$OPENAI_API_KEY",
  "azure_search_key": "$AZURE_SEARCH_KEY"
}
EOF
)

# Send the POST request
curl --request POST \
     --url http://localhost:7071/api/MyHttpTrigger \
     --header 'Content-Type: application/json' \
     --data "$JSON_PAYLOAD"