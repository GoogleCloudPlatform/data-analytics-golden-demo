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
import asyncio
from typing import AsyncGenerator, Optional, List, Dict, Any
from typing_extensions import override
from pydantic import BaseModel, Field
from google.adk.events import Event
import os # Needed for project ID, region etc.
import json # Still needed for other parts of the agent, e.g., in _fail_workflow_event

from google.adk.agents import LlmAgent, BaseAgent, LoopAgent
from google.adk.agents.invocation_context import InvocationContext
from google.genai import types
from google.adk.tools.tool_context import ToolContext

# Tools from data_engineering_agent_autonomous
import data_analytics_agent.data_engineering_agent_autonomous.data_engineering_tools as de_tools
# Tools from dataform
import data_analytics_agent.dataform.dataform as dataform_helper
# Tools from wait_tool
import data_analytics_agent.wait_tool as wait_tool_helper
# Specific tool from the current data_engineering_agent.py location
import data_analytics_agent.gemini.gemini_helper as gemini_helper # New import for internal LLM calls
import data_analytics_agent.data_engineering_agent.data_engineering_agent as de_agent_for_normalization


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

GEMINI_MODEL = "gemini-2.5-flash" # Use flash for faster tool calls, pro for reasoning if needed

# This will be the FINAL output schema for the DataEngineeringWorkflowCustomAgent (the orchestrator)
class DataEngineeringWorkflowOutput(BaseModel):
    status: str = Field(description="Overall status: 'success' or 'failed'")
    tool_name: str = Field(description="Name of the workflow that produced this result.")
    query: Optional[str] = Field(None, description="The query that initiated the workflow (if applicable).")
    messages: list[str] = Field(description="List of informational messages during processing.")
    results: Optional[dict] = Field(None, description="Detailed results of the data engineering workflow.")
    success: bool = Field(description="Did the overall workflow succeed?")

# Output schemas for individual LlmAgents (matching the tool's dictionary output structure)
class InitialPromptParseOutput(BaseModel):
    workflow_type: str = Field(description="Identified workflow type: 'BIGQUERY_PIPELINE', 'DATAFORM_PIPELINE', or 'UNKNOWN'")
    repository_name: str = Field(description="Extracted or inferred repository name. 'MISSING' if not found.")
    workspace_name: str = Field(description="Extracted or inferred workspace name. Defaults to 'default' or 'MISSING' if not found.")
    success: bool = Field(description="Did the parsing tool call complete successfully?")

class NormalizeBigQueryResourceNamesOutput(BaseModel):
    rewritten_prompt: str = Field(description="The original user prompt with all identified BigQuery dataset and table names corrected to their exact canonical forms.")
    success: bool = Field(description="Did the tool call complete successfully?")

class GenerateFixPromptOutput(BaseModel):
    data_engineering_prompt: str = Field(description="The generated data engineering prompt.")
    success: bool = Field(description="Did the tool call complete successfully?")

class ResolveRepositoryOutput(BaseModel):
    exists: bool = Field(description="True if repository exists, False otherwise (from get_repository).")
    repository_id: Optional[str] = Field(None, description="The ID of the Dataform repository (if exists).")
    success: bool = Field(description="Did the tool call complete successfully?")

class ResolveWorkspaceOutput(BaseModel):
    exists: bool = Field(description="True if workspace exists, False otherwise (from get_workspace).")
    workspace_id: Optional[str] = Field(None, description="The ID of the Dataform workspace (if exists).")
    discovered_workspaces: List[str] = Field(description="List of discovered workspace IDs if resolution was ambiguous.")
    success: bool = Field(description="Did the tool call complete successfully?")

class FileExistenceOutput(BaseModel):
    exists: bool = Field(description="True if the file exists, False otherwise.")
    success: bool = Field(description="Did the tool call complete successfully.")

class GeneralSuccessOutput(BaseModel):
    success: bool = Field(description="Did the tool call complete successfully?")

class CallDataEngAgentOutput(BaseModel):
    agent_raw_output: List[str] = Field(description="Raw output from the data engineering agent (flattened list of messages).")
    success: bool = Field(description="Did the tool call complete successfully?")

class LLMJudgeOutput(BaseModel):
    satisfactory: bool = Field(description="True if the LLM judge deemed the results satisfactory, False otherwise.")
    reasoning: Optional[str] = Field(None, description="Reasoning provided by the LLM judge.")
    success: bool = Field(description="Did the tool call complete successfully.")

class CompileAndRunWorkflowOutput(BaseModel):
    workflow_invocation_id: Optional[str] = Field(None, description="The ID of the Dataform workflow invocation.")
    compilation_id: Optional[str] = Field(None, description="The ID of the Dataform compilation result.")
    success: bool = Field(description="Did the tool call complete successfully.")

class CheckJobStateOutput(BaseModel):
    job_state: str = Field(description="The state of the Dataform job (e.g., SUCCEEDED, FAILED, RUNNING)."
    )
    success: bool = Field(description="Did the tool call complete successfully.")

class TimeDelayOutput(BaseModel):
    duration: int = Field(description="The duration the agent waited in seconds.")
    success: bool = Field(description="Did the tool call complete successfully.")


# --- Wrapper Functions for Tools ---

# New Wrapper for parsing the initial user prompt
async def parse_initial_prompt_wrapper(user_prompt: str) -> dict:
    logger.info("BEGIN: parse_initial_prompt_wrapper")

    response_schema = {
        "type": "object",
        "properties": {
            "workflow_type": {
                "type": "string",
                "description": "Identified workflow type: 'BIGQUERY_PIPELINE' if the prompt mentions 'BigQuery pipeline', 'DATAFORM_PIPELINE' if it mentions 'Dataform pipeline', 'repository', or 'workspace'. If neither is clearly specified, return 'UNKNOWN'.",
                "enum": ["BIGQUERY_PIPELINE", "DATAFORM_PIPELINE", "UNKNOWN"]
            },
            "repository_name": {
                "type": "string",
                "description": "The full, exact name of the pipeline or Dataform repository as provided by the user. For example, if the prompt is 'pipeline named Sales Data Pipeline 01', extract 'Sales Data Pipeline 01'. If multiple names are present, pick the one most closely associated with the main pipeline task. Return 'MISSING' if no repository/pipeline name can be clearly identified.",
            },
            "workspace_name": {
                "type": "string",
                "description": "The name of the Dataform workspace. Look for 'workspace Z'. If not specified for a 'DATAFORM_PIPELINE', default to 'default'. If not applicable (e.g., BIGQUERY_PIPELINE where workspace is always 'default'), state 'default'.",
            }
        },
        "required": ["workflow_type", "repository_name", "workspace_name"]
    }

    prompt = f"""
    You are an expert Data Engineering Workflow orchestrator. Your task is to accurately parse a user's natural language request to identify the core components needed to initiate a data pipeline creation or modification workflow.

    **Instructions:**
    1.  **Identify Workflow Type:**
        *   If the user explicitly mentions "BigQuery pipeline" or just "pipeline", set `workflow_type` to "BIGQUERY_PIPELINE".
        *   If the user explicitly mentions "Dataform pipeline", "Dataform repository", "Dataform workspace", or just "repository" or "workspace" in the context of a pipeline, set `workflow_type` to "DATAFORM_PIPELINE".
        *   If the type is ambiguous or not mentioned, set `workflow_type` to "UNKNOWN".
    2.  **Extract Repository Name:**
        *   Look for phrases like "pipeline named 'X'", "repository 'Y'", or similar explicit mentions.
        *   **Crucially, extract the *full, exact string* of the name.** For example, if the prompt is "Create a new BigQuery pipeline named 'Sales Data Pipeline 01'", then `repository_name` should be "Sales Data Pipeline 01".
        *   If a clear repository or pipeline name is not found, set `repository_name` to "MISSING".
    3.  **Extract Workspace Name:**
        *   Look for phrases like "workspace 'Z'".
        *   If `workflow_type` is "BIGQUERY_PIPELINE", the `workspace_name` should *always* be "default", regardless of user input.
        *   If `workflow_type` is "DATAFORM_PIPELINE" and a workspace name is *not* explicitly provided by the user, default `workspace_name` to "default".
        *   If `workflow_type` is "DATAFORM_PIPELINE" and a workspace name *is* provided, use that name.

    **Example User Prompts and Expected Extractions (for guidance):**
    - User: "Create a new BigQuery pipeline named 'Sales Data Pipeline 01'. I want to generate a denormalized sales table..."
      Output: workflow_type='BIGQUERY_PIPELINE', repository_name='Sales Data Pipeline 01', workspace_name='default'
    - User: "Modify my Dataform repository 'sales-etl' in workspace 'dev' to add a new view."
      Output: workflow_type='DATAFORM_PIPELINE', repository_name='sales-etl', workspace_name='dev'
    - User: "Build a new pipeline to process customer data."
      Output: workflow_type='UNKNOWN', repository_name='MISSING', workspace_name='MISSING' (or 'default' if an action could imply it)

    Your response MUST be a JSON object conforming to the provided 'response_schema'. Do NOT include any conversational text outside the JSON.

    Here is the user's prompt: 
    <user-prompt>
    {user_prompt}
    </user-prompt>
    """

    parsing_success = False

    try:
        gemini_raw_response = await asyncio.to_thread(
            gemini_helper.gemini_llm,
            prompt=prompt,
            model=GEMINI_MODEL,
            response_schema=response_schema,
            temperature=0.1,
            topK=1
        )

        parsed_response = json.loads(gemini_raw_response)
        
        # Apply defaulting logic as confirmed
        workflow_type = parsed_response.get("workflow_type", "UNKNOWN")
        repository_name = parsed_response.get("repository_name", "MISSING")
        workspace_name = parsed_response.get("workspace_name", "MISSING")

        if workflow_type == "BIGQUERY_PIPELINE":
            workspace_name = "default"
        elif workflow_type == "DATAFORM_PIPELINE" and workspace_name == "MISSING":
            workspace_name = "default" # Default if not specified for Dataform pipeline too
        
        # Check if critical information was successfully extracted
        if workflow_type != "UNKNOWN" and repository_name != "MISSING":
            parsing_success = True

        logger.info(f"END: parse_initial_prompt_wrapper - Parsed: {{'workflow_type': {workflow_type}, 'repository_name': {repository_name}, 'workspace_name': {workspace_name}}}, Success: {parsing_success}")
        
        return {
            "workflow_type": workflow_type,
            "repository_name": repository_name,
            "workspace_name": workspace_name,
            "success": parsing_success # Reflect actual parsing success of critical fields
        }

    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse Gemini's JSON response for initial prompt parsing: {e}. Raw: {gemini_raw_response}", exc_info=True)
        return {
            "workflow_type": "UNKNOWN",
            "repository_name": "MISSING",
            "workspace_name": "MISSING",
            "success": False
        }
    except Exception as e:
        logger.error(f"An error occurred during initial prompt parsing: {e}", exc_info=True)
        return {
            "workflow_type": "UNKNOWN",
            "repository_name": "MISSING",
            "workspace_name": "MISSING",
            "success": False
        }

