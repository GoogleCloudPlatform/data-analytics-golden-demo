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
import re
import json

import data_analytics_agent.utils.rest_api.rest_api_helper as rest_api_helper 
import data_analytics_agent.tools.dataplex.dataprofile_tools as dataprofile_tools

logger = logging.getLogger(__name__)


async def get_data_quality_scans() -> dict: # Changed to async def
    """
    Lists all Dataplex data quality scans in the configured region.

    This function specifically filters the results to include only scans of
    type 'DATA_QUALITY'.

    Returns:
        dict: A dictionary containing the status and the list of data quality scans.
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    messages = []
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans"

    try:
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        messages.append("Successfully retrieved list of all data scans from the API.")

        all_scans = json_result.get("dataScans", [])
        quality_scans_only = [
            scan for scan in all_scans if scan.get("type") == "DATA_QUALITY"
        ]
        messages.append(f"Filtered results. Found {len(quality_scans_only)} data quality scans.")

        filtered_results = {"dataScans": quality_scans_only}

        return {
            "status": "success",
            "tool_name": "get_data_quality_scans",
            "query": None,
            "messages": messages,
            "results": filtered_results
        }
    except Exception as e:
        messages.append(f"An error occurred while listing data quality scans: {e}")
        return {
            "status": "failed",
            "tool_name": "get_data_quality_scans",
            "query": None,
            "messages": messages,
            "results": None
        }


async def get_data_quality_scans_for_table(dataset_id:str, table_name:str) -> dict: # Changed to async def
    """
    Lists all Dataplex data quality scan attached to the table.

    This function specifically filters the results to include only scans of
    type 'DATA_QUALITY' and assigned to the dataset id/name and table name.

    Args:
        dataset_id (str): The ID (or name) of the BigQuery dataset.
        table_name (str): The BigQuery table to check for data quality scans.

    Returns:
        dict: A dictionary containing the status and the list of data quality scans.
        {
            "status": "success" or "failed",
            "tool_name": "get_data_quality_scans_for_table",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "dataScans": [ ... list of scan objects of type data_quality ... ]
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

        # Filter the returned scans to only include those of type 'DATA_QUALITY'
        all_scans = json_result.get("dataScans", [])

        # Using a list comprehension for a concise filter
        quality_scans_only = []

        for item in all_scans:
            if item.get("type") == "DATA_QUALITY" and \
               item.get("data", {}).get("resource").lower() == f"//bigquery.googleapis.com/projects/{project_id}/datasets/{dataset_id}/tables/{table_name}".lower():
                quality_scans_only.append(item)
            
        messages.append(f"Filtered results. Found {len(quality_scans_only)} data quality scans for dataset {dataset_id}.")

        # Create the final results payload with the filtered list
        filtered_results = {"dataScans": quality_scans_only}

        return {
            "status": "success",
            "tool_name": "get_data_quality_scans_for_table",
            "query": None,
            "messages": messages,
            "results": filtered_results
        }
    except Exception as e:
        messages.append(f"An error occurred while listing data quality scans: {e}")
        return {
            "status": "failed",
            "tool_name": "get_data_quality_scans_for_table",
            "query": None,
            "messages": messages,
            "results": None
        }


async def get_data_quality_scan(data_quality_scan_name: str) -> dict: # Changed to async def
    """
    Gets a single Dataplex data quality scan in the configured region.  
    This returns the "Full" view which has all the scan details (more than just a data scan listing (e.g. tool: get_data_quality_scans))

    Args:
        data_quality_scan_name (str): The name of the data quality scan.

    Returns:
        dict: A dictionary containing the status and the list of data quality scans.
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    messages = []
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{data_quality_scan_name}?view=FULL"

    try:
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        messages.append("Successfully retrieved the data get_data_quality_scan from the API.")

        return {
            "status": "success",
            "tool_name": "get_data_quality_scan",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while listing data quality scan: {e}")
        return {
            "status": "failed",
            "tool_name": "get_data_quality_scan",
            "query": None,
            "messages": messages,
            "results": None
        }


async def exists_data_quality_scan(data_quality_scan_name: str) -> dict: # Changed to async def
    """
    Checks if a Dataplex data quality scan already exists.

    Args:
        data_quality_scan_name (str): The short name/ID of the data quality scan.

    Returns:
        dict: A dictionary containing the status and a boolean result.
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")

    list_result = await get_data_quality_scans() # Added await
    messages = list_result.get("messages", [])

    if list_result["status"] == "failed":
        return list_result

    try:
        scan_exists = False
        full_scan_name_to_find = f"projects/{project_id}/locations/{dataplex_region}/dataScans/{data_quality_scan_name}"

        for item in list_result.get("results", {}).get("dataScans", []):
            if item.get("name") == full_scan_name_to_find:
                scan_exists = True
                messages.append(f"Found matching data quality scan: '{data_quality_scan_name}'.")
                break
        
        if not scan_exists:
            messages.append(f"Data quality scan '{data_quality_scan_name}' does not exist.")

        return {
            "status": "success",
            "tool_name": "exists_data_quality_scan",
            "query": None,
            "messages": messages,
            "results": {"exists": scan_exists}
        }
    except Exception as e:
        messages.append(f"An unexpected error occurred while processing scan list: {e}")
        return {
            "status": "failed",
            "tool_name": "exists_data_quality_scan",
            "query": None,
            "messages": messages,
            "results": None
        }


async def get_data_quality_scan_recommendations(data_profile_scan_name: str) -> dict: # Changed to async def
    """
    Gets recommended data quality rules based on a completed data profile scan.

    Args:
        data_profile_scan_name (str): The short name/ID of the *data profile* scan
                                      from which to generate recommendations.

    Returns:
        dict: A dictionary containing the status and the recommended rules.
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    messages = []
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{data_profile_scan_name}:generateDataQualityRules"

    try:
        messages.append(f"Requesting DQ recommendations from profile scan '{data_profile_scan_name}'.")
        json_result = await rest_api_helper.rest_api_helper(url, "POST", {}) # Added await
        messages.append("Successfully generated recommended data quality rules.")
        return {
            "status": "success",
            "tool_name": "get_data_quality_scan_recommendations",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while generating DQ rule recommendations: {e}")
        return {
            "status": "failed",
            "tool_name": "get_data_quality_scan_recommendations",
            "query": None,
            "messages": messages,
            "results": None
        }


async def create_data_quality_scan(data_quality_scan_name: str, display_name: str, description: str, # Changed to async def
                             bigquery_dataset_name: str, bigquery_table_name: str,
                             data_profile_scan_name: str) -> dict:
    """
    Creates a new Dataplex data quality scan based on recommended rules from an
    existing data profile scan.

    This function automatically performs the following steps:
    1. Checks if the target data quality scan already exists.
    2. Finds the corresponding data profile scan for the table.
    3. If the profile scan exists, it fetches the recommended quality rules.
    4. It then creates the data quality scan using those recommended rules.

    Args:
        data_quality_scan_name (str): The short name/ID for the new data quality scan.
        display_name (str): The user-friendly display name for the scan.
        description (str): A description for the data quality scan.
        bigquery_dataset_name (str): The BigQuery dataset of the table to be scanned.
        bigquery_table_name (str): The BigQuery table to be scanned.
        data_profile_scan_name (str): The short name/ID of the data profile scan.

    Returns:
        dict: A dictionary containing the status and results of the operation.
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    messages = []

    # 1. Check if the DATA QUALITY scan we want to create already exists.
    dq_existence_check = await exists_data_quality_scan(data_quality_scan_name) # Added await
    messages.extend(dq_existence_check.get("messages", []))
    
    if dq_existence_check["status"] == "failed":
        return dq_existence_check # Propagate failure

    if dq_existence_check["results"]["exists"]:
        full_scan_name = f"projects/{project_id}/locations/{dataplex_region}/dataScans/{data_quality_scan_name}"
        return {
            "status": "success",
            "tool_name": "create_data_quality_scan",
            "query": None,
            "messages": messages,
            "results": {"name": full_scan_name, "created": False, "reason": "Scan already exists."}
        }

    # 2. Determine the conventional name of the prerequisite DATA PROFILE scan.
    #data_profile_scan_name = f"{bigquery_dataset_name}-{bigquery_table_name}-profile-scan".lower().replace("_","-")
    #messages.append(f"Checking for prerequisite data profile scan: '{data_profile_scan_name}'")

    # 3. Check if the prerequisite DATA PROFILE scan exists.
    profile_existence_check = await dataprofile_tools.exists_data_profile_scan(data_profile_scan_name) # Added await
    messages.extend(profile_existence_check.get("messages", []))

    if profile_existence_check["status"] == "failed":
        return profile_existence_check # Propagate failure
    
    if not profile_existence_check["results"]["exists"]:
        messages.append(f"Prerequisite data profile scan '{data_profile_scan_name}' not found. Cannot create data quality scan without it.")
        return {
            "status": "failed",
            "tool_name": "create_data_quality_scan",
            "query": None,
            "messages": messages,
            "results": None
        }

    # 4. Get the recommended rules from the existing profile scan.
    recommended_rules_result = await get_data_quality_scan_recommendations(data_profile_scan_name) # Added await
    messages.extend(recommended_rules_result.get("messages", []))

    if recommended_rules_result["status"] == "failed":
        return recommended_rules_result # Propagate failure

    # 5. Construct the data quality specification from the recommendations.
    rules = recommended_rules_result.get("results", {}).get("rule", [])
    if not rules:
        messages.append("No recommended rules were generated from the profile scan. Cannot create an empty quality scan.")
        return {
            "status": "failed",
            "tool_name": "create_data_quality_scan",
            "query": None,
            "messages": messages,
            "results": None
        }

    # As per the notebook, a default sampling percent of 100 is used.
    data_quality_spec = {
        "rules": rules,
        "samplingPercent": 100
    }
    messages.append(f"Successfully built data quality spec with {len(rules)} recommended rules.")

    # 6. Now, proceed with creating the Data Quality scan.
    messages.append(f"Creating Data Quality Scan '{data_quality_scan_name}' with the generated spec.")
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans?dataScanId={data_quality_scan_name}"
    resource_path = f"//bigquery.googleapis.com/projects/{project_id}/datasets/{bigquery_dataset_name}/tables/{bigquery_table_name}"

    request_body = {
        "dataQualitySpec": data_quality_spec,
        "data": {"resource": resource_path},
        "description": description,
        "displayName": display_name
    }

    try:
        json_result = await rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await
        messages.append(f"Successfully initiated Data Quality Scan creation for '{data_quality_scan_name}'.")
        return {
            "status": "success",
            "tool_name": "create_data_quality_scan",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred during the final step of creating the data quality scan: {e}")
        return {
            "status": "failed",
            "tool_name": "create_data_quality_scan",
            "query": None,
            "messages": messages,
            "results": None
        }
    

async def start_data_quality_scan(data_quality_scan_name: str) -> dict: # Changed to async def
    """
    Triggers a run of an existing Dataplex data quality scan.

    Args:
        data_quality_scan_name (str): The short name/ID of the scan to run.

    Returns:
        dict: A dictionary containing the status and the job information.
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    messages = []
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{data_quality_scan_name}:run"
    request_body = {}

    try:
        messages.append(f"Attempting to run Data Quality Scan '{data_quality_scan_name}'.")
        json_result = await rest_api_helper.rest_api_helper(url, "POST", {}) # Added await
        
        job_info = json_result.get("job", {})
        job_name = job_info.get("name", "Unknown Job")
        job_state = job_info.get("state", "Unknown State")

        messages.append(f"Successfully started Data Quality Scan job: {job_name} - State: {job_state}")

        return {
            "status": "success",
            "tool_name": "start_data_quality_scan",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while starting the data quality scan: {e}")
        return {
            "status": "failed",
            "tool_name": "start_data_quality_scan",
            "query": None,
            "messages": messages,
            "results": None
        }


async def get_data_quality_scan_state(data_quality_scan_job_name: str) -> dict: # Changed to async def
    """
    Gets the current state of a running data quality scan job.

    Args:
        data_quality_scan_job_name (str): The full resource name of the scan job, e.g., 
                                          "projects/.../locations/.../dataScans/.../jobs/...".

    Returns:
        dict: A dictionary containing the status and the job state.
    """
    messages = []
    url = f"https://dataplex.googleapis.com/v1/{data_quality_scan_job_name}"
    
    try:
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        state = json_result.get("state", "UNKNOWN")
        messages.append(f"Job '{data_quality_scan_job_name}' is in state: {state}")
        
        return {
            "status": "success",
            "tool_name": "get_data_quality_scan_state",
            "query": None,
            "messages": messages,
            "results": {"state": state}
        }
    except Exception as e:
        messages.append(f"An error occurred while getting the data quality scan job state: {e}")
        return {
            "status": "failed",
            "tool_name": "get_data_quality_scan_state",
            "query": None,
            "messages": messages,
            "results": None
        }


async def update_bigquery_table_dataplex_labels_for_quality(dataplex_scan_name: str, bigquery_dataset_name: str, bigquery_table_name: str) -> dict: # Changed to async def
    """
    Updates a BigQuery table's labels to link it to a Dataplex data quality scan.

    Args:
        dataplex_scan_name (str): The short name/ID of the quality scan to link.
        bigquery_dataset_name (str): The BigQuery dataset containing the table.
        bigquery_table_name (str): The BigQuery table to update.
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")
    messages = []
    url = f"https://bigquery.googleapis.com/bigquery/v2/projects/{project_id}/datasets/{bigquery_dataset_name}/tables/{bigquery_table_name}"

    request_body = {
        "labels": {
            "dataplex-dq-published-project": project_id,
            "dataplex-dq-published-location": dataplex_region,
            "dataplex-dq-published-scan": dataplex_scan_name,
        }
    }

    try:
        messages.append(f"Patching BigQuery table '{bigquery_dataset_name}.{bigquery_table_name}' with Data Quality labels.")
        json_result = await rest_api_helper.rest_api_helper(url, "PATCH", request_body) # Added await
        messages.append("Successfully updated BigQuery table labels for data quality.")
        return {
            "status": "success",
            "tool_name": "update_bigquery_table_dataplex_labels_for_quality",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while updating the BigQuery table labels for quality: {e}")
        return {
            "status": "failed",
            "tool_name": "update_bigquery_table_dataplex_labels_for_quality",
            "query": None,
            "messages": messages,
            "results": None
        }


async def list_data_quality_scan_jobs(data_quality_scan_name: str) -> dict: # Changed to async def
    """
    Lists all data quality scan jobs associated with a specific data quality scan.

    Args:
        data_quality_scan_name (str): The short name/ID of the data quality scan.

    Returns:
        dict: A dictionary containing the status and the list of data quality scan jobs.
        {
            "status": "success" or "failed",
            "tool_name": "list_data_quality_scan_jobs",
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
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{data_quality_scan_name}/jobs"

    try:
        messages.append(f"Attempting to list jobs for Data Quality Scan '{data_quality_scan_name}'.")
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        
        jobs = json_result.get("dataScanJobs", [])
        messages.append(f"Successfully retrieved {len(jobs)} jobs for scan '{data_quality_scan_name}'.")

        return {
            "status": "success",
            "tool_name": "list_data_quality_scan_jobs",
            "query": None,
            "messages": messages,
            "results": {"jobs": jobs}
        }
    except Exception as e:
        messages.append(f"An error occurred while listing data quality scan jobs: {e}")
        return {
            "status": "failed",
            "tool_name": "list_data_quality_scan_jobs",
            "query": None,
            "messages": messages,
            "results": None
        }


async def delete_data_quality_scan_job(data_quality_scan_job_name: str) -> dict: # Changed to async def
    """
    Deletes a specific Dataplex data quality scan job.

    Args:
        data_quality_scan_job_name (str): The full resource name of the scan job, e.g.,
                                          "projects/.../locations/.../dataScans/.../jobs/...".

    Returns:
        dict: A dictionary containing the status of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "delete_data_quality_scan_job",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {} # Empty dictionary on success
        }
    """
    messages = []
    
    # The URL for deleting a job is the job's full resource path.
    url = f"https://dataplex.googleapis.com/v1/{data_quality_scan_job_name}"
    
    try:
        messages.append(f"Attempting to delete Data Quality Scan job: '{data_quality_scan_job_name}'.")
        # DELETE operation typically returns an empty response or an Operation object
        await rest_api_helper.rest_api_helper(url, "DELETE", None) # Added await
        messages.append(f"Successfully deleted Data Quality Scan job: '{data_quality_scan_job_name}'.")
        return {
            "status": "success",
            "tool_name": "delete_data_quality_scan_job",
            "query": None,
            "messages": messages,
            "results": {}
        }
    except Exception as e:
        messages.append(f"An error occurred while deleting data quality scan job '{data_quality_scan_job_name}': {e}")
        return {
            "status": "failed",
            "tool_name": "delete_data_quality_scan_job",
            "query": None,
            "messages": messages,
            "results": None
        }


async def delete_data_quality_scan(data_quality_scan_name: str) -> dict: # Changed to async def
    """
    Deletes a specific Dataplex data quality scan definition.
    This operation only succeeds if there are no associated scan jobs.
    The agent's workflow should ensure jobs are deleted first.

    Args:
        data_quality_scan_name (str): The short name/ID of the data quality scan to delete.

    Returns:
        dict: A dictionary containing the status of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "delete_data_quality_scan",
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
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{data_quality_scan_name}"

    try:
        messages.append(f"Attempting to delete Data Quality Scan definition: '{data_quality_scan_name}'.")
        # DELETE operation typically returns an empty response or an Operation object
        await rest_api_helper.rest_api_helper(url, "DELETE", None) # Added await
        messages.append(f"Successfully deleted Data Quality Scan definition: '{data_quality_scan_name}'.")
        return {
            "status": "success",
            "tool_name": "delete_data_quality_scan",
            "query": None,
            "messages": messages,
            "results": {}
        }
    except Exception as e:
        messages.append(f"An error occurred while deleting data quality scan definition '{data_quality_scan_name}': {e}")
        return {
            "status": "failed",
            "tool_name": "delete_data_quality_scan",
            "query": None,
            "messages": messages,
            "results": None
        }


async def get_data_quality_scan_job_full_details(data_quality_scan_job_name: str) -> dict: # Changed to async def
    """
    Fetches the full details of a specific Dataplex data quality scan job,
    including the complete data quality results.

    Args:
        data_quality_scan_job_name (str): The full resource name of the scan job, e.g., 
                                          "projects/.../locations/.../dataScans/.../jobs/...".

    Returns:
        dict: A dictionary containing the status and the full job details.
        {
            "status": "success" or "failed",
            "tool_name": "get_data_quality_scan_job_full_details",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "job": {
                    "name": "projects/.../locations/.../dataScans/.../jobs/...",
                    "uid": "...",
                    "createTime": "...",
                    "startTime": "...",
                    "state": "SUCCEEDED",
                    "dataQualityResult": { ... full data quality payload ... }
                    // ... other job attributes
                }
            }
        }
    """
    messages = []
    
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")

    # Parse the incoming data_quality_scan_job_name to extract scan_id and job_id.
    # This allows us to reconstruct the URL using the correct project_id (alphanumeric)
    # and dataplex_region from environment variables.
    # Example job_name format: projects/PROJECT_NUMBER/locations/LOCATION/dataScans/SCAN_ID/jobs/JOB_ID
    match = re.match(r"projects/[^/]+/locations/[^/]+/dataScans/([^/]+)/jobs/([^/]+)", data_quality_scan_job_name)
    
    if not match:
        messages.append(f"Invalid data_quality_scan_job_name format: {data_quality_scan_job_name}")
        return {
            "status": "failed",
            "tool_name": "get_data_quality_scan_job_full_details",
            "query": None,
            "messages": messages,
            "results": None
        }
    
    scan_id = match.group(1)
    job_id = match.group(2)

    # Reconstruct the URL using the correct project_id and region from env vars
    # and include the '?view=FULL' parameter to get the full quality results.
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_region}/dataScans/{scan_id}/jobs/{job_id}?view=FULL"
    
    try:
        messages.append(f"Attempting to retrieve full data quality job details for: {data_quality_scan_job_name} with view=FULL.")
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        
        # Check if dataQualityResult is present, which indicates a successful full fetch for a completed job.
        if not json_result.get("dataQualityResult"):
            job_state = json_result.get("state")
            if job_state and job_state != "SUCCEEDED":
                messages.append(f"Job state is '{job_state}'. Full data quality results are typically available only for 'SUCCEEDED' jobs.")
            else:
                messages.append("Data quality results are not present in the job details. This might indicate an incomplete or failed quality check.")
        
        messages.append(f"Successfully retrieved full job details for '{data_quality_scan_job_name}'.")
        return {
            "status": "success",
            "tool_name": "get_data_quality_scan_job_full_details",
            "query": None,
            "messages": messages,
            "results": {"job": json_result}
        }
    except Exception as e:
        messages.append(f"An error occurred while retrieving full data quality job details: {e}")
        return {
            "status": "failed",
            "tool_name": "get_data_quality_scan_job_full_details",
            "query": None,
            "messages": messages,
            "results": None
        }


################################################################################################################
# parse_create_and_run_data_quality_scan_params
################################################################################################################
from google.adk.tools.tool_context import ToolContext
import data_analytics_agent.tools.bigquery.bigquery_table_tools as bigquery_table_tools
import data_analytics_agent.utils.gemini.gemini_helper as gemini_helper

async def parse_create_and_run_data_quality_scan_params(tool_context: ToolContext, prompt: str) -> dict:
    """
    Parses a user prompt for data quality scan details and sets them in session state for subsequent agents to use.
    """
    response_schema = {
        "type": "object",
        "properties": {
            "data_quality_scan_name": {
                "type": "string",
                "description": "This is the data quality scan name. If no name is provided you should create one that uses hyphens (not spaces) for seperators."
            },
            "data_quality_display_name": {
                "type": "string",
                "description": "This is the data quality scan name. If no name is provided you should create one that uses spaces for seperators."
            },
            "bigquery_dataset_name": {
                "type": "string",
                "description": "The matching BigQuery dataset name."
            },
            "bigquery_table_name": {
                "type": "string",
                "description": "The matching BigQuery table name."
            }
        },
        "required": ["data_quality_scan_name", "data_quality_display_name", "bigquery_dataset_name", "bigquery_table_name"]
    }

    get_bigquery_table_list_helper_response = await bigquery_table_tools.get_bigquery_table_list()
    bigquery_dataset_and_table_schema = get_bigquery_table_list_helper_response["results"]

    prompt_01 = f"""You need to match or create the correct names for the following using the below schema information from BigQuery.

    The user provided the below information "original-user-prompt" and you need to extract the:
    - data_quality_scan_name: This information may or may not be provided by the user.
        - You can create the scan name, using hyphens for seperators, and a good name would match the table name and then append a "-data-quality-scan".
        - For example "my_table" would have a scan name of "my-table-data-quality-scan".
        - Keep this to about 30 characters.
    - data_quality_display_name: This information may or may not be provided by the user.
        - You can create the display name, using spaces for seperators, and a good name would match the table name and then append a " Data Quality Scan".
        - For example "my_table" would have a scan name of "My Table Data Quality Scan".
        - Keep this to about 30 characters.
    - bigquery_dataset_name:  This must be a match from the <bigquery-dataset-and-table-schema> based upon the user's prompt.

    There could be misspelled words, spaces, etc. So please correct them.

    <original-user-prompt>
    {prompt}
    </original-user-prompt>

    <bigquery-dataset-and-table-schema>
    {bigquery_dataset_and_table_schema}
    </bigquery-dataset-and-table-schema>
    """

    gemini_response = await gemini_helper.gemini_llm(prompt_01, response_schema=response_schema, model="gemini-2.5-flash", temperature=0.2)
    gemini_response_dict = json.loads(gemini_response)   

    data_quality_scan_name = gemini_response_dict.get("data_quality_scan_name",None) 
    data_quality_display_name = gemini_response_dict.get("data_quality_display_name",None) 
    bigquery_dataset_name = gemini_response_dict.get("bigquery_dataset_name",None) 
    bigquery_table_name = gemini_response_dict.get("bigquery_table_name",None) 

    tool_context.state["data_quality_scan_name_param"] = data_quality_scan_name
    tool_context.state["data_quality_display_name_param"] = data_quality_display_name
    tool_context.state["bigquery_dataset_name_param"] = bigquery_dataset_name
    tool_context.state["bigquery_table_name_param"] = bigquery_table_name
    tool_context.state["initial_data_quality_query_param"] = prompt 

    logger.info(f"parse_create_and_run_data_quality_scan_params: data_quality_scan_name: {data_quality_scan_name}")
    logger.info(f"parse_create_and_run_data_quality_scan_params: data_quality_display_name: {data_quality_display_name}")
    logger.info(f"parse_create_and_run_data_quality_scan_params: bigquery_dataset_name: {bigquery_dataset_name}")
    logger.info(f"parse_create_and_run_data_quality_scan_params: bigquery_table_name: {bigquery_table_name}")
    logger.info(f"parse_create_and_run_data_quality_scan_params: initial_prompt_content: {prompt}")    

    ##################################################################
    # Get the data profile scan name
    ##################################################################
    response_schema_data_profile = {
        "type": "object",
        "properties": {
            "data_profile_scan_name": {
                "type": "string",
                "description": "The name of the data profile scan to use for recommendations."
            }
        },
        "required": ["data_profile_scan_name"]
    }

    get_data_profile_scans_for_table_response = await dataprofile_tools.get_data_profile_scans_for_table(bigquery_dataset_name, bigquery_table_name)
    data_profile_scans_for_table = get_data_profile_scans_for_table_response["results"]

    prompt_02 = f"""You need to find the data profile scan name in the below list based upon the user's prompt and the following values.
    If you cannot find one, use the most recent. If there are no profile scans then return "unknown" for the data_profile_scan_name.

    data_quality_scan_name: {data_quality_scan_name}
    data_quality_display_name: {data_quality_display_name}
    bigquery_dataset_name: {bigquery_dataset_name}
    bigquery_table_name: {bigquery_table_name}

    There could be misspelled words, spaces, etc. So please correct them.

    <original-user-prompt>
    {prompt}
    </original-user-prompt>

    <data-profile-scans-for-table>
    {data_profile_scans_for_table}
    </data-profile-scans-for-table>
    """

    gemini_response_data_profile = await gemini_helper.gemini_llm(prompt_02, response_schema=response_schema_data_profile, model="gemini-2.5-flash", temperature=0.2)
    gemini_response_data_profile_dict = json.loads(gemini_response_data_profile)   

    data_profile_scan_name = gemini_response_data_profile_dict.get("data_profile_scan_name",None)

    # remove the whole resource name
    if "/" in data_profile_scan_name:
        data_profile_scan_name = data_profile_scan_name.split("/")[-1]

    tool_context.state["data_profile_scan_name_param"] = data_profile_scan_name

    logger.info(f"parse_create_and_run_data_quality_scan_params: data_profile_scan_name: {data_profile_scan_name}")


    return {
        "status": "success",
        "tool_name": "parse_and_set_data_quality_params_tool",
        "query": None,
        "messages": [
            "Data quality parameters parsed and set in session state and being returned"
        ],
        "results": {
            "data_quality_scan_name" : data_quality_scan_name,
            "data_quality_display_name" : data_quality_display_name,
            "bigquery_dataset_name" : bigquery_dataset_name,
            "bigquery_table_name" : bigquery_table_name,
            "data_profile_scan_name" : data_profile_scan_name
        }
    }


################################################################################################################
# create_and_run_data_quality_scan
################################################################################################################
import data_analytics_agent.utils.time_delay.wait_tool as wait_tool

from typing import AsyncGenerator
from pydantic import Field
from google.genai import types
from google.adk.events import Event 


async def create_and_run_data_quality_scan(
    data_quality_scan_name: str,
    data_quality_display_name: str,
    bigquery_dataset_name: str,
    bigquery_table_name: str,
    data_profile_scan_name: str,
    initial_prompt_content: str,
    event_author_name: str
) -> AsyncGenerator[Event, None]:
    """
    Orchestrates the complete Dataplex Data Quality scan workflow.
    """
    logger.info(f"[{event_author_name}] Starting Data Quality Scan workflow for {data_quality_scan_name}.")

    response = {
        "status": "success",
        "tool_name": "full_data_quality_workflow",
        "query": initial_prompt_content,
        "messages": [],
        "results": {
            "data_quality_scan_name": data_quality_scan_name,
            "data_quality_display_name": data_quality_display_name,
            "bigquery_dataset_name": bigquery_dataset_name,
            "bigquery_table_name": bigquery_table_name,
            "data_profile_scan_name": data_profile_scan_name,
            "data_quality_scan_job_name": None,
            "data_quality_scan_job_state": None,
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
        content=types.Content(role='assistant', parts=[types.Part(text=f"Initiating full data quality scan workflow for '{bigquery_dataset_name}.{bigquery_table_name}'.")])
    )
    response["messages"].append(f"Workflow initiated for {data_quality_scan_name}.")

    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 1/5: Creating data quality scan definition: '{data_quality_scan_name}'.")])
        )
        create_scan_result = await create_data_quality_scan(
            data_quality_scan_name,
            data_quality_display_name,
            data_quality_display_name, # Description
            bigquery_dataset_name,
            bigquery_table_name,
            data_profile_scan_name
        )
        if create_scan_result["status"] != "success":
            raise Exception(f"Failed to create scan definition: {create_scan_result.get('error_message', 'Unknown error')}")
        
        success_message = f"Successfully created data quality scan definition: {data_quality_scan_name}. Now waiting for it to register."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed to create data quality scan '{data_quality_scan_name}'. Error: {e}", response):
            yield error_event
        return

    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 2/5: Waiting for scan '{data_quality_scan_name}' to be registered and exist.")])
        )
        scan_exists = False
        max_attempts = 10
        for i in range(max_attempts):
            exists_check_result = await exists_data_quality_scan(data_quality_scan_name)
            if exists_check_result["status"] == "success" and exists_check_result["results"]["exists"]:
                scan_exists = True
                break
            yield Event(
                author=event_author_name,
                content=types.Content(role='assistant', parts=[types.Part(text=f"Scan not yet registered (attempt {i+1}/{max_attempts}). Waiting 2 seconds...")])
            )
            await wait_tool.wait_for_seconds(2)

        if not scan_exists:
            raise Exception(f"Scan '{data_quality_scan_name}' did not become registered after {max_attempts * 2} seconds.")
        
        success_message = f"Data quality scan '{data_quality_scan_name}' is now registered and ready."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed while waiting for scan '{data_quality_scan_name}' to register. Error: {e}", response):
            yield error_event
        return

    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 3/5: Starting the data quality scan job for '{data_quality_scan_name}'.")])
        )
        start_job_result = await start_data_quality_scan(data_quality_scan_name)
        if start_job_result["status"] != "success" or not start_job_result["results"].get("job", {}).get("name"):
            raise Exception(f"Failed to start scan job: {start_job_result.get('error_message', 'Unknown error')}")
        
        job_name = start_job_result["results"]["job"]["name"]
        response["results"]["data_quality_scan_job_name"] = job_name
        
        success_message = f"Successfully started data quality scan job: '{job_name}'. Monitoring its progress."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed to start data quality scan job for '{data_quality_scan_name}'. Error: {e}", response):
            yield error_event
        return

    job_name = response["results"]["data_quality_scan_job_name"]
    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 4/5: Monitoring data quality job '{job_name}' for completion.")])
        )
        job_completed = False
        final_job_state = "UNKNOWN"
        max_attempts = 50
        for i in range(max_attempts):
            job_state_result = await get_data_quality_scan_state(job_name)
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
            raise Exception(f"Data quality job '{job_name}' did not complete after {max_attempts * 5} seconds. Final state: {final_job_state}")
        
        if final_job_state != "SUCCEEDED":
            raise Exception(f"Data quality job '{job_name}' completed with state: {final_job_state}. (Expected SUCCEEDED)")

        response["results"]["data_quality_scan_job_state"] = final_job_state
        success_message = f"Data quality job '{job_name}' completed successfully with state: {final_job_state}. Now linking to BigQuery."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        final_job_state = final_job_state if 'final_job_state' in locals() else 'UNKNOWN_FAILED'
        response["results"]["data_quality_scan_job_state"] = final_job_state
        for error_event in _handle_error_and_finish(f"Data quality job '{job_name}' failed or did not complete. Error: {e}", response):
            yield error_event
        return

    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 5/5: Linking data quality scan '{data_quality_scan_name}' to BigQuery table '{bigquery_dataset_name}.{bigquery_table_name}'." )])
        )
        link_result = await update_bigquery_table_dataplex_labels_for_quality(
            data_quality_scan_name,
            bigquery_dataset_name,
            bigquery_table_name,
        )
        if link_result["status"] != "success":
            raise Exception(f"Failed to link to BigQuery: {link_result.get('error_message', 'Unknown error')}")
        
        success_message = f"Successfully linked the data quality scan to BigQuery. Results should now be visible in the BigQuery console."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed to link data quality scan '{data_quality_scan_name}' to BigQuery. Error: {e}", response):
            yield error_event
        return

    final_overall_message = "Data quality workflow completed successfully!" if response["success"] else "Data quality workflow completed with failures."
    yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=final_overall_message)]))
    response["messages"].append(final_overall_message)