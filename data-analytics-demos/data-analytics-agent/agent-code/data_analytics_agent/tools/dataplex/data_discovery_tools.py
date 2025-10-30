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


logger = logging.getLogger(__name__)


async def list_gcs_buckets() -> dict: 
    """
    Lists all Google Cloud Storage (GCS) buckets in the current project.

    Returns:
        dict: A dictionary containing the status and a list of GCS bucket names.
        {
            "status": "success" or "failed",
            "tool_name": "list_gcs_buckets",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "buckets": [ "bucket_name_1", "bucket_name_2", ... ]
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    messages = []
    # Google Cloud Storage JSON API endpoint for listing buckets
    # https://cloud.google.com/storage/docs/json_api/v1/buckets/list
    url = f"https://storage.googleapis.com/storage/v1/b?project={project_id}"

    try:
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) 
        messages.append("Successfully retrieved list of GCS buckets from the API.")

        buckets = [item['name'] for item in json_result.get("items", [])]

        messages.append(f"Found {len(buckets)} GCS buckets.")

        return {
            "status": "success",
            "tool_name": "list_gcs_buckets",
            "query": None,
            "messages": messages,
            "results": {"buckets": buckets}
        }
    except Exception as e:
        messages.append(f"An error occurred while listing GCS buckets: {e}")
        return {
            "status": "failed",
            "tool_name": "list_gcs_buckets",
            "query": None,
            "messages": messages,
            "results": None
        }


async def get_data_discovery_scans() -> dict: 
    """
    Lists all Dataplex data discovery scans in the configured region.

    This function specifically filters the results to include only scans of
    type 'DATA_DISCOVERY'.

    Returns:
        dict: A dictionary containing the status and the list of data discovery scans.
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    messages = []
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans"

    try:
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) 
        messages.append("Successfully retrieved list of all data scans from the API.")

        all_scans = json_result.get("dataScans", [])
        discovery_scans_only = [
            scan for scan in all_scans if scan.get("type") == "DATA_DISCOVERY"
        ]
        messages.append(f"Filtered results. Found {len(discovery_scans_only)} data discovery scans.")

        filtered_results = {"dataScans": discovery_scans_only}

        return {
            "status": "success",
            "tool_name": "get_data_discovery_scans",
            "query": None,
            "messages": messages,
            "results": filtered_results
        }
    except Exception as e:
        messages.append(f"An error occurred while listing data discovery scans: {e}")
        return {
            "status": "failed",
            "tool_name": "get_data_discovery_scans",
            "query": None,
            "messages": messages,
            "results": None
        }


async def get_data_discovery_scans_for_bucket(gcs_bucket_name:str) -> dict: 
    """
    Lists all Dataplex data discovery scan attached to the table.

    This function specifically filters the results to include only scans of
    type 'DATA_DISCOVERY' and assigned to the dataset id/name and table name.

    Args:
        gcs_bucket_name (str): The name of the GCS bucket to scan (e.g., 'my-bucket').

    Returns:
        dict: A dictionary containing the status and the list of data discovery scans.
        {
            "status": "success" or "failed",
            "tool_name": "get_data_discovery_scans_for_bucket",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "dataScans": [ ... list of scan objects of type data_discovery ... ]
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
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) 
        messages.append("Successfully retrieved list of all data scans from the API.")

        # Filter the returned scans to only include those of type 'DATA_discovery'
        all_scans = json_result.get("dataScans", [])

        # Using a list comprehension for a concise filter
        discovery_scans_only = []

        for item in all_scans:
            if item.get("type") == "DATA_DISCOVERY" and \
               item.get("data", {}).get("resource").lower() == f"//storage.googleapis.com/projects/{project_id}/buckets/{gcs_bucket_name}".lower():
                discovery_scans_only.append(item)
            
        messages.append(f"Filtered results. Found {len(discovery_scans_only)} data discovery scans for bucket {gcs_bucket_name}.")

        # Create the final results payload with the filtered list
        filtered_results = {"dataScans": discovery_scans_only}

        return {
            "status": "success",
            "tool_name": "get_data_discovery_scans_for_bucket",
            "query": None,
            "messages": messages,
            "results": filtered_results
        }
    except Exception as e:
        messages.append(f"An error occurred while listing data discovery scans: {e}")
        return {
            "status": "failed",
            "tool_name": "get_data_discovery_scans_for_bucket",
            "query": None,
            "messages": messages,
            "results": None
        }


async def exists_data_discovery_scan(data_discovery_scan_name: str) -> dict: 
    """
    Checks if a Dataplex data discovery scan already exists.

    Args:
        data_discovery_scan_name (str): The short name/ID of the data discovery scan.

    Returns:
        dict: A dictionary containing the status and a boolean result.
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")

    list_result = await get_data_discovery_scans() 
    messages = list_result.get("messages", [])

    if list_result["status"] == "failed":
        return list_result

    try:
        scan_exists = False
        full_scan_name_to_find = f"projects/{project_id}/locations/{dataplex_region}/dataScans/{data_discovery_scan_name}"

        for item in list_result.get("results", {}).get("dataScans", []):
            if item.get("name") == full_scan_name_to_find:
                scan_exists = True
                messages.append(f"Found matching data discovery scan: '{data_discovery_scan_name}'.")
                break
        
        if not scan_exists:
            messages.append(f"Data discovery scan '{data_discovery_scan_name}' does not exist.")

        return {
            "status": "success",
            "tool_name": "exists_data_discovery_scan",
            "query": None,
            "messages": messages,
            "results": {"exists": scan_exists}
        }
    except Exception as e:
        messages.append(f"An unexpected error occurred while processing scan list: {e}")
        return {
            "status": "failed",
            "tool_name": "exists_data_discovery_scan",
            "query": None,
            "messages": messages,
            "results": None
        }