# Wrapper for de_agent_for_normalization.normalize_bigquery_resource_names
async def normalize_bigquery_resource_names_wrapper(user_prompt: str) -> dict:
    """
    Normalizes BigQuery dataset and table names within a user's prompt by
    identifying inexact references and replacing them with exact, canonical
    BigQuery resource names.
    """
    logger.info("BEGIN: normalize_bigquery_resource_names_wrapper")
    result = await asyncio.to_thread(
        de_agent_for_normalization.normalize_bigquery_resource_names,
        user_prompt
    )
    logger.info(f"END: normalize_bigquery_resource_names_wrapper: {result}")
    success = result.get("status") == "success"
    response = {
        "rewritten_prompt": result.get("results", {}).get("rewritten_prompt", user_prompt),
        "success": success,
    }
    return response

# Wrapper for dataform_helper.get_repository_id_based_upon_display_name
async def get_repository_id(repository_name: str) -> dict:
    logger.info("BEGIN: get_repository_id")
    if not repository_name:
        return {"exists": False, "repository_id": None, "success": False}
    
    result_from_dataform_tool = await asyncio.to_thread(dataform_helper.get_repository_id_based_upon_display_name, repository_name)
    logger.info(f"Result from dataform_helper.get_repository_id_based_upon_display_name: {result_from_dataform_tool}")

    success = result_from_dataform_tool.get("status") == "success"
    processed_output = {
        "exists": result_from_dataform_tool.get("results", {}).get("exists", False),
        "repository_id": (result_from_dataform_tool.get("results", {}).get("repository_id").split('/')[-1]
                          if result_from_dataform_tool.get("results", {}).get("repository_id") else None),
        "success": success,
    }

    logger.info(f"END: get_repository_id: {processed_output}")
    return processed_output

# Wrapper for dataform_helper.create_bigquery_pipeline
async def create_bigquery_pipeline(derived_repository_id: str, repository_display_name: str) -> dict:
    logger.info("BEGIN: create_bigquery_pipeline")
    if not all([derived_repository_id, repository_display_name]):
        logger.error("Error: Missing parameters for create_bigquery_pipeline.")
        return {"success": False, "exists": False, "repository_id": None}
    
    result = await asyncio.to_thread(dataform_helper.create_bigquery_pipeline, derived_repository_id, repository_display_name)
    logger.info(f"END: create_bigquery_pipeline: {result}")

    success = result.get("status") == "success"
    repo_id_from_creation = (result.get("results", {}).get("name").split('/')[-1]
                             if result.get("results", {}).get("name") else None) if success else None

    return {
        "success": success,
        "exists": success, # If created, it now exists
        "repository_id": repo_id_from_creation
    }

# Wrapper for dataform_helper.create_dataform_pipeline
async def create_dataform_pipeline(actual_repository_id: str, repository_display_name: str) -> dict:
    logger.info("BEGIN: create_dataform_pipeline")
    if not all([actual_repository_id, repository_display_name]):
        logger.error("Error: Missing parameters for create_dataform_pipeline.")
        return {"success": False, "exists": False, "repository_id": None}
    
    result = await asyncio.to_thread(dataform_helper.create_dataform_pipeline, actual_repository_id, repository_display_name)
    logger.info(f"END: create_dataform_pipeline: {result}")

    success = result.get("status") == "success"
    repo_id_from_creation = (result.get("results", {}).get("name").split('/')[-1]
                             if result.get("results", {}).get("name") else None) if success else None

    return {
        "success": success,
        "exists": success, # If created, it now exists
        "repository_id": repo_id_from_creation
    }

# Wrapper for dataform_helper.get_workspace_id_based_upon_display_name
async def get_workspace_id(actual_repository_id: str, target_workspace_name: str) -> dict:
    logger.info("BEGIN: get_workspace_id")
    
    if not all([actual_repository_id, target_workspace_name]):
        logger.error("Error: Missing parameters for get_workspace_id.")
        return {"exists": False, "workspace_id": None, "discovered_workspaces": [], "success": False}
    
    result_from_dataform_tool = await asyncio.to_thread(dataform_helper.get_workspace_id_based_upon_display_name, actual_repository_id, target_workspace_name)
    logger.info(f"Result from dataform_helper.get_workspace_id_based_upon_display_name: {result_from_dataform_tool}")

    if result_from_dataform_tool is None:
        logger.error(f"Error: dataform_helper.get_workspace_id_based_upon_display_name returned None for repository '{actual_repository_id}', workspace '{target_workspace_name}'.")
        return {"exists": False, "workspace_id": None, "discovered_workspaces": [], "success": False}
    
    success = result_from_dataform_tool.get("status") == "success"
    processed_output = {
        "exists": result_from_dataform_tool.get("results", {}).get("exists", False),
        "workspace_id": result_from_dataform_tool.get("results", {}).get("workspace_id"),
        "discovered_workspaces": result_from_dataform_tool.get("discovered-workspaces", []),
        "success": success
    }
    
    logger.info(f"END: get_workspace_id: {processed_output}")
    return processed_output

# Wrapper for dataform_helper.create_workspace
async def create_workspace(actual_repository_id: str, actual_workspace_id: str) -> dict:
    logger.info("BEGIN: create_workspace")
    if not all([actual_repository_id, actual_workspace_id]):
        logger.error("Error: Missing parameters for create_workspace.")
        return {"success": False}
    
    result = await asyncio.to_thread(dataform_helper.create_workspace, actual_repository_id, actual_workspace_id)
    logger.info(f"END: create_workspace: {result}")
    
    success = result.get("status") == "success"
    return {"success": success}

# Wrapper for dataform_helper.does_workspace_file_exist (for workflow_settings.yaml)
async def check_for_workflow_settings(actual_repository_id: str, actual_workspace_id: str) -> dict:
    logger.info("BEGIN: check_for_workflow_settings")
    if not all([actual_repository_id, actual_workspace_id]):
        logger.error("Error: Missing parameters for check_for_workflow_settings.")
        return {"exists": False, "success": False}
    
    result = await asyncio.to_thread(dataform_helper.does_workspace_file_exist, actual_repository_id, actual_workspace_id, "workflow_settings.yaml")
    logger.info(f"END: check_for_workflow_settings: {result}")

    success = result.get("status") == "success"
    exists = result.get("results", {}).get("exists", False) if success else False # Ensure exists is only true if tool call succeeded
    return {"exists": exists, "success": success}

# Wrapper for dataform_helper.write_workflow_settings_file
async def upload_workflow_settings(actual_repository_id: str, actual_workspace_id: str) -> dict:
    logger.info("BEGIN: upload_workflow_settings")
    if not all([actual_repository_id, actual_workspace_id]):
        logger.error("Error: Missing parameters for upload_workflow_settings.")
        return {"success": False}
    
    result = await asyncio.to_thread(dataform_helper.write_workflow_settings_file, actual_repository_id, actual_workspace_id)
    logger.info(f"END: upload_workflow_settings: {result}")
    
    success = result.get("status") == "success"
    return {"success": success}

# Wrapper for dataform_helper.commit_workspace
async def commit_source_control(actual_repository_id: str, actual_workspace_id: str, commit_message: str) -> dict:
    logger.info("BEGIN: commit_source_control")
    if not all([actual_repository_id, actual_workspace_id, commit_message]):
        logger.error("Error: Missing parameters for commit_source_control.")
        return {"success": False}
    
    result = await asyncio.to_thread(dataform_helper.commit_workspace, actual_repository_id, actual_workspace_id, "Autonomous Data Engineering Agent", "agent@example.com", commit_message)
    logger.info(f"END: commit_source_control: {result}")
    
    success = result.get("status") == "success"
    return {"success": success}

# Wrapper for de_tools.call_bigquery_data_engineering_agent
async def call_bigquery_data_engineering_agent_wrapper(actual_repository_id: str, actual_workspace_id: str, data_engineering_prompt: str) -> dict:
    logger.info("BEGIN: call_bigquery_data_engineering_agent_wrapper")
    if not all([actual_repository_id, actual_workspace_id, data_engineering_prompt]):
        logger.error("Error: Missing parameters for call_bigquery_data_engineering_agent_wrapper.")
        return {"agent_raw_output": [], "success": False} # Return empty list if params missing
    
    result = await asyncio.to_thread(de_tools.call_bigquery_data_engineering_agent, actual_repository_id, actual_workspace_id, data_engineering_prompt)
    logger.info(f"END: call_bigquery_data_engineering_agent_wrapper: {result}")

    success = result.get("status") == "success"
    
    # Extract only the relevant text messages and descriptions into a flat list of strings
    extracted_messages = []
    # Check if 'results' key exists and is a list
    if success and isinstance(result.get("results"), list):
        # raw_agent_output_messages is now correctly assigned directly from result["results"]
        raw_agent_output_messages = result["results"] 
        
        for item in raw_agent_output_messages:
            if isinstance(item, dict) and "messages" in item and isinstance(item["messages"], list):
                for msg_obj in item["messages"]:
                    if isinstance(msg_obj, dict) and "agentMessage" in msg_obj and isinstance(msg_obj["agentMessage"], dict):
                        agent_msg = msg_obj["agentMessage"]
                        # Extract progressMessage text
                        if "progressMessage" in agent_msg and isinstance(agent_msg["progressMessage"], dict):
                            text = agent_msg["progressMessage"].get("textMessage")
                            if text:
                                extracted_messages.append(text)
                        # Extract terminalMessage description
                        if "terminalMessage" in agent_msg and isinstance(agent_msg["terminalMessage"], dict):
                            term_msg = agent_msg["terminalMessage"]
                            if "successMessage" in term_msg and isinstance(term_msg["successMessage"], dict):
                                desc = term_msg["successMessage"].get("description")
                                if desc:
                                    extracted_messages.append(desc)
                                
    return {
        "agent_raw_output": extracted_messages, # Now a List[str]
        "success": success
    }

# Wrapper for de_tools.llm_as_a_judge
async def llm_as_a_judge_wrapper(prompt_given_to_de_agent: str, bq_agent_response_results: List[str]) -> dict: # Expect List[str]
    logger.info("BEGIN: llm_as_a_judge_wrapper")
    
    if not all([prompt_given_to_de_agent, bq_agent_response_results]):
        logger.error("Error: Missing parameters for llm_as_a_judge_wrapper.")
        return {"satisfactory": False, "reasoning": "Missing input parameters.", "success": False}
    
    # Passing the list of strings directly to the underlying tool
    result = await asyncio.to_thread(de_tools.llm_as_a_judge, prompt_given_to_de_agent, bq_agent_response_results)
    logger.info(f"END: llm_as_a_judge_wrapper: {result}")

    success = result.get("status") == "success"
    return {
        "satisfactory": result.get("results", {}).get("satisfactory", False),
        "reasoning": result.get("results", {}).get("reasoning", "No reasoning provided."),
        "success": success
    }

# Wrapper for dataform_helper.rollback_workspace
async def rollback_source_control(actual_repository_id: str, actual_workspace_id: str) -> dict:
    logger.info("BEGIN: rollback_source_control")
    if not all([actual_repository_id, actual_workspace_id]):
        logger.error("Error: Missing parameters for rollback_source_control.")
        return {"success": False}
    
    result = await asyncio.to_thread(dataform_helper.rollback_workspace, actual_repository_id, actual_workspace_id)
    logger.info(f"END: rollback_source_control: {result}")
    
    success = result.get("status") == "success"
    return {"success": success}

# Wrapper for dataform_helper.does_workspace_file_exist (for actions.yaml)
async def check_for_actions_settings(actual_repository_id: str, actual_workspace_id: str) -> dict:
    logger.info("BEGIN: check_for_actions_settings")
    if not all([actual_repository_id, actual_workspace_id]):
        logger.error("Error: Missing parameters for check_for_actions_settings.")
        return {"exists": False, "success": False}
    
    result = await asyncio.to_thread(dataform_helper.does_workspace_file_exist, actual_repository_id, actual_workspace_id, "definitions/actions.yaml")
    logger.info(f"END: check_for_actions_settings: {result}")

    success = result.get("status") == "success"
    exists = result.get("results", {}).get("exists", False) if success else False
    return {"exists": exists, "success": success}

# Wrapper for dataform_helper.write_actions_yaml_file
async def upload_actions_settings(actual_repository_id: str, actual_workspace_id: str) -> dict:
    logger.info("BEGIN: upload_actions_settings")
    if not all([actual_repository_id, actual_workspace_id]):
        logger.error("Error: Missing parameters for upload_actions_settings.")
        return {"success": False}
    
    result = await asyncio.to_thread(dataform_helper.write_actions_yaml_file, actual_repository_id, actual_workspace_id)
    logger.info(f"END: upload_actions_settings: {result}")
    
    success = result.get("status") == "success"
    return {"success": success}

# Wrapper for dataform_helper.compile_and_run_dataform_workflow
async def compile_and_execute_workflow(actual_repository_id: str, actual_workspace_id: str) -> dict:
    logger.info("BEGIN: compile_and_execute_workflow")
    if not all([actual_repository_id, actual_workspace_id]):
        logger.error("Error: Missing parameters for compile_and_execute_workflow.")
        return {"workflow_invocation_id": None, "compilation_id": None, "success": False}
    
    result = await asyncio.to_thread(dataform_helper.compile_and_run_dataform_workflow, actual_repository_id, actual_workspace_id)
    logger.info(f"END: compile_and_execute_workflow: {result}")

    success = result.get("status") == "success"
    workflow_invocation_full_name = result.get("results", {}).get("name")
    compilation_result_full_name = result.get("results", {}).get("compilationResult")

    workflow_invocation_id = workflow_invocation_full_name.split('/')[-1] if workflow_invocation_full_name else None
    compilation_id = compilation_result_full_name.split('/')[-1] if compilation_result_full_name else None

    return {
        "workflow_invocation_id": workflow_invocation_id,
        "compilation_id": compilation_id,
        "success": success
    }

# Wrapper for dataform_helper.get_worflow_invocation_status
async def check_workflow_execution_status(tool_context: ToolContext, repository_id: str, workflow_invocation_id: str) -> dict:
    """
    Checks the state of a Dataform workflow invocation and signals the loop to escalate if complete.
    """
    logger.debug(f"BEGIN: check_workflow_execution_status")

    if not all([repository_id, workflow_invocation_id]):
        logger.error("Error: Missing 'repository_id' or 'workflow_invocation_id'.")
        tool_context.actions.escalate = True # Escalate if critical param is missing
        return {
            "job_state": "TOOL_ERROR",
            "success": False
        }

    result = await asyncio.to_thread(dataform_helper.get_worflow_invocation_status, repository_id, workflow_invocation_id)
    
    logger.debug(f"END: check_workflow_execution_status result: {result}")

    dataform_job_state = "UNKNOWN"
    tool_call_success = False

    if result["status"] == "success":
        dataform_job_state = result["results"]["state"]
        tool_call_success = True # The tool itself successfully retrieved a state
        
        # This is the critical line: Escalate if the job is in a final state
        if dataform_job_state in ["SUCCEEDED", "FAILED", "CANCELLED"]:
            tool_context.actions.escalate = True 
    else:
        # If the underlying tool call failed, consider it a failure and escalate to stop the loop
        tool_context.actions.escalate = True
        dataform_job_state = "TOOL_FAILED"
        logger.error(f"Error calling dataform_helper.get_worflow_invocation_status: {result.get('messages')}")


    return {
        "job_state": dataform_job_state,
        "success": tool_call_success
    }

# Wrapper for wait_tool_helper.wait_for_seconds
async def time_delay(duration: int) -> dict:
    """
    Instructs the agent's execution environment to pause for the specified number of seconds.
    """
    print(f"BEGIN: wait_for_seconds (duration: {duration})")
    result = await asyncio.to_thread(wait_tool_helper.wait_for_seconds, duration)
    print(f"END: wait_for_seconds")
    success = False
    if result["status"] == "success":
        success = True
    return {
        "duration": duration,
        "success": success
    }


# --- LlmAgent Definitions ---

# Step 0: Parse Initial User Prompt
agent_parse_initial_prompt_instruction = """
Your only task is to parse the initial user prompt to identify the workflow type, repository name, and workspace name.
1. Call `parse_initial_prompt_wrapper(user_prompt="{{initial_data_engineering_query_param}}")`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `parse_initial_prompt_wrapper`.
"""
agent_parse_initial_prompt = LlmAgent(
    name="ParseInitialPrompt",
    model=GEMINI_MODEL,
    instruction=agent_parse_initial_prompt_instruction,
    input_schema=None,
    output_schema=InitialPromptParseOutput,
    output_key="agent_parse_initial_prompt",
    tools=[parse_initial_prompt_wrapper],
)


