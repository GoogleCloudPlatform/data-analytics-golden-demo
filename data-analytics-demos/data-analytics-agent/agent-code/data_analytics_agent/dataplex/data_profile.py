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
import data_analytics_agent.rest_api_helper as rest_api_helper # Assuming this is now your async version
import logging
import re

logger = logging.getLogger(__name__)


dataprofile_agent_instruction="""You are a specialist **Dataplex Scan Management Agent**. Your purpose is to manage the lifecycle of data profile scans on BigQuery tables. You can create new scans, run existing ones, check their status, and list all available scans. Your primary goal is to help users understand the content and structure of their data by running these automated profiles.

**Your Operational Playbooks (Workflows):**

You must follow these logical workflows to fulfill user requests. Do not call tools out of sequence.

**Workflow 1: Creating and Running a New Data Profile Scan**

This is the most common workflow. Use this when a user says, "profile my table," "create a data scan for `my_table`," or "I want to see the profile for `dataset.table`."

1.  **Gather Information:** You need three pieces of information from the user. Ask for them if they are not provided:
    *   `bigquery_dataset_name`
    *   `bigquery_table_name`
    *   A `data_profile_scan_name` (you can suggest a name based on the table, e.g., `my_dataset_my_table_profile_01`. You can do 02 if 01 exists).

2.  **Step 1: Create the Scan Definition:**
    *   Call `create_data_profile_scan(...)` with the gathered information.
    *   This tool automatically checks if the scan already exists. If it does, it will report success, and you can proceed to the next step. If it's new, it will initiate the creation.

3.  **Step 2: Link the Scan to BigQuery:**
    *   **This is a CRITICAL, non-optional step.** For the results to be visible in the BigQuery UI, you MUST link the scan.
    *   Call `update_bigquery_table_dataplex_labels(...)` using the `dataplex_scan_name`, `bigquery_dataset_name`, and `bigquery_table_name`.
    *   Inform the user that you are "linking the scan to the BigQuery table so results will be visible."

4.  **Step 3: Start the Scan Job:**
    *   Call `start_data_profile_scan(data_profile_scan_name=...)`.
    *   Inform the user that you have started the scan and it may take a few minutes to complete.
    *   **Crucially, capture the `job.name` from the results of this tool.** You will need this full resource name for the next step.

5.  **Step 4: Monitor the Scan Job:**
    *   You must now monitor the job to completion.
    *   Use the `job.name` from the previous step and call `get_data_profile_scan_state(data_profile_scan_job_name=...)`.
    *   The `state` will likely be "RUNNING" or "PENDING".
    *   If the `state` is still "RUNNING" or "PENDING", you **must call the `wait_for_seconds` tool** with a random duration between 15 and 30 seconds.
    *   After the wait, you should then re-poll `get_data_profile_scan_state`.
    *   Repeat this polling and waiting until the `state` is "SUCCEEDED", "FAILED", or "CANCELLED".
    *   Report the final status to the user. If it succeeded, tell them, "The data profile scan has completed successfully. You can now view the results in the 'Data profile' tab of the table in the BigQuery console."

**Workflow 2: Running an Existing Scan**

Use this when a user says, "re-run the profile for `my_table`" or "start the `my_scan_name` scan."

1.  **Gather Information:** You only need the `data_profile_scan_name`.
2.  **Verify Existence:** Before trying to run it, call `exists_data_profile_scan(data_profile_scan_name=...)`. If it returns `false`, inform the user the scan doesn't exist and ask if they want to create it (initiating Workflow 1).
3.  **Start and Monitor:** If the scan exists, proceed directly to **Step 3 and Step 4** of **Workflow 1** (Start the Scan Job and Monitor the Scan Job).

**Workflow 3: Listing Available Scans**

Use this for simple discovery questions like, "what data profile scans exist?" or "list all my scans."

1.  **Execute:** Call `get_data_profile_scans()`.
2.  **Present Results:** Do not just dump the JSON. Summarize the results for the user. For each scan in the `dataScans` list, present the `displayName` and the target table from the `data.resource` field.

**Workflow 4: Listing Available Scans for a table**

Use this for simple discovery questions like, "what data profile scans exist on table" or "list all my profile scans on my tables in dataset."

1.  **Execute:** Verify the dataset name by calling the tool `get_bigquery_dataset_list`. Do not trust the user input, look it up.
2.  **Execute:** Verify the table name by calling the tool `get_bigquery_table_list`. Do not trust the user input, look it up.
3.  **Execute:** Call the tool `get_data_profile_scans_for_table` with the dataset_id and table_name.
4.  **Present Results:** Do not just dump the JSON. Summarize the results for the user. For each scan in the `dataScans` list, present the table name passed to the tool, `name`, `displayName` and `description`.

**General Principles:**

*   **Be Proactive and Guiding:** You are a manager, not just a tool executor. Guide the user through the process. For example: "Okay, I will create a data profile scan for that table. This involves several steps: creating the scan, linking it to BigQuery, running it, and monitoring it to completion. I'll keep you updated."
*   **Handle Job Names:** The `data_profile_scan_job_name` required by `get_data_profile_scan_state` is a *long, full resource path*. It is only returned by the `start_data_profile_scan` tool. You must capture and use it correctly. It is NOT the same as the short `data_profile_scan_name`.

**Protocol for Off-Topic and Out-of-Scope Requests:**
**CRITICAL TRIGGER:** You **MUST** transfer the user back to the coordinator if the user's verbatim prompt is **exactly** "Create a scan workflow".
"""


