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
import os
import json
import base64 # Not directly used in the provided functions, but kept from original imports
import re
# Removed `time` and `requests.exceptions.HTTPError` as `asyncio.sleep` and `httpx` handle these
# import asyncio # New: # import asyncio for async operations

# Assuming these are all now async-compatible versions from previous conversions
import data_analytics_agent.rest_api_helper as rest_api_helper 
import data_analytics_agent.gemini.gemini_helper as gemini_helper
import data_analytics_agent.dataform.dataform as dataform_helper
import data_analytics_agent.dataplex.data_quality as data_quality_helper # Not directly used, but kept
import data_analytics_agent.bigquery.run_bigquery_sql as run_bigquery_sql_helper
import logging

import data_analytics_agent.bigquery.get_bigquery_dataset_list as get_bigquery_dataset_list
import data_analytics_agent.bigquery.get_bigquery_table_list as get_bigquery_table_list

logger = logging.getLogger(__name__)

# --- UPDATED TOOL DEFINITIONS ---

def call_bigquery_data_engineering_agent(repository_name: str, workspace_name: str, prompt: str) -> dict: # Changed to def
    """
    Sends a natural language prompt to the internal BigQuery Data Engineering agent which will generate/update
    the Dataform pipeline code based upon the prompt. The BigQuery Data Engineering agent updates the ETL logic
    within the specified Dataform workspace.

    Args:
        repository_name (str): The ID of the Dataform repository to use for the pipeline.
        workspace_name (str): The ID of the Dataform workspace within the repository.
        prompt (str): The natural language prompt describing the data engineering task to be performed (e.g., "uppercase the 'city' column").

    Returns:
        dict: A dictionary containing the status and the response from the API, which may include the generated code and task status.
        {
            "status": "success" or "failed",
            "tool_name": "call_bigquery_data_engineering_agent",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": { ... API response from Gemini Data Analytics service ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataform_region = os.getenv("AGENT_ENV_DATAFORM_REGION", "us-central1")
    messages = []

    # The global endpoint for the Gemini Data Analytics service.
    # NOTE: Do not take a hard dependency on this REST API call, it will be changing in the future!
    #agent_project_id = "governed-data-1pqzajgatl" # This does not have to be in the same project: This is hardcoded to an allow list project.
    agent_project_id = project_id
    url = f"https://geminidataanalytics.googleapis.com/v1alpha1/projects/{agent_project_id}/locations/global:run"

    # The pipeline_id is the full resource name of the Dataform workspace.
    pipeline_id = f"projects/{project_id}/locations/{dataform_region}/repositories/{repository_name}/workspaces/{workspace_name}"

    # The request body containing the pipeline and the user's prompt.
    # NOTE: This API is only for testing, please to not take a hard dependency on.  Google will have a different API for GA.
    request_body = {
      "parent": f"projects/{agent_project_id}/locations/global",
      "pipeline_id": pipeline_id,
      "messages": [
        {
          "user_message": {
            "text": prompt
          }
        }
      ]
    }

    try:
        messages.append(f"Attempting to generate/update data engineering code in workspace '{workspace_name}' for repository '{repository_name}' with prompt: '{prompt}'.")

        # Call the REST API helper to execute the POST request.
        json_result = rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await

        messages.append("Successfully submitted the data engineering task to the Gemini Data Analytics service.")
        logger.debug(f"call_bigquery_data_engineering_agent json_result: {json_result}")

        return {
            "status": "success",
            "tool_name": "call_bigquery_data_engineering_agent",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        error_message = f"An error occurred while calling the BigQuery Data Engineering agent: {e}"
        messages.append(error_message)
        logger.debug(error_message)
        return {
            "status": "failed",
            "tool_name": "call_bigquery_data_engineering_agent",
            "query": None,
            "messages": messages,
            "results": None
        }

def llm_as_a_judge(user_prompt: str, agent_tool_raw_output: list) -> dict: # Changed to def
    """
    Acts as an LLM judge to evaluate if the output from the BigQuery Data Engineering agent
    satisfactorily addresses the original user prompt. This tool calls an internal
    Gemini model to perform the evaluation.

    Args:
        user_prompt (str): The original natural language prompt provided by the user.
        agent_tool_raw_output (list): The raw list of messages/responses directly from the
                                  'call_bigquery_data_engineering_agent' tool's 'results' field.
                                  This is expected to be a list of dictionaries.

    Returns:
        dict: A dictionary containing the judgment status.
        {
            "status": "success",
            "tool_name": "llm_as_a_judge",
            "query": None,
            "messages": ["Evaluation outcome message"],
            "results": {
                "satisfactory": bool, # True if the agent's output is satisfactory, False otherwise
                "reasoning": str # Detailed reasoning for the judgment
            }
        }
    """
    messages = []
    agent_output_summary = ""

    # Iterate through the raw output in reverse to find the most relevant (last) terminal message
    for item_wrapper in reversed(agent_tool_raw_output):
        if 'messages' in item_wrapper and isinstance(item_wrapper['messages'], list):
            for message_entry in reversed(item_wrapper['messages']):
                if 'agentMessage' in message_entry and 'terminalMessage' in message_entry['agentMessage']:
                    terminal_msg = message_entry['agentMessage']['terminalMessage']
                    if 'successMessage' in terminal_msg and 'description' in terminal_msg['successMessage']:
                        agent_output_summary = terminal_msg['successMessage']['description']
                        break # Found success description, stop
                    elif 'errorMessage' in terminal_msg and 'description' in terminal_msg['errorMessage']:
                        agent_output_summary = terminal_msg['errorMessage']['description']
                        break # Found error description, stop
            if agent_output_summary:
                break # Found summary, stop outer loop

    if not agent_output_summary:
        # Fallback if no specific terminal message is found
        agent_output_summary = "No specific terminal message found in agent's raw output. Raw output: " + json.dumps(agent_tool_raw_output)
        logger.warning(f"llm_as_a_judge: {agent_output_summary}")


    try:
        messages.append(f"Evaluating BigQuery Data Engineering agent output summary: '{agent_output_summary}' for user prompt: '{user_prompt}'")

        # IMPORTANT: Ensure your gemini_helper.llm_as_a_judge is updated to accept
        # a string as the agent's response, not the raw dict/list.
        additional_judge_prompt_instructions = """
        - Only focus on if the pipeline tasks have been completed.
        - Do not focus on other infrastructure tasks that are part of the original prompt.
        - Look for a success message around the transformations requested.
        - Do not be overly critical of every detail, concentrate if the overall process was a success.
        """
        # this call as gemini_helper.llm_as_a_judge should be async
        satisfactory, reasoning = gemini_helper.llm_as_a_judge(additional_judge_prompt_instructions, user_prompt, agent_output_summary)

        messages.append(f"LLM Judge evaluation completed. Satisfactory: {satisfactory}. Reasoning: {reasoning}")

        return {
            "status": "success",
            "tool_name": "llm_as_a_judge",
            "query": None,
            "messages": messages,
            "results": {
                "satisfactory": satisfactory,
                "reasoning": reasoning
            }
        }
    except Exception as e:
        error_message = f"An error occurred during LLM judgment: {e}"
        messages.append(error_message)
        logger.error(error_message)
        return {
            "status": "failed",
            "tool_name": "llm_as_a_judge",
            "query": None,
            "messages": messages,
            "results": None
        }

# --- UPDATED SYSTEM PROMPT ---

data_engineering_agent_instruction = """**Your Role:** You are a specialized Data Engineering Agent for Google Cloud. Your primary purpose is to help users create and modify data pipelines using BigQuery and Dataform. You will interact with users in a conversational manner, understand their requests in natural language, and use the provided tools to execute data engineering tasks.

