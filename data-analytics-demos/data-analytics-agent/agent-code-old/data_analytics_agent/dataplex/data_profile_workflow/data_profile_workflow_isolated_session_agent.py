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
from typing import AsyncGenerator, Optional
from typing_extensions import override

# --- NEW IMPORT ---
import asyncio
import os # --- CHANGE 1 of 2: ADD THIS IMPORT ---

from google.adk.agents import LlmAgent, BaseAgent, LoopAgent, SequentialAgent
from google.adk.agents.invocation_context import InvocationContext
from google.genai import types
from google.adk.sessions import InMemorySessionService
from google.adk.runners import Runner
from google.adk.events import Event
from pydantic import BaseModel, Field
import json
import data_analytics_agent.dataplex.data_profile as data_profile_tools
import data_analytics_agent.wait_tool as wait_tool_helper
from google.adk.tools.tool_context import ToolContext
import uuid

# ---
# ... (NO CHANGES IN THIS ENTIRE SECTION, from line 23 to 834) ...
# All class definitions, tool wrappers, and the child agent remain IDENTICAL.
# Scroll down to the very end of the file for the second change.
# ---

# --- Constants ---
APP_NAME = "data_profile_app"
USER_ID = "data_profile_session"
SESSION_ID = str(uuid.uuid4())[:8] # Unique identifier for this specific profiling task
GEMINI_MODEL = "gemini-2.5-flash"


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# This will be the FINAL output schema for the DataProfileWorkflowIsolatedSessionAgent (the orchestrator)
# class DataProfilingWorkflowOutput(BaseModel):
#     status: str = Field(description="Overall status: 'success' or 'failed'")
#     tool_name: str = Field(description="Name of the tool/workflow that produced this result.")
#     query: Optional[str] = Field(None, description="The query that initiated the workflow (if applicable).")
#     messages: list[str] = Field(description="List of informational messages during processing.")
#     results: Optional[dict] = Field(None, description="Detailed results of the data profile scan, if successful.")
#     success: bool = Field(description="Did the overall workflow succeed?")

# Specific Output Schemas for each LlmAgent's tool
class CreateScanOutput(BaseModel):
    data_profile_scan_name: str = Field(description="The data profile scan name")
    data_profile_display_name: str = Field(description="The data profile scan display name.")
    bigquery_dataset_name: str = Field(description="The BigQuery dataset name.")
    bigquery_table_name: str = Field(description="The BigQuery table name.")
    success: bool = Field(description="Did the tool call complete successfully?")

class LinkToBigQueryOutput(BaseModel):
    dataplex_scan_name: str = Field(description="The name of the Dataplex scan linked.")
    bigquery_dataset_name: str = Field(description="The BigQuery dataset name.")
    bigquery_table_name: str = Field(description="The BigQuery table name.")
    success: bool = Field(description="Did the tool call complete successfully.")

class CheckScanExistsOutput(BaseModel):
    success: bool = Field(description="True if the scan exists, False otherwise.")

class StartScanJobOutput(BaseModel):
    data_profile_scan_job_name: Optional[str] = Field(None, description="The name of the started scan job.")
    success: bool = Field(description="Did the tool call complete successfully.")

class CheckScanJobStateOutput(BaseModel):
    data_profile_scan_job_state: str = Field(description="The state of the scan job (e.g., SUCCEEDED, FAILED, RUNNING).")
    success: bool = Field(description="True if the job completed successfully, False otherwise or still running.")

class TimeDelayOutput(BaseModel):
    success: bool = Field(description="True if the delay completed successfully.")


class DataProfileWorkflowIsolatedSessionAgent(BaseAgent):
    """
    Agent that creates and monitors Dataplex Data Profiles

    This agent orchestrates a sequence of LLM agents create to:
    - **Step 1: Create the Scan Definition:**
    - **Step 2: Link the Scan to BigQuery:**
    - **Step 3: Start the Scan Job:**
    - **Step 4: Monitor the Scan Job:**
    """

    # Declare the agents pass to the class
    agent_data_profile_create_scan: LlmAgent          # Creates the scan and returns the scan id
    agent_data_profile_link_to_bigquery: LlmAgent     # Links the scan id to BigQuery, returns nothing
    agent_data_profile_check_scan_exists: LlmAgent    # Tests to see if the scan exists (it can take a few seconds), return nothing
    agent_data_profile_scan_job_start: LlmAgent       # Starts the scan job and returns the scan job id
    agent_data_profile_scan_job_state: LlmAgent       # Tests the status of the scan job, returns when complete
    agent_time_delay_create: LlmAgent                 # Sleeps for {x} seconds
    agent_time_delay_job: LlmAgent                    # Sleeps for {x} seconds

    agent_loop_wait_for_scan_create: LoopAgent
    agent_loop_wait_for_scan_complete: LoopAgent

    def __init__(
        self,
        name: str,
        agent_data_profile_create_scan: LlmAgent,
        agent_data_profile_link_to_bigquery: LlmAgent,
        agent_data_profile_check_scan_exists: LlmAgent,
        agent_data_profile_scan_job_start: LlmAgent,
        agent_data_profile_scan_job_state: LlmAgent,
        agent_time_delay_create: LlmAgent,
        agent_time_delay_job: LlmAgent,
    ):
        """
        Initializes the DataProfileWorkflowIsolatedSessionAgent.
        """

        # Agents that will Loop and Wait for completion
        agent_loop_wait_for_scan_create = LoopAgent(
            name="WaitForScanCreate",
            sub_agents=[agent_data_profile_check_scan_exists, agent_time_delay_create],
            max_iterations=10)

        agent_loop_wait_for_scan_complete = LoopAgent(
            name="WaitForScanComplete",
            sub_agents=[agent_data_profile_scan_job_state, agent_time_delay_job],
            max_iterations=50)

        # Sub-Agents (no need for the agents used by the Loop agents)
        sub_agents_list = [
            agent_data_profile_create_scan,
            agent_data_profile_link_to_bigquery,
            agent_loop_wait_for_scan_create,
            agent_data_profile_scan_job_start,
            agent_loop_wait_for_scan_complete
        ]

        # Every agent needs to be here (including internal Loop agents)
        super().__init__(
            name=name,
            # Create
            agent_data_profile_create_scan=agent_data_profile_create_scan,

            # Link to BQ
            agent_data_profile_link_to_bigquery=agent_data_profile_link_to_bigquery,

            # Create "Wait" Loop
            agent_loop_wait_for_scan_create=agent_loop_wait_for_scan_create,
            agent_data_profile_check_scan_exists=agent_data_profile_check_scan_exists,
            agent_time_delay_create=agent_time_delay_create,

            # Start "Scan" Job
            agent_data_profile_scan_job_start=agent_data_profile_scan_job_start,

            # Scan Job "Wait" Loop
            agent_loop_wait_for_scan_complete=agent_loop_wait_for_scan_complete,
            agent_data_profile_scan_job_state=agent_data_profile_scan_job_state,
            agent_time_delay_job=agent_time_delay_job,

            # Must include all sub agents
            sub_agents=sub_agents_list,
        )

    @override
    async def _run_async_impl(
        self, ctx: InvocationContext
    ) -> AsyncGenerator[Event, None]:
        """
        Implements the custom orchestration logic for the data profile scans.
        Uses the instance attributes assigned by Pydantic (e.g., self.agent_data_profile_create_scan).

        Returns:
            dict: 
        """
        logger.info(f"[{self.name}] Starting Data Profile Scan workflow.")
        response = {
            "status": "success",
            "tool_name": "data_profile_scan_workflow",
            "query": None,
            "messages": [],
            "results": {
                "data_profile_scan_name": None,
                "data_profile_display_name": None,
                "bigquery_dataset_name": None,
                "bigquery_table_name": None,
                "data_profile_scan_job_name": None,
                "data_profile_scan_job_state": None,
            },
            "success": True # Overall workflow success status
        }

        # The initial prompt content is now expected to be in ctx.session.state,
        # populated by OrchestratingDataProfileWorkflowIsolatedSessionAgent.
        initial_prompt_content = ctx.session.state.get("initial_data_profile_query")
        #response["query"] = initial_prompt_content

        # Yield an initial message to show activity
        yield Event(
            author=self.name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Initiating data profile scan workflow based on your request.")])
        )

        ########################################################
        # STEP: agent_data_profile_create_scan
        ########################################################
        logger.info(f"[{self.name}] Agent: agent_data_profile_create_scan")
        async for event in self.agent_data_profile_create_scan.run_async(ctx):
            logger.info(f"[{self.name}] Internal event from agent_data_profile_create_scan: {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event # Re-yield all events from the LlmAgent for UI visibility

        agent_data_profile_create_scan_result: Optional[dict] = ctx.session.state.get("agent_data_profile_create_scan")
        logger.info(f"[{self.name}]agent_data_profile_create_scan_result: {agent_data_profile_create_scan_result}")

        if not agent_data_profile_create_scan_result or not agent_data_profile_create_scan_result.get("success"):
            logger.info(f"Failed: agent_data_profile_create_scan")
            response["status"] = "failed"
            response["success"] = False
            scan_name = agent_data_profile_create_scan_result.get("data_profile_scan_name") if agent_data_profile_create_scan_result else 'Unknown'
            response["messages"].append(f"Failed to create the data profile scan: {scan_name}")
            if agent_data_profile_create_scan_result:
                response["results"].update({
                    "data_profile_scan_name": agent_data_profile_create_scan_result.get("data_profile_scan_name"),
                    "data_profile_display_name": agent_data_profile_create_scan_result.get("data_profile_display_name"),
                    "bigquery_dataset_name": agent_data_profile_create_scan_result.get("bigquery_dataset_name"),
                    "bigquery_table_name": agent_data_profile_create_scan_result.get("bigquery_table_name"),
                })
            # Yield final error event immediately
            yield Event(
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=json.dumps(response, indent=2))])
            )
            return
        else:
            logger.info(f"agent_data_profile_create_scan: SUCCESS")
            success_message = f"Successfully created data profile scan definition: {agent_data_profile_create_scan_result.get('data_profile_scan_name')}. Now waiting for it to register."
            response["messages"].append(success_message)
            response["results"].update({
                "data_profile_scan_name": agent_data_profile_create_scan_result.get("data_profile_scan_name"),
                "data_profile_display_name": agent_data_profile_create_scan_result.get("data_profile_display_name"),
                "bigquery_dataset_name": agent_data_profile_create_scan_result.get("bigquery_dataset_name"),
                "bigquery_table_name": agent_data_profile_create_scan_result.get("bigquery_table_name"),
            })
            # Explicitly yield a progress message for the UI
            yield Event(
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=success_message)])
            )

        ########################################################
        # STEP: agent_loop_wait_for_scan_create
        ########################################################
        logger.info(f"[{self.name}] Agent: agent_loop_wait_for_scan_create")
        async for event in self.agent_loop_wait_for_scan_create.run_async(ctx):
            logger.info(f"[{self.name}] Internal event from agent_loop_wait_for_scan_create: {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event # Re-yield events from the loop agent, including time delay messages

        agent_loop_wait_for_scan_create_result: Optional[dict] = ctx.session.state.get("agent_loop_wait_for_scan_create")
        logger.info(f"[{self.name}]agent_loop_wait_for_scan_create_result: {agent_loop_wait_for_scan_create_result}")

        if not agent_loop_wait_for_scan_create_result or not agent_loop_wait_for_scan_create_result.get("success"):
            logger.info(f"Failed to wait for data profile to create.")
            response["status"] = "failed"
            response["success"] = False
            error_message = f"Failed to wait for the scan '{response['results']['data_profile_scan_name']}' to be registered. It might be taking too long."
            response["messages"].append(error_message)
            yield Event( # Yield final error event
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=json.dumps(response, indent=2))])
            )
            return
        else:
            logger.info(f"agent_loop_wait_for_scan_create: SUCCESS")
            success_message = f"Data profile scan '{response['results']['data_profile_scan_name']}' is now registered and ready."
            response["messages"].append(success_message)
            # Explicitly yield a progress message for the UI
            yield Event(
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=success_message)])
            )


        ########################################################
        # STEP: agent_data_profile_scan_job_start
        ########################################################
        logger.info(f"[{self.name}] Agent: agent_data_profile_scan_job_start")
        async for event in self.agent_data_profile_scan_job_start.run_async(ctx):
            logger.info(f"[{self.name}] Internal event from agent_data_profile_scan_job_start: {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event

        agent_data_profile_scan_job_start_result: Optional[dict] = ctx.session.state.get("agent_data_profile_scan_job_start")
        logger.info(f"[{self.name}]agent_data_profile_scan_job_start_result: {agent_data_profile_scan_job_start_result}")

        if not agent_data_profile_scan_job_start_result or not agent_data_profile_scan_job_start_result.get("success"):
            logger.info(f"Failed: agent_data_profile_scan_job_start")
            response["status"] = "failed"
            response["success"] = False
            error_message = f"Failed to start the scan job for data profile scan: {response['results']['data_profile_scan_name']}"
            response["messages"].append(error_message)
            if agent_data_profile_scan_job_start_result:
                response["results"]["data_profile_scan_job_name"] = agent_data_profile_scan_job_start_result.get("data_profile_scan_job_name")
            yield Event( # Yield final error event
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=json.dumps(response, indent=2))])
            )
            return
        else:
            logger.info(f"agent_data_profile_scan_job_start: SUCCESS")
            success_message = f"Successfully started the data profile scan job: {agent_data_profile_scan_job_start_result.get('data_profile_scan_job_name')}. Monitoring its progress."
            response["messages"].append(success_message)
            response["results"]["data_profile_scan_job_name"] = agent_data_profile_scan_job_start_result.get("data_profile_scan_job_name")
            
            # PROMOTE data_profile_scan_job_name to root of session state for next step's instruction templating
            ctx.session.state["current_data_profile_scan_job_name"] = agent_data_profile_scan_job_start_result.get("data_profile_scan_job_name")

            # Explicitly yield a progress message for the UI
            yield Event(
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=success_message)])
            )


        ########################################################
        # STEP: agent_loop_wait_for_scan_complete
        ########################################################
        logger.info(f"[{self.name}] Agent: agent_loop_wait_for_scan_complete")
        async for event in self.agent_loop_wait_for_scan_complete.run_async(ctx):
            logger.info(f"[{self.name}] Internal event from agent_loop_wait_for_scan_complete: {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event # Re-yield events from the loop agent, including time delay messages

        agent_loop_wait_for_scan_complete_result: Optional[dict] = ctx.session.state.get("agent_loop_wait_for_scan_complete")
        logger.info(f"[{self.name}]agent_loop_wait_for_scan_complete_result: {agent_loop_wait_for_scan_complete_result}")

        if not agent_loop_wait_for_scan_complete_result or not agent_loop_wait_for_scan_complete_result.get("success"):
            logger.info(f"Failed: agent_loop_wait_for_scan_complete")
            response["status"] = "failed"
            response["success"] = False
            job_name = response['results'].get('data_profile_scan_job_name')
            job_state = agent_loop_wait_for_scan_complete_result.get("data_profile_scan_job_state") if agent_loop_wait_for_scan_complete_result else 'Unknown'
            error_message = f"Data profiling job '{job_name}' failed or was cancelled. Final state: {job_state}"
            response["messages"].append(error_message)
            if agent_loop_wait_for_scan_complete_result:
                response["results"]["data_profile_scan_job_state"] = agent_loop_wait_for_scan_complete_result.get("data_profile_scan_job_state")
            yield Event( # Yield final error event
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=json.dumps(response, indent=2))])
            )
            return
        else:
            logger.info(f"agent_loop_wait_for_scan_complete: SUCCESS")
            success_message = f"Data profiling job '{response['results']['data_profile_scan_job_name']}' completed successfully with state: {agent_loop_wait_for_scan_complete_result.get('data_profile_scan_job_state')}. Now linking to BigQuery."
            response["messages"].append(success_message)
            response["results"]["data_profile_scan_job_state"] = agent_loop_wait_for_scan_complete_result.get("data_profile_scan_job_state")
            # Explicitly yield a progress message for the UI
            yield Event(
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=success_message)])
            )


        ########################################################
        # STEP: agent_data_profile_link_to_bigquery
        ########################################################
        logger.info(f"[{self.name}] Agent: agent_data_profile_link_to_bigquery")
        async for event in self.agent_data_profile_link_to_bigquery.run_async(ctx):
            logger.info(f"[{self.name}] Internal event from agent_data_profile_link_to_bigquery: {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event

        agent_data_profile_link_to_bigquery_result: Optional[dict] = ctx.session.state.get("agent_data_profile_link_to_bigquery")
        logger.info(f"[{self.name}]agent_data_profile_link_to_bigquery_result: {agent_data_profile_link_to_bigquery_result}")

        if not agent_data_profile_link_to_bigquery_result or not agent_data_profile_link_to_bigquery_result.get("success"):
            logger.info(f"Failed: agent_data_profile_link_to_bigquery")
            response["status"] = "failed"
            response["success"] = False
            scan_name = agent_data_profile_link_to_bigquery_result.get("dataplex_scan_name") if agent_data_profile_link_to_bigquery_result else 'Unknown'
            error_message = f"Failed to link the data profile scan '{scan_name}' to BigQuery."
            response["messages"].append(error_message)
            yield Event( # Yield final error event
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=json.dumps(response, indent=2))])
            )
            return
        else:
            logger.info(f"agent_data_profile_link_to_bigquery: SUCCESS")
            success_message = f"Successfully linked the data profile scan to BigQuery. Results should now be visible in the BigQuery console."
            response["messages"].append(success_message)
            yield Event( # Explicitly yield a progress message for the UI
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=success_message)])
            )

        # Done!
        logger.info(f"[{self.name}] Workflow finished.")
        if response["status"] == "success":
            response["success"] = True

        yield Event( # Final event for the whole workflow, with full structured response
            author=self.name,
            content=types.Content(role='assistant', parts=[types.Part(text=json.dumps(response, indent=2))])
        )
        return


################################################################################################
# 1. agent_data_profile_create_scan
################################################################################################
# --- CORRECTED ---
async def agent_data_profile_create_scan_tool(data_profile_scan_name: str, data_profile_display_name: str, bigquery_dataset_name: str, bigquery_table_name: str) -> dict:
    """
    Creates data data profile scan.
    """
    print("BEGIN: agent_data_profile_create_scan_tool")
    result = await asyncio.to_thread(
        data_profile_tools.create_data_profile_scan,
        data_profile_scan_name,
        data_profile_display_name,
        bigquery_dataset_name,
        bigquery_table_name
    )
    print(f"END: agent_data_profile_create_scan_tool: {result}")
    success = False
    if result["status"] == "success":
        success = True
    response = {
        "data_profile_scan_name": data_profile_scan_name,
        "data_profile_display_name": data_profile_display_name,
        "bigquery_dataset_name": bigquery_dataset_name,
        "bigquery_table_name": bigquery_table_name,
        "success": success
    }
    return response

agent_data_profile_create_scan_instruction = """Create the Scan Definition:
1.  Call `agent_data_profile_create_scan_tool(data_profile_scan_name="{{data_profile_scan_name}}", data_profile_display_name="{{data_profile_display_name}}", bigquery_dataset_name="{{bigquery_dataset_name}}", bigquery_table_name="{{bigquery_table_name}}")` using the parameters from the current session state.
2.  After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `agent_data_profile_create_scan_tool`.
"""

