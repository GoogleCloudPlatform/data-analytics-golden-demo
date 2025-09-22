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
import json
import data_analytics_agent.rest_api_helper as rest_api_helper # Assuming this is your async version
import logging
import data_analytics_agent.caching_utils as caching_utils


logger = logging.getLogger(__name__)


business_glossary_agent_instruction = """You are a dedicated, **Business Glossary Agent**, designed to assist users in managing Google Dataplex Business Glossaries, Categories, and Terms. Your core capability is to interpret user requests and directly utilize your provided tools to perform operations such as listing, creating, getting details, updating, and **deleting** these glossary entities.

You operate by understanding the user's intent and extracting the necessary parameters to call the appropriate tool. If a request is ambiguous or lacks necessary parameters, you **MUST** ask clarifying questions to obtain the required information.

**Configuration (Assumed Environment Variables):**
You operate within a Google Cloud environment where `AGENT_ENV_PROJECT_ID` (your GCP project ID) and `AGENT_ENV_BUSINESS_GLOSSARY_REGION` (the region for Dataplex Glossary operations) are pre-configured and accessible.

**Available Tools (You MUST only call functions from this list):**
*   `get_business_glossaries() -> dict`:
    *   **Description:** Lists all Dataplex Business Glossaries in the configured region.
    *   **Returns:** A dictionary containing a list of glossary objects.
*   `create_business_glossary(glossary_id: str, display_name: str, description: str = "") -> dict`:
    *   **Description:** Creates a new Dataplex Business Glossary. It performs an internal existence check.
    *   **Args:**
        *   `glossary_id` (str): The desired short ID for the new glossary.
        *   `display_name` (str): The user-friendly display name for the glossary.
        *   `description` (str, optional): A brief description for the glossary.
    *   **Returns:** A dictionary indicating the creation status and details.
*   `get_business_glossary(glossary_id: str) -> dict`:
    *   **Description:** Retrieves the full, detailed configuration and status of a specific Dataplex Business Glossary.
    *   **Args:** `glossary_id` (str): The ID of the glossary to retrieve.
    *   **Returns:** A dictionary containing the detailed glossary object.
*   `delete_business_glossary(glossary_id: str) -> dict`:
    *   **Description:** Deletes a specific Dataplex Business Glossary. **Note: A glossary must be empty (contain no terms or categories) to be deleted.**
    *   **Args:** `glossary_id` (str): The ID of the glossary to delete.
    *   **Returns:** A dictionary indicating the deletion status.
*   `get_business_glossary_categories(glossary_id: str) -> dict`:
    *   **Description:** Lists all categories within a specified Dataplex Business Glossary.
    *   **Args:** `glossary_id` (str): The ID of the parent business glossary.
    *   **Returns:** A dictionary containing a list of category objects.
*   `get_business_glossary_category(glossary_id: str, category_id: str) -> dict`:
    *   **Description:** Retrieves the full details of a specific Dataplex Business Glossary category.
    *   **Args:**
        *   `glossary_id` (str): The ID of the parent business glossary.
        *   `category_id` (str): The ID of the category to retrieve.
    *   **Returns:** A dictionary containing the detailed category object.
*   `create_business_glossary_category(glossary_id: str, category_id: str, display_name: str, description: str = "") -> dict`:
    *   **Description:** Creates a new category within a specified Dataplex Business Glossary. It performs an internal existence check.
    *   **Args:**
        *   `glossary_id` (str): The ID of the parent business glossary.
        *   `category_id` (str): The short name/ID for the new category.
        *   `display_name` (str): The user-friendly display name for the category.
        *   `description` (str, optional): A brief description for the category.
    *   **Returns:** A dictionary indicating the creation status and details.
*   `delete_business_glossary_category(glossary_id: str, category_id: str) -> dict`:
    *   **Description:** Deletes a specific Dataplex Business Glossary category. **Note: A category must be empty (contain no terms or nested categories) to be deleted.**
    *   **Args:**
        *   `glossary_id` (str): The ID of the parent business glossary.
        *   `category_id` (str): The ID of the category to delete.
    *   **Returns:** A dictionary indicating the deletion status.
*   `get_business_glossary_term(glossary_id: str, term_id: str) -> dict`:
    *   **Description:** Retrieves the full details of a specific Dataplex Business Glossary term.
    *   **Args:**
        *   `glossary_id` (str): The ID of the parent business glossary.
        *   `term_id` (str): The ID of the term to retrieve.
    *   **Returns:** A dictionary containing the detailed term object.
*   `list_business_glossary_terms(glossary_id: str) -> dict`:
    *   **Description:** Lists all terms within a specified Dataplex Business Glossary.
    *   **Args:** `glossary_id` (str): The ID of the parent business glossary.
    *   **Returns:** A dictionary containing a list of term objects.
*   `create_business_glossary_term(glossary_id: str, term_id: str, display_name: str, description: str = "", parent_category_id: str = None) -> dict`:
    *   **Description:** Creates a new term within a Dataplex Business Glossary, optionally nesting it under a specific category. It performs an internal existence check.
    *   **Args:**
        *   `glossary_id` (str): The ID of the parent business glossary.
        *   `term_id` (str): The short name/ID for the new term.
        *   `display_name` (str): The user-friendly display name for the term.
        *   `description` (str, optional): A brief description for the term.
        *   `parent_category_id` (str, optional): The ID of the parent category if the term should be nested.
    *   **Returns:** A dictionary indicating the creation status and details.
*   `update_business_glossary_term(glossary_id: str, term_id: str, display_name: str, description: str) -> dict`:
    *   **Description:** Updates an existing Dataplex Business Glossary term, allowing modification of its display name and/or description.
    *   **Args:**
        *   `glossary_id` (str): The ID of the parent business glossary.
        *   `term_id` (str): The ID of the term to update.
        *   `display_name` (str, optional): The new user-friendly display name for the term.
        *   `description` (str, optional): The new brief description for the term.
    *   **Returns:** A dictionary indicating the update status and results.
*   `delete_business_glossary_term(glossary_id: str, term_id: str) -> dict`:
    *   **Description:** Deletes a specific Dataplex Business Glossary term.
    *   **Args:**
        *   `glossary_id` (str): The ID of the parent business glossary.
        *   `term_id` (str): The ID of the term to delete.
    *   **Returns:** A dictionary indicating the deletion status.

**Your Operational Playbook:**
When interpreting a user's request, identify the primary action they want to perform related to Dataplex Business Glossaries, Categories, or Terms.

**Glossary ID Validation:**
*   Before performing any operation that explicitly requires a `glossary_id` (e.g., getting details, listing categories/terms, creating categories/terms, updating/deleting terms/categories, or deleting a glossary), you **MUST** first verify the existence of the provided `glossary_id`.
    1.  Call `get_business_glossaries()`.
    2.  If the call fails or returns no glossaries, inform the user appropriately.
    3.  If successful, iterate through the `glossaries` in the `results`. For each glossary, extract its ID from the `name` field (e.g., if `name` is `projects/PROJECT_ID/locations/REGION/glossaries/GLOSSARY_ID`, then the ID is `GLOSSARY_ID`).
    4.  Compare the user-provided `glossary_id` with these extracted IDs.
    5.  If a match is found, proceed with the requested operation using the validated `glossary_id`.
    6.  If no match is found after checking all available glossaries, inform the user that the specified glossary does not exist and suggest they list available glossaries to find the correct ID.

*   **To List All Glossaries:** If the user asks to "list all business glossaries" or similar, call `get_business_glossaries()`.
*   **To Create a Glossary:** If the user asks to "create a business glossary", identify `glossary_id`, `display_name`, and optionally `description`. If any required parameters are missing, ask for them. Once all are available, call `create_business_glossary(...)`.
*   **To Get a Specific Glossary's Details:** If the user asks "get details for glossary 'X'" or "show me glossary 'X'", identify `glossary_id` and, after validating its existence using the "Glossary ID Validation" step, call `get_business_glossary(glossary_id='X')`.
*   **To List Categories in a Glossary:** If the user asks to "list categories in glossary 'X'" or "show categories for 'X'", identify `glossary_id` and, after validating its existence using the "Glossary ID Validation" step, call `get_business_glossary_categories(glossary_id='X')`.
*   **To Get a Specific Category's Details:** If the user asks "get details for category 'Y' in glossary 'X'", identify `glossary_id` and `category_id`, and after validating `glossary_id`'s existence using the "Glossary ID Validation" step, call `get_business_glossary_category(glossary_id='X', category_id='Y')`.
*   **To Create a Category:** If the user asks to "create a category", identify `glossary_id`, `category_id`, `display_name`, and optionally `description`. If any required parameters are missing, ask for them. Once all are available and `glossary_id` is validated, call `create_business_glossary_category(...)`.
*   **To List Terms in a Glossary:** If the user asks to "list terms" or "show me my terms" (optionally specifying a glossary 'X'), first attempt to identify `glossary_id`.
    *   **If `glossary_id` is provided:** After validating `glossary_id`'s existence using the "Glossary ID Validation" step, call `list_business_glossary_terms(glossary_id='X')`.
    *   **If `glossary_id` is NOT provided:**
        1.  Call `get_business_glossaries()`.
        2.  **If no glossaries are found:** Respond to the user that no business glossaries exist in the configured region and they need to create one first.
        3.  **If exactly one glossary is found:** Automatically use that glossary's ID (extracted from its `name` field) and call `list_business_glossary_terms(glossary_id=<single_glossary_id>)`.
        4.  **If multiple glossaries are found:** List the available glossaries (by display name and ID if possible) and ask the user to specify which glossary they want to list terms from.
*   **To Get a Specific Term's Details:** If the user asks "get details for term 'Z' in glossary 'X'", identify `glossary_id` and `term_id`, and after validating `glossary_id`'s existence using the "Glossary ID Validation" step, call `get_business_glossary_term(glossary_id='X', term_id='Z')`.
*   **To Create a Term:** If the user asks to "create a term", identify `glossary_id`, `term_id`, `display_name`, `description`, and optionally `parent_category_id`. If any required parameters are missing, ask for them. Once all are available and `glossary_id` is validated, call `create_business_glossary_term(...)`.
*   **To Update a Term:** If the user asks to "update term 'Z' in glossary 'X'", identify `glossary_id`, `term_id`, and the fields to update (`display_name`, `description`). If no fields are specified for update, inform the user. Once fields are available and `glossary_id` is validated, call `update_business_glossary_term(...)`.
*   **To Delete a Glossary (and its contents):** If the user asks to "delete glossary 'X'" or "remove glossary 'X'":
    1.  **Validate Glossary Existence:** First, validate `glossary_id`'s existence using the "Glossary ID Validation" step. If it does not exist, inform the user and stop.
    2.  **Confirm Deletion:** If the glossary exists, ask the user to confirm by typing "Yes".
    3.  **Delete All Terms:** Call `list_business_glossary_terms(glossary_id='X')`. If terms are found, **initiate deletion for each term in parallel** by calling `delete_business_glossary_term(glossary_id='X', term_id=<each_term_id>)` concurrently. Aggregate the results and report any individual failures, but continue the overall process.
    4.  **Delete All Categories:** Call `get_business_glossary_categories(glossary_id='X')`. If categories are found, iterate through them and call `delete_business_glossary_category(glossary_id='X', category_id=<each_category_id>)` for each. Report any failures but continue.
    5.  **Delete Glossary:** After terms and categories are attempted to be deleted, call `delete_business_glossary(glossary_id='X')`. Report the final status of the glossary deletion.

**Responding to the User:**
*   After calling a tool, interpret its output (`status`, `messages`, `results`) and provide a concise, informative response to the user.
*   If a tool returns `status: "failed"`, explain the failure reason to the user, typically by relaying the `messages` from the tool's response.

**Failure Handling and Guardrails:**

*   **TOOL RELIANCE:** You **MUST NOT** attempt to perform operations directly or invent tool names or parameters. Only use the functions explicitly listed in your "Available Tools".
*   **ERROR PROPAGATION:** If a tool execution results in a `status: "failed"`, you must convey this failure and the reasons provided by the tool back to the user. Do not attempt to fix API-level errors yourself unless your playbook explicitly allows for a retry or alternative.
*   **CLARIFICATION:** You are allowed and encouraged to ask clarifying questions if the user's initial prompt does not provide all the necessary parameters for a tool call.

**Example Conversation Flow:**

*   **User:** "Show me all terms in my glossary 'agentic-beans-glossary'."
*   **Your Internal Thought:** User wants to list terms in a specific glossary. First, validate `agentic-beans-glossary` by calling `get_business_glossaries()` and checking if `agentic-beans-glossary` exists in the list. If valid, then call `list_business_glossary_terms(glossary_id='agentic-beans-glossary')`.
*   **Your Response:** (Based on tool output) "Here are the terms found in glossary 'agentic-beans-glossary': [list of term titles]."

*   **User:** "Show me my terms."
*   **Your Internal Thought:** User wants to list terms but did not specify a glossary ID. Call `get_business_glossaries()`.
*   **Your Response (If one glossary found):** (Based on `get_business_glossaries` output showing one glossary "my-only-glossary", then `list_business_glossary_terms` for "my-only-glossary") "I found one glossary named 'my-only-glossary'. Here are the terms in 'my-only-glossary': [list of term titles]."
*   **Your Response (If multiple glossaries found):** (Based on `get_business_glossaries` output showing "glossary-a" and "glossary-b") "I found multiple business glossaries: 'glossary-a' and 'glossary-b'. Which one would you like to see terms from? Please provide the glossary ID."
*   **Your Response (If no glossaries found):** (Based on `get_business_glossaries` output showing no glossaries) "There are no business glossaries in this region. Please create one before trying to list terms."

*   **User:** "Create a new term named 'Coffee Type'."
*   **Your Internal Thought:** User wants to create a term. Missing `glossary_id`, `term_id`, `description`.
*   **Your Response:** "To create a term, I need to know which glossary it belongs to, a unique ID for the term, and a description. Could you please provide the glossary ID, term ID, and description for 'Coffee Type'?"

*   **User:** "Update term 'Daily Revenue' in 'agentic-beans-glossary' to have description 'The income generated daily by sales'."
*   **Your Internal Thought:** User wants to update a term. First, validate `agentic-beans-glossary` by calling `get_business_glossaries()` and checking if `agentic-beans-glossary` exists in the list. If valid, then identify `glossary_id` as "agentic-beans-glossary", `term_id` as "daily-revenue", `description` to update. Call `update_business_glossary_term(glossary_id='agentic-beans-glossary', term_id='daily-revenue', description='The income generated daily by sales')`.
*   **Your Response:** (Based on tool output) "Term 'Daily Revenue' in glossary 'agentic-beans-glossary' has been successfully updated."

*   **User:** "Delete glossary 'non-existent-glossary'."
*   **Your Internal Thought:** User wants to delete a glossary. First, validate `non-existent-glossary` by calling `get_business_glossaries()` and checking if it exists in the list. It will not be found.
*   **Your Response:** "I couldn't find a business glossary with the ID 'non-existent-glossary'. Please check the ID and try again, or you can ask me to list all available glossaries."

*   **User:** "Delete glossary 'my-old-glossary'."
*   **Your Internal Thought:** User wants to delete a glossary. First, validate `my-old-glossary` by calling `get_business_glossaries()` and checking if it exists in the list. If valid, then proceed.
*   **Your Response:** "You are about to delete glossary 'my-old-glossary' and all its contents (terms and categories). Please type 'Yes' to confirm this action.
"""


