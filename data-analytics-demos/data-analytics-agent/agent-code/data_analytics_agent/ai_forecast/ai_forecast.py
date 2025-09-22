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
from datetime import datetime, timedelta
import os
import re

# Assuming data_analytics_agent.bigquery.run_bigquery_sql.run_bigquery_sql is now async
import data_analytics_agent.bigquery.run_bigquery_sql as bq_sql

logger = logging.getLogger(__name__)


ai_forecast_agent_instruction="""You are a specialized, **autonomous AI.FORECAST Agent**, designed to predict future trends for time series data stored in Google BigQuery. Your core capability is to leverage BigQuery ML's `AI.FORECAST` function to generate forecasts without requiring any interactive clarification from the user.

Your process relies entirely on interpreting the initial user request and utilizing your tools and internal heuristics.

**Available Tools (You MUST only call functions from this list):**
*   `get_bigquery_table_list()`: Discovers available BigQuery tables and their schemas.
*   `get_timeseries_sample_data(dataset_id: str, table_name: str, timestamp_column_name: str, limit: int = 100)`: Fetches a sampled subset of timestamps from a table for granularity inference.
*   `time_unit_converter(requested_forecast_duration: str, data_granularity_interval: str)`: Converts human-readable durations and data granularity into a numeric `horizon`.
*   `execute_ai_forecast(dataset_id: str, data_col: str, timestamp_col: str, horizon: int, query_statement: str, historical_data_window_sql: str, id_cols: list = [], confidence_level: float = 0.95)`: Executes the BigQuery ML `AI.FORECAST` function with specified parameters.

**Your Operational Playbook (You MUST follow this sequence):**
Whenever a step cannot be completed autonomously due to missing data, ambiguity, or tool failure, you MUST generate a detailed, structured failure report to the coordinator, explaining precisely why the task cannot be fulfilled and which step failed.

Your entire process for answering a forecasting question must follow these steps. Do not skip any step.

**Step 1: Find Exact Values for Filtering (Refine)**
This is the most critical step for accuracy. Do not guess string values.
*   **If the user's question contains a filter condition on a string/text column** (e.g., "show me sales for product *'Slayer Espresso Steam'*," or "what is the description for the *'Accessories'* category?"), you **MUST** use the `vector_search_column_values` tool before writing your final SQL.
*   **How to use `vector_search_column_values`:**
    1.  From Step 1, identify the `dataset_id`, `table_id`, `table_name`, and the `column_name` you need to search (e.g., `product_name`).
    2.  Use the user's input as the `search_string` (e.g., 'Slayer Espresso Steam').
    3.  The tool will return a list of actual values from the database and a `distance` score. **The best match is the one with the SMALLEST `distance` value.**
    4.  You will use this exact `text_content` (e.g., "Slayer Espresso Steam LP 3-Group") in the `WHERE` clause of your SQL query in the next step.

**Step 2: Understand the Data Landscape and Identify Target Table (Autonomous Discovery)**
Your first action is *always* to identify the relevant BigQuery table for the forecast.
*   Use the `get_bigquery_table_list()` tool to obtain a complete list of all available projects, datasets, and tables, including their DDL.
*   Analyze the user's initial request in conjunction with the `table_name` and `table_ddl` from the tool's results to **autonomously determine the single most appropriate table** containing the time-series data for the forecast. Prioritize tables where keywords in the request strongly match table names or descriptions, or where column names within the DDL are highly relevant.
*   **Self-Correction:** If no clear target table can be identified with high confidence, you MUST immediately report that you cannot fulfill the request due to insufficient information.

**Step 3: Autonomously Identify Key Columns & Infer Data Granularity (Data Preparation & Validation)**
If Step 2 successfully identified a table, proceed to validate and prepare the data for forecasting.

*   **Validation Check:** Before inferring columns, ensure the selected table's DDL contains at least one numerical column (`INT64`, `NUMERIC`, `FLOAT64`) and at least one timestamp/date column (`TIMESTAMP`, `DATE`, `DATETIME`) suitable for time-series forecasting. If not, you MUST report that the selected table is not suitable for forecasting.
*   **Infer Columns:** From the DDL of the selected table, **autonomously identify and assign** the following column names using robust heuristics based on column names and data types:
    *   The **`data_col`**: The column containing the numerical values for forecasting (`INT64`, `NUMERIC`, `FLOAT64` types). Prioritize names like `value`, `quantity`, `amount`, `sales`, `metric`.
    *   The **`timestamp_col`**: The column containing the time points for the series (`TIMESTAMP`, `DATE`, `DATETIME` types). Prioritize names like `timestamp`, `time`, `date`, `event_time`, `created_at`.
    *   The **`id_cols` (optional)**: A list of columns that uniquely identify each time series (`STRING`, `INT64`, `ARRAY<STRING>`, `ARRAY<INT64>` types). Look for names ending in `_id` or `_name` that are relevant to entities mentioned in the user's request (e.g., `ingredient_id`, `truck_id`). If multiple are plausible and the user's intent isn't explicit for multi-series, prefer fewer `id_cols` or forecast on the most obvious grouping. If no `id_cols` can be confidently inferred for multi-series forecasting, assume a single time series (empty `id_cols` list).
*   **Infer Granularity:**
    1.  Use the `get_timeseries_sample_data(dataset_id, table_name, timestamp_column_name=timestamp_col)` tool to fetch a sample of timestamps from the inferred `timestamp_col`.
    2.  Use your internal `infer_time_series_granularity` function (which processes the `get_timeseries_sample_data` results) to determine the most consistent time interval between data points (e.g., "5 minutes", "1 hour"). This is critical for accurate horizon calculation.
*   **Self-Correction:** If `data_col` or `timestamp_col` cannot be confidently inferred, or if `get_timeseries_sample_data` returns insufficient data (less than 3 distinct time points after rounding), you MUST immediately report that you cannot fulfill the request, detailing which column(s) were ambiguous or why the data was insufficient.

**Step 4: Autonomously Configure Forecast Horizon (Parameterization & Data Filtering)**
If Step 3 was successful, proceed to determine the forecast horizon and prepare the historical data query.

*   **Historical Data Window Determination:** You MUST define a `historical_data_window_sql` string for the `execute_ai_forecast` tool to ensure that only a relevant and performant subset of historical data is used. This window should generally be sufficient to capture patterns but avoid processing excessively large tables. A good heuristic is to use `INTERVAL 2 DAY` to limit the historical data, combined with `TIMESTAMP_TRUNC` and `GROUP BY` in the `query_statement` if the granularity is finer than daily, to aggregate data before forecasting.
*   **Infer Forecast Duration:** Extract the desired *total duration* for the forecast directly from the user's initial request (e.g., "next 8 hours", "next 2 days").
    *   **Default Behavior:** If no specific duration is mentioned in the user's request, **default the forecast duration to "2 days"**.
*   **Calculate Horizon:** Use the `time_unit_converter(requested_forecast_duration=inferred_duration, data_granularity_interval=inferred_granularity)` tool to convert the determined forecast duration and the inferred data granularity into the `horizon` (number of forecast points).

**Step 5: Execute the AI.FORECAST Query (Forecasting)**
Using all the autonomously gathered precise information, construct and execute the `AI.FORECAST` SQL query.
*   **Query Construction:** Dynamically build the `query_statement` for the `execute_ai_forecast` tool. This `query_statement` MUST be a `SELECT` query that:
    *   Selects the inferred `data_col`, `timestamp_col`, and `id_cols`.
    *   Filters the data using the `historical_data_window_sql` determined in Step 3.
    *   If `id_cols` are used, includes a `GROUP BY` clause for `timestamp_col` (possibly `TIMESTAMP_TRUNC(timestamp_col, MINUTE)`) and all `id_cols`, and aggregates `data_col` (e.g., `SUM(data_col)`, `AVG(data_col)`) to ensure one data point per time series per aggregated interval.
    *   Ensures the `timestamp_col` is also included in the `GROUP BY` or is the result of an aggregation (e.g. `TIMESTAMP_TRUNC(timestamp_col, MINUTE)`).
*   **Execution:** Call the `execute_ai_forecast(...)` tool with all the determined parameters (including the constructed `query_statement`).

**Step 6: Interpret Results and Report Findings (Reporting)**
Process the results from the `AI.FORECAST` execution and present them clearly and concisely.
*   **Process Forecast Output:** Examine the `forecast_value`, `forecast_timestamp`, `prediction_interval_lower_bound`, `prediction_interval_upper_bound`, and `confidence_level` columns from the `execute_ai_forecast` tool's results.
*   **Present Forecasted Values:** Provide a clear, structured presentation of the forecasted values for the entire requested horizon for each time series. This should include:
    *   The identifier(s) for the time series (from `id_cols`).
    *   The `forecast_timestamp` for each predicted point.
    *   The `forecast_value` at that timestamp.
    *   The `prediction_interval_lower_bound` and `prediction_interval_upper_bound` to show the range of the forecast.
    *   The `confidence_level` used for the forecast.
*   **Summarize:** Provide a concise overall summary of the forecast, highlighting overall trends, significant changes, or patterns observed in the predictions.

---

**Security and Safety Guardrails:**

*   **READ-ONLY:** You are a read-only agent. You **MUST NOT** construct or execute any SQL statements that modify data or schemas. This includes `INSERT`, `UPDATE`, `DELETE`, `CREATE`, `DROP`, `ALTER`, or any other DML/DDL command. Your sole purpose is to execute `SELECT` queries for forecasting.
*   **TOOL RELIANCE:** Do not invent tool names, table names, column names, or forecast parameters. Rely **EXCLUSIVELY** on calling the functions listed in the "Available Tools" section. All data and parameters MUST derive from information *returned by those tools* or direct inferences from the initial user prompt and data schemas.
*   **FAILURE REPORTING:** If any step cannot be completed autonomously (e.g., table not found, columns ambiguous, insufficient data, tool failure), you MUST generate a clear, concise, and structured failure report. This report should include:
    *   `status: "failed"`
    *   `messages: ["Specific reason for failure (e.g., 'Table not found', 'Cannot infer data_col', 'Insufficient historical data').", "Any relevant tool messages."]`
    *   `debug_info: { ... }` (Optional: provide internal state/tool outputs leading to failure for debugging by coordinator).
    You are an autonomous agent and should not ask clarifying questions; your communication is strictly outputs of successful tasks or detailed failure reports.

**Example Reasoning Flow:**

*   **Example 1: Successful Forecast**
*   **User Question:** "Predict the quantity of ingredients on my trucks for the next 8 hours in `agentic_beans_curated`."
*   **Your Internal Thought Process:**
    1.  **Step 1 (Autonomous Discovery):** Call `get_bigquery_table_list()`. Identify `agentic_beans_curated.telemetry_inventory` as the most relevant table based on dataset and keywords like "ingredients," "trucks," "telemetry," "inventory."
    2.  **Step 2 (Data Preparation):**
        *   **Validation Check:** DDL confirms numerical (`current_quantity_value`) and timestamp (`telemetry_timestamp`) columns are present.
        *   Analyze `telemetry_inventory` DDL. Autonomously infer:
            *   `data_col`: `current_quantity_value` (FLOAT64, likely quantity)
            *   `timestamp_col`: `telemetry_timestamp` (TIMESTAMP, clearly a time column)
            *   `id_cols`: `['ingredient_id', 'truck_id']` (INT64 columns relevant to "ingredients" and "trucks")
        *   Call `get_timeseries_sample_data(dataset_id='agentic_beans_curated', table_name='telemetry_inventory', timestamp_column_name='telemetry_timestamp')`.
        *   Process samples: My internal `infer_time_series_granularity` determines the data granularity is "5 minutes" (due to the SQL rounding to nearest minute).
    3.  **Step 3 (Parameterization):**
        *   Infer `forecast_duration` from prompt: "8 hours".
        *   **Historical Data Window Determination:** Define `historical_data_window_sql` = `telemetry_timestamp BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 DAY) AND CURRENT_TIMESTAMP()`.
        *   Call `time_unit_converter(requested_forecast_duration='8 hours', data_granularity_interval='5 minutes')`. Result: `horizon=96`.
    4.  **Step 4 (Forecasting):**
        *   Construct `query_statement`: `SELECT ingredient_id, truck_id, TIMESTAMP_TRUNC(telemetry_timestamp, MINUTE) AS telemetry_timestamp, AVG(current_quantity_value) AS current_quantity_value FROM \`agentic_beans_curated.telemetry_inventory\` WHERE telemetry_timestamp BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 DAY) AND CURRENT_TIMESTAMP() GROUP BY 1, 2, 3`.
        *   Call `execute_ai_forecast(dataset_id='agentic_beans_curated', data_col='current_quantity_value', timestamp_col='telemetry_timestamp', horizon=96, query_statement='[constructed_query_here]', historical_data_window_sql='telemetry_timestamp BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 DAY) AND CURRENT_TIMESTAMP()', id_cols=['ingredient_id', 'truck_id'], confidence_level=0.95)`.
    5.  **Step 5 (Reporting):**
        *   Receive forecast results.
        *   "Here are the forecasted quantities for your ingredients on trucks for the next 8 hours (96 5-minute intervals), with a 95% confidence level:
            *   **Ingredient 1 on Truck 1:**
                *   2025-08-07 00:30:00 UTC: Value 2500 (Lower Bound: 2400, Upper Bound: 2600)
                *   2025-08-07 00:35:00 UTC: Value 2490 (Lower Bound: 2390, Upper Bound: 2590)
                *   ... (List key forecast points)
            *   **Ingredient 2 on Truck 1:**
                *   ... (list forecasted values and intervals)
            A comprehensive forecast has been generated showing the predicted quantities and their confidence intervals over the specified horizon.

*   **Example 2: Failure to Infer Table**
*   **User Question:** "Predict sales for my lemonade stand next week."
*   **Your Internal Thought Process:**
    1.  **Step 1 (Autonomous Discovery):** Call `get_bigquery_table_list()`. Analyze results. No table names or DDL descriptions clearly match "lemonade stand sales" with high confidence.
    *   **Self-Correction Trigger:** Cannot identify a single clear target table.
    *   **Failure Report:**
        ```json
        {
            "status": "failed",
            "messages": [
                "Unable to autonomously identify a single, highly relevant BigQuery table for forecasting based on the request 'Predict sales for my lemonade stand next week.'. No tables in the available list strongly match 'lemonade stand' or 'sales' in their names or DDL descriptions. Please provide more specific table information.",
                "Step 1: Autonomous Discovery failed."
            ],
            "debug_info": {
                "initial_request": "Predict sales for my lemonade stand next week.",
                "tool_output_get_bigquery_table_list_summary": "[Summary of tables found, e.g., 'Found tables: telemetry_inventory, sales_data, data_quality_metrics...']"
            }
        }
        ```
"""


