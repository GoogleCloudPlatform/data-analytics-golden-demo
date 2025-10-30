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
import logging
import re

from typing import Optional
from google.adk.tools.tool_context import ToolContext


logger = logging.getLogger(__name__)

async def parse_and_set_data_engineering_params_tool(tool_context: ToolContext, prompt: str) -> dict:
    """
    Parses the user prompt for data engineering workflow parameters and sets them in the session state.
    Expected parameters: data_quality_scan_name, repository_name, workspace_name, workflow_type.
    """
    logger.info(f"BEGIN: parse_and_set_data_engineering_params_tool with prompt: {prompt}")

    # Initialize all parameters as None
    data_quality_scan_name = None
    repository_name = None
    workspace_name = None
    workflow_type = None

    # --- Extract from structured part of the prompt if present (using regex) ---
    repo_match = re.search(r"repository_name:\s*\"([^\"]+)\"", prompt, re.IGNORECASE)
    if repo_match:
        repository_name = repo_match.group(1)

    workspace_match = re.search(r"workspace_name:\s*\"([^\"]+)\"", prompt, re.IGNORECASE)
    if workspace_match:
        workspace_name = workspace_match.group(1)
        
    dq_scan_match = re.search(r"data_quality_scan_name:\s*\"([^\"]+)\"", prompt, re.IGNORECASE)
    if dq_scan_match:
        data_quality_scan_name = dq_scan_match.group(1)

    # --- Infer workflow_type from natural language part of the prompt ---
    # The Coordinator's prompt has clear instructions for this inference.
    lower_prompt = prompt.lower()
    if "dataform pipeline" in lower_prompt or "dataform" in lower_prompt or "repository" in lower_prompt or "workspace" in lower_prompt or "repo" in lower_prompt:
        workflow_type = "DATAFORM_PIPELINE"
    elif "bigquery pipeline" in lower_prompt or "bigquery" in lower_prompt: # Added "bigquery" alone for robustness
        workflow_type = "BIGQUERY_PIPELINE"
    # Add more conditions for other workflow types if applicable

    # Set parameters in session state using the _param suffix
    tool_context.state["data_quality_scan_name_param"] = data_quality_scan_name
    tool_context.state["repository_name_param"] = repository_name
    tool_context.state["workspace_name_param"] = workspace_name
    tool_context.state["workflow_type_param"] = workflow_type

    # Set this workflow's flag to True
    tool_context.state["_awaiting_data_engineering_workflow_selection"] = True
    print("DEBUG: Flag '_awaiting_data_engineering_workflow_selection' set to True.")
    # Explicitly set the Data Profile flag to False
    tool_context.state["_awaiting_data_profile_workflow_selection"] = False
    print("DEBUG: Flag '_awaiting_data_profile_workflow_selection' set to False (by DE tool).")


    messages = []
    success = True

    # --- Validation: Check if all critical parameters were successfully extracted/inferred ---
    if not data_quality_scan_name:
        messages.append("Missing 'data_quality_scan_name' in prompt.")
        success = False
    if not repository_name:
        messages.append("Missing 'repository_name' in prompt.")
        success = False
    if not workspace_name:
        messages.append("Missing 'workspace_name' in prompt.")
        success = False
    if not workflow_type:
        messages.append("Could not infer 'workflow_type' from prompt. Please specify if it's a 'dataform pipeline' or 'bigquery pipeline'.")
        success = False

    if success:
        messages.append("All required data engineering workflow parameters successfully parsed.")
    else:
        messages.append("Failed to parse all required data engineering workflow parameters.")
    
    logger.info(f"END: parse_and_set_data_engineering_params_tool - Result: {{'status': 'success' if success else 'failed', 'messages': {messages}, 'extracted_params': {{'data_quality_scan_name': {data_quality_scan_name}, 'repository_name': {repository_name}, 'workspace_name': {workspace_name}, 'workflow_type': {workflow_type}}}}}")

    return {
        "status": "success" if success else "failed",
        "tool_name": "parse_and_set_data_engineering_params_tool",
        "query": prompt,
        "messages": messages,
        "results": {
            "data_quality_scan_name": data_quality_scan_name,
            "repository_name": repository_name,
            "workspace_name": workspace_name,
            "workflow_type": workflow_type,
            "all_params_set": success # Indicate if all critical params were set
        }
    }