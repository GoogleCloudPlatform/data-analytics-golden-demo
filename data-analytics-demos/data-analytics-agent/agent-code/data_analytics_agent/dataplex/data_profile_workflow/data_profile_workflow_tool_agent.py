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
from typing import AsyncGenerator
from typing_extensions import override
import asyncio # <-- IMPORT asyncio

from google.adk.agents import BaseAgent
from google.adk.agents.invocation_context import InvocationContext
from google.adk.events import Event
from google.genai import types
# The target tool is now SYNCHRONOUS
import data_analytics_agent.dataplex.data_profile_workflow.data_profile_tool_workflow as data_profile_tool_workflow_helper

logger = logging.getLogger(__name__)

class DataProfileWorkflowToolAgentOrchestrator(BaseAgent):
    """
    An orchestrator agent whose purpose is to run the
    run_full_data_profile_workflow (a synchronous generator tool) in a
    non-blocking way and re-yield its events.
    This safely bridges the synchronous tool with the ADK's async environment.
    """
    def __init__(self, name: str):
        super().__init__(name=name)

    @override
    async def _run_async_impl(self, ctx: InvocationContext) -> AsyncGenerator[Event, None]:
        logger.info(f"[{self.name}] Delegated to DataProfileWorkflowToolAgentOrchestrator to run full data profile workflow.")

        # Extract parameters directly from the InvocationContext.session.state
        data_profile_scan_name = ctx.session.state.get("data_profile_scan_name_param")
        data_profile_display_name = ctx.session.state.get("data_profile_display_name_param")
        bigquery_dataset_name = ctx.session.state.get("bigquery_dataset_name_param")
        bigquery_table_name = ctx.session.state.get("bigquery_table_name_param")
        initial_prompt_content = ctx.session.state.get("initial_data_profile_query_param")

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

        # The `run_full_data_profile_workflow` function is synchronous and returns a generator.
        # We must run this synchronous function in a separate thread to avoid blocking the asyncio event loop.
        # `asyncio.to_thread` is the modern way to do this.
        try:
            # Step 1: Run the synchronous function in a thread. It returns the generator object.
            sync_generator = await asyncio.to_thread(
                data_profile_tool_workflow_helper.run_full_data_profile_workflow,
                data_profile_scan_name=data_profile_scan_name,
                data_profile_display_name=data_profile_display_name,
                bigquery_dataset_name=bigquery_dataset_name,
                bigquery_table_name=bigquery_table_name,
                initial_prompt_content=initial_prompt_content,
                event_author_name=self.name
            )

            # Step 2: Iterate through the generator. Each iteration might block (e.g., time.sleep).
            # So we wrap the iteration logic in a function that can also be run in a thread.
            def next_item(gen):
                try:
                    return next(gen)
                except StopIteration:
                    return None

            while True:
                # Get the next event from the generator in a non-blocking way
                event = await asyncio.to_thread(next_item, sync_generator)
                if event is None:
                    # The generator is exhausted
                    break
                # Re-yield all events from the streaming tool
                yield event

        except Exception as e:
            logger.error(f"[{self.name}] An unexpected error occurred while running the synchronous data profile workflow: {e}", exc_info=True)
            yield Event(
                author=self.name,
                content=types.Content(role='assistant', parts=[types.Part(text=f"A critical error occurred in the workflow runner: {e}")])
            )
        
        logger.info(f"[{self.name}] Data profile workflow execution completed and all events re-yielded.")