# Step 1: Normalize BigQuery Resource Names
agent_normalize_bq_names_instruction = """
Your only task is to normalize BigQuery resource names in the user's prompt.
1. Call `normalize_bigquery_resource_names_wrapper(user_prompt="{{initial_data_engineering_query_param}}")`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `normalize_bigquery_resource_names_wrapper`.
"""
agent_normalize_bq_names = LlmAgent(
    name="NormalizeBQNames",
    model=GEMINI_MODEL,
    instruction=agent_normalize_bq_names_instruction,
    input_schema=None,
    output_schema=NormalizeBigQueryResourceNamesOutput,
    output_key="agent_normalize_bq_names",
    tools=[normalize_bigquery_resource_names_wrapper],
)


# Step 4.1: Resolve/Create Repository (sub-agents for conditional logic in orchestrator)
agent_de_get_repo_id_instruction = """
Resolve Dataform repository ID:
1. Call `get_repository_id(repository_name="{{repository_name_param}}")`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `get_repository_id`.
"""
agent_de_get_repo_id = LlmAgent(
    name="DataEngGetRepoID",
    model=GEMINI_MODEL,
    instruction=agent_de_get_repo_id_instruction,
    input_schema=None,
    output_schema=ResolveRepositoryOutput,
    output_key="agent_de_get_repo_id",
    tools=[get_repository_id],
)

agent_de_create_bq_repo_instruction = """
Create a new BigQuery pipeline repository:
1. Call `create_bigquery_pipeline(derived_repository_id="{{derived_repository_id}}", repository_display_name="{{repository_name_param}}")`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `create_bigquery_pipeline`.
"""
agent_de_create_bq_repo = LlmAgent(
    name="DataEngCreateBQRepo",
    model=GEMINI_MODEL,
    instruction=agent_de_create_bq_repo_instruction,
    input_schema=None,
    output_schema=ResolveRepositoryOutput, # Re-using for status and results
    output_key="agent_de_create_bq_repo",
    tools=[create_bigquery_pipeline],
)

agent_de_create_dataform_repo_instruction = """
Create a new Dataform pipeline repository:
1. Call `create_dataform_pipeline(actual_repository_id="{{repository_name_param}}", repository_display_name="{{repository_name_param}}")`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `create_dataform_pipeline`.
"""
agent_de_create_dataform_repo = LlmAgent(
    name="DataEngCreateDFRepo",
    model=GEMINI_MODEL,
    instruction=agent_de_create_dataform_repo_instruction,
    input_schema=None,
    output_schema=ResolveRepositoryOutput, # Re-using for status and results
    output_key="agent_de_create_dataform_repo",
    tools=[create_dataform_pipeline],
)

# Step 4.2: Resolve/Create Workspace (sub-agents for conditional logic in orchestrator)
agent_de_get_workspace_id_instruction = """
Resolve Dataform workspace ID:
1. Call `get_workspace_id(actual_repository_id="{{actual_repository_id}}", target_workspace_name="{{target_workspace_name}}")`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `get_workspace_id`.
"""
agent_de_get_workspace_id = LlmAgent(
    name="DataEngGetWorkspaceID",
    model=GEMINI_MODEL,
    instruction=agent_de_get_workspace_id_instruction,
    input_schema=None,
    output_schema=ResolveWorkspaceOutput,
    output_key="agent_de_get_workspace_id",
    tools=[get_workspace_id],
)

agent_de_create_workspace_instruction = """
Create a new Dataform workspace:
1. Call `create_workspace(actual_repository_id="{{actual_repository_id}}", actual_workspace_id="{{actual_workspace_id}}")`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `create_workspace`.
"""
agent_de_create_workspace = LlmAgent(
    name="DataEngCreateWorkspace",
    model=GEMINI_MODEL,
    instruction=agent_de_create_workspace_instruction,
    input_schema=None,
    output_schema=GeneralSuccessOutput, # Simplified output schema for create success
    output_key="agent_de_create_workspace",
    tools=[create_workspace],
)

# Step 4.3: Initialize Workspace (workflow_settings.yaml)
agent_de_check_workflow_settings_instruction = """
Check if 'workflow_settings.yaml' exists in the workspace:
1. Call `check_for_workflow_settings(actual_repository_id="{{actual_repository_id}}", actual_workspace_id="{{actual_workspace_id}}")`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `check_for_workflow_settings`.
"""
agent_de_check_workflow_settings = LlmAgent(
    name="DataEngCheckWorkflowSettings",
    model=GEMINI_MODEL,
    instruction=agent_de_check_workflow_settings_instruction,
    input_schema=None,
    output_schema=FileExistenceOutput,
    output_key="agent_de_check_workflow_settings",
    tools=[check_for_workflow_settings],
)

agent_de_write_workflow_settings_instruction = """
Write the initial 'workflow_settings.yaml' file:
1. Call `upload_workflow_settings(actual_repository_id="{{actual_repository_id}}", actual_workspace_id="{{actual_workspace_id}}")`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `upload_workflow_settings`.
"""
agent_de_write_workflow_settings = LlmAgent(
    name="DataEngWriteWorkflowSettings",
    model=GEMINI_MODEL,
    instruction=agent_de_write_workflow_settings_instruction,
    input_schema=None,
    output_schema=GeneralSuccessOutput, # Simplified output schema
    output_key="agent_de_write_workflow_settings",
    tools=[upload_workflow_settings],
)

# Generic commit agent, message set in orchestrator before call
agent_de_commit_workspace_instruction = """
Commit changes to the Dataform workspace:
1. Call `commit_source_control(actual_repository_id="{{actual_repository_id}}", actual_workspace_id="{{actual_workspace_id}}", commit_message="{{commit_message}}")`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `commit_source_control`.
"""
agent_de_commit_workspace = LlmAgent(
    name="DataEngCommitWorkspace",
    model=GEMINI_MODEL,
    instruction=agent_de_commit_workspace_instruction,
    input_schema=None,
    output_schema=GeneralSuccessOutput, # Simplified output schema
    output_key="agent_de_commit_workspace",
    tools=[commit_source_control],
)

# Step 4.4: Generate/Update Code with BigQuery Data Engineering Agent
agent_de_call_bq_de_agent_instruction = """
Call the BigQuery Data Engineering Agent to generate/update code:
1. Call `call_bigquery_data_engineering_agent_wrapper(actual_repository_id="{{actual_repository_id}}", actual_workspace_id="{{actual_workspace_id}}", data_engineering_prompt="{{data_engineering_prompt}})`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `call_bigquery_data_engineering_agent_wrapper`.
"""
agent_de_call_bq_de_agent = LlmAgent(
    name="DataEngCallBQDEAgent",
    model=GEMINI_MODEL,
    instruction=agent_de_call_bq_de_agent_instruction,
    input_schema=None,
    output_schema=CallDataEngAgentOutput,
    output_key="agent_de_call_bq_de_agent",
    tools=[call_bigquery_data_engineering_agent_wrapper],
)

# Step 4.5: Evaluate Generated Code with LLM Judge
agent_de_llm_judge_instruction = """
Evaluate generated code using LLM Judge:
1. Call `llm_as_a_judge_wrapper(prompt_given_to_de_agent="{{data_engineering_prompt}}", bq_agent_response_results={{bq_agent_response_results | tojson}})`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `llm_as_a_judge_wrapper`.
"""
agent_de_llm_judge = LlmAgent(
    name="DataEngLLMJudge",
    model=GEMINI_MODEL,
    instruction=agent_de_llm_judge_instruction,
    input_schema=None,
    output_schema=LLMJudgeOutput,
    output_key="agent_de_llm_judge",
    tools=[llm_as_a_judge_wrapper],
)

# Step 4.6: Rollback (if LLM Judge fails)
agent_de_rollback_workspace_instruction = """
Rollback Dataform workspace:
1. Call `rollback_source_control(actual_repository_id="{{actual_repository_id}}", actual_workspace_id="{{actual_workspace_id}}")`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `rollback_source_control`.
"""
agent_de_rollback_workspace = LlmAgent(
    name="DataEngRollbackWorkspace",
    model=GEMINI_MODEL,
    instruction=agent_de_rollback_workspace_instruction,
    input_schema=None,
    output_schema=GeneralSuccessOutput, # Simplified output schema
    output_key="agent_de_rollback_workspace",
    tools=[rollback_source_control],
)

# Step 4.7: Ensure `actions.yaml` Exists
agent_de_check_actions_yaml_instruction = """
Check if 'definitions/actions.yaml' exists in the workspace:
1. Call `check_for_actions_settings(actual_repository_id="{{actual_repository_id}}", actual_workspace_id="{{actual_workspace_id}}")`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `check_for_actions_settings`.
"""
agent_de_check_actions_yaml = LlmAgent(
    name="DataEngCheckActionsYaml",
    model=GEMINI_MODEL,
    instruction=agent_de_check_actions_yaml_instruction,
    input_schema=None,
    output_schema=FileExistenceOutput,
    output_key="agent_de_check_actions_yaml",
    tools=[check_for_actions_settings],
)

