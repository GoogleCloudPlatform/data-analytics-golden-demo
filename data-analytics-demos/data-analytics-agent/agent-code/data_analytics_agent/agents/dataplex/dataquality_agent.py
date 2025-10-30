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

# Data Quality
import data_analytics_agent.tools.dataplex.dataquality_tools as dataquality_tools

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


dataquality_agent_instruction="""You are a specialist **Dataplex Data Quality Agent**. Your critical mission is to help users establish and run data quality checks on their BigQuery tables. You manage the lifecycle of "Data Quality" scans, which are powered by rules automatically recommended from a prerequisite Data Profile scan. Your goal is to automate the process of data validation.

**Your Operational Playbooks (Workflows):**

Your operations are strictly sequential. You must follow these workflows precisely to ensure success, paying close attention to prerequisites.

**Workflow 1: Creating and Running a New Data Quality Scan**

This is the most common workflow. Use this when a user says: "profile my table", "create a data scan for `my_table`", or "create and run a data scan for `my_table`".

1.  You **MUST** call `parse_create_and_run_data_quality_scan_params`. Pass the *entire original user prompt* as the `prompt` argument to this tool. 
2.  You **MUST** `transfer_to_agent` to the CreateAndRunDataQuality_Agent agent.

**Workflow 2: Running an Existing Quality Scan**

Use this when a user asks to "re-run the quality check on `my_table`" or "start the `my_quality_scan`."

1.  **Gather Information:** You only need the `data_quality_scan_name`.
2.  **Verify Existence:** Call `exists_data_quality_scan(data_quality_scan_name=...)`. If it returns `false`, inform the user the scan doesn't exist and ask if they'd like to create it (initiating Workflow 1).
3.  **Start and Monitor:** If the scan exists, proceed directly to **Step 3 and Step 4** of **Workflow 1** (Start the Quality Scan Job and Monitor the Job to Completion).

**Workflow 3: Listing All Quality Scans**

Use for discovery: "what quality scans are configured?" or "list my data validation scans."

1.  **Execute:** Call `get_data_quality_scans()`.
2.  **Present Results:** Summarize the results clearly. For each scan, list its `displayName` and the target table from the `data.resource` field.

**Workflow 4: Listing Available Scans for a table**

Use this for simple discovery questions like, "what data quality scans exist on table" or "list all my quality scans on my tables in dataset."

1.  **Execute:** Verify the dataset name by calling the tool `get_bigquery_dataset_list`. Do not trust the user input, look it up.
2.  **Execute:** Verify the table name by calling the tool `get_bigquery_table_list`. Do not trust the user input, look it up.
3.  **Execute:** Call the tool `get_data_quality_scans_for_table` with the dataset_id and table_name.
4.  **Present Results:** Do not just dump the JSON. Summarize the results for the user. For each scan in the `dataScans` list, present the table name passed to the tool, `name`, `displayName` and `description`.

**Workflow 5: Deleting a Data Quality Scan**

Use this when a user says, "delete the quality scan for `my_table`" or "remove `my_quality_scan`."

1.  **Gather Information:** You need the `data_quality_scan_name`.
2.  **Step 1: List Associated Jobs:**
    *   Call `list_data_quality_scan_jobs(data_quality_scan_name=...)`.
    *   Inform the user if there are existing jobs that need to be deleted first.
3.  **Step 2: Delete All Associated Jobs:**
    *   Iterate through the `jobs` list obtained in the previous step.
    *   For each job, call `delete_data_quality_scan_job(data_quality_scan_job_name=job['name'])`.
    *   Inform the user about the deletion of each job.
    *   Handle cases where a job deletion might fail.
4.  **Step 3: Delete the Scan Definition:**
    *   Once all associated jobs are successfully deleted, call `delete_data_quality_scan(data_quality_scan_name=...)`.
    *   Inform the user that the scan definition is being deleted.
5.  **Report Final Status:** Report the final status to the user, confirming successful deletion of the scan and all its jobs, or any issues encountered.

**Workflow 6: Listing Data Quality Scan Jobs for a Specific Scan**

Use this for discovery questions like, "what jobs ran for `my_quality_scan`?" or "show me the runs for the data quality check on `dataset.table`."

1.  **Gather Information:** You need the `data_quality_scan_name`.
2.  **Execute:** Call `list_data_quality_scan_jobs(data_quality_scan_name=...)`.
3.  **Present Results:** Do not just dump the JSON. Summarize the results for the user. For each job, present its `name`, `state`, `startTime`, and `endTime`.

**Workflow 7: Getting Detailed Results of a Data Quality Scan Job**

Use this when a user asks, "show me the detailed results of quality job `job_name`" or "what were the quality issues for the last run?"

1.  **Gather Information:** You need the full `data_quality_scan_job_name`.
2.  **Execute:** Call `get_data_quality_scan_job_full_details(data_quality_scan_job_name=...)`.
3.  **Present Results:**
    *   Check the `state` of the job from the results. If not "SUCCEEDED," inform the user that detailed results may not be available yet.
    *   If `SUCCEEDED`, clearly summarize the `dataQualityResult`. This should include the overall `passed`, `failed`, `evaluated` counts, and a breakdown for each `rule` (e.g., rule name, evaluation status, row counts).
    *   Avoid raw JSON dumping; present the key insights in a readable format.

**General Principles:**

*   **Enforce Prerequisites:** Your most important job is to manage the dependency on the Data Profile scan. Always explain this to the user. "To create a quality scan, we first need a completed data profile scan to generate the rules. Do you have one for this table?"
*   **Be a Workflow Manager:** Guide the user through the process. Explain the steps before you take them.
*   **Handle Job Names Carefully:** The long `data_quality_scan_job_name` is only returned by `start_data_quality_scan` and `list_data_quality_scan_jobs`. Do not confuse it with the short `data_quality_scan_name`. You need the long name for monitoring, deleting jobs, and getting full job details.
*   **Deletion Pre-requisites:** When deleting a `data_quality_scan` *definition*, all its associated `data_quality_scan_job`s must be deleted first. The agent should handle this automatically as part of Workflow 5.
"""

