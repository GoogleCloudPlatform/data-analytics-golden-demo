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
import json
import logging
import os

# Assuming data_analytics_agent.bigquery.run_bigquery_sql.run_bigquery_sql is available
import data_analytics_agent.bigquery.run_bigquery_sql as bq_sql

logger = logging.getLogger(__name__)

ai_generate_bool_agent_instruction = """You are a specialized, **autonomous AI.GENERATE_BOOL Agent**. Your core purpose is to act as a **semantic filter** for data stored in Google BigQuery. You take a user's natural language request (e.g., "which products are coffee?") and use BigQuery ML's `AI.GENERATE_BOOL` function to find all rows that match that conceptual criteria, whether in text or image data.

You must operate autonomously without asking for clarification. If any step fails, you must generate a detailed failure report.

**Available Tools (You MUST only call functions from this list):**
*   `get_bigquery_table_list()`: Discovers available BigQuery tables and their schemas.
*   `get_bigquery_table_schema(dataset_id: str, table_name: str)`: Fetches the detailed schema for a specific table.
*   `execute_ai_generate_bool(dataset_id: str, table_name: str, search_column: str, is_image_column: bool, question: str, select_columns: list)`: Executes the `AI.GENERATE_BOOL` query against a specified column and returns the matching rows.

**Your Operational Playbook (You MUST follow this sequence):**

**Step 1: Understand the Data Landscape and Identify Target Table**
*   Your first action is to use `get_bigquery_table_list()` to see all available tables.
*   Analyze the user's request and the table schemas to **autonomously determine the single most appropriate table** for the query.

**Step 2: Identify the Target Column and Prepare the Question**
*   Once a table is selected, use `get_bigquery_table_schema()` to get its detailed column information.
*   Analyze the user's question (e.g., "which products are coffee?", "which images show a cold brew?") and the schema to **autonomously identify the single most relevant column** to search.
*   **Translate the User's Question:** Before passing the question to the tool, you **MUST** re-frame it as a simple, singular boolean question that applies to a single row. For example, if the user asks "Show me all images that have latte art," you must transform this into a question like "Does this image contain latte art?" for the `question` parameter.
*   **Heuristics for Column Selection:**
    *   For questions about text ("what is...", "which product is..."), you MUST select a column of type `STRING`. Prioritize columns with names like `name`, `description`, `title`.
    *   For questions about images ("which image contains...", "is there a picture of..."), you MUST select a column with the specific type `STRUCT<uri STRING, version STRING, authorizer STRING, details JSON>`. This is the only supported format for image queries.
    *   If you identify a valid image column, you will pass its name to the `execute_ai_generate_bool` tool and set the `is_image_column` parameter to `True`.
*   **Self-Correction:** If you cannot identify a single, clear target column of type `STRING` or the specific `STRUCT` for images, you MUST immediately report a failure.

**Step 3: Determine Columns to Return**
*   From the table schema, identify the most relevant columns to display to the user in the final result. This should typically include primary key or name/identifier columns (e.g., `product_id`, `product_name`, `product_description`).
*   **CRITICAL:** If you are performing an image search (i.e., you identified a `STRUCT` column in Step 2), you **MUST NOT** include the image column itself (neither the `STRUCT` nor any related `_uri` `STRING` column) in the `select_columns` list. The tool will **automatically** add a clickable `signed_url` to the results for you.

**Step 4: Execute the AI.GENERATE_BOOL Query**
*   Call the `execute_ai_generate_bool(...)` tool with all the parameters determined in the previous steps: `dataset_id`, `table_name`, `search_column`, `is_image_column`, the re-framed `question`, and the `select_columns`.

**Step 5: Display Final Results**
*   After the `execute_ai_generate_bool` tool successfully returns a result, your task is complete.
*   You MUST directly output the Markdown-formatted results provided by the tool.
*   DO NOT attempt to summarize, re-format, or add any commentary. The raw tool output is the final answer.

---

**Security and Safety Guardrails:**
*   **READ-ONLY:** You MUST NOT construct or execute any SQL statements that modify data (`INSERT`, `UPDATE`, `DELETE`, etc.). Your sole purpose is to execute `SELECT` queries using the provided tools.
*   **TOOL RELIANCE:** Rely **EXCLUSIVELY** on the tools listed above. Do not invent tool parameters, table names, or column names.
"""

def execute_ai_generate_bool(
    dataset_id: str,
    table_name: str,
    search_column: str,
    is_image_column: bool,
    question: str,
    select_columns: list
) -> dict:
    """
    Executes a BigQuery AI.GENERATE_BOOL query to filter rows based on a natural language question.
    If the query is on an image column, it automatically generates a signed URL for viewing.

    Args:
        dataset_id (str): The BigQuery dataset ID.
        table_name (str): The name of the table to query.
        search_column (str): The name of the column containing the text or image struct to analyze.
        is_image_column (bool): Set to True if the search_column is an image struct, False otherwise.
        question (str): The natural language question to evaluate (e.g., 'Is this coffee?').
        select_columns (list[str]): A list of column names to return in the final result.

    Returns:
        dict: A dictionary conforming to the agent's tool output schema with the query results.
    """
    tool_name = "execute_ai_generate_bool"
    messages = []

    # --- Get configuration from environment variables ---
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    region = os.getenv("AGENT_ENV_VERTEX_AI_REGION")
    endpoint = os.getenv("VERTEX_AI_ENDPOINT", "gemini-1.5-flash")
    connection_name = os.getenv("VERTEX_AI_CONNECTION_NAME", "vertex-ai")

    # --- Input Validation ---
    if not all([project_id, region]):
        messages.append("Configuration Error: AGENT_ENV_PROJECT_ID and AGENT_ENV_VERTEX_AI_REGION must be set as environment variables.")
        return {"status": "failed", "tool_name": tool_name, "messages": messages, "results": None}

    if not all([dataset_id, table_name, search_column, question, select_columns]):
        messages.append("Input Error: All parameters (dataset_id, table_name, search_column, question, select_columns) must be provided.")
        return {"status": "failed", "tool_name": tool_name, "messages": messages, "results": None}

    # --- Construct the Query ---
    connection_id = f"{project_id}.{region}.{connection_name}"
    fully_qualified_table = f"`{project_id}.{dataset_id}.{table_name}`"
    
    # The column to use inside the AI function's WHERE clause
    ai_function_target_column = f"{search_column}" if is_image_column else search_column

    # --- Construct the SELECT clause ---
    # This logic now robustly handles the select list for image queries.
    final_select_list = []
    if is_image_column:
        # For image searches, filter out the struct column and any confusing URI columns.
        for col in select_columns:
            # Add the column only if it's NOT the image struct itself or a related URI string.
            if col != search_column and '_uri' not in col:
                final_select_list.append(f"`{col}`")
        # ALWAYS add the signed URL function call for image queries.
        # This creates a URL that is too long to display in the Agent (it causes issues when the LLM formats it)
        # final_select_list.append(f"JSON_VALUE(OBJ.GET_ACCESS_URL({search_column},'r'),'$.access_urls.read_url') AS signed_url")
        # Use the authorized URL
        final_select_list.append(f"REPLACE({search_column}.uri, 'gs://', 'https://storage.cloud.google.com/') AS signed_url")

    else:
        # For non-image queries, just quote all requested columns.
        final_select_list = [f"`{col}`" for col in select_columns]

    select_clause = ", ".join(final_select_list)
    
    # Prevent empty SELECT clause
    if not select_clause:
        messages.append("Query construction failed: The final list of columns to select was empty.")
        return {"status": "failed", "tool_name": tool_name, "messages": messages, "results": None}

    # thinking_budget set to zero for none, -1 is unlimited or do you can a integer
    query = f"""
    SELECT
      {select_clause}
    FROM
      {fully_qualified_table}
    WHERE AI.GENERATE_BOOL(
      ('{question}', {ai_function_target_column}),
      connection_id => '{connection_id}',
      endpoint => '{endpoint}',
      model_params => JSON '{{"generation_config":{{"thinking_config": {{"thinking_budget": 0}}}}}}'
    ).result = TRUE;
    """

    # --- Execute the Query ---
    try:
        logger.debug(f"[{tool_name}] Executing SQL: {query}")
        query_result = bq_sql.run_bigquery_sql(query)
        logger.debug(f"[{tool_name}] BigQuery SQL result: {json.dumps(query_result, indent=2)}")

        if query_result["status"] == "failed":
            messages.append("The AI.GENERATE_BOOL query failed to execute.")
            messages.extend(query_result["messages"])
            return {"status": "failed", "tool_name": tool_name, "query": query, "messages": messages, "results": None}


        results = query_result.get("results", [])
        
        if not results:
            formatted_string = "No matching results were found for the query."
        else:
            output_parts = ["Here are the results that matched your query:\n"]
            
            # Use enumerate to get a row number, starting from 1
            for i, row in enumerate(results, start=1):
                output_parts.append(f"*   **Result {i}:**")
                
                # Loop through each key-value pair in the row dictionary
                for key, value in row.items():
                    # Skip the raw ai_analysis struct, it's not for display
                    if key == 'ai_analysis':
                        continue

                    # Special formatting for the signed_url
                    if key == 'signed_url' and value:
                        output_parts.append(f"    *   **Image:** [View image](<{value}>)")  # Must use < > since the UI will change the link otherwise (UI thing)
                    else:
                        # Generic formatting for all other fields
                        # Makes the key human-readable (e.g., product_name -> Product Name)
                        formatted_key = key.replace('_', ' ').title()
                        output_parts.append(f"    *   **{formatted_key}:** {value}")
            
            output_parts.append("\nThis concludes the list of matching results.")
            formatted_string = "\n".join(output_parts)
        
        messages.append("Successfully executed the query and formatted the results for display.")
        return {"status": "success", "tool_name": tool_name, "query": query, "messages": messages, "results": formatted_string}

    except Exception as e:
        messages.append(f"An unexpected error occurred during execution: {e}")
        logger.error(f"[{tool_name}] Unexpected Error: {e}", exc_info=True)
        return {"status": "failed", "tool_name": tool_name, "query": query, "messages": messages, "results": None}