####################################################################################
# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
####################################################################################
import os
import logging

import data_analytics_agent.utils.rest_api.rest_api_helper as rest_api_helper 


logger = logging.getLogger(__name__)


async def get_business_glossaries() -> dict: 
    """
    Lists all Dataplex business glossaries in the configured region.

    Returns:
        dict: A dictionary containing the status and the list of business glossaries.
        {
            "status": "success" or "failed",
            "tool_name": "get_business_glossaries",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "glossaries": [ ... list of glossary objects ... ]
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")
    messages = []

    # The URL to list all business glossaries in the specified project and region.
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{business_glossary_region}/glossaries"

    try:
        # Call the REST API to get the list of all existing business glossaries
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) 
        messages.append("Successfully retrieved list of all business glossaries from the API.")

        # Extract the list of glossaries
        glossaries = json_result.get("glossaries", [])

        messages.append(f"Found {len(glossaries)} business glossaries.")

        # Create the final results payload with the list
        filtered_results = {"glossaries": glossaries}

        return {
            "status": "success",
            "tool_name": "get_business_glossaries",
            "query": None,
            "messages": messages,
            "results": filtered_results
        }
    except Exception as e:
        messages.append(f"An error occurred while listing business glossaries: {e}")
        return {
            "status": "failed",
            "tool_name": "get_business_glossaries",
            "query": None,
            "messages": messages,
            "results": None
        }
    

async def exists_business_glossary(glossary_id: str) -> dict: 
    """
    Checks if a Dataplex business glossary already exists by checking the full list.

    Args:
        glossary_id (str): The ID of the business glossary to retrieve

    Returns:
        dict: A dictionary containing the status and results of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "exists_business_glossary",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "exists": True # or False
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")

    # Call the dedicated function to list all glossaries
    list_result = await get_business_glossaries() 
    messages = list_result.get("messages", [])

    # If listing glossaries failed, propagate the failure
    if list_result["status"] == "failed":
        return {
            "status": "failed",
            "tool_name": "exists_business_glossary_scan", 
            "query": None,
            "messages": messages,
            "results": None
        }

    try:
        glossary_exists = False
        json_payload = list_result.get("results", {})
        full_glossary_name_to_find = f"projects/{project_id}/locations/{business_glossary_region}/glossaries/{glossary_id}"

        # Loop through the list of glossaries from the results
        for item in json_payload.get("glossaries", []):
            if item.get("name") == full_glossary_name_to_find:
                glossary_exists = True
                messages.append(f"Found matching glossary: '{glossary_id}'.")
                break

        if not glossary_exists:
            messages.append(f"Glossary '{glossary_id}' does not exist.")

        return {
            "status": "success",
            "tool_name": "exists_business_glossary",
            "query": None,
            "messages": messages,
            "results": {"exists": glossary_exists}
        }
    except Exception as e: # Catch potential errors while processing the list
        messages.append(f"An unexpected error occurred while processing glossary list: {e}")
        return {
            "status": "failed",
            "tool_name": "exists_business_glossary",
            "query": None,
            "messages": messages,
            "results": None
        }


