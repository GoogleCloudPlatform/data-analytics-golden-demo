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

import data_analytics_agent.utils.caching.caching_utils as caching_utils 
import data_analytics_agent.utils.rest_api.rest_api_helper as rest_api_helper 

logger = logging.getLogger(__name__)

@caching_utils.timed_cache(5 * 60) # Use the async-aware cache decorator
async def get_bigquery_dataset_list() -> dict: # Marked as async def
    """
    Lists all BigQuery datasets in the configured project and specified region.

    Returns:
        dict: A dictionary containing the status and the list of BigQuery datasets.
        {
            "status": "success" or "failed",
            "tool_name": "get_bigquery_dataset_list",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "datasets": [ ... list of dataset objects ... ]
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    bigquery_region = os.getenv("AGENT_ENV_BIGQUERY_REGION") # e.g., "us-central1"
    messages = []

    if not project_id:
        messages.append("Error: AGENT_ENV_PROJECT_ID environment variable not set.")
        return { "status": "failed", "tool_name": "get_bigquery_dataset_list", "query": None, "messages": messages, "results": None }
    if not bigquery_region:
        messages.append("Error: AGENT_ENV_BIGQUERY_REGION environment variable not set.")
        return { "status": "failed", "tool_name": "get_bigquery_dataset_list", "query": None, "messages": messages, "results": None }


    # The URL to list all BigQuery datasets based on the curl command provided.
    # The 'rep' part is included as it was present in your curl example.
    url = f"https://bigquery.{bigquery_region}.rep.googleapis.com/bigquery/v2/projects/{project_id}/datasets"

    try:
        # Call the REST API to get the list of all existing BigQuery datasets
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        messages.append("Successfully retrieved list of all BigQuery datasets from the API.")

        # The BigQuery API response for listing datasets typically has a 'datasets' key
        datasets = json_result.get("datasets", [])

        messages.append(f"Found {len(datasets)} BigQuery datasets.")

        # Create the final results payload with the filtered list
        filtered_results = {"datasets": datasets}

        return {
            "status": "success",
            "tool_name": "get_bigquery_dataset_list",
            "query": None,
            "messages": messages,
            "results": filtered_results
        }
    except Exception as e:
        messages.append(f"An error occurred while listing BigQuery datasets: {e}")
        return {
            "status": "failed",
            "tool_name": "get_bigquery_dataset_list",
            "query": None,
            "messages": messages,
            "results": None
        }