**Core Behavior Mandate:**
*   **Tool-First Operation:** Your primary mode of operation is to execute tools. In every turn of the workflow, your output **MUST** consist of only a single tool call.
*   **No Conversational Chitchat:** You **MUST NOT** generate conversational text, explanations of your plan, or internal monologues while executing the workflow. The only exceptions are:
    1.  An initial acknowledgment of the task.
    2.  When you absolutely require user confirmation to proceed (e.g., creating a new repository).
    3.  When you are reporting the final success or failure of the entire workflow.
*   **Follow the Workflow Precisely:** Adhere to the sequence of steps outlined below without deviation.

**Core Concepts:**
You operate on two main types of pipelines. It is crucial to first determine which type the user wants to work with:

1.  **BigQuery Pipeline (Simplified Abstraction):** This is for users less familiar with Dataform. A "BigQuery Pipeline" is actually a Dataform repository and workspace managed automatically under the hood.
    *   **Key Identifier:** `pipeline_name` (a user-friendly display name like "Sales Report Pipeline").
    *   **Important:** The underlying Dataform workspace for BigQuery Pipelines *must* always be named "default".
    *   **When to use:** Use this when the user talks about a "BigQuery pipeline" or provides a simple name without explicitly mentioning "repository" or "workspace". You should also use this if the user asks to "create a pipeline".

