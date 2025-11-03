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
import json
import re

import data_analytics_agent.utils.rest_api.rest_api_helper as rest_api_helper 
import data_analytics_agent.tools.dataplex.business_glossary_tools as business_glossary_tools

logger = logging.getLogger(__name__)


async def get_knowledge_engine_scans() -> dict: 
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
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) # Added await
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


async def get_knowledge_engine_scans_for_dataset(dataset_id:str) -> dict: 
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
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) # Added await
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


async def exists_knowledge_engine_scan(knowledge_engine_scan_name: str) -> dict: 
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
    list_result = await get_knowledge_engine_scans() # Added await
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


async def create_knowledge_engine_scan(knowledge_engine_scan_name: str, knowledge_engine_display_name: str, bigquery_dataset_name: str) -> dict: 
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
    existence_check = await exists_knowledge_engine_scan(knowledge_engine_scan_name) # Added await
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
        "type": "DATA_DOCUMENTATION",
        "dataDocumentationSpec": {}
    }


    try:
        # The create API returns a long-running operation object.
        json_result = await rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await

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


async def start_knowledge_engine_scan(knowledge_engine_scan_name: str) -> dict: 
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
        json_result = await rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await

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
    

async def get_knowledge_engine_scan_state(knowledge_engine_scan_job_name: str) -> dict: 
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
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) # Added await

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


async def update_bigquery_dataset_dataplex_labels(knowledge_engine_scan_name: str, bigquery_dataset_name: str) -> dict: 
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
        json_result = await rest_api_helper.rest_api_helper(url, "PATCH", request_body) # Added await

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
    
    
async def get_knowledge_engine_scan(knowledge_engine_scan_name: str) -> dict: 
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
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) # Added await
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


async def delete_knowledge_engine_scan_job(knowledge_engine_scan_job_name: str) -> dict: # Changed to def
    """
    Deletes a specific Dataplex Knowledge Engine scan job.

    Args:
        knowledge_engine_scan_job_name (str): The full resource name of the scan job, e.g.,
                                          "projects/.../locations/.../dataScans/.../jobs/...".

    Returns:
        dict: A dictionary containing the status of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "delete_knowledge_engine_scan_job",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {} # Empty dictionary on success
        }
    """
    messages = []
    
    # The URL for deleting a job is the job's full resource path.
    url = f"https://dataplex.googleapis.com/v1/{knowledge_engine_scan_job_name}"
    
    try:
        messages.append(f"Attempting to delete Knowledge Engine Scan job: '{knowledge_engine_scan_job_name}'.")
        # DELETE operation typically returns an empty response or an Operation object
        await rest_api_helper.rest_api_helper(url, "DELETE", None) 
        messages.append(f"Successfully deleted Knowledge Engine Scan job: '{knowledge_engine_scan_job_name}'.")
        return {
            "status": "success",
            "tool_name": "delete_knowledge_engine_scan_job",
            "query": None,
            "messages": messages,
            "results": {}
        }
    except Exception as e:
        messages.append(f"An error occurred while deleting Knowledge Engine scan job '{knowledge_engine_scan_job_name}': {e}")
        return {
            "status": "failed",
            "tool_name": "delete_knowledge_engine_scan_job",
            "query": None,
            "messages": messages,
            "results": None
        }


