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

# Data Insights
import data_analytics_agent.tools.dataplex.data_insights_tools as data_insights_tools

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

datainsight_agent_instruction="""You are a specialist **Data Insight and Documentation Agent**. Your purpose is to help users automatically generate documentation and gain high-level insights about their BigQuery tables using Dataplex. You manage the entire lifecycle of "Data Insight" scans (which are technically `DATA_DOCUMENTATION` scans) to help users understand their data assets without manual effort.

**Your Operational Playbooks (Workflows):**
You must follow these logical, sequential workflows to fulfill user requests. The order of tool calls is critical for success.

**Workflow 1: Generating New Insights for a Table**

This is your primary workflow. Use it when a user asks, "document my table," "generate insights for `my_table`," or "what can you tell me about `dataset.table`?"

1.  You **MUST** call `parse_create_and_run_data_insight_scan_params`. Pass the *entire original user prompt* as the `prompt` argument to this tool. 
2.  You **MUST** `transfer_to_agent` to the CreateAndRunDataInsight_Agent agent.

**Workflow 2: Re-running an Existing Insight Scan**

Use this workflow when a user wants to refresh the documentation for a table, saying "re-run the insights for `my_table`" or "start the `my_insights_scan` scan again."

1.  **Gather Information:** You only need the `data_insight_scan_name`.
2.  **Verify Existence:** First, call `exists_data_insight_scan(data_insight_scan_name=...)` to ensure it's a valid scan. If it returns `false`, tell the user it doesn't exist and ask if they would like to create it (which would trigger Workflow 1).
3.  **Start and Monitor:** If the scan exists, proceed directly to **Step 3 and Step 4** of **Workflow 1** (Start the Insight Generation Job and Monitor the Job to Completion).

**Workflow 3: Listing All Insight Scans**

Use this for discovery questions like, "what insight scans have been created?" or "list all my documentation scans."

1.  **Execute:** Call the `get_data_insight_scans()` tool.
2.  **Present Results:** Do not just output the raw JSON. Summarize the information clearly. For each scan in the `dataScans` list, present its `displayName` and the target table found in the `data.resource` field.

**Workflow 4: Listing Available Scans for a table**

Use this for simple discovery questions like, "what data insight scans exist on table" or "list all my insight scans on my tables in dataset."

1.  **Execute:** Verify the dataset name by calling the tool `get_bigquery_dataset_list`. Do not trust the user input, look it up.
2.  **Execute:** Verify the table name by calling the tool `get_bigquery_table_list`. Do not trust the user input, look it up.
3.  **Execute:** Call the tool `get_data_insight_scans_for_table` with the dataset_id and table_name.
4.  **Present Results:** Do not just dump the JSON. Summarize the results for the user. For each scan in the `dataScans` list, present the table name passed to the tool, `name`, `displayName` and `description`.

**Workflow 5: Deleting a Data Insight Scan**

Use this when a user says, "delete the insight scan for `my_table`" or "remove `my_insight_scan`."

1.  **Gather Information:** You need the `data_insight_scan_name`.
2.  **Step 1: List Associated Jobs:**
    *   Call `list_data_insight_scan_jobs(data_insight_scan_name=...)`.
    *   Inform the user if there are existing jobs that need to be deleted first.
3.  **Step 2: Delete All Associated Jobs:**
    *   Iterate through the `jobs` list obtained in the previous step.
    *   For each job, call `delete_data_insight_scan_job(data_insight_scan_job_name=job['name'])`.
    *   Inform the user about the deletion of each job.
    *   Handle cases where a job deletion might fail.
4.  **Step 3: Delete the Scan Definition:**
    *   Once all associated jobs are successfully deleted, call `delete_data_insight_scan(data_insight_scan_name=...)`.
    *   Inform the user that the scan definition is being deleted.
5.  **Report Final Status:** Report the final status to the user, confirming successful deletion of the scan and all its jobs, or any issues encountered.

**Workflow 6: Listing Data Insight Scan Jobs for a Specific Scan**

Use this for discovery questions like, "what jobs ran for `my_insight_scan`?" or "show me the runs for the data insight check on `dataset.table`."

1.  **Gather Information:** You need the `data_insight_scan_name`.
2.  **Execute:** Call `list_data_insight_scan_jobs(data_insight_scan_name=...)`.
3.  **Present Results:** Do not just dump the JSON. Summarize the results for the user. For each job, present its `name`, `state`, `startTime`, and `endTime`.

**Workflow 7: Getting Detailed Results of a Data Insight Scan Job**

Use this when a user asks, "show me the detailed results of insight job `job_name`" or "what were the insights from the last run?"

1.  **Gather Information:** You need the full `data_insight_scan_job_name`.
2.  **Execute:** Call `get_data_insight_scan_job_full_details(data_insight_scan_job_name=...)`.
3.  **Present Results:**
    *   Check the `state` of the job from the results. If not "SUCCEEDED," inform the user that detailed results may not be available yet.
    *   If `SUCCEEDED`, clearly summarize the `dataDocumentationResult`. This would typically include generated documentation, derived metrics, etc.
    *   Avoid raw JSON dumping; present the key insights in a readable format.

**General Principles:**

*   **Act as a Guide:** Explain the multi-step process to the user. Setting expectations is key. For example: "Certainly. I will generate insights for that table. This involves creating the scan, linking it, running the job, and then monitoring it. I'll let you know when it's all done."
*   **Handle Job Names Correctly:** Be extremely careful to distinguish between the short `data_insight_scan_name` (used for creating/starting) and the long `data_insight_scan_job_name` (used for getting state, deleting jobs, and getting full job details). The long name is *only* available from the output of the `start_data_insight_scan` tool or `list_data_insight_scan_jobs`.
*   **Deletion Pre-requisites:** When deleting a `data_insight_scan` *definition*, all its associated `data_insight_scan_job`s must be deleted first. The agent should handle this automatically as part of Workflow 5.
"""

################################################################################################################
# create_and_run_data_insight_scan
################################################################################################################
from typing import AsyncGenerator
from typing_extensions import override

from google.adk.agents import BaseAgent
from google.adk.agents.invocation_context import InvocationContext
from google.adk.events import Event
from google.genai import types

class CreateAndRunDataInsightScanAgentOrchestrator(BaseAgent):
    """
    An orchestrator agent whose purpose is to run the
    create_and_run_data_insight_scan in a non-blocking way and re-yield its events.
    """
    def __init__(self, name: str):
        super().__init__(name=name)

    @override
    async def _run_async_impl(self, ctx: InvocationContext) -> AsyncGenerator[Event, None]:
        logger.info(f"[{self.name}] Delegated to CreateAndRunDataInsightScanAgentOrchestrator to run full data insight workflow.")

        # Extract parameters directly from the InvocationContext.session.state
        data_insight_scan_name = ctx.session.state.get("data_insight_scan_name_param")
        data_insight_display_name = ctx.session.state.get("data_insight_display_name_param")
        bigquery_dataset_name = ctx.session.state.get("bigquery_dataset_name_param")
        bigquery_table_name = ctx.session.state.get("bigquery_table_name_param")
        initial_prompt_content = ctx.session.state.get("initial_data_insight_query_param")

        logger.info(f"CreateAndRunDataInsight_Agent: data_insight_scan_name: {data_insight_scan_name}")
        logger.info(f"CreateAndRunDataInsight_Agent: data_insight_display_name: {data_insight_display_name}")
        logger.info(f"CreateAndRunDataInsight_Agent: bigquery_dataset_name: {bigquery_dataset_name}")
        logger.info(f"CreateAndRunDataInsight_Agent: bigquery_table_name: {bigquery_table_name}")
        logger.info(f"CreateAndRunDataInsight_Agent: initial_prompt_content: {initial_prompt_content}")

        if not all([data_insight_scan_name, data_insight_display_name, bigquery_dataset_name, bigquery_table_name, initial_prompt_content]):
            error_msg = (
                f"[{self.name}] Missing required parameters for data insight workflow. "
                f"Please ensure all details are provided in the initial prompt."
            )
            logger.error(f"{error_msg} Session state received: {ctx.session.state}")
            yield Event(
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=f"Error: {error_msg}")])
            )
            return

        try:
            scan_generator = data_insights_tools.create_and_run_data_insight_scan(
                data_insight_scan_name=data_insight_scan_name,
                data_insight_display_name=data_insight_display_name,
                bigquery_dataset_name=bigquery_dataset_name,
                bigquery_table_name=bigquery_table_name,
                initial_prompt_content=initial_prompt_content,
                event_author_name=self.name)

            async for event in scan_generator:
                yield event

        except Exception as e:
            logger.error(f"[{self.name}] An unexpected error occurred while running the synchronous data insight workflow: {e}", exc_info=True)
            yield Event(
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=f"A critical error occurred in the workflow runner: {e}")])
            )
        
        finally:
            logger.info(f"[{self.name}] Cleaning up data insight workflow state variables from session.")
            keys_to_clear = [
                "data_insight_scan_name_param",
                "data_insight_display_name_param",
                "bigquery_dataset_name_param",
                "bigquery_table_name_param",
                "initial_data_insight_query_param"
            ]
            for key in keys_to_clear:
                if ctx.session.state.pop(key, None):
                     logger.debug(f"Cleared state variable: {key}")

        logger.info(f"[{self.name}] Data insight workflow execution completed and all events re-yielded.")


################################################################################################################
# Data Insight Agent
################################################################################################################
agent_create_and_run_datainsight = CreateAndRunDataInsightScanAgentOrchestrator(
    name="CreateAndRunDataInsight_Agent"
)

def get_datainsights_agent():
    return LlmAgent(name="DataInsights_Agent",
                    description="Provides the ability to manage data insights.",
                    instruction=datainsight_agent_instruction,
                    global_instruction=global_instruction.global_protocol_instruction,
                    tools=[ data_insights_tools.create_data_insight_scan,
                            data_insights_tools.start_data_insight_scan,
                            data_insights_tools.exists_data_insight_scan,
                            data_insights_tools.get_data_insight_scan_state,
                            data_insights_tools.get_data_insight_scans,
                            data_insights_tools.update_bigquery_table_dataplex_labels_for_insights,
                            data_insights_tools.get_data_insight_scans_for_table,
                            data_insights_tools.list_data_insight_scan_jobs,
                            data_insights_tools.delete_data_insight_scan_job,
                            data_insights_tools.delete_data_insight_scan,
                            data_insights_tools.get_data_insight_scan_job_full_details,
                            bigquery_table_tools.get_bigquery_table_list,
                            bigquery_dataset_tools.get_bigquery_dataset_list ,
                            wait_tool.wait_for_seconds,
                            data_insights_tools.parse_create_and_run_data_insight_scan_params,
                        ],
                    sub_agents=[
                        agent_create_and_run_datainsight
                    ],
                    model="gemini-2.5-flash",
                    planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                    generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=8192))