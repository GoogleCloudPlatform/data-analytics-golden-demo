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
import yaml # Not used in this specific file, but kept from original import
import data_analytics_agent.rest_api_helper as rest_api_helper # Assuming this is your async version
import logging

logger = logging.getLogger(__name__)


def conversational_analytics_data_agent_list() -> dict: # Changed to def
    """
    Lists all available Conversational Analytics Data Agents in the configured project and region.

    This tool is useful for discovering which agents have already been created.

    Returns:
        dict: A standard agent tool dictionary containing the status and results.
        {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_list",
            "query": None,
            "messages": ["Successfully listed conversational data agents."],
            "results": {
                "dataAgents": [
                    {
                        "name": "projects/your-project/locations/global/dataAgents/sales-agent-1",
                        "createTime": "2024-01-01T12:00:00Z",
                        "data_analytics_agent": {
                            "published_context": {
                                "datasource_references": {"bq": {"tableReferences": [{"tableId": "sales"}]}},
                                "system_instruction": "You are a sales analyst..."
                            }
                        }
                    },
                    {
                        "name": "projects/your-project/locations/global/dataAgents/support-agent-2",
                        "createTime": "2024-01-02T14:30:00Z",
                        "data_analytics_agent": {
                            "published_context": {
                                "datasource_references": {"bq": {"tableReferences": [{"tableId": "tickets"}]}},
                                "system_instruction": "You are a customer support analyst..."
                            }
                        }
                    }
                ]
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    global_location = os.getenv("AGENT_ENV_CONVERSATIONAL_ANALYTICS_REGION")
    messages = []
    url = f"https://geminidataanalytics.googleapis.com/v1alpha/projects/{project_id}/locations/{global_location}/dataAgents"

    try:
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        messages.append("Successfully listed conversational data agents.")
        return {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_list",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while listing data agents: {e}")
        return {
            "status": "failed",
            "tool_name": "conversational_analytics_data_agent_list",
            "query": None,
            "messages": messages,
            "results": None
        }


def conversational_analytics_data_agent_exists(data_agent_id: str) -> dict: # Changed to def
    """
    Checks if a Conversational Analytics Data Agent with a specific ID already exists.

    This is a key utility to prevent errors when attempting to create a data agent with
    an ID that is already in use.

    Args:
        data_agent_id (str): The short, unique identifier for the data agent to check.

    Returns:
        dict: A standard agent tool dictionary containing the status and a boolean result.
        {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_exists",
            "query": None,
            "messages": ["Data agent 'sales-agent-1' already exists."],
            "results": {
                "exists": True
            }
        }
    }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    global_location = os.getenv("AGENT_ENV_CONVERSATIONAL_ANALYTICS_REGION")

    list_result = conversational_analytics_data_agent_list() # Added await
    messages = list_result.get("messages", [])

    if list_result["status"] == "failed":
        return list_result

    try:
        agent_exists = False
        full_agent_name = f"projects/{project_id}/locations/{global_location}/dataAgents/{data_agent_id}"
        for item in list_result.get("results", {}).get("dataAgents", []):
            if item.get("name") == full_agent_name:
                agent_exists = True
                messages.append(f"Data agent '{data_agent_id}' already exists.")
                break
        
        if not agent_exists:
            messages.append(f"Data agent '{data_agent_id}' does not exist.")

        return {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_exists",
            "query": None,
            "messages": messages,
            "results": {"exists": agent_exists}
        }
    except Exception as e:
        messages.append(f"An error occurred while checking for data agent existence: {e}")
        return {
            "status": "failed",
            "tool_name": "conversational_analytics_data_agent_exists",
            "query": None,
            "messages": messages,
            "results": None
        }


