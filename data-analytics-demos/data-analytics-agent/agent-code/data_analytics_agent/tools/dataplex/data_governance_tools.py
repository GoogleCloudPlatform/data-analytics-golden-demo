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

import data_analytics_agent.utils.rest_api.rest_api_helper as rest_api_helper 

import logging

logger = logging.getLogger(__name__)



async def get_data_governance_for_table(dataset_id: str, table_name: str) -> dict: # Changed to def
    """
    Gets all the data governance tags on a table (aspect types).

    Args:
        dataset_id (str): The dataset in which the table resides.  
        table_name (str): The name of the table.

    Returns:
        dict: 
        {
            "status": "success",
            "tool_name": "get_data_governance_for_table",
            "query": None,
            "messages": ["List of messages during processing"]
            "results": {
                "name": "projects/{project-id}/locations/us/entryGroups/@bigquery/entries/bigquery.googleapis.com/projects/{project-id}/datasets/governed_data_curated/tables/customer",
                "entryType": "projects/{project-number}/locations/global/entryTypes/bigquery-table",
                "createTime": "2025-06-12T14:05:40.087281Z",
                "updateTime": "2025-06-23T15:51:16.656516Z",
                "aspects": {
                    "{project-number}.global.data-domain-aspect-type": {
                    "aspectType": "projects/{project-number}/locations/global/aspectTypes/data-domain-aspect-type",
                    "createTime": "2025-06-23T15:51:16.006056Z",
                    "updateTime": "2025-06-23T15:51:16.006056Z",
                    "data": {
                        "zone": "Curated"
                    },
                    "aspectSource": {}
                    },
                etc...
                }
        }     
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    bigquery_region = os.getenv("AGENT_ENV_BIGQUERY_REGION")
    messages = []

    # Note: The URL uses bigquery_region (e.g., 'us-central1') for Dataplex entry points for BigQuery resources.
    # It constructs a fully qualified resource name for the BigQuery table within Dataplex Entry Groups.
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{bigquery_region}/entryGroups/@bigquery/entries/bigquery.googleapis.com/projects/{project_id}/datasets/{dataset_id}/tables/{table_name}?view=ALL"

    try:
        response = await rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        logger.debug(f"get_data_governance_for_table -> response: {json.dumps(response, indent=2)}")

        return_value = { "status": "success", "tool_name": "get_data_governance_for_table", "query": None, "messages": messages, "results": response }
        logger.debug(f"get_data_governance_for_table -> return_value: {json.dumps(return_value, indent=2)}")

        return return_value            

    except Exception as e:
        messages.append(f"Error when calling rest api: {e}")
        return_value = { "status": "failed", "tool_name": "get_data_governance_for_table", "query": None, "messages": messages, "results": None }   
        return return_value