agent_de_write_actions_yaml_instruction = """
Write the 'definitions/actions.yaml' file:
1. Call `upload_actions_settings(actual_repository_id="{{actual_repository_id}}", actual_workspace_id="{{actual_workspace_id}}")`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `upload_actions_settings`.
"""
agent_de_write_actions_yaml = LlmAgent(
    name="DataEngWriteActionsYaml",
    model=GEMINI_MODEL,
    instruction=agent_de_write_actions_yaml_instruction,
    input_schema=None,
    output_schema=GeneralSuccessOutput, # Simplified output schema
    output_key="agent_de_write_actions_yaml",
    tools=[upload_actions_settings],
)

# Step 4.8: Compile and Run Dataform Workflow
agent_de_compile_and_run_instruction = """
Compile and run Dataform workflow:
1. Call `compile_and_execute_workflow(actual_repository_id="{{actual_repository_id}}", actual_workspace_id="{{actual_workspace_id}}")`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `compile_and_execute_workflow`.
"""
agent_de_compile_and_run = LlmAgent(
    name="DataEngCompileAndRun",
    model=GEMINI_MODEL,
    instruction=agent_de_compile_and_run_instruction,
    input_schema=None,
    output_schema=CompileAndRunWorkflowOutput,
    output_key="agent_de_compile_and_run",
    tools=[compile_and_execute_workflow],
)

# Step 5: Monitor Pipeline Workflow Status (for LoopAgent) - Uses the new wrapper tool
agent_de_check_job_state_instruction = """
Check the state of the Dataform workflow invocation:
1. Call `check_workflow_execution_status(repository_id="{{actual_repository_id}}", workflow_invocation_id="{{workflow_invocation_id}}")`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `check_workflow_execution_status`.
"""
agent_de_check_job_state = LlmAgent(
    name="DataEngCheckJobState",
    model=GEMINI_MODEL,
    instruction=agent_de_check_job_state_instruction,
    input_schema=None,
    output_schema=CheckJobStateOutput,
    output_key="agent_loop_wait_for_de_job_complete", # This key is read by the LoopAgent
    tools=[check_workflow_execution_status],
)

agent_de_time_delay_job_instruction = """
Your only task is to wait for a specified duration.
1. Call `time_delay(duration=5)`.
2. After the tool returns, immediately respond by calling `set_model_response` with the exact dictionary result returned by `time_delay`. Do NOT generate any conversational text, explanations, or any other content. Your entire response MUST be solely the `set_model_response` tool call.
"""
agent_de_time_delay_job = LlmAgent(
    name="DataEngTimeDelayJob",
    model=GEMINI_MODEL,
    instruction=agent_de_time_delay_job_instruction,
    input_schema=None,
    output_schema=TimeDelayOutput,
    output_key="agent_de_time_delay_job",
    tools=[time_delay],
)

