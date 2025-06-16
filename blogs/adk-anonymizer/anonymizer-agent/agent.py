"""Agent for generating SQL queries to anonymize BigQuery tables."""

from typing import Any, Dict, List, Tuple

from google.adk import agents
from google.cloud import bigquery

Agent = agents.Agent

BQ_JOB_EXECUTION_PROJECT = "REPLACE_WITH_YOUR_PROJECT"

COMPATIBLE_ML_DESCRIBE_TYPES: frozenset[str] = frozenset([
    "STRING",
    "INTEGER",
    "INT64",
    "FLOAT",
    "FLOAT64",
    "NUMERIC",
    "BIGNUMERIC",
    "BOOLEAN",
    "BOOL",
    "BYTES",
    "TIMESTAMP",
    "DATE",
    "TIME",
    "DATETIME",
])


def _format_bq_table_id(project_id: str, dataset_id: str, table_id: str) -> str:
  """Helper to consistently format BigQuery table IDs for SQL queries (e.g., `project.dataset.table`)."""
  return f"`{project_id}.{dataset_id}.{table_id}`"


def _format_bq_table_ref(
    project_id: str, dataset_id: str, table_id: str
) -> str:
  """Helper to consistently format BigQuery table references for API calls (e.g., project.dataset.table)."""
  return f"{project_id}.{dataset_id}.{table_id}"


def validate_sql_query(sql_query: str) -> Dict[str, str]:
  """Validates a Google BigQuery SQL query using a dry run.

  Args:
      sql_query: The BigQuery SQL query string to validate.

  Returns:
      A dictionary with:
      - "status": "success" or "error".
      - "message": A descriptive message of the outcome.
      - "bytes_processed" (optional): Estimated bytes if the query were run (on
      success).
      - "error_type" (optional): Category of error (on error).
  """
  try:
    client = bigquery.Client(project=BQ_JOB_EXECUTION_PROJECT)
    client.query(sql_query, job_config=bigquery.QueryJobConfig(dry_run=True))
    return {"status": "SUCCESS"}

  except Exception as ex:
    return {
        "status": "ERROR",
        "error_details": str(ex),
    }


def sample_bigquery_table(
    project_id: str, dataset_id: str, table_id: str
) -> Dict[str, Any]:
  """Retrieves a sample of rows from a BigQuery table.

  This is useful to quickly inspect data before anonymizing a large
  table.

  Args:
      project_id: The Google Cloud project ID.
      dataset_id: The BigQuery dataset ID.
      table_id: The BigQuery table ID.
      limit: The maximum number of rows to retrieve.

  Returns:
      A dictionary with:
      - "status": "success" or "error".
      - "data" (optional): A list of JSON-serializable dictionaries (rows) on
      success.
      - "count" (optional): The number of rows retrieved on success.
      - "message" (optional): An error message on failure.
      - "error_type" (optional): Category of error on failure.
  """
  full_table_sql_id = _format_bq_table_id(project_id, dataset_id, table_id)
  limit = 50
  query = f"SELECT * FROM {full_table_sql_id} LIMIT {limit}"

  try:
    client = bigquery.Client(project=BQ_JOB_EXECUTION_PROJECT)
    row_iterator = client.query_and_wait(
        query, project=BQ_JOB_EXECUTION_PROJECT, max_results=1000
    )
    rows = [{key: val for key, val in row.items()} for row in row_iterator]

    return {
        "status": "success",
        "data": rows,
        "count": len(rows),
    }

  except Exception as ex:
    return {
        "status": "ERROR",
        "error_details": str(ex),
    }


def _get_table_schema_and_categorize_columns(
    client: bigquery.Client, table_ref_str: str
) -> Tuple[List[str], List[str], List[str]]:
  """Fetches table schema and categorizes columns for ML.DESCRIBE_DATA compatibility.

  Args:
      client: An authenticated BigQuery client.
      table_ref_str: The table reference string (e.g., "project.dataset.table").

  Returns:
      A tuple containing:
      - compatible_columns_sql: List of SQL-formatted compatible column names
      for SELECT.
      - profiled_column_names: List of raw compatible column names.
      - skipped_column_details: List of strings describing skipped incompatible
      columns.
  """
  table_obj = client.get_table(table_ref_str)

  compatible_columns_sql: List[str] = []
  profiled_column_names: List[str] = []
  skipped_column_details: List[str] = []

  for field in table_obj.schema:
    if field.field_type in COMPATIBLE_ML_DESCRIBE_TYPES:
      compatible_columns_sql.append(f"`{field.name}`")
      profiled_column_names.append(field.name)
    else:
      skipped_column_details.append(f"{field.name} (Type: {field.field_type})")
  return compatible_columns_sql, profiled_column_names, skipped_column_details


