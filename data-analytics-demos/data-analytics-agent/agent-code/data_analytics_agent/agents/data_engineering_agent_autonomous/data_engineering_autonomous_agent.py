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
from typing import AsyncGenerator, Optional, List, Dict, Any
from typing_extensions import override
from pydantic import BaseModel, Field
from google.adk.events import Event
import os 
import json 
import re

from google.adk.agents import LlmAgent, BaseAgent, LoopAgent
from google.adk.agents.invocation_context import InvocationContext
from google.genai import types
from google.adk.tools.tool_context import ToolContext

import data_analytics_agent.tools.data_engineering_agent.data_engineering_tools as data_engineering_tools
import data_analytics_agent.tools.dataform.dataform_tools as dataform_tools
import data_analytics_agent.utils.time_delay.wait_tool as wait_tool


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

GEMINI_MODEL = "gemini-2.5-flash" # Use flash for faster tool calls, pro for reasoning if needed

# This will be the FINAL output schema for the DataEngineeringAutonomousWorkflowAgent (the orchestrator)
class DataEngineeringWorkflowOutput(BaseModel):
    status: str = Field(description="Overall status: 'success' or 'failed'")
    tool_name: str = Field(description="Name of the workflow that produced this result.")
    query: Optional[str] = Field(None, description="The query that initiated the workflow (if applicable).")
    messages: list[str] = Field(description="List of informational messages during processing.")
    results: Optional[dict] = Field(None, description="Detailed results of the data engineering workflow.")
    success: bool = Field(description="Did the overall workflow succeed?")

# Output schemas for individual LlmAgents (matching the tool's dictionary output structure)
class CheckDQFailuresOutput(BaseModel):
    failed_row_count: int = Field(description="The number of failed data quality rules.")
    success: bool = Field(description="Did the tool call complete successfully?")
    data_quality_scan_dataset_name: Optional[str] = Field(None, description="Dataset name of DQ results table.")
    data_quality_scan_table_name: Optional[str] = Field(None, description="Table name of DQ results table.")


class GetDQAnalysisOutput(BaseModel):
    failed_rules_details: list[Dict[str, Any]] = Field(description="Detailed results of the tool, including failed_rules_details.")
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
    success: bool = Field(description="Did the tool call complete successfully?")

class GeneralSuccessOutput(BaseModel):
    success: bool = Field(description="Did the tool call complete successfully?")

class CallDataEngAgentOutput(BaseModel):
    agent_raw_output: List[str] = Field(description="Raw output from the data engineering agent (flattened list of messages).")
    success: bool = Field(description="Did the tool call complete successfully?")

class LLMJudgeOutput(BaseModel):
    satisfactory: bool = Field(description="True if the LLM judge deemed the results satisfactory, False otherwise.")
    reasoning: Optional[str] = Field(None, description="Reasoning provided by the LLM judge.")
    success: bool = Field(description="Did the tool call complete successfully?")

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

# Wrapper for data_engineering_tools.check_data_quality_failures
async def check_for_data_quality_failures(data_quality_scan_name: str) -> dict:
    """
    Checks for failed data quality validation rules
    """
    print("BEGIN: check_for_data_quality_failures")
    result = await data_engineering_tools.check_data_quality_failures(
        data_quality_scan_name
    )
    print(f"END: check_for_data_quality_failures: {result}")
    success = False
    if result["status"] == "success":
        success = True
    response = {
        "failed_row_count": result["results"]["failed_row_count"],
        "success": success,
        "data_quality_scan_dataset_name": result.get("data_quality_scan_dataset_name"),
        "data_quality_scan_table_name": result.get("data_quality_scan_table_name"),
    }
    return response

# Wrapper for data_engineering_tools.get_data_quality_failure_analysis
async def get_failed_data(data_quality_scan_name: str, data_quality_scan_dataset_name: str, data_quality_scan_table_name: str) -> dict:
    logger.info("BEGIN: get_failed_data")
    
    if not all([data_quality_scan_name, data_quality_scan_dataset_name, data_quality_scan_table_name]):
        logger.error("Error: Missing parameters for get_failed_data.")
        return {"failed_rules_details": [], "success": False}
    
    result = await data_engineering_tools.get_data_quality_failure_analysis(
        data_quality_scan_name,
        data_quality_scan_dataset_name,
        data_quality_scan_table_name
    )
    logger.info(f"END: get_failed_data: {result}")

    success = result.get("status") == "success"
    return {
        "failed_rules_details": result.get("results", {}).get("failed_rules_details", []),
        "success": success
    }

