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
import logging

import data_analytics_agent.utils.rest_api.rest_api_helper as rest_api_helper

logger = logging.getLogger(__name__)


async def conversational_analytics_data_agent_conversations_list() -> dict: # Changed to def
    """
    Lists all existing conversations in the configured project and region.

    This tool is useful for discovering past conversations that can be resumed or analyzed.
    It returns a list of all conversation resources.

    Returns:
        dict: A standard agent tool dictionary containing the status and results.
        {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_conversations_list",
            "query": None,
            "messages": ["Successfully listed conversations."],
            "results": {
                "conversations": [
                    {
                        "name": "projects/your-project/locations/global/conversations/my-convo-123",
                        "agents": ["projects/your-project/locations/global/dataAgents/sales-agent"],
                        "createTime": "2024-01-01T12:00:00Z"
                    },
                    {
                        "name": "projects/your-project/locations/global/conversations/another-chat-456",
                        "agents": ["projects/your-project/locations/global/dataAgents/support-agent"],
                        "createTime": "2024-01-02T14:30:00Z"
                    }
                ]
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    global_location = os.getenv("AGENT_ENV_CONVERSATIONAL_ANALYTICS_REGION")
    messages = []
    url = f"https://geminidataanalytics.googleapis.com/v1alpha/projects/{project_id}/locations/{global_location}/conversations"
    
    try:
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) 
        messages.append("Successfully listed conversations.")
        return {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_conversations_list",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while listing conversations: {e}")
        return {
            "status": "failed",
            "tool_name": "conversational_analytics_data_agent_conversations_list",
            "query": None,
            "messages": messages,
            "results": None
        }


async def conversational_analytics_data_agent_conversations_get(conversation_id: str) -> dict: # Changed to def
    """
    Retrieves the full details of a specific conversation by its ID.

    Use this tool to inspect the state or history of a single, known conversation.

    Args:
        conversation_id (str): The unique identifier for the conversation (e.g., "my-convo-123").

    Returns:
        dict: A standard agent tool dictionary containing the status and results.
        {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_conversations_get",
            "query": None,
            "messages": ["Successfully retrieved conversation 'my-convo-123'."],
            "results": {
                "name": "projects/your-project/locations/global/conversations/my-convo-123",
                "agents": ["projects/your-project/locations/global/dataAgents/sales-agent"],
                "createTime": "2024-01-01T12:00:00Z"
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    global_location = os.getenv("AGENT_ENV_CONVERSATIONAL_ANALYTICS_REGION")
    messages = []
    url = f"https://geminidataanalytics.googleapis.com/v1alpha/projects/{project_id}/locations/{global_location}/conversations/{conversation_id}"

    try:
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) 
        messages.append(f"Successfully retrieved conversation '{conversation_id}'.")
        return {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_conversations_get",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while getting conversation '{conversation_id}': {e}")
        return {
            "status": "failed",
            "tool_name": "conversational_analytics_data_agent_conversations_get",
            "query": None,
            "messages": messages,
            "results": None
        }


async def conversational_analytics_data_agent_conversations_exists(conversation_id: str) -> dict: # Changed to def
    """
    Checks if a conversation with the specified ID already exists.

    This is a convenient pre-flight check to avoid errors when attempting to create a
    conversation with an ID that is already in use.

    Args:
        conversation_id (str): The unique identifier for the conversation to check.

    Returns:
        dict: A standard agent tool dictionary containing the status and a boolean result.
        {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_conversations_exists",
            "query": None,
            "messages": ["Conversation 'my-convo-123' already exists."],
            "results": {
                "exists": True
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    global_location = os.getenv("AGENT_ENV_CONVERSATIONAL_ANALYTICS_REGION")
    
    list_result = await conversational_analytics_data_agent_conversations_list() 
    messages = list_result.get("messages", [])

    if list_result["status"] == "failed":
        return list_result

    try:
        convo_exists = False
        full_convo_name = f"projects/{project_id}/locations/{global_location}/conversations/{conversation_id}"
        for item in list_result.get("results", {}).get("conversations", []):
            if item.get("name") == full_convo_name:
                convo_exists = True
                messages.append(f"Conversation '{conversation_id}' already exists.")
                break
        
        if not convo_exists:
            messages.append(f"Conversation '{conversation_id}' does not exist.")

        return {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_conversations_exists",
            "query": None,
            "messages": messages,
            "results": {"exists": convo_exists}
        }
    except Exception as e:
        messages.append(f"An error occurred while checking for conversation existence: {e}")
        return {
            "status": "failed",
            "tool_name": "conversational_analytics_data_agent_conversations_exists",
            "query": None,
            "messages": messages,
            "results": None
        }


async def conversational_analytics_data_agent_conversations_create(data_agent_id: str, conversation_id: str) -> dict: # Changed to def
    """
    Creates a new, empty conversation and associates it with a specific data agent.

    This is the first step required before starting a stateful (memory-enabled) chat session.
    The tool first checks if the conversation ID is already in use to prevent errors.

    Args:
        data_agent_id (str): The ID of the data agent to associate this conversation with.
        conversation_id (str): The desired unique ID for the new conversation.

    Returns:
        dict: A standard agent tool dictionary containing the status and results.
        {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_conversations_create",
            "query": None,
            "messages": ["Successfully created conversation 'my-new-convo'."],
            "results": {
                "name": "projects/your-project/locations/global/conversations/my-new-convo",
                "agents": ["projects/your-project/locations/global/dataAgents/sales-agent"],
                "createTime": "2024-01-03T10:00:00Z"
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    global_location = os.getenv("AGENT_ENV_CONVERSATIONAL_ANALYTICS_REGION")

    existence_check = await conversational_analytics_data_agent_conversations_exists(conversation_id) 
    messages = existence_check.get("messages", [])

    if existence_check["status"] == "failed":
        return existence_check
    
    if existence_check["results"]["exists"]:
        return {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_conversations_create",
            "query": None,
            "messages": messages,
            "results": {"created": False, "reason": "Conversation already exists."}
        }

    url = f"https://geminidataanalytics.googleapis.com/v1alpha/projects/{project_id}/locations/{global_location}/conversations?conversation_id={conversation_id}"
    request_body = {
        "agents": [f"projects/{project_id}/locations/{global_location}/dataAgents/{data_agent_id}"]
    }

    try:
        json_result = await rest_api_helper.rest_api_helper(url, "POST", request_body) 
        messages.append(f"Successfully created conversation '{conversation_id}'.")
        return {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_conversations_create",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while creating conversation '{conversation_id}': {e}")
        return {
            "status": "failed",
            "tool_name": "conversational_analytics_data_agent_conversations_create",
            "query": None,
            "messages": messages,
            "results": None
        }