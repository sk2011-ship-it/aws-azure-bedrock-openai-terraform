import logging
import azure.functions as func
import os
import openai
import requests
import json


def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    try:
        req_body = req.get_json()
    except ValueError:
        return func.HttpResponse("Invalid request body", status_code=400)

    query = req_body.get('query')
    if not query:
        return func.HttpResponse("No query provided", status_code=400)

    # Check for API keys in request body, fallback to environment variables
    openai_api_key = req_body.get('openai_api_key') or os.getenv("OPENAI_API_KEY")
    azure_search_key = req_body.get('azure_search_key') or os.getenv("AZURE_SEARCH_KEY")

    if not openai_api_key:
        return func.HttpResponse("OpenAI API key not provided", status_code=400)

    # Set up Azure OpenAI
    openai.api_type = "azure"
    openai.api_base = os.getenv("OPENAI_API_BASE", "https://my-openai-service.openai.azure.com/")
    openai.api_version = "2023-05-15"
    openai.api_key = openai_api_key

    # Azure Search settings
    search_service_name = os.getenv("AZURE_SEARCH_SERVICE", "saurabh-ai-search-service")
    search_index_name = os.getenv("AZURE_SEARCH_INDEX", "my-search-index")
    search_api_version = "2024-07-01"

    try:
        # Perform search using REST API
        search_url = f"https://{search_service_name}.search.windows.net/indexes/{search_index_name}/docs/search?api-version={search_api_version}"
        headers = {
            "Content-Type": "application/json",
            "api-key": azure_search_key
        }
        search_body = {
            "search": query,
            "top": 3,
            "select": "content"
        }
        search_response = requests.post(search_url, headers=headers, json=search_body)
        search_response.raise_for_status()  # Raise an exception for bad status codes
        search_results = search_response.json()

        # Extract content from search results
        context = "\n".join([doc['content'] for doc in search_results.get('value', [])])
        print("got context ", context)

        # Prepare prompt for GPT-4o-mini
        prompt = f"Based on the following context, answer the query: '{query}'\n\nContext:\n{context}"

        # Call Azure OpenAI API
        try:
            response = openai.ChatCompletion.create(
                engine="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You are a helpful assistant. Use the provided context to answer the user's query."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=150
            )
            generated_text = response.choices[0].message['content'].strip()
        except openai.error.AuthenticationError as e:
            logging.error(f"OpenAI API Authentication Error: {str(e)}")
            return func.HttpResponse(
                "An authentication error occurred with the OpenAI API. Please check your API key and endpoint.",
                status_code=500
            )
        except openai.error.APIError as e:
            logging.error(f"OpenAI API Error: {str(e)}")
            return func.HttpResponse(
                f"An error occurred while calling the OpenAI API: {str(e)}",
                status_code=500
            )

        return func.HttpResponse(f"Query: {query}\n\nResponse: {generated_text}")

    except requests.exceptions.RequestException as e:
        logging.error(f"Error calling Azure Search API: {str(e)}")
        return func.HttpResponse(
            f"An error occurred while searching: {str(e)}",
            status_code=500
        )
    except Exception as e:
        logging.error(f"Error processing request: {str(e)}")
        return func.HttpResponse(
            f"An error occurred while processing your request: {str(e)}",
            status_code=500
        )