# Helper function for parsing various timestamp formats (retained as synchronous)
def _parse_flexible_timestamp(timestamp_val) -> datetime:
    """
    Helper function to parse various timestamp string/numeric formats into a datetime object.
    Handles ISO 8601 and common Unix timestamp formats (seconds, milliseconds, microseconds, nanoseconds).
    """
    if timestamp_val is None:
        raise ValueError("Timestamp value is None.")

    timestamp_str = str(timestamp_val) # Ensure it's a string for parsing attempts

    # Try parsing as float (Unix timestamp) first
    try:
        ts_float = float(timestamp_str)
        if ts_float > 2e14: # Very large, likely nanoseconds (after 2000 epoch)
            return datetime.fromtimestamp(ts_float / 1e9) # Convert to seconds for fromtimestamp
        elif ts_float > 2e11: # Likely microseconds
            return datetime.fromtimestamp(ts_float / 1e6) # Convert to seconds
        elif ts_float > 2e8: # Likely milliseconds
            return datetime.fromtimestamp(ts_float / 1e3) # Convert to seconds
        else: # Assume seconds for smaller numbers or if previous heuristics fail
            return datetime.fromtimestamp(ts_float)
    except ValueError:
        pass

    # Try standard ISO 8601 with or without ' UTC' indicator (which BigQuery often adds)
    try:
        return datetime.fromisoformat(timestamp_str.replace(' UTC', ''))
    except ValueError:
        pass

    raise ValueError(f"Could not parse timestamp: '{timestamp_str}' into a datetime object. Supported formats: ISO 8601, Unix epoch (seconds, ms, us, ns).")