async def create_data_discovery_scan(data_discovery_scan_name: str, display_name: str, gcs_bucket_name: str, biglake_connection_name: str) -> dict: 
    """
    Creates a new Dataplex data discovery scan for a GCS bucket to create BigLake tables.

    Args:
        data_discovery_scan_name (str): The short name/ID for the new scan.
        display_name (str): The user-friendly display name for the scan.
        gcs_bucket_name (str): The name of the GCS bucket to scan (e.g., 'my-bucket').
        biglake_connection_name (str): The full resource name of the BigLake connection.
                                      e.g., "projects/.../locations/.../connections/..."

    Returns:
        dict: A dictionary containing the status and results of the operation.
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    
    existence_check = await exists_data_discovery_scan(data_discovery_scan_name) 
    messages = existence_check.get("messages", [])
    
    if existence_check["status"] == "failed":
        return existence_check

    if existence_check["results"]["exists"]:
        full_scan_name = f"projects/{project_id}/locations/{dataplex_region}/dataScans/{data_discovery_scan_name}"
        return {
            "status": "success",
            "tool_name": "create_data_discovery_scan",
            "query": None,
            "messages": messages,
            "results": {"name": full_scan_name, "created": False}
        }

    messages.append(f"Creating Data Discovery Scan '{data_discovery_scan_name}'.")
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans?dataScanId={data_discovery_scan_name}"
    gcs_resource_path = f"//storage.googleapis.com/projects/{project_id}/buckets/{gcs_bucket_name}"

    request_body = {
        "displayName": display_name,
        "type": "DATA_DISCOVERY",
        "data": {"resource": gcs_resource_path},
        "dataDiscoverySpec": {
            "storageConfig": {
                "csvOptions": {"delimiter": ",", "headerRows": 1}
            },
            "bigqueryPublishingConfig": {
                "connection": biglake_connection_name,
                "tableType": "BIGLAKE"
            }
        }
    }

    try:
        json_result = await rest_api_helper.rest_api_helper(url, "POST", request_body) 
        messages.append(f"Successfully initiated Data Discovery Scan creation for '{data_discovery_scan_name}'.")
        return {
            "status": "success",
            "tool_name": "create_data_discovery_scan",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while creating the data discovery scan: {e}")
        return {
            "status": "failed",
            "tool_name": "create_data_discovery_scan",
            "query": None,
            "messages": messages,
            "results": None
        }


async def start_data_discovery_scan(data_discovery_scan_name: str) -> dict: 
    """
    Triggers a run of an existing Dataplex data discovery scan.

    Args:
        data_discovery_scan_name (str): The short name/ID of the scan to run.

    Returns:
        dict: A dictionary containing the status and the job information.
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    messages = []
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{data_discovery_scan_name}:run"
    
    try:
        messages.append(f"Attempting to run Data Discovery Scan '{data_discovery_scan_name}'.")
        json_result = await rest_api_helper.rest_api_helper(url, "POST", {}) 
        job_info = json_result.get("job", {})
        messages.append(f"Successfully started job: {job_info.get('name')} - State: {job_info.get('state')}")
        return {
            "status": "success",
            "tool_name": "start_data_discovery_scan",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while starting the data discovery scan: {e}")
        return {
            "status": "failed",
            "tool_name": "start_data_discovery_scan",
            "query": None,
            "messages": messages,
            "results": None
        }


async def get_data_discovery_scan_state(data_discovery_scan_job_name: str) -> dict: 
    """
    Gets the current state of a running data discovery scan job.

    Args:
        data_discovery_scan_job_name (str): The full resource name of the scan job, e.g., 
                                          "projects/.../locations/.../dataScans/.../jobs/...".
    """
    messages = []
    url = f"https://dataplex.googleapis.com/v1/{data_discovery_scan_job_name}"
    
    try:
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) 
        state = json_result.get("state", "UNKNOWN")
        messages.append(f"Job '{data_discovery_scan_job_name}' is in state: {state}")
        
        return {
            "status": "success",
            "tool_name": "get_data_discovery_scan_state",
            "query": None,
            "messages": messages,
            "results": {"state": state}
        }
    except Exception as e:
        messages.append(f"An error occurred while getting the data discovery scan job state: {e}")
        return {
            "status": "failed",
            "tool_name": "get_data_discovery_scan_state",
            "query": None,
            "messages": messages,
            "results": None
        }

