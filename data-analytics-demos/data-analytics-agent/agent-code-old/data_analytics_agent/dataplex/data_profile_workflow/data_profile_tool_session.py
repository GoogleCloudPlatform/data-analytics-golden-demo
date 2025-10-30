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
from google.adk.tools.tool_context import ToolContext
from pydantic import BaseModel, Field
import json
import data_analytics_agent.bigquery.get_bigquery_table_list as get_bigquery_table_list_helper
import data_analytics_agent.gemini.gemini_helper as gemini_helper

# class DataProfileToolSession(BaseModel):
#     data_profile_scan_name: str
#     data_profile_display_name: str
#     bigquery_dataset_name: str
#     bigquery_table_name: str
#     initial_query: str

async def parse_and_set_data_profile_params_tool(tool_context: ToolContext, prompt: str) -> dict:
    """
    Parses a user prompt for data profile scan details and sets them in session state
    for subsequent agents to use.
    The expected prompt format is:
    "Create a data profile scan:\n
    data_profile_scan_name: 'your-scan-name'\n
    data_profile_display_name: 'Your Display Name'\n
    bigquery_dataset_name: 'your_dataset'\n
    bigquery_table_name: 'your_table'"
    """
    scan_details = {
        "data_profile_scan_name": None,
        "data_profile_display_name": None,
        "bigquery_dataset_name": None,
        "bigquery_table_name": None,
    }

    lines = prompt.split('\n')
    for line in lines:
        if ':' in line:
            key_value = line.split(':', 1)
            key = key_value[0].strip().replace('data_profile_', '') # Normalize key for parsing
            value = key_value[1].strip().strip('"').strip("'") # Remove quotes

            if key == "scan_name":
                scan_details["data_profile_scan_name"] = value
            elif key == "display_name":
                scan_details["data_profile_display_name"] = value
            elif key == "bigquery_dataset_name":
                scan_details["bigquery_dataset_name"] = value
            elif key == "bigquery_table_name":
                scan_details["bigquery_table_name"] = value

    response_schema = {
        "type": "object",
        "properties": {
            "bigquery_dataset_name": {
                "type": "string",
                "description": "The matching BigQuery dataset name."
            },
            "bigquery_table_name": {
                "type": "string",
                "description": "The matching BigQuery table name."
            }
        },
        "required": ["bigquery_dataset_name", "bigquery_table_name"]
    }

    get_bigquery_table_list_helper_response = get_bigquery_table_list_helper.get_bigquery_table_list()
    bigquery_dataset_and_table_schema = get_bigquery_table_list_helper_response["results"]

    prompt = f"""You need to match the correct names for the following using the below schema information from BigQuery.

    The user provided this information and the name may or may not be correct.
    There could be misspelled words, spaces, etc.
    You need to find the best match.

    bigquery_dataset_name = "{scan_details['bigquery_dataset_name']}"
    bigquery_table_name = "{scan_details['bigquery_table_name']}"

    <bigquery-dataset-and-table-schema>
    {bigquery_dataset_and_table_schema}
    </bigquery-dataset-and-table-schema>
    """

    gemini_response = gemini_helper.gemini_llm(prompt, response_schema=response_schema, model="gemini-2.5-flash", temperature=0.2)
    gemini_response_dict = json.loads(gemini_response)   

    bigquery_dataset_name = gemini_response_dict.get("bigquery_dataset_name",scan_details["bigquery_dataset_name"]) 
    bigquery_table_name = gemini_response_dict.get("bigquery_table_name",scan_details["bigquery_table_name"]) 

    tool_context.state["data_profile_scan_name_param"] = scan_details["data_profile_scan_name"]
    tool_context.state["data_profile_display_name_param"] = scan_details["data_profile_display_name"]
    tool_context.state["bigquery_dataset_name_param"] = bigquery_dataset_name
    tool_context.state["bigquery_table_name_param"] = bigquery_table_name
    tool_context.state["initial_data_profile_query_param"] = prompt # Store the original query

    # Set this workflow's flag to False
    tool_context.state["_awaiting_data_engineering_workflow_selection"] = False
    print("DEBUG: Flag '_awaiting_data_engineering_workflow_selection' set to False.")
    # Explicitly set the Data Profile flag to True
    tool_context.state["_awaiting_data_profile_workflow_selection"] = True
    print("DEBUG: Flag '_awaiting_data_profile_workflow_selection' set to True (by DE tool).")

    return {
        "status": "success",
        "tool_name": "parse_and_set_data_profile_params_tool",
        "query": None,
        "messages": [
            "Data profile parameters parsed and set in session state and being returned"
        ],
        "results": {
            "data_profile_scan_name" : scan_details["data_profile_scan_name"],
            "data_profile_display_name" : scan_details["data_profile_display_name"],
            "bigquery_dataset_name" : bigquery_dataset_name,
            "bigquery_table_name" : bigquery_table_name
        }
    }