def get_timeseries_sample_data(dataset_id: str, table_name: str, timestamp_column_name: str, limit: int = 100) -> dict: # Changed to def
    """
    Fetches a sorted, distinct sample of timestamp data from a specified BigQuery table and column,
    limited to the last 1 day and rounded to the nearest minute. This tool is used to infer
    the time series granularity.

    Args:
        dataset_id (str): The BigQuery dataset ID where the table resides.
        table_name (str): The name of the table to sample.
        timestamp_column_name (str): The name of the column containing timestamp values.
        limit (int): The maximum number of timestamp samples to retrieve. Default is 100.

    Returns:
        dict: A dictionary conforming to the agent's tool output schema.
              On success, `results` will contain a list of dictionaries, each with the
              timestamp column name as key and the timestamp value.
              Example successful response:
              {
                  "status": "success",
                  "tool_name": "get_timeseries_sample_data",
                  "query": "SELECT DISTINCT ... FROM `project.dataset.table` WHERE ... LIMIT 100",
                  "messages": ["Successfully retrieved timestamp samples."],
                  "results": [
                      {"telemetry_timestamp": "2023-01-01 00:00:00 UTC"},
                      {"telemetry_timestamp": "2023-01-01 00:05:00 UTC"},
                      ...
                  ]
              }

              Example failed response:
              {
                  "status": "failed",
                  "tool_name": "get_timeseries_sample_data",
                  "query": None,
                  "messages": ["Error: Table not found or column does not exist."],
                  "results": None
              }
    """
    messages = []
    tool_name = "get_timeseries_sample_data"
    query = None
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")

    if not all([project_id, dataset_id, table_name, timestamp_column_name]):
        messages.append("Input Error: project_id, dataset_id, table_name, and timestamp_column_name cannot be empty.")
        return {
            "status": "failed",
            "tool_name": tool_name,
            "query": query,
            "messages": messages,
            "results": None
        }

    query = f"""SELECT DISTINCT CAST(TIMESTAMP_TRUNC(TIMESTAMP_ADD({timestamp_column_name}, INTERVAL 30 SECOND), MINUTE) AS STRING) AS {timestamp_column_name}
                  FROM `{project_id}.{dataset_id}.{table_name}`
                 WHERE {timestamp_column_name} IS NOT NULL
                   AND {timestamp_column_name} BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY) AND CURRENT_TIMESTAMP()
              ORDER BY {timestamp_column_name} ASC
               LIMIT {limit}"""

    try:
        logger.debug(f"[{tool_name}] Executing SQL: {query}")
        query_result = bq_sql.run_bigquery_sql(query) # Added await
        logger.debug(f"[{tool_name}] BigQuery SQL result: {json.dumps(query_result, indent=2)}")

        if query_result["status"] == "failed":
            messages.append(f"Failed to retrieve timestamp samples from BigQuery. Check if table/column exists or permissions.")
            messages.extend(query_result["messages"])
            return {
                "status": "failed",
                "tool_name": tool_name,
                "query": query,
                "messages": messages,
                "results": None
            }
        
        if not isinstance(query_result.get("results"), list):
             messages.append(f"Unexpected result format from run_bigquery_sql. Expected a list in 'results', got {type(query_result.get('results'))}")
             return {
                "status": "failed",
                "tool_name": tool_name,
                "query": query,
                "messages": messages,
                "results": None
            }

        if not query_result["results"]:
            messages.append(f"No timestamp data found in '{timestamp_column_name}' for table `{project_id}.{dataset_id}.{table_name}` within the last 1 day. Cannot infer granularity.")
            return {
                "status": "success",
                "tool_name": tool_name,
                "query": query,
                "messages": messages,
                "results": []
            }

        messages.append("Successfully retrieved timestamp samples (rounded to nearest minute).")
        return {
            "status": "success",
            "tool_name": tool_name,
            "query": query,
            "messages": messages,
            "results": query_result["results"]
        }

    except Exception as e:
        messages.append(f"An unexpected error occurred while sampling timestamp data: {e}")
        logger.error(f"[{tool_name}] Unexpected Error: {e}", exc_info=True)
        return {
            "status": "failed",
            "tool_name": tool_name,
            "query": query,
            "messages": messages,
            "results": None
        }


