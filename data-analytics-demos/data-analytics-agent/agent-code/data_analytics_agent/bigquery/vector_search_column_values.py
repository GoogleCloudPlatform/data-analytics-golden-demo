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
# Assuming run_bigquery_sql_helper.run_bigquery_sql is now async
import data_analytics_agent.bigquery.run_bigquery_sql as run_bigquery_sql_helper 
import logging
import os

logger = logging.getLogger(__name__)

def vector_search_column_values(dataset_id: str, table_id: str, table_name: str, column_name: str, search_string: str) -> dict: # Changed to def
    """
    Gathers string values from a specified BigQuery column based on a vector embedding similarity search.

    This tool is crucial for an AI (LLM) agent to perform robust and flexible searches for string fields
    in BigQuery. It should be called **before** constructing a NL2SQL query that involves searching
    for specific string values within a column. 

    For example, if the user types "Slayer Espresso Steam", this function uses vector embeddings
    to find highly similar strings stored in the database, such as "Slayer Espresso Steam LP 3-Group"
    or "Slayer Espresso Steamer", along with a similarity `distance`. The **SMALLER** the
    `distance` value, the better the match between the `search_string` and the retrieved
    database string.

    Args:
        dataset_id (str): The ID (or name) of the BigQuery dataset containing the table.
        table_id (str): The ID (or name) of the specific table within the dataset.
        table_name (str): The actual name of the table to search.
        column_name (str): The name of the column within the specified table to perform the search on.
        search_string (str): The string provided by the user that needs to be matched against
                             the column's values using vector embeddings.

    Returns:
        dict: A dictionary containing the status of the operation, tool name, messages,
              and a list of search results. Each search result includes:
              - `text_content` (str): The string value found in the BigQuery column that
                                      is similar to the `search_string`.
              - `distance` (float): A numerical value representing the semantic distance
                                    between the `search_string`'s embedding and the
                                    `text_content`'s embedding. A smaller distance indicates
                                    higher similarity.

        Example return structure:
        {
            "status": "success",
            "tool_name": "vector_search_column_values",
            "query": "None",
            "messages": ["List of messages during processing"],
            "results": [
                            {
                                "text_content": "Slayer Espresso Steam LP 3-Group",
                                "distance": 0.8910,
                            },
                            {
                                "text_content": "Slayer Espresso Steamer",
                                "distance": 0.6731,
                            }
                        ]
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    response = {
        "status": "success",
        "tool_name": "vector_search_column_values",
        "query": None,
        "messages": [],
        "results": None
    }

    # The SQL query uses BigQuery's VECTOR_SEARCH function to find similar text content
    # based on pre-computed embeddings stored in `data_analytics_agent_metadata.vector_embedding_metadata`.
    # It also generates an embedding for the `search_string` on the fly using ML.GENERATE_TEXT_EMBEDDING.
    # AND array_length(text_embedding) = 768 -- For "null" vector embedding values
    sql = f"""SELECT base.text_content AS text_content,
                     ROUND(distance,6) as distance
                FROM VECTOR_SEARCH((SELECT * 
                                      FROM `data_analytics_agent_metadata.vector_embedding_metadata` 
                                     WHERE project_id   = '{project_id}' 
                                     AND dataset_name = '{dataset_id}' 
                                     AND table_name   = '{table_name}' 
                                     AND column_name  = '{column_name}' 
                                     AND array_length(text_embedding) = 768
                                   ),
                                  'text_embedding',
                                  (SELECT text_embedding,
                                          content AS query
                                     FROM ML.GENERATE_TEXT_EMBEDDING(MODEL `data_analytics_agent_metadata.textembedding_model`,
                                                                     (SELECT '{search_string}' AS content),
                                                                     STRUCT(TRUE AS flatten_json_output, 
                                                                           'SEMANTIC_SIMILARITY' as task_type,
                                                                           768 AS output_dimensionality)
                                                                     )),
                                  top_k => 20)
             ORDER BY distance;"""

    vector_search_result = run_bigquery_sql_helper.run_bigquery_sql(sql) # Added await
    
    if vector_search_result["status"] == "failed":
        response["messages"].append(f"Failed to run SQL (Vector Search): {sql}")
        response["messages"].extend(vector_search_result["messages"])
        response["status"] = "failed"
        return response

    result_list = []
    for row in vector_search_result["results"]:
        text_content = row["text_content"]
        distance = float(row["distance"])
        search_result = {
            "text_content": text_content,
            "distance": distance,
        }
        result_list.append(search_result)

    response["results"] = result_list
    return response


def find_best_table_column_for_string(dataset_id: str, search_string: str) -> dict: # Changed to def
    """
    Identifies the most relevant BigQuery table and column within a specified dataset
    where a given search string is most likely to be found, based on vector embedding similarity.

    This tool is designed to help an AI (LLM) agent determine the correct context (table and column)
    for a user's search query when the specific table or column is not explicitly provided.
    It performs a broad search across all indexed columns within the dataset to find the
    best semantic match for the `search_string`.

    Args:
        dataset_id (str): The ID (or name) of the BigQuery dataset to search within.
        search_string (str): The string provided by the user that needs to be matched.

    Returns:
        dict: A dictionary containing the status of the operation, tool name, messages,
              and the best search result. The best search result includes:
              - `dataset_id` (str): The ID of the dataset where the match was found.
              - `table_name` (str): The name of the table containing the best match.
              - `column_name` (str): The name of the column containing the best match.
              - `text_content` (str): The specific string value in the database that is
                                      the best match for the `search_string`.
              - `distance` (float): The semantic distance. A smaller distance indicates higher similarity.

        Example return structure for success:
        {
            "status": "success",
            "tool_name": "find_best_table_column_for_string",
            "query": "None",
            "messages": ["Successfully found best match."],
            "result": {
                            "dataset_id": "my_ecommerce_data",
                            "table_name": "products",
                            "column_name": "product_name",
                            "text_content": "Slayer Espresso Steam LP 3-Group",
                            "distance": 0.0512
                      }
        }
        Example return structure for no match/failure:
        {
            "status": "failed",
            "tool_name": "find_best_table_column_for_string",
            "query": "SQL query...",
            "messages": ["No suitable match found or an error occurred."],
            "result": None
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    if not project_id:
        return {
            "status": "failed",
            "tool_name": "find_best_table_column_for_string",
            "query": "None",
            "messages": ["AGENT_ENV_PROJECT_ID environment variable not set."],
            "result": None
        }

    response = {
        "status": "success",
        "tool_name": "find_best_table_column_for_string",
        "query": None,
        "messages": [],
        "result": None
    }

    # The SQL query uses BigQuery's VECTOR_SEARCH function to find the most similar text content
    # across all indexed columns within the specified dataset. It searches the
    # `data_analytics_agent_metadata.vector_embedding_metadata` table directly.
    sql = f"""SELECT
                base.dataset_name,
                base.table_name,
                base.column_name,
                base.text_content,
                ROUND(distance, 6) as distance
            FROM
                VECTOR_SEARCH(
                    (SELECT *
                     FROM `{project_id}.data_analytics_agent_metadata.vector_embedding_metadata`
                     WHERE dataset_name = '{dataset_id}'
                       AND array_length(text_embedding) = 768 -- Ensure valid embeddings
                    ),
                    'text_embedding',
                    (SELECT text_embedding,
                            content AS query
                       FROM ML.GENERATE_TEXT_EMBEDDING(MODEL `{project_id}.data_analytics_agent_metadata.textembedding_model`,
                                                       (SELECT '{search_string}' AS content),
                                                       STRUCT(TRUE AS flatten_json_output,
                                                              'SEMANTIC_SIMILARITY' as task_type,
                                                              768 AS output_dimensionality)
                                                       )),
                    top_k => 1 -- Only interested in the single best match
                )
            ORDER BY
                distance ASC
            LIMIT 1;
    """

    vector_search_result = run_bigquery_sql_helper.run_bigquery_sql(sql) # Added await
    response["query"] = sql # Store the query for debugging/info

    if vector_search_result["status"] == "failed":
        response["messages"].append(f"Failed to run SQL (Vector Search for best table/column): {sql}")
        response["messages"].extend(vector_search_result["messages"])
        response["status"] = "failed"
        return response

    if not vector_search_result["results"]:
        response["messages"].append(f"No suitable table or column found for '{search_string}' in dataset '{dataset_id}'.")
        response["status"] = "failed"
        return response

    # There should only be one result due to LIMIT 1
    best_match_row = vector_search_result["results"][0]
    
    response["result"] = {
        "dataset_id": best_match_row["dataset_name"],
        "table_name": best_match_row["table_name"],
        "column_name": best_match_row["column_name"],
        "text_content": best_match_row["text_content"],
        "distance": float(best_match_row["distance"]),
    }
    response["messages"].append(f"Successfully identified best table and column for '{search_string}'.")
    return response