# Wrapper for data_engineering_tools.generate_data_engineering_fix_prompt
async def generate_data_enginnering_agent_correction_prompt(failed_rules_details: List[Dict[str, Any]]) -> dict:
    logger.info("BEGIN: generate_data_enginnering_agent_correction_prompt")
    if not failed_rules_details:
        logger.error("Error: 'failed_rules_details' is empty.")
        return {"data_engineering_prompt": "", "success": False}
    
    result = await data_engineering_tools.generate_data_engineering_fix_prompt(failed_rules_details)
    logger.info(f"END: generate_data_enginnering_agent_correction_prompt: {result}")

    success = result.get("status") == "success"
    return {
        "data_engineering_prompt": result.get("results", {}).get("data_engineering_prompt", ""),
        "success": success
    }

# Wrapper for dataform_tools.get_repository_id_based_upon_display_name
async def get_repository_id(repository_name: str) -> dict:
    logger.info("BEGIN: get_repository_id")
    if not repository_name:
        return {"exists": False, "repository_id": None, "success": False}
    
    result_from_dataform_tool = await dataform_tools.get_repository_id_based_upon_display_name(repository_name)
    logger.info(f"Result from dataform_tools.get_repository_id_based_upon_display_name: {result_from_dataform_tool}")

    success = result_from_dataform_tool.get("status") == "success"
    processed_output = {
        "exists": result_from_dataform_tool.get("results", {}).get("exists", False),
        "repository_id": result_from_dataform_tool.get("results", {}).get("repository_id"),
        "success": success,
    }

    logger.info(f"END: get_repository_id: {processed_output}")
    return processed_output

# Wrapper for dataform_tools.create_bigquery_pipeline
async def create_bigquery_pipeline(derived_repository_id: str, repository_display_name: str) -> dict:
    logger.info("BEGIN: create_bigquery_pipeline")
    if not all([derived_repository_id, repository_display_name]):
        logger.error("Error: Missing parameters for create_bigquery_pipeline.")
        return {"success": False, "exists": False, "repository_id": None}
    
    result = await dataform_tools.create_bigquery_pipeline(derived_repository_id, repository_display_name)
    logger.info(f"END: create_bigquery_pipeline: {result}")

    success = result.get("status") == "success"
    repo_id_from_creation = result.get("results", {}).get("name") if success else None

    return {
        "success": success,
        "exists": success, # If created, it now exists
        "repository_id": repo_id_from_creation
    }

# Wrapper for dataform_tools.create_dataform_pipeline
async def create_dataform_pipeline(actual_repository_id: str, repository_display_name: str) -> dict:
    logger.info("BEGIN: create_dataform_pipeline")
    if not all([actual_repository_id, repository_display_name]):
        logger.error("Error: Missing parameters for create_dataform_pipeline.")
        return {"success": False, "exists": False, "repository_id": None}
    
    result = await dataform_tools.create_dataform_pipeline(actual_repository_id, repository_display_name)
    logger.info(f"END: create_dataform_pipeline: {result}")

    success = result.get("status") == "success"
    repo_id_from_creation = result.get("results", {}).get("name") if success else None

    return {
        "success": success,
        "exists": success, # If created, it now exists
        "repository_id": repo_id_from_creation
    }

# Wrapper for dataform_tools.get_workspace_id_based_upon_display_name
async def get_workspace_id(actual_repository_id: str, target_workspace_name: str) -> dict:
    logger.info("BEGIN: get_workspace_id")
    
    if not all([actual_repository_id, target_workspace_name]):
        logger.error("Error: Missing parameters for get_workspace_id.")
        return {"exists": False, "workspace_id": None, "discovered_workspaces": [], "success": False}
    
    result_from_dataform_tool = await dataform_tools.get_workspace_id_based_upon_display_name(actual_repository_id, target_workspace_name)
    logger.info(f"Result from dataform_tools.get_workspace_id_based_upon_display_name: {result_from_dataform_tool}")

    success = result_from_dataform_tool.get("status") == "success"
    processed_output = {
        "exists": result_from_dataform_tool.get("results", {}).get("exists", False),
        "workspace_id": result_from_dataform_tool.get("results", {}).get("workspace_id"),
        "discovered_workspaces": result_from_dataform_tool.get("discovered_workspaces", []),
        "success": success
    }
    
    logger.info(f"END: get_workspace_id: {processed_output}")
    return processed_output