agent_data_profile_create_scan = LlmAgent(
     name="DataProfileCreateScan",
     model=GEMINI_MODEL,
     instruction=agent_data_profile_create_scan_instruction,
     input_schema=None,
     output_schema=CreateScanOutput,
     output_key="agent_data_profile_create_scan",
     tools=[agent_data_profile_create_scan_tool]
 )


################################################################################################
# 2. agent_data_profile_link_to_bigquery
################################################################################################
# --- CORRECTED ---
async def agent_data_profile_link_to_bigquery_tool(dataplex_scan_name: str, bigquery_dataset_name: str, bigquery_table_name: str) -> dict:
    """
    Updates a BigQuery table's labels to link it to a Dataplex data profile scan.
    """
    print("BEGIN: agent_data_profile_link_to_bigquery_tool")
    result = await asyncio.to_thread(
        data_profile_tools.update_bigquery_table_dataplex_labels,
        dataplex_scan_name,
        bigquery_dataset_name,
        bigquery_table_name,
    )
    print(f"END: agent_data_profile_link_to_bigquery_tool: {result}")
    success = False
    if result["status"] == "success":
        success = True
    response = {
        "dataplex_scan_name": dataplex_scan_name,
        "bigquery_dataset_name": bigquery_dataset_name,
        "bigquery_table_name": bigquery_table_name,
        "success": success
    }
    return response

