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
from typing import Optional, Generator
from pydantic import BaseModel, Field
import json

from google.adk.tools.tool_context import ToolContext
from google.genai import types
from google.adk.events import Event # <-- Only import Event

import data_analytics_agent.dataplex.data_profile as data_profile_tools
import data_analytics_agent.wait_tool as wait_tool_helper

logger = logging.getLogger(__name__)

# This will be the FINAL output schema for the consolidated tool's conceptual output.
# When yielded, it will be contained within the 'content' of an Event.
# class DataProfileToolWorkflowOutput(BaseModel):
#     status: str = Field(description="Overall status: 'success' or 'failed'")
#     tool_name: str = Field(description="Name of the tool/workflow that produced this result.")
#     query: Optional[str] = Field(None, description="The query that initiated the workflow (if applicable).")
#     messages: list[str] = Field(description="List of informational messages during processing.")
#     results: Optional[dict] = Field(None, description="Detailed results of the data profile scan, if successful.")
#     success: bool = Field(description="Did the overall workflow succeed?")

def run_full_data_profile_workflow(
    data_profile_scan_name: str,
    data_profile_display_name: str,
    bigquery_dataset_name: str,
    bigquery_table_name: str,
    initial_prompt_content: str,
    event_author_name: str
) -> Generator[Event, None, None]:
    """
    Orchestrates the complete Dataplex Data Profile scan workflow, including
    creating the scan, starting the job, monitoring its state, and linking to BigQuery.
    Emits progress messages to the user interface by yielding Events.

    Args:
        data_profile_scan_name (str): The name/ID for the data profile scan.
        data_profile_display_name (str): The display name for the data profile scan.
        bigquery_dataset_name (str): The BigQuery dataset name.
        bigquery_table_name (str): The BigQuery table name.
        initial_prompt_content (str): The original user query that initiated this workflow.
        event_author_name (str): The name to use as the author for yielded Event messages.

    Yields:
        Event: Progress messages and a final structured Event containing the workflow output.
    """
    logger.info(f"[{event_author_name}] Starting Data Profile Scan workflow for {data_profile_scan_name}.")

    response = {
        "status": "success",
        "tool_name": "full_data_profile_workflow",
        "query": initial_prompt_content,
        "messages": [],
        "results": {
            "data_profile_scan_name": data_profile_scan_name,
            "data_profile_display_name": data_profile_display_name,
            "bigquery_dataset_name": bigquery_dataset_name,
            "bigquery_table_name": bigquery_table_name,
            "data_profile_scan_job_name": None,
            "data_profile_scan_job_state": None,
        },
        "success": True
    }

    # Helper to yield an error and then finish
    def _handle_error_and_finish(err_message: str, current_response: dict):
        current_response["status"] = "failed"
        current_response["success"] = False
        current_response["messages"].append(err_message)
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=f"Error: {err_message}")]))
        
        # --- CORRECTED CODE ---
        # REMOVED the actions parameter. The orchestrator's completion will signal finality.
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=json.dumps(current_response, indent=2))]),
        )

    # Emit initial message
    yield Event(
        author=event_author_name,
        content=types.Content(role='assistant', parts=[types.Part(text=f"Initiating full data profile scan workflow for '{bigquery_dataset_name}.{bigquery_table_name}'.")])
    )
    response["messages"].append(f"Workflow initiated for {data_profile_scan_name}.")


    # --- Step 1: Create the Scan Definition ---
    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 1/5: Creating data profile scan definition: '{data_profile_scan_name}'.")])
        )
        create_scan_result = data_profile_tools.create_data_profile_scan(
            data_profile_scan_name,
            data_profile_display_name,
            bigquery_dataset_name,
            bigquery_table_name
        )
        if create_scan_result["status"] != "success":
            raise Exception(f"Failed to create scan definition: {create_scan_result.get('error_message', 'Unknown error')}")
        
        success_message = f"Successfully created data profile scan definition: {data_profile_scan_name}. Now waiting for it to register."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed to create data profile scan '{data_profile_scan_name}'. Error: {e}", response):
            yield error_event
        return


    # --- Step 2: Wait for Scan to Exist (Polling Loop) ---
    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 2/5: Waiting for scan '{data_profile_scan_name}' to be registered and exist.")])
        )
        scan_exists = False
        max_attempts = 10
        for i in range(max_attempts):
            exists_check_result = data_profile_tools.exists_data_profile_scan(data_profile_scan_name)
            if exists_check_result["status"] == "success" and exists_check_result["results"]["exists"]:
                scan_exists = True
                break
            yield Event(
                author=event_author_name,
                content=types.Content(role='assistant', parts=[types.Part(text=f"Scan not yet registered (attempt {i+1}/{max_attempts}). Waiting 2 seconds...")])
            )
            wait_tool_helper.wait_for_seconds(2)

        if not scan_exists:
            raise Exception(f"Scan '{data_profile_scan_name}' did not become registered after {max_attempts * 2} seconds.")
        
        success_message = f"Data profile scan '{data_profile_scan_name}' is now registered and ready."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed while waiting for scan '{data_profile_scan_name}' to register. Error: {e}", response):
            yield error_event
        return


    # --- Step 3: Start the Scan Job ---
    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 3/5: Starting the data profile scan job for '{data_profile_scan_name}'.")])
        )
        start_job_result = data_profile_tools.start_data_profile_scan(data_profile_scan_name)
        if start_job_result["status"] != "success" or not start_job_result["results"].get("job", {}).get("name"):
            raise Exception(f"Failed to start scan job: {start_job_result.get('error_message', 'Unknown error')}")
        
        job_name = start_job_result["results"]["job"]["name"]
        response["results"]["data_profile_scan_job_name"] = job_name
        
        success_message = f"Successfully started data profile scan job: '{job_name}'. Monitoring its progress."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed to start data profile scan job for '{data_profile_scan_name}'. Error: {e}", response):
            yield error_event
        return


    # --- Step 4: Monitor the Scan Job State (Polling Loop) ---
    job_name = response["results"]["data_profile_scan_job_name"]
    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 4/5: Monitoring data profile job '{job_name}' for completion.")])
        )
        job_completed = False
        final_job_state = "UNKNOWN"
        max_attempts = 50
        for i in range(max_attempts):
            job_state_result = data_profile_tools.get_data_profile_scan_state(job_name)
            if job_state_result["status"] == "success" and job_state_result["results"].get("job", {}).get("state"):
                current_state = job_state_result["results"]["job"]["state"]
                yield Event(
                    author=event_author_name,
                    content=types.Content(role='assistant', parts=[types.Part(text=f"Job '{job_name}' status: {current_state} (attempt {i+1}/{max_attempts}).")])
                )
                if current_state in ["SUCCEEDED", "FAILED", "CANCELLED"]:
                    job_completed = True
                    final_job_state = current_state
                    break
            else:
                yield Event(
                    author=event_author_name,
                    content=types.Content(role='assistant', parts=[types.Part(text=f"Could not retrieve job status (attempt {i+1}/{max_attempts}). Retrying in 5 seconds...")])
                )
            wait_tool_helper.wait_for_seconds(5)

        if not job_completed:
            raise Exception(f"Data profiling job '{job_name}' did not complete after {max_attempts * 5} seconds. Final state: {final_job_state}")
        
        if final_job_state != "SUCCEEDED":
            raise Exception(f"Data profiling job '{job_name}' completed with state: {final_job_state}. (Expected SUCCEEDED)")

        response["results"]["data_profile_scan_job_state"] = final_job_state
        success_message = f"Data profiling job '{job_name}' completed successfully with state: {final_job_state}. Now linking to BigQuery."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        final_job_state = final_job_state if 'final_job_state' in locals() else 'UNKNOWN_FAILED'
        response["results"]["data_profile_scan_job_state"] = final_job_state
        for error_event in _handle_error_and_finish(f"Data profiling job '{job_name}' failed or did not complete. Error: {e}", response):
            yield error_event
        return

    # --- Step 5: Link the Scan to BigQuery ---
    try:
        yield Event(
            author=event_author_name,
            content=types.Content(role='assistant', parts=[types.Part(text=f"Step 5/5: Linking data profile scan '{data_profile_scan_name}' to BigQuery table '{bigquery_dataset_name}.{bigquery_table_name}'." )])
        )
        link_result = data_profile_tools.update_bigquery_table_dataplex_labels(
            data_profile_scan_name,
            bigquery_dataset_name,
            bigquery_table_name,
        )
        if link_result["status"] != "success":
            raise Exception(f"Failed to link to BigQuery: {link_result.get('error_message', 'Unknown error')}")
        
        success_message = f"Successfully linked the data profile scan to BigQuery. Results should now be visible in the BigQuery console."
        yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=success_message)]))
        response["messages"].append(success_message)

    except Exception as e:
        for error_event in _handle_error_and_finish(f"Failed to link data profile scan '{data_profile_scan_name}' to BigQuery. Error: {e}", response):
            yield error_event
        return

    # --- Workflow Complete ---
    final_overall_message = "Data profiling workflow completed successfully!" if response["success"] else "Data profiling workflow completed with failures."
    yield Event(author=event_author_name, content=types.Content(role='assistant', parts=[types.Part(text=final_overall_message)]))
    response["messages"].append(final_overall_message)

    # Do not yield the entire json summary
    # yield Event(
    #     author=event_author_name,
    #     content=types.Content(role='assistant', parts=[types.Part(text=json.dumps(response, indent=2))]),
    # )
    