async def list_data_discovery_scan_jobs(data_discovery_scan_name: str) -> dict: 
    """
    Lists all data discovery scan jobs associated with a specific data discovery scan.

    Args:
        data_discovery_scan_name (str): The short name/ID of the data discovery scan.

    Returns:
        dict: A dictionary containing the status and the list of data discovery scan jobs.
        {
            "status": "success" or "failed",
            "tool_name": "list_data_discovery_scan_jobs",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "jobs": [ ... list of scan job objects ... ]
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    messages = []

    # API endpoint to list jobs for a specific data scan.
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{data_discovery_scan_name}/jobs"

    try:
        messages.append(f"Attempting to list jobs for Data Discovery Scan '{data_discovery_scan_name}'.")
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) 
        
        jobs = json_result.get("dataScanJobs", [])
        messages.append(f"Successfully retrieved {len(jobs)} jobs for scan '{data_discovery_scan_name}'.")

        return {
            "status": "success",
            "tool_name": "list_data_discovery_scan_jobs",
            "query": None,
            "messages": messages,
            "results": {"jobs": jobs}
        }
    except Exception as e:
        messages.append(f"An error occurred while listing data discovery scan jobs: {e}")
        return {
            "status": "failed",
            "tool_name": "list_data_discovery_scan_jobs",
            "query": None,
            "messages": messages,
            "results": None
        }


async def delete_data_discovery_scan_job(data_discovery_scan_job_name: str) -> dict: 
    """
    Deletes a specific Dataplex data discovery scan job.

    Args:
        data_discovery_scan_job_name (str): The full resource name of the scan job, e.g.,
                                          "projects/.../locations/.../dataScans/.../jobs/...".

    Returns:
        dict: A dictionary containing the status of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "delete_data_discovery_scan_job",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {} # Empty dictionary on success
        }
    """
    messages = []
    
    # The URL for deleting a job is the job's full resource path.
    url = f"https://dataplex.googleapis.com/v1/{data_discovery_scan_job_name}"
    
    try:
        messages.append(f"Attempting to delete Data Discovery Scan job: '{data_discovery_scan_job_name}'.")
        # DELETE operation typically returns an empty response or an Operation object
        await rest_api_helper.rest_api_helper(url, "DELETE", None) 
        messages.append(f"Successfully deleted Data Discovery Scan job: '{data_discovery_scan_job_name}'.")
        return {
            "status": "success",
            "tool_name": "delete_data_discovery_scan_job",
            "query": None,
            "messages": messages,
            "results": {}
        }
    except Exception as e:
        messages.append(f"An error occurred while deleting data discovery scan job '{data_discovery_scan_job_name}': {e}")
        return {
            "status": "failed",
            "tool_name": "delete_data_discovery_scan_job",
            "query": None,
            "messages": messages,
            "results": None
        }


async def delete_data_discovery_scan(data_discovery_scan_name: str) -> dict: 
    """
    Deletes a specific Dataplex data discovery scan definition.
    This operation only succeeds if there are no associated scan jobs.
    The agent's workflow should ensure jobs are deleted first.

    Args:
        data_discovery_scan_name (str): The short name/ID of the data discovery scan to delete.

    Returns:
        dict: A dictionary containing the status of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "delete_data_discovery_scan",
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
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{data_discovery_scan_name}"

    try:
        messages.append(f"Attempting to delete Data Discovery Scan definition: '{data_discovery_scan_name}'.")
        # DELETE operation typically returns an empty response or an Operation object
        await rest_api_helper.rest_api_helper(url, "DELETE", None) 
        messages.append(f"Successfully deleted Data Discovery Scan definition: '{data_discovery_scan_name}'.")
        return {
            "status": "success",
            "tool_name": "delete_data_discovery_scan",
            "query": None,
            "messages": messages,
            "results": {}
        }
    except Exception as e:
        messages.append(f"An error occurred while deleting data discovery scan definition '{data_discovery_scan_name}': {e}")
        return {
            "status": "failed",
            "tool_name": "delete_data_discovery_scan",
            "query": None,
            "messages": messages,
            "results": None
        }