agent_data_profile_link_to_bigquery_instruction = """Link the Scan to BigQuery:
1.  Call `agent_data_profile_link_to_bigquery_tool(dataplex_scan_name="{{data_profile_scan_name}}", bigquery_dataset_name="{{bigquery_dataset_name}}", bigquery_table_name="{{bigquery_table_name}}")` using the parameters from the current session state.
2.  After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `agent_data_profile_link_to_bigquery_tool`.
"""

agent_data_profile_link_to_bigquery = LlmAgent(
     name="DataProfileLinkToBigQuery",
     model=GEMINI_MODEL,
     instruction=agent_data_profile_link_to_bigquery_instruction,
     input_schema=None,
     output_schema=LinkToBigQueryOutput,
     output_key="agent_data_profile_link_to_bigquery",
     tools=[agent_data_profile_link_to_bigquery_tool]
 )


################################################################################################
# 3. agent_data_profile_check_scan_exists
################################################################################################
# --- CORRECTED ---
async def agent_data_profile_check_scan_exists_tool(tool_context: ToolContext, data_profile_scan_name: str) -> dict:
    """
    Checks to see if a data profile scan exists.
    """
    print(f"BEGIN: agent_data_profile_check_scan_exists_tool")
    result = await asyncio.to_thread(data_profile_tools.exists_data_profile_scan, data_profile_scan_name)
    print(f"END: agent_data_profile_check_scan_exists_tool: {result}")
    success = False
    if result["status"] == "success":
        success = result["results"]["exists"]
        if success:
            tool_context.actions.escalate = True # Exit the Loop Agent
    response = {
        "success": success
    }
    return response

agent_data_profile_check_scan_exists_instruction = """Checks to see if a data profile scan exists on a table.
1.  Call `agent_data_profile_check_scan_exists_tool(data_profile_scan_name="{{data_profile_scan_name}}")` using the scan name from the current session state.
2.  After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `agent_data_profile_check_scan_exists_tool`.
"""