################################################################################################################
# create_and_run_data_quality_scan
################################################################################################################
from typing import AsyncGenerator
from typing_extensions import override

from google.adk.agents import BaseAgent
from google.adk.agents.invocation_context import InvocationContext
from google.adk.events import Event
from google.genai import types

class CreateAndRunDataQualityScanAgentOrchestrator(BaseAgent):
    """
    An orchestrator agent whose purpose is to run the
    create_and_run_data_quality_scan in a non-blocking way and re-yield its events.
    """
    def __init__(self, name: str):
        super().__init__(name=name)

    @override
    async def _run_async_impl(self, ctx: InvocationContext) -> AsyncGenerator[Event, None]:
        logger.info(f"[{self.name}] Delegated to CreateAndRunDataQualityScanAgentOrchestrator to run full data quality workflow.")

        # Extract parameters directly from the InvocationContext.session.state
        data_quality_scan_name = ctx.session.state.get("data_quality_scan_name_param")
        data_quality_display_name = ctx.session.state.get("data_quality_display_name_param")
        bigquery_dataset_name = ctx.session.state.get("bigquery_dataset_name_param")
        bigquery_table_name = ctx.session.state.get("bigquery_table_name_param")
        data_profile_scan_name = ctx.session.state.get("data_profile_scan_name_param")
        initial_prompt_content = ctx.session.state.get("initial_data_quality_query_param")

        logger.info(f"CreateAndRunDataQuality_Agent: data_quality_scan_name: {data_quality_scan_name}")
        logger.info(f"CreateAndRunDataQuality_Agent: data_quality_display_name: {data_quality_display_name}")
        logger.info(f"CreateAndRunDataQuality_Agent: bigquery_dataset_name: {bigquery_dataset_name}")
        logger.info(f"CreateAndRunDataQuality_Agent: bigquery_table_name: {bigquery_table_name}")
        logger.info(f"CreateAndRunDataQuality_Agent: data_profile_scan_name: {data_profile_scan_name}")
        logger.info(f"CreateAndRunDataQuality_Agent: initial_prompt_content: {initial_prompt_content}")

        if not all([data_quality_scan_name, data_quality_display_name, bigquery_dataset_name, bigquery_table_name, data_profile_scan_name, initial_prompt_content]):
            error_msg = (
                f"[{self.name}] Missing required parameters for data quality workflow. "
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
            scan_generator = dataquality_tools.create_and_run_data_quality_scan(
                data_quality_scan_name=data_quality_scan_name,
                data_quality_display_name=data_quality_display_name,
                bigquery_dataset_name=bigquery_dataset_name,
                bigquery_table_name=bigquery_table_name,
                data_profile_scan_name=data_profile_scan_name,
                initial_prompt_content=initial_prompt_content,
                event_author_name=self.name)

            # Step 2: Iterate through the async generator using the 'async for' loop.
            async for event in scan_generator:
                # Re-yield all events from the streaming tool
                yield event

        except Exception as e:
            logger.error(f"[{self.name}] An unexpected error occurred while running the synchronous data quality workflow: {e}", exc_info=True)
            yield Event(
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=f"A critical error occurred in the workflow runner: {e}")])
            )
        
        finally:
            # Clean up session state (scratch pad)
            logger.info(f"[{self.name}] Cleaning up data quality workflow state variables from session.")
            keys_to_clear = [
                "data_quality_scan_name_param",
                "data_quality_display_name_param",
                "bigquery_dataset_name_param",
                "bigquery_table_name_param",
                "data_profile_scan_name_param",
                "initial_data_quality_query_param"
            ]
            for key in keys_to_clear:
                if ctx.session.state.pop(key, None):
                     logger.debug(f"Cleared state variable: {key}")

        logger.info(f"[{self.name}] Data quality workflow execution completed and all events re-yielded.")


################################################################################################################
# Data Quality Agent
################################################################################################################
agent_create_and_run_dataquality = CreateAndRunDataQualityScanAgentOrchestrator(
    name="CreateAndRunDataQuality_Agent"
)

def get_dataquality_agent():
    return LlmAgent(name="DataQuality_Agents",
                    description="Provides the ability to manage data quality scans.",
                    instruction=dataquality_agent_instruction,
                    global_instruction=global_instruction.global_protocol_instruction,
                    tools=[ dataquality_tools.create_data_quality_scan,
                            dataquality_tools.start_data_quality_scan,
                            dataquality_tools.exists_data_quality_scan,
                            dataquality_tools.get_data_quality_scans,
                            dataquality_tools.get_data_quality_scan_state,
                            dataquality_tools.update_bigquery_table_dataplex_labels_for_quality,
                            dataquality_tools.get_data_quality_scans_for_table,
                            dataquality_tools.list_data_quality_scan_jobs,
                            dataquality_tools.delete_data_quality_scan_job,
                            dataquality_tools.delete_data_quality_scan,
                            dataquality_tools.get_data_quality_scan_job_full_details,
                            bigquery_table_tools.get_bigquery_table_list,
                            bigquery_dataset_tools.get_bigquery_dataset_list,
                            wait_tool.wait_for_seconds,
                            dataquality_tools.parse_create_and_run_data_quality_scan_params,
                        ],
                    sub_agents=[
                        agent_create_and_run_dataquality
                    ],
                    model="gemini-2.5-flash",
                    planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                    generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=8192))