# Wrapper for dataform_tools.create_workspace
async def create_workspace(actual_repository_id: str, actual_workspace_id: str) -> dict:
    logger.info("BEGIN: create_workspace")
    if not all([actual_repository_id, actual_workspace_id]):
        logger.error("Error: Missing parameters for create_workspace.")
        return {"success": False}
    
    result = await dataform_tools.create_workspace(actual_repository_id, actual_workspace_id)
    logger.info(f"END: create_workspace: {result}")
    
    success = result.get("status") == "success"
    return {"success": success}

# Wrapper for dataform_tools.does_workspace_file_exist (for workflow_settings.yaml)
async def check_for_workflow_settings(actual_repository_id: str, actual_workspace_id: str) -> dict:
    logger.info("BEGIN: check_for_workflow_settings")
    if not all([actual_repository_id, actual_workspace_id]):
        logger.error("Error: Missing parameters for check_for_workflow_settings.")
        return {"exists": False, "success": False}
    
    result = await dataform_tools.does_workspace_file_exist(actual_repository_id, actual_workspace_id, "workflow_settings.yaml")
    logger.info(f"END: check_for_workflow_settings: {result}")

    success = result.get("status") == "success"
    exists = result.get("results", {}).get("exists", False) if success else False # Ensure exists is only true if tool call succeeded
    return {"exists": exists, "success": success}

# Wrapper for dataform_tools.write_workflow_settings_file
async def upload_workflow_settings(actual_repository_id: str, actual_workspace_id: str) -> dict:
    logger.info("BEGIN: upload_workflow_settings")
    if not all([actual_repository_id, actual_workspace_id]):
        logger.error("Error: Missing parameters for upload_workflow_settings.")
        return {"success": False}
    
    result = await dataform_tools.write_workflow_settings_file(actual_repository_id, actual_workspace_id)
    logger.info(f"END: upload_workflow_settings: {result}")
    
    success = result.get("status") == "success"
    return {"success": success}

# Wrapper for dataform_tools.commit_workspace
async def commit_source_control(actual_repository_id: str, actual_workspace_id: str, commit_message: str) -> dict:
    logger.info("BEGIN: commit_source_control")
    if not all([actual_repository_id, actual_workspace_id, commit_message]):
        logger.error("Error: Missing parameters for commit_source_control.")
        return {"success": False}
    
    result = await dataform_tools.commit_workspace(actual_repository_id, actual_workspace_id, "Autonomous Data Engineering Agent", "agent@example.com", commit_message)
    logger.info(f"END: commit_source_control: {result}")
    
    success = result.get("status") == "success"
    return {"success": success}

# Wrapper for data_engineering_tools.call_bigquery_data_engineering_agent
async def call_bigquery_data_engineering_agent(actual_repository_id: str, actual_workspace_id: str, data_engineering_prompt: str) -> dict:
    logger.info("BEGIN: call_bigquery_data_engineering_agent")
    if not all([actual_repository_id, actual_workspace_id, data_engineering_prompt]):
        logger.error("Error: Missing parameters for call_bigquery_data_engineering_agent.")
        return {"agent_raw_output": [], "success": False} # Return empty list if params missing
    
    result = await data_engineering_tools.call_bigquery_data_engineering_agent(actual_repository_id, actual_workspace_id, data_engineering_prompt)
    logger.info(f"END: call_bigquery_data_engineering_agent: {result}")

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

# Update the schema to reflect List[str]
class CallDataEngAgentOutput(BaseModel):
    agent_raw_output: List[str] = Field(description="Raw output from the data engineering agent (flattened list of messages).")
    success: bool = Field(description="Did the tool call complete successfully?")

