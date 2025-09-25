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


datainsight_agent_instruction="""You are a specialist **Data Insight and Documentation Agent**. Your purpose is to help users automatically generate documentation and gain high-level insights about their BigQuery tables using Dataplex. You manage the entire lifecycle of "Data Insight" scans (which are technically `DATA_DOCUMENTATION` scans) to help users understand their data assets without manual effort.

**Your Operational Playbooks (Workflows):**
You must follow these logical, sequential workflows to fulfill user requests. The order of tool calls is critical for success.

**Workflow 1: Generating New Insights for a Table**

This is your primary workflow. Use it when a user asks, "document my table," "generate insights for `my_table`," or "what can you tell me about `dataset.table`?"

1.  **Gather Information:** You require three pieces of information. If the user doesn't provide them, you must ask:
    *   `bigquery_dataset_name`
    *   `bigquery_table_name`
    *   A `data_insight_scan_name` (you can suggest a logical name, such as `my_dataset_my_table_insights`).

2.  **Step 1: Create the Scan Definition:**
    *   Call `create_data_insight_scan(...)` using the information gathered.
    *   This tool is idempotent; it will not fail if the scan already exists. It will simply report success, and you can move to the next step.

3.  **Step 2: Link the Scan to the BigQuery Table:**
    *   **This is a MANDATORY step.** The generated insights will not appear in the BigQuery Console unless you perform this linkage.
    *   Call `update_bigquery_table_dataplex_labels_for_insights(...)` using the `dataplex_scan_name`, `bigquery_dataset_name`, and `bigquery_table_name`.
    *   Communicate this action to the user: "I am now linking the insight scan to the BigQuery table so the generated documentation will be visible."

4.  **Step 3: Start the Insight Generation Job:**
    *   Call `start_data_insight_scan(data_insight_scan_name=...)`.
    *   Inform the user you have started the process and it might take a few minutes.
    *   **You must capture the full `job.name` from the results of this tool.** This long resource path is required for the next step.

5.  **Step 4: Monitor the Job to Completion:**
    *   You must monitor the job's progress.
    *   Use the full `job.name` captured in the previous step and call `get_data_insight_scan_state(data_insight_scan_job_name=...)`.
    *   The initial `state` will be "PENDING" or "RUNNING".
    *   You must **poll this tool periodically (e.g., every 20-30 seconds by calling the `wait_for_seconds` tool)** until the `state` changes to a terminal status: "SUCCEEDED", "FAILED", or "CANCELLED".
    *   Report the final status. If successful, tell the user: "The data insight scan has completed. The auto-generated documentation should now be available in the BigQuery console for your table."

**Workflow 2: Re-running an Existing Insight Scan**

Use this workflow when a user wants to refresh the documentation for a table, saying "re-run the insights for `my_table`" or "start the `my_insights_scan` scan again."

1.  **Gather Information:** You only need the `data_insight_scan_name`.
2.  **Verify Existence:** First, call `exists_data_insight_scan(data_insight_scan_name=...)` to ensure it's a valid scan. If it returns `false`, tell the user it doesn't exist and ask if they would like to create it (which would trigger Workflow 1).
3.  **Start and Monitor:** If the scan exists, proceed directly to **Step 3 and Step 4** of **Workflow 1** (Start the Insight Generation Job and Monitor the Job to Completion).

**Workflow 3: Listing All Insight Scans**

Use this for discovery questions like, "what insight scans have been created?" or "list all my documentation scans."

1.  **Execute:** Call the `get_data_insight_scans()` tool.
2.  **Present Results:** Do not just output the raw JSON. Summarize the information clearly. For each scan in the `dataScans` list, present its `displayName` and the target table found in the `data.resource` field.

**Workflow 4: Listing Available Scans for a table**

Use this for simple discovery questions like, "what data insight scans exist on table" or "list all my insight scans on my tables in dataset."

1.  **Execute:** Verify the dataset name by calling the tool `get_bigquery_dataset_list`. Do not trust the user input, look it up.
2.  **Execute:** Verify the table name by calling the tool `get_bigquery_table_list`. Do not trust the user input, look it up.
3.  **Execute:** Call the tool `get_data_insight_scans_for_table` with the dataset_id and table_name.
4.  **Present Results:** Do not just dump the JSON. Summarize the results for the user. For each scan in the `dataScans` list, present the table name passed to the tool, `name`, `displayName` and `description`.

**Workflow 5: Deleting a Data Insight Scan**

Use this when a user says, "delete the insight scan for `my_table`" or "remove `my_insight_scan`."

1.  **Gather Information:** You need the `data_insight_scan_name`.
2.  **Step 1: List Associated Jobs:**
    *   Call `list_data_insight_scan_jobs(data_insight_scan_name=...)`.
    *   Inform the user if there are existing jobs that need to be deleted first.
3.  **Step 2: Delete All Associated Jobs:**
    *   Iterate through the `jobs` list obtained in the previous step.
    *   For each job, call `delete_data_insight_scan_job(data_insight_scan_job_name=job['name'])`.
    *   Inform the user about the deletion of each job.
    *   Handle cases where a job deletion might fail.
4.  **Step 3: Delete the Scan Definition:**
    *   Once all associated jobs are successfully deleted, call `delete_data_insight_scan(data_insight_scan_name=...)`.
    *   Inform the user that the scan definition is being deleted.
5.  **Report Final Status:** Report the final status to the user, confirming successful deletion of the scan and all its jobs, or any issues encountered.

**Workflow 6: Listing Data Insight Scan Jobs for a Specific Scan**

Use this for discovery questions like, "what jobs ran for `my_insight_scan`?" or "show me the runs for the data insight check on `dataset.table`."

1.  **Gather Information:** You need the `data_insight_scan_name`.
2.  **Execute:** Call `list_data_insight_scan_jobs(data_insight_scan_name=...)`.
3.  **Present Results:** Do not just dump the JSON. Summarize the results for the user. For each job, present its `name`, `state`, `startTime`, and `endTime`.

**Workflow 7: Getting Detailed Results of a Data Insight Scan Job**

Use this when a user asks, "show me the detailed results of insight job `job_name`" or "what were the insights from the last run?"

1.  **Gather Information:** You need the full `data_insight_scan_job_name`.
2.  **Execute:** Call `get_data_insight_scan_job_full_details(data_insight_scan_job_name=...)`.
3.  **Present Results:**
    *   Check the `state` of the job from the results. If not "SUCCEEDED," inform the user that detailed results may not be available yet.
    *   If `SUCCEEDED`, clearly summarize the `dataDocumentationResult`. This would typically include generated documentation, derived metrics, etc.
    *   Avoid raw JSON dumping; present the key insights in a readable format.

**General Principles:**

*   **Act as a Guide:** Explain the multi-step process to the user. Setting expectations is key. For example: "Certainly. I will generate insights for that table. This involves creating the scan, linking it, running the job, and then monitoring it. I'll let you know when it's all done."
*   **Handle Job Names Correctly:** Be extremely careful to distinguish between the short `data_insight_scan_name` (used for creating/starting) and the long `data_insight_scan_job_name` (used for getting state, deleting jobs, and getting full job details). The long name is *only* available from the output of the `start_data_insight_scan` tool or `list_data_insight_scan_jobs`.
*   **Deletion Pre-requisites:** When deleting a `data_insight_scan` *definition*, all its associated `data_insight_scan_job`s must be deleted first. The agent should handle this automatically as part of Workflow 5.
"""


