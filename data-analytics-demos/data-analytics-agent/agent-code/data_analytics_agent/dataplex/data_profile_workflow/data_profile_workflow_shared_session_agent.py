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

import asyncio
import os # Import os to get environment variables
import json # Import json to handle debug_info if needed

from google.adk.agents import LlmAgent, BaseAgent, LoopAgent, SequentialAgent
from google.adk.agents.invocation_context import InvocationContext
from google.genai import types
from google.adk.sessions import InMemorySessionService
from google.adk.runners import Runner
from google.adk.events import Event
from pydantic import BaseModel, Field
import data_analytics_agent.dataplex.data_profile as data_profile_tools
import data_analytics_agent.wait_tool as wait_tool_helper
from google.adk.tools.tool_context import ToolContext
import uuid

# Only needed when running as console
# # --- Constants ---
# APP_NAME = "data_profile_app"
# USER_ID = "data_profile_user"  # Changed to be more generic for a direct run
# SESSION_ID = str(uuid.uuid4())[:8]  # Unique identifier for this specific profiling task
GEMINI_MODEL = "gemini-2.5-flash"

# from dotenv import load_dotenv
# load_dotenv()  # Load environment variables

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# This will be the FINAL output schema for the DataProfileWorkflowSharedSessionAgent (the orchestrator)
class DataProfilingWorkflowOutput(BaseModel):
    status: str = Field(description="Overall status: 'success' or 'failed'")
    tool_name: str = Field(description="Name of the tool/workflow that produced this result.")
    query: Optional[str] = Field(None, description="The query that initiated the workflow (if applicable).")
    messages: list[str] = Field(description="List of informational messages during processing.")
    results: Optional[dict] = Field(None, description="Detailed results of the data profile scan, if successful.")
    success: bool = Field(description="Did the overall workflow succeed?")


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
    data_profile_scan_job_state: str = Field(
        description="The state of the scan job (e.g., SUCCEEDED, FAILED, RUNNING)."
    )
    success: bool = Field(description="True if the job completed successfully, False otherwise or still running.")


class TimeDelayOutput(BaseModel):
    success: bool = Field(description="True if the delay completed successfully.")