async def get_data_discovery_scan_job_full_details(data_discovery_scan_job_name: str) -> dict: 
    """
    Fetches the full details of a specific Dataplex data discovery scan job,
    including the complete data discovery results.

    Args:
        data_discovery_scan_job_name (str): The full resource name of the scan job, e.g., 
                                          "projects/.../locations/.../dataScans/.../jobs/...".

    Returns:
        dict: A dictionary containing the status and the full job details.
        {
            "status": "success" or "failed",
            "tool_name": "get_data_discovery_scan_job_full_details",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "job": {
                    "name": "projects/.../locations/.../dataScans/.../jobs/...",
                    "uid": "...",
                    "createTime": "...",
                    "startTime": "...",
                    "state": "SUCCEEDED",
                    "dataDiscoveryResult": { ... full discovery payload ... }
                    // ... other job attributes
                }
            }
        }
    """
    messages = []
    
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")

    # Parse the incoming data_discovery_scan_job_name to extract scan_id and job_id.
    # This allows us to reconstruct the URL using the correct project_id (alphanumeric)
    # and dataplex_region from environment variables.
    # Example job_name format: projects/PROJECT_NUMBER/locations/LOCATION/dataScans/SCAN_ID/jobs/JOB_ID
    match = re.match(r"projects/[^/]+/locations/[^/]+/dataScans/([^/]+)/jobs/([^/]+)", data_discovery_scan_job_name)
    
    if not match:
        messages.append(f"Invalid data_discovery_scan_job_name format: {data_discovery_scan_job_name}")
        return {
            "status": "failed",
            "tool_name": "get_data_discovery_scan_job_full_details",
            "query": None,
            "messages": messages,
            "results": None
        }
    
    scan_id = match.group(1)
    job_id = match.group(2)

    # Reconstruct the URL using the correct project_id and region from env vars
    # and include the '?view=FULL' parameter to get the full discovery results.
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{scan_id}/jobs/{job_id}?view=FULL"
    
    try:
        messages.append(f"Attempting to retrieve full data discovery job details for: {data_discovery_scan_job_name} with view=FULL.")
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) 
        
        # Check if dataDiscoveryResult is present, which indicates a successful full fetch for a completed job.
        if not json_result.get("dataDiscoveryResult"):
            job_state = json_result.get("state")
            if job_state and job_state != "SUCCEEDED":
                messages.append(f"Job state is '{job_state}'. Full data discovery results are typically available only for 'SUCCEEDED' jobs.")
            else:
                messages.append("Data discovery results are not present in the job details. This might indicate an incomplete or failed discovery.")
        
        messages.append(f"Successfully retrieved full job details for '{data_discovery_scan_job_name}'.")
        return {
            "status": "success",
            "tool_name": "get_data_discovery_scan_job_full_details",
            "query": None,
            "messages": messages,
            "results": {"job": json_result}
        }
    except Exception as e:
        messages.append(f"An error occurred while retrieving full data discovery job details: {e}")
        return {
            "status": "failed",
            "tool_name": "get_data_discovery_scan_job_full_details",
            "query": None,
            "messages": messages,
            "results": None
        }
    
################################################################################################################
# parse_create_and_run_data_discovery_scan_params
################################################################################################################
from google.adk.tools.tool_context import ToolContext
import data_analytics_agent.utils.gemini.gemini_helper as gemini_helper