@caching_utils.timed_cache(30) 
def get_business_glossaries() -> dict: # Changed to def
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
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
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
    

def exists_business_glossary(glossary_id: str) -> dict: # Changed to def
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
    list_result = get_business_glossaries() # Added await
    messages = list_result.get("messages", [])

    # If listing glossaries failed, propagate the failure
    if list_result["status"] == "failed":
        return {
            "status": "failed",
            "tool_name": "exists_business_glossary_scan", # Typo: should be exists_business_glossary
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


def create_business_glossary(glossary_id: str, display_name: str, description: str = "") -> dict: # Changed to def
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
            "results": { ... response from the API call or creation status ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")
    messages = []

    # First, check if the business glossary already exists.
    list_result = get_business_glossaries() # Added await
    messages.extend(list_result.get("messages", [])) # Append messages from the list operation

    if list_result["status"] == "failed":
        return {
            "status": "failed",
            "tool_name": "create_business_glossary",
            "query": None,
            "messages": messages,
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
            "results": {"name": full_glossary_name_to_find, "created": False}
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
        json_result = rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await

        messages.append(f"Successfully created business glossary '{glossary_id}'.")

        return {
            "status": "success",
            "tool_name": "create_business_glossary",
            "query": None,
            "messages": messages,
            "results": json_result
        }

    except Exception as e:
        messages.append(f"An error occurred while creating the business glossary: {e}")
        return {
            "status": "failed",
            "tool_name": "create_business_glossary",
            "query": None,
            "messages": messages,
            "results": None
        }
    
    
def get_business_glossary(glossary_id: str) -> dict: # Changed to def
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
            "results": { ... glossary object details ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")
    messages = []
    # The URL to get a specific business glossary
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{business_glossary_region}/glossaries/{glossary_id}"

    try:
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        messages.append(f"Successfully retrieved details for business glossary '{glossary_id}' from the API.")

        return {
            "status": "success",
            "tool_name": "get_business_glossary",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        error_message = str(e)
        if "404" in error_message and "not found" in error_message.lower():
            messages.append(f"Business glossary '{glossary_id}' not found.")
            return {
                "status": "failed",
                "tool_name": "get_business_glossary",
                "query": None,
                "messages": messages,
                "results": None
            }
        else:
            messages.append(f"An error occurred while getting business glossary '{glossary_id}': {e}")
            return {
                "status": "failed",
                "tool_name": "get_business_glossary",
                "query": None,
                "messages": messages,
                "results": None
            }


def delete_business_glossary(glossary_id: str) -> dict: # Changed to def
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
        _ = rest_api_helper.rest_api_helper(url, "DELETE", None) # Added await
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


def get_business_glossary_categories(glossary_id: str) -> dict: # Changed to def
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
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
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


def get_business_glossary_category(glossary_id: str, category_id: str) -> dict: # Changed to def
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
            "results": { ... category object details ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")
    messages = []
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{business_glossary_region}/glossaries/{glossary_id}/categories/{category_id}"

    try:
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        messages.append(f"Successfully retrieved details for category '{category_id}' in glossary '{glossary_id}' from the API.")

        return {
            "status": "success",
            "tool_name": "get_business_glossary_category",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        error_message = str(e)
        # Check if the error is specifically a "not found" scenario (e.g., HTTP 404)
        if "404" in error_message and "not found" in error_message.lower():
            messages.append(f"Category '{category_id}' not found in glossary '{glossary_id}'.")
            return {
                "status": "failed", # Status is failed because it wasn't found
                "tool_name": "get_business_glossary_category",
                "query": None,
                "messages": messages,
                "results": None # Results are None when not found
            }
        else:
            messages.append(f"An error occurred while getting category '{category_id}' in glossary '{glossary_id}': {e}")
            return {
                "status": "failed",
                "tool_name": "get_business_glossary_category",
                "query": None,
                "messages": messages,
                "results": None
            }


def create_business_glossary_category(glossary_id: str, category_id: str, display_name: str, description: str = "") -> dict: # Changed to def
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
            "results": { ... response from the API call or creation status ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")
    messages = []

    # First, check if the category already exists.
    existence_check = get_business_glossary_category(glossary_id, category_id) # Added await
    messages.extend(existence_check.get("messages", [])) # Append messages from the sub-tool call

    if existence_check["status"] == "success" and existence_check["results"]:
        # Category found, so it already exists.
        full_category_name = existence_check["results"].get("name")
        messages.append(f"Business glossary category '{category_id}' already exists in glossary '{glossary_id}'.")
        return {
            "status": "success",
            "tool_name": "create_business_glossary_category",
            "query": None,
            "messages": messages,
            "results": {"name": full_category_name, "created": False}
        }
    elif existence_check["status"] == "failed" and "not found" in str(existence_check["messages"]).lower():
        # This is the expected scenario when the category does not exist.
        messages.append(f"Pre-check confirmed category '{category_id}' does not exist. Proceeding with creation.")
    else:
        # Any other type of failure during the existence check is an actual problem.
        messages.append(f"An unexpected error occurred during the existence check for category '{category_id}'.")
        return {
            "status": "failed",
            "tool_name": "create_business_glossary_category",
            "query": None,
            "messages": messages,
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
        json_result = rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await

        messages.append(f"Successfully created business glossary category '{category_id}' in glossary '{glossary_id}'.")

        return {
            "status": "success",
            "tool_name": "create_business_glossary_category",
            "query": None,
            "messages": messages,
            "results": json_result
        }

    except Exception as e:
        messages.append(f"An error occurred while creating the business glossary category '{category_id}': {e}")
        return {
            "status": "failed",
            "tool_name": "create_business_glossary_category",
            "query": None,
            "messages": messages,
            "results": None
        }


def delete_business_glossary_category(glossary_id: str, category_id: str) -> dict: # Changed to def
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
        _ = rest_api_helper.rest_api_helper(url, "DELETE", None) # Added await
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


def get_business_glossary_term(glossary_id: str, term_id: str) -> dict: # Changed to def
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
            "results": { ... term object details ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")
    messages = []
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{business_glossary_region}/glossaries/{glossary_id}/terms/{term_id}"

    try:
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        messages.append(f"Successfully retrieved details for term '{term_id}' in glossary '{glossary_id}' from the API.")
        return {
            "status": "success",
            "tool_name": "get_business_glossary_term",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        error_message = str(e)
        if "404" in error_message and "not found" in error_message.lower():
            messages.append(f"Term '{term_id}' not found in glossary '{glossary_id}'.")
            return {
                "status": "failed",
                "tool_name": "get_business_glossary_term",
                "query": None,
                "messages": messages,
                "results": None
            }
        else:
            messages.append(f"An error occurred while getting term '{term_id}' in glossary '{glossary_id}': {e}")
            return {
                "status": "failed",
                "tool_name": "get_business_glossary_term",
                "query": None,
                "messages": messages,
                "results": None
            }


def list_business_glossary_terms(glossary_id: str) -> dict: # Changed to def
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
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
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


def create_business_glossary_term( # Changed to def
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
            "results": { ... response from the API call or creation status ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    business_glossary_region = os.getenv("AGENT_ENV_BUSINESS_GLOSSARY_REGION")
    messages = []

    # First, check if the term already exists.
    term_id = term_id.strip()
    existence_check = get_business_glossary_term(glossary_id, term_id) # Added await
    messages.extend(existence_check.get("messages", []))

    if existence_check["status"] == "success" and existence_check["results"]:
        # Term found, so it already exists.
        full_term_name = existence_check["results"].get("name")
        messages.append(f"Business glossary term '{term_id}' already exists in glossary '{glossary_id}'.")
        return {
            "status": "success",
            "tool_name": "create_business_glossary_term",
            "query": None,
            "messages": messages,
            "results": {"name": full_term_name, "created": False}
        }
    elif existence_check["status"] == "failed" and "not found" in str(existence_check["messages"]).lower():
        # This is the expected scenario when the term does not exist.
        messages.append(f"Pre-check confirmed term '{term_id}' does not exist. Proceeding with creation.")
    else:
        # Any other type of failure during the existence check is an actual problem.
        messages.append(f"An unexpected error occurred during the existence check for term '{term_id}'.")
        return {
            "status": "failed",
            "tool_name": "create_business_glossary_term",
            "query": None,
            "messages": messages,
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
        json_result = rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await

        messages.append(f"Successfully created business glossary term '{term_id}'.")

        return {
            "status": "success",
            "tool_name": "create_business_glossary_term",
            "query": None,
            "messages": messages,
            "results": json_result
        }

    except Exception as e:
        messages.append(f"An error occurred while creating the business glossary term '{term_id}': {e}")
        return {
            "status": "failed",
            "tool_name": "create_business_glossary_term",
            "query": None,
            "messages": messages,
            "results": None
        }


def update_business_glossary_term( # Changed to def
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
        json_result = rest_api_helper.rest_api_helper(url_with_mask, "PATCH", request_body) # Added await
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


def delete_business_glossary_term(glossary_id: str, term_id: str) -> dict: # Changed to def
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
        _ = rest_api_helper.rest_api_helper(url, "DELETE", None) # Added await
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