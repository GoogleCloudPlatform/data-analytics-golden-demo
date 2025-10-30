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
import json
import data_analytics_agent.rest_api_helper as rest_api_helper # Assuming this is now your async version
import os
import logging

logger = logging.getLogger(__name__)

def get_bigquery_table_schema(dataset_id: str, table_id: str) -> dict: # Changed to def
    """Fetches the schema and metadata for a specific BigQuery table.
    This contains more details than the get_bigquery_table_list tool.    

    Args:
        dataset_id (str): The ID of the dataset containing the table.
        table_id (str): The ID of the table whose schema you want to fetch.

    Returns:
        dict: This will return:         
        {
            "status": "success",
            "tool_name": "get_bigquery_table_schema",
            "query": None,
            "messages": ["List of messages during processing"]
            "results": {
                        "status": "success",
                        "schema": {
                            "name": "string",
                            "type": "string",
                            "mode": "string",
                            "schema": {
                                "fields": [
                                    {
                                        "name": "customer_id",
                                        "type": "INTEGER",
                                        "description": "Unique identifier for the customer."
                                    },
                                    {
                                        "name": "first_name",
                                        "type": "STRING",
                                        "description": "The first name of the customer."
                                    }
                                ]
                            }
                        }
            }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    messages = [] # Ensure messages is a list, as it's initialized here
    return_value = None
  
    url = f"https://bigquery.googleapis.com/bigquery/v2/projects/{project_id}/datasets/{dataset_id}/tables/{table_id}"

    try:
        response = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        logger.debug(f"get_bigquery_table_schema -> response: {json.dumps(response, indent=2)}")

        if "schema" in response:
            schema = response["schema"]        
            return_value = { "status": "success", "tool_name": "get_bigquery_table_schema", "query": None, "messages": messages, "results": schema }
            logger.debug(f"get_bigquery_table_schema -> return_value: {json.dumps(return_value, indent=2)}")
        else:
            messages.append(f"Schema not found in the API response for the specified table ({table_id}).") # Changed .add to .append
            return_value = { "status": "failed", "tool_name": "get_bigquery_table_schema", "query": None, "messages": messages, "results": None }

        return return_value 
      
    except Exception as e:
        messages.append(f"Error when calling BigQuery API: {e}") # Changed .add to .append
        return_value = { "status": "failed", "tool_name": "get_bigquery_table_schema", "query": None, "messages": messages, "results": None }
        return return_value