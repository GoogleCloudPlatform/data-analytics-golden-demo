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
import time
import requests
import google.auth
import google.auth.transport.requests
import logging

logger = logging.getLogger(__name__)

# Helper function to avoid code duplication for processing paginated results
def _process_and_paginate_results(session, initial_response_data, project_id, job_id, bigquery_region, headers):
    """Processes a query result set, handling pagination."""
    all_rows = []
    
    # Process the first page of results
    schema = [field['name'] for field in initial_response_data['schema']['fields']]
    for row in initial_response_data.get('rows', []):
        all_rows.append({schema[i]: cell.get('v') for i, cell in enumerate(row['f'])})

    # Handle subsequent pages
    page_token = initial_response_data.get('pageToken')
    while page_token:
        logger.debug(f"Fetching next page of results with pageToken...")
        results_url = f"https://bigquery.googleapis.com/bigquery/v2/projects/{project_id}/queries/{job_id}?location={bigquery_region}&pageToken={page_token}"
        response = session.get(results_url, headers=headers)
        response.raise_for_status()
        
        page_data = response.json()
        for row in page_data.get('rows', []):
             all_rows.append({schema[i]: cell.get('v') for i, cell in enumerate(row['f'])})
        
        page_token = page_data.get('pageToken')
        
    logger.debug(f"all_rows: {all_rows}")
    return all_rows


def run_bigquery_sql(sql: str) -> dict:
    """Executes a SQL statement against Google BigQuery.

    IMPORTANT: When formatting the table names in the join clause make sure you use backticks.
        - e.g.: `project_id.dataset_name.table_name`
    
    IMPORTANT: You should call the tool "vector_search_column_values" for any columns that are strings to get their actual values.

    This function connects to the BigQuery and runs the provided SQL.
    It intelligently handles two types of queries:
    1.  Data-returning queries (`SELECT`, `WITH`): It fetches all resulting rows,
        paginating if necessary, and returns them as a JSON array of objects.
    2.  DDL/DML statements (`CREATE`, `INSERT`): It runs the job, waits for
        completion, and returns a JSON object confirming success or raises an
        exception on failure.

    Args:
        sql (str): The full SQL statement to execute on BigQuery.

    Returns:
        NOTE: If this is a DML operation the results will be None or null.  The messages will contain if this was a SELECT (return results) 
              or a DML that does not return rows (results).
        dict:
        {
            "status": "success",
            "tool_name": "run_bigquery_sql",
            "query": "The SQL statement used",
            "messages": ["List of messages during processing"]
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
    logger.debug("--- Starting BigQuery jobs.query Execution ---")

    import os

    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    bigquery_region = os.getenv("AGENT_ENV_BIGQUERY_REGION")
    messages = []

    # 1. Authentication and Setup
    try:
        credentials, _ = google.auth.default(
            scopes=["https://www.googleapis.com/auth/cloud-platform", "https://www.googleapis.com/auth/bigquery"]
        )
        auth_req = google.auth.transport.requests.Request()
        credentials.refresh(auth_req)
        logger.debug("Successfully authenticated.")
    except google.auth.exceptions.DefaultCredentialsError as e:
        raise Exception(f"Authentication failed. Run 'gcloud auth application-default login'. Error: {e}")

    headers = {"Authorization": f"Bearer {credentials.token}", "Content-Type": "application/json"}
    session = requests.Session()
    
    # 2. Submit Query to the Synchronous Endpoint (jobs.query)
    query_url = f"https://bigquery.googleapis.com/bigquery/v2/projects/{project_id}/queries"
    
    # Set a reasonable timeout. If the query takes longer, jobComplete will be false.
    payload = {
        "query": sql,
        "useLegacySql": False,
        "timeoutMs": 60 * 1000 * 5 # seconds * ms * minutes
    }
    
    logger.debug(f"Submitting query to {query_url} with a 30s timeout...")
    is_select_query = sql.strip().upper().startswith(("SELECT", "WITH"))
    try:       
        response = session.post(query_url, data=json.dumps(payload), headers=headers)
        response.raise_for_status()
        response_data = response.json()

        job_id = response_data['jobReference']['jobId']
        location = response_data['jobReference']['location']
        job_complete = response_data['jobComplete']
        
    except Exception as e:
        messages.append(f"Error when calling rest api ({query_url}): {e}")
        return_value = { "status": "failed", "tool_name": "run_bigquery_sql", "query": sql, "messages": messages, "results": None }
        return return_value

    # 3. Handle the response based on whether the job completed in time
    if job_complete:
        logger.debug("Query completed within timeout (fast path).")
        if response_data.get('errors'):
            messages.append(f"{json.dumps(response_data['errors'], indent=2)}")
            return_value = { "status": "failed", "tool_name": "run_bigquery_sql", "query": sql, "messages": messages, "results": None }
            return return_value

        logger.debug(f"run_bigquery_sql -> response: {json.dumps(response_data, indent=2)}")

        if is_select_query:
            rows = _process_and_paginate_results(session, response_data, project_id, job_id, location, headers)
            messages.append("Executed a SELECT query so the results will be poplulated with rows.")
            return_value = { "status": "success", "tool_name": "run_bigquery_sql", "query": sql, "messages": messages, "results": rows }
            return return_value
        else: # DML/DDL
            rows_affected = int(response_data.get('numDmlAffectedRows', 0))
            messages.append(f"Executed a DML query which affected {rows_affected} rows.")
            return_value = { "status": "success", "tool_name": "run_bigquery_sql", "query": sql, "messages": messages, "results": None }
            return return_value

    else:
        logger.debug("Query timed out, falling back to polling (slow path)...")
        # Fallback to polling the jobs.get endpoint
        job_status_url = f"https://bigquery.googleapis.com/bigquery/v2/projects/{project_id}/jobs/{job_id}?location={bigquery_region}"
        while True:
            time.sleep(2)
            logger.debug("Polling job status...")
            job_status_response = session.get(job_status_url, headers=headers)
            job_status_response.raise_for_status()
            status_data = job_status_response.json()

            if status_data['status']['state'] == 'DONE':
                logger.debug("Job finished.")
                if status_data['status'].get('errorResult'):
                    messages.append(f"{json.dumps(status_data['status']['errorResult'], indent=2)}")
                    return_value = { "status": "failed", "tool_name": "run_bigquery_sql", "query": sql, "messages": messages, "results": None }  
                    return return_value             
                
                # Job is done, now process the final result
                if is_select_query:
                    # We need to fetch the results now that the job is complete
                    results_url = f"https://bigquery.googleapis.com/bigquery/v2/projects/{project_id}/jobs/{job_id}/results?location={bigquery_region}"
                    final_results_res = session.get(results_url, headers=headers)
                    final_results_res.raise_for_status()
                    rows = _process_and_paginate_results(session, final_results_res.json(), project_id, job_id, location, headers)
                    messages.append("Executed a SELECT query so the results will be poplulated with rows.")
                    return_value = { "status": "success", "tool_name": "run_bigquery_sql", "query": sql, "messages": messages, "results": rows }
                    return return_value

                else: # DML/DDL
                    rows_affected = int(status_data.get('statistics', {}).get('query', {}).get('numDmlAffectedRows', 0))
                    messages.append(f"Executed a DML query which affected {rows_affected} rows.")
                    return_value = { "status": "success", "tool_name": "run_bigquery_sql", "query": sql, "messages": messages, "results": None }
                    return return_value
                