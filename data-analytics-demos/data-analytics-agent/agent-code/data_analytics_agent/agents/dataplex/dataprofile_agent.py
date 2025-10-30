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

# Global instruction
import data_analytics_agent.agents.global_instruction as global_instruction

# Data Profile
import data_analytics_agent.tools.dataplex.dataprofile_tools as dataprofile_tools

# BigQuery
import data_analytics_agent.tools.bigquery.bigquery_table_tools as bigquery_table_tools
import data_analytics_agent.tools.bigquery.bigquery_dataset_tools as bigquery_dataset_tools

# Time Delay
import data_analytics_agent.utils.time_delay.wait_tool as wait_tool


# ADK
from google.adk.agents import LlmAgent
from google.adk.planners import BuiltInPlanner
from google.genai.types import ThinkingConfig
from google.genai import types


logger = logging.getLogger(__name__)


dataprofile_agent_instruction="""You are a specialist **Dataplex Scan Management Agent**. Your purpose is to manage the lifecycle of data profile scans on BigQuery tables. You can create new scans, run existing ones, check their status, and list all available scans. Your primary goal is to help users understand the content and structure of their data by running these automated profiles.

**Your Operational Playbooks (Workflows):**

You must follow these logical workflows to fulfill user requests. Do not call tools out of sequence.

**Workflow 1: Creating and Running a New Data Profile Scan**

This is the most common workflow. Use this when a user says: "profile my table", "create a data scan for `my_table`", or "create and run a data scan for `my_table`".

1.  You **MUST** call `parse_create_and_run_data_profile_scan_params`. Pass the *entire original user prompt* as the `prompt` argument to this tool. 
2.  You **MUST** `transfer_to_agent` to the CreateAndRunDataProfile_Agent agent.

**Workflow 2: Running an Existing Scan**

Use this when a user says, "re-run the profile for `my_table`" or "start the `my_scan_name` scan."

1.  **Gather Information:** You only need the `data_profile_scan_name`.
2.  **Verify Existence:** Before trying to run it, call `exists_data_profile_scan(data_profile_scan_name=...)`. If it returns `false`, inform the user the scan doesn't exist and ask if they want to create it (initiating Workflow 1).
3.  **Start and Monitor:** If the scan exists, proceed directly to **Step 3 and Step 4** of **Workflow 1** (Start the Scan Job and Monitor the Scan Job).

**Workflow 3: Listing Available Scans**

Use this for simple discovery questions like, "what data profile scans exist?" or "list all my scans."

1.  **Execute:** Call `get_data_profile_scans()`.
2.  **Present Results:** Do not just dump the JSON. Summarize the results for the user. For each scan in the `dataScans` list, present the `displayName` and the target table from the `data.resource` field.

**Workflow 4: Listing Available Scans for a table**

Use this for simple discovery questions like, "what data profile scans exist on table" or "list all my profile scans on my tables in dataset."

1.  **Execute:** Verify the dataset name by calling the tool `get_bigquery_dataset_list`. Do not trust the user input, look it up.
2.  **Execute:** Verify the table name by calling the tool `get_bigquery_table_list`. Do not trust the user input, look it up.
3.  **Execute:** Call the tool `get_data_profile_scans_for_table` with the dataset_id and table_name.
4.  **Present Results:** Do not just dump the JSON. Summarize the results for the user. For each scan in the `dataScans` list, present the table name passed to the tool, `name`, `displayName` and `description`.

**General Principles:**

*   **Be Proactive and Guiding:** You are a manager, not just a tool executor. Guide the user through the process. For example: "Okay, I will create a data profile scan for that table. This involves several steps: creating the scan, linking it to BigQuery, running it, and monitoring it to completion. I'll keep you updated."
*   **Handle Job Names:** The `data_profile_scan_job_name` required by `get_data_profile_scan_state` is a *long, full resource path*. It is only returned by the `start_data_profile_scan` tool. You must capture and use it correctly. It is NOT the same as the short `data_profile_scan_name`.
"""


################################################################################################################
# create_and_run_data_profile_scan
################################################################################################################
from typing import AsyncGenerator
from typing_extensions import override

from google.adk.agents import BaseAgent
from google.adk.agents.invocation_context import InvocationContext
from google.adk.events import Event
from google.genai import types

class CreateAndRunDataProfileScanAgentOrchestrator(BaseAgent):
    """
    An orchestrator agent whose purpose is to run the
    create_and_run_data_profile_scan in a non-blocking way and re-yield its events.
    """
    def __init__(self, name: str):
        super().__init__(name=name)

    @override
    async def _run_async_impl(self, ctx: InvocationContext) -> AsyncGenerator[Event, None]:
        logger.info(f"[{self.name}] Delegated to CreateAndRunDataProfileScanAgentOrchestrator to run full data profile workflow.")

        # Extract parameters directly from the InvocationContext.session.state
        data_profile_scan_name = ctx.session.state.get("data_profile_scan_name_param")
        data_profile_display_name = ctx.session.state.get("data_profile_display_name_param")
        bigquery_dataset_name = ctx.session.state.get("bigquery_dataset_name_param")
        bigquery_table_name = ctx.session.state.get("bigquery_table_name_param")
        initial_prompt_content = ctx.session.state.get("initial_data_profile_query_param")

        logger.info(f"CreateAndRunDataProfile_Agent: data_profile_scan_name: {data_profile_scan_name}")
        logger.info(f"CreateAndRunDataProfile_Agent: data_profile_display_name: {data_profile_display_name}")
        logger.info(f"CreateAndRunDataProfile_Agent: bigquery_dataset_name: {bigquery_dataset_name}")
        logger.info(f"CreateAndRunDataProfile_Agent: bigquery_table_name: {bigquery_table_name}")
        logger.info(f"CreateAndRunDataProfile_Agent: initial_prompt_content: {initial_prompt_content}")

        if not all([data_profile_scan_name, data_profile_display_name, bigquery_dataset_name, bigquery_table_name, initial_prompt_content]):
            error_msg = (
                f"[{self.name}] Missing required parameters for data profiling workflow. "
                f"Please ensure all details are provided in the initial prompt."
            )
            logger.error(f"{error_msg} Session state received: {ctx.session.state}")
            yield Event(
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=f"Error: {error_msg}")])
            )
            return

        try:
            # Step 1: Call the async generator function. This returns an async generator object.
            scan_generator = dataprofile_tools.create_and_run_data_profile_scan(
                data_profile_scan_name=data_profile_scan_name,
                data_profile_display_name=data_profile_display_name,
                bigquery_dataset_name=bigquery_dataset_name,
                bigquery_table_name=bigquery_table_name,
                initial_prompt_content=initial_prompt_content,
                event_author_name=self.name)

            # Step 2: Iterate through the async generator using the 'async for' loop.
            # This is the correct and idiomatic way to consume an async generator.
            # It handles the __anext__ calls and StopAsyncIteration automatically.
            async for event in scan_generator:
                # Re-yield all events from the streaming tool
                yield event

        except Exception as e:
            logger.error(f"[{self.name}] An unexpected error occurred while running the synchronous data profile workflow: {e}", exc_info=True)
            yield Event(
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=f"A critical error occurred in the workflow runner: {e}")])
            )
        
        finally:
            # Clean up session state (scratch pad)
            logger.info(f"[{self.name}] Cleaning up data profile workflow state variables from session.")
            keys_to_clear = [
                "data_profile_scan_name_param",
                "data_profile_display_name_param",
                "bigquery_dataset_name_param",
                "bigquery_table_name_param",
                "initial_data_profile_query_param"
            ]
            for key in keys_to_clear:
                # Use pop for safe deletion - it won't raise an error if the key is already gone.
                if ctx.session.state.pop(key, None):
                     logger.debug(f"Cleared state variable: {key}")

        logger.info(f"[{self.name}] Data profile workflow execution completed and all events re-yielded.")


################################################################################################################
# Data Profile Agent
################################################################################################################
agent_create_and_run_dataprofile = CreateAndRunDataProfileScanAgentOrchestrator(
    name="CreateAndRunDataProfile_Agent"
)

def get_dataprofile_agent():
    return LlmAgent(name="DataProfile_Agent",
                             description="Provides the ability to manage individual data profile scan operations.", 
                             instruction=dataprofile_agent_instruction,
                             global_instruction=global_instruction.global_protocol_instruction,
                             tools=[ dataprofile_tools.create_data_profile_scan,
                                     dataprofile_tools.start_data_profile_scan,
                                     dataprofile_tools.exists_data_profile_scan,
                                     dataprofile_tools.get_data_profile_scans,
                                     dataprofile_tools.update_bigquery_table_dataplex_labels,
                                     dataprofile_tools.get_data_profile_scans_for_table,
                                     dataprofile_tools.list_data_profile_scan_jobs,
                                     dataprofile_tools.delete_data_profile_scan_job,
                                     dataprofile_tools.delete_data_profile_scan,
                                     dataprofile_tools.get_data_profile_scan_job_full_details,
                                     dataprofile_tools.get_data_profile_scan_state,
                                     bigquery_table_tools.get_bigquery_table_list,
                                     bigquery_dataset_tools.get_bigquery_dataset_list,
                                     wait_tool.wait_for_seconds,
                                     dataprofile_tools.parse_create_and_run_data_profile_scan_params,
                                   ],
                             sub_agents=[
                                 agent_create_and_run_dataprofile
                             ],
                             model="gemini-2.5-flash",
                             planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                             generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=65536))
