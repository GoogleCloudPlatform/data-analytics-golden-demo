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
import re
# import asyncio # New: # import asyncio for asyncio.sleep
import data_analytics_agent.wait_tool as wait_tool # Assuming you have this async wait tool

logger = logging.getLogger(__name__)


knowledge_engine_agent_instruction="""You are a specialized, **Knowledge Engine Agent**, designed to assist users in managing Google Dataplex Knowledge Engine Scans. Your core capability is to interact with Dataplex Knowledge Engine APIs via your provided tools to list, create, start, retrieve status, and get details of knowledge engine scans.

You will interpret user requests and utilize your tools to fulfill them. If a request is ambiguous or lacks necessary parameters, you **MUST** ask clarifying questions to obtain the required information.

If the user says "knowledge scan" this refers to this agent.

**Configuration (Assumed Environment Variables):**
You operate within a Google Cloud environment where `AGENT_ENV_PROJECT_ID` and `AGENT_ENV_DATAPLEX_REGION` are pre-configured and accessible.

**Available Tools (You MUST only call functions from this list):**
*   `get_knowledge_engine_scans() -> dict`:
    *   **Description:** Lists all Dataplex Knowledge Engine scans in the configured region.
    *   **Returns:** A dictionary containing a list of knowledge engine scan objects.
*   `get_knowledge_engine_scans_for_dataset(dataset_id:str) -> dict`:
    *   **Description:** Lists all Dataplex Knowledge Engine scans that are configured to scan a specific BigQuery dataset.
    *   **Args:** `dataset_id` (str): The ID (or name) of the BigQuery dataset.
    *   **Returns:** A dictionary containing a list of knowledge engine scan objects.
*   `exists_knowledge_engine_scan(knowledge_engine_scan_name: str) -> dict`:
    *   **Description:** Checks if a specific Dataplex Knowledge Engine scan exists.
    *   **Args:** `knowledge_engine_scan_name` (str): The short name/ID of the knowledge engine scan.
    *   **Returns:** A dictionary indicating if the scan exists (`"exists": True/False`).
*   `create_knowledge_engine_scan(knowledge_engine_scan_name: str, knowledge_engine_display_name: str, bigquery_dataset_name: str) -> dict`:
    *   **Description:** Creates a new Dataplex Knowledge Engine scan targeting a BigQuery dataset. It includes an internal existence check.
    *   **Args:**
        *   `knowledge_engine_scan_name` (str): The short name/ID for the new scan.
        *   `knowledge_engine_display_name` (str): The user-friendly display name for the scan.
        *   `bigquery_dataset_name` (str): The BigQuery dataset to be scanned (e.g., "my_dataset_id").
    *   **Returns:** A dictionary indicating the creation status and details.
*   `start_knowledge_engine_scan(knowledge_engine_scan_name: str) -> dict`:
    *   **Description:** Initiates a new job for a specific Dataplex Knowledge Engine scan.
    *   **Args:** `knowledge_engine_scan_name` (str): The short name/ID of the knowledge engine scan to start.
    *   **Returns:** A dictionary containing the job operation details.
*   `get_knowledge_engine_scan_state(knowledge_engine_scan_job_name: str) -> dict`:
    *   **Description:** Retrieves the current state/status of a specific Dataplex Knowledge Engine scan job.
    *   **Args:** `knowledge_engine_scan_job_name` (str): The full operation name of the knowledge engine scan job.
    *   **Returns:** A dictionary with the job's state (e.g., "RUNNING", "SUCCEEDED", "FAILED").
*   `update_bigquery_dataset_dataplex_labels(knowledge_engine_scan_name: str, bigquery_dataset_name: str) -> dict`:
    *   **Description:** Updates Dataplex labels on a BigQuery dataset associated with a Knowledge Engine scan.
    *   **Args:**
        *   `knowledge_engine_scan_name` (str): The short name/ID of the knowledge engine scan.
        *   `bigquery_dataset_name` (str): The name of the BigQuery dataset.
    *   **Returns:** A dictionary indicating the update status.
*   `get_knowledge_engine_scan(knowledge_engine_scan_name: str) -> dict`:
    *   **Description:** Retrieves the full, detailed configuration and status of a specific Dataplex Knowledge Engine scan.
    *   **Args:** `knowledge_engine_scan_name` (str): The short name/ID of the knowledge engine scan.
    *   **Returns:** A dictionary containing the detailed scan object.
*   `get_bigquery_dataset_list() -> dict`: Gets the datasets in BigQuery. You should call this to get the dataset_id based on the name the user provided. Do not trust the name provided.
    *   **Returns:** A dictionary indicating the update status and results.
    
**Your Operational Playbook:**
When interpreting a user's request, identify the primary action they want to perform related to Knowledge Engine scans.

*   **To List All Scans:** If the user asks to "list all knowledge engine scans" or similar, call `get_knowledge_engine_scans()`.
*   **To List Scans for a Specific Dataset:** If the user asks "list knowledge scans for dataset 'X'", "show me knowledge scans on dataset 'Y'", or similar, call `get_knowledge_engine_scans_for_dataset(dataset_id='X')`. 
    * Workflow *
        1.  **Execute:** Verify the dataset name by calling the tool `get_bigquery_dataset_list`. Do not trust the user input, look it up.
        2.  **Execute:** Call the tool `get_knowledge_engine_scans_for_dataset` with the dataset_id.
        3.  **Present Results:** Do not just dump the JSON. Summarize the results for the user. For each scan in the `dataScans` list, present the table name passed to the tool, `name`, `displayName` and `description`.
*   **To Check if a Scan Exists:** If the user asks "does scan 'X' exist?", call `exists_knowledge_engine_scan(knowledge_engine_scan_name='X')`.
*   **To Get Details of a Specific Scan:** If the user asks "get details for scan 'X'" or "show me scan 'X'", call `get_knowledge_engine_scan(knowledge_engine_scan_name='X')`.
*   **To Create a Scan:**
    *   If the user asks to "create a knowledge engine scan", you **MUST** identify the `bigquery_dataset_name`.
    *   If `bigquery_dataset_name` is missing, ask the user to provide it (e.g., "Please provide the BigQuery dataset name you want to scan.").
    *   Once `bigquery_dataset_name` is available:
        *   **Derive `knowledge_engine_scan_name`**: Take the `bigquery_dataset_name`, replace all underscores (`_`) with dashes (`-`), and append the suffix `-knowledge-scan`. (e.g., `my_dataset` becomes `my-dataset-knowledge-scan`).
        *   **Derive `knowledge_engine_display_name`**: Take the `bigquery_dataset_name`, replace all underscores (`_`) with spaces (` `), convert to proper case (e.g., `my_dataset` becomes `My Dataset`), and append the suffix ` Knowledge Scan`. (e.g., `my_dataset` becomes `My Dataset Knowledge Scan`).
        *   Call `create_knowledge_engine_scan(knowledge_engine_scan_name='derived_scan_name', knowledge_engine_display_name='derived_display_name', bigquery_dataset_name='provided_dataset_name')`.
        *   Upon successful creation, call `update_bigquery_dataset_dataplex_labels(knowledge_engine_scan_name='derived_scan_name', bigquery_dataset_name='provided_dataset_name')`.
        *   Upon successful label update, call `start_knowledge_engine_scan(knowledge_engine_scan_name='derived_scan_name')`.
        *   Upon successful scan start, extract the `job_name` from the `start_knowledge_engine_scan` result and then call `get_knowledge_engine_scan_state(knowledge_engine_scan_job_name='job_name')` to monitor its initial state.
*   **To Start a Scan Job:** If the user asks to "start scan 'X'" or "run knowledge engine scan 'X'", call `start_knowledge_engine_scan(knowledge_engine_scan_name='X')`.
*   **To Get Scan Job State:** If the user asks "what is the status of job 'Y'?" or "get state of job 'Y'", call `get_knowledge_engine_scan_state(knowledge_engine_scan_job_name='Y')`. You must **poll this tool periodically (e.g., every 15-30 seconds by calling the `wait_for_seconds` tool)** until the `state` becomes "SUCCEEDED", "FAILED", or "CANCELLED".
*   **To Update Labels:** If the user explicitly asks to "update labels for scan 'X' on dataset 'Y'", call `update_bigquery_dataset_dataplex_labels(knowledge_engine_scan_name='X', bigquery_dataset_name='Y')`.

**Responding to the User:**
*   After calling a tool, interpret its output (`status`, `messages`, `results`) and provide a concise, informative response to the user.
*   If a tool returns `status: "failed"`, explain the failure reason to the user, typically by relaying the `messages` from the tool's response.

**Failure Handling and Guardrails:**

*   **TOOL RELIANCE:** You **MUST NOT** attempt to perform operations directly or invent tool names or parameters. Only use the functions explicitly listed in your "Available Tools".
*   **ERROR PROPAGATION:** If a tool execution results in a `status: "failed"`, you must convey this failure and the reasons provided by the tool back to the user. Do not attempt to fix API-level errors yourself unless your playbook explicitly allows for a retry or alternative.
*   **CLARIFICATION:** You are allowed and encouraged to ask clarifying questions if the user's initial prompt does not provide all the necessary parameters for a tool call.

**Example Conversation Flow:**

*   **User:** "List all knowledge engine scans."
*   **Your Internal Thought:** User wants to list scans. Call `get_knowledge_engine_scans()`.
*   **Your Response:** (Based on tool output) "Here are the knowledge engine scans in your project: [list of scan names]."

*   **User:** "Create a knowledge engine scan for `my_data_warehouse`."
*   **Your Internal Thought:** User wants to create a scan. `bigquery_dataset_name` is `my_data_warehouse`.
    *   `knowledge_engine_scan_name` will be `my-data-warehouse-knowledge-scan`.
    *   `knowledge_engine_display_name` will be `My Data Warehouse Knowledge Scan`.
    *   Call `create_knowledge_engine_scan('my-data-warehouse-knowledge-scan', 'My Data Warehouse Knowledge Scan', 'my_data_warehouse')`.
    *   Then call `update_bigquery_dataset_dataplex_labels('my-data-warehouse-knowledge-scan', 'my_data_warehouse')`.
    *   Then call `start_knowledge_engine_scan('my-data-warehouse-knowledge-scan')`.
    *   Then call `get_knowledge_engine_scan_state('job_name_from_previous_step')`.
*   **Your Response:** (Based on tool output) "Initiated creation of knowledge engine scan 'my-data-warehouse-knowledge-scan' for dataset 'my_data_warehouse'. Linking BigQuery UI labels. The scan has been started and its current state is 'RUNNING'."

*   **User:** "Start the scan named 'product-catalog-scan'."
*   **Your Internal Thought:** User wants to start a scan. Call `start_knowledge_engine_scan(knowledge_engine_scan_name='product-catalog-scan')`.
*   **Your Response:** (Based on tool output) "Initiated knowledge engine scan 'product-catalog-scan'. The operation ID is 'projects/.../operations/...'"
"""