class DataProfileWorkflowSharedSessionAgent(BaseAgent):
    """
    Agent that creates and monitors Dataplex Data Profiles

    This agent orchestrates a sequence of LLM agents create to:
    - **Step 1: Create the Scan Definition:**
    - **Step 2: Link the Scan to BigQuery:**
    - **Step 3: Start the Scan Job:**
    - **Step 4: Monitor the Scan Job:**
    """

    # Declare the agents pass to the class
    agent_data_profile_create_scan: LlmAgent  # Creates the scan and returns the scan id
    agent_data_profile_link_to_bigquery: LlmAgent  # Links the scan id to BigQuery, returns nothing
    agent_data_profile_check_scan_exists: LlmAgent  # Tests to see if the scan exists (it can take a few seconds), return nothing
    agent_data_profile_scan_job_start: LlmAgent  # Starts the scan job and returns the scan job id
    agent_data_profile_scan_job_state: LlmAgent  # Tests the status of the scan job, returns when complete
    agent_time_delay_create: LlmAgent  # Sleeps for {x} seconds
    agent_time_delay_job: LlmAgent  # Sleeps for {x} seconds

    loop_wait_for_scan_create: LoopAgent
    loop_wait_for_scan_complete: LoopAgent

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
        Initializes the DataProfileWorkflowSharedSessionAgent.
        """

        # Agents that will Loop and Wait for completion
        loop_wait_for_scan_create = LoopAgent(
            name="WaitForScanCreate", sub_agents=[agent_data_profile_check_scan_exists, agent_time_delay_create], max_iterations=10
        )

        loop_wait_for_scan_complete = LoopAgent(
            name="WaitForScanComplete", sub_agents=[agent_data_profile_scan_job_state, agent_time_delay_job], max_iterations=50
        )

        # Sub-Agents
        sub_agents_list = [
            agent_data_profile_create_scan,
            loop_wait_for_scan_create,  # Use the internal LoopAgent instance here
            agent_data_profile_scan_job_start,
            loop_wait_for_scan_complete,  # Use the internal LoopAgent instance here
            agent_data_profile_link_to_bigquery,  # Link to BQ moved to the end
        ]

        # Every agent needs to be here (including internal Loop agents)
        super().__init__(
            name=name,
            # Create
            agent_data_profile_create_scan=agent_data_profile_create_scan,
            # Link to BQ
            agent_data_profile_link_to_bigquery=agent_data_profile_link_to_bigquery,
            # Create "Wait" Loop
            loop_wait_for_scan_create=loop_wait_for_scan_create,  # Pass internal instance
            agent_data_profile_check_scan_exists=agent_data_profile_check_scan_exists,
            agent_time_delay_create=agent_time_delay_create,
            # Start "Scan" Job
            agent_data_profile_scan_job_start=agent_data_profile_scan_job_start,
            # Scan Job "Wait" Loop
            loop_wait_for_scan_complete=loop_wait_for_scan_complete,  # Pass internal instance
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
            DataProfilingWorkflowOutput: A Pydantic model containing the workflow status and results.
        """
        logger.info(f"[{self.name}] Starting Data Profile Scan workflow.")

        # Initialize the response structure for the final output
        response = DataProfilingWorkflowOutput(
            status="success",
            tool_name="data_profile_scan_workflow",
            query=None,
            messages=[],
            results={
                "data_profile_scan_name": None,
                "data_profile_display_name": None,
                "bigquery_dataset_name": None,
                "bigquery_table_name": None,
                "data_profile_scan_job_name": None,
                "data_profile_scan_job_state": None,
            },
            success=True,  # Overall workflow success status
        )

        # Retrieve parameters directly from the main session state (no parent/child sessions)
        # Use _param suffix as per session_tools.py
        response.query = ctx.session.state.get("initial_data_profile_query_param", "")

        # Populate initial scan details from session state using _param suffix
        response.results["data_profile_scan_name"] = ctx.session.state.get("data_profile_scan_name_param")
        response.results["data_profile_display_name"] = ctx.session.state.get("data_profile_display_name_param")
        response.results["bigquery_dataset_name"] = ctx.session.state.get("bigquery_dataset_name_param")
        response.results["bigquery_table_name"] = ctx.session.state.get("bigquery_table_name_param")

        # Helper function for consistent final output message
        def _create_summary_event(current_response: DataProfilingWorkflowOutput) -> Event:
            project_id = os.getenv("AGENT_ENV_PROJECT_ID")
            bigquery_ui_link = "N/A"
            if project_id and current_response.results.get('bigquery_dataset_name') and current_response.results.get('bigquery_table_name'):
                # Constructing the BigQuery console URL
                bigquery_ui_link = (
                    f"https://console.cloud.google.com/bigquery?project={project_id}"
                    f"&ws=!1m5!1m4!4m3!1s{project_id}"
                    f"!2s{current_response.results['bigquery_dataset_name']}"
                    f"!3s{current_response.results['bigquery_table_name']}"
                )

            # Using a multi-line f-string for Markdown formatting
            final_summary_message = f"""**Data Profile Workflow finished with status: {current_response.status.upper()}**
**Overall Success:** {'Yes' if current_response.success else 'No'}

### Workflow Details
- **Scan Name:** {current_response.results.get('data_profile_scan_name', 'N/A')}
- **Display Name:** {current_response.results.get('data_profile_display_name', 'N/A')}
- **BigQuery Dataset:** {current_response.results.get('bigquery_dataset_name', 'N/A')}
- **BigQuery Table:** {current_response.results.get('bigquery_table_name', 'N/A')}
- **Scan Job Name:** {current_response.results.get('data_profile_scan_job_name', 'N/A')}
- **Final Scan Job State:** {current_response.results.get('data_profile_scan_job_state', 'N/A')}
- **BigQuery Console Link:** {bigquery_ui_link}

### Messages from Workflow Steps
"""
            if current_response.messages:
                messages_list = "\n".join([f"- {msg}" for msg in current_response.messages])
                final_summary_message += messages_list
            else:
                final_summary_message += "No detailed messages from steps."
            
            return Event(
                author=self.name,
                content=types.Content(role="assistant", parts=[types.Part(text=final_summary_message)]),
            )

        # Yield an initial message to show activity
        yield Event(
            author=self.name,
            content=types.Content(
                role="assistant",
                parts=[
                    types.Part(
                        text=f"Initiating data profile scan workflow based on your request for table '{response.results['bigquery_dataset_name']}.{response.results['bigquery_table_name']}'."
                    )
                ],
            ),
        )

        ########################################################
        # STEP: agent_data_profile_create_scan
        ########################################################
        logger.info(f"[{self.name}] Running Agent: agent_data_profile_create_scan")
        async for event in self.agent_data_profile_create_scan.run_async(ctx):
            logger.info(
                f"[{self.name}] Internal event from agent_data_profile_create_scan: {event.model_dump_json(indent=2, exclude_none=True)}"
            )
            yield event  # Re-yield all events from the LlmAgent for UI visibility

        agent_data_profile_create_scan_result: Optional[dict] = ctx.session.state.get(
            "agent_data_profile_create_scan"
        )
        logger.info(f"[{self.name}] agent_data_profile_create_scan_result: {agent_data_profile_create_scan_result}")

        if not agent_data_profile_create_scan_result or not agent_data_profile_create_scan_result.get("success"):
            logger.info(f"Failed: agent_data_profile_create_scan")
            response.status = "failed"
            response.success = False
            scan_name = (
                agent_data_profile_create_scan_result.get("data_profile_scan_name")
                if agent_data_profile_create_scan_result
                else "Unknown"
            )
            response.messages.append(f"Failed to create the data profile scan: {scan_name}")
            # Update results with any partial info before failing
            if agent_data_profile_create_scan_result:
                response.results.update(
                    {
                        "data_profile_scan_name": agent_data_profile_create_scan_result.get(
                            "data_profile_scan_name"
                        ),
                        "data_profile_display_name": agent_data_profile_create_scan_result.get(
                            "data_profile_display_name"
                        ),
                        "bigquery_dataset_name": agent_data_profile_create_scan_result.get(
                            "bigquery_dataset_name"
                        ),
                        "bigquery_table_name": agent_data_profile_create_scan_result.get("bigquery_table_name"),
                    }
                )
            yield _create_summary_event(response) # Use helper for consistent output
            return  # Stop processing if initial story failed
        else:
            logger.info(f"agent_data_profile_create_scan: SUCCESS")
            success_message = f"Successfully created data profile scan definition: {agent_data_profile_create_scan_result.get('data_profile_scan_name')}. Now waiting for it to register."
            response.messages.append(success_message)
            # Ensure results are updated based on actual successful creation
            response.results.update(
                {
                    "data_profile_scan_name": agent_data_profile_create_scan_result.get("data_profile_scan_name"),
                    "data_profile_display_name": agent_data_profile_create_scan_result.get(
                        "data_profile_display_name"
                    ),
                    "bigquery_dataset_name": agent_data_profile_create_scan_result.get("bigquery_dataset_name"),
                    "bigquery_table_name": agent_data_profile_create_scan_result.get("bigquery_table_name"),
                }
            )
            # Explicitly yield a progress message for the UI
            yield Event(
                author=self.name,
                content=types.Content(role="assistant", parts=[types.Part(text=success_message)]),
            )

        ########################################################
        # STEP: loop_wait_for_scan_create
        ########################################################
        logger.info(f"[{self.name}] Running Agent: loop_wait_for_scan_create")
        async for event in self.loop_wait_for_scan_create.run_async(ctx):
            logger.info(
                f"[{self.name}] Internal event from loop_wait_for_scan_create: {event.model_dump_json(indent=2, exclude_none=True)}"
            )
            yield event  # Re-yield events from the loop agent, including time delay messages

        loop_wait_for_scan_create_result: Optional[dict] = ctx.session.state.get(
            "agent_loop_wait_for_scan_create"
        )  # Key matches output_key of check_scan_exists
        logger.info(f"[{self.name}] loop_wait_for_scan_create_result: {loop_wait_for_scan_create_result}")

        if not loop_wait_for_scan_create_result or not loop_wait_for_scan_create_result.get("success"):
            logger.info(f"Failed to wait for data profile to create.")
            response.status = "failed"
            response.success = False
            error_message = f"Failed to wait for the scan '{response.results['data_profile_scan_name']}' to be registered. It might be taking too long or encountered an issue during creation."
            response.messages.append(error_message)
            yield _create_summary_event(response) # Use helper for consistent output
            return
        else:
            logger.info(f"loop_wait_for_scan_create: SUCCESS")
            success_message = f"Data profile scan '{response.results['data_profile_scan_name']}' is now registered and ready."
            response.messages.append(success_message)
            # Explicitly yield a progress message for the UI
            yield Event(
                author=self.name,
                content=types.Content(role="assistant", parts=[types.Part(text=success_message)]),
            )

        ########################################################
        # STEP: agent_data_profile_scan_job_start
        ########################################################
        logger.info(f"[{self.name}] Running Agent: agent_data_profile_scan_job_start")
        async for event in self.agent_data_profile_scan_job_start.run_async(ctx):
            logger.info(
                f"[{self.name}] Internal event from agent_data_profile_scan_job_start: {event.model_dump_json(indent=2, exclude_none=True)}"
            )
            yield event

        agent_data_profile_scan_job_start_result: Optional[dict] = ctx.session.state.get(
            "agent_data_profile_scan_job_start"
        )
        logger.info(
            f"[{self.name}] agent_data_profile_scan_job_start_result: {agent_data_profile_scan_job_start_result}"
        )

        if not agent_data_profile_scan_job_start_result or not agent_data_profile_scan_job_start_result.get("success"):
            logger.info(f"Failed: agent_data_profile_scan_job_start")
            response.status = "failed"
            response.success = False
            error_message = (
                f"Failed to start the scan job for data profile scan: {response.results['data_profile_scan_name']}"
            )
            response.messages.append(error_message)
            if agent_data_profile_scan_job_start_result:
                response.results["data_profile_scan_job_name"] = agent_data_profile_scan_job_start_result.get(
                    "data_profile_scan_job_name"
                )
            yield _create_summary_event(response) # Use helper for consistent output
            return
        else:
            logger.info(f"agent_data_profile_scan_job_start: SUCCESS")
            success_message = f"Successfully started the data profile scan job: {agent_data_profile_scan_job_start_result.get('data_profile_scan_job_name')}. Monitoring its progress."
            response.messages.append(success_message)
            response.results["data_profile_scan_job_name"] = agent_data_profile_scan_job_start_result.get(
                "data_profile_scan_job_name"
            )

            # PROMOTE data_profile_scan_job_name to root of session state for next step's instruction templating
            # This key is used without _param suffix by agent_data_profile_scan_job_state_instruction
            ctx.session.state["current_data_profile_scan_job_name"] = (
                agent_data_profile_scan_job_start_result.get("data_profile_scan_job_name")
            )

            # Explicitly yield a progress message for the UI
            yield Event(
                author=self.name,
                content=types.Content(role="assistant", parts=[types.Part(text=success_message)]),
            )

        ########################################################
        # STEP: loop_wait_for_scan_complete
        ########################################################
        logger.info(f"[{self.name}] Running Agent: loop_wait_for_scan_complete")
        async for event in self.loop_wait_for_scan_complete.run_async(ctx):
            logger.info(
                f"[{self.name}] Internal event from loop_wait_for_scan_complete: {event.model_dump_json(indent=2, exclude_none=True)}"
            )
            yield event  # Re-yield events from the loop agent, including time delay messages

        loop_wait_for_scan_complete_result: Optional[dict] = ctx.session.state.get(
            "agent_loop_wait_for_scan_complete"
        )  # Key matches output_key of check_scan_job_state
        logger.info(f"[{self.name}] loop_wait_for_scan_complete_result: {loop_wait_for_scan_complete_result}")

        if not loop_wait_for_scan_complete_result or not loop_wait_for_scan_complete_result.get("success"):
            logger.info(f"Failed: loop_wait_for_scan_complete")
            response.status = "failed"
            response.success = False
            job_name = response.results.get("data_profile_scan_job_name")
            job_state = (
                loop_wait_for_scan_complete_result.get("data_profile_scan_job_state")
                if loop_wait_for_scan_complete_result
                else "Unknown"
            )
            error_message = f"Data profiling job '{job_name}' failed or was cancelled. Final state: {job_state}"
            response.messages.append(error_message)
            if loop_wait_for_scan_complete_result:
                response.results["data_profile_scan_job_state"] = loop_wait_for_scan_complete_result.get(
                    "data_profile_scan_job_state"
                )
            yield _create_summary_event(response) # Use helper for consistent output
            return
        else:
            logger.info(f"loop_wait_for_scan_complete: SUCCESS")
            success_message = f"Data profiling job '{response.results['data_profile_scan_job_name']}' completed successfully with state: {loop_wait_for_scan_complete_result.get('data_profile_scan_job_state')}."
            response.messages.append(success_message)
            response.results["data_profile_scan_job_state"] = loop_wait_for_scan_complete_result.get(
                "data_profile_scan_job_state"
            )
            # Explicitly yield a progress message for the UI
            yield Event(
                author=self.name,
                content=types.Content(role="assistant", parts=[types.Part(text=success_message)]),
            )

        ########################################################
        # STEP: agent_data_profile_link_to_bigquery
        ########################################################
        logger.info(f"[{self.name}] Running Agent: agent_data_profile_link_to_bigquery")
        async for event in self.agent_data_profile_link_to_bigquery.run_async(ctx):
            logger.info(
                f"[{self.name}] Internal event from agent_data_profile_link_to_bigquery: {event.model_dump_json(indent=2, exclude_none=True)}"
            )
            yield event

        agent_data_profile_link_to_bigquery_result: Optional[dict] = ctx.session.state.get(
            "agent_data_profile_link_to_bigquery"
        )
        logger.info(
            f"[{self.name}] agent_data_profile_link_to_bigquery_result: {agent_data_profile_link_to_bigquery_result}"
        )

        if not agent_data_profile_link_to_bigquery_result or not agent_data_profile_link_to_bigquery_result.get(
            "success"
        ):
            logger.info(f"Failed: agent_data_profile_link_to_bigquery")
            response.status = "failed"
            response.success = False
            scan_name = (
                agent_data_profile_link_to_bigquery_result.get("dataplex_scan_name")
                if agent_data_profile_link_to_bigquery_result
                else "Unknown"
            )
            error_message = f"Failed to link the data profile scan '{scan_name}' to BigQuery."
            response.messages.append(error_message)
            yield _create_summary_event(response) # Use helper for consistent output
            return
        else:
            logger.info(f"agent_data_profile_link_to_bigquery: SUCCESS")
            success_message = (
                f"Successfully linked the data profile scan to BigQuery. Results should now be visible in the BigQuery console."
            )
            response.messages.append(success_message)
            yield Event(  # Explicitly yield a progress message for the UI
                author=self.name,
                content=types.Content(role="assistant", parts=[types.Part(text=success_message)]),
            )

        # Done!
        logger.info(f"[{self.name}] Workflow finished.")
        # The overall success is determined by the last step's success
        # If any step before this failed, response.success would already be False
        # If we reached here, it's a success
        response.success = True
        response.status = "success"

        yield _create_summary_event(response) # Use helper for consistent output
        return