# Wrapper for data_engineering_tools.llm_as_a_judge
async def llm_as_a_judge(prompt_given_to_de_agent: str, bq_agent_response_results: List[str]) -> dict: # Expect List[str]
    logger.info("BEGIN: llm_as_a_judge")
    
    if not all([prompt_given_to_de_agent, bq_agent_response_results]):
        logger.error("Error: Missing parameters for llm_as_a_judge.")
        return {"satisfactory": False, "reasoning": "Missing input parameters.", "success": False}
    
    # Passing the list of strings directly to the underlying tool
    # The llm_as_a_judge tool may need its prompt updated to understand this new format.
    result = await data_engineering_tools.llm_as_a_judge(prompt_given_to_de_agent, bq_agent_response_results)
    logger.info(f"END: llm_as_a_judge: {result}")

    success = result.get("status") == "success"
    return {
        "satisfactory": result.get("results", {}).get("satisfactory", False),
        "reasoning": result.get("results", {}).get("reasoning", "No reasoning provided."),
        "success": success
    }

# Wrapper for dataform_tools.rollback_workspace
async def rollback_source_control(actual_repository_id: str, actual_workspace_id: str) -> dict:
    logger.info("BEGIN: rollback_source_control")
    if not all([actual_repository_id, actual_workspace_id]):
        logger.error("Error: Missing parameters for rollback_source_control.")
        return {"success": False}
    
    result = await dataform_tools.rollback_workspace(actual_repository_id, actual_workspace_id)
    logger.info(f"END: rollback_source_control: {result}")
    
    success = result.get("status") == "success"
    return {"success": success}

# Wrapper for dataform_tools.does_workspace_file_exist (for actions.yaml)
async def check_for_actions_settings(actual_repository_id: str, actual_workspace_id: str) -> dict:
    logger.info("BEGIN: check_for_actions_settings")
    if not all([actual_repository_id, actual_workspace_id]):
        logger.error("Error: Missing parameters for check_for_actions_settings.")
        return {"exists": False, "success": False}
    
    result = await dataform_tools.does_workspace_file_exist(actual_repository_id, actual_workspace_id, "definitions/actions.yaml")
    logger.info(f"END: check_for_actions_settings: {result}")

    success = result.get("status") == "success"
    exists = result.get("results", {}).get("exists", False) if success else False
    return {"exists": exists, "success": success}

# Wrapper for dataform_tools.write_actions_yaml_file
async def upload_actions_settings(actual_repository_id: str, actual_workspace_id: str) -> dict:
    logger.info("BEGIN: upload_actions_settings")
    if not all([actual_repository_id, actual_workspace_id]):
        logger.error("Error: Missing parameters for upload_actions_settings.")
        return {"success": False}
    
    result = await dataform_tools.write_actions_yaml_file(actual_repository_id, actual_workspace_id)
    logger.info(f"END: upload_actions_settings: {result}")
    
    success = result.get("status") == "success"
    return {"success": success}

# Wrapper for dataform_tools.compile_and_run_dataform_workflow
async def compile_and_execute_workflow(actual_repository_id: str, actual_workspace_id: str) -> dict:
    logger.info("BEGIN: compile_and_execute_workflow")
    if not all([actual_repository_id, actual_workspace_id]):
        logger.error("Error: Missing parameters for compile_and_execute_workflow.")
        return {"workflow_invocation_id": None, "compilation_id": None, "success": False}
    
    result = await dataform_tools.compile_and_run_dataform_workflow(actual_repository_id, actual_workspace_id)
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

# Wrapper for dataform_tools.get_worflow_invocation_status
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

    result = await dataform_tools.get_worflow_invocation_status(repository_id, workflow_invocation_id)
    
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
        logger.error(f"Error calling dataform_tools.get_worflow_invocation_status: {result.get('messages')}")


    return {
        "job_state": dataform_job_state,
        "success": tool_call_success
    }

# Wrapper for wait_tool.wait_for_seconds
async def time_delay(duration: int) -> dict:
    """
    Instructs the agent's execution environment to pause for the specified number of seconds.
    """
    print(f"BEGIN: wait_for_seconds (duration: {duration})")
    result = await wait_tool.wait_for_seconds(duration)
    print(f"END: wait_for_seconds")
    success = False
    if result["status"] == "success":
        success = True
    return {
        "duration": duration,
        "success": success
    }