async def parse_create_and_run_data_discovery_scan_params(tool_context: ToolContext, prompt: str) -> dict:
    """
    Parses a user prompt for data discovery scan details and sets them in session state for subsequent agents to use.
    """
    response_schema = {
        "type": "object",
        "properties": {
            "data_discovery_scan_name": {
                "type": "string",
                "description": "This is the data discovery scan name. If no name is provided you should create one that uses hyphens (not spaces) for seperators."
            },
            "display_name": {
                "type": "string",
                "description": "This is the data discovery display name. If no name is provided you should create one that uses spaces for seperators."
            },
            "gcs_bucket_name": {
                "type": "string",
                "description": "The matching GCS bucket name."
            },
            "biglake_connection_name": {
                "type": "string",
                "description": "The name of the BigLake connection."
            }
        },
        "required": ["gcs_bucket_name", "biglake_connection_name"]
    }

    list_gcs_buckets_helper_response = await list_gcs_buckets()
    gcs_bucket_schema = list_gcs_buckets_helper_response["results"]

    prompt_template = f"""You need to match or create the correct names for the following using the below schema information from GCS.

    The user provided the below information "original-user-prompt" and you need to extract the:
    - data_discovery_scan_name: This information may or may not be provided by the user.
        - You can create the scan name, using hyphens for seperators, and a good name would match the bucket name and then append a "-data-discovery-scan".
        - For example "my_bucket" would have a scan name of "my-bucket-data-discovery-scan".
        - Keep this to about 30 characters.
    - display_name: This information may or may not be provided by the user.
        - You can create the display name, using spaces for seperators, and a good name would match the bucket name and then append a " Data Discovery Scan".
        - For example "my_bucket" would have a display name of "My Bucket Data Discovery Scan".
        - Keep this to about 30 characters.
    - gcs_bucket_name:  This must be a match from the <gcs-bucket-schema> based upon the user's prompt.
    - biglake_connection_name: This must be provided by the user in the prompt.

    There could be misspelled words, spaces, etc. So please correct them.

    <original-user-prompt>
    {prompt}
    </original-user-prompt>

    <gcs-bucket-schema>
    {gcs_bucket_schema}
    </gcs-bucket-schema>
    """

    gemini_response = await gemini_helper.gemini_llm(prompt_template, response_schema=response_schema, model="gemini-2.5-flash", temperature=0.2)
    gemini_response_dict = json.loads(gemini_response)   

    data_discovery_scan_name = gemini_response_dict.get("data_discovery_scan_name") 
    display_name = gemini_response_dict.get("display_name") 
    gcs_bucket_name = gemini_response_dict.get("gcs_bucket_name") 
    biglake_connection_name = gemini_response_dict.get("biglake_connection_name") 

    tool_context.state["data_discovery_scan_name_param"] = data_discovery_scan_name
    tool_context.state["display_name_param"] = display_name
    tool_context.state["gcs_bucket_name_param"] = gcs_bucket_name
    tool_context.state["biglake_connection_name_param"] = biglake_connection_name
    tool_context.state["initial_data_discovery_query_param"] = prompt

    logger.info(f"parse_create_and_run_data_discovery_scan_params: data_discovery_scan_name: {data_discovery_scan_name}")
    logger.info(f"parse_create_and_run_data_discovery_scan_params: display_name: {display_name}")
    logger.info(f"parse_create_and_run_data_discovery_scan_params: gcs_bucket_name: {gcs_bucket_name}")
    logger.info(f"parse_create_and_run_data_discovery_scan_params: biglake_connection_name: {biglake_connection_name}")
    logger.info(f"parse_create_and_run_data_discovery_scan_params: initial_prompt_content: {prompt}")    

    return {
        "status": "success",
        "tool_name": "parse_and_set_data_discovery_params_tool",
        "messages": ["Data discovery parameters parsed and set in session state."],
        "results": gemini_response_dict
    }


################################################################################################################
# create_and_run_data_discovery_scan
################################################################################################################
import data_analytics_agent.utils.time_delay.wait_tool as wait_tool

from typing import AsyncGenerator
from google.genai import types
from google.adk.events import Event 