################################################################################################
# 1. agent_data_profile_create_scan
################################################################################################
async def agent_data_profile_create_scan_tool(
    data_profile_scan_name: str, data_profile_display_name: str, bigquery_dataset_name: str, bigquery_table_name: str
) -> dict:
    """
    Creates data data profile scan.
    """
    print("BEGIN: agent_data_profile_create_scan_tool")
    result = await asyncio.to_thread(
        data_profile_tools.create_data_profile_scan,
        data_profile_scan_name,
        data_profile_display_name,
        bigquery_dataset_name,
        bigquery_table_name,
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
        "success": success,
    }
    return response


# UPDATED: Use _param suffix in instruction template
agent_data_profile_create_scan_instruction = """Create the Scan Definition:
1.  Call `agent_data_profile_create_scan_tool(data_profile_scan_name="{{data_profile_scan_name_param}}", data_profile_display_name="{{data_profile_display_name_param}}", bigquery_dataset_name="{{bigquery_dataset_name_param}}", bigquery_table_name="{{bigquery_table_name_param}}")` using the parameters from the current session state.
2.  After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `agent_data_profile_create_scan_tool`.
"""

agent_data_profile_create_scan = LlmAgent(
    name="DataProfileCreateScan",
    model=GEMINI_MODEL,
    instruction=agent_data_profile_create_scan_instruction,
    input_schema=None,
    output_schema=CreateScanOutput,
    output_key="agent_data_profile_create_scan",
    tools=[agent_data_profile_create_scan_tool],
)