def parse_duration_string(duration_str: str) -> timedelta:
    """
    Parses a duration string (e.g., '8 hours', '1 day', '2 weeks', '30 minutes') into a timedelta object.
    Supports single unit durations.
    (This remains synchronous as it performs no I/O)
    """
    duration_str = duration_str.lower().strip()
    match = re.match(r'(\d+)\s*(hour|day|week|minute)s?', duration_str)
    if not match:
        raise ValueError(f"Invalid duration string format: '{duration_str}'. Expected formats like '8 hours', '1 day', '2 weeks', '30 minutes'.")

    value = int(match.group(1))
    unit = match.group(2)

    if unit == 'minute':
        return timedelta(minutes=value)
    elif unit == 'hour':
        return timedelta(hours=value)
    elif unit == 'day':
        return timedelta(days=value)
    elif unit == 'week':
        return timedelta(weeks=value)
    else:
        raise ValueError(f"Unsupported time unit: {unit} in '{duration_str}'")


def time_unit_converter(requested_forecast_duration: str, data_granularity_interval: str) -> dict:
    """
    Converts a requested forecast duration and the time series data's granularity interval
    into a 'horizon' value suitable for BigQuery ML's AI.FORECAST function.
    The horizon represents the number of data points to forecast.
    (This remains synchronous as it performs no I/O)
    """
    messages = []
    tool_name = "time_unit_converter"
    try:
        requested_td = parse_duration_string(requested_forecast_duration)
        requested_minutes = requested_td.total_seconds() / 60

        granularity_td = parse_duration_string(data_granularity_interval)
        granularity_minutes = granularity_td.total_seconds() / 60

        if granularity_minutes <= 0:
            raise ValueError("Data granularity interval must be a positive duration.")

        horizon = int(requested_minutes / granularity_minutes)
        if requested_minutes % granularity_minutes != 0:
            horizon += 1

        messages.append(f"Successfully calculated horizon for requested forecast duration '{requested_forecast_duration}' "
                        f"with data granularity interval of '{data_granularity_interval}'.")
        
        return {
            "status": "success",
            "tool_name": tool_name,
            "query": None,
            "messages": messages,
            "results": {
                "horizon": horizon,
                "requested_duration_minutes": requested_minutes,
                "data_granularity_minutes": granularity_minutes
            }
        }

    except ValueError as ve:
        messages.append(f"Input Error: {ve}")
        logger.error(f"[{tool_name}] Input Error: {ve}")
        return {
            "status": "failed",
            "tool_name": tool_name,
            "query": None,
            "messages": messages,
            "results": None
        }
    except Exception as e:
        messages.append(f"An unexpected error occurred: {e}")
        logger.error(f"[{tool_name}] Unexpected Error: {e}", exc_info=True)
        return {
            "status": "failed",
            "tool_name": tool_name,
            "query": None,
            "messages": messages,
            "results": None
        }


def infer_time_series_granularity(timestamp_samples: list, timestamp_column_name: str) -> dict:
    """
    Infers the most likely consistent time interval (granularity) from a list of sorted timestamp samples.
    Now robust to handle various timestamp formats and reports granularity down to whole seconds
    or "less than 1 second" for very fine-grained data.
    (This remains synchronous as it performs no I/O, only calls _parse_flexible_timestamp)
    """
    messages = []
    tool_name = "infer_time_series_granularity"

    if not timestamp_samples or len(timestamp_samples) < 2:
        messages.append("Not enough timestamp samples to infer granularity (at least 2 distinct points needed).")
        logger.warning(messages[-1])
        return {
            "status": "success",
            "tool_name": tool_name,
            "query": None,
            "messages": messages,
            "results": {"inferred_granularity_interval": None, "confidence": 0.0}
        }

    time_differences_seconds = []
    
    for i in range(len(timestamp_samples) - 1):
        try:
            ts1_val = timestamp_samples[i].get(timestamp_column_name)
            ts2_val = timestamp_samples[i+1].get(timestamp_column_name)

            ts1 = _parse_flexible_timestamp(ts1_val)
            ts2 = _parse_flexible_timestamp(ts2_val)
            
            diff = (ts2 - ts1).total_seconds()
            if diff > 0: # Only consider positive differences
                time_differences_seconds.append(diff)
        except Exception as e:
            messages.append(f"Could not parse timestamp or calculate difference for sample index {i} or {i+1}: {e}. Skipping data point.")
            logger.warning(messages[-1])
            continue

    if not time_differences_seconds:
        messages.append("No valid positive time differences could be calculated from samples. Granularity cannot be inferred.")
        logger.warning(messages[-1])
        return {
            "status": "success",
            "tool_name": tool_name,
            "query": None,
            "messages": messages,
            "results": {"inferred_granularity_interval": None, "confidence": 0.0}
        }

    from collections import Counter
    diff_counts = Counter(time_differences_seconds)
    most_common_diff_sec, count = diff_counts.most_common(1)[0]

    confidence = count / len(time_differences_seconds)

    def format_interval_human_readable(seconds):
        if seconds >= 86400 and seconds % 86400 == 0: # Full days
            return f"{int(seconds / 86400)} days"
        elif seconds >= 3600 and seconds % 3600 == 0: # Full hours
            return f"{int(seconds / 3600)} hours"
        elif seconds >= 60 and seconds % 60 == 0: # Full minutes
            return f"{int(seconds / 60)} minutes"
        elif seconds > 0: # Handle seconds and sub-seconds (rounding to nearest second)
            rounded_to_nearest_second = round(seconds)
            if rounded_to_nearest_second > 0:
                return f"{int(rounded_to_nearest_second)} seconds"
            else: # If rounding to nearest second results in 0, it means it's less than 0.5 seconds
                return "less than 1 second"
        else:
            return "unknown"

    inferred_granularity_interval = format_interval_human_readable(most_common_diff_sec)
    
    messages.append(f"Inferred granularity: {inferred_granularity_interval} with confidence {confidence:.2f}")
    logger.info(messages[-1])
    
    return {
        "status": "success",
        "tool_name": tool_name,
        "query": None,
        "messages": messages,
        "results": {
            "inferred_granularity_interval": inferred_granularity_interval,
            "confidence": round(confidence, 2)            
        }
    }


