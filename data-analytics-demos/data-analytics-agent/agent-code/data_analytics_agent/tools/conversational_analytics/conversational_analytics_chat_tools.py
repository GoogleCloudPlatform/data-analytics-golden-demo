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
import json_stream
import requests
import google.auth
import google.auth.transport.requests
import collections.abc
import logging
import asyncio
import httpx


logger = logging.getLogger(__name__)


async def conversational_analytics_data_agent_chat_stateful(conversational_analytics_data_agent_id: str, chat_message: str, conversation_id: str) -> dict:
    """
    Initiates a chat with a Conversational Analytics Data Agent and captures the full streaming response.
    This is a stateful conversation since it has a conversation_id.

    This tool handles both stateless (one-off) and stateful (memory-enabled) conversations.
    It connects to the streaming API, collects all the message chunks, processes them to create
    a human-readable log, and returns the complete, structured conversation transcript.

    Args:
        conversational_analytics_data_agent_id (str): The short ID of the data agent to chat with.
        chat_message (str): The user's message or question to send to the agent.
        conversation_id (str): The ID of an existing conversation to continue a stateful chat. 

    Returns:
        dict: A standard agent tool dictionary containing the status and results.
        {
            "status": "success" or "failed",
            "tool_name": "conversational_analytics_data_agent_chat_streaming",
            "query": "The original user chat_message",
            "messages": [
                "Starting stateful conversation (ID: my-convo-123).",
                "Connection successful. Receiving and processing stream...",
                "User Question: How many orders were shipped?",
                "Generated SQL:\nSELECT COUNT(*) FROM orders WHERE status = 'shipped';",
                "Final Summary: There were 123 shipped orders.",
                "Stream finished successfully."
            ],
            "results": [
                {
                    "userMessage": { "text": "How many orders were shipped?" }
                },
                {
                    "systemMessage": {
                        "schema": {
                            "query": { "question": "How many orders were shipped?" }
                        }
                    }
                },
                {
                    "systemMessage": {
                        "data": { "generatedSql": "SELECT COUNT(*) FROM orders WHERE status = 'shipped';" }
                    }
                },
                {
                    "systemMessage": {
                        "text": { "parts": ["There were 123 shipped orders."] }
                    }
                }
            ]
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    global_location = os.getenv("AGENT_ENV_CONVERSATIONAL_ANALYTICS_REGION")
    messages = []

    # --- Helper functions are nested to encapsulate them within the tool ---

    # CORRECTED: Changed from 'async def' to 'def' as no awaitable operations are performed.
    def _convert_to_native(obj):
        """Recursively converts json-stream's objects into native Python types."""
        if isinstance(obj, collections.abc.Mapping):
            return {key: _convert_to_native(value) for key, value in obj.items()}
        elif isinstance(obj, collections.abc.Sequence) and not isinstance(obj, str):
            return [_convert_to_native(item) for item in obj]
        else:
            return obj

    # CORRECTED: Changed from 'async def' to 'def' as no awaitable operations are performed.
    def _process_message(message_dict):
        """Processes a single message dictionary and returns a formatted string for the log."""
        system_message = message_dict.get("systemMessage")
        if not system_message:
            return None # Ignore non-system messages like userMessage

        if question := system_message.get("schema", {}).get("query", {}).get("question"):
            return f"User Question: {question}"
        if generated_sql := system_message.get("data", {}).get("generatedSql"):
            return f"Generated SQL:\n{generated_sql.strip()}"
        if instructions := system_message.get("chart", {}).get("query", {}).get("instructions"):
            return f"Charting Task: {instructions}"
        if parts := system_message.get("text", {}).get("parts"):
            return f"Final Summary: {' '.join(parts)}"
        return None

    # --- Main function logic ---

    url = f"https://geminidataanalytics.googleapis.com/v1alpha/projects/{project_id}/locations/{global_location}:chat"
    
    if conversation_id:
        messages.append(f"Starting stateful conversation (ID: {conversation_id}).")
        request_body = {
            "messages": [{"userMessage": {"text": chat_message}}],
            "conversation_reference": {
                "conversation": f"projects/{project_id}/locations/{global_location}/conversations/{conversation_id}",
                "data_agent_context": {"data_agent": f"projects/{project_id}/locations/{global_location}/dataAgents/{conversational_analytics_data_agent_id}"}
            }
        }
    else:
        messages.append("Starting stateless conversation.")
        request_body = {
            "messages": [{"userMessage": {"text": chat_message}}],
            "data_agent_context": {"data_agent": f"projects/{project_id}/locations/{global_location}/dataAgents/{conversational_analytics_data_agent_id}"}
        }
    
    try:
        credentials, _ = await asyncio.to_thread(google.auth.default,
            scopes=["https://www.googleapis.com/auth/cloud-platform", "https://www.googleapis.com/auth/bigquery"]
        )
        auth_req = google.auth.transport.requests.Request()
        await asyncio.to_thread(credentials.refresh, auth_req)
        
        headers = {
            "Content-Type": "application/json",
            "Authorization": "Bearer " + credentials.token
        }

        all_streamed_objects = []
        async with httpx.AsyncClient() as client:
            async with client.stream("POST", url, json=request_body, headers=headers) as response:
                response.raise_for_status()
                messages.append("Connection successful. Receiving and processing stream...")
                
                response_text = ""
                async for chunk in response.aiter_text():
                    response_text += chunk
                
                import json
                all_streamed_objects = json.loads(response_text) 

                for message_obj in all_streamed_objects:
                    # CORRECTED: Removed 'await' since the function is now synchronous
                    processed_info = _process_message(message_obj)
                    if processed_info:
                        messages.append(processed_info)
        
        messages.append("Stream finished successfully.")
        
        # CORRECTED: Removed 'await' since the function is now synchronous
        native_python_list = _convert_to_native(all_streamed_objects)

        return {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_chat_streaming",
            "query": chat_message,
            "messages": messages,
            "results": native_python_list
        }

    except Exception as e:
        error_message = f"An error occurred during the chat stream: {e}"
        messages.append(error_message)
        return {
            "status": "failed",
            "tool_name": "conversational_analytics_data_agent_chat_streaming",
            "query": chat_message,
            "messages": messages,
            "results": None
        }


