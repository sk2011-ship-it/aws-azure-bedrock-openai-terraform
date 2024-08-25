#!/bin/bash

# Extract keys from Terraform output
OPENAI_API_KEY=$(terraform output -raw openai_api_key)
AZURE_SEARCH_KEY=$(terraform output -raw azure_search_primary_key)
LANGUAGE_KEY=$(terraform output -raw language_key)
LANGUAGE_ENDPOINT=$(terraform output -raw language_endpoint)

# Construct the JSON payload
JSON_PAYLOAD=$(cat << EOF
{
  "query": "name of candidate",
  "openai_api_key": "$OPENAI_API_KEY",
  "azure_search_key": "$AZURE_SEARCH_KEY",
  "language_key": "$LANGUAGE_KEY",
  "language_endpoint": "$LANGUAGE_ENDPOINT"
}
EOF
)

# Send the POST request
curl --request POST \
     --url http://localhost:7071/api/MyHttpTrigger \
     --header 'Content-Type: application/json' \
     --data "$JSON_PAYLOAD"