# --- LlmAgent Definitions ---

# Step 1: Check DQ Failures
agent_de_check_dq_failures_instruction = """
Check for data quality failures:
1. Call `check_for_data_quality_failures(data_quality_scan_name="{{data_quality_scan_name_param}}")`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `check_for_data_quality_failures`.
"""
agent_de_check_dq_failures = LlmAgent(
    name="DataEngCheckDQFailures",
    model=GEMINI_MODEL,
    instruction=agent_de_check_dq_failures_instruction,
    input_schema=None,
    output_schema=CheckDQFailuresOutput,
    output_key="agent_de_check_dq_failures",
    tools=[check_for_data_quality_failures],
)

# Step 2: Get Detailed DQ Analysis
agent_de_get_dq_analysis_instruction = """
Get detailed data quality failure analysis:
1. Call `get_failed_data(data_quality_scan_name="{{data_quality_scan_name_param}}", data_quality_scan_dataset_name="{{data_quality_scan_dataset_name}}", data_quality_scan_table_name="{{data_quality_scan_table_name}}")`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `get_failed_data`.
"""
agent_de_get_dq_analysis = LlmAgent(
    name="DataEngGetDQAnalysis",
    model=GEMINI_MODEL,
    instruction=agent_de_get_dq_analysis_instruction,
    input_schema=None,
    output_schema=GetDQAnalysisOutput,
    output_key="agent_de_get_dq_analysis",
    tools=[get_failed_data],
)