def get_data_profile_scans() -> dict: # Changed to def
    """
    Lists all Dataplex data profile scans in the configured region.

    This function specifically filters the results to include only scans of
    type 'DATA_PROFILE'.

    Returns:
        dict: A dictionary containing the status and the list of data profile scans.
        {
            "status": "success" or "failed",
            "tool_name": "get_data_profile_scans",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "dataScans": [ ... list of scan objects of type DATA_PROFILE ... ]
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

        # Filter the returned scans to only include those of type 'DATA_PROFILE'
        all_scans = json_result.get("dataScans", [])
        
        # Using a list comprehension for a concise filter
        profile_scans_only = [
            scan for scan in all_scans if scan.get("type") == "DATA_PROFILE"
        ]

        messages.append(f"Filtered results. Found {len(profile_scans_only)} data profile scans.")

        # Create the final results payload with the filtered list
        filtered_results = {"dataScans": profile_scans_only}

        return {
            "status": "success",
            "tool_name": "get_data_profile_scans",
            "query": None,
            "messages": messages,
            "results": filtered_results
        }
    except Exception as e:
        messages.append(f"An error occurred while listing data profile scans: {e}")
        return {
            "status": "failed",
            "tool_name": "get_data_profile_scans",
            "query": None,
            "messages": messages,
            "results": None
        }


def get_data_profile_scans_for_table(dataset_id:str, table_name:str) -> dict: # Changed to def
    """
    Lists all Dataplex data profile scan attached to the table.

    This function specifically filters the results to include only scans of
    type 'DATA_PROFILE' and assigned to the dataset id/name and table name.

    Args:
        dataset_id (str): The ID (or name) of the BigQuery dataset.
        table_name (str): The BigQuery table to check for data profile scans.

    Returns:
        dict: A dictionary containing the status and the list of data profile scans.
        {
            "status": "success" or "failed",
            "tool_name": "get_data_profile_scans_for_table",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "dataScans": [ ... list of scan objects of type data_profile ... ]
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

        # Filter the returned scans to only include those of type 'DATA_PROFILE'
        all_scans = json_result.get("dataScans", [])

        # Using a list comprehension for a concise filter
        profile_scans_only = []

        for item in all_scans:
            if item.get("type") == "DATA_PROFILE" and \
               item.get("data", {}).get("resource").lower() == f"//bigquery.googleapis.com/projects/{project_id}/datasets/{dataset_id}/tables/{table_name}".lower():
                profile_scans_only.append(item)
            
        messages.append(f"Filtered results. Found {len(profile_scans_only)} data profile scans for dataset {dataset_id}.")

        # Create the final results payload with the filtered list
        filtered_results = {"dataScans": profile_scans_only}

        return {
            "status": "success",
            "tool_name": "get_data_profile_scans_for_table",
            "query": None,
            "messages": messages,
            "results": filtered_results
        }
    except Exception as e:
        messages.append(f"An error occurred while listing data profile scans: {e}")
        return {
            "status": "failed",
            "tool_name": "get_data_profile_scans_for_table",
            "query": None,
            "messages": messages,
            "results": None
        }


def exists_data_profile_scan(data_profile_scan_name: str) -> dict: # Changed to def
    """
    Checks if a Dataplex data profile scan already exists by checking the full list.

    Args:
        data_profile_scan_name (str): The short name/ID of the data profile scan.

    Returns:
        dict: A dictionary containing the status and results of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "exists_data_profile_scan",
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
    list_result = get_data_profile_scans() # Added await
    messages = list_result.get("messages", [])

    # If listing scans failed, propagate the failure.
    if list_result["status"] == "failed":
        return {
            "status": "failed",
            "tool_name": "exists_data_profile_scan",
            "query": None,
            "messages": messages,
            "results": None
        }

    try:
        scan_exists = False
        json_payload = list_result.get("results", {})
        full_scan_name_to_find = f"projects/{project_id}/locations/{dataplex_region}/dataScans/{data_profile_scan_name}"

        # Loop through the list of scans from the results
        for item in json_payload.get("dataScans", []):
            if item.get("name") == full_scan_name_to_find:
                scan_exists = True
                messages.append(f"Found matching scan: '{data_profile_scan_name}'.")
                break
        
        if not scan_exists:
            messages.append(f"Scan '{data_profile_scan_name}' does not exist.")

        return {
            "status": "success",
            "tool_name": "exists_data_profile_scan",
            "query": None,
            "messages": messages,
            "results": {"exists": scan_exists}
        }
    except Exception as e: # Catch potential errors while processing the list
        messages.append(f"An unexpected error occurred while processing scan list: {e}")
        return {
            "status": "failed",
            "tool_name": "exists_data_profile_scan",
            "query": None,
            "messages": messages,
            "results": None
        }


def create_data_profile_scan(data_profile_scan_name: str, data_profile_display_name: str, bigquery_dataset_name: str, bigquery_table_name: str) -> dict: # Changed to def
    """
    Creates a new Dataplex data profile scan if it does not already exist.

    Args:
        data_profile_scan_name (str): The short name/ID for the new data profile scan.
        data_profile_display_name (str): The user-friendly display name for the scan.
        bigquery_dataset_name (str): The BigQuery dataset of the table to be scanned.
        bigquery_table_name (str): The BigQuery table to be scanned.

    Returns:
        dict: A dictionary containing the status and results of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "create_data_profile_scan",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": { ... response from the API call ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    
    # First, check if the data profile scan already exists.
    existence_check = exists_data_profile_scan(data_profile_scan_name) # Added await
    messages = existence_check.get("messages", [])
    
    # If the check failed, propagate the failure.
    if existence_check["status"] == "failed":
        return {
            "status": "failed",
            "tool_name": "create_data_profile_scan",
            "query": None,
            "messages": messages,
            "results": None
        }

    # If the scan already exists, report success and stop.
    if existence_check["results"]["exists"]:
        full_scan_name = f"projects/{project_id}/locations/{dataplex_region}/dataScans/{data_profile_scan_name}"
        return {
            "status": "success",
            "tool_name": "create_data_profile_scan",
            "query": None,
            "messages": messages,
            "results": {"name": full_scan_name, "created": False}
        }

    # If the scan does not exist, proceed with creation.
    messages.append(f"Creating Data Profile Scan '{data_profile_scan_name}'.")
    
    # API endpoint to create a data scan. The scan ID is passed as a query parameter.
    # https://cloud.google.com/dataplex/docs/reference/rest/v1/projects.locations.dataScans/create
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans?dataScanId={data_profile_scan_name}"

    # The resource path for the BigQuery table to be scanned.
    bigquery_resource_path = f"//bigquery.googleapis.com/projects/{project_id}/datasets/{bigquery_dataset_name}/tables/{bigquery_table_name}"

    request_body = {
        "dataProfileSpec": {"samplingPercent": 25},
        "data": {"resource": bigquery_resource_path},
        "description": data_profile_display_name,
        "displayName": data_profile_display_name
    }

    try:
        # The create API returns a long-running operation object.
        json_result = rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await
        
        operation_name = json_result.get("name", "Unknown Operation")
        messages.append(f"Successfully initiated Data Profile Scan creation. Operation: {operation_name}")

        return {
            "status": "success",
            "tool_name": "create_data_profile_scan",
            "query": None,
            "messages": messages,
            "results": json_result
        }

    except Exception as e:
        messages.append(f"An error occurred while creating the data profile scan: {e}")
        return {
            "status": "failed",
            "tool_name": "create_data_profile_scan",
            "query": None,
            "messages": messages,
            "results": None
        }    


def start_data_profile_scan(data_profile_scan_name: str) -> dict: # Changed to def
    """
    Triggers a run of an existing Dataplex data profile scan.

    This initiates a new scan job. To check the status of this job, you will
    need the job name from the results and use the 'get_state_data_profile_scan' tool.

    Args:
        data_profile_scan_name (str): The short name/ID of the data profile scan to run.

    Returns:
        dict: A dictionary containing the status and the job information.
        {
            "status": "success" or "failed",
            "tool_name": "start_data_profile_scan",
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
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{data_profile_scan_name}:run"

    # The run method requires a POST request with an empty body.
    request_body = {}

    try:
        messages.append(f"Attempting to run Data Profile Scan '{data_profile_scan_name}'.")
        
        # Call the REST API to trigger the scan run.
        json_result = rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await
        
        # Extract job details for a more informative message.
        # Use .get() for safe access in case the response structure is unexpected.
        job_info = json_result.get("job", {})
        job_name = job_info.get("name", "Unknown Job")
        job_state = job_info.get("state", "Unknown State")

        messages.append(f"Successfully started Data Profile Scan job: {job_name} - State: {job_state}")

        return {
            "status": "success",
            "tool_name": "start_data_profile_scan",
            "query": None,
            "messages": messages,
            "results": json_result
        }

    except Exception as e:
        messages.append(f"An error occurred while starting the data profile scan: {e}")
        return {
            "status": "failed",
            "tool_name": "start_data_profile_scan",
            "query": None,
            "messages": messages,
            "results": None
        }    
    

def get_data_profile_scan_state(data_profile_scan_job_name: str) -> dict: # Changed to def
    """
    Gets the current state of a running data profile scan job.

    The job is created when a scan is started via 'start_data_profile_scan'.
    This function returns basic job details, suitable for polling the state.

    Args:
        data_profile_scan_job_name (str): The full resource name of the scan job, e.g., 
                                          "projects/.../locations/.../dataScans/.../jobs/...".

    Returns:
        dict: A dictionary containing the status and the job information.
        {
            "status": "success" or "failed",
            "tool_name": "get_data_profile_scan_state",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "job": {
                    "name": "projects/.../locations/.../dataScans/.../jobs/...",
                    "uid": "...",
                    "createTime": "...",
                    "startTime": "...",
                    "state": "SUCCEEDED", # or "RUNNING", "FAILED", etc.
                    # dataProfileResult will NOT be present in this light view
                }
            }
        }
    """
    messages = []
    
    # The API endpoint for getting a job's status is generic. 
    # The job name itself is the full path after the API version.
    url = f"https://dataplex.googleapis.com/v1/{data_profile_scan_job_name}"
    
    try:
        # Make a GET request to the specific job URL.
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        
        # Safely extract the state from the response.
        state = json_result.get("state", "UNKNOWN")
        messages.append(f"Data Profile job '{data_profile_scan_job_name}' is in state: {state}")

        return {
            "status": "success",
            "tool_name": "get_data_profile_scan_state",
            "query": None,
            "messages": messages,
            "results": {"job": json_result} # Return the full job object (without full dataProfileResult)
        }
    except Exception as e:
        messages.append(f"An error occurred while getting the data profile scan job state: {e}")
        return {
            "status": "failed",
            "tool_name": "get_data_profile_scan_state",
            "query": None,
            "messages": messages,
            "results": None
        }
    

def update_bigquery_table_dataplex_labels(dataplex_scan_name: str, bigquery_dataset_name: str, bigquery_table_name: str) -> dict: # Changed to def
    """
    Updates a BigQuery table's labels to link it to a Dataplex data profile scan.

    This operation is necessary for the data profile results to appear in the
    "Data profile" tab of the table details page in the BigQuery Console.

    Args:
        dataplex_scan_name (str): The short name/ID of the data profile scan to link.
        bigquery_dataset_name (str): The BigQuery dataset containing the table.
        bigquery_table_name (str): The BigQuery table to update with labels.

    Returns:
        dict: A dictionary containing the status and the BigQuery API response.
        {
            "status": "success" or "failed",
            "tool_name": "update_bigquery_table_dataplex_labels",
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
    url = f"https://bigquery.googleapis.com/bigquery/v2/projects/{project_id}/datasets/{bigquery_dataset_name}/tables/{bigquery_table_name}"

    # The request body contains the specific labels that link the table to the scan.
    request_body = {
        "labels": {
            "dataplex-dp-published-project": project_id,
            "dataplex-dp-published-location": dataplex_region,
            "dataplex-dp-published-scan": dataplex_scan_name,
        }
    }

    try:
        messages.append(f"Patching BigQuery table '{bigquery_dataset_name}.{bigquery_table_name}' with Dataplex labels.")
        
        # Call the REST API using PATCH to update the table's labels.
        json_result = rest_api_helper.rest_api_helper(url, "PATCH", request_body) # Added await
        
        messages.append("Successfully updated BigQuery table labels.")

        return {
            "status": "success",
            "tool_name": "update_bigquery_table_dataplex_labels",
            "query": None,
            "messages": messages,
            "results": json_result
        }

    except Exception as e:
        messages.append(f"An error occurred while updating the BigQuery table labels: {e}")
        return {
            "status": "failed",
            "tool_name": "update_bigquery_table_dataplex_labels",
            "query": None,
            "messages": messages,
            "results": None
        }

def list_data_profile_scan_jobs(data_profile_scan_name: str) -> dict: # Changed to def
    """
    Lists all data profile scan jobs associated with a specific data profile scan.

    Args:
        data_profile_scan_name (str): The short name/ID of the data profile scan.

    Returns:
        dict: A dictionary containing the status and the list of data profile scan jobs.
        {
            "status": "success" or "failed",
            "tool_name": "list_data_profile_scan_jobs",
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
    # https://cloud.google.com/dataplex/docs/reference/rest/v1/projects.locations.dataScans.jobs/list
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{data_profile_scan_name}/jobs"

    try:
        messages.append(f"Attempting to list jobs for Data Profile Scan '{data_profile_scan_name}'.")
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        
        jobs = json_result.get("dataScanJobs", [])
        messages.append(f"Successfully retrieved {len(jobs)} jobs for scan '{data_profile_scan_name}'.")

        return {
            "status": "success",
            "tool_name": "list_data_profile_scan_jobs",
            "query": None,
            "messages": messages,
            "results": {"jobs": jobs}
        }
    except Exception as e:
        messages.append(f"An error occurred while listing data profile scan jobs: {e}")
        return {
            "status": "failed",
            "tool_name": "list_data_profile_scan_jobs",
            "query": None,
            "messages": messages,
            "results": None
        }

def delete_data_profile_scan_job(data_profile_scan_job_name: str) -> dict: # Changed to def
    """
    Deletes a specific Dataplex data profile scan job.

    Args:
        data_profile_scan_job_name (str): The full resource name of the scan job, e.g.,
                                          "projects/.../locations/.../dataScans/.../jobs/...".

    Returns:
        dict: A dictionary containing the status of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "delete_data_profile_scan_job",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {} # Empty dictionary on success
        }
    """
    messages = []
    
    # The URL for deleting a job is the job's full resource path.
    # https://cloud.google.com/dataplex/docs/reference/rest/v1/projects.locations.dataScans.jobs/delete
    url = f"https://dataplex.googleapis.com/v1/{data_profile_scan_job_name}"
    
    try:
        messages.append(f"Attempting to delete Data Profile Scan job: '{data_profile_scan_job_name}'.")
        # DELETE operation typically returns an empty response or an Operation object
        rest_api_helper.rest_api_helper(url, "DELETE", None) # Added await
        messages.append(f"Successfully deleted Data Profile Scan job: '{data_profile_scan_job_name}'.")
        return {
            "status": "success",
            "tool_name": "delete_data_profile_scan_job",
            "query": None,
            "messages": messages,
            "results": {}
        }
    except Exception as e:
        messages.append(f"An error occurred while deleting data profile scan job '{data_profile_scan_job_name}': {e}")
        return {
            "status": "failed",
            "tool_name": "delete_data_profile_scan_job",
            "query": None,
            "messages": messages,
            "results": None
        }

def delete_data_profile_scan(data_profile_scan_name: str) -> dict: # Changed to def
    """
    Deletes a specific Dataplex data profile scan definition.
    This operation only succeeds if there are no associated scan jobs.
    The agent's workflow should ensure jobs are deleted first.

    Args:
        data_profile_scan_name (str): The short name/ID of the data profile scan to delete.

    Returns:
        dict: A dictionary containing the status of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "delete_data_profile_scan",
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
    # https://cloud.google.com/dataplex/docs/reference/rest/v1/projects.locations.dataScans/delete
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{data_profile_scan_name}"

    try:
        messages.append(f"Attempting to delete Data Profile Scan definition: '{data_profile_scan_name}'.")
        # DELETE operation typically returns an empty response or an Operation object
        rest_api_helper.rest_api_helper(url, "DELETE", None) # Added await
        messages.append(f"Successfully deleted Data Profile Scan definition: '{data_profile_scan_name}'.")
        return {
            "status": "success",
            "tool_name": "delete_data_profile_scan",
            "query": None,
            "messages": messages,
            "results": {}
        }
    except Exception as e:
        messages.append(f"An error occurred while deleting data profile scan definition '{data_profile_scan_name}': {e}")
        return {
            "status": "failed",
            "tool_name": "delete_data_profile_scan",
            "query": None,
            "messages": messages,
            "results": None
        }


def get_data_profile_scan_job_full_details(data_profile_scan_job_name: str) -> dict: # Changed to def
    """
    Fetches the full details of a specific Dataplex data profile scan job,
    including the complete data profile results.

    Args:
        data_profile_scan_job_name (str): The full resource name of the scan job, e.g., 
                                          "projects/.../locations/.../dataScans/.../jobs/...".

    Returns:
        dict: A dictionary containing the status and the full job details.
        {
            "status": "success" or "failed",
            "tool_name": "get_data_profile_scan_job_full_details",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "job": {
                    "name": "projects/.../locations/.../dataScans/.../jobs/...",
                    "uid": "...",
                    "createTime": "...",
                    "startTime": "...",
                    "state": "SUCCEEDED",
                    "dataProfileResult": { ... full data profile payload ... }
                    // ... other job attributes
                }
            }
        }
    """
    messages = []
    
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")

    # Parse the incoming data_profile_scan_job_name to extract scan_id and job_id.
    # This allows us to reconstruct the URL using the correct project_id (alphanumeric)
    # and dataplex_region from environment variables.
    # Example job_name format: projects/PROJECT_NUMBER/locations/LOCATION/dataScans/SCAN_ID/jobs/JOB_ID
    match = re.match(r"projects/[^/]+/locations/[^/]+/dataScans/([^/]+)/jobs/([^/]+)", data_profile_scan_job_name)
    
    if not match:
        messages.append(f"Invalid data_profile_scan_job_name format: {data_profile_scan_job_name}")
        return {
            "status": "failed",
            "tool_name": "get_data_profile_scan_job_full_details",
            "query": None,
            "messages": messages,
            "results": None
        }
    
    scan_id = match.group(1)
    job_id = match.group(2)

    # Reconstruct the URL using the correct project_id and region from env vars
    # and include the '?view=FULL' parameter to get the full profile results.
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{scan_id}/jobs/{job_id}?view=FULL"
    
    try:
        messages.append(f"Attempting to retrieve full data profile job details for: {data_profile_scan_job_name} with view=FULL.")
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        
        # Check if dataProfileResult is present, which indicates a successful full fetch for a completed job.
        if not json_result.get("dataProfileResult"):
            job_state = json_result.get("state")
            if job_state and job_state != "SUCCEEDED":
                messages.append(f"Job state is '{job_state}'. Full data profile results are typically available only for 'SUCCEEDED' jobs.")
            else:
                messages.append("Data profile results are not present in the job details. This might indicate an incomplete or failed profile generation.")
        
        messages.append(f"Successfully retrieved full job details for '{data_profile_scan_job_name}'.")
        return {
            "status": "success",
            "tool_name": "get_data_profile_scan_job_full_details",
            "query": None,
            "messages": messages,
            "results": {"job": json_result}
        }
    except Exception as e:
        messages.append(f"An error occurred while retrieving full data profile job details: {e}")
        return {
            "status": "failed",
            "tool_name": "get_data_profile_scan_job_full_details",
            "query": None,
            "messages": messages,
            "results": None
        }