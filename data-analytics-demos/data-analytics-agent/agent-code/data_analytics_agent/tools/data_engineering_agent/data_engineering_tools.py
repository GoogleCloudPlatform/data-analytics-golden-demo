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
import logging

import data_analytics_agent.utils.rest_api.rest_api_helper as rest_api_helper 
import data_analytics_agent.utils.gemini.gemini_helper as gemini_helper
import data_analytics_agent.tools.dataplex.dataquality_tools as dataquality_tools
import data_analytics_agent.tools.bigquery.bigquery_execute_sql_tools as bigquery_execute_sql_tools

logger = logging.getLogger(__name__)


def _trim_trailing_zeros_string(s_number):
    """
    Trims trailing zeros from a string representation of a number.
    Assumes the input is a string.

    BigQuery can return 10.030000000 for 10.03 and we do not need the trailing zeros which
    will confuse the RegEx.
    """
    if not isinstance(s_number, str):
        s_number = str(s_number) # Convert to string if not already

    s_number = s_number.rstrip('0')
    if s_number.endswith('.'):
        s_number = s_number.rstrip('.')
    return s_number


async def call_bigquery_data_engineering_agent(repository_name: str, workspace_name: str, prompt: str) -> dict:
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

    #agent_project_id = "governed-data-1pqzajgatl" # This is hardcoded to an allow list project.
    agent_project_id = project_id

    # NOTE: Do not take a hard dependency on this REST API call, it will be changing in the future!
    url = f"https://geminidataanalytics.googleapis.com/v1alpha1/projects/{agent_project_id}/locations/global:run"

    pipeline_id = f"projects/{project_id}/locations/{dataform_region}/repositories/{repository_name}/workspaces/{workspace_name}"

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

        json_result = await rest_api_helper.rest_api_helper(url, "POST", request_body)

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


async def llm_as_a_judge(user_prompt: str, agent_tool_raw_output: list) -> dict:
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

        additional_judge_prompt_instructions = """
        - Only focus on if the pipeline tasks have been completed.
        - Do not focus on other infrastructure tasks that are part of the original prompt.
        - Look for a success message around the transformations requested.
        - Do not be overly critical of every detail, concentrate if the overall process was a success.
        """

        satisfactory, reasoning = await gemini_helper.llm_as_a_judge(additional_judge_prompt_instructions, user_prompt, agent_output_summary)

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