# --- Orchestrator Class ---
class DataEngineeringWorkflowCustomAgent(BaseAgent):
    """
    Agent that orchestrates data engineering pipeline creation/modification
    based on a user prompt.
    """
    # Declare the agents passed to the class
    agent_parse_initial_prompt: LlmAgent # New parsing agent
    agent_normalize_bq_names: LlmAgent
    agent_de_get_repo_id: LlmAgent
    agent_de_create_bq_repo: LlmAgent
    agent_de_create_dataform_repo: LlmAgent
    agent_de_get_workspace_id: LlmAgent
    agent_de_create_workspace: LlmAgent
    agent_de_check_workflow_settings: LlmAgent
    agent_de_write_workflow_settings: LlmAgent
    agent_de_commit_workspace: LlmAgent
    agent_de_call_bq_de_agent: LlmAgent
    agent_de_llm_judge: LlmAgent
    agent_de_rollback_workspace: LlmAgent
    agent_de_check_actions_yaml: LlmAgent
    agent_de_write_actions_yaml: LlmAgent
    agent_de_compile_and_run: LlmAgent
    # These must be declared as class attributes for Pydantic validation
    agent_de_check_job_state: LlmAgent
    agent_de_time_delay_job: LlmAgent

    loop_wait_for_de_job_complete: LoopAgent

    def __init__(self, name: str,
                 agent_parse_initial_prompt: LlmAgent, # New agent in constructor
                 agent_normalize_bq_names: LlmAgent,
                 agent_de_get_repo_id: LlmAgent,
                 agent_de_create_bq_repo: LlmAgent,
                 agent_de_create_dataform_repo: LlmAgent,
                 agent_de_get_workspace_id: LlmAgent,
                 agent_de_create_workspace: LlmAgent,
                 agent_de_check_workflow_settings: LlmAgent,
                 agent_de_write_workflow_settings: LlmAgent,
                 agent_de_commit_workspace: LlmAgent,
                 agent_de_call_bq_de_agent: LlmAgent,
                 agent_de_llm_judge: LlmAgent,
                 agent_de_rollback_workspace: LlmAgent,
                 agent_de_check_actions_yaml: LlmAgent,
                 agent_de_write_actions_yaml: LlmAgent,
                 agent_de_compile_and_run: LlmAgent,
                 # Parameters for __init__ must match the class attributes
                 agent_de_check_job_state: LlmAgent,
                 agent_de_time_delay_job: LlmAgent):

        loop_wait_for_de_job_complete = LoopAgent(
            name="WaitForDEJobComplete", sub_agents=[agent_de_check_job_state, agent_de_time_delay_job], max_iterations=10
        ) # Max iterations based on expected job duration (e.g., 60 * 7 seconds = 7 minutes)

        # Define the overall sequence of sub-agents that will be run by this orchestrator.
        # Not all sub-agents will run in a strict sequence; some will be called conditionally
        # within _run_async_impl, but they must all be declared here.
        sub_agents_list = [
            agent_parse_initial_prompt, # New first step
            agent_normalize_bq_names,
            agent_de_get_repo_id,
            agent_de_create_bq_repo,
            agent_de_create_dataform_repo,
            agent_de_get_workspace_id,
            agent_de_create_workspace,
            agent_de_check_workflow_settings,
            agent_de_write_workflow_settings,
            agent_de_commit_workspace, # One instance for all commits
            agent_de_call_bq_de_agent,
            agent_de_llm_judge,
            agent_de_rollback_workspace,
            agent_de_check_actions_yaml,
            agent_de_write_actions_yaml,
            agent_de_compile_and_run,
            loop_wait_for_de_job_complete # The loop agent itself
        ]

        super().__init__(
            name=name,
            agent_parse_initial_prompt=agent_parse_initial_prompt, # New agent
            agent_normalize_bq_names=agent_normalize_bq_names,
            agent_de_get_repo_id=agent_de_get_repo_id,
            agent_de_create_bq_repo=agent_de_create_bq_repo,
            agent_de_create_dataform_repo=agent_de_create_dataform_repo,
            agent_de_get_workspace_id=agent_de_get_workspace_id,
            agent_de_create_workspace=agent_de_create_workspace,
            agent_de_check_workflow_settings=agent_de_check_workflow_settings,
            agent_de_write_workflow_settings=agent_de_write_workflow_settings,
            agent_de_commit_workspace=agent_de_commit_workspace,
            agent_de_call_bq_de_agent=agent_de_call_bq_de_agent,
            agent_de_llm_judge=agent_de_llm_judge,
            agent_de_rollback_workspace=agent_de_rollback_workspace,
            agent_de_check_actions_yaml=agent_de_check_actions_yaml,
            agent_de_write_actions_yaml=agent_de_write_actions_yaml,
            agent_de_compile_and_run=agent_de_compile_and_run,
            loop_wait_for_de_job_complete=loop_wait_for_de_job_complete,
            agent_de_check_job_state=agent_de_check_job_state, # Still required for Pydantic validation of class attributes
            agent_de_time_delay_job=agent_de_time_delay_job, # Still required for Pydantic validation of class attributes
            sub_agents=sub_agents_list,
        )

    @override
    async def _run_async_impl(
        self, ctx: InvocationContext
    ) -> AsyncGenerator[Event, None]:
        logger.info(f"[{self.name}] Starting Data Engineering workflow.")

        # Initialize response structure
        # Retrieve the initial user prompt that triggered this workflow from ctx.last_message
        initial_user_prompt = ctx.session.state.get("initial_data_engineering_query_param", "") 
        initial_user_prompt = initial_user_prompt.split("For context:")[0].strip() # Remove any context
        
        # Ensure this prompt is stored in the session state for sub-agents to access via templating
        ctx.session.state["initial_data_engineering_query_param"] = initial_user_prompt

        # These will be populated by the parsing agent
        workflow_type_param = ""
        repository_name_param = ""
        workspace_name_param = ""

        response = DataEngineeringWorkflowOutput(
            status="success",
            tool_name="data_engineering_workflow",
            query=initial_user_prompt,
            messages=[],
            results={
                "original_user_prompt": initial_user_prompt,
                "rewritten_prompt": None,
                "repository_name": None,
                "workspace_name": None,
                "workflow_type": None,
                "actual_repository_id": None,
                "actual_workspace_id": None,
                "workflow_invocation_id": None,
                "final_job_state": None,
                "dataform_invocation_url": None,
                "bigquery_ui_link": None,
            },
            success=True,
        )

        # This helper function will now yield an event and then *implicitly* stop iteration
        def _fail_workflow_event(msg: str, current_response: DataEngineeringWorkflowOutput, debug_info: Optional[Dict[str, Any]] = None) -> Event:
            current_response.status = "failed"
            current_response.success = False
            current_response.messages.append(msg)
            
            # Using a multi-line f-string for Markdown formatting
            error_summary = f"""**Data Engineering Workflow FAILED:** {msg}

### Workflow Details
- **Initiated for prompt:** {current_response.results.get('original_user_prompt', 'N/A')}
- **Inferred Workflow Type:** {current_response.results.get('workflow_type', 'N/A')}
- **Inferred Repository Name:** {current_response.results.get('repository_name', 'N/A')}
- **Inferred Workspace Name:** {current_response.results.get('workspace_name', 'N/A')}
- **Actual Repository ID:** {current_response.results.get('actual_repository_id', 'N/A')}
- **Actual Workspace ID:** {current_response.results.get('actual_workspace_id', 'N/A')}
- **Dataform Invocation ID:** {current_response.results.get('workflow_invocation_id', 'N/A')}
- **Final Job State:** {current_response.results.get('final_job_state', 'N/A')}
- **Dataform UI Link:** {current_response.results.get('dataform_invocation_url', 'N/A')}
"""
            if debug_info:
                # Append debug info in a code block for readability
                error_summary += f"""
### Debug Information
```json
{json.dumps(debug_info, indent=2, default=str)}
```
"""            
            logger.error(f"Workflow failed: {msg}") # Keep existing log
            return Event(
                author=self.name,
                content=types.Content(role="assistant", parts=[types.Part(text=error_summary)]),
            )

        # Initial message
        yield Event(
            author=self.name,
            content=types.Content(
                role="assistant",
                parts=[
                    types.Part(
                        text=f"Initiating data engineering workflow based on your prompt."
                    )
                ],
            ),
        )

        ########################################################
        # STEP 0: Parse Initial User Prompt to get Workflow Metadata
        ########################################################
        logger.info(f"[{self.name}] Running Agent: ParseInitialPrompt")
        # initial_data_engineering_query_param is now guaranteed to be in ctx.session.state
        async for event in self.agent_parse_initial_prompt.run_async(ctx):
            logger.info(f"[{self.name}] Internal event from ParseInitialPrompt: {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event # Re-yield all events from the LlmAgent for UI visibility

        parse_initial_prompt_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_parse_initial_prompt")

        if not parse_initial_prompt_result or not parse_initial_prompt_result.get("success"):
            yield _fail_workflow_event(f"Failed to parse initial user prompt for workflow metadata. Please ensure to clearly specify the pipeline name and type (e.g., 'BigQuery pipeline named \"My Pipeline\"').", response, debug_info=parse_initial_prompt_result)
            return

        workflow_type_param = parse_initial_prompt_result.get("workflow_type", "UNKNOWN")
        repository_name_param = parse_initial_prompt_result.get("repository_name", "MISSING")
        workspace_name_param = parse_initial_prompt_result.get("workspace_name", "MISSING")
        
        # Store extracted parameters in response results for final summary
        response.results["workflow_type"] = workflow_type_param
        response.results["repository_name"] = repository_name_param
        response.results["workspace_name"] = workspace_name_param

        if workflow_type_param == "UNKNOWN":
            yield _fail_workflow_event(
                f"Could not infer the workflow type (BigQuery Pipeline or Dataform Pipeline) from your prompt. Please clarify.",
                response, debug_info=parse_initial_prompt_result
            )
            return
        
        if repository_name_param == "MISSING":
            yield _fail_workflow_event(
                f"Could not identify a repository or pipeline name from your prompt. Please provide one (e.g., 'pipeline named \"My Pipeline\"').",
                response, debug_info=parse_initial_prompt_result
            )
            return
        
        # Store for templating in subsequent steps
        ctx.session.state["workflow_type_param"] = workflow_type_param
        ctx.session.state["repository_name_param"] = repository_name_param
        ctx.session.state["workspace_name_param"] = workspace_name_param

        response.messages.append(f"Parsed prompt: Workflow Type='{workflow_type_param}', Repository='{repository_name_param}', Workspace='{workspace_name_param}'.")
        yield Event(
            author=self.name,
            content=types.Content(role="assistant", parts=[types.Part(text=f"Successfully parsed your request. Workflow Type: '{workflow_type_param}', Repository: '{repository_name_param}'. Now preparing the Dataform environment.")])
        )

        ########################################################
        # STEP 1: Normalize BigQuery Resource Names in Prompt
        ########################################################
        logger.info(f"[{self.name}] Running Agent: NormalizeBQNames")
        # initial_data_engineering_query_param is now guaranteed to be in ctx.session.state
        async for event in self.agent_normalize_bq_names.run_async(ctx):
            logger.info(f"[{self.name}] Internal event from NormalizeBQNames: {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event # Re-yield all events from the LlmAgent for UI visibility

        normalize_bq_names_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_normalize_bq_names")

        if not normalize_bq_names_result or not normalize_bq_names_result.get("success"):
            yield _fail_workflow_event(f"Failed to normalize BigQuery resource names in the prompt.", response, debug_info=normalize_bq_names_result)
            return

        rewritten_prompt = normalize_bq_names_result.get("rewritten_prompt")
        if not rewritten_prompt:
            yield _fail_workflow_event(f"Normalization returned an empty rewritten prompt.", response, debug_info=normalize_bq_names_result)
            return

        ctx.session.state["rewritten_prompt"] = rewritten_prompt # Store for next step's templating
        response.results["rewritten_prompt"] = rewritten_prompt
        response.messages.append(f"BigQuery resource names normalized. Rewritten prompt: '{rewritten_prompt}'")
        if rewritten_prompt != initial_user_prompt:
            yield Event(
                author=self.name,
                content=types.Content(role="assistant", parts=[types.Part(text=f"I've refined your request to use exact BigQuery table and dataset names for accuracy. Rewritten prompt: '{rewritten_prompt}'.")])
            )
        else:
             yield Event(
                author=self.name,
                content=types.Content(role="assistant", parts=[types.Part(text=f"BigQuery resource names validated. Proceeding with your request: '{rewritten_prompt}'.")])
            )


        ########################################################
        # STEP 3: Verify/Create Dataform Repository
        ########################################################
        actual_repository_id = None
        
        # 3.1. Resolve Actual Repository ID
        logger.info(f"[{self.name}] Running Agent: DataEngGetRepoID")
        # repository_name_param already in state from Step 0
        async for event in self.agent_de_get_repo_id.run_async(ctx):
            logger.info(f"[{self.name}] Internal event from DataEngGetRepoID: {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event # Re-yield all events from the LlmAgent for UI visibility
        get_repo_id_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_de_get_repo_id")

        if not get_repo_id_result or not get_repo_id_result.get("success"):
            yield _fail_workflow_event(f"Failed to resolve repository ID due to tool error.", response, debug_info=get_repo_id_result)
            return

        if not get_repo_id_result.get("exists"):
            response.messages.append(f"Repository '{repository_name_param}' does not exist. Attempting to create.")

            if workflow_type_param == "BIGQUERY_PIPELINE":
                derived_repository_id = repository_name_param.lower().replace(" ", "-")
                ctx.session.state["derived_repository_id"] = derived_repository_id # Store for templating

                logger.info(f"[{self.name}] Running Agent: DataEngCreateBQRepo")
                async for event in self.agent_de_create_bq_repo.run_async(ctx):
                    logger.info(f"[{self.name}] Internal event from DataEngCreateBQRepo: {event.model_dump_json(indent=2, exclude_none=True)}")
                    yield event # Re-yield all events from the LlmAgent for UI visibility
                create_repo_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_de_create_bq_repo")

                if not create_repo_result or not create_repo_result.get("success"):
                    yield _fail_workflow_event(f"Failed to create BigQuery pipeline repository '{derived_repository_id}'.", response, debug_info=create_repo_result)
                    return
                actual_repository_id = create_repo_result.get("repository_id")
                response.messages.append(f"Successfully created BigQuery pipeline repository: {actual_repository_id}")

            elif workflow_type_param == "DATAFORM_PIPELINE":
                actual_repository_id = repository_name_param # For Dataform, use the input name as ID
                # No derived_repository_id needed here, 'repository_name_param' directly used in instruction
                
                logger.info(f"[{self.name}] Running Agent: DataEngCreateDFRepo")
                async for event in self.agent_de_create_dataform_repo.run_async(ctx):
                    logger.info(f"[{self.name}] Internal event from DataEngCreateDFRepo: {event.model_dump_json(indent=2, exclude_none=True)}")
                    yield event # Re-yield all events from the LlmAgent for UI visibility
                create_repo_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_de_create_dataform_repo")

                if not create_repo_result or not create_repo_result.get("success"):
                    yield _fail_workflow_event(f"Failed to create Dataform pipeline repository '{actual_repository_id}'.", response, debug_info=create_repo_result)
                    return
                actual_repository_id = create_repo_result.get("repository_id")
                response.messages.append(f"Successfully created Dataform pipeline repository: {actual_repository_id}")
            else:
                yield _fail_workflow_event(f"Unsupported workflow type '{workflow_type_param}' for repository creation.", response)
                return
        else:
            actual_repository_id = get_repo_id_result.get("repository_id")
            response.messages.append(f"Repository '{repository_name_param}' already exists with ID: {actual_repository_id}")

        ctx.session.state["actual_repository_id"] = actual_repository_id # Store for subsequent steps
        response.results["actual_repository_id"] = actual_repository_id
        yield Event(
            author=self.name,
            content=types.Content(role="assistant", parts=[types.Part(text=f"Repository '{repository_name_param}' resolved to ID '{actual_repository_id}'.")])
        )


        ########################################################
        # STEP 4: Verify/Create Dataform Workspace
        ########################################################
        target_workspace_name = "default" if workflow_type_param == "BIGQUERY_PIPELINE" else workspace_name_param
        ctx.session.state["target_workspace_name"] = target_workspace_name # Store for templating
        actual_workspace_id = None

        logger.info(f"[{self.name}] Running Agent: DataEngGetWorkspaceID")
        async for event in self.agent_de_get_workspace_id.run_async(ctx):
            logger.info(f"[{self.name}] Internal event from DataEngGetWorkspaceID: {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event # Re-yield all events from the LlmAgent for UI visibility
        get_workspace_id_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_de_get_workspace_id")

        if not get_workspace_id_result or not get_workspace_id_result.get("success"):
            yield _fail_workflow_event(f"Failed to resolve workspace ID due to tool error.", response, debug_info=get_workspace_id_result)
            return

        if not get_workspace_id_result.get("exists"):
            discovered_workspaces = get_workspace_id_result.get("discovered_workspaces", [])
            if len(discovered_workspaces) == 1 and workflow_type_param == "BIGQUERY_PIPELINE": # For BQ pipeline, default workspace might already exist
                actual_workspace_id = discovered_workspaces[0]
                response.messages.append(f"Discovered a single existing workspace '{actual_workspace_id}'. Proceeding with it.")
                ctx.session.state["actual_workspace_id"] = actual_workspace_id # Ensure it's set for subsequent steps
            else:
                actual_workspace_id = target_workspace_name.lower().replace(" ", "-")
                ctx.session.state["actual_workspace_id"] = actual_workspace_id # Set before calling create

                logger.info(f"[{self.name}] Running Agent: DataEngCreateWorkspace")
                async for event in self.agent_de_create_workspace.run_async(ctx):
                    logger.info(f"[{self.name}] Internal event from DataEngCreateWorkspace: {event.model_dump_json(indent=2, exclude_none=True)}")
                    yield event # Re-yield all events from the LlmAgent for UI visibility
                create_workspace_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_de_create_workspace")

                if not create_workspace_result or not create_workspace_result.get("success"):
                    yield _fail_workflow_event(f"Failed to create workspace '{actual_workspace_id}'. Discovered: {discovered_workspaces}", response, debug_info=create_workspace_result)
                    return
                response.messages.append(f"Successfully created workspace: {actual_workspace_id}")
        else:
            actual_workspace_id = get_workspace_id_result.get("workspace_id")
            response.messages.append(f"Workspace '{target_workspace_name}' already exists with ID: {actual_workspace_id}")

        ctx.session.state["actual_workspace_id"] = actual_workspace_id # Store for subsequent steps
        response.results["actual_workspace_id"] = actual_workspace_id
        yield Event(
            author=self.name,
            content=types.Content(role="assistant", parts=[types.Part(text=f"Workspace '{target_workspace_name}' resolved to ID '{actual_workspace_id}'.")])
        )


        ########################################################
        # STEP 5: Initialize Workspace (if necessary) - workflow_settings.yaml
        ########################################################
        logger.info(f"[{self.name}] Running Agent: DataEngCheckWorkflowSettings")
        async for event in self.agent_de_check_workflow_settings.run_async(ctx):
            logger.info(f"[{self.name}] Internal event from DataEngCheckWorkflowSettings: {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event # Re-yield all events from the LlmAgent for UI visibility
        check_settings_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_de_check_workflow_settings")

        if not check_settings_result or not check_settings_result.get("success"):
            yield _fail_workflow_event(f"Failed to check for workflow_settings.yaml.", response, debug_info=check_settings_result)
            return

        if not check_settings_result.get("exists"):
            response.messages.append("workflow_settings.yaml not found. Writing and committing.")
            logger.info(f"[{self.name}] Running Agent: DataEngWriteWorkflowSettings")
            async for event in self.agent_de_write_workflow_settings.run_async(ctx):
                logger.info(f"[{self.name}] Internal event from DataEngWriteWorkflowSettings: {event.model_dump_json(indent=2, exclude_none=True)}")
                yield event # Re-yield all events from the LlmAgent for UI visibility
            write_settings_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_de_write_workflow_settings")

            if not write_settings_result or not write_settings_result.get("success"):
                yield _fail_workflow_event(f"Failed to write workflow_settings.yaml.", response, debug_info=write_settings_result)
                return

            ctx.session.state["commit_message"] = "Initial commit of workflow_settings.yaml"
            logger.info(f"[{self.name}] Running Agent: DataEngCommitWorkspace (WorkflowSettings)")
            async for event in self.agent_de_commit_workspace.run_async(ctx):
                logger.info(f"[{self.name}] Internal event from DataEngCommitWorkspace (WorkflowSettings): {event.model_dump_json(indent=2, exclude_none=True)}")
                yield event # Re-yield all events from the LlmAgent for UI visibility
            commit_settings_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_de_commit_workspace")

            if not commit_settings_result or not commit_settings_result.get("success"):
                yield _fail_workflow_event(f"Failed to commit workflow_settings.yaml.", response, debug_info=commit_settings_result)
                return
            response.messages.append("Successfully wrote and committed workflow_settings.yaml.")
        else:
            response.messages.append("workflow_settings.yaml already exists. Skipping initialization.")
        yield Event(
            author=self.name,
            content=types.Content(role="assistant", parts=[types.Part(text="Workspace initialization complete.")])
        )

        ########################################################
        # STEP 6: Generate/Update Code with BigQuery Data Engineering Agent
        ########################################################
        logger.info(f"[{self.name}] Running Agent: DataEngCallBQDEAgent")
        # Use the rewritten prompt from step 1
        ctx.session.state["data_engineering_prompt"] = rewritten_prompt
        async for event in self.agent_de_call_bq_de_agent.run_async(ctx):
            logger.info(f"[{self.name}] Internal event from DataEngCallBQDEAgent: {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event # Re-yield all events from the LlmAgent for UI visibility
        call_bq_de_agent_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_de_call_bq_de_agent")

        logger.info(f"[{self.name}] DEBUG: call_bq_de_agent_result from session state after agent call: {call_bq_de_agent_result}")

        if not call_bq_de_agent_result or not call_bq_de_agent_result.get("success"):
            yield _fail_workflow_event(f"Failed to call BigQuery Data Engineering Agent.", response, debug_info=call_bq_de_agent_result)
            return

        bq_agent_raw_output = call_bq_de_agent_result.get("agent_raw_output")

        # --- NEW CHECK FOR MEANINGFUL OUTPUT ---
        if not bq_agent_raw_output: # This checks if the raw output is empty, None, or similar falsy value
            yield _fail_workflow_event(
                f"BigQuery Data Engineering Agent call succeeded, but returned empty or invalid results. "
                f"Raw output: {bq_agent_raw_output}",
                response,
                debug_info=call_bq_de_agent_result
            )
            return
        # --- END NEW CHECK ---

        # Set the extracted content into the session state for the LLM Judge (as List[str])
        ctx.session.state["bq_agent_response_results"] = bq_agent_raw_output
        response.messages.append("BigQuery Data Engineering Agent called. Evaluating generated code.")
        yield Event(
            author=self.name,
            content=types.Content(role="assistant", parts=[types.Part(text="Code generation initiated. Evaluating results.")])
        )


        ########################################################
        # STEP 7: Evaluate Generated Code with LLM Judge
        ########################################################
        logger.info(f"[{self.name}] Running Agent: DataEngLLMJudge")
        async for event in self.agent_de_llm_judge.run_async(ctx):
            logger.info(f"[{self.name}] Internal event from DataEngLLMJudge: {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event # Re-yield all events from the LlmAgent for UI visibility
        llm_judge_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_de_llm_judge")

        if not llm_judge_result or not llm_judge_result.get("success"):
            yield _fail_workflow_event(f"Failed during LLM Judge evaluation.", response, debug_info=llm_judge_result)
            return

        if not llm_judge_result.get("satisfactory"):
            response.messages.append("LLM Judge deemed generated code unsatisfactory. Attempting rollback.")
            logger.info(f"[{self.name}] Running Agent: DataEngRollbackWorkspace")
            async for event in self.agent_de_rollback_workspace.run_async(ctx):
                logger.info(f"[{self.name}] Internal event from DataEngRollbackWorkspace: {event.model_dump_json(indent=2, exclude_none=True)}")
                yield event # Re-yield all events from the LlmAgent for UI visibility
            rollback_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_de_rollback_workspace")

            if not rollback_result or not rollback_result.get("success"):
                yield _fail_workflow_event(f"LLM Judge unsatisfactory and failed to rollback workspace. Reason: {llm_judge_result.get('reasoning')}", response, debug_info={"llm_judge_result": llm_judge_result, "rollback_result": rollback_result})
                return
            yield _fail_workflow_event(f"LLM Judge deemed generated code unsatisfactory. Workspace rolled back. Reason: {llm_judge_result.get('reasoning')}", response, debug_info=llm_judge_result)
            return
        response.messages.append("LLM Judge found generated code satisfactory. Committing changes.")
        yield Event(
            author=self.name,
            content=types.Content(role="assistant", parts=[types.Part(text="Code evaluated and deemed satisfactory. Committing changes.")])
        )


        ########################################################
        # STEP 8: Commit Generated Code
        ########################################################
        ctx.session.state["commit_message"] = "Data Engineering Agent commit of generated code"
        logger.info(f"[{self.name}] Running Agent: DataEngCommitWorkspace (GeneratedCode)")
        async for event in self.agent_de_commit_workspace.run_async(ctx):
            logger.info(f"[{self.name}] Internal event from DataEngCommitWorkspace (GeneratedCode): {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event # Re-yield all events from the LlmAgent for UI visibility
        commit_code_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_de_commit_workspace")

        if not commit_code_result or not commit_code_result.get("success"):
            yield _fail_workflow_event(f"Failed to commit generated code.", response, debug_info=commit_code_result)
            return
        response.messages.append("Successfully committed generated code.")
        yield Event(
            author=self.name,
            content=types.Content(role="assistant", parts=[types.Part(text="Changes committed. Ensuring 'actions.yaml' exists.")])
        )


        ########################################################
        # STEP 9: Ensure `actions.yaml` Exists
        ########################################################
        logger.info(f"[{self.name}] Running Agent: DataEngCheckActionsYaml")
        async for event in self.agent_de_check_actions_yaml.run_async(ctx):
            logger.info(f"[{self.name}] Internal event from DataEngCheckActionsYaml: {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event # Re-yield all events from the LlmAgent for UI visibility
        check_actions_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_de_check_actions_yaml")

        if not check_actions_result or not check_actions_result.get("success"):
            yield _fail_workflow_event(f"Failed to check for definitions/actions.yaml.", response, debug_info=check_actions_result)
            return

        if not check_actions_result.get("exists"):
            response.messages.append("definitions/actions.yaml not found. Writing and committing.")
            logger.info(f"[{self.name}] Running Agent: DataEngWriteActionsYaml")
            async for event in self.agent_de_write_actions_yaml.run_async(ctx):
                logger.info(f"[{self.name}] Internal event from DataEngWriteActionsYaml: {event.model_dump_json(indent=2, exclude_none=True)}")
                yield event # Re-yield all events from the LlmAgent for UI visibility
            write_actions_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_de_write_actions_yaml")

            if not write_actions_result or not write_actions_result.get("success"):
                yield _fail_workflow_event(f"Failed to write definitions/actions.yaml.", response, debug_info=write_actions_result)
                return

            ctx.session.state["commit_message"] = "Data Engineering Agent commit of definitions/actions.yaml"
            logger.info(f"[{self.name}] Running Agent: DataEngCommitWorkspace (ActionsYaml)")
            async for event in self.agent_de_commit_workspace.run_async(ctx):
                logger.info(f"[{self.name}] Internal event from DataEngCommitWorkspace (ActionsYaml): {event.model_dump_json(indent=2, exclude_none=True)}")
                yield event # Re-yield all events from the LlmAgent for UI visibility
            commit_actions_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_de_commit_workspace")

            if not commit_actions_result or not commit_actions_result.get("success"):
                yield _fail_workflow_event(f"Failed to commit definitions/actions.yaml.", response, debug_info=commit_actions_result)
                return
            response.messages.append("Successfully wrote and committed definitions/actions.yaml.")
        else:
            response.messages.append("definitions/actions.yaml already exists. Skipping.")
        yield Event(
            author=self.name,
            content=types.Content(role="assistant", parts=[types.Part(text="`actions.yaml` check complete. Compiling and running workflow.")])
        )


        ########################################################
        # STEP 10: Compile and Run Dataform Workflow
        ########################################################
        logger.info(f"[{self.name}] Running Agent: DataEngCompileAndRun")
        async for event in self.agent_de_compile_and_run.run_async(ctx):
            logger.info(f"[{self.name}] Internal event from DataEngCompileAndRun: {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event # Re-yield all events from the LlmAgent for UI visibility
        compile_and_run_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_de_compile_and_run")

        if not compile_and_run_result or not compile_and_run_result.get("success"):
            yield _fail_workflow_event(f"Failed to compile and run Dataform workflow.", response, debug_info=compile_and_run_result)
            return

        workflow_invocation_id = compile_and_run_result.get("workflow_invocation_id")
        compilation_id = compile_and_run_result.get("compilation_id")

        if not workflow_invocation_id:
            yield _fail_workflow_event(f"Workflow invocation ID not returned after compilation and run attempt.", response, debug_info=compile_and_run_result)
            return

        ctx.session.state["workflow_invocation_id"] = workflow_invocation_id # Store for monitoring
        ctx.session.state["compilation_id"] = compilation_id # Store compilation ID for URL
        response.results["workflow_invocation_id"] = workflow_invocation_id
        response.results["compilation_id"] = compilation_id # Add to response results for visibility
         
        response.messages.append(f"Dataform workflow started with invocation ID: {workflow_invocation_id}. Monitoring its status.")
        yield Event(
            author=self.name,
            content=types.Content(role="assistant", parts=[types.Part(text=f"Dataform workflow started ({workflow_invocation_id}). Monitoring progress...")])
        )


        logger.info(f"[{self.name}] DEBUG: Entering LoopAgent 'WaitForDEJobComplete' to monitor job state.")
        ########################################################
        # STEP 11: Monitor Pipeline Workflow Status and Report Result
        ########################################################
        # This is the corrected direct call to the LoopAgent as per the working example
        async for event in self.loop_wait_for_de_job_complete.run_async(ctx):
            logger.info(f"[{self.name}] Internal event from WaitForDEJobComplete: {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event # Re-yield all events from the LoopAgent (which handles its internal sub-agents and their events)

        logger.info(f"[{self.name}] DEBUG: LoopAgent 'WaitForDEJobComplete' has finished. Retrieving final state from session.")

        loop_wait_for_de_job_complete_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_loop_wait_for_de_job_complete")

        logger.info(f"[{self.name}] DEBUG: Retrieved loop_wait_for_de_job_complete_result: {loop_wait_for_de_job_complete_result}")

        if not loop_wait_for_de_job_complete_result or not loop_wait_for_de_job_complete_result.get("success"):
            logger.error(f"[{self.name}] DEBUG: LoopAgent result is None or failed. Yielding failure event and returning.")
            yield _fail_workflow_event(f"Monitoring loop for Dataform job failed or timed out.", response, debug_info=loop_wait_for_de_job_complete_result)
            return

        final_job_state = loop_wait_for_de_job_complete_result.get("job_state")
        response.results["final_job_state"] = final_job_state

        project_id = os.getenv("AGENT_ENV_PROJECT_ID")
        dataform_region = os.getenv("AGENT_ENV_DATAFORM_REGION", "us-central1") # Default if not set

        # Construct Dataform Workflow Invocation URL and BigQuery UI Link
        dataform_invocation_url = (
            f"https://console.cloud.google.com/bigquery/dataform/locations/{dataform_region}/"
            f"repositories/{response.results.get('actual_repository_id', 'N/A')}/workspaces/{response.results.get('actual_workspace_id', 'N/A')}"
        )
        response.results["dataform_invocation_url"] = dataform_invocation_url

        bigquery_ui_link = None
        if workflow_type_param == "BIGQUERY_PIPELINE":
            bigquery_ui_link = (
                f"https://console.cloud.google.com/bigquery?project={project_id}&ws=!1m6!1m5!19m4!1m3!1s{project_id}!2s{dataform_region}!3s{response.results.get('actual_repository_id', 'N/A')}"
            )
            response.results["bigquery_ui_link"] = bigquery_ui_link


        # Construct human-readable summary message
        final_summary_message = f"""**Data Engineering Workflow finished with status: {final_job_state.upper()}**
**Overall Success:** {'Yes' if final_job_state == 'SUCCEEDED' else 'No'}

### Workflow Details
- **Initiated for prompt:** {response.results.get('original_user_prompt', 'N/A')}
- **Inferred Workflow Type:** {response.results.get('workflow_type', 'N/A')}
- **Inferred Repository Name:** {response.results.get('repository_name', 'N/A')}
- **Inferred Workspace Name:** {response.results.get('workspace_name', 'N/A')}
- **Repository used:** {response.results.get('repository_name', 'N/A')} (ID: {response.results.get('actual_repository_id', 'N/A')})
- **Workspace used:** {response.results.get('workspace_name', 'N/A')} (ID: {response.results.get('actual_workspace_id', 'N/A')})
- **Dataform Workflow Invocation ID:** {response.results.get('workflow_invocation_id', 'N/A')}
- **Final Dataform Job State:** {final_job_state}
- **Dataform UI Link:** {dataform_invocation_url}
"""
        if bigquery_ui_link:
            final_summary_message += f"- **BigQuery UI Link:** {bigquery_ui_link}\n"

        final_summary_message += "\n### Messages from Workflow Steps\n"
        if response.messages:
            # Join with a newline and a list item marker
            messages_list = "\n".join([f"- {msg}" for msg in response.messages])
            final_summary_message += messages_list
        else:
            final_summary_message += "No detailed messages from steps."

        # Yield the final event with the human-readable summary
        yield Event(
            author=self.name,
            content=types.Content(role="assistant", parts=[types.Part(text=final_summary_message)]),
        )
        return