def profile_bigquery_table(
    project_id: str, dataset_id: str, table_id: str
) -> Dict[str, Any]:
  """Performs a statistical analysis of a BigQuery table using ML.DESCRIBE_DATA.

  It automatically selects columns compatible with ML.DESCRIBE_DATA for
  profiling. This is useful to quickly identify data types and patterns
  before anonymizing a large table.

  Args:
      project_id: The Google Cloud project ID.
      dataset_id: The BigQuery dataset ID.
      table_id: The BigQuery table ID.

  Returns:
      A dictionary containing profiling results or error details:
      On success:
          {
              "status": "success",
              "profile": List[Dict[str, Any]],  // The profile data from
              ML.DESCRIBE_DATA
              "profiled_columns": List[str],    // Names of columns that were
              profiled
              "skipped_incompatible_columns": List[str] // Details of columns
              skipped
          }
      On error:
          {
              "status": "error",
              "error_type": str,
              "message": str,
              "details": Dict[str, Any] // Contextual information about the
              error
          }
  """
  client = bigquery.Client(project=BQ_JOB_EXECUTION_PROJECT)
  full_table_sql_id = _format_bq_table_id(project_id, dataset_id, table_id)
  full_table_ref_str = _format_bq_table_ref(project_id, dataset_id, table_id)

  operation_details = {
      "project_id": project_id,
      "dataset_id": dataset_id,
      "table_id": table_id,
      "profiled_columns": [],
      "skipped_incompatible_columns": [],
      "query_attempted": None,
  }

  try:
    # 1. Get schema and identify compatible columns
    compatible_sql, profiled_names, skipped_details = (
        _get_table_schema_and_categorize_columns(client, full_table_ref_str)
    )

    operation_details["profiled_columns"] = profiled_names
    operation_details["skipped_incompatible_columns"] = skipped_details

    if not compatible_sql:
      message = (
          "No columns compatible with ML.DESCRIBE_DATA found in table"
          f" {full_table_ref_str}."
      )
      if skipped_details:
        message += (
            f" Skipped incompatible columns: {', '.join(skipped_details)}."
        )
      return {
          "status": "error",
          "error_type": "NoCompatibleColumnsError",
          "message": message,
          "details": operation_details,
      }

    # 2. Construct and execute the ML.DESCRIBE_DATA query
    select_statement_for_cte = ", ".join(compatible_sql)
    source_for_describe = (
        f"(SELECT {select_statement_for_cte} FROM {full_table_sql_id})"
    )

    query = f"SELECT * FROM ML.DESCRIBE_DATA({source_for_describe}, STRUCT())"
    operation_details["query_attempted"] = query

    row_iterator = client.query_and_wait(
        query, project=project_id, max_results=1000
    )
    rows = [{key: val for key, val in row.items()} for row in row_iterator]

    return {
        "status": "success",
        "profile": rows,
        "profiled_columns": profiled_names,
        "skipped_incompatible_columns": skipped_details,
    }

  except Exception as ex:
    return {
        "status": "ERROR",
        "error_details": str(ex),
    }


AGENT_SYSTEM_PROMPT = r"""
You are an expert BigQuery Data Engineer specializing in data privacy. Your goal is to generate a BigQuery SQL script that creates an anonymized, sampled copy of a user-specified table for testing purposes.

WORKFLOW:

1.  Input: Get a BigQuery table reference (`project.dataset.table`) from the user.
2.  Analyze: Use `profile_bigquery_table` and `sample_bigquery_table` to inspect the table's schema and data. Identify sensitive columns (PII like names, emails, IDs, addresses) by examining column names and data patterns. Always make sure to use both `profile_bigquery_table` and `sample_bigquery_table` to get a comprehensive view of the table.
3.  Strategize Masking: For each sensitive column, choose an appropriate masking method. Keep non-sensitive columns as-is. If in doubt, anonymize the column. Your options include:
    - Hashing (SHA-256): For deterministic de-identification of joinable keys.
    - Redaction/Partial Masking: Obscuring parts of a string (e.g., `REGEXP_REPLACE`, `SUBSTR`).
    - Generalization: Reducing precision (e.g., `DATE_TRUNC`, numeric bucketing).
    - Randomization: Replacing numbers with random values in a plausible range.
    - Nullification/Default Value: Replacing data with `NULL` or a fixed placeholder (e.g., `'MASKED'`).
4.  Generate SQL:
    - Construct a `SELECT` statement which applies the chosen masking functions to the selected columns in the `FROM` clause. It should have ALL THE COLUMN NAMES AND TYPES EXACTLY AS IS from the original table.
    - Use `TABLESAMPLE SYSTEM (10 PERCENT)` to generate a smaller test dataset.
    - Apply the chosen masking functions in the `SELECT` list, ensuring data types are correctly handled.
    - Add comments to the SQL explaining the masking applied.
5.  Validate: Use the `ValidateSQL` tool to verify the script is correct and fix any errors.
6.  Output: Present the final, validated SQL script in a code block.
"""

root_agent = Agent(
    name="anonymous_table_generator",
    model="gemini-2.0-flash",
    description=(
        "Agent to generate SQL for creating anonymized versions of existing"
        " BigQuery tables."
    ),
    instruction=AGENT_SYSTEM_PROMPT,
    tools=[sample_bigquery_table, profile_bigquery_table, validate_sql_query],
)