async def create_and_run_data_discovery_scan(
    data_discovery_scan_name: str,
    display_name: str,
    gcs_bucket_name: str,
    biglake_connection_name: str,
    initial_prompt_content: str,
    event_author_name: str
) -> AsyncGenerator[Event, None]:
    """
    Orchestrates the complete Dataplex Data Discovery scan workflow.
    """
    logger.info(f"[{event_author_name}] Starting Data Discovery Scan workflow for {data_discovery_scan_name}.")

    response = {
        "status": "success",
        "tool_name": "full_data_discovery_workflow",
        "query": initial_prompt_content,
        "messages": [],
        "results": {
            "data_discovery_scan_name": data_discovery_scan_name,
            "display_name": display_name,
            "gcs_bucket_name": gcs_bucket_name,
            "biglake_connection_name": biglake_connection_name,
            "data_discovery_scan_job_name": None,
            "data_discovery_scan_job_state": None,
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

    yield Event(
        author=event_author_name,
        content=types.Content(role='assistant', parts=[types.Part(text=f"Initiating full data discovery scan workflow for GCS bucket '{gcs_bucket_name}'.")])
    )
    response["messages"].append(f"Workflow initiated for {data_discovery_scan_name}.")

    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 1/4: Creating data discovery scan definition: '{data_discovery_scan_name}'.")])
        )
        create_scan_result = await create_data_discovery_scan(
            data_discovery_scan_name,
            display_name,
            gcs_bucket_name,
            biglake_connection_name
        )
        if create_scan_result["status"] != "success":
            raise Exception(f"Failed to create scan definition: {create_scan_result.get('messages', ['Unknown error'])[-1]}")
        
        success_message = f"Successfully created data discovery scan definition: {data_discovery_scan_name}. Now waiting for it to register."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed to create data discovery scan '{data_discovery_scan_name}'. Error: {e}", response):
            yield error_event
        return

    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 2/4: Waiting for scan '{data_discovery_scan_name}' to be registered and exist.")])
        )
        scan_exists = False
        max_attempts = 20
        for i in range(max_attempts):
            exists_check_result = await exists_data_discovery_scan(data_discovery_scan_name)
            if exists_check_result["status"] == "success" and exists_check_result["results"]["exists"]:
                scan_exists = True
                break
            yield Event(
                author=event_author_name,
                content=types.Content(role='assistant', parts=[types.Part(text=f"Scan not yet registered (attempt {i+1}/{max_attempts}). Waiting 2 seconds...")])
            )
            await wait_tool.wait_for_seconds(2)

        if not scan_exists:
            raise Exception(f"Scan '{data_discovery_scan_name}' did not become registered after {max_attempts * 2} seconds.")
        
        success_message = f"Data discovery scan '{data_discovery_scan_name}' is now registered and ready."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed while waiting for scan '{data_discovery_scan_name}' to register. Error: {e}", response):
            yield error_event
        return

    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 3/4: Starting the data discovery scan job for '{data_discovery_scan_name}'.")])
        )
        start_job_result = await start_data_discovery_scan(data_discovery_scan_name)
        if start_job_result["status"] != "success" or not start_job_result["results"].get("job", {}).get("name"):
            raise Exception(f"Failed to start scan job: {start_job_result.get('messages', ['Unknown error'])[-1]}")
        
        job_name = start_job_result["results"]["job"]["name"]
        response["results"]["data_discovery_scan_job_name"] = job_name
        
        success_message = f"Successfully started data discovery scan job: '{job_name}'. Monitoring its progress."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed to start data discovery scan job for '{data_discovery_scan_name}'. Error: {e}", response):
            yield error_event
        return

    job_name = response["results"]["data_discovery_scan_job_name"]
    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 4/4: Monitoring data discovery job '{job_name}' for completion.")])
        )
        job_completed = False
        final_job_state = "UNKNOWN"
        max_attempts = 100
        for i in range(max_attempts):
            job_state_result = await get_data_discovery_scan_state(job_name)
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
            raise Exception(f"Data discovery job '{job_name}' did not complete after {max_attempts * 5} seconds. Last known state: {final_job_state}")
        
        if final_job_state != "SUCCEEDED":
            raise Exception(f"Data discovery job '{job_name}' completed with state: {final_job_state}. (Expected SUCCEEDED)")

        response["results"]["data_discovery_scan_job_state"] = final_job_state
        success_message = f"Data discovery job '{job_name}' completed successfully with state: {final_job_state}."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        final_job_state = final_job_state if 'final_job_state' in locals() else 'UNKNOWN_FAILED'
        response["results"]["data_discovery_scan_job_state"] = final_job_state
        for error_event in _handle_error_and_finish(f"Data discovery job '{job_name}' failed or did not complete. Error: {e}", response):
            yield error_event
        return

    final_overall_message = "Data discovery workflow completed successfully!" if response["success"] else "Data discovery workflow completed with failures."
    yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=final_overall_message)]))
    response["messages"].append(final_overall_message)