################################################################################################
# 2. agent_data_profile_link_to_bigquery
################################################################################################
async def agent_data_profile_link_to_bigquery_tool(
    dataplex_scan_name: str, bigquery_dataset_name: str, bigquery_table_name: str
) -> dict:
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
        "success": success,
    }
    return response


# UPDATED: Use _param suffix in instruction template
agent_data_profile_link_to_bigquery_instruction = """Link the Scan to BigQuery:
1.  Call `agent_data_profile_link_to_bigquery_tool(dataplex_scan_name="{{data_profile_scan_name_param}}", bigquery_dataset_name="{{bigquery_dataset_name_param}}", bigquery_table_name="{{bigquery_table_name_param}}")` using the parameters from the current session state.
2.  After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `agent_data_profile_link_to_bigquery_tool`.
"""

agent_data_profile_link_to_bigquery = LlmAgent(
    name="DataProfileLinkToBigQuery",
    model=GEMINI_MODEL,
    instruction=agent_data_profile_link_to_bigquery_instruction,
    input_schema=None,
    output_schema=LinkToBigQueryOutput,
    output_key="agent_data_profile_link_to_bigquery",
    tools=[agent_data_profile_link_to_bigquery_tool],
)


################################################################################################
# 3. agent_data_profile_check_scan_exists
################################################################################################
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
            tool_context.actions.escalate = True  # Exit the Loop Agent if scan exists
    response = {"success": success}
    return response


# UPDATED: Use _param suffix in instruction template
agent_data_profile_check_scan_exists_instruction = """Checks to see if a data profile scan exists on a table.
1.  Call `agent_data_profile_check_scan_exists_tool(data_profile_scan_name="{{data_profile_scan_name_param}}")` using the scan name from the current session state.
2.  After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `agent_data_profile_check_scan_exists_tool`.
"""

agent_data_profile_check_scan_exists = LlmAgent(
    name="DataProfileCheckScanExists",
    model=GEMINI_MODEL,
    instruction=agent_data_profile_check_scan_exists_instruction,
    input_schema=None,
    output_schema=CheckScanExistsOutput,
    output_key="agent_loop_wait_for_scan_create",  # This key is read by the LoopAgent
    tools=[agent_data_profile_check_scan_exists_tool],
)


################################################################################################
# 4. agent_data_profile_scan_job_start
################################################################################################
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
    response = {"data_profile_scan_job_name": data_profile_scan_job_name, "success": success}
    return response


# UPDATED: Use _param suffix in instruction template
agent_data_profile_scan_job_start_instruction = """Starts a Data Profile Job Scan.
1.  Call `agent_data_profile_scan_job_start_tool(data_profile_scan_name="{{data_profile_scan_name_param}}")` using the scan name from the current session state.
2.  After the tool returns, immediately respond using the `set_model_response` tool. The arguments for `set_model_response` MUST be the exact dictionary result returned by `agent_data_profile_scan_job_start_tool`.
"""

agent_data_profile_scan_job_start = LlmAgent(
    name="DataProfileStartScanJob",
    model=GEMINI_MODEL,
    instruction=agent_data_profile_scan_job_start_instruction,
    input_schema=None,
    output_schema=StartScanJobOutput,
    output_key="agent_data_profile_scan_job_start",
    tools=[agent_data_profile_scan_job_start_tool],
)


################################################################################################
# 6. agent_data_profile_scan_job_state
################################################################################################
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
            tool_context.actions.escalate = True  # Exit the Loop Agent if job is in a final state
    response = {"data_profile_scan_job_state": data_profile_scan_job_state, "success": success}
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
    output_key="agent_loop_wait_for_scan_complete",  # This key is read by the LoopAgent
    tools=[agent_data_profile_scan_job_state_tool],
)


################################################################################################
# Helper: agent_time_delay
################################################################################################
async def agent_time_delay_tool(duration: int) -> dict:
    """
    Instructs the agent's execution environment to pause for the specified number of seconds.
    """
    print(f"BEGIN: wait_for_seconds (duration: {duration})")
    result = await asyncio.to_thread(wait_tool_helper.wait_for_seconds, duration)
    print(f"END: wait_for_seconds")
    success = False
    if result["status"] == "success":
        success = True
    response = {"success": success}
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
    tools=[agent_time_delay_tool],
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
    tools=[agent_time_delay_tool],
)


# # --- Create the custom agent instance ---
# data_profiling_agent = DataProfileWorkflowSharedSessionAgent(
#     name="DataProfileWorkflowSharedSessionAgent",  # Now the top-level agent
#     agent_data_profile_create_scan=agent_data_profile_create_scan,
#     agent_data_profile_link_to_bigquery=agent_data_profile_link_to_bigquery,
#     agent_data_profile_check_scan_exists=agent_data_profile_check_scan_exists,
#     agent_data_profile_scan_job_start=agent_data_profile_scan_job_start,
#     agent_data_profile_scan_job_state=agent_data_profile_scan_job_state,
#     agent_time_delay_create=agent_time_delay_create,
#     agent_time_delay_job=agent_time_delay_job,
# )

################################################################################################
# Only needed when running in console
################################################################################################
# # --- Constants ---
# APP_NAME = "data_profile_app"
# USER_ID = "data_profile_user"  # Changed to be more generic for a direct run

# from dotenv import load_dotenv
# load_dotenv()  # Load environment variables


# # --- Setup Runner and Session ---
# # Use a consistent session ID for demonstration purposes, or generate if needed.
# # Generate a new UUID for a fresh session each run for distinct scan names
# current_session_id = str(uuid.uuid4())[:8]

# # Define initial state with required parameters for the DataProfileWorkflowSharedSessionAgent
# INITIAL_STATE = {
#     "initial_data_profile_query_param": "Please create a data profile for the 'adam_copy' table in the 'dataform' BigQuery dataset.",
#     "data_profile_scan_name_param": f"my-test-scan-{current_session_id}",
#     "data_profile_display_name_param": f"My Test Data Profile {current_session_id}",
#     "bigquery_dataset_name_param": "dataform",
#     "bigquery_table_name_param": "adam_copy",
# }


# async def setup_session_and_runner():
#     session_service = InMemorySessionService()
#     session = await session_service.create_session(
#         app_name=APP_NAME, user_id=USER_ID, session_id=current_session_id, state=INITIAL_STATE
#     )
#     logger.info(f"Initial session state: {session.state}")
#     runner = Runner(
#         agent=data_profiling_agent,  # Pass the custom orchestrator agent directly
#         app_name=APP_NAME,
#         session_service=session_service,
#     )
#     return session_service, runner


# # --- Function to Interact with the Agent ---
# async def call_agent_async(user_input_message: str):
#     """
#     Sends an input message to the agent and runs the workflow.
#     """
#     global current_session_id  # Use global to allow modification of the session_id for subsequent runs

#     # Re-generate session ID and update INITIAL_STATE for a fresh run
#     current_session_id = str(uuid.uuid4())[:8]
#     INITIAL_STATE["data_profile_scan_name_param"] = f"my-test-scan-{current_session_id}"
#     INITIAL_STATE["data_profile_display_name_param"] = f"My Test Data Profile {current_session_id}"

#     session_service, runner = await setup_session_and_runner()

#     current_session = await session_service.get_session(
#         app_name=APP_NAME, user_id=USER_ID, session_id=current_session_id
#     )
#     if not current_session:
#         logger.error("Session not found!")
#         return

#     # Update initial_data_profile_query in session state if a new user input is provided
#     current_session.state["initial_data_profile_query_param"] = user_input_message
#     logger.info(f"Updated session state query to: {user_input_message}")

#     content = types.Content(role="user", parts=[types.Part(text=user_input_message)])
#     events = runner.run_async(user_id=USER_ID, session_id=current_session_id, new_message=content)

#     final_response = "No final response captured."
#     async for event in events:
#         if event.is_final_response() and event.content and event.content.parts:
#             logger.info(f"Potential final response from [{event.author}]: {event.content.parts[0].text}")
#             final_response = event.content.parts[0].text

#     print("\n--- Agent Interaction Result ---")
#     print("Agent Final Response: ", final_response)

#     final_session = await session_service.get_session(
#         app_name=APP_NAME, user_id=USER_ID, session_id=current_session_id
#     )
#     print("Final Session State:")
#     print(json.dumps(final_session.state, indent=2))
#     print("-------------------------------\n")

#     # Clean up the session after completion
#     await session_service.delete_session(app_name=APP_NAME, user_id=USER_ID, session_id=current_session_id)
#     logger.info(f"Deleted session: {current_session_id}")


# # --- Run the Agent ---
# if __name__ == "__main__":  # Ensures this runs only when script is executed directly
#     print("Executing using 'asyncio.run()' (for standard Python scripts)...")
#     try:
#         # This creates an event loop, runs your async function, and closes the loop.
#         asyncio.run(
#             call_agent_async("Initiate a data profile scan for the `dataform.adam_copy` BigQuery table.")
#         )
#     except Exception as e:
