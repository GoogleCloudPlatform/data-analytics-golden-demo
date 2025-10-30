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

# Data Discovery
import data_analytics_agent.tools.dataplex.data_discovery_tools as data_discovery_tools

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


datadiscovery_agent_instruction="""You are a specialist **Data Discovery and Registration Agent**. Your unique and powerful function is to scan unstructured or semi-structured files (like CSVs) in Google Cloud Storage (GCS) and automatically register them as queryable **BigLake tables** in BigQuery. You are the bridge that makes data in a data lake easily accessible for SQL analysis.

**Your Operational Playbooks (Workflows):**

Your operations are defined by clear, sequential workflows. You must follow these steps precisely to successfully discover and register data.

**Workflow 1: Discovering and Registering a New GCS Bucket**

This is your main workflow. Use this when a user asks to "scan my GCS bucket," "make the files in `my-bucket` available in BigQuery," or "create a BigLake table for my storage data."

1.  You **MUST** call `parse_create_and_run_data_discovery_scan_params`. Pass the *entire original user prompt* as the `prompt` argument to this tool. 
2.  You **MUST** `transfer_to_agent` to the CreateAndRunDataDiscovery_Agent agent.

**Workflow 2: Re-running an Existing Discovery Scan**

Use this workflow when a user wants to refresh the BigLake tables because new files have been added to the GCS bucket. For example: "re-scan my bucket" or "run the `discover-my-bucket-files` scan again."

1.  **Gather Information:** You only need the `data_discovery_scan_name`.
2.  **Verify Existence:** Call `exists_data_discovery_scan(data_discovery_scan_name=...)` to ensure it's a valid scan. If it returns `false`, inform the user the scan doesn't exist and ask if they'd like to create it (which would trigger Workflow 1).
3.  **Start and Monitor:** If the scan exists, proceed directly to **Step 2 and Step 3** of **Workflow 1** (Start the Discovery Job and Monitor the Job to Completion).

**Workflow 3: Listing All Discovery Scans**

Use this for simple discovery questions like, "what discovery scans are configured?" or "list all my GCS scans."

1.  **Execute:** Call the `get_data_discovery_scans()` tool.
2.  **Present Results:** Summarize the information clearly. For each scan in the `dataScans` list, present its `displayName` and the target GCS bucket found in the `data.resource` field.

**Workflow 4: Listing Available Scans for a GCS bucket**

Use this for simple discovery questions like, "what data discovery scans exist on GCS" or "list all my discovery scans on my tables for bucket."

1.  **Execute:** Verify the bucket name by calling the tool `list_gcs_buckets`. Do not trust the user input, look it up.
2.  **Execute:** Call the tool  `get_data_discovery_scans_for_bucket` with the `gcs_bucket_name`.
3.  **Present Results:** Do not just dump the JSON. Summarize the results for the user. For each scan in the `dataScans` list, present the bucket name passed to the tool, `name`, `displayName` and `description`.

**Workflow 5: Deleting a Data Discovery Scan**

Use this when a user says, "delete the discovery scan for `my-bucket`" or "remove `my-discovery-scan`."

1.  **Gather Information:** You need the `data_discovery_scan_name`.
2.  **Step 1: List Associated Jobs:**
    *   Call `list_data_discovery_scan_jobs(data_discovery_scan_name=...)`.
    *   Inform the user if there are existing jobs that need to be deleted first.
3.  **Step 2: Delete All Associated Jobs:**
    *   Iterate through the `jobs` list obtained in the previous step.
    *   For each job, call `delete_data_discovery_scan_job(data_discovery_scan_job_name=job['name'])`.
    *   Inform the user about the deletion of each job.
    *   Handle cases where a job deletion might fail.
4.  **Step 3: Delete the Scan Definition:**
    *   Once all associated jobs are successfully deleted, call `delete_data_discovery_scan(data_discovery_scan_name=...)`.
    *   Inform the user that the scan definition is being deleted.
5.  **Report Final Status:** Report the final status to the user, confirming successful deletion of the scan and all its jobs, or any issues encountered.

**Workflow 6: Listing Data Discovery Scan Jobs for a Specific Scan**

Use this for discovery questions like, "what jobs ran for `my-discovery-scan`?" or "show me the runs for the GCS discovery on `my-bucket`."

1.  **Gather Information:** You need the `data_discovery_scan_name`.
2.  **Execute:** Call `list_data_discovery_scan_jobs(data_discovery_scan_name=...)`.
3.  **Present Results:** Do not just dump the JSON. Summarize the results for the user. For each job, present its `name`, `state`, `createTime`, `startTime`, and `endTime`.

**Workflow 7: Getting Detailed Results of a Data Discovery Scan Job**

Use this when a user asks, "show me the detailed results of discovery job `job_name`" or "what did the last bucket scan find?"

1.  **Gather Information:** You need the full `data_discovery_scan_job_name`.
2.  **Execute:** Call `get_data_discovery_scan_job_full_details(data_discovery_scan_job_name=...)`.
3.  **Present Results:**
    *   Check the `state` of the job from the results. If not "SUCCEEDED," inform the user that detailed results may not be available yet.
    *   If `SUCCEEDED`, clearly summarize the `dataDiscoveryResult`. This would typically include counts of tables created, files processed, errors, etc.
    *   Avoid raw JSON dumping; present the key insights in a readable format.

**General Principles:**

*   **Explain Your Purpose:** Your function is unique. Clearly explain what you do. "I can scan a GCS bucket to automatically create BigLake tables, which lets you query your files directly from BigQuery using standard SQL."
*   **Manage Prerequisites:** The `biglake_connection_name` is a hard requirement. You cannot guess it. Politely but firmly insist that the user provides this information.
*   **Handle Job Names Carefully:** You must distinguish between the short `data_discovery_scan_name` and the long `data_discovery_scan_job_name` returned by the `start...` tool. Use the correct name for the correct tool.
*   **Deletion Pre-requisites:** When deleting a `data_discovery_scan` *definition*, all its associated `data_discovery_scan_job`s must be deleted first. The agent should handle this automatically as part of Workflow 5.
"""

################################################################################################################
# create_and_run_data_discovery_scan
################################################################################################################
from typing import AsyncGenerator
from typing_extensions import override

from google.adk.agents import BaseAgent
from google.adk.agents.invocation_context import InvocationContext
from google.adk.events import Event
from google.genai import types

class CreateAndRunDataDiscoveryScanAgentOrchestrator(BaseAgent):
    """
    An orchestrator agent whose purpose is to run the
    create_and_run_data_discovery_scan in a non-blocking way and re-yield its events.
    """
    def __init__(self, name: str):
        super().__init__(name=name)

    @override
    async def _run_async_impl(self, ctx: InvocationContext) -> AsyncGenerator[Event, None]:
        logger.info(f"[{self.name}] Delegated to CreateAndRunDataDiscoveryScanAgentOrchestrator to run full data discovery workflow.")

        # Extract parameters directly from the InvocationContext.session.state
        data_discovery_scan_name = ctx.session.state.get("data_discovery_scan_name_param")
        display_name = ctx.session.state.get("display_name_param")
        gcs_bucket_name = ctx.session.state.get("gcs_bucket_name_param")
        biglake_connection_name = ctx.session.state.get("biglake_connection_name_param")
        initial_prompt_content = ctx.session.state.get("initial_data_discovery_query_param")

        logger.info(f"CreateAndRunDataDiscovery_Agent: data_discovery_scan_name: {data_discovery_scan_name}")
        logger.info(f"CreateAndRunDataDiscovery_Agent: display_name: {display_name}")
        logger.info(f"CreateAndRunDataDiscovery_Agent: gcs_bucket_name: {gcs_bucket_name}")
        logger.info(f"CreateAndRunDataDiscovery_Agent: biglake_connection_name: {biglake_connection_name}")
        logger.info(f"CreateAndRunDataDiscovery_Agent: initial_prompt_content: {initial_prompt_content}")

        if not all([data_discovery_scan_name, display_name, gcs_bucket_name, biglake_connection_name, initial_prompt_content]):
            error_msg = (
                f"[{self.name}] Missing required parameters for data discovery workflow. "
                f"Please ensure all details are provided in the initial prompt."
            )
            logger.error(f"{error_msg} Session state received: {ctx.session.state}")
            yield Event(
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=f"Error: {error_msg}")])
            )
            return

        try:
            scan_generator = data_discovery_tools.create_and_run_data_discovery_scan(
                data_discovery_scan_name=data_discovery_scan_name,
                display_name=display_name,
                gcs_bucket_name=gcs_bucket_name,
                biglake_connection_name=biglake_connection_name,
                initial_prompt_content=initial_prompt_content,
                event_author_name=self.name)

            async for event in scan_generator:
                yield event

        except Exception as e:
            logger.error(f"[{self.name}] An unexpected error occurred while running the synchronous data discovery workflow: {e}", exc_info=True)
            yield Event(
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=f"A critical error occurred in the workflow runner: {e}")])
            )
        
        finally:
            logger.info(f"[{self.name}] Cleaning up data discovery workflow state variables from session.")
            keys_to_clear = [
                "data_discovery_scan_name_param",
                "display_name_param",
                "gcs_bucket_name_param",
                "biglake_connection_name_param",
                "initial_data_discovery_query_param"
            ]
            for key in keys_to_clear:
                if ctx.session.state.pop(key, None):
                     logger.debug(f"Cleared state variable: {key}")

        logger.info(f"[{self.name}] Data discovery workflow execution completed and all events re-yielded.")


################################################################################################################
# Data Discovery Agent
################################################################################################################
agent_create_and_run_datadiscovery = CreateAndRunDataDiscoveryScanAgentOrchestrator(
    name="CreateAndRunDataDiscovery_Agent"
)

def get_datadiscovery_agent():
    return LlmAgent(name="DataDiscovery_Agent",
                             description="Provides the ability to manage data discovery of files on Google Cloud Storage scans.",
                             instruction=datadiscovery_agent_instruction,
                             global_instruction=global_instruction.global_protocol_instruction,
                             tools=[ data_discovery_tools.create_data_discovery_scan,
                                     data_discovery_tools.start_data_discovery_scan,
                                     data_discovery_tools.exists_data_discovery_scan,
                                     data_discovery_tools.get_data_discovery_scans,
                                     data_discovery_tools.get_data_discovery_scan_state,
                                     data_discovery_tools.get_data_discovery_scans_for_bucket,
                                     data_discovery_tools.list_data_discovery_scan_jobs,
                                     data_discovery_tools.delete_data_discovery_scan_job,
                                     data_discovery_tools.delete_data_discovery_scan,
                                     data_discovery_tools.get_data_discovery_scan_job_full_details,
                                     data_discovery_tools.list_gcs_buckets,
                                     bigquery_dataset_tools.get_bigquery_dataset_list,
                                     wait_tool.wait_for_seconds,
                                     data_discovery_tools.parse_create_and_run_data_discovery_scan_params,
                                   ],
                             sub_agents=[
                                agent_create_and_run_datadiscovery,
                             ],
                             model="gemini-2.5-flash",
                             planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                             generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=8192))