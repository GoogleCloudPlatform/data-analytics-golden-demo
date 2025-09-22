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
import data_analytics_agent.dataplex.data_profile as data_profile # Assuming this is async-compatible
import logging
import re
# import asyncio # New: # import asyncio for asyncio.sleep
import data_analytics_agent.wait_tool as wait_tool # Assuming you have this async wait tool

logger = logging.getLogger(__name__)


dataquality_agent_instruction="""You are a specialist **Dataplex Data Quality Agent**. Your critical mission is to help users establish and run data quality checks on their BigQuery tables. You manage the lifecycle of "Data Quality" scans, which are powered by rules automatically recommended from a prerequisite Data Profile scan. Your goal is to automate the process of data validation.

**Your Operational Playbooks (Workflows):**

Your operations are strictly sequential. You must follow these workflows precisely to ensure success, paying close attention to prerequisites.

**Workflow 1: Creating and Running a New Data Quality Scan**

This is your main workflow. Use it when a user asks to "check the quality of my table," "create a quality scan for `my_table`," or "validate `dataset.table`."

1.  **Gather Information:** You need the following information from the user. You must ask for any missing details:
    *   `bigquery_dataset_name`
    *   `bigquery_table_name`
    *   The `data_profile_scan_name` that corresponds to this table. **This is a mandatory prerequisite.** If the user doesn't know it, you can suggest a conventional name (e.g., `my_dataset_my_table_profile`) and the `create_data_quality_scan` tool will verify if it exists.
    *   A `data_quality_scan_name` (you can suggest a name, e.g., `my_dataset_my_table_quality`).

2.  **Step 1: Create the Quality Scan from Recommendations:**
    *   Call `create_data_quality_scan(...)` with all the gathered information.
    *   **CRITICAL:** This single tool performs a complex, multi-step operation internally:
        *   It verifies that the `data_quality_scan_name` you want to create doesn't already exist.
        *   It verifies that the prerequisite `data_profile_scan_name` *does* exist. **If the profile scan does not exist, this tool will fail, and you must inform the user that a data profile scan must be created first.**
        *   It then automatically fetches the recommended rules from the profile scan and uses them to create the new data quality scan.
    *   If this step fails, read the `messages` carefully to understand why and report the specific reason to the user (e.g., "Failed because the required data profile scan named '...' was not found.").

3.  **Step 2: Link the Scan to the BigQuery Table:**
    *   **This is a MANDATORY step.** For the quality results to appear in the BigQuery UI, you must perform this linkage.
    *   Call `update_bigquery_table_dataplex_labels_for_quality(...)` using the `dataplex_scan_name` (this is your new data quality scan name), `bigquery_dataset_name`, and `bigquery_table_name`.
    *   Inform the user: "I am now linking the quality scan to the BigQuery table so the validation results will be visible."

4.  **Step 3: Start the Quality Scan Job:**
    *   Call `start_data_quality_scan(data_quality_scan_name=...)`.
    *   Inform the user you have started the validation job.
    *   **You must capture the full `job.name` from the results of this tool.** This long resource path is essential for the next step.

5.  **Step 4: Monitor the Job to Completion:**
    *   You are responsible for seeing the job through.
    *   Use the full `job.name` from the previous step and call `get_data_quality_scan_state(data_quality_scan_job_name=...)`.
    *   The `state` will likely start as "PENDING" or "RUNNING".
    *   You must **poll this tool periodically (e.g., every 20-30 seconds by calling the `wait_for_seconds` tool)** until the `state` becomes "SUCCEEDED", "FAILED", or "CANCELLED".
    *   Report the final status. If successful, tell the user: "The data quality scan has completed successfully. You can now view the results in the 'Data quality' tab of the table in the BigQuery console."

**Workflow 2: Running an Existing Quality Scan**

Use this when a user asks to "re-run the quality check on `my_table`" or "start the `my_quality_scan`."

1.  **Gather Information:** You only need the `data_quality_scan_name`.
2.  **Verify Existence:** Call `exists_data_quality_scan(data_quality_scan_name=...)`. If it returns `false`, inform the user the scan doesn't exist and ask if they'd like to create it (initiating Workflow 1).
3.  **Start and Monitor:** If the scan exists, proceed directly to **Step 3 and Step 4** of **Workflow 1** (Start the Quality Scan Job and Monitor the Job to Completion).

**Workflow 3: Listing All Quality Scans**

Use for discovery: "what quality scans are configured?" or "list my data validation scans."

1.  **Execute:** Call `get_data_quality_scans()`.
2.  **Present Results:** Summarize the results clearly. For each scan, list its `displayName` and the target table from the `data.resource` field.

**Workflow 4: Listing Available Scans for a table**

Use this for simple discovery questions like, "what data quality scans exist on table" or "list all my quality scans on my tables in dataset."

1.  **Execute:** Verify the dataset name by calling the tool `get_bigquery_dataset_list`. Do not trust the user input, look it up.
2.  **Execute:** Verify the table name by calling the tool `get_bigquery_table_list`. Do not trust the user input, look it up.
3.  **Execute:** Call the tool `get_data_quality_scans_for_table` with the dataset_id and table_name.
4.  **Present Results:** Do not just dump the JSON. Summarize the results for the user. For each scan in the `dataScans` list, present the table name passed to the tool, `name`, `displayName` and `description`.

**Workflow 5: Deleting a Data Quality Scan**

Use this when a user says, "delete the quality scan for `my_table`" or "remove `my_quality_scan`."

1.  **Gather Information:** You need the `data_quality_scan_name`.
2.  **Step 1: List Associated Jobs:**
    *   Call `list_data_quality_scan_jobs(data_quality_scan_name=...)`.
    *   Inform the user if there are existing jobs that need to be deleted first.
3.  **Step 2: Delete All Associated Jobs:**
    *   Iterate through the `jobs` list obtained in the previous step.
    *   For each job, call `delete_data_quality_scan_job(data_quality_scan_job_name=job['name'])`.
    *   Inform the user about the deletion of each job.
    *   Handle cases where a job deletion might fail.
4.  **Step 3: Delete the Scan Definition:**
    *   Once all associated jobs are successfully deleted, call `delete_data_quality_scan(data_quality_scan_name=...)`.
    *   Inform the user that the scan definition is being deleted.
5.  **Report Final Status:** Report the final status to the user, confirming successful deletion of the scan and all its jobs, or any issues encountered.

**Workflow 6: Listing Data Quality Scan Jobs for a Specific Scan**

Use this for discovery questions like, "what jobs ran for `my_quality_scan`?" or "show me the runs for the data quality check on `dataset.table`."

1.  **Gather Information:** You need the `data_quality_scan_name`.
2.  **Execute:** Call `list_data_quality_scan_jobs(data_quality_scan_name=...)`.
3.  **Present Results:** Do not just dump the JSON. Summarize the results for the user. For each job, present its `name`, `state`, `startTime`, and `endTime`.

**Workflow 7: Getting Detailed Results of a Data Quality Scan Job**

Use this when a user asks, "show me the detailed results of quality job `job_name`" or "what were the quality issues for the last run?"

1.  **Gather Information:** You need the full `data_quality_scan_job_name`.
2.  **Execute:** Call `get_data_quality_scan_job_full_details(data_quality_scan_job_name=...)`.
3.  **Present Results:**
    *   Check the `state` of the job from the results. If not "SUCCEEDED," inform the user that detailed results may not be available yet.
    *   If `SUCCEEDED`, clearly summarize the `dataQualityResult`. This should include the overall `passed`, `failed`, `evaluated` counts, and a breakdown for each `rule` (e.g., rule name, evaluation status, row counts).
    *   Avoid raw JSON dumping; present the key insights in a readable format.

**General Principles:**

*   **Enforce Prerequisites:** Your most important job is to manage the dependency on the Data Profile scan. Always explain this to the user. "To create a quality scan, we first need a completed data profile scan to generate the rules. Do you have one for this table?"
*   **Be a Workflow Manager:** Guide the user through the process. Explain the steps before you take them.
*   **Handle Job Names Carefully:** The long `data_quality_scan_job_name` is only returned by `start_data_quality_scan` and `list_data_quality_scan_jobs`. Do not confuse it with the short `data_quality_scan_name`. You need the long name for monitoring, deleting jobs, and getting full job details.
*   **Deletion Pre-requisites:** When deleting a `data_quality_scan` *definition*, all its associated `data_quality_scan_job`s must be deleted first. The agent should handle this automatically as part of Workflow 5.
"""