async def conversational_analytics_data_agent_chat_stateless(conversational_analytics_data_agent_id: str, chat_message: str) -> dict:
    """
    Initiates a chat with a Conversational Analytics Data Agent and captures the full streaming response.
    This is a stateless conversation since it does not have a conversation_id.

    This tool handles both stateless (one-off) and stateful (memory-enabled) conversations.
    It connects to the streaming API, collects all the message chunks, processes them to create
    a human-readable log, and returns the complete, structured conversation transcript.

    Args:
        conversational_analytics_data_agent_id (str): The short ID of the data agent to chat with.
        chat_message (str): The user's message or question to send to the agent.

    Returns:
        dict: A standard agent tool dictionary containing the status and results.
        {
            "status": "success" or "failed",
            "tool_name": "conversational_analytics_data_agent_chat_streaming",
            "query": "The original user chat_message",
            "messages": [
                "Starting stateful conversation (ID: my-convo-123).",
                "Connection successful. Receiving and processing stream...",
                "User Question: How many orders were shipped?",
                "Generated SQL:\nSELECT COUNT(*) FROM orders WHERE status = 'shipped';",
                "Final Summary: There were 123 shipped orders.",
                "Stream finished successfully."
            ],
            "results": [
                {
                    "userMessage": { "text": "How many orders were shipped?" }
                },
                {
                    "systemMessage": {
                        "schema": {
                            "query": { "question": "How many orders were shipped?" }
                        }
                    }
                },
                {
                    "systemMessage": {
                        "data": { "generatedSql": "SELECT COUNT(*) FROM orders WHERE status = 'shipped';" }
                    }
                },
                {
                    "systemMessage": {
                        "text": { "parts": ["There were 123 shipped orders."] }
                    }
                }
            ]
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    global_location = os.getenv("AGENT_ENV_CONVERSATIONAL_ANALYTICS_REGION")
    messages = []

    # --- Helper functions are nested to encapsulate them within the tool ---

    # CORRECTED: Changed from 'async def' to 'def' as no awaitable operations are performed.
    def _convert_to_native(obj):
        """Recursively converts json-stream's objects into native Python types."""
        if isinstance(obj, collections.abc.Mapping):
            return {key: _convert_to_native(value) for key, value in obj.items()}
        elif isinstance(obj, collections.abc.Sequence) and not isinstance(obj, str):
            return [_convert_to_native(item) for item in obj]
        else:
            return obj

    # CORRECTED: Changed from 'async def' to 'def' as no awaitable operations are performed.
    def _process_message(message_dict):
        """Processes a single message dictionary and returns a formatted string for the log."""
        system_message = message_dict.get("systemMessage")
        if not system_message:
            return None # Ignore non-system messages like userMessage

        if question := system_message.get("schema", {}).get("query", {}).get("question"):
            return f"User Question: {question}"
        if generated_sql := system_message.get("data", {}).get("generatedSql"):
            return f"Generated SQL:\n{generated_sql.strip()}"
        if instructions := system_message.get("chart", {}).get("query", {}).get("instructions"):
            return f"Charting Task: {instructions}"
        if parts := system_message.get("text", {}).get("parts"):
            return f"Final Summary: {' '.join(parts)}"
        return None

    # --- Main function logic ---

    url = f"https://geminidataanalytics.googleapis.com/v1alpha/projects/{project_id}/locations/{global_location}:chat"
    
    conversation_id = None

    if conversation_id:
        messages.append(f"Starting stateful conversation (ID: {conversation_id}).")
        request_body = {
            "messages": [{"userMessage": {"text": chat_message}}],
            "conversation_reference": {
                "conversation": f"projects/{project_id}/locations/{global_location}/conversations/{conversation_id}",
                "data_agent_context": {"data_agent": f"projects/{project_id}/locations/{global_location}/dataAgents/{conversational_analytics_data_agent_id}"}
            }
        }
    else:
        messages.append("Starting stateless conversation.")
        request_body = {
            "messages": [{"userMessage": {"text": chat_message}}],
            "data_agent_context": {"data_agent": f"projects/{project_id}/locations/{global_location}/dataAgents/{conversational_analytics_data_agent_id}"}
        }
    
    try:
        # These are synchronous google.auth calls, so run them in a separate thread
        credentials, _ = await asyncio.to_thread(google.auth.default,
            scopes=["https://www.googleapis.com/auth/cloud-platform", "https://www.googleapis.com/auth/bigquery"]
        )
        auth_req = google.auth.transport.requests.Request()
        await asyncio.to_thread(credentials.refresh, auth_req)

        headers = {
            "Content-Type": "application/json",
            "Authorization": "Bearer " + credentials.token
        }

        all_streamed_objects = []
        async with httpx.AsyncClient() as client:
            async with client.stream("POST", url, json=request_body, headers=headers) as response:
                response.raise_for_status()
                messages.append("Connection successful. Receiving and processing stream...")
                
                response_text = ""
                async for chunk in response.aiter_text():
                    response_text += chunk
                
                import json
                all_streamed_objects = json.loads(response_text) 

                for message_obj in all_streamed_objects:
                    # CORRECTED: Removed 'await' since the function is now synchronous
                    processed_info = _process_message(message_obj)
                    if processed_info:
                        messages.append(processed_info)
        
        messages.append("Stream finished successfully.")
        
        # CORRECTED: Removed 'await' since the function is now synchronous
        native_python_list = _convert_to_native(all_streamed_objects)

        return {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_chat_streaming",
            "query": chat_message,
            "messages": messages,
            "results": native_python_list
        }

    except Exception as e:
        error_message = f"An error occurred during the chat stream: {e}"
        messages.append(error_message)
        return {
            "status": "failed",
            "tool_name": "conversational_analytics_data_agent_chat_streaming",
            "query": chat_message,
            "messages": messages,
            "results": None
        }