agent_data_profile_check_scan_exists = LlmAgent(
     name="DataProfileCheckScanExists",
     model=GEMINI_MODEL,
     instruction=agent_data_profile_check_scan_exists_instruction,
     input_schema=None,
     output_schema=CheckScanExistsOutput,
     output_key="agent_loop_wait_for_scan_create",
     tools=[agent_data_profile_check_scan_exists_tool]
 )


################################################################################################
# 4. agent_data_profile_scan_job_start
################################################################################################
# --- CORRECTED ---
async def agent_data_profile_scan_job_start_tool(data_profile_scan_name: str) -> dict:
    """
    This will start a scan job and return the job id.
    """
    print("BEGIN: agent_data_profile_scan_job_start_tool")
    result = await asyncio.to_thread(data_profile_tools.start_data_profile_scan, data_profile_scan_name)
    print(f"END: agent_data_profile_scan_job_start_tool: {result}")
    success = False
    data_profile_scan_job_name = None
    if result["status"] == "success":
        success = True
        data_profile_scan_job_name = result["results"]["job"]["name"]
    response = {
        "data_profile_scan_job_name": data_profile_scan_job_name,
        "success": success
    }
    return response

agent_data_profile_scan_job_start_instruction = """Starts a Data Profile Job Scan.
1.  Call `agent_data_profile_scan_job_start_tool(data_profile_scan_name="{{data_profile_scan_name}}")` using the scan name from the current session state.
2.  After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `agent_data_profile_scan_job_start_tool`.
"""

agent_data_profile_scan_job_start = LlmAgent(
     name="DataProfileStartScanJob",
     model=GEMINI_MODEL,
     instruction=agent_data_profile_scan_job_start_instruction,
     input_schema=None,
     output_schema=StartScanJobOutput,
     output_key="agent_data_profile_scan_job_start",
     tools=[agent_data_profile_scan_job_start_tool]
 )


################################################################################################
# 6. agent_data_profile_scan_job_state
################################################################################################
# --- CORRECTED ---
async def agent_data_profile_scan_job_state_tool(tool_context: ToolContext, data_profile_scan_job_name: str) -> dict:
    """
    Checks to see if a data profile scan exists.
    """
    print(f"BEGIN: agent_data_profile_scan_job_state_tool: {data_profile_scan_job_name}")
    result = await asyncio.to_thread(data_profile_tools.get_data_profile_scan_state, data_profile_scan_job_name)
    print(f"END: agent_data_profile_scan_job_state_tool: {result}")
    success = False
    data_profile_scan_job_state = "UNKNOWN"
    if result["status"] == "success":
        data_profile_scan_job_state = result["results"]["job"]["state"]
        if data_profile_scan_job_state == "SUCCEEDED":
            success = True
        if data_profile_scan_job_state in ["SUCCEEDED", "FAILED", "CANCELLED"]:
            tool_context.actions.escalate = True
    response = {
        "data_profile_scan_job_state": data_profile_scan_job_state,
        "success": success
    }
    return response

agent_data_profile_scan_job_state_instruction = """Checks the state of a data profile scan job.
1.  Call `agent_data_profile_scan_job_state_tool(data_profile_scan_job_name="{{current_data_profile_scan_job_name}}")` using the job name from the current session state.
2.  After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `agent_data_profile_scan_job_state_tool`.
"""

agent_data_profile_scan_job_state = LlmAgent(
     name="DataProfileCheckScanJob",
     model=GEMINI_MODEL,
     instruction=agent_data_profile_scan_job_state_instruction,
     input_schema=None,
     output_schema=CheckScanJobStateOutput,
     output_key="agent_loop_wait_for_scan_complete",
     tools=[agent_data_profile_scan_job_state_tool]
 )


################################################################################################
# Helper: agent_time_delay
################################################################################################
# --- CORRECTED ---
async def agent_time_delay_tool(duration: int) -> dict:
    """
    Instructs the agent's execution environment to pause for the specified number of seconds.
    """
    print("Waiting for Data Profile Scan to be created...")
    print(f"BEGIN: wait_for_seconds")
    result = await asyncio.to_thread(wait_tool_helper.wait_for_seconds, duration)
    print(f"END: wait_for_seconds")
    success = False
    if result["status"] == "success":
        success = True
    response = {
        "success": success
    }
    return response

agent_time_delay_create_instruction = """Your only task is to wait for a specified duration.
1. Call `agent_time_delay_tool(duration=2)`.
2. After the tool returns, immediately respond by calling `set_model_response` with the exact dictionary result returned by `agent_time_delay_tool`. Do NOT generate any conversational text, explanations, or any other content. Your entire response MUST be solely the `set_model_response` tool call.
"""