async def create_business_glossary(glossary_id: str, display_name: str, description: str = "") -> dict: 
    """
    Creates a new Dataplex business glossary if it does not already exist.

    Args:
        glossary_id (str): The short name/ID for the new business glossary.
        display_name (str): The user-friendly display name for the glossary.
        description (str, optional): A brief description for the glossary. Defaults to "".

    Returns:
        dict: A dictionary containing the status and results of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "create_business_glossary",
            "query": None,
            "messages": ["List of messages during processing"],
            "exists" : True/False (True if created),
            "results": { ... response from the API call or creation status ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")
    messages = []

    # First, check if the business glossary already exists.
    list_result = await get_business_glossaries() 
    messages.extend(list_result.get("messages", [])) # Append messages from the list operation

    if list_result["status"] == "failed":
        return {
            "status": "failed",
            "tool_name": "create_business_glossary",
            "query": None,
            "messages": messages,
            "exists" : False,
            "results": None
        }

    glossaries = list_result.get("results", {}).get("glossaries", [])
    glossary_exists = False
    full_glossary_name_to_find = f"projects/{project_id}/locations/{business_glossary_region}/glossaries/{glossary_id}"

    for glossary in glossaries:
        if glossary.get("name") == full_glossary_name_to_find:
            glossary_exists = True
            break

    if glossary_exists:
        messages.append(f"Business glossary '{glossary_id}' already exists.")
        return {
            "status": "success",
            "tool_name": "create_business_glossary",
            "query": None,
            "messages": messages,
            "exists" : True,
            "results": {"name": full_glossary_name_to_find }
        }

    # If the glossary does not exist, proceed with creation.
    messages.append(f"Creating business glossary '{glossary_id}'.")

    # API endpoint to create a glossary. The glossary ID is passed as a query parameter.
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{business_glossary_region}/glossaries?glossaryId={glossary_id}"

    request_body = {
        "displayName": display_name,
        "description": description
    }

    try:
        json_result = await rest_api_helper.rest_api_helper(url, "POST", request_body) 

        messages.append(f"Successfully created business glossary '{glossary_id}'.")

        return {
            "status": "success",
            "tool_name": "create_business_glossary",
            "query": None,
            "messages": messages,
            "exists" : False,
            "results": json_result
        }

    except Exception as e:
        messages.append(f"An error occurred while creating the business glossary: {e}")
        return {
            "status": "failed",
            "tool_name": "create_business_glossary",
            "query": None,
            "messages": messages,
            "exists" : False,
            "results": None
        }
    
    
async def get_business_glossary(glossary_id: str) -> dict: 
    """
    Gets a single Dataplex business glossary in the configured region.

    Args:
        glossary_id (str): The ID of the business glossary to retrieve.

    Returns:
        dict: A dictionary containing the status and the details of the business glossary.
        {
            "status": "success" or "failed",
            "tool_name": "get_business_glossary",
            "query": None,
            "messages": ["List of messages during processing"],
            "exists" : True/False (True if exists),
            "results": { ... glossary object details ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")
    messages = []
    # The URL to get a specific business glossary
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{business_glossary_region}/glossaries/{glossary_id}"

    try:
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) 
        messages.append(f"Successfully retrieved details for business glossary '{glossary_id}' from the API.")

        return {
            "status": "success",
            "tool_name": "get_business_glossary",
            "query": None,
            "messages": messages,
            "exists": True,
            "results": json_result
        }
    except RuntimeError as e: 
        error_message = str(e)

        if "HTTP Status: 404" in error_message:
            messages.append(f"Business Glossary '{glossary_id}' not found.")
            return {
                "status": "success", # Status is success because it wasn't found
                "tool_name": "get_business_glossary",
                "query": None,
                "messages": messages,
                "exists": False,
                "results": None
            }
        else:
            # Handle other potential RuntimeErrors from the helper
            messages.append(f"An API error occurred while getting business glossary '{glossary_id}': {error_message}")
            return {
                "status": "failed",
                "tool_name": "get_business_glossary",
                "query": None,
                "messages": messages,
                "exists": False,
                "results": None
            }


async def delete_business_glossary(glossary_id: str) -> dict: 
    """
    Deletes a specific Dataplex Business Glossary.
    Note: A glossary must be empty (contain no terms or categories) to be deleted.

    Args:
        glossary_id (str): The ID of the glossary to delete.

    Returns:
        dict: A dictionary indicating the deletion status.
        {
            "status": "success" or "failed",
            "tool_name": "delete_business_glossary",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "deleted": True/False,
                "glossary_id": str,
                "error": str (if failed)
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")
    messages = []

    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{business_glossary_region}/glossaries/{glossary_id}"

    try:
        messages.append(f"Attempting to delete business glossary '{glossary_id}'.")
        # Dataplex API for deleting glossaries typically returns an empty 200 OK or a long-running operation.
        # rest_api_helper should handle the HTTP status and raise exceptions for errors.
        _ = await rest_api_helper.rest_api_helper(url, "DELETE", None) 
        messages.append(f"Successfully deleted business glossary '{glossary_id}'.")
        return {
            "status": "success",
            "tool_name": "delete_business_glossary",
            "query": None,
            "messages": messages,
            "results": {"deleted": True, "glossary_id": glossary_id}
        }
    except Exception as e:
        messages.append(f"Failed to delete business glossary '{glossary_id}': {e}")
        return {
            "status": "failed",
            "tool_name": "delete_business_glossary",
            "query": None,
            "messages": messages,
            "results": {"deleted": False, "glossary_id": glossary_id, "error": str(e)}
        }


async def get_business_glossary_categories(glossary_id: str) -> dict: 
    """
    Lists all categories within a specified Dataplex business glossary.

    Args:
        glossary_id (str): The ID of the parent business glossary.

    Returns:
        dict: A dictionary containing the status and the list of categories.
        {
            "status": "success" or "failed",
            "tool_name": "get_business_glossary_categories",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "categories": [ ... list of category objects ... ]
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")
    messages = []
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{business_glossary_region}/glossaries/{glossary_id}/categories"

    try:
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) 
        messages.append(f"Successfully retrieved list of categories for glossary '{glossary_id}' from the API.")

        categories = json_result.get("categories", [])
        messages.append(f"Found {len(categories)} categories in glossary '{glossary_id}'.")

        return {
            "status": "success",
            "tool_name": "get_business_glossary_categories",
            "query": None,
            "messages": messages,
            "results": {"categories": categories}
        }
    except Exception as e:
        messages.append(f"An error occurred while listing categories for glossary '{glossary_id}': {e}")
        return {
            "status": "failed",
            "tool_name": "get_business_glossary_categories",
            "query": None,
            "messages": messages,
            "results": None
        }


async def get_business_glossary_category(glossary_id: str, category_id: str) -> dict: 
    """
    Gets a single Dataplex business glossary category within a specified glossary.

    Args:
        glossary_id (str): The ID of the parent business glossary.
        category_id (str): The ID of the category to retrieve.

    Returns:
        dict: A dictionary containing the status and the details of the category.
        {
            "status": "success" or "failed",
            "tool_name": "get_business_glossary_category",
            "query": None,
            "messages": ["List of messages during processing"],
            "exists": True/False (True if exists),
            "results": { ... category object details ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")
    messages = []
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{business_glossary_region}/glossaries/{glossary_id}/categories/{category_id}"

    try:
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) 
        messages.append(f"Successfully retrieved details for category '{category_id}' in glossary '{glossary_id}' from the API.")

        return {
            "status": "success",
            "tool_name": "get_business_glossary_category",
            "query": None,
            "messages": messages,
            "exists": True,
            "results": json_result
        }
    
    except RuntimeError as e: 
        error_message = str(e)

        if "HTTP Status: 404" in error_message:
            messages.append(f"Category '{category_id}' not found in glossary '{glossary_id}'.")
            return {
                "status": "success", # Status is success because it wasn't found
                "tool_name": "get_business_glossary_category",
                "query": None,
                "messages": messages,
                "exists": False,
                "results": None
            }
        else:
            # Handle other potential RuntimeErrors from the helper
            messages.append(f"An API error occurred while getting category '{category_id}' in glossary '{glossary_id}': {error_message}")
            return {
                "status": "failed",
                "tool_name": "get_business_glossary_category",
                "query": None,
                "messages": messages,
                "exists": False,
                "results": None
            }
        
    except Exception as e:
        # Catch any other unexpected errors (e.g., programming errors)
        messages.append(f"An unexpected system error occurred: {e}")
        return {
            "status": "failed",
            "tool_name": "get_business_glossary_category",
            "query": None,
            "messages": messages,
            "exists": False,
            "results": None
        }


async def create_business_glossary_category(glossary_id: str, category_id: str, display_name: str, description: str = "") -> dict: 
    """
    Creates a new Dataplex business glossary category if it does not already exist.

    Args:
        glossary_id (str): The ID of the parent business glossary.
        category_id (str): The short name/ID for the new category.
        display_name (str): The user-friendly display name for the category.
        description (str, optional): A brief description for the category. Defaults to "".

    Returns:
        dict: A dictionary containing the status and results of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "create_business_glossary_category",
            "query": None,
            "messages": ["List of messages during processing"],
            "exists" : True / False (set to true if it already exists)
            "results": { ... response from the API call or creation status ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")
    messages = []

    # First, check if the category already exists.
    existence_check = await get_business_glossary_category(glossary_id, category_id) 
    messages.extend(existence_check.get("messages", [])) # Append messages from the sub-tool call

    if existence_check["status"] == "success":
        if existence_check["exists"] == True:
            # Category found, so it already exists.
            full_category_name = existence_check["results"].get("name")
            messages.append(f"Business glossary category '{category_id}' already exists in glossary '{glossary_id}'.")
            return {
                "status": "success",
                "tool_name": "create_business_glossary_category",
                "query": None,
                "messages": messages,
                "exists" : True,
                "results": { "name": full_category_name }
            }
    else:
        # Any other type of failure during the existence check is an actual problem.
        messages.append(f"An unexpected error occurred during the existence check for category '{category_id}'.")
        return {
            "status": "failed",
            "tool_name": "create_business_glossary_category",
            "query": None,
            "messages": messages,
            "exists" : False,
            "results": None
        }

    # If we reached here, the category does not exist, and we need to create it.
    messages.append(f"Attempting to create business glossary category '{category_id}' in glossary '{glossary_id}'.")

    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{business_glossary_region}/glossaries/{glossary_id}/categories?categoryId={category_id}"
    parent_glossary_name = f"projects/{project_id}/locations/{business_glossary_region}/glossaries/{glossary_id}"

    request_body = {
        "displayName": display_name,
        "description": description,
        "parent": parent_glossary_name
    }

    try:
        json_result = await rest_api_helper.rest_api_helper(url, "POST", request_body) 

        messages.append(f"Successfully created business glossary category '{category_id}' in glossary '{glossary_id}'.")

        return {
            "status": "success",
            "tool_name": "create_business_glossary_category",
            "query": None,
            "messages": messages,
            "exists" : False,
            "results": json_result
        }

    except Exception as e:
        messages.append(f"An error occurred while creating the business glossary category '{category_id}': {e}")
        return {
            "status": "failed",
            "tool_name": "create_business_glossary_category",
            "query": None,
            "messages": messages,
            "exists" : False,
            "results": None
        }


async def delete_business_glossary_category(glossary_id: str, category_id: str) -> dict: 
    """
    Deletes a specific Dataplex Business Glossary category.
    Note: A category must be empty (contain no terms or nested categories) to be deleted.

    Args:
        glossary_id (str): The ID of the parent business glossary.
        category_id (str): The ID of the category to delete.

    Returns:
        dict: A dictionary indicating the deletion status.
        {
            "status": "success" or "failed",
            "tool_name": "delete_business_glossary_category",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "deleted": True/False,
                "category_id": str,
                "error": str (if failed)
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")
    messages = []

    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{business_glossary_region}/glossaries/{glossary_id}/categories/{category_id}"

    try:
        messages.append(f"Attempting to delete category '{category_id}' from glossary '{glossary_id}'.")
        _ = await rest_api_helper.rest_api_helper(url, "DELETE", None) 
        messages.append(f"Successfully deleted category '{category_id}' from glossary '{glossary_id}'.")
        return {
            "status": "success",
            "tool_name": "delete_business_glossary_category",
            "query": None,
            "messages": messages,
            "results": {"deleted": True, "category_id": category_id, "glossary_id": glossary_id}
        }
    except Exception as e:
        messages.append(f"Failed to delete category '{category_id}' from glossary '{glossary_id}': {e}")
        return {
            "status": "failed",
            "tool_name": "delete_business_glossary_category",
            "query": None,
            "messages": messages,
            "results": {"deleted": False, "category_id": category_id, "glossary_id": glossary_id, "error": str(e)}
        }


async def get_business_glossary_term(glossary_id: str, term_id: str) -> dict: 
    """
    Gets a single Dataplex business glossary term.

    Args:
        glossary_id (str): The ID of the parent business glossary.
        term_id (str): The ID of the term to retrieve.

    Returns:
        dict: A dictionary containing the status and the details of the term.
        {
            "status": "success" or "failed",
            "tool_name": "get_business_glossary_term",
            "query": None,
            "messages": ["List of messages during processing"],
            "exists" : True/False (True if exists),
            "results": { ... term object details ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")
    messages = []
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{business_glossary_region}/glossaries/{glossary_id}/terms/{term_id}"

    try:
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) 
        messages.append(f"Successfully retrieved details for term '{term_id}' in glossary '{glossary_id}' from the API.")
        return {
            "status": "success",
            "tool_name": "get_business_glossary_term",
            "query": None,
            "messages": messages,
            "exists": True,
            "results": json_result
        }
    except RuntimeError as e: 
        error_message = str(e)

        if "HTTP Status: 404" in error_message:
            messages.append(f"Term '{term_id}' not found.")
            return {
                "status": "success", # Status is success because it wasn't found
                "tool_name": "get_business_glossary_term",
                "query": None,
                "messages": messages,
                "exists": False,
                "results": None
            }
        else:
            # Handle other potential RuntimeErrors from the helper
            messages.append(f"An API error occurred while getting term '{term_id}': {error_message}")
            return {
                "status": "failed",
                "tool_name": "get_business_glossary_term",
                "query": None,
                "messages": messages,
                "exists": False,
                "results": None
            }


async def list_business_glossary_terms(glossary_id: str) -> dict: 
    """
    Lists all terms within a specified Dataplex business glossary.

    Args:
        glossary_id (str): The ID of the parent business glossary.

    Returns:
        dict: A dictionary containing the status and the list of terms.
        {
            "status": "success" or "failed",
            "tool_name": "list_business_glossary_terms",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "terms": [ ... list of term objects ... ]
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")
    messages = []
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{business_glossary_region}/glossaries/{glossary_id}/terms?pageSize=1000"

    try:
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) 
        messages.append(f"Successfully retrieved list of terms for glossary '{glossary_id}' from the API.")

        terms = json_result.get("terms", [])
        messages.append(f"Found {len(terms)} terms in glossary '{glossary_id}'.")

        return {
            "status": "success",
            "tool_name": "list_business_glossary_terms",
            "query": None,
            "messages": messages,
            "results": {"terms": terms}
        }
    except Exception as e:
        messages.append(f"An error occurred while listing terms for glossary '{glossary_id}': {e}")
        return {
            "status": "failed",
            "tool_name": "list_business_glossary_terms",
            "query": None,
            "messages": messages,
            "results": None
        }


async def create_business_glossary_term( 
    glossary_id: str,
    term_id: str,
    display_name: str,
    description: str = "",
    parent_category_id: str = ""
) -> dict:
    """
    Creates a new Dataplex business glossary term if it does not already exist.
    The term can be created directly under a glossary or under a specific category.

    Args:
        glossary_id (str): The ID of the parent business glossary.
        term_id (str): The short name/ID for the new term.
        display_name (str): The user-friendly display name for the term.
        description (str, optional): A brief description for the term. Defaults to "".
        parent_category_id (str, optional): The ID of the parent category if the term
                                             should be nested. Defaults to empty string (term under glossary).

    Returns:
        dict: A dictionary containing the status and results of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "create_business_glossary_term",
            "query": None,
            "messages": ["List of messages during processing"],
            "exists": True/False (True if created)
            "results": { ... response from the API call or creation status ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")
    messages = []

    # First, check if the term already exists.
    term_id = term_id.strip()
    existence_check = await get_business_glossary_term(glossary_id, term_id) 
    messages.extend(existence_check.get("messages", []))

    if existence_check["status"] == "success":
        if existence_check["exists"] == True:
            # Term found, so it already exists.
            full_term_name = existence_check["results"].get("name")
            messages.append(f"Business glossary term '{term_id}' already exists in glossary '{glossary_id}'.")
            return {
                "status": "success",
                "tool_name": "create_business_glossary_term",
                "query": None,
                "messages": messages,
                "exists" : True,
                "results": {"name": full_term_name }
        }
    else:
        # Any other type of failure during the existence check is an actual problem.
        messages.append(f"An unexpected error occurred during the existence check for term '{term_id}'.")
        return {
            "status": "failed",
            "tool_name": "create_business_glossary_term",
            "query": None,
            "messages": messages,
            "exists" : False,
            "results": None
        }

    # If we reached here, the term does not exist, and we need to create it.
    messages.append(f"Attempting to create business glossary term '{term_id}' in glossary '{glossary_id}'.")

    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{business_glossary_region}/glossaries/{glossary_id}/terms?termId={term_id}"

    # Construct the parent resource name based on whether a category is provided
    if parent_category_id is not "":
        parent_resource = f"projects/{project_id}/locations/{business_glossary_region}/glossaries/{glossary_id}/categories/{parent_category_id}"
        messages.append(f"Term will be nested under category: '{parent_category_id}'.")
    else:
        parent_resource = f"projects/{project_id}/locations/{business_glossary_region}/glossaries/{glossary_id}"
        messages.append("Term will be created directly under the glossary.")


    request_body = {
        "displayName": display_name,
        "description": description,
        "parent": parent_resource
    }

    try:
        json_result = await rest_api_helper.rest_api_helper(url, "POST", request_body) 

        messages.append(f"Successfully created business glossary term '{term_id}'.")

        return {
            "status": "success",
            "tool_name": "create_business_glossary_term",
            "query": None,
            "messages": messages,
            "exists" : False,
            "results": json_result
        }

    except Exception as e:
        messages.append(f"An error occurred while creating the business glossary term '{term_id}': {e}")
        return {
            "status": "failed",
            "tool_name": "create_business_glossary_term",
            "query": None,
            "messages": messages,
            "exists" : False,
            "results": None
        }


async def update_business_glossary_term( 
    glossary_id: str,
    term_id: str,
    display_name: str, 
    description: str
) -> dict:
    """
    Updates an existing Dataplex business glossary term.
    Only provided fields (displayName, description) will be updated.

    Args:
        glossary_id (str): The ID of the parent business glossary.
        term_id (str): The ID of the term to update.
        display_name (str): The new user-friendly display name for the term.
        description (str): The new brief description for the term.

    Returns:
        dict: A dictionary containing the status and results of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "update_business_glossary_term",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": { ... response from the API call ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")
    messages = []
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{business_glossary_region}/glossaries/{glossary_id}/terms/{term_id}"

    update_mask_fields = []
    request_body = {}

    if display_name is not None:
        request_body["displayName"] = display_name
        update_mask_fields.append("displayName")
    if description is not None:
        request_body["description"] = description
        update_mask_fields.append("description")

    if not update_mask_fields:
        messages.append("No fields provided for update. Skipping update operation.")
        return {
            "status": "success",
            "tool_name": "update_business_glossary_term",
            "query": None,
            "messages": messages,
            "results": {"updated": False, "reason": "No fields to update"}
        }

    update_mask = ",".join(update_mask_fields)
    url_with_mask = f"{url}?update_mask={update_mask}"

    messages.append(f"Attempting to update business glossary term '{term_id}' with fields: {update_mask_fields}.")

    try:
        json_result = await rest_api_helper.rest_api_helper(url_with_mask, "PATCH", request_body) 
        messages.append(f"Successfully updated business glossary term '{term_id}'.")
        return {
            "status": "success",
            "tool_name": "update_business_glossary_term",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while updating the business glossary term '{term_id}': {e}")
        return {
            "status": "failed",
            "tool_name": "update_business_glossary_term",
            "query": None,
            "messages": messages,
            "results": None
        }


async def delete_business_glossary_term(glossary_id: str, term_id: str) -> dict: 
    """
    Deletes a specific Dataplex Business Glossary term.

    Args:
        glossary_id (str): The ID of the parent business glossary.
        term_id (str): The ID of the term to delete.

    Returns:
        dict: A dictionary indicating the deletion status.
        {
            "status": "success" or "failed",
            "tool_name": "delete_business_glossary_term",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "deleted": True/False,
                "term_id": str,
                "error": str (if failed)
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")
    messages = []

    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{business_glossary_region}/glossaries/{glossary_id}/terms/{term_id}"

    try:
        messages.append(f"Attempting to delete term '{term_id}' from glossary '{glossary_id}'.")
        _ = await rest_api_helper.rest_api_helper(url, "DELETE", None) 
        messages.append(f"Successfully deleted term '{term_id}' from glossary '{glossary_id}'.")
        return {
            "status": "success",
            "tool_name": "delete_business_glossary_term",
            "query": None,
            "messages": messages,
            "results": {"deleted": True, "term_id": term_id, "glossary_id": glossary_id}
        }
    except Exception as e:
        messages.append(f"Failed to delete term '{term_id}' from glossary '{glossary_id}': {e}")
        return {
            "status": "failed",
            "tool_name": "delete_business_glossary_term",
            "query": None,
            "messages": messages,
            "results": {"deleted": False, "term_id": term_id, "glossary_id": glossary_id, "error": str(e)}
        }