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

# Import tools
import data_analytics_agent.tools.bigquery.bigquery_execute_sql_tools as bigquery_execute_sql_tools

logger = logging.getLogger(__name__)


async def _parse_flexible_timestamp(timestamp_val) -> datetime:
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


async def get_timeseries_sample_data(dataset_id: str, table_name: str, timestamp_column_name: str, limit: int = 100) -> dict: # Changed to def
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
        query_result = await bigquery_execute_sql_tools.run_bigquery_sql(query) # Added await
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


async def parse_duration_string(duration_str: str) -> timedelta:
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


async def time_unit_converter(requested_forecast_duration: str, data_granularity_interval: str) -> dict:
    """
    Converts a requested forecast duration and the time series data's granularity interval
    into a 'horizon' value suitable for BigQuery ML's AI.FORECAST function.
    The horizon represents the number of data points to forecast.
    (This remains synchronous as it performs no I/O)
    """
    messages = []
    tool_name = "time_unit_converter"
    try:
        requested_td = await parse_duration_string(requested_forecast_duration)
        requested_minutes = requested_td.total_seconds() / 60

        granularity_td = await parse_duration_string(data_granularity_interval)
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


async def infer_time_series_granularity(timestamp_samples: list, timestamp_column_name: str) -> dict:
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

            ts1 = await _parse_flexible_timestamp(ts1_val)
            ts2 = await _parse_flexible_timestamp(ts2_val)
            
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


async def execute_ai_forecast( # Changed to def
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
        query_result = await bigquery_execute_sql_tools.run_bigquery_sql(forecast_sql_query) # Added await
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