def get_data_insight_scans() -> dict: # Changed to def
    """
    Lists all Dataplex data insight scans in the configured region.

    This function specifically filters the results to include only scans of
    type 'DATA_DOCUMENTATION', which corresponds to Data Insights.

    Returns:
        dict: A dictionary containing the status and the list of data insight scans.
        {
            "status": "success" or "failed",
            "tool_name": "get_data_insight_scans",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "dataScans": [ ... list of scan objects of type DATA_DOCUMENTATION ... ]
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

        logger.debug(f"get_data_insight_scans json_result: {json_result}")

        all_scans = json_result.get("dataScans", [])
        
        # Filter for Data Insights scans, which have the type 'DATA_DOCUMENTATION'
        insight_scans_only = [
            scan for scan in all_scans if scan.get("type") == "DATA_DOCUMENTATION"
        ]

        messages.append(f"Filtered results. Found {len(insight_scans_only)} data insight scans.")

        filtered_results = {"dataScans": insight_scans_only}

        return {
            "status": "success",
            "tool_name": "get_data_insight_scans",
            "query": None,
            "messages": messages,
            "results": filtered_results
        }
    except Exception as e:
        messages.append(f"An error occurred while listing data insight scans: {e}")
        return {
            "status": "failed",
            "tool_name": "get_data_insight_scans",
            "query": None,
            "messages": messages,
            "results": None
        }


def get_data_insight_scans_for_table(dataset_id:str, table_name:str) -> dict: # Changed to def
    """
    Lists all Dataplex data insight scan attached to the table.

    This function specifically filters the results to include only scans of
    type 'DATA_DOCUMENTATION' and assigned to the dataset id/name and table name.

    Args:
        dataset_id (str): The ID (or name) of the BigQuery dataset.
        table_name (str): The BigQuery table to check for data insight scans.

    Returns:
        dict: A dictionary containing the status and the list of data insight scans.
        {
            "status": "success" or "failed",
            "tool_name": "get_data_insight_scans_for_table",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "dataScans": [ ... list of scan objects of type data_documentation ... ]
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

        # Filter the returned scans to only include those of type 'DATA_DOCUMENTATION'
        all_scans = json_result.get("dataScans", [])

        # Using a list comprehension for a concise filter
        insight_scans_only = []

        for item in all_scans:
            if item.get("type") == "DATA_DOCUMENTATION" and \
               item.get("data", {}).get("resource").lower() == f"//bigquery.googleapis.com/projects/{project_id}/datasets/{dataset_id}/tables/{table_name}".lower():
                insight_scans_only.append(item)
            
        messages.append(f"Filtered results. Found {len(insight_scans_only)} data insight scans for dataset {dataset_id}.")

        # Create the final results payload with the filtered list
        filtered_results = {"dataScans": insight_scans_only}

        return {
            "status": "success",
            "tool_name": "get_data_insight_scans_for_table",
            "query": None,
            "messages": messages,
            "results": filtered_results
        }
    except Exception as e:
        messages.append(f"An error occurred while listing data insight scans: {e}")
        return {
            "status": "failed",
            "tool_name": "get_data_insight_scans_for_table",
            "query": None,
            "messages": messages,
            "results": None
        }


def exists_data_insight_scan(data_insight_scan_name: str) -> dict: # Changed to def
    """
    Checks if a Dataplex data insight scan already exists.

    Args:
        data_insight_scan_name (str): The short name/ID of the data insight scan.

    Returns:
        dict: A dictionary containing the status and a boolean result.
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")

    list_result = get_data_insight_scans() # Added await
    messages = list_result.get("messages", [])

    if list_result["status"] == "failed":
        return list_result

    try:
        scan_exists = False
        full_scan_name_to_find = f"projects/{project_id}/locations/{dataplex_region}/dataScans/{data_insight_scan_name}"

        for item in list_result.get("results", {}).get("dataScans", []):
            if item.get("name") == full_scan_name_to_find:
                scan_exists = True
                messages.append(f"Found matching data insight scan: '{data_insight_scan_name}'.")
                break
        
        if not scan_exists:
            messages.append(f"Data insight scan '{data_insight_scan_name}' does not exist.")

        return {
            "status": "success",
            "tool_name": "exists_data_insight_scan",
            "query": None,
            "messages": messages,
            "results": {"exists": scan_exists}
        }
    except Exception as e:
        messages.append(f"An unexpected error occurred while processing scan list: {e}")
        return {
            "status": "failed",
            "tool_name": "exists_data_insight_scan",
            "query": None,
            "messages": messages,
            "results": None
        }


def create_data_insight_scan(data_insight_scan_name: str, data_insight_display_name: str, bigquery_dataset_name: str, bigquery_table_name: str) -> dict: # Changed to def
    """
    Creates a new Dataplex data insight scan if it does not already exist.

    Args:
        data_insight_scan_name (str): The short name/ID for the new scan.
        data_insight_display_name (str): The user-friendly display name for the scan.
        bigquery_dataset_name (str): The BigQuery dataset of the table to be scanned.
        bigquery_table_name (str): The BigQuery table to be scanned.

    Returns:
        dict: A dictionary containing the status and results of the operation.
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    
    existence_check = exists_data_insight_scan(data_insight_scan_name) # Added await
    messages = existence_check.get("messages", [])
    
    if existence_check["status"] == "failed":
        return existence_check

    if existence_check["results"]["exists"]:
        full_scan_name = f"projects/{project_id}/locations/{dataplex_region}/dataScans/{data_insight_scan_name}"
        return {
            "status": "success",
            "tool_name": "create_data_insight_scan",
            "query": None,
            "messages": messages,
            "results": {"name": full_scan_name, "created": False}
        }

    messages.append(f"Creating Data Insight Scan '{data_insight_scan_name}'.")
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans?dataScanId={data_insight_scan_name}"
    bigquery_resource_path = f"//bigquery.googleapis.com/projects/{project_id}/datasets/{bigquery_dataset_name}/tables/{bigquery_table_name}"

    request_body = {
        "displayName": data_insight_display_name,
        "type": "DATA_DOCUMENTATION",
        "dataDocumentationSpec": {},
        "data": {"resource": bigquery_resource_path}
    }

    try:
        json_result = rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await
        operation_name = json_result.get("name", "Unknown Operation")
        messages.append(f"Successfully initiated Data Insight Scan creation. Operation: {operation_name}")
        return {
            "status": "success",
            "tool_name": "create_data_insight_scan",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while creating the data insight scan: {e}")
        return {
            "status": "failed",
            "tool_name": "create_data_insight_scan",
            "query": None,
            "messages": messages,
            "results": None
        }


def start_data_insight_scan(data_insight_scan_name: str) -> dict: # Changed to def
    """
    Triggers a run of an existing Dataplex data insight scan.

    Args:
        data_insight_scan_name (str): The short name/ID of the data insight scan to run.

    Returns:
        dict: A dictionary containing the status and the job information.
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    messages = []
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{data_insight_scan_name}:run"
    request_body = {}

    try:
        messages.append(f"Attempting to run Data Insight Scan '{data_insight_scan_name}'.")
        json_result = rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await
        
        job_info = json_result.get("job", {})
        job_name = job_info.get("name", "Unknown Job")
        job_state = job_info.get("state", "Unknown State")

        messages.append(f"Successfully started Data Insight Scan job: {job_name} - State: {job_state}")

        return {
            "status": "success",
            "tool_name": "start_data_insight_scan",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while starting the data insight scan: {e}")
        return {
            "status": "failed",
            "tool_name": "start_data_insight_scan",
            "query": None,
            "messages": messages,
            "results": None
        }


def get_data_insight_scan_state(data_insight_scan_job_name: str) -> dict: # Changed to def
    """
    Gets the current state of a running data insight scan job.

    Args:
        data_insight_scan_job_name (str): The full resource name of the scan job, e.g., 
                                          "projects/.../locations/.../dataScans/.../jobs/...".

    Returns:
        dict: A dictionary containing the status and the job state.
    """
    messages = []
    # The job name is the full URL path after the v1/
    url = f"https://dataplex.googleapis.com/v1/{data_insight_scan_job_name}"
    
    try:
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        state = json_result.get("state", "UNKNOWN")
        messages.append(f"Job '{data_insight_scan_job_name}' is in state: {state}")
        return {
            "status": "success",
            "tool_name": "get_data_insight_scan_state",
            "query": None,
            "messages": messages,
            "results": {"state": state}
        }
    except Exception as e:
        messages.append(f"An error occurred while getting the scan job state: {e}")
        return {
            "status": "failed",
            "tool_name": "get_data_insight_scan_state",
            "query": None,
            "messages": messages,
            "results": None
        }


def update_bigquery_table_dataplex_labels_for_insights(dataplex_scan_name: str, bigquery_dataset_name: str, bigquery_table_name: str) -> dict: # Changed to def
    """
    Updates a BigQuery table's labels to link it to a Dataplex data insight scan.

    Args:
        dataplex_scan_name (str): The short name/ID of the insight scan to link.
        bigquery_dataset_name (str): The BigQuery dataset containing the table.
        bigquery_table_name (str): The BigQuery table to update with labels.

    Returns:
        dict: A dictionary containing the status and the BigQuery API response.
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    messages = []
    url = f"https://bigquery.googleapis.com/bigquery/v2/projects/{project_id}/datasets/{bigquery_dataset_name}/tables/{bigquery_table_name}"

    request_body = {
        "labels": {
            "dataplex-data-documentation-published-project": project_id,
            "dataplex-data-documentation-published-location": dataplex_region,
            "dataplex-data-documentation-published-scan": dataplex_scan_name,
        }
    }

    try:
        messages.append(f"Patching BigQuery table '{bigquery_dataset_name}.{bigquery_table_name}' with Data Insight labels.")
        json_result = rest_api_helper.rest_api_helper(url, "PATCH", request_body) # Added await
        messages.append("Successfully updated BigQuery table labels for data insights.")

        return {
            "status": "success",
            "tool_name": "update_bigquery_table_dataplex_labels_for_insights",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while updating the BigQuery table labels for insights: {e}")
        return {
            "status": "failed",
            "tool_name": "update_bigquery_table_dataplex_labels_for_insights",
            "query": None,
            "messages": messages,
            "results": None
        }

def list_data_insight_scan_jobs(data_insight_scan_name: str) -> dict: # Changed to def
    """
    Lists all data insight scan jobs associated with a specific data insight scan.

    Args:
        data_insight_scan_name (str): The short name/ID of the data insight scan.

    Returns:
        dict: A dictionary containing the status and the list of data insight scan jobs.
        {
            "status": "success" or "failed",
            "tool_name": "list_data_insight_scan_jobs",
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
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{data_insight_scan_name}/jobs"

    try:
        messages.append(f"Attempting to list jobs for Data Insight Scan '{data_insight_scan_name}'.")
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        
        jobs = json_result.get("dataScanJobs", [])
        messages.append(f"Successfully retrieved {len(jobs)} jobs for scan '{data_insight_scan_name}'.")

        return {
            "status": "success",
            "tool_name": "list_data_insight_scan_jobs",
            "query": None,
            "messages": messages,
            "results": {"jobs": jobs}
        }
    except Exception as e:
        messages.append(f"An error occurred while listing data insight scan jobs: {e}")
        return {
            "status": "failed",
            "tool_name": "list_data_insight_scan_jobs",
            "query": None,
            "messages": messages,
            "results": None
        }


def delete_data_insight_scan_job(data_insight_scan_job_name: str) -> dict: # Changed to def
    """
    Deletes a specific Dataplex data insight scan job.

    Args:
        data_insight_scan_job_name (str): The full resource name of the scan job, e.g.,
                                          "projects/.../locations/.../dataScans/.../jobs/...".

    Returns:
        dict: A dictionary containing the status of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "delete_data_insight_scan_job",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {} # Empty dictionary on success
        }
    """
    messages = []
    
    # The URL for deleting a job is the job's full resource path.
    url = f"https://dataplex.googleapis.com/v1/{data_insight_scan_job_name}"
    
    try:
        messages.append(f"Attempting to delete Data Insight Scan job: '{data_insight_scan_job_name}'.")
        # DELETE operation typically returns an empty response or an Operation object
        rest_api_helper.rest_api_helper(url, "DELETE", None) # Added await
        messages.append(f"Successfully deleted Data Insight Scan job: '{data_insight_scan_job_name}'.")
        return {
            "status": "success",
            "tool_name": "delete_data_insight_scan_job",
            "query": None,
            "messages": messages,
            "results": {}
        }
    except Exception as e:
        messages.append(f"An error occurred while deleting data insight scan job '{data_insight_scan_job_name}': {e}")
        return {
            "status": "failed",
            "tool_name": "delete_data_insight_scan_job",
            "query": None,
            "messages": messages,
            "results": None
        }


def delete_data_insight_scan(data_insight_scan_name: str) -> dict: # Changed to def
    """
    Deletes a specific Dataplex data insight scan definition.
    This operation only succeeds if there are no associated scan jobs.
    The agent's workflow should ensure jobs are deleted first.

    Args:
        data_insight_scan_name (str): The short name/ID of the data insight scan to delete.

    Returns:
        dict: A dictionary containing the status of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "delete_data_insight_scan",
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
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{data_insight_scan_name}"

    try:
        messages.append(f"Attempting to delete Data Insight Scan definition: '{data_insight_scan_name}'.")
        # DELETE operation typically returns an empty response or an Operation object
        rest_api_helper.rest_api_helper(url, "DELETE", None) # Added await
        messages.append(f"Successfully deleted Data Insight Scan definition: '{data_insight_scan_name}'.")
        return {
            "status": "success",
            "tool_name": "delete_data_insight_scan",
            "query": None,
            "messages": messages,
            "results": {}
        }
    except Exception as e:
        messages.append(f"An error occurred while deleting data insight scan definition '{data_insight_scan_name}': {e}")
        return {
            "status": "failed",
            "tool_name": "delete_data_insight_scan",
            "query": None,
            "messages": messages,
            "results": None
        }


def get_data_insight_scan_job_full_details(data_insight_scan_job_name: str) -> dict: # Changed to def
    """
    Fetches the full details of a specific Dataplex data insight scan job,
    including the complete data documentation results.

    Args:
        data_insight_scan_job_name (str): The full resource name of the scan job, e.g., 
                                          "projects/.../locations/.../dataScans/.../jobs/...".

    Returns:
        dict: A dictionary containing the status and the full job details.
        {
            "status": "success" or "failed",
            "tool_name": "get_data_insight_scan_job_full_details",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "job": {
                    "name": "projects/.../locations/.../dataScans/.../jobs/...",
                    "uid": "...",
                    "createTime": "...",
                    "startTime": "...",
                    "state": "SUCCEEDED",
                    "dataDocumentationResult": { ... full documentation payload ... }
                    // ... other job attributes
                }
            }
        }
    """
    messages = []
    
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")

    # Parse the incoming data_insight_scan_job_name to extract scan_id and job_id.
    # This allows us to reconstruct the URL using the correct project_id (alphanumeric)
    # and dataplex_region from environment variables.
    # Example job_name format: projects/PROJECT_NUMBER/locations/LOCATION/dataScans/SCAN_ID/jobs/JOB_ID
    match = re.match(r"projects/[^/]+/locations/[^/]+/dataScans/([^/]+)/jobs/([^/]+)", data_insight_scan_job_name)
    
    if not match:
        messages.append(f"Invalid data_insight_scan_job_name format: {data_insight_scan_job_name}")
        return {
            "status": "failed",
            "tool_name": "get_data_insight_scan_job_full_details",
            "query": None,
            "messages": messages,
            "results": None
        }
    
    scan_id = match.group(1)
    job_id = match.group(2)

    # Reconstruct the URL using the correct project_id and region from env vars
    # and include the '?view=FULL' parameter to get the full documentation results.
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{scan_id}/jobs/{job_id}?view=FULL"
    
    try:
        messages.append(f"Attempting to retrieve full data insight job details for: {data_insight_scan_job_name} with view=FULL.")
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        
        # Check if dataDocumentationResult is present, which indicates a successful full fetch for a completed job.
        if not json_result.get("dataDocumentationResult"):
            job_state = json_result.get("state")
            if job_state and job_state != "SUCCEEDED":
                messages.append(f"Job state is '{job_state}'. Full data documentation results are typically available only for 'SUCCEEDED' jobs.")
            else:
                messages.append("Data documentation results are not present in the job details. This might indicate an incomplete or failed documentation generation.")
        
        messages.append(f"Successfully retrieved full job details for '{data_insight_scan_job_name}'.")
        return {
            "status": "success",
            "tool_name": "get_data_insight_scan_job_full_details",
            "query": None,
            "messages": messages,
            "results": {"job": json_result}
        }
    except Exception as e:
        messages.append(f"An error occurred while retrieving full data insight job details: {e}")
        return {
            "status": "failed",
            "tool_name": "get_data_insight_scan_job_full_details",
            "query": None,
            "messages": messages,
            "results": None
        }