agent_time_delay_create = LlmAgent(
     name="TimeDelayCreate",
     model=GEMINI_MODEL,
     instruction=agent_time_delay_create_instruction,
     input_schema=None,
     output_schema=TimeDelayOutput,
     output_key="agent_time_delay_create",
     tools=[ agent_time_delay_tool ]
 )


agent_time_delay_job_instruction = """Your only task is to wait for a specified duration.
1. Call `agent_time_delay_tool(duration=5)`.
2. After the tool returns, immediately respond by calling `set_model_response` with the exact dictionary result returned by `agent_time_delay_tool`. Do NOT generate any conversational text, explanations, or any other content. Your entire response MUST be solely the `set_model_response` tool call.
"""

agent_time_delay_job = LlmAgent(
     name="TimeDelayJob",
     model=GEMINI_MODEL,
     instruction=agent_time_delay_job_instruction,
     input_schema=None,
     output_schema=TimeDelayOutput,
     output_key="agent_time_delay_job",
     tools=[ agent_time_delay_tool ]
 )


################################################################################################
# Create the OrchestratingDataProfileWorkflowIsolatedSessionAgent
################################################################################################
class OrchestratingDataProfileWorkflowIsolatedSessionAgent(BaseAgent):
    # Declare data_profiling_workflow_agent as a class attribute with its type hint
    data_profiling_workflow_agent: DataProfileWorkflowIsolatedSessionAgent

    def __init__(self, name: str):
        # Instantiate the DataProfileWorkflowIsolatedSessionAgent here first
        data_profiling_workflow_agent_instance = DataProfileWorkflowIsolatedSessionAgent(
            name="DataProfilingWorkflow", # A distinct name for this instance
            agent_data_profile_create_scan=agent_data_profile_create_scan,
            agent_data_profile_link_to_bigquery=agent_data_profile_link_to_bigquery,
            agent_data_profile_check_scan_exists=agent_data_profile_check_scan_exists,
            agent_data_profile_scan_job_start=agent_data_profile_scan_job_start,
            agent_data_profile_scan_job_state=agent_data_profile_scan_job_state,
            agent_time_delay_create=agent_time_delay_create,
            agent_time_delay_job=agent_time_delay_job,
        )

        # Pass the instantiated agent to the super().__init__
        super().__init__(
            name=name,
            data_profiling_workflow_agent=data_profiling_workflow_agent_instance
        )

    @override
    async def _run_async_impl(self, ctx: InvocationContext) -> AsyncGenerator[Event, None]:
        logger.info(f"[{self.name}] Parent Agent starting a new data profiling task.")

        task_id = str(uuid.uuid4())[:8]

        # --- IMPORTANT CHANGE HERE: Retrieve parameters directly from parent's session state ---
        # These parameters are expected to be set by the Coordinator agent (root_agent)
        # using a dedicated parsing tool *before* delegating to this agent.
        initial_prompt_content = ctx.session.state.get("initial_data_profile_query_param", "")

        scan_details = {
            "data_profile_scan_name": ctx.session.state.get("data_profile_scan_name_param", f"test-scan-{task_id}"),
            "data_profile_display_name": ctx.session.state.get("data_profile_display_name_param", f"Test Data Profile {task_id}"),
            "bigquery_dataset_name": ctx.session.state.get("bigquery_dataset_name_param", "dataform"),
            "bigquery_table_name": ctx.session.state.get("bigquery_table_name_param", "adam_copy"),
        }

        # 1. Create a NEW, ISOLATED SESSION for this data profiling task
        child_session_service = InMemorySessionService()
        child_session_id = f"{ctx.session.user_id}-{ctx.session.id}-dp-{task_id}"

        # Populate the child_session.state directly with parsed details
        # This is CRUCIAL for LlmAgent instruction templating
        initial_child_session_state = {
            "initial_data_profile_query": initial_prompt_content, # Store the original raw query
            "data_profile_scan_name": scan_details["data_profile_scan_name"],
            "data_profile_display_name": scan_details["data_profile_display_name"],
            "bigquery_dataset_name": scan_details["bigquery_dataset_name"],
            "bigquery_table_name": scan_details["bigquery_table_name"],
        }

        child_session = await child_session_service.create_session(
            app_name=APP_NAME,
            user_id=ctx.session.user_id,
            session_id=child_session_id,
            state=initial_child_session_state # Initialize with parsed details
        )
        logger.info(f"[{self.name}] Created isolated child session: {child_session_id} with state: {initial_child_session_state}")


        # 2. Create a NEW RUNNER instance for the DataProfileWorkflowIsolatedSessionAgent
        child_runner = Runner(
            agent=self.data_profiling_workflow_agent,
            app_name=APP_NAME,
            session_service=child_session_service
        )
        
        child_content = types.Content(role='user', parts=[types.Part(text=f"Please initiate the data profile scan using the details already provided.")])

        data_profile_final_result = None
        # 3. Run the DataProfileWorkflowIsolatedSessionAgent workflow independently
        async for event in child_runner.run_async(
            user_id=ctx.session.user_id,
            session_id=child_session_id,
            new_message=child_content
        ):
            logger.info(f"[{self.name}] Event from child workflow [{event.author}]: {event.model_dump_json(indent=2, exclude_none=True)}")
            yield event # Re-yield events from the child to the parent's caller (the Coordinator/UI)

            if event.is_final_response() and event.content and event.content.parts:
                try:
                    # Attempt to parse ONLY if content looks like JSON
                    if event.content.parts[0].text.strip().startswith('{'):
                        data_profile_final_result = json.loads(event.content.parts[0].text)
                        logger.info(f"[{self.name}] Captured final result from child: {json.dumps(data_profile_final_result, indent=2)}")
                    else:
                        logger.warning(f"[{self.name}] Child's final-flagged event was not JSON: {event.content.parts[0].text}")
                except json.JSONDecodeError:
                    logger.error(f"Failed to parse child's final response as JSON: {event.content.parts[0].text}")

        # 4. Store only the necessary final outcome in the parent's session state
        if data_profile_final_result and data_profile_final_result.get("success"):
            child_results = data_profile_final_result.get("results", {})
            ctx.session.state[f"data_profile_task_{task_id}_summary"] = {
                "status": data_profile_final_result.get("status"),
                "scan_name": child_results.get("data_profile_scan_name"),
                "display_name": child_results.get("data_profile_display_name"),
                "dataset_name": child_results.get("bigquery_dataset_name"),
                "table_name": child_results.get("bigquery_table_name"),
                "job_name": child_results.get("data_profile_scan_job_name"),
                "job_state": child_results.get("data_profile_scan_job_state"),
            }
        else:
            ctx.session.state[f"data_profile_task_{task_id}_summary"] = {
                "status": "failed",
                "message": "Child workflow did not return a valid final result or failed.",
                "scan_name": data_profile_final_result.get("results", {}).get("data_profile_scan_name") if data_profile_final_result else None
            }

        # 5. Delete the child session to free up memory
        await child_session_service.delete_session(app_name=APP_NAME, user_id=ctx.session.user_id, session_id=child_session_id)
        logger.info(f"[{self.name}] Deleted isolated child session: {child_session_id}")
        
        # --- CHANGE 2 of 2: REPLACE THE FINAL YIELD BLOCK ---
        # --- OLD CODE TO BE REPLACED ---
        # final_response_for_caller = {
        #     "overall_status": "Data profiling task initiated and completed.",
        #     "task_id": task_id,
        #     "result_summary": ctx.session.state[f"data_profile_task_{task_id}_summary"]
        # }
        # yield Event(
        #     author=self.name,
        #     content=types.Content(role='assistant', parts=[types.Part(text=json.dumps(final_response_for_caller, indent=2))])
        # )
        # logger.info(f"[{self.name}] Parent Agent finished task {task_id}.")
        
        # --- NEW CODE ---
        # 1. Get the summary dictionary we already created.
        summary = ctx.session.state[f"data_profile_task_{task_id}_summary"]

        # 2. Create the BigQuery link.
        project_id = os.getenv("AGENT_ENV_PROJECT_ID")
        bigquery_ui_link = "N/A"
        if project_id and summary.get('dataset_name') and summary.get('table_name'):
            bigquery_ui_link = (
                f"https://console.cloud.google.com/bigquery?project={project_id}"
                f"&ws=!1m5!1m4!4m3!1s{project_id}"
                f"!2s{summary['dataset_name']}"
                f"!3s{summary['table_name']}"
            )

        # 3. Format the summary into a Markdown string.
        markdown_summary = f"""**Data Profile Task Complete**
- **Status:** {summary.get('status', 'Unknown')}
- **Scan Name:** {summary.get('scan_name', 'N/A')}
- **BigQuery Table:** `{summary.get('dataset_name', 'N/A')}.{summary.get('table_name', 'N/A')}`
- **Scan Job Name:** {summary.get('job_name', 'N/A')}
- **Final Job State:** {summary.get('job_state', 'N/A')}
- **BigQuery Console Link:** {bigquery_ui_link}"""

        # 4. Yield the new Markdown string as the final response.
        yield Event(
            author=self.name,
            content=types.Content(role='assistant', parts=[types.Part(text=markdown_summary)])
        )
        logger.info(f"[{self.name}] Parent Agent finished task {task_id}.")