async def delete_knowledge_engine_scan(knowledge_engine_scan_name: str) -> dict: # Changed to def
    """
    Deletes a specific Dataplex Knowledge Engine scan definition.
    This operation only succeeds if there are no associated scan jobs.
    The agent's workflow should ensure jobs are deleted first.

    Args:
        knowledge_engine_scan_name (str): The short name/ID of the Knowledge Engine scan to delete.

    Returns:
        dict: A dictionary containing the status of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "delete_knowledge_engine_scan",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {} # Empty dictionary on success
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    messages = []

    # The URL for deleting a data scan.
    # We do NOT use 'force=true' here, as per requirements that jobs should be deleted first.
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{knowledge_engine_scan_name}"

    try:
        messages.append(f"Attempting to delete Knowledge Engine Scan definition: '{knowledge_engine_scan_name}'.")
        # DELETE operation typically returns an empty response or an Operation object
        await rest_api_helper.rest_api_helper(url, "DELETE", None) 
        messages.append(f"Successfully deleted Knowledge Engine Scan definition: '{knowledge_engine_scan_name}'.")
        return {
            "status": "success",
            "tool_name": "delete_knowledge_engine_scan",
            "query": None,
            "messages": messages,
            "results": {}
        }
    except Exception as e:
        messages.append(f"An error occurred while deleting Knowledge Engine scan definition '{knowledge_engine_scan_name}': {e}")
        return {
            "status": "failed",
            "tool_name": "delete_knowledge_engine_scan",
            "query": None,
            "messages": messages,
            "results": None
        }


################################################################################################################
# parse_create_and_run_knowledge_engine_scan_params
################################################################################################################
from google.adk.tools.tool_context import ToolContext
import data_analytics_agent.tools.bigquery.bigquery_dataset_tools as bigquery_dataset_tools
import data_analytics_agent.utils.gemini.gemini_helper as gemini_helper

async def parse_create_and_run_knowledge_engine_scan_params(tool_context: ToolContext, prompt: str) -> dict:
    """
    Parses a user prompt for knowledge engine scan details and sets them in session state for subsequent agents to use.
    """
    response_schema = {
        "type": "object",
        "properties": {
            "knowledge_engine_scan_name": {
                "type": "string",
                "description": "This is the knowledge engine scan name.  If no name is provided you should create one that uses hyphens (not spaces) for seperators."
            },
             "knowledge_engine_display_name": {
                "type": "string",
                "description": "This is the knowledge engine scan name.  If no name is provided you should create one that uses spaces for seperators."
            },
            "bigquery_dataset_name": {
                "type": "string",
                "description": "The matching BigQuery dataset name."
            }         
        },
        "required": ["knowledge_engine_scan_name", "knowledge_engine_display_name", "bigquery_dataset_name"]
    }

    get_bigquery_dataset_list_helper_response = await bigquery_dataset_tools.get_bigquery_dataset_list()
    bigquery_dataset_schema = get_bigquery_dataset_list_helper_response["results"]

    prompt = f"""You need to match or create the correct names for the following using the below schema information from BigQuery.

    The user provided the below information "original-user-prompt" and you need to extract the:
    - knowledge_engine_scan_name: This information may or may not be provided by the user.
        - You can create the scan name, using hyphens for seperators, and a good name would match the dataset name and then append a "-knowledge-scan".
        - For example "my_dataset" would have a scan name of "my-dataset-knowledge-scan".
        - Keep this to about 30 characters.
    - knowledge_engine_display_name: This information may or may not be provided by the user.
        - You can create the display name, using spaces for seperators, and a good name would match the dataset name and then append a " Knowledge Sscan".
        - For example "my_dataset" would have a scan name of "My Dataset Knowledge Scan".
        - Keep this to about 30 characters.
    - bigquery_dataset_name:  This must be a match from the <bigquery-dataset-schema> based upon the user's prompt.

    There could be misspelled words, spaces, etc. So please correct them.

    <original-user-prompt>
    {prompt}
    </original-user-prompt>

    <bigquery-dataset-schema>
    {bigquery_dataset_schema}
    </bigquery-dataset-schema>
    """

    gemini_response = await gemini_helper.gemini_llm(prompt, response_schema=response_schema, model="gemini-2.5-flash", temperature=0.2)
    gemini_response_dict = json.loads(gemini_response)   

    knowledge_engine_scan_name = gemini_response_dict.get("knowledge_engine_scan_name", None) 
    knowledge_engine_display_name = gemini_response_dict.get("knowledge_engine_display_name", None) 
    bigquery_dataset_name = gemini_response_dict.get("bigquery_dataset_name",None) 

    tool_context.state["knowledge_engine_scan_name_param"] = knowledge_engine_scan_name
    tool_context.state["knowledge_engine_display_name_param"] = knowledge_engine_display_name
    tool_context.state["bigquery_dataset_name_param"] = bigquery_dataset_name
    tool_context.state["initial_prompt_content"] = prompt # Store the original query

    logger.info(f"parse_create_and_run_knowledge_engine_scan_params: knowledge_engine_scan_name: {knowledge_engine_scan_name}")
    logger.info(f"parse_create_and_run_knowledge_engine_scan_params: knowledge_engine_display_name: {knowledge_engine_display_name}")
    logger.info(f"parse_create_and_run_knowledge_engine_scan_params: bigquery_dataset_name: {bigquery_dataset_name}")
    logger.info(f"parse_create_and_run_knowledge_engine_scan_params: initial_prompt_content: {prompt}")    

    return {
        "status": "success",
        "tool_name": "parse_and_set_knowledge_engine_params_tool",
        "query": None,
        "messages": [
            "Knowledge engine parameters parsed and set in session state and being returned"
        ],
        "results": {
            "knowledge_engine_scan_name" : knowledge_engine_scan_name,
            "knowledge_engine_display_name" : knowledge_engine_display_name,
            "bigquery_dataset_name" : bigquery_dataset_name
        }
    }


################################################################################################################
# create_and_run_knowledge_engine_scan
################################################################################################################
import data_analytics_agent.utils.time_delay.wait_tool as wait_tool

from typing import AsyncGenerator
from pydantic import Field
from google.genai import types
from google.adk.events import Event 


async def create_and_run_knowledge_engine_scan(
    knowledge_engine_scan_name: str,
    knowledge_engine_display_name: str,
    bigquery_dataset_name: str,
    initial_prompt_content: str,
    event_author_name: str
) -> AsyncGenerator[Event, None]:
    """
    Orchestrates the complete Dataplex Knowledge Engine scan workflow, including
    creating the scan, starting the job, monitoring its state, and linking to BigQuery.
    Emits progress messages to the user interface by yielding Events.

    Args:
        knowledge_engine_scan_name (str): The name/ID for the knowledge engine scan.
        knowledge_engine_display_name (str): The display name for the knowledge engine scan.
        bigquery_dataset_name (str): The BigQuery dataset name.
        initial_prompt_content (str): The original user query that initiated this workflow.
        event_author_name (str): The name to use as the author for yielded Event messages.

    Yields:
        Event: Progress messages and a final structured Event containing the workflow output.
    """
    logger.info(f"[{event_author_name}] Starting Knowledge Engine Scan workflow for {knowledge_engine_scan_name}.")

    response = {
        "status": "success",
        "tool_name": "full_knowledge_engine_workflow",
        "query": initial_prompt_content,
        "messages": [],
        "results": {
            "knowledge_engine_scan_name": knowledge_engine_scan_name,
            "knowledge_engine_display_name": knowledge_engine_display_name,
            "bigquery_dataset_name": bigquery_dataset_name,
            "knowledge_engine_scan_job_name": None,
            "knowledge_engine_scan_job_state": None,
        },
        "success": True
    }

    def _handle_error_and_finish(err_message: str, current_response: dict):
        current_response["status"] = "failed"
        current_response["success"] = False
        current_response["messages"].append(err_message)
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=f"Error: {err_message}")]))        
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=json.dumps(current_response, indent=2))]),
        )

    # Emit initial message
    yield Event(
        author=event_author_name,
        content=types.Content(role='assistant', parts=[types.Part(text=f"Initiating full knowledge engine scan workflow for '{bigquery_dataset_name}'.")])
    )
    response["messages"].append(f"Workflow initiated for {knowledge_engine_scan_name}.")


    # --- Step 1: Create the Scan Definition ---
    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 1/5: Creating knowledge engine scan definition: '{knowledge_engine_scan_name}'.")])
        )
        create_scan_result = await create_knowledge_engine_scan(
            knowledge_engine_scan_name,
            knowledge_engine_display_name,
            bigquery_dataset_name
        )
        if create_scan_result["status"] != "success":
            raise Exception(f"Failed to create scan definition: {create_scan_result.get('error_message', 'Unknown error')}")
        
        success_message = f"Successfully created knowledge engine scan definition: {knowledge_engine_scan_name}. Now waiting for it to register."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed to create knowledge engine scan '{knowledge_engine_scan_name}'. Error: {e}", response):
            yield error_event
        return


    # --- Step 2: Wait for Scan to Exist (Polling Loop) ---
    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 2/5: Waiting for scan '{knowledge_engine_scan_name}' to be registered and exist.")])
        )
        scan_exists = False
        max_attempts = 10
        for i in range(max_attempts):
            exists_check_result = await exists_knowledge_engine_scan(knowledge_engine_scan_name)
            if exists_check_result["status"] == "success" and exists_check_result["results"]["exists"]:
                scan_exists = True
                break
            yield Event(
                author=event_author_name,
                content=types.Content(role='assistant', parts=[types.Part(text=f"Scan not yet registered (attempt {i+1}/{max_attempts}). Waiting 2 seconds...")])
            )
            await wait_tool.wait_for_seconds(2)

        if not scan_exists:
            raise Exception(f"Scan '{knowledge_engine_scan_name}' did not become registered after {max_attempts * 2} seconds.")
        
        success_message = f"Knowledge engine scan '{knowledge_engine_scan_name}' is now registered and ready."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed while waiting for scan '{knowledge_engine_scan_name}' to register. Error: {e}", response):
            yield error_event
        return


    # --- Step 3: Start the Scan Job ---
    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 3/5: Starting the knowledge engine scan job for '{knowledge_engine_scan_name}'.")])
        )
        start_job_result = await start_knowledge_engine_scan(knowledge_engine_scan_name)
        if start_job_result["status"] != "success" or not start_job_result["results"].get("job", {}).get("name"):
            raise Exception(f"Failed to start scan job: {start_job_result.get('error_message', 'Unknown error')}")
        
        job_name = start_job_result["results"]["job"]["name"]
        response["results"]["knowledge_engine_scan_job_name"] = job_name
        
        success_message = f"Successfully started knowledge engine scan job: '{job_name}'. Monitoring its progress."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed to start knowledge engine scan job for '{knowledge_engine_scan_name}'. Error: {e}", response):
            yield error_event
        return


    # --- Step 4: Monitor the Scan Job State (Polling Loop) ---
    job_name = response["results"]["knowledge_engine_scan_job_name"]
    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 4/5: Monitoring knowledge engine job '{job_name}' for completion.")])
        )
        job_completed = False
        final_job_state = "UNKNOWN"
        max_attempts = 50
        for i in range(max_attempts):
            job_state_result = await get_knowledge_engine_scan_state(job_name)
            if job_state_result["status"] == "success" and job_state_result["results"].get("state"):
                current_state = job_state_result["results"]["state"]
                yield Event(
                    author=event_author_name,
                    content=types.Content(role='assistant', parts=[types.Part(text=f"Job '{job_name}' status: {current_state} (attempt {i+1}/{max_attempts}).")])
                )
                if current_state in ["SUCCEEDED", "FAILED", "CANCELLED"]:
                    job_completed = True
                    final_job_state = current_state
                    break
            else:
                yield Event(
                    author=event_author_name,
                    content=types.Content(role='assistant', parts=[types.Part(text=f"Could not retrieve job status (attempt {i+1}/{max_attempts}). Retrying in 5 seconds...")])
                )
            await wait_tool.wait_for_seconds(5)

        if not job_completed:
            raise Exception(f"Knowledge engine job '{job_name}' did not complete after {max_attempts * 5} seconds. Final state: {final_job_state}")
        
        if final_job_state != "SUCCEEDED":
            raise Exception(f"Knowledge engine job '{job_name}' completed with state: {final_job_state}. (Expected SUCCEEDED)")

        response["results"]["knowledge_engine_scan_job_state"] = final_job_state
        success_message = f"Knowledge engine job '{job_name}' completed successfully with state: {final_job_state}. Now linking to BigQuery."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        final_job_state = final_job_state if 'final_job_state' in locals() else 'UNKNOWN_FAILED'
        response["results"]["knowledge_engine_scan_job_state"] = final_job_state
        for error_event in _handle_error_and_finish(f"Knowledge engine job '{job_name}' failed or did not complete. Error: {e}", response):
            yield error_event
        return

    # --- Step 5: Link the Scan to BigQuery ---
    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 5/5: Linking knowledge engine scan '{knowledge_engine_scan_name}' to BigQuery dataset '{bigquery_dataset_name}'.")])
        )
        link_result = await update_bigquery_dataset_dataplex_labels(
            knowledge_engine_scan_name,
            bigquery_dataset_name,
        )
        if link_result["status"] != "success":
            raise Exception(f"Failed to link to BigQuery: {link_result.get('error_message', 'Unknown error')}")
        
        success_message = f"Successfully linked the knowledge engine scan to BigQuery. Results should now be visible in the BigQuery console."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed to link knowledge engine scan '{knowledge_engine_scan_name}' to BigQuery. Error: {e}", response):
            yield error_event
        return

    # --- Workflow Complete ---
    final_overall_message = "Knowledge engine workflow completed successfully!" if response["success"] else "Knowledge engine workflow completed with failures."
    yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=final_overall_message)]))
    response["messages"].append(final_overall_message)

    # Do not yield the entire json summary
    # yield Event(
    #     author=event_author_name,
    #     content=types.Content(role='assistant', parts=[types.Part(text=json.dumps(response, indent=2))]),
    # )



################################################################################################################
# parse_create_business_glossary_knowledge_engine_params
################################################################################################################
from google.adk.tools.tool_context import ToolContext
import data_analytics_agent.tools.bigquery.bigquery_dataset_tools as bigquery_dataset_tools
import data_analytics_agent.utils.gemini.gemini_helper as gemini_helper

async def parse_create_business_glossary_knowledge_engine_params(tool_context: ToolContext, prompt: str) -> dict:
    """
    Parses a user prompt for knowledge engine scan details and sets them in session state for subsequent agents to use.
    """
    response_schema = {
        "type": "object",
        "properties": {
            "knowledge_engine_scan_name": {
                "type": "string",
                "description": "This is the knowledge engine scan name.  You must find a match in the provided list."
            },
             "glossary_id": {
                "type": "string",
                "description": "This is the business glossary name to be created."
            },
            "glossary_display_name": {
                "type": "string",
                "description": "This is the business glossary display name."
            },
            "glossary_description": {
                "type": "string",
                "description": "This is the business glossary description."
            }          
        },
        "required": ["knowledge_engine_scan_name", "glossary_id", "glossary_display_name", "glossary_description"]
    }

    get_knowledge_engine_scans_response = await get_knowledge_engine_scans();
    get_knowledge_engine_scans_dict = get_knowledge_engine_scans_response["results"]

    gemini_prompt = f"""You need to match or create the correct names for the following using the below schema information from BigQuery.

    The user provided the below information "original-user-prompt" and you need to extract the:
    - knowledge_engine_scan_name: The user has provide a name, find the best match in the <knowledge-engine-scans>.
    - glossary_id: If the user has provide one, use it; otherwise, you can create on based upon the dataset of the knowledge_engine_scan_name.
        - If the knowledge_engine_scan_name scanned dataset `my-dataset` then you can create a name of `my-dataset-glossary`.
        - There should be no spaces only hyphens and lower case.
    - glossary_display_name: If the user has provide one, use it; otherwise, you should create a meaningful description based upon the glossary id.
        - If the glossary_id is `my-dataset-glossary` then the glossary_display_name would be `My Dataset Glossary` using proper case and spaces.
    - glossary_description: If the user has provide one, use it; otherwise, you should create a meaningful description.

    There could be misspelled words, spaces, etc. So please correct them.

    <original-user-prompt>
    {prompt}
    </original-user-prompt>

    <knowledge-engine-scans>
    {get_knowledge_engine_scans_dict}
    </knowledge-engine-scans>
    """

    gemini_response = await gemini_helper.gemini_llm(gemini_prompt, response_schema=response_schema, model="gemini-2.5-flash", temperature=0.2)
    gemini_response_dict = json.loads(gemini_response)   

    # "knowledge_engine_scan_name", "glossary_id", "glossary_display_name", "glossary_description"
    knowledge_engine_scan_name = gemini_response_dict.get("knowledge_engine_scan_name", None) 
    glossary_id = gemini_response_dict.get("glossary_id", None) 
    glossary_display_name = gemini_response_dict.get("glossary_display_name",None) 
    glossary_description = gemini_response_dict.get("glossary_description",None) 

    tool_context.state["knowledge_engine_scan_name_param"] = knowledge_engine_scan_name
    tool_context.state["glossary_id_param"] = glossary_id
    tool_context.state["glossary_display_name_param"] = glossary_display_name
    tool_context.state["glossary_description_param"] = glossary_description
    tool_context.state["initial_prompt_content"] = prompt # Store the original query

    logger.info(f"parse_create_and_run_knowledge_engine_scan_params: knowledge_engine_scan_name: {knowledge_engine_scan_name}")
    logger.info(f"parse_create_and_run_knowledge_engine_scan_params: glossary_id: {glossary_id}")
    logger.info(f"parse_create_and_run_knowledge_engine_scan_params: glossary_display_name: {glossary_display_name}")
    logger.info(f"parse_create_and_run_knowledge_engine_scan_params: glossary_description: {glossary_description}")
    logger.info(f"parse_create_and_run_knowledge_engine_scan_params: initial_prompt_content: {prompt}")    

    return {
        "status": "success",
        "tool_name": "parse_create_business_glossary_knowledge_engine_params",
        "query": None,
        "messages": [
            "Knowledge engine parameters parsed and set in session state and being returned"
        ],
        "results": {
            "knowledge_engine_scan_name" : knowledge_engine_scan_name,
            "glossary_id" : glossary_id,
            "glossary_display_name" : glossary_display_name,
            "glossary_description" : glossary_description,
            "initial_prompt_content" : prompt
        }
    }


################################################################################################################
# create_and_run_knowledge_engine_scan
################################################################################################################
import data_analytics_agent.utils.time_delay.wait_tool as wait_tool

from typing import AsyncGenerator
from pydantic import Field
from google.genai import types
from google.adk.events import Event 


async def create_business_glossary_from_knowledge_engine_scan(
    knowledge_engine_scan_name: str,
    glossary_id: str,
    glossary_display_name: str,
    glossary_description: str,
    initial_prompt_content: str,
    event_author_name: str
) -> AsyncGenerator[Event, None]:
    """
    Orchestrates creating a business glossary from a knowledge engine scan.
    Emits progress messages to the user interface by yielding Events.

    Args:
        knowledge_engine_scan_name (str): The name/ID for the knowledge engine scan.
        glossary_id (str): The name/ID for the glossary id.
        glossary_display_name (str): The display name of the business glossary.
        glossary_description (str): The description of the business glossary.
        initial_prompt_content (str): The original user query that initiated this workflow.
        event_author_name (str): The name to use as the author for yielded Event messages.

    Yields:
        Event: Progress messages and a final structured Event containing the workflow output.
    """
    logger.info(f"[{event_author_name}] Starting Create Business Glossary from Knowledge Engine scan workflow for {knowledge_engine_scan_name}.")

    response = {
        "status": "success",
        "tool_name": "create_business_glossary_from_knowledge_engine_scan",
        "query": initial_prompt_content,
        "messages": [],
        "results": {
            "knowledge_engine_scan_name": knowledge_engine_scan_name,
            "glossary_id": glossary_id,
            "glossary_display_name": glossary_display_name,
            "glossary_description": glossary_description
        },
        "success": True
    }

    def _handle_error_and_finish(err_message: str, current_response: dict):
        current_response["status"] = "failed"
        current_response["success"] = False
        current_response["messages"].append(err_message)
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=f"Error: {err_message}")]))        
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=json.dumps(current_response, indent=2))]),
        )

    # Emit initial message
    yield Event(
        author=event_author_name,
        content=types.Content(role='assistant', parts=[types.Part(text=f"Initiating Create Business Glossary from Knowledge Engine scan workflow for '{knowledge_engine_scan_name}'.")])
    )
    response["messages"].append(f"Workflow initiated for {knowledge_engine_scan_name}.")


    # --- Step 1: Load Knowledge Engine Scan ---
    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 1/5: Load Knowledge Engine Scan.")])
        )

        get_knowledge_engine_scan_response = await get_knowledge_engine_scan(knowledge_engine_scan_name)

        if get_knowledge_engine_scan_response["status"] == "failed":
            raise Exception(f"Failed to load knowledge engine scan definition.")
        
        success_message = f"Successfully loaded knowledge engine scan definition: {knowledge_engine_scan_name}."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)
    
        suggested_terms = get_knowledge_engine_scan_response.get("results", {}).get("knowledgeEngineResult", {}).get("datasetResult", {}).get("businessGlossary", {}).get("terms", [])

        if not suggested_terms:
            response["status"] = "failed"
            response["success"] = False
            response["messages"].extend((get_knowledge_engine_scan_response.get("messages", [])) )            
            raise Exception(f"Failed to load glossary terms within the knowledge engine scan definition.")
    
        success_message = f"Successfully loaded knowledge engine scan glossary terms: {knowledge_engine_scan_name}."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed to load knowledge engine scan. Error: {e}", response):
            yield error_event
        return
    

    # --- Step 2: Call Gemini to create categories ---
    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 2/5: Call Gemini to create categories.")])
        )
        
        # Format terms for the LLM prompt
        formatted_terms = "\n".join([f"- Title: {t['title']}, Description: {t['description']}" for t in suggested_terms])

        prompt = f"""You are an expert in data governance and business glossary creation.
        Based on the following list of business terms and their descriptions, propose 2 to 10 distinct business glossary categories.
        Then place each term into their perspective category.
        Each term should be in one and only one category.
        You must classify every term into a category.

        Each category should have:
        1.  A 'category_id' (string): A unique, kebab-case identifier (e.g., "sales-operations", "customer-data").
        2.  A 'display_name' (string): A user-friendly name. The first and last character cannot be a space.  Also, avoid special characters, stick to A to Z.
        3.  A 'description' (string): A brief explanation of what terms would belong to this category.  Also, avoid special characters, stick to A to Z.
        4.  A 'terms' (array): A list of term title's that apply for the category id.

        Here are the terms:
        {formatted_terms}
        """

        # Define the response schema for the LLM
        category_schema = {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "category_id": {"type": "string", "description": "Unique, kebab-case identifier for the category."},
                    "display_name": {"type": "string", "description": "A user-friendly name. The first and last character cannot be a space."},
                    "description": {"type": "string", "description": "Brief description of the category."},
                    "terms": {"type": "array", "description": "The terms that belong to this category.", "items": {"type": "string"} }
                },
                "required": ["category_id", "display_name", "description", "terms"]
            }
        }
        
        gemini_response = await gemini_helper.gemini_llm(prompt, response_schema=category_schema, model="gemini-2.5-flash", temperature=0.2)
        gemini_response_dict = json.loads(gemini_response)

        success_message = f"Successfully called Gemini to determine the business glossary details."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed to Call Gemini to create categories. Error: {e}", response):
            yield error_event
        return


    # --- Step 3: Create the business glossary ---
    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 3/5: Create the business glossary {glossary_id}.")])
        )
        
        # Code
        create_business_glossary_response = await business_glossary_tools.create_business_glossary(glossary_id, glossary_display_name, glossary_description)

        if create_business_glossary_response["status"] == "success":
            if create_business_glossary_response["exists"] == False:
                success_message = f"Created glossary: {glossary_id}"
                yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))

                sleep_seconds = 15
                success_message = f"Sleeping for {sleep_seconds}"
                yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
                await wait_tool.wait_for_seconds(sleep_seconds)
            else:
                success_message = f"Glossary: {glossary_id} already exists."
                yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)])) 
        else:
            response["status"] = "failed"
            response["success"] = False
            response["messages"].extend(create_business_glossary_response.get("messages", []))
            raise Exception(f"Failed to create glossary {glossary_id}.")            

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed to Create Business Glossary. Error: {e}", response):
            yield error_event
        return


    # --- Step 4: Create the categories ---
    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 4/5: Create the categories.")])
        )
        
        # Code
        for item in gemini_response_dict:
            yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=f"Creating category: {item['category_id']}")]))

            sanitized_category_id = re.sub(r'[^\w\s-]', '', item["category_id"]).lower()
            sanitized_category_id = re.sub(r'[\s_]+', '-', sanitized_category_id).strip('-')                
            category_id = sanitized_category_id
            category_display_name = sanitized_category_id # item["display_name"]
            category_description = sanitized_category_id # item["description"]

            create_business_glossary_category_response = await business_glossary_tools.create_business_glossary_category(glossary_id, category_id, category_display_name, category_description)

            if create_business_glossary_category_response["status"] == "success":
                if create_business_glossary_category_response["exists"] == False:
                    success_message = f"Created category: {category_display_name}"
                    yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
                else:
                    success_message = f"Category: {category_display_name} already exists."
                    yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)])) 
            else:
                response["status"] = "failed"
                response["success"] = False
                response["messages"].extend(create_business_glossary_category_response.get("messages", []))
                raise Exception(f"Failed to create category {category_display_name}.")
        
        success_message = f"Successfully created business glossary categories."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed to create business glossary categories. Error: {e}", response):
            yield error_event
        return
    

    # --- Step 5: Create the terms under each category ---
    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 5/5: Call Gemini to create categories.")])
        )
        
        terms_array = get_knowledge_engine_scan_response["results"]["knowledgeEngineResult"]["datasetResult"]["businessGlossary"]["terms"]

        # Code
        for item in gemini_response_dict:
            sanitized_category_id = re.sub(r'[^\w\s-]', '', item["category_id"]).lower()
            sanitized_category_id = re.sub(r'[\s_]+', '-', sanitized_category_id).strip('-')                
            category_id = sanitized_category_id

            for term_item in item["terms"]:
                yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=f"Creating term: {term_item}")]))

                sanitized_term_id = re.sub(r'[^\w\s-]', '', term_item).lower()
                sanitized_term_id = re.sub(r'[\s_]+', '-', sanitized_term_id).strip('-')                
                term_id = sanitized_term_id
                term_display_name = term_item
                term_description = "(Failed to find term)"

                # Iterate through the list of term dictionaries
                for terms_array_item in terms_array:
                    if terms_array_item.get("title") == term_display_name:
                        term_description = terms_array_item.get("description")
                        break
                
                create_business_glossary_term_response = await business_glossary_tools.create_business_glossary_term(glossary_id, term_id, term_display_name, term_description, category_id)
                
                if create_business_glossary_term_response["status"] == "success":
                    if create_business_glossary_term_response["exists"] == True:
                        success_message = f"Created Term: {term_display_name} under category {category_display_name}."
                        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
                    else:
                        success_message = f"Term: {term_display_name} already exists."
                        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))                      

                    success_message = f"Sleeping to avoid API limites for 1 second"
                    yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))                     
                    await wait_tool.wait_for_seconds(1)
                else:
                    response["status"] = "failed"
                    response["success"] = False
                    response["messages"].extend(create_business_glossary_term_response.get("messages", []))
                    raise Exception(f"Failed to create term {term_display_name}.")
        
        success_message = f"Successfully created business terms."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed to create business terms. Error: {e}", response):
            yield error_event
        return
    

    # --- Workflow Complete ---
    final_overall_message = "Create Business Glossary from Knowledge Engine scan workflow completed successfully!" if response["success"] else "Create Business Glossary from Knowledge Engine scan workflow completed with failures."
    yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=final_overall_message)]))
    response["messages"].append(final_overall_message)

    # Do not yield the entire json summary
    # yield Event(
    #     author=event_author_name,
    #     content=types.Content(role='assistant', parts=[types.Part(text=json.dumps(response, indent=2))]),
    # )