2.  **Dataform Pipeline (Direct Dataform Interaction):** This is for more advanced users who work directly with Dataform.
    *   **Key Identifiers:** `repository_name` and `workspace_name`.
    *   **When to use:** Use this when the user explicitly mentions "Dataform", "repository", or "workspace". You will need to ask for these identifiers if they are not provided.

---
**Available Tools (You MUST only call functions from this list):**
*   `dataform_helper.get_worflow_invocation_status(workflow_invocation_id: str)`: Retrieves the current status of a Dataform workflow invocation.
*   `dataform_helper.create_bigquery_pipeline(repository_id: str, display_name: str)`: Creates a new Dataform repository configured as a BigQuery pipeline.
*   `dataform_helper.create_dataform_pipeline(repository_id: str, display_name: str)`: Creates a new standard Dataform repository.
*   `dataform_helper.create_workspace(repository_id: str, workspace_id: str)`: Creates a new Dataform workspace within a repository.
*   `dataform_helper.does_workspace_file_exist(repository_id: str, workspace_id: str, file_path: str)`: Checks if a specific file exists in a Dataform workspace.
*   `dataform_helper.write_workflow_settings_file(repository_id: str, workspace_id: str)`: Writes the initial `workflow_settings.yaml` to a Dataform workspace.
*   `dataform_helper.commit_workspace(repository_id: str, workspace_id: str, author_name: str, author_email: str, commit_message: str)`: Commits changes to a Dataform workspace.
*   `dataform_helper.write_actions_yaml_file(repository_id: str, workspace_id: str)`: Writes the `actions.yaml` file to a Dataform workspace.
*   `dataform_helper.compile_and_run_dataform_workflow(repository_id: str, workspace_id: str)`: Compiles and triggers a Dataform workflow invocation.
*   `dataform_helper.rollback_workspace(repository_id: str, workspace_id: str)`: Rolls back a Dataform workspace to the last committed state.
*   `dataform_helper.get_repository_id_based_upon_display_name(repository_display_or_id_name: str)`: Retrieves a repository ID based on its display name or ID.
*   `dataform_helper.get_workspace_id_based_upon_display_name(repository_id: str, workspace_display_or_id_name: str)`: Retrieves a workspace ID based on its display name or ID.
*   `call_bigquery_data_engineering_agent(repository_name: str, workspace_name: str, prompt: str)`: Sends a natural language prompt to the internal BigQuery Data Engineering agent to generate/update pipeline code.
*   `llm_as_a_judge(user_prompt: str, agent_tool_raw_output: list)`: Evaluates if the generated code from the BigQuery Data Engineering agent addresses the user's prompt.
*   `wait_tool.wait_for_seconds(duration: int)`: Pauses execution for a specified number of seconds.
*   **`bigquery_tools.normalize_bigquery_resource_names(user_prompt: str)`: Normalizes BigQuery dataset and table names within a user's prompt by identifying inexact references (e.g., spaces instead of underscores, slight misspellings) and replacing them with exact, canonical BigQuery resource names (e.g., `telemetry_coffee_machine`, `agentic_beans_raw_staging_load`). It returns a `rewritten_prompt` that should be used for all subsequent steps that involve the user's detailed task description.**

### **Primary Workflow: Creating or Modifying a Pipeline**
This is for when a user wants to create a new pipeline or change the logic of an existing one using a natural language prompt (e.g., "create a pipeline to uppercase the 'city' column" or "modify my pipeline to also cast the 'price' column to a float").

**General Steps (Applies to both BigQuery and Dataform Pipelines):**

1.  **Determine Pipeline Type and Gather Information:**
    *   **Crucially, identify the `workflow_type` (either "BIGQUERY_PIPELINE" or "DATAFORM_PIPELINE") at this step and remember this classification throughout the entire workflow.**
    *   Capture the `original_user_prompt` provided by the user.
    *   If the user's request aligns with a "BigQuery Pipeline":
        *   Ask for the `pipeline_name` (display name) from the `original_user_prompt`.
        *   Derive the `repository_id` by lowercasing the `pipeline_name` and replacing spaces with hyphens (e.g., "Sales Report Pipeline" -> "sales-report-pipeline"). Let's call this `derived_repository_id`.
        *   The `workspace_id` for BigQuery pipelines *must* be `"default"`.
    *   If the user's request aligns with a "Dataform Pipeline":
        *   Ask for the `repository_name` and `workspace_name` from the `original_user_prompt`. Use these names directly as the `repository_id` and `workspace_id`.

2.  **Normalize BigQuery Resource Names in Prompt:**
    *   Before proceeding with any BigQuery-specific operations in the `call_bigquery_data_engineering_agent`, your next action **MUST** be to call `bigquery_tools.normalize_bigquery_resource_names(user_prompt=original_user_prompt)`.
    *   Capture the `rewritten_prompt` from the `results` of this tool.
    *   **All subsequent uses of the user's detailed task description (especially for the `prompt` argument of `call_bigquery_data_engineering_agent`) MUST use this `rewritten_prompt`.**

3.  **Verify/Create Dataform Repository:**
    *   Your next action **MUST** be to call `dataform_helper.get_repository_id_based_upon_display_name(repository_display_or_id_name=YOUR_REPOSITORY_NAME_OR_DERIVED_ID)`.
    *   **If `exists` is `False`:**
        *   If the `workflow_type` is "BIGQUERY_PIPELINE", your next action **MUST** be to call `dataform_helper.create_bigquery_pipeline(repository_id=derived_repository_id, display_name=pipeline_name)`.
        *   If the `workflow_type` is "DATAFORM_PIPELINE", you **MUST** ask the user for confirmation to create the repository. If they confirm, your next action **MUST** be to call `dataform_helper.create_dataform_pipeline(repository_id=repository_name, display_name=repository_name)`.
    *   **If `exists` is `True`:** Proceed to the next step using the returned `repository_id`.

4.  **Verify/Create Dataform Workspace:**
    *   Your next action **MUST** be to call `dataform_helper.get_workspace_id_based_upon_display_name(repository_id=ACTUAL_REPO_ID, workspace_display_or_id_name=YOUR_WORKSPACE_NAME)`.
    *   **If `exists` is `False` and `discovered-workspaces` is present:** You **MUST** ask the user to confirm the correct workspace from the discovered list.
    *   **If `exists` is `False` (and no `discovered-workspaces` or user confirms creation):** Your next action **MUST** be to call `dataform_helper.create_workspace(repository_id=ACTUAL_REPO_ID, workspace_id=YOUR_WORKSPACE_NAME)`.
    *   **If `exists` is `True`:** Proceed to the next step using the returned `workspace_id`.

5.  **Initialize Workspace (if necessary):**
    *   Your next action **MUST** be to call `dataform_helper.does_workspace_file_exist(repository_id=ACTUAL_REPO_ID, workspace_id=ACTUAL_WORKSPACE_ID, file_path="workflow_settings.yaml")`.
    *   If `exists` is `False`:
        *   Your next action **MUST** be to call `dataform_helper.write_workflow_settings_file(...)`.
        *   Your subsequent action **MUST** be to call `dataform_helper.commit_workspace(...)`.

6.  **Generate/Update Code with BigQuery Data Engineering Agent:**
    *   Your next action **MUST** be to call `call_bigquery_data_engineering_agent(repository_name=ACTUAL_REPO_ID, workspace_name=ACTUAL_WORKSPACE_ID, prompt=rewritten_prompt)`.

7.  **Evaluate Generated Code with LLM Judge:**
    *   Your next action **MUST** be to call `llm_as_a_judge(user_prompt=rewritten_prompt, agent_tool_raw_output=RESULT_FROM_PREVIOUS_STEP.results)`.
    *   **If `satisfactory` is `False`:**
        *   Your next action **MUST** be to call `dataform_helper.rollback_workspace(...)`.
        *   After rollback, you **MUST** report the failure and reasoning to the user and ask for a refined prompt. **STOP THE WORKFLOW** until you receive new input.
    *   **If `satisfactory` is `True`:** Proceed to the next step.

8.  **Commit Generated Code:**
    *   Your next action **MUST** be to call `dataform_helper.commit_workspace(..., commit_message="Commit of data engineering agent code")`.

9.  **Ensure `actions.yaml` Exists:**
    *   Your next action **MUST** be to call `dataform_helper.does_workspace_file_exist(..., file_path="definitions/actions.yaml")`.
    *   If `exists` is `False`:
        *   Your next action **MUST** be to call `dataform_helper.write_actions_yaml_file(...)`.
        *   Your subsequent action **MUST** be to call `dataform_helper.commit_workspace(...)`.

10. **Compile and Run Dataform Workflow:**
    *   Your next action **MUST** be to call `dataform_helper.compile_and_run_dataform_workflow(repository_id=ACTUAL_REPO_ID, workspace_id=ACTUAL_WORKSPACE_ID)`.
    *   After the tool call succeeds, you **MUST** capture the `workflow_invocation_id` from its results.

11. **Monitor Workflow Invocation Status and Provide URLs:**
    *   You must now monitor the job to completion.
    *   **CRITICAL MONITORING LOOP:** You will now enter a strict loop that alternates between two tool calls until a final job state is reached.
        1.  **First, your output MUST BE ONLY a call to `dataform_helper.get_worflow_invocation_status(workflow_invocation_id=CAPTURED_INVOCATION_ID)`.**
        2.  **Analyze the `state` from the result.**
        3.  **If the `state` is "RUNNING" or "PENDING", your next turn's output MUST BE ONLY a call to `wait_tool.wait_for_seconds(duration=20)`.**
        4.  **Repeat this sequence until the `state` is "SUCCEEDED", "FAILED", or "CANCELLED".**
        5.  **DO NOT generate any conversational text while you are in this polling loop.**
    *   **Once the loop terminates, you MUST generate a final summary message for the user.**
    *   **When reporting, you MUST use the `workflow_type` determined in Step 1 to decide which URLs to provide:**
        *   **Always construct the Dataform Workflow Invocation URL.**
        *   **IF the `workflow_type` was "BIGQUERY_PIPELINE", THEN ALSO construct the BigQuery UI Link.**
        *   **Provide a clear, final message to the user based on the `workflow_type` and the final job status.**

---
### **General Operating Principles**
*   **Be Proactive and Guiding:** You are a manager, not just a tool executor. Guide the user through the process. For example: "Okay, I will create a data pipeline for that task. This involves several steps: ensuring the Dataform repository and workspace are ready, generating the code, committing it, and then running the pipeline. I'll keep you updated."
*   **Clarify Intent:** Always start by confirming the user's high-level goal: are they trying to create or modify a pipeline? What kind (BigQuery or Dataform)?
*   **Gather Information:** Ask clarifying questions to get all the necessary parameters for a tool (`pipeline_name`, `repository_name`, `workspace_name`, `prompt`).
*   **Be Transparent:** Explain what you are about to do before calling a tool. After the tool runs, clearly communicate the outcome, including any important IDs (`workflow_invocation_id`) or URLs.
*   **Summarize:** At the end of an interaction, provide a concise summary of the actions taken and the final result.
*   **Error Handling:** If a tool fails, present the error messages clearly to the user. If the error implies a fixable user input issue (like a wrong workspace name), guide them on how to correct it.
"""



def normalize_bigquery_resource_names(user_prompt: str) -> dict:
    """
    Normalizes BigQuery dataset and table names within a user's prompt by
    identifying inexact references and replacing them with exact, canonical
    BigQuery resource names using an LLM for intelligent fuzzy matching.

    Args:
        user_prompt (str): The original natural language prompt from the user.

    Returns:
        dict: A dictionary containing the status, tool name, messages, and
              the results, which include the 'rewritten_prompt'.
        {
            "status": "success" or "failed",
            "tool_name": "normalize_bigquery_resource_names",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "rewritten_prompt": str
            }
        }
    """
    messages = []
    # Default to original prompt in case of failure
    rewritten_prompt = user_prompt

    try:
        messages.append("Attempting to normalize BigQuery resource names in the user prompt.")

        # 1. Fetch available datasets
        dataset_list_response = get_bigquery_dataset_list.get_bigquery_dataset_list()
        if dataset_list_response["status"] == "failed":
            messages.extend(dataset_list_response["messages"])
            raise Exception(f"Failed to retrieve BigQuery dataset list: {dataset_list_response['messages']}")


        # 2. Fetch available tables
        table_list_response = get_bigquery_table_list.get_bigquery_table_list()
        if table_list_response["status"] == "failed":
            messages.extend(table_list_response["messages"])
            raise Exception(f"Failed to retrieve BigQuery table list: {table_list_response['messages']}")

        # 3. Define the response schema for Gemini
        response_schema = {
            "type": "object",
            "properties": {
                "rewritten_prompt": {
                    "type": "string",
                    "description": "The original user prompt with all identified BigQuery dataset and table names corrected to their exact canonical forms. No additional conversational text or explanations."
                }
            },
            "required": ["rewritten_prompt"]
        }

        # 4. Construct the prompt for Gemini
        # 4. Construct the prompt for Gemini
        system_instruction_for_gemini = """
        You are a highly accurate and strict BigQuery resource name normalization assistant.
        Your sole purpose is to rewrite the 'Original User Prompt' by making all
        BigQuery dataset and table names explicit, canonical, and compliant with BigQuery naming rules.

        **Core Tasks:**
        1.  **Standardize Existing References:** For any BigQuery dataset or table mentioned that *exists* in the provided lists, replace its user-given name with its exact, canonical form (e.g., `project_id.dataset_id.table_name` or `dataset_id.table_name`).
        2.  **Validate and Format New Names:** For any *new* table name being created or proposed, convert it into a legal BigQuery table name using `snake_case` (lowercase, spaces replaced by underscores, no special characters other than underscores) and ensure it is wrapped in backticks.

        **Strict Rules for Rewriting (Adhere to all points without deviation):**
        *   **Identify All References:** Carefully scan the 'Original User Prompt' for any phrases that refer to BigQuery datasets or tables, whether they are existing or newly proposed.
        *   **Canonical Matching for Existing Resources:**
            *   When matching user-provided names (e.g., "telemetry coffee machine", "customer's table") to names in 'Available BigQuery Datasets' or 'Available BigQuery Tables', be flexible with phrasing, common synonyms, or possessive forms. Focus on identifying the core entity.
            *   **Example:** "customer's table" should be matched to a canonical table name like `customers` or `customer` from the available list.
            *   Prioritize matching the fullest possible canonical name: `project_id.dataset_id.table_name` > `dataset_id.table_name` > `table_name`.
        *   **Strict Formatting for New Names:**
            *   If the user's prompt indicates the creation of a *new* table (e.g., "create a copy of the table named 'X'", "new table Y"), the name provided for this *new* table **MUST** be converted to a BigQuery-compatible `snake_case` format.
            *   **Conversion Rule:** Convert all letters to lowercase, and replace any spaces or hyphens with single underscores. Remove any other special characters. For example, "customer 01" becomes `customer_01`. "My New Sales Report" becomes `my_new_sales_report`.
        *   **Backtick Enforcement:** Every single BigQuery dataset, table, or fully qualified name in the **rewritten prompt** MUST be enclosed in backticks (`` ` ``).
        *   **Remove Redundant Words:** When a canonical BigQuery name (especially `dataset_id.table_name` or `project_id.dataset_id.table_name`) is inserted, remove redundant surrounding words like "table", "dataset", "schema", etc., from the original prompt to make the reference concise and direct.
            *   **Example:** "the customer's table in agentic curated dataset" should be rewritten to refer directly to the canonical name, like "the table `agentic_curated.customers`" or "the table `project_id.agentic_curated.customers`".
        *   **Preserve Unrelated Text:** Only modify the BigQuery resource names. Keep all other text, instructions, and formatting (like quotes around literal strings like "unknown") from the original prompt unchanged.
        *   **Output Format:** Your final output MUST be a JSON object conforming to the provided 'Response Schema'. The JSON should contain ONLY the rewritten user prompt under the 'rewritten_prompt' key. DO NOT include any conversational text, reasoning, or additional formatting outside of the JSON structure.

        **Example Transformations to achieve the desired outcome:**
        - Original: "Create a BigQuery pipeline named "Adam Pipeline 90". For the customer's table in agentic curated dataset create a copy of the table and name it "customer 01". Set the customer name to uppercase."
        - Available Tables (illustrative, assume these exist): [`agentic_curated.customers`, `agentic_curated.customer_details`]
        - Available Datasets (illustrative): [`agentic_curated`]
        - **Rewritten (Expected):** "Create a BigQuery pipeline named "Adam Pipeline 90". For the table `agentic_curated.customers` create a copy of the table and name it `customer_01`. Set the customer name to uppercase."
        """

        gemini_user_message = f"""
        Original User Prompt:
        {user_prompt}

        Available BigQuery Datasets:        
        {json.dumps(dataset_list_response['results'], indent=2)}

        Available BigQuery Tables:
        {json.dumps(table_list_response['results'], indent=2)}
        """

        messages.append("Sending normalization request to Gemini using gemini-2.5-flash model...")
        # Call gemini_llm directly with the specified model and schema
        gemini_raw_response = gemini_helper.gemini_llm(
            prompt=gemini_user_message,
            model="gemini-2.5-flash", # Specify the model as requested
            response_schema=response_schema, # Pass the defined schema
            temperature=0.1, # Keep temperature low for deterministic-like behavior
            topK=1 # Ensure it's very focused
        )

        # 5. Parse the JSON response from Gemini
        try:
            gemini_response_json = json.loads(gemini_raw_response)
            rewritten_prompt = gemini_response_json.get("rewritten_prompt", user_prompt)
            # Ensure no extra markdown from JSON wrapping if gemini_llm didn't clean it fully
            rewritten_prompt = rewritten_prompt.strip().lstrip("```json").rstrip("```")

        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse Gemini's JSON response for normalization: {e}. Raw: {gemini_raw_response}", exc_info=True)
            messages.append(f"Failed to parse Gemini's response. Using original prompt. Error: {e}")
            # If parsing fails, fall back to the original prompt
            rewritten_prompt = user_prompt
        except KeyError as e:
            logger.error(f"Missing 'rewritten_prompt' key in Gemini's response: {e}. Raw: {gemini_raw_response}", exc_info=True)
            messages.append(f"Gemini response missing 'rewritten_prompt'. Using original prompt. Error: {e}")
            rewritten_prompt = user_prompt

        messages.append(f"Original Prompt: \"{user_prompt}\"")
        messages.append(f"Rewritten Prompt: \"{rewritten_prompt}\"")
        logger.info(f"BigQuery Name Normalization: Original: '{user_prompt}' -> Rewritten: '{rewritten_prompt}'")

        return {
            "status": "success",
            "tool_name": "normalize_bigquery_resource_names",
            "query": None,
            "messages": messages,
            "results": {
                "rewritten_prompt": rewritten_prompt
            }
        }

    except Exception as e:
        error_message = f"An error occurred during BigQuery name normalization: {e}"
        messages.append(error_message)
        logger.error(error_message, exc_info=True)
        return {
            "status": "failed",
            "tool_name": "normalize_bigquery_resource_names",
            "query": None,
            "messages": messages,
            "results": {
                "rewritten_prompt": user_prompt # Return original prompt on failure
            }
        }