# Step 3: Generate Data Engineering Fix Prompt
agent_de_generate_fix_prompt_instruction = """
Your only task is to generate a data engineering fix prompt.
1. Call `generate_data_enginnering_agent_correction_prompt(failed_rules_details={{failed_rules_details}})`.
2. After the tool returns, immediately respond by calling `set_model_response` with the exact dictionary result returned by `generate_data_enginnering_agent_correction_prompt`. Do NOT generate any conversational text, explanations, or any other content. Your entire response MUST be solely the `set_model_response` tool call.
"""
agent_de_generate_fix_prompt = LlmAgent(
    name="DataEngGenerateFixPrompt",
    model=GEMINI_MODEL,
    instruction=agent_de_generate_fix_prompt_instruction,
    input_schema=None,
    output_schema=GenerateFixPromptOutput,
    output_key="agent_de_generate_fix_prompt",
    tools=[generate_data_enginnering_agent_correction_prompt],
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
1. Call `call_bigquery_data_engineering_agent(actual_repository_id="{{actual_repository_id}}", actual_workspace_id="{{actual_workspace_id}}", data_engineering_prompt="{{data_engineering_prompt}})`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `call_bigquery_data_engineering_agent`.
"""
agent_de_call_bq_de_agent = LlmAgent(
    name="DataEngCallBQDEAgent",
    model=GEMINI_MODEL,
    instruction=agent_de_call_bq_de_agent_instruction,
    input_schema=None,
    output_schema=CallDataEngAgentOutput,
    output_key="agent_de_call_bq_de_agent",
    tools=[call_bigquery_data_engineering_agent],
)

# Step 4.5: Evaluate Generated Code with LLM Judge
agent_de_llm_judge_instruction = """
Evaluate generated code using LLM Judge:
1. Call `llm_as_a_judge(prompt_given_to_de_agent="{{data_engineering_prompt}}", bq_agent_response_results={{bq_agent_response_results | tojson}})`.
2. After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `llm_as_a_judge`.
"""
agent_de_llm_judge = LlmAgent(
    name="DataEngLLMJudge",
    model=GEMINI_MODEL,
    instruction=agent_de_llm_judge_instruction,
    input_schema=None,
    output_schema=LLMJudgeOutput,
    output_key="agent_de_llm_judge",
    tools=[llm_as_a_judge],
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
1. Call `time_delay(duration=4)`.
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
class DataEngineeringAutonomousWorkflowAgent(BaseAgent):
    """
    Agent that orchestrates autonomous data engineering pipeline correction based on data quality failures.
    """
    # Declare the agents passed to the class
    agent_de_check_dq_failures: LlmAgent
    agent_de_get_dq_analysis: LlmAgent
    agent_de_generate_fix_prompt: LlmAgent
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

    loop_wait_for_de_job_complete: LoopAgent

    def __init__(self, name: str,
                 agent_de_check_dq_failures: LlmAgent,
                 agent_de_get_dq_analysis: LlmAgent,
                 agent_de_generate_fix_prompt: LlmAgent,
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
                 agent_de_compile_and_run: LlmAgent
                 ):

        loop_wait_for_de_job_complete = LoopAgent(
            name="WaitForDEJobComplete", sub_agents=[agent_de_check_job_state, agent_de_time_delay_job], max_iterations=10
        ) # Max iterations based on expected job duration (e.g., 60 * 7 seconds = 7 minutes)

        # Define the overall sequence of sub-agents that will be run by this orchestrator.
        # Not all sub-agents will run in a strict sequence; some will be called conditionally
        # within _run_async_impl, but they must all be declared here.
        sub_agents_list = [
            agent_de_check_dq_failures,
            agent_de_get_dq_analysis,
            agent_de_generate_fix_prompt,
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
            agent_de_check_dq_failures=agent_de_check_dq_failures,
            agent_de_get_dq_analysis=agent_de_get_dq_analysis,
            agent_de_generate_fix_prompt=agent_de_generate_fix_prompt,
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
            sub_agents=sub_agents_list,
        )

    @override
    async def _run_async_impl(
        self, ctx: InvocationContext
    ) -> AsyncGenerator[Event, None]:
        logger.info(f"[{self.name}] Starting Autonomous Data Engineering workflow.")

        # TODO: Change this and have Gemini extract these parameters.
        prompt = ctx.user_content.parts[0].text
        logger.info(f"[{self.name}] Parsing initial prompt: {prompt}")

        # Initialize all parameters as None
        data_quality_scan_name_param = None
        repository_name_param = None
        workspace_name_param = None
        workflow_type_param = None

        # Extract from structured part of the prompt using regex
        repo_match = re.search(r"repository_name:\s*\"([^\"]+)\"", prompt, re.IGNORECASE)
        if repo_match:
            repository_name_param = repo_match.group(1)

        workspace_match = re.search(r"workspace_name:\s*\"([^\"]+)\"", prompt, re.IGNORECASE)
        if workspace_match:
            workspace_name_param = workspace_match.group(1)
            
        dq_scan_match = re.search(r"data_quality_scan_name:\s*\"([^\"]+)\"", prompt, re.IGNORECASE)
        if dq_scan_match:
            data_quality_scan_name_param = dq_scan_match.group(1)

        # Infer workflow_type from natural language part of the prompt
        lower_prompt = prompt.lower()
        if "dataform pipeline" in lower_prompt or "dataform" in lower_prompt or "repository" in lower_prompt or "workspace" in lower_prompt or "repo" in lower_prompt:
            workflow_type_param = "DATAFORM_PIPELINE"
        elif "bigquery pipeline" in lower_prompt or "bigquery" in lower_prompt:
            workflow_type_param = "BIGQUERY_PIPELINE"
        
        initial_query_param = prompt

        # Initialize response structure
        response = DataEngineeringWorkflowOutput(
            status="success",
            tool_name="autonomous_data_engineering_workflow",
            query=initial_query_param,
            messages=[],
            results={
                "data_quality_scan_name": data_quality_scan_name_param,
                "repository_name": repository_name_param,
                "workspace_name": workspace_name_param,
                "workflow_type": workflow_type_param,
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
        # It does not 'return' a value itself.
        def _fail_workflow_event(msg: str, current_response: DataEngineeringWorkflowOutput, debug_info: Optional[Dict[str, Any]] = None) -> Event:
            current_response.status = "failed"
            current_response.success = False
            current_response.messages.append(msg)
            
            # Using a multi-line f-string for Markdown formatting
            error_summary = f"""**Autonomous Data Engineering Workflow FAILED:** {msg}

### Workflow Details
- **Initiated for scan:** {current_response.results.get('data_quality_scan_name', 'N/A')}
- **Repository:** {current_response.results.get('actual_repository_id', 'N/A')}
- **Workspace:** {current_response.results.get('actual_workspace_id', 'N/A')}
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

            # --- VALIDATION ---
            error_messages = []
            if not data_quality_scan_name_param:
                error_messages.append("Missing 'data_quality_scan_name' in prompt.")
            if not repository_name_param:
                error_messages.append("Missing 'repository_name' in prompt.")
            if not workspace_name_param:
                error_messages.append("Missing 'workspace_name' in prompt.")
            if not workflow_type_param:
                error_messages.append("Could not infer 'workflow_type' from prompt. Please specify if it's a 'dataform pipeline' or 'bigquery pipeline'.")

            if error_messages:
                full_error_msg = f"Failed to parse required parameters from prompt. Errors: {'; '.join(error_messages)}"
                debug_info = {
                    "prompt": prompt,
                    "parsed_params": {
                        "data_quality_scan_name": data_quality_scan_name_param,
                        "repository_name": repository_name_param,
                        "workspace_name": workspace_name_param,
                        "workflow_type": workflow_type_param,
                    }
                }
                yield _fail_workflow_event(full_error_msg, response, debug_info=debug_info)
                return

        # Initial message
        yield Event(
            author=self.name,
            content=types.Content(
                role="assistant",
                parts=[
                    types.Part(
                        text=f"Initiating autonomous data engineering workflow to fix issues for scan '{data_quality_scan_name_param}'."
                    )
                ],
            ),
        )

        ########################################################
        # STEP 1: Check for Data Quality Failures
        ########################################################
        logger.info(f"[{self.name}] Running Agent: DataEngCheckDQFailures")
        ctx.session.state["data_quality_scan_name_param"] = data_quality_scan_name_param
        async for event in self.agent_de_check_dq_failures.run_async(ctx):
            logger.info(f"[{self.name}] Internal event from DataEngCheckDQFailures: {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event # Re-yield all events from the LlmAgent for UI visibility

        # IMPORTANT: Retrieve as dict, not Pydantic model
        check_dq_failures_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_de_check_dq_failures")

        if not check_dq_failures_result or not check_dq_failures_result.get("success"):
            yield _fail_workflow_event(f"Failed to check data quality failures.", response, debug_info=check_dq_failures_result)
            return

        failed_row_count = check_dq_failures_result.get("failed_row_count", 0)
        data_quality_scan_dataset_name = check_dq_failures_result.get("data_quality_scan_dataset_name")
        data_quality_scan_table_name = check_dq_failures_result.get("data_quality_scan_table_name")

        if failed_row_count == 0:
            response.messages.append("No data quality failures found. No correction needed.")
            yield Event(
                author=self.name,
                content=types.Content(role="assistant", parts=[types.Part(text=response.model_dump_json(indent=2, exclude_none=True))]),
            )
            return

        response.messages.append(f"Found {failed_row_count} data quality failures. Proceeding with analysis.")
        # Store for next step's templating
        ctx.session.state["data_quality_scan_dataset_name"] = data_quality_scan_dataset_name
        ctx.session.state["data_quality_scan_table_name"] = data_quality_scan_table_name
        # The data_quality_scan_name is already in session state from initial param.
        yield Event(
            author=self.name,
            content=types.Content(role="assistant", parts=[types.Part(text=f"Detected {failed_row_count} data quality issues. Analyzing details to generate a fix strategy.")])
        )


        ########################################################
        # STEP 2: Get Detailed Data Quality Failure Analysis
        ########################################################
        logger.info(f"[{self.name}] Running Agent: DataEngGetDQAnalysis")
        async for event in self.agent_de_get_dq_analysis.run_async(ctx):
            logger.info(f"[{self.name}] Internal event from DataEngGetDQAnalysis: {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event # Re-yield all events from the LlmAgent for UI visibility
        get_dq_analysis_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_de_get_dq_analysis")

        if not get_dq_analysis_result or not get_dq_analysis_result.get("success"):
            yield _fail_workflow_event(f"Failed to get detailed data quality analysis.", response, debug_info=get_dq_analysis_result)
            return

        failed_rules_details = get_dq_analysis_result.get("failed_rules_details", [])
        if not failed_rules_details:
            response.messages.append("No detailed failed rules found despite initial count. Exiting.")
            yield Event(
                author=self.name,
                content=types.Content(role="assistant", parts=[types.Part(text=response.model_dump_json(indent=2, exclude_none=True))]),
            )
            return

        # Store for next step's templating
        ctx.session.state["failed_rules_details"] = failed_rules_details
        response.messages.append(f"Retrieved detailed analysis for {len(failed_rules_details)} failed rules.")
        yield Event(
            author=self.name,
            content=types.Content(role="assistant", parts=[types.Part(text="Detailed analysis retrieved. Now generating data engineering fix prompts.")])
        )


        ########################################################
        # STEP 3: Generate Data Engineering Fix Prompt
        ########################################################
        logger.info(f"[{self.name}] Running Agent: DataEngGenerateFixPrompt")
        async for event in self.agent_de_generate_fix_prompt.run_async(ctx):
            logger.info(f"[{self.name}] Internal event from DataEngGenerateFixPrompt: {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event # Re-yield all events from the LlmAgent for UI visibility
        generate_fix_prompt_result: Optional[Dict[str, Any]] = ctx.session.state.get("agent_de_generate_fix_prompt")

        if not generate_fix_prompt_result or not generate_fix_prompt_result.get("success"):
            yield _fail_workflow_event(f"Failed to generate data engineering fix prompt.", response, debug_info=generate_fix_prompt_result)
            return

        data_engineering_prompt = generate_fix_prompt_result.get("data_engineering_prompt")
        if not data_engineering_prompt:
            yield _fail_workflow_event(f"Generated data engineering prompt is empty.", response, debug_info=generate_fix_prompt_result)
            return

        # Store for next step's templating
        ctx.session.state["data_engineering_prompt"] = data_engineering_prompt
        response.messages.append(f"Generated data engineering prompt.")
        yield Event(
            author=self.name,
            content=types.Content(role="assistant", parts=[types.Part(text="Generated fix prompts. Starting pipeline correction process.")])
        )


        ########################################################
        # STEP 4: Execute Autonomous Pipeline Correction
        ########################################################
        actual_repository_id = None
        
        # 4.1. Resolve Actual Repository ID
        logger.info(f"[{self.name}] Running Agent: DataEngGetRepoID")
        ctx.session.state["repository_name_param"] = repository_name_param # Ensure this is in state for templating
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


        # 4.2. Resolve Actual Workspace ID
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
                actual_workspace_id = target_workspace_name
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


        # 4.3. Initialize Workspace (if necessary) - workflow_settings.yaml
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

        # 4.4. Generate/Update Code with BigQuery Data Engineering Agent
        logger.info(f"[{self.name}] Running Agent: DataEngCallBQDEAgent")
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


        # 4.5. Evaluate Generated Code with LLM Judge
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


        # 4.6. Commit Generated Code
        ctx.session.state["commit_message"] = "Autonomous commit of data engineering agent code"
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


        # 4.7. Ensure `actions.yaml` Exists
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

            ctx.session.state["commit_message"] = "Autonomous commit of definitions/actions.yaml"
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


        # 4.8. Compile and Run Dataform Workflow
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
        # STEP 5: Monitor Pipeline Workflow Status and Report Result
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


        # Construct human-readable summary message using Markdown
        final_summary_message = f"""**Autonomous Data Engineering Workflow finished with status: {final_job_state.upper()}**
**Overall Success:** {'Yes' if final_job_state == 'SUCCEEDED' else 'No'}

### Workflow Details
- **Initiated for scan:** {response.results.get('data_quality_scan_name', 'N/A')}
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


def get_data_engineering_autonomous_agent():
    return  DataEngineeringAutonomousWorkflowAgent(
        name="DataEngineeringAgent_Autonomous_Agent", 
        agent_de_check_dq_failures=agent_de_check_dq_failures,
        agent_de_get_dq_analysis=agent_de_get_dq_analysis,
        agent_de_generate_fix_prompt=agent_de_generate_fix_prompt,
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
        agent_de_compile_and_run=agent_de_compile_and_run
    )