def get_knowledge_engine_scans() -> dict: # Changed to def
    """
    Lists all Dataplex knowledge engine scans in the configured region.

    This function specifically filters the results to include only scans of
    type 'knowledge_engine'.

    Returns:
        dict: A dictionary containing the status and the list of knowledge engine scans.
        {
            "status": "success" or "failed",
            "tool_name": "get_knowledge_engine_scans",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "dataScans": [ ... list of scan objects of type knowledge_engine ... ]
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    messages = []

    # The URL to list all data scans in the specified project and region.
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans"

    try:
        # Call the REST API to get the list of all existing data scans
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        messages.append("Successfully retrieved list of all data scans from the API.")

        # Filter the returned scans to only include those of type 'knowledge_engine'
        all_scans = json_result.get("dataScans", [])

        # Using a list comprehension for a concise filter
        profile_scans_only = [
            scan for scan in all_scans if scan.get("type") == "KNOWLEDGE_ENGINE"
        ]

        messages.append(f"Filtered results. Found {len(profile_scans_only)} knowledge engine scans.")

        # Create the final results payload with the filtered list
        filtered_results = {"dataScans": profile_scans_only}

        return {
            "status": "success",
            "tool_name": "get_knowledge_engine_scans",
            "query": None,
            "messages": messages,
            "results": filtered_results
        }
    except Exception as e:
        messages.append(f"An error occurred while listing knowledge engine scans: {e}")
        return {
            "status": "failed",
            "tool_name": "get_knowledge_engine_scans",
            "query": None,
            "messages": messages,
            "results": None
        }


def get_knowledge_engine_scans_for_dataset(dataset_id:str) -> dict: # Changed to def
    """
    Lists all Dataplex knowledge engine scans attached to the dataset.

    This function specifically filters the results to include only scans of
    type 'knowledge_engine' and assigned to the dataset id/name.

    Args:
        dataset_id (str): The ID (or name) of the BigQuery dataset.

    Returns:
        dict: A dictionary containing the status and the list of knowledge engine scans.
        {
            "status": "success" or "failed",
            "tool_name": "get_knowledge_engine_scans",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "dataScans": [ ... list of scan objects of type knowledge_engine ... ]
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    messages = []

    # The URL to list all data scans in the specified project and region.
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans"

    try:
        # Call the REST API to get the list of all existing data scans
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        messages.append("Successfully retrieved list of all data scans from the API.")

        # Filter the returned scans to only include those of type 'knowledge_engine'
        all_scans = json_result.get("dataScans", [])

        # Using a list comprehension for a concise filter
        profile_scans_only = []

        for item in all_scans:
            if item.get("type") == "KNOWLEDGE_ENGINE" and \
               item.get("data", {}).get("resource").lower() == f"//bigquery.googleapis.com/projects/{project_id}/datasets/{dataset_id}".lower():
                profile_scans_only.append(item)
            
        messages.append(f"Filtered results. Found {len(profile_scans_only)} knowledge engine scans for dataset {dataset_id}.")

        # Create the final results payload with the filtered list
        filtered_results = {"dataScans": profile_scans_only}

        return {
            "status": "success",
            "tool_name": "get_knowledge_engine_scans_for_dataset",
            "query": None,
            "messages": messages,
            "results": filtered_results
        }
    except Exception as e:
        messages.append(f"An error occurred while listing knowledge engine scans: {e}")
        return {
            "status": "failed",
            "tool_name": "get_knowledge_engine_scans_for_dataset",
            "query": None,
            "messages": messages,
            "results": None
        }


def exists_knowledge_engine_scan(knowledge_engine_scan_name: str) -> dict: # Changed to def
    """
    Checks if a Dataplex knowledge engine scan already exists by checking the full list.

    Args:
        knowledge_engine_scan_name (str): The short name/ID of the knowledge engine scan.

    Returns:
        dict: A dictionary containing the status and results of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "exists_knowledge_engine_scan",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "exists": True # or False
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")

    # Call the dedicated function to list all scans
    list_result = get_knowledge_engine_scans() # Added await
    messages = list_result.get("messages", [])

    # If listing scans failed, propagate the failure
    if list_result["status"] == "failed":
        return {
            "status": "failed",
            "tool_name": "exists_knowledge_engine_scan",
            "query": None,
            "messages": messages,
            "results": None
        }

    try:
        scan_exists = False
        json_payload = list_result.get("results", {})
        full_scan_name_to_find = f"projects/{project_id}/locations/{dataplex_region}/dataScans/{knowledge_engine_scan_name}"

        # Loop through the list of scans from the results
        for item in json_payload.get("dataScans", []):
            if item.get("name") == full_scan_name_to_find:
                scan_exists = True
                messages.append(f"Found matching scan: '{knowledge_engine_scan_name}'.")
                break

        if not scan_exists:
            messages.append(f"Scan '{knowledge_engine_scan_name}' does not exist.")

        return {
            "status": "success",
            "tool_name": "exists_knowledge_engine_scan",
            "query": None,
            "messages": messages,
            "results": {"exists": scan_exists}
        }
    except Exception as e: # Catch potential errors while processing the list
        messages.append(f"An unexpected error occurred while processing scan list: {e}")
        return {
            "status": "failed",
            "tool_name": "exists_knowledge_engine_scan",
            "query": None,
            "messages": messages,
            "results": None
        }


def create_knowledge_engine_scan(knowledge_engine_scan_name: str, knowledge_engine_display_name: str, bigquery_dataset_name: str) -> dict: # Changed to def
    """
    Creates a new Dataplex knowledge engine Scan if it does not already exist.

    Args:
        knowledge_engine_scan_name (str): The short name/ID for the new knowledge engine scan.
        knowledge_engine_display_name (str): The user-friendly display name for the scan.
        bigquery_dataset_name (str): The BigQuery dataset to be scanned.

    Returns:
        dict: A dictionary containing the status and results of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "create_knowledge_engine_scan",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": { ... response from the API call ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")

    # First, check if the knowledge engine scan already exists.
    existence_check = exists_knowledge_engine_scan(knowledge_engine_scan_name) # Added await
    messages = existence_check.get("messages", [])

    # If the check failed, propagate the failure.
    if existence_check["status"] == "failed":
        return {
            "status": "failed",
            "tool_name": "create_knowledge_engine_scan",
            "query": None,
            "messages": messages,
            "results": None
        }

    # If the scan already exists, report success and stop.
    if existence_check["results"]["exists"]:
        full_scan_name = f"projects/{project_id}/locations/{dataplex_region}/dataScans/{knowledge_engine_scan_name}"
        return {
            "status": "success",
            "tool_name": "create_knowledge_engine_scan",
            "query": None,
            "messages": messages,
            "results": {"name": full_scan_name, "created": False}
        }

    # If the scan does not exist, proceed with creation.
    messages.append(f"Creating knowledge engine Scan '{knowledge_engine_scan_name}'.")

    # API endpoint to create a data scan. The scan ID is passed as a query parameter.
    # https://cloud.google.com/dataplex/docs/reference/rest/v1/projects.locations.dataScans/create
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans?dataScanId={knowledge_engine_scan_name}"

    request_body = {
    "name": f"projects/{project_id}/locations/{dataplex_region}/dataScans/{knowledge_engine_scan_name}",
    "uid": knowledge_engine_scan_name,
    "description": f"Knowledge engine scan for the dataset {bigquery_dataset_name}",
    "displayName": knowledge_engine_scan_name,
    "data": {
        "resource": f"//bigquery.googleapis.com/projects/{project_id}/datasets/{bigquery_dataset_name}" },
        "executionSpec": {
            "trigger": {
                "onDemand": {} }
                },
        "type": "KNOWLEDGE_ENGINE",
        "knowledgeEngineSpec": {}
    }


    try:
        # The create API returns a long-running operation object.
        json_result = rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await

        operation_name = json_result.get("name", "Unknown Operation")
        messages.append(f"Successfully initiated knowledge engine Scan creation. Operation: {operation_name}")

        return {
            "status": "success",
            "tool_name": "create_knowledge_engine_scan",
            "query": None,
            "messages": messages,
            "results": json_result
        }

    except Exception as e:
        messages.append(f"An error occurred while creating the knowledge engine scan: {e}")
        return {
            "status": "failed",
            "tool_name": "create_knowledge_engine_scan",
            "query": None,
            "messages": messages,
            "results": None
        }


def start_knowledge_engine_scan(knowledge_engine_scan_name: str) -> dict: # Changed to def
    """
    Triggers a run of an existing Dataplex knowledge engine scan.

    This initiates a new scan job. To check the status of this job, you will
    need the job name from the results and use the 'get_state_knowledge_engine_scan' tool.

    Args:
        knowledge_engine_scan_name (str): The short name/ID of the knowledge engine scan to run.

    Returns:
        dict: A dictionary containing the status and the job information.
        {
            "status": "success" or "failed",
            "tool_name": "start_knowledge_engine_scan",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "job": {
                    "name": "projects/.../locations/.../dataScans/.../jobs/...",
                    "uid": "...",
                    "createTime": "...",
                    "startTime": "...",
                    "state": "RUNNING",
                    "dataProfileResult": {}
                }
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    messages = []

    # The API endpoint to run a data scan job. Note the custom ':run' verb at the end.
    # https://cloud.google.com/dataplex/docs/reference/rest/v1/projects.locations.dataScans/run
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{knowledge_engine_scan_name}:run"

    # The run method requires a POST request with an empty body.
    request_body = {}

    try:
        messages.append(f"Attempting to run knowledge engine Scan '{knowledge_engine_scan_name}'.")

        # Call the REST API to trigger the scan run.
        json_result = rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await

        # Extract job details for a more informative message.
        # Use .get() for safe access in case the response structure is unexpected.
        job_info = json_result.get("job", {})
        job_name = job_info.get("name", "Unknown Job")
        job_state = job_info.get("state", "Unknown State")

        messages.append(f"Successfully started knowledge engine Scan job: {job_name} - State: {job_state}")

        return {
            "status": "success",
            "tool_name": "start_knowledge_engine_scan",
            "query": None,
            "messages": messages,
            "results": json_result
        }

    except Exception as e:
        messages.append(f"An error occurred while starting the knowledge engine scan: {e}")
        return {
            "status": "failed",
            "tool_name": "start_knowledge_engine_scan",
            "query": None,
            "messages": messages,
            "results": None
        }
    

def get_knowledge_engine_scan_state(knowledge_engine_scan_job_name: str) -> dict: # Changed to def
    """
    Gets the current state of a running knowledge engine scan job.

    The job is created when a scan is started via 'start_knowledge_engine_scan'.

    Args:
        knowledge_engine_scan_job_name (str): The full resource name of the scan job, e.g.,
                                          "projects/.../locations/.../dataScans/.../jobs/...".

    Returns:
        dict: A dictionary containing the status and the job state.
        {
            "status": "success" or "failed",
            "tool_name": "get_knowledge_engine_scan_state",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "state": "SUCCEEDED" # or "RUNNING", "FAILED", etc.
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")    
    messages = []

    # The API endpoint for getting a job's status is generic.
    # The job name itself is the full path after the API version.
    url = f"https://dataplex.googleapis.com/v1/{knowledge_engine_scan_job_name}"

    try:
        # Make a GET request to the specific job URL.
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await

        # Safely extract the state from the response.
        state = json_result.get("state", "UNKNOWN")
        messages.append(f"knowledge engine job '{knowledge_engine_scan_job_name}' is in state: {state}")

        return {
            "status": "success",
            "tool_name": "get_knowledge_engine_scan_state",
            "query": None,
            "messages": messages,
            "results": {"state": state}
        }
    except Exception as e:
        messages.append(f"An error occurred while getting the knowledge engine scan job state: {e}")
        return {
            "status": "failed",
            "tool_name": "get_knowledge_engine_scan_state",
            "query": None,
            "messages": messages,
            "results": None
        }


def update_bigquery_dataset_dataplex_labels(knowledge_engine_scan_name: str, bigquery_dataset_name: str) -> dict: # Changed to def
    """
    Updates a BigQuery table's labels to link it to a Dataplex knowledge engine scan.

    This operation is necessary for the knowledge engine results to appear in the
    "knowledge engine" tab of the table details page in the BigQuery Console.

    Args:
        knowledge_engine_scan_name (str): The short name/ID of the knowledge engine scan to link.
        bigquery_dataset_name (str): The BigQuery dataset containing the knowledge scan.

    Returns:
        dict: A dictionary containing the status and the BigQuery API response.
        {
            "status": "success" or "failed",
            "tool_name": "update_bigquery_dataset_dataplex_labels",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": { ... response from the BigQuery tables.patch API call ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    messages = []

    # API endpoint for patching a BigQuery table's metadata.
    # https://cloud.google.com/bigquery/docs/reference/rest/v2/tables/patch
    url = f"https://bigquery.googleapis.com/bigquery/v2/projects/{project_id}/datasets/{bigquery_dataset_name}"

    # The request body contains the specific labels that link the table to the scan.
    request_body = {
        "labels": {
            "dataplex-knowledge-engine-published-project": project_id,
            "dataplex-knowledge-engine-published-location": dataplex_region,
            "dataplex-knowledge-engine-published-scan": knowledge_engine_scan_name,
        }
    }

    try:
        messages.append(f"Patching BigQuery table '{bigquery_dataset_name}' with Dataplex labels.")

        # Call the REST API using PATCH to update the table's labels.
        json_result = rest_api_helper.rest_api_helper(url, "PATCH", request_body) # Added await

        messages.append("Successfully updated BigQuery dataset labels.")

        return {
            "status": "success",
            "tool_name": "update_bigquery_dataset_dataplex_labels",
            "query": None,
            "messages": messages,
            "results": json_result
        }

    except Exception as e:
        messages.append(f"An error occurred while updating the BigQuery table labels: {e}")
        return {
            "status": "failed",
            "tool_name": "update_bigquery_dataset_dataplex_labels",
            "query": None,
            "messages": messages,
            "results": None
        }
    
    
def get_knowledge_engine_scan(knowledge_engine_scan_name: str) -> dict: # Changed to def
    """
    Gets a single Dataplex knowledge engine scan in the configured region.
    This returns the "Full" view which has all the scan details (more than just a data scan listing (e.g. tool: get_knowledge_engine_scans))

    Args:
        knowledge_engine_scan_name (str): The name of the knowledge engine scan.

    Returns:
        dict: A dictionary containing the status and the list of knowledge engine scans.
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    messages = []
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{knowledge_engine_scan_name}?view=FULL"

    if "projects/" in knowledge_engine_scan_name:
        url = f"https://dataplex.googleapis.com/v1/{knowledge_engine_scan_name}?view=FULL"      

    try:
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        messages.append("Successfully retrieved the data get_knowledge_engine_scan from the API.")

        return {
            "status": "success",
            "tool_name": "get_knowledge_engine_scan",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while listing knowledge engine scan: {e}")
        return {
            "status": "failed",
            "tool_name": "get_knowledge_engine_scan",
            "query": None,
            "messages": messages,
            "results": None
        }