def conversational_analytics_data_agent_get(data_agent_id: str) -> dict: # Changed to def
    """
    Retrieves the full configuration and details of a single, specified data agent.

    Use this tool when you need to inspect the system instructions or data sources
    of a known data agent.

    Args:
        data_agent_id (str): The short, unique identifier for the data agent to retrieve.

    Returns:
        dict: A standard agent tool dictionary containing the status and the full agent resource.
        {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_get",
            "query": None,
            "messages": ["Successfully retrieved data agent 'sales-agent-1'."],
            "results": {
                "name": "projects/your-project/locations/global/dataAgents/sales-agent-1",
                "createTime": "2024-01-01T12:00:00Z",
                "data_analytics_agent": {
                    "published_context": {
                        "datasource_references": {"bq": {"tableReferences": [{"tableId": "sales"}]}},
                        "system_instruction": "You are a sales analyst..."
                    }
                }
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    global_location = os.getenv("AGENT_ENV_CONVERSATIONAL_ANALYTICS_REGION")
    messages = []
    url = f"https://geminidataanalytics.googleapis.com/v1alpha/projects/{project_id}/locations/{global_location}/dataAgents/{data_agent_id}"

    try:
        json_result = rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        messages.append(f"Successfully retrieved data agent '{data_agent_id}'.")
        return {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_get",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while getting data agent '{data_agent_id}': {e}")
        return {
            "status": "failed",
            "tool_name": "conversational_analytics_data_agent_get",
            "query": None,
            "messages": messages,
            "results": None
        }


def conversational_analytics_data_agent_create(data_agent_id: str, system_instruction: str, bigquery_data_source: dict, enable_python: bool = False) -> dict: # Changed to def
    """
    Creates a new Conversational Analytics Data Agent if it does not already exist.

    This tool requires a pre-formatted system instruction (often YAML) and a dictionary
    defining the BigQuery data sources the agent can access.

    Args:
        data_agent_id (str): The desired unique ID for the new data agent.
        system_instruction (str): The detailed prompt and configuration (e.g., in YAML format)
                                  that defines the agent's persona, knowledge, and rules.
        bigquery_data_source (dict): A dictionary specifying the BigQuery tables.
                                     Example: {"bq": {"tableReferences": [{"tableId": "sales"}]}}
        enable_python (bool, optional): Flag to enable Python code generation. Defaults to False.

    Returns:
        dict: A standard agent tool dictionary with the status and API response.
        {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_create",
            "query": None,
            "messages": ["Successfully created data agent 'new-sales-agent'."],
            "results": {
                "name": "operations/12345",
                "metadata": {
                    "@type": "type.googleapis.com/google.cloud.gemini.v1alpha.OperationMetadata",
                    "target": "projects/your-project/locations/global/dataAgents/new-sales-agent"
                }
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    global_location = os.getenv("AGENT_ENV_CONVERSATIONAL_ANALYTICS_REGION")

    existence_check = conversational_analytics_data_agent_exists(data_agent_id) # Added await
    messages = existence_check.get("messages", [])

    if existence_check["status"] == "failed":
        return existence_check

    if existence_check["results"]["exists"]:
        return {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_create",
            "query": None,
            "messages": messages,
            "results": {"created": False, "reason": "Data agent already exists."}
        }

    url = f"https://geminidataanalytics.googleapis.com/v1alpha/projects/{project_id}/locations/{global_location}/dataAgents?data_agent_id={data_agent_id}"
    request_body = {
        "data_analytics_agent": {
            "published_context": {
                "datasource_references": bigquery_data_source,
                "system_instruction": system_instruction,
                "options": {"analysis": {"python": {"enabled": enable_python}}}
            }
        }
    }

    try:
        json_result = rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await
        messages.append(f"Successfully created data agent '{data_agent_id}'.")
        return {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_create",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while creating data agent '{data_agent_id}': {e}")
        return {
            "status": "failed",
            "tool_name": "conversational_analytics_data_agent_create",
            "query": None,
            "messages": messages,
            "results": None
        }


def conversational_analytics_data_agent_delete(data_agent_id: str) -> dict: # Changed to def
    """
    Permanently deletes a specified Conversational Analytics Data Agent.

    Warning: This action is irreversible and will remove the agent and its configuration.

    Args:
        data_agent_id (str): The short, unique identifier of the data agent to delete.

    Returns:
        dict: A standard agent tool dictionary indicating the outcome.
        {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_delete",
            "query": None,
            "messages": ["Successfully deleted data agent 'old-agent'."],
            "results": {}
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    global_location = os.getenv("AGENT_ENV_CONVERSATIONAL_ANALYTICS_REGION")
    messages = []
    url = f"https://geminidataanalytics.googleapis.com/v1alpha/projects/{project_id}/locations/{global_location}/dataAgents/{data_agent_id}"

    try:
        # A successful DELETE often returns an empty JSON object.
        json_result = rest_api_helper.rest_api_helper(url, "DELETE", None) # Added await
        messages.append(f"Successfully deleted data agent '{data_agent_id}'.")
        return {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_delete",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while deleting data agent '{data_agent_id}': {e}")
        return {
            "status": "failed",
            "tool_name": "conversational_analytics_data_agent_delete",
            "query": None,
            "messages": messages,
            "results": None
        }