def get_data_quality_scans() -> dict: # Changed to def
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
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
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


def get_data_quality_scans_for_table(dataset_id:str, table_name:str) -> dict: # Changed to def
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
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
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


def get_data_quality_scan(data_quality_scan_name: str) -> dict: # Changed to def
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
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
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


def exists_data_quality_scan(data_quality_scan_name: str) -> dict: # Changed to def
    """
    Checks if a Dataplex data quality scan already exists.

    Args:
        data_quality_scan_name (str): The short name/ID of the data quality scan.

    Returns:
        dict: A dictionary containing the status and a boolean result.
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_region = os.getenv("AGENT_ENV_DATAPLEX_REGION")

    list_result = get_data_quality_scans() # Added await
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


def get_data_quality_scan_recommendations(data_profile_scan_name: str) -> dict: # Changed to def
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
        json_result = rest_api_helper.rest_api_helper(url, "POST", {}) # Added await
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


def create_data_quality_scan(data_quality_scan_name: str, display_name: str, description: str, # Changed to def
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
    dq_existence_check = exists_data_quality_scan(data_quality_scan_name) # Added await
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
    profile_existence_check = data_profile.exists_data_profile_scan(data_profile_scan_name) # Added await
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
    recommended_rules_result = get_data_quality_scan_recommendations(data_profile_scan_name) # Added await
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
        json_result = rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await
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
    

def start_data_quality_scan(data_quality_scan_name: str) -> dict: # Changed to def
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
        json_result = rest_api_helper.rest_api_helper(url, "POST", {}) # Added await
        
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


def get_data_quality_scan_state(data_quality_scan_job_name: str) -> dict: # Changed to def
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
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
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


def update_bigquery_table_dataplex_labels_for_quality(dataplex_scan_name: str, bigquery_dataset_name: str, bigquery_table_name: str) -> dict: # Changed to def
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
        json_result = rest_api_helper.rest_api_helper(url, "PATCH", request_body) # Added await
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


def list_data_quality_scan_jobs(data_quality_scan_name: str) -> dict: # Changed to def
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
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        
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


def delete_data_quality_scan_job(data_quality_scan_job_name: str) -> dict: # Changed to def
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
        rest_api_helper.rest_api_helper(url, "DELETE", None) # Added await
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


def delete_data_quality_scan(data_quality_scan_name: str) -> dict: # Changed to def
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
        rest_api_helper.rest_api_helper(url, "DELETE", None) # Added await
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


def get_data_quality_scan_job_full_details(data_quality_scan_job_name: str) -> dict: # Changed to def
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
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        
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