async def check_data_quality_failures(data_quality_scan_name: str) -> dict:
    """
    Checks if there are any failed data quality records for a given scan.

    Args:
        data_quality_scan_name (str): The name of the data quality scan.

    Returns:
        dict: A dictionary containing the status, messages, and the count of failed rows.
        {
            "status": "success" or "failed",
            "tool_name": "check_data_quality_failures",
            "query": None,
            "messages": ["List of messages during processing"],
            "data_quality_scan_dataset_name" : "The data quality scan dataset id/name for downstream tools",
            "data_quality_scan_table_name" : "The data quality scan table name for downstream tools",
            "results": {"failed_row_count": int}
        }
    """
    response = {
        "status": "success",
        "tool_name": "check_data_quality_failures",
        "query": None,
        "messages": [],
        "data_quality_scan_dataset_name" : None,
        "data_quality_scan_table_name" : None,
        "results": {"failed_row_count": 0}
    }
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")

    response["messages"].append(f"Geting the data quality scan in order to determine the output results table")
    get_data_quality_scan_result = await dataquality_tools.get_data_quality_scan(data_quality_scan_name)

    if get_data_quality_scan_result["status"] == "failed":
        response["status"] = "failed"
        response["messages"].extend(get_data_quality_scan_result["messages"])
        response["messages"].append(f"Could not find data quality scan of: {data_quality_scan_name}")
        return response

    if "dataQualitySpec" not in get_data_quality_scan_result["results"]:
        response["status"] = "failed"
        response["messages"].extend(get_data_quality_scan_result["messages"])
        response["messages"].append(f"The data quality scan {data_quality_scan_name} does not have a 'dataQualitySpec' attribute meaning it did not save the results to an output table.")
        return response

    if "postScanActions" not in get_data_quality_scan_result["results"]["dataQualitySpec"]:
        response["status"] = "failed"
        response["messages"].extend(get_data_quality_scan_result["messages"])
        response["messages"].append(f"The data quality scan {data_quality_scan_name} does not have a 'postScanActions' attribute meaning it did not save the results to an output table.")
        return response

    if "bigqueryExport" not in get_data_quality_scan_result["results"]["dataQualitySpec"]["postScanActions"]:
        response["status"] = "failed"
        response["messages"].extend(get_data_quality_scan_result["messages"])
        response["messages"].append(f"The data quality scan {data_quality_scan_name} does not have a 'bigqueryExport' attribute meaning it did not save the results to an output table.")
        return response

    if "resultsTable" not in get_data_quality_scan_result["results"]["dataQualitySpec"]["postScanActions"]["bigqueryExport"]:
        response["status"] = "failed"
        response["messages"].extend(get_data_quality_scan_result["messages"])
        response["messages"].append(f"The data quality scan {data_quality_scan_name} does not have a 'resultsTable' attribute meaning it did not save the results to an output table.")
        return response

    split_string = get_data_quality_scan_result["results"]["dataQualitySpec"]["postScanActions"]["bigqueryExport"]["resultsTable"].split('/')
    data_quality_scan_dataset_name = split_string[6]
    data_quality_scan_table_name = split_string[8]

    response["messages"].append(f"Succesfully determined the data_quality_scan_dataset_name ({data_quality_scan_dataset_name}) and data_quality_scan_table_name ({data_quality_scan_table_name}) values from the data quality scan.")
    response["data_quality_scan_dataset_name"] = data_quality_scan_dataset_name
    response["data_quality_scan_table_name"] = data_quality_scan_table_name

    sql = f"""SELECT COUNT(*) AS FailedCount
                FROM `{project_id}.{data_quality_scan_dataset_name}.{data_quality_scan_table_name}`
                WHERE data_quality_job_id = (SELECT data_quality_job_id
                                                FROM `{project_id}.{data_quality_scan_dataset_name}.{data_quality_scan_table_name}`
                                            WHERE data_quality_scan. data_scan_id = '{data_quality_scan_name}'
                                                AND job_start_time = (SELECT MAX(job_start_time)
                                                                        FROM `{project_id}.{data_quality_scan_dataset_name}.{data_quality_scan_table_name}`
                                                                        WHERE data_quality_scan.data_scan_id = '{data_quality_scan_name}')
                                            LIMIT 1)
                AND rule_passed = FALSE;"""

    logger.debug(f"check_data_quality_failures SQL: {sql}")
    count_query_result = await bigquery_execute_sql_tools.run_bigquery_sql(sql)

    if count_query_result["status"] == "failed":
        response["messages"].append(f"Failed to run SQL (count failed rows): {sql}")
        response["messages"].extend(count_query_result["messages"])
        response["status"] = "failed"
        return response

    failed_row_count = int(count_query_result["results"][0]["FailedCount"])
    response["results"]["failed_row_count"] = failed_row_count
    response["messages"].append(f"Found {failed_row_count} failed data quality records.")
    return response


async def get_data_quality_failure_analysis(data_quality_scan_name: str,
                                      data_quality_scan_dataset_name: str,
                                      data_quality_scan_table_name: str) -> dict:
    """
    Retrieves detailed analysis of data quality failures, including bad data samples.

    Args:
        data_quality_scan_name (str): The name of the data quality scan.
        data_quality_scan_dataset_name (str): The dataset name of the data quality results table.
        data_quality_scan_table_name (str): The table name of the data quality results table.

    Returns:
        dict: A dictionary containing the status, messages, and a list of failed rule details.
        {
            "status": "success" or "failed",
            "tool_name": "get_data_quality_failure_analysis",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {"failed_rules_details": list[dict]}
        }
    """
    response = {
        "status": "success",
        "tool_name": "get_data_quality_failure_analysis",
        "query": None,
        "messages": [],
        "results": {"failed_rules_details": []}
    }
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")

    sql = f"""SELECT data_source.dataset_id, data_source.table_id, rule_column, rule_parameters, rule_failed_records_query
               FROM `{project_id}.{data_quality_scan_dataset_name}.{data_quality_scan_table_name}`
              WHERE data_quality_job_id = (SELECT data_quality_job_id
                                             FROM `{project_id}.{data_quality_scan_dataset_name}.{data_quality_scan_table_name}`
                                            WHERE data_quality_scan.data_scan_id = '{data_quality_scan_name}'
                                              AND job_start_time = (SELECT MAX(job_start_time)
                                                                      FROM `{project_id}.{data_quality_scan_dataset_name}.{data_quality_scan_table_name}`
                                                                     WHERE data_quality_scan.data_scan_id = '{data_quality_scan_name}')
                                           LIMIT 1)
              AND rule_passed = FALSE;"""

    logger.debug(f"get_data_quality_failure_analysis SQL (get failed rules): {sql}")
    failed_rows_result = await bigquery_execute_sql_tools.run_bigquery_sql(sql)

    if failed_rows_result["status"] == "failed":
        response["messages"].append(f"Failed to run SQL (get failed rules): {sql}")
        response["messages"].extend(failed_rows_result["messages"])
        response["status"] = "failed"
        return response

    for row in failed_rows_result["results"]:
        rule_column = row["rule_column"]
        rule_parameters = row["rule_parameters"]
        rule_failed_records_query = row["rule_failed_records_query"]

        sql_bad_data = rule_failed_records_query.replace("SELECT *",f"SELECT {rule_column}")
        failed_data_result = await bigquery_execute_sql_tools.run_bigquery_sql(sql_bad_data)

        if failed_data_result["status"] == "failed":
            response["messages"].append(f"Failed to run SQL (Data Quality Failed Rows): {sql_bad_data}")
            response["messages"].extend(failed_data_result["messages"])
            response["status"] = "failed"
            return response

        bad_values_list = []
        for failed_row in failed_data_result["results"]:
            value = _trim_trailing_zeros_string(failed_row[f"{rule_column}"])
            bad_values_list.append(value)

        response["results"]["failed_rules_details"].append({
            "rule_column": rule_column,
            "rule_parameters": rule_parameters,
            "bad_values": bad_values_list
        })
    response["messages"].append("Successfully retrieved data quality failure analysis.")
    return response


async def generate_data_engineering_fix_prompt(analysis_results: list) -> dict:
    """
    Generates a natural language prompt for the Data Engineering Agent based on data quality analysis.

    Args:
        analysis_results (list): A list of dictionaries, each containing details about a failed rule,
                                 including 'rule_column', 'rule_parameters', 'bad_values'.

    Returns:
        dict: A dictionary containing the status, messages, and the generated prompt string.
        {
            "status": "success" or "failed",
            "tool_name": "generate_data_engineering_fix_prompt",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {"data_engineering_prompt": str}
        }
    """
    response = {
        "status": "success",
        "tool_name": "generate_data_engineering_fix_prompt",
        "query": None,
        "messages": [],
        "results": {"data_engineering_prompt": ""}
    }

    column_prompts_xml = ""
    for rule_detail in analysis_results:
        rule_column = rule_detail["rule_column"]
        # rule_parameters is a dict like {"regex": "^\\d+(\\.\\d+)?$"}
        # Ensure it's stringified if it's not already a string
        rule_parameters_str = json.dumps(rule_detail["rule_parameters"]) if isinstance(rule_detail["rule_parameters"], dict) else str(rule_detail["rule_parameters"])

        bad_values = rule_detail["bad_values"]

        bad_values_xml = f"<invalid-values-for-{rule_column}>\n"
        for value in bad_values:
            # Escape XML special characters in values if necessary, though for numbers/percentages, it's usually fine.
            # For general robustness, consider: value = value.replace('&', '&amp;').replace('<', '&lt;')...
            bad_values_xml += f"<value>{value}</value>\n"
        bad_values_xml += f"</invalid-values-for-{rule_column}>\n"

        column_prompts_xml += f"""<column-{rule_column}>
        Column Name: {rule_column}
        RegEx: {rule_parameters_str}

        {bad_values_xml}

        </column-{rule_column}>
        """

    # Updated meta-prompt
    data_engineering_agent_meta_prompt = f"""There is a broken data engineering pipeline that needs correction.
I have the below column(s) that have failed a data quality check.
The data quality check is using regular expressions to test for data integrity.
For each column listed, please generate short, direct, and actionable prompts for a data engineering agent to correct the ETL process.

**Workflow for each column:**
1.  **Analyze `bad_values` and `RegEx` (expected good format):**
    *   Examine the provided `<value>` entries within `<invalid-values-for-{rule_column}>` and compare them against the `RegEx` (which defines the expected good format).
    *   Identify distinct patterns of invalid data and determine the necessary correction action for each.
2.  **Derive Exact Match Regular Expressions and Correction Actions:**
    *   For each *type of correction* required for a column (e.g., removing a suffix, or scaling a number), identify all specific bad data patterns that necessitate that correction.
    *   Create a regular expression that precisely matches these invalid data patterns. This regex **must** be an "exact match" with "no optional lengths" (i.e., use `\d{{n}}` or `.` without `+` or `*`).
    *   If multiple distinct fixed-length patterns for a column require the *same correction action*, combine their individual exact-match regexes using the `|` (OR) operator within a non-capturing group `(?:...)`. Example: `(?:\d{{2}}\.\d{{1}}%|\d{{2}}\.\d{{2}}%)`.
    *   Determine the specific correction action:
        *   If the bad values contain a suffix (e.g., `%`, `° Celsius`, ` Liters`) that is not allowed by the `RegEx` for the column, the action is "remove the 'SUFFIX' suffix".
        *   If the bad values are decimal numbers (e.g., `0.XXXX`) that *match* a pattern like `0\.\d{{4}}` or `0\.\d{{3}}` *and* the column name strongly implies a percentage (e.g., `_percent`, `_pct`) *and* the `RegEx` (expected good format) implies a number that *should* be between 0-100 (e.g., `^\\d+(\\.\\d{{1,2}})?$`), the action is "multiply by 100".
        *   (You can extend these rules for other common data quality issues as needed in future iterations.)
3.  **Formulate Correction Prompt(s):**
    *   For each unique combination of a derived exact-match regex and its corresponding correction action, construct a separate prompt for the data engineering agent.

**Example Output Prompt Format (note multiple lines for a single column if different issues or fix types arise):**
- Correct column 'item_cost' by testing for '(?:\$\d{{3}}\.\d{{2}}|\$\d{{2}}\.\d{{2}})' and remove the '$' character.
- Correct column 'inventory_status' by testing for 'QTY-\d{{4}}' and remove the 'QTY-' prefix.
- Correct column 'sensor_humidity_reading' by testing for '\d{{2}}\.\d{{1}}%' and remove the '%' character.
- Correct column 'water_level_pct' by testing for '0\.\d{{4}}' and multiply by 100.
- Correct column 'temperature_kelvin' by testing for '(?:\d{{3}}K|\d{{2}}K)' and remove the 'K' suffix.

**Here is the data in XML format for analysis:**

<data-for-correction>
{column_prompts_xml}
</data-for-correction>
"""

    response["messages"].append(f"Meta-prompt for Data Engineering Agent: {data_engineering_agent_meta_prompt}")

    # The response_schema remains the same as provided by the user
    response_schema = {
        "type": "object",
        "required": [
            "generated_prompts"
        ],
        "properties": {
            "generated_prompts": {
            "type": "array",
            "items": {
                "type": "object",
                "required": [
                    "column_prompt"
                ],
                "properties": {
                    "column_prompt": {
                        "type": "string"
                    }
                }
            }
            }
        }
    }

    logger.info(f"Autonomous: data_engineering_agent_meta_prompt: {data_engineering_agent_meta_prompt}")
    # Call the LLM with the generated meta-prompt and the expected response schema
    generated_prompt_response = await gemini_helper.gemini_llm(data_engineering_agent_meta_prompt, response_schema=response_schema)

    data_engineering_agent_prompt_str = ""
    # Ensure the JSON parsing is robust
    try:
        parsed_response = json.loads(generated_prompt_response)
        # Iterate over the list of prompts and concatenate them
        for item in parsed_response.get("generated_prompts",[]):
            data_engineering_agent_prompt_str += item.get("column_prompt", "") + "\n"
    except json.JSONDecodeError as e:
        response["status"] = "failed"
        response["messages"].append(f"Failed to parse LLM response: {e}. Raw response: {generated_prompt_response}")
        return response

    logger.info(f"Autonomous: data_engineering_agent_prompt: {data_engineering_agent_prompt_str}")
    response["results"]["data_engineering_prompt"] = data_engineering_agent_prompt_str.strip() # .strip() to remove trailing newline
    response["messages"].append(f"Generated Data Engineering Prompt: {data_engineering_agent_prompt_str.strip()}")
    return response


async def normalize_bigquery_resource_names(user_prompt: str) -> dict:
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
        dataset_list_response = await get_bigquery_dataset_list.get_bigquery_dataset_list()
        if dataset_list_response["status"] == "failed":
            messages.extend(dataset_list_response["messages"])
            raise Exception(f"Failed to retrieve BigQuery dataset list: {dataset_list_response['messages']}")


        # 2. Fetch available tables
        table_list_response = await get_bigquery_table_list.get_bigquery_table_list()
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
        gemini_raw_response = await gemini_helper.gemini_llm(
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