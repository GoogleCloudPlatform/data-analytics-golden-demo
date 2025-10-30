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

# BigQuery
import data_analytics_agent.tools.bigquery.bigquery_dataset_tools as bigquery_dataset_tools

# Knowledge Engine
import data_analytics_agent.tools.dataplex.knowledge_engine_tools as knowledge_engine_tools

# Time Delay
import data_analytics_agent.utils.time_delay.wait_tool as wait_tool


# ADK
from google.adk.agents import LlmAgent
from google.adk.planners import BuiltInPlanner
from google.genai.types import ThinkingConfig
from google.genai import types


logger = logging.getLogger(__name__)


knowledge_engine_agent_instruction="""You are a specialized, **Knowledge Engine Agent**, designed to assist users in managing Google Dataplex Knowledge Engine Scans. Your core capability is to interact with Dataplex Knowledge Engine APIs via your provided tools to list, create, start, retrieve status, and get details of knowledge engine scans.

You will interpret user requests and utilize your tools to fulfill them. If a request is ambiguous or lacks necessary parameters, you **MUST** ask clarifying questions to obtain the required information.

If the user says "knowledge scan" this refers to this agent.

**Available Tools (You MUST only call functions from this list):**
*   `get_knowledge_engine_scans() -> dict`:
    *   **Description:** Lists all Dataplex Knowledge Engine scans in the configured region.
    *   **Returns:** A dictionary containing a list of knowledge engine scan objects.
*   `get_knowledge_engine_scans_for_dataset(dataset_id:str) -> dict`:
    *   **Description:** Lists all Dataplex Knowledge Engine scans that are configured to scan a specific BigQuery dataset.
    *   **Args:** `dataset_id` (str): The ID (or name) of the BigQuery dataset.
    *   **Returns:** A dictionary containing a list of knowledge engine scan objects.
*   `exists_knowledge_engine_scan(knowledge_engine_scan_name: str) -> dict`:
    *   **Description:** Checks if a specific Dataplex Knowledge Engine scan exists.
    *   **Args:** `knowledge_engine_scan_name` (str): The short name/ID of the knowledge engine scan.
    *   **Returns:** A dictionary indicating if the scan exists (`"exists": True/False`).
*   `create_knowledge_engine_scan(knowledge_engine_scan_name: str, knowledge_engine_display_name: str, bigquery_dataset_name: str) -> dict`:
    *   **Description:** Creates a new Dataplex Knowledge Engine scan targeting a BigQuery dataset. It includes an internal existence check.
    *   **Args:**
        *   `knowledge_engine_scan_name` (str): The short name/ID for the new scan.
        *   `knowledge_engine_display_name` (str): The user-friendly display name for the scan.
        *   `bigquery_dataset_name` (str): The BigQuery dataset to be scanned (e.g., "my_dataset_id").
    *   **Returns:** A dictionary indicating the creation status and details.
*   `start_knowledge_engine_scan(knowledge_engine_scan_name: str) -> dict`:
    *   **Description:** Initiates a new job for a specific Dataplex Knowledge Engine scan.
    *   **Args:** `knowledge_engine_scan_name` (str): The short name/ID of the knowledge engine scan to start.
    *   **Returns:** A dictionary containing the job operation details.
*   `get_knowledge_engine_scan_state(knowledge_engine_scan_job_name: str) -> dict`:
    *   **Description:** Retrieves the current state/status of a specific Dataplex Knowledge Engine scan job.
    *   **Args:** `knowledge_engine_scan_job_name` (str): The full operation name of the knowledge engine scan job.
    *   **Returns:** A dictionary with the job's state (e.g., "RUNNING", "SUCCEEDED", "FAILED").
*   `update_bigquery_dataset_dataplex_labels(knowledge_engine_scan_name: str, bigquery_dataset_name: str) -> dict`:
    *   **Description:** Updates Dataplex labels on a BigQuery dataset associated with a Knowledge Engine scan.
    *   **Args:**
        *   `knowledge_engine_scan_name` (str): The short name/ID of the knowledge engine scan.
        *   `bigquery_dataset_name` (str): The name of the BigQuery dataset.
    *   **Returns:** A dictionary indicating the update status.
*   `get_knowledge_engine_scan(knowledge_engine_scan_name: str) -> dict`:
    *   **Description:** Retrieves the full, detailed configuration and status of a specific Dataplex Knowledge Engine scan.
    *   **Args:** `knowledge_engine_scan_name` (str): The short name/ID of the knowledge engine scan.
    *   **Returns:** A dictionary containing the detailed scan object.
*   `get_bigquery_dataset_list() -> dict`: Gets the datasets in BigQuery. You should call this to get the dataset_id based on the name the user provided. Do not trust the name provided.
    *   **Returns:** A dictionary indicating the update status and results.
    
**Your Operational Playbook:**
When interpreting a user's request, identify the primary action they want to perform related to Knowledge Engine scans.

*   **To List All Scans:** If the user asks to "list all knowledge engine scans" or similar, call `get_knowledge_engine_scans()`.
*   **To List Scans for a Specific Dataset:** If the user asks "list knowledge scans for dataset 'X'", "show me knowledge scans on dataset 'Y'", or similar, call `get_knowledge_engine_scans_for_dataset(dataset_id='X')`. 
    * Workflow *
        1.  **Execute:** Verify the dataset name by calling the tool `get_bigquery_dataset_list`. Do not trust the user input, look it up.
        2.  **Execute:** Call the tool `get_knowledge_engine_scans_for_dataset` with the dataset_id.
        3.  **Present Results:** Do not just dump the JSON. Summarize the results for the user. For each scan in the `dataScans` list, present the table name passed to the tool, `name`, `displayName` and `description`.
*   **To Check if a Scan Exists:** If the user asks "does scan 'X' exist?", call `exists_knowledge_engine_scan(knowledge_engine_scan_name='X')`.
*   **To Get Details of a Specific Scan:** If the user asks "get details for scan 'X'" or "show me scan 'X'", call `get_knowledge_engine_scan(knowledge_engine_scan_name='X')`.

*   **To Create a Scan:**
    1.  You **MUST** call `parse_create_and_run_knowledge_engine_scan_params`. Pass the *entire original user prompt* as the `prompt` argument to this tool. 
    2.  You **MUST** `transfer_to_agent` to the CreateAndRunKnowledgeEngine_Agent agent.

*   **To Create a Business Glossary FROM a Knowledge Engine Scan:**
    1.  You **MUST** call `parse_create_business_glossary_knowledge_engine_params`. Pass the *entire original user prompt* as the `prompt` argument to this tool. 
    2.  You **MUST** `transfer_to_agent` to the CreateBusinessGlossaryFromKnowledgeEngineScan_Agent agent.
    
*   **To Start a Scan Job:** If the user asks to "start scan 'X'" or "run knowledge engine scan 'X'", call `start_knowledge_engine_scan(knowledge_engine_scan_name='X')`.
*   **To Get Scan Job State:** If the user asks "what is the status of job 'Y'?" or "get state of job 'Y'", call `get_knowledge_engine_scan_state(knowledge_engine_scan_job_name='Y')`. You must **poll this tool periodically (e.g., every 15-30 seconds by calling the `wait_for_seconds` tool)** until the `state` becomes "SUCCEEDED", "FAILED", or "CANCELLED".
*   **To Update Labels:** If the user explicitly asks to "update labels for scan 'X' on dataset 'Y'", call `update_bigquery_dataset_dataplex_labels(knowledge_engine_scan_name='X', bigquery_dataset_name='Y')`.

*   **Deleting a Knowledge Scan** Use this when a user says, "delete the knowledge scan for `my_dataset`" or "remove `my_knowledge_engine_scan`."
    1.  **Gather Information:** You need the `knowledge_engine_scan_name`.
    2.  **Step 1: List Associated Jobs:**
        *   Call `list_knowledge_engine_scan_jobs(knowledge_engine_scan_name=...)`.
        *   Inform the user if there are existing jobs that need to be deleted first.
    3.  **Step 2: Delete All Associated Jobs:**
        *   Iterate through the `jobs` list obtained in the previous step.
        *   For each job, call `delete_knowledge_engine_scan_job(knowledge_engine_scan_job_name=job['name'])`.
        *   Inform the user about the deletion of each job.
        *   Handle cases where a job deletion might fail.
    4.  **Step 3: Delete the Scan Definition:**
        *   Once all associated jobs are successfully deleted, call `delete_knowledge_engine_scan(knowledge_engine_scan_name=...)`.
        *   Inform the user that the scan definition is being deleted.
    5.  **Report Final Status:** Report the final status to the user, confirming successful deletion of the scan and all its jobs, or any issues encountered.


**Responding to the User:**
*   After calling a tool, interpret its output (`status`, `messages`, `results`) and provide a concise, informative response to the user.
*   If a tool returns `status: "failed"`, explain the failure reason to the user, typically by relaying the `messages` from the tool's response.

**Failure Handling and Guardrails:**

*   **TOOL RELIANCE:** You **MUST NOT** attempt to perform operations directly or invent tool names or parameters. Only use the functions explicitly listed in your "Available Tools".
*   **ERROR PROPAGATION:** If a tool execution results in a `status: "failed"`, you must convey this failure and the reasons provided by the tool back to the user. Do not attempt to fix API-level errors yourself unless your playbook explicitly allows for a retry or alternative.
*   **CLARIFICATION:** You are allowed and encouraged to ask clarifying questions if the user's initial prompt does not provide all the necessary parameters for a tool call.

**Example Conversation Flow:**

*   **User:** "List all knowledge engine scans."
*   **Your Internal Thought:** User wants to list scans. Call `get_knowledge_engine_scans()`.
*   **Your Response:** (Based on tool output) "Here are the knowledge engine scans in your project: [list of scan names]."

*   **User:** "Create a knowledge engine scan for `my_data_warehouse`."
*   **Your Internal Thought:** User wants to create a scan. `bigquery_dataset_name` is `my_data_warehouse`.
    *   `knowledge_engine_scan_name` will be `my-data-warehouse-knowledge-scan`.
    *   `knowledge_engine_display_name` will be `My Data Warehouse Knowledge Scan`.
    *   Call `create_knowledge_engine_scan('my-data-warehouse-knowledge-scan', 'My Data Warehouse Knowledge Scan', 'my_data_warehouse')`.
    *   Then call `update_bigquery_dataset_dataplex_labels('my-data-warehouse-knowledge-scan', 'my_data_warehouse')`.
    *   Then call `start_knowledge_engine_scan('my-data-warehouse-knowledge-scan')`.
    *   Then call `get_knowledge_engine_scan_state('job_name_from_previous_step')`.
*   **Your Response:** (Based on tool output) "Initiated creation of knowledge engine scan 'my-data-warehouse-knowledge-scan' for dataset 'my_data_warehouse'. Linking BigQuery UI labels. The scan has been started and its current state is 'RUNNING'."

*   **User:** "Start the scan named 'product-catalog-scan'."
*   **Your Internal Thought:** User wants to start a scan. Call `start_knowledge_engine_scan(knowledge_engine_scan_name='product-catalog-scan')`.
*   **Your Response:** (Based on tool output) "Initiated knowledge engine scan 'product-catalog-scan'. The operation ID is 'projects/.../operations/...'"
"""


################################################################################################################
# create_and_run_knowledge_engine_scan
################################################################################################################
from typing import AsyncGenerator
from typing_extensions import override

from google.adk.agents import BaseAgent
from google.adk.agents.invocation_context import InvocationContext
from google.adk.events import Event
from google.genai import types

class CreateAndRunKnowledgeEngineScanAgentOrchestrator(BaseAgent):
    """
    An orchestrator agent whose purpose is to run the
    create_and_run_knowledge_engine_scan in a non-blocking way and re-yield its events.
    """
    def __init__(self, name: str):
        super().__init__(name=name)

    @override
    async def _run_async_impl(self, ctx: InvocationContext) -> AsyncGenerator[Event, None]:
        logger.info(f"[{self.name}] Delegated to CreateAndRunKnowledgeEngineScanAgentOrchestrator to run full knowledge engine workflow.")

        # Extract parameters directly from the InvocationContext.session.state
        knowledge_engine_scan_name = ctx.session.state.get("knowledge_engine_scan_name_param")
        knowledge_engine_display_name = ctx.session.state.get("knowledge_engine_display_name_param")
        bigquery_dataset_name = ctx.session.state.get("bigquery_dataset_name_param")
        initial_prompt_content = ctx.session.state.get("initial_prompt_content")

        logger.info(f"CreateAndRunKnowledgeEngine_Agent: knowledge_engine_scan_name: {knowledge_engine_scan_name}")
        logger.info(f"CreateAndRunKnowledgeEngine_Agent: knowledge_engine_display_name: {knowledge_engine_display_name}")
        logger.info(f"CreateAndRunKnowledgeEngine_Agent: bigquery_dataset_name: {bigquery_dataset_name}")
        logger.info(f"CreateAndRunKnowledgeEngine_Agent: initial_prompt_content: {initial_prompt_content}")

        if not all([knowledge_engine_scan_name, knowledge_engine_display_name, bigquery_dataset_name, initial_prompt_content]):
            error_msg = (
                f"[{self.name}] Missing required parameters for knowledge engine workflow. "
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
            scan_generator = knowledge_engine_tools.create_and_run_knowledge_engine_scan(
                knowledge_engine_scan_name=knowledge_engine_scan_name,
                knowledge_engine_display_name=knowledge_engine_display_name,
                bigquery_dataset_name=bigquery_dataset_name,
                initial_prompt_content=initial_prompt_content,
                event_author_name=self.name)

            # Step 2: Iterate through the async generator using the 'async for' loop.
            # This is the correct and idiomatic way to consume an async generator.
            # It handles the __anext__ calls and StopAsyncIteration automatically.
            async for event in scan_generator:
                # Re-yield all events from the streaming tool
                yield event

        except Exception as e:
            logger.error(f"[{self.name}] An unexpected error occurred while running the synchronous knowledge engine workflow: {e}", exc_info=True)
            yield Event(
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=f"A critical error occurred in the workflow runner: {e}")])
            )
        
        finally:
            # Clean up session state (scratch pad)
            logger.info(f"[{self.name}] Cleaning up knowledge engine workflow state variables from session.")
            keys_to_clear = [
                "knowledge_engine_scan_name_param",
                "knowledge_engine_display_name_param",
                "bigquery_dataset_name_param",
                "initial_prompt_content"
            ]
            for key in keys_to_clear:
                # Use pop for safe deletion - it won't raise an error if the key is already gone.
                if ctx.session.state.pop(key, None):
                     logger.debug(f"Cleared state variable: {key}")

        logger.info(f"[{self.name}] Knowledge engine workflow execution completed and all events re-yielded.")



class CreateBusinessGlossaryFromKnowledgeEngineScanAgentOrchestrator(BaseAgent):
    """
    An orchestrator agent whose purpose is to run the create a business glossary
    from a knowledge engine scan.
    """
    def __init__(self, name: str):
        super().__init__(name=name)

    @override
    async def _run_async_impl(self, ctx: InvocationContext) -> AsyncGenerator[Event, None]:
        logger.info(f"[{self.name}] Delegated to CreateBusinessGlossaryFromKnowledgeEngineScanAgentOrchestrator to run full knowledge engine workflow.")

        # Extract parameters directly from the InvocationContext.session.state
        knowledge_engine_scan_name = ctx.session.state.get("knowledge_engine_scan_name_param")
        glossary_id = ctx.session.state.get("glossary_id_param")
        glossary_display_name = ctx.session.state.get("glossary_display_name_param")
        glossary_description = ctx.session.state.get("glossary_description_param")
        initial_prompt_content = ctx.session.state.get("initial_prompt_content")

        logger.info(f"CreateBusinessGlossaryFromKnowledgeEngineScan_Agent: knowledge_engine_scan_name: {knowledge_engine_scan_name}")
        logger.info(f"CreateBusinessGlossaryFromKnowledgeEngineScan_Agent: glossary_id: {glossary_id}")
        logger.info(f"CreateBusinessGlossaryFromKnowledgeEngineScan_Agent: glossary_display_name: {glossary_display_name}")
        logger.info(f"CreateBusinessGlossaryFromKnowledgeEngineScan_Agent: glossary_description: {glossary_description}")
        logger.info(f"CreateBusinessGlossaryFromKnowledgeEngineScan_Agent: initial_prompt_content: {initial_prompt_content}")

        if not all([knowledge_engine_scan_name, glossary_id, glossary_display_name, glossary_description, initial_prompt_content]):
            error_msg = (
                f"[{self.name}] Missing required parameters for knowledge engine workflow. "
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
            scan_generator = knowledge_engine_tools.create_business_glossary_from_knowledge_engine_scan(
                knowledge_engine_scan_name=knowledge_engine_scan_name,
                glossary_id=glossary_id,
                glossary_display_name=glossary_display_name,
                glossary_description=glossary_description,
                initial_prompt_content=initial_prompt_content,
                event_author_name=self.name)

            # Step 2: Iterate through the async generator using the 'async for' loop.
            # This is the correct and idiomatic way to consume an async generator.
            # It handles the __anext__ calls and StopAsyncIteration automatically.
            async for event in scan_generator:
                # Re-yield all events from the streaming tool
                yield event

        except Exception as e:
            logger.error(f"[{self.name}] An unexpected error occurred while running the synchronous knowledge engine workflow: {e}", exc_info=True)
            yield Event(
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=f"A critical error occurred in the workflow runner: {e}")])
            )
        
        finally:
            # Clean up session state (scratch pad)
            logger.info(f"[{self.name}] Cleaning up knowledge engine workflow state variables from session.")
            keys_to_clear = [
                "knowledge_engine_scan_name_param",
                "glossary_id",
                "glossary_display_name",
                "glossary_description"
            ]
            for key in keys_to_clear:
                # Use pop for safe deletion - it won't raise an error if the key is already gone.
                if ctx.session.state.pop(key, None):
                     logger.debug(f"Cleared state variable: {key}")

        logger.info(f"[{self.name}] Create Business Glossary From Knowledge Engine Scan workflow execution completed and all events re-yielded.")


################################################################################################################
# Knowledge Engine Agent
################################################################################################################
agent_create_and_run_knowledge_engine = CreateAndRunKnowledgeEngineScanAgentOrchestrator(
    name="CreateAndRunKnowledgeEngine_Agent"
)

agent_create_business_glossary_from_knowledge_engine_scan = CreateBusinessGlossaryFromKnowledgeEngineScanAgentOrchestrator(
    name="CreateBusinessGlossaryFromKnowledgeEngineScan_Agent"
)


def get_knowledge_engine_agent():
    return LlmAgent(name="KnowledgeEngine_Agent",
                    description="Provides access to knowledge engine which can create and extract insights of metadata in BigQuery.",
                    instruction=knowledge_engine_agent_instruction,
                    global_instruction=global_instruction.global_protocol_instruction,
                    tools=[ knowledge_engine_tools.get_knowledge_engine_scans,
                        knowledge_engine_tools.get_knowledge_engine_scans_for_dataset,
                        knowledge_engine_tools.exists_knowledge_engine_scan,
                        knowledge_engine_tools.create_knowledge_engine_scan,
                        knowledge_engine_tools.start_knowledge_engine_scan,
                        knowledge_engine_tools.get_knowledge_engine_scan_state,
                        knowledge_engine_tools.update_bigquery_dataset_dataplex_labels,
                        knowledge_engine_tools.get_knowledge_engine_scan,
                        knowledge_engine_tools.delete_knowledge_engine_scan_job,
                        knowledge_engine_tools.delete_knowledge_engine_scan,

                        bigquery_dataset_tools.get_bigquery_dataset_list,
                        
                        wait_tool.wait_for_seconds,
                        
                        knowledge_engine_tools.parse_create_and_run_knowledge_engine_scan_params,
                        knowledge_engine_tools.parse_create_business_glossary_knowledge_engine_params
                        ],
                    sub_agents=[
                        agent_create_and_run_knowledge_engine,
                        agent_create_business_glossary_from_knowledge_engine_scan
                    ],
                    model="gemini-2.5-flash",
                    planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                    generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=8192))