# Tool: execute_ai_forecast (UPDATED DOCSTRING AND id_cols default)
def execute_ai_forecast( # Changed to def
    dataset_id: str,
    data_col: str,
    timestamp_col: str,
    horizon: int,
    query_statement: str,
    historical_data_window_sql: str, # This parameter acts as a guide for the agent when constructing query_statement
    id_cols: list = [], # Changed default to an empty list
    confidence_level: float = 0.95
) -> dict:
    """
    Executes the BigQuery ML AI.FORECAST function.

    Args:
        dataset_id (str): The BigQuery dataset ID.
        data_col (str): The name of the column containing the data to forecast.
        timestamp_col (str): The name of the column containing the time points.
        horizon (int): The number of time points to forecast into the future.
        query_statement (str): A full GoogleSQL query statement that generates the data for forecasting.
                               This query MUST include a robust filter on the timestamp column (e.g., using a WHERE clause
                               with TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL X DAY) or similar) to limit the amount
                               of historical data processed. This is critical for performance and to prevent processing
                               billions of rows.
        historical_data_window_sql (str): An SQL WHERE clause fragment provided by the agent's logic
                                          to indicate the intended historical data window. This parameter is
                                          informational for this tool, as the actual filtering logic MUST be
                                          present within the `query_statement` itself.
        id_cols (list[str], optional): A list of column names that identify unique time series.
                                        Defaults to an empty list (forecasts a single time series).
        confidence_level (float, optional): The confidence interval for the forecast (0 to <1).
                                            Defaults to 0.95.

    Returns:
        dict: A dictionary conforming to the agent's tool output schema with forecast results.
        {
            "status": "success" or "failed",
            "tool_name": "execute_ai_forecast",
            "query": "query sql",
            "messages": ["List of messages during processing"],
            "results": [
                        {
                          "field-1": "value-1",
                          "field-2": "value-2",
                          "field-3": "value-3"
                        },
                        {
                          "field-1": "value-1",
                          "field-2": "value-2",
                          "field-3": "value-3"
                        }                        
                       ]
        }          
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    messages = []
    tool_name = "execute_ai_forecast"
    forecast_sql_query = None

    if not project_id:
        messages.append("Configuration Error: AGENT_ENV_PROJECT_ID environment variable not set.")
        return {
            "status": "failed",
            "tool_name": tool_name,
            "query": forecast_sql_query,
            "messages": messages,
            "results": None
        }

    if not query_statement:
        messages.append("Input Error: 'query_statement' must be provided as the input data source for AI.FORECAST and MUST include a timestamp filter.")
        return {
            "status": "failed",
            "tool_name": tool_name,
            "query": forecast_sql_query,
            "messages": messages,
            "results": None
        }
    
    input_source = f"(\n{query_statement}\n)"
    
    if historical_data_window_sql:
        messages.append("Warning: 'historical_data_window_sql' parameter is informational only for 'execute_ai_forecast'. Please ensure data filtering is correctly implemented within the 'query_statement' itself (e.g., using a WHERE clause).")

    id_cols_arg = ""
    # Check if id_cols is provided AND non-empty
    if id_cols: # This checks for both None and empty list
        if not isinstance(id_cols, list) or not all(isinstance(col, str) for col in id_cols):
            messages.append("Input Error: 'id_cols' must be a list of strings if provided.")
            return {
                "status": "failed",
                "tool_name": tool_name,
                "query": forecast_sql_query,
                "messages": messages,
                "results": None
            }
        id_cols_str = ", ".join([f"'{col}'" for col in id_cols])
        id_cols_arg = f", id_cols => [{id_cols_str}]"
    
    forecast_sql_query = f"""
    SELECT
      *
    FROM
      AI.FORECAST(
        {input_source},
        data_col => '{data_col}',
        timestamp_col => '{timestamp_col}',
        horizon => {horizon},
        confidence_level => {confidence_level}
        {id_cols_arg}
      )
    """

    try:
        logger.debug(f"[{tool_name}] Executing AI.FORECAST SQL:\n{forecast_sql_query}")
        query_result = bq_sql.run_bigquery_sql(forecast_sql_query) # Added await
        logger.debug(f"[{tool_name}] BigQuery AI.FORECAST result: {json.dumps(query_result, indent=2)}")

        if query_result["status"] == "failed":
            messages.append(f"AI.FORECAST query failed.")
            messages.extend(query_result["messages"])
            return {
                "status": "failed",
                "tool_name": tool_name,
                "query": forecast_sql_query,
                "messages": messages,
                "results": None
            }

        messages.append("AI.FORECAST query executed successfully.")
        return {
            "status": "success",
            "tool_name": tool_name,
            "query": forecast_sql_query,
            "messages": messages,
            "results": query_result["results"]
        }

    except Exception as e:
        messages.append(f"An unexpected error occurred during AI.FORECAST execution: {e}")
        logger.error(f"[{tool_name}] Unexpected Error: {e}", exc_info=True)
        return {
            "status": "failed",
            "tool_name": tool_name,
            "query": forecast_sql_query,
            "messages": messages,
            "results": None
        }