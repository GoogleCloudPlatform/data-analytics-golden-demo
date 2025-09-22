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
import base64 # Not used in these functions, but kept from original
import re
# Removed requests.exceptions.HTTPError as httpx exceptions are used
# import asyncio # New: # import asyncio for async operations

import data_analytics_agent.rest_api_helper as rest_api_helper # Assuming this is your async version
import data_analytics_agent.gemini.gemini_helper as gemini_helper # Assuming this is async-compatible
import logging

logger = logging.getLogger(__name__)


datacatalog_agent_instruction = """**Your Core Identity and Goal:**
You are a highly intelligent **Data Catalog Search Agent**. Your primary function is to help users discover and understand data assets within the Google Cloud ecosystem. You act as an expert librarian, translating natural language questions into precise, structured search queries OR broad semantic queries to find tables, filesets, glossary terms, and other data resources. You also provide detailed governance information about specific data assets.

**Your Operational Playbook:**
You have three main operational modes: **Structured Discovery**, **Semantic Lookup**, and **Governance Inspection**.

**Mode 1: Structured Discovery (Finding Specific Assets with Criteria)**
This is for when a user asks to "find," "where is," "what," or "show me" questions that imply specific criteria like system, type, location, update time, or explicit custom metadata. You must use the `search_data_catalog` tool for these.

**Your Thought Process for `search_data_catalog`:**

1.  **Deconstruct the User's Request:** Break down the user's natural language question into key concepts. Identify names, descriptions, data types, systems (like BigQuery), locations, and any potential custom metadata or labels they mention. This mode is for queries that can be translated into the precise Dataplex Query Syntax.
    *   *User Question:* "Show me all sensitive BigQuery tables related to finance that were updated this year."
    *   *Deconstruction:*
        *   **System:** BigQuery -> `system=BIGQUERY`
        *   **Type:** tables -> `type=TABLE`
        *   **Keyword:** finance -> `description:finance` (or `name:finance`)
        *   **Timeframe:** updated this year -> `updatetime>YYYY-01-01` (replace with current year)
        *   **Governance:** sensitive -> This sounds like custom metadata. I should look for an aspect. Maybe `aspect:governance.sensitivity=PII` or `aspect:governance.is_sensitive=true`.

2.  **Construct the Search Query:** Using the deconstructed parts, build a valid query string according to the `Dataplex Query Syntax Guide` provided in the tool's docstring.
    *   **CRITICAL:** Pay close attention to the syntax. Use `( )` for grouping, `OR` for alternatives, and be mindful of case sensitivity (`type=TABLE`, not `type=table`).
    *   *Constructed Query:* `system=BIGQUERY AND type=TABLE AND (description:finance OR name:finance) AND updatetime>2024-01-01 AND aspect:governance.sensitivity=PII`

3.  **Execute and Present:**
    *   Call `search_data_catalog` with your constructed query.
    *   **Always show the user the exact query you used.** This provides transparency and helps them learn. Say, "I searched the data catalog with the following structured query: `[your_query_here]`".
    *   Summarize the results. For each result, highlight the key information: `displayName`, `linkedResource` (the path), and a brief snippet of the `description` if available. This makes the output human-readable.

**Mode 2: Semantic Lookup (Natural Language / Glossary)**
Use this mode when a user provides a general keyword, a natural language phrase, or asks to "look up" a concept, especially if it sounds like a glossary term or a broad, less structured search. This tool leverages semantic understanding of the query. You must use the `semantic_data_catalog_lookup` tool for these.

**Your Thought Process for `semantic_data_catalog_lookup`:**

1.  **Identify the Broad Request:** The user is asking a general question without specific structured criteria. Examples: "What is knowledge management?", "Look up 'customer lifetime value'", "Find anything about 'data governance best practices'".
    *   *User Question:* "Look up 'knowledge management'."
    *   *Deconstruction:* The direct phrase "knowledge management" is the natural language query.

2.  **Execute and Interpret:**
    *   Call `semantic_data_catalog_lookup` with the user's natural language phrase as the `query_string`.
    *   **Always show the user the natural language query you used.** Say, "I performed a semantic lookup in the data catalog for: `[your_query_here]`".
    *   Summarize the results, prioritizing relevance. For each result, highlight `displayName`, `linkedResource`, and `description`. Pay special attention to glossary terms if they appear in the results.

**Mode 3: Governance Inspection (Deep Dive)**
Use this mode when a user asks for specific governance details about a known table. This includes questions about "tags," "labels," "data owner," "steward," "data domain," "sensitivity level," or other governance-related terms.

**Your Thought Process for `get_data_governance_for_table`:**
1.  **Identify the Target Table:** The user must specify a table. If they only provide the table name, you might need to first use `get_bigquery_table_list()` or even `search_data_catalog` to find the correct `dataset_id`.
    *   *User Question:* "What are the governance tags on the `customers` table in the `sales` dataset?"
    *   *Deconstruction:*
        *   `dataset_id`: `sales`
        *   `table_name`: `customers`
2.  **Execute and Interpret:**
    *   Call `get_data_governance_for_table(dataset_id='sales', table_name='customers')`.
    *   The results will be in a JSON object under the `aspects` key. This is a dictionary of custom metadata.
    *   Do not just dump the raw JSON. Interpret it for the user. Summarize the key-value pairs from the `data` field within each aspect.
    *   *Example Interpretation:* "The `customers` table has the following governance information: It belongs to the 'Sales' data domain and is marked with a sensitivity level of 'PII'."

**General Principles:**
*   **Discern User Intent:** Carefully determine if the user is asking for:
    *   **Specific, filtered assets:** (e.g., "BigQuery tables updated this year") -> Use `search_data_catalog`.
    *   **Broad terms or concepts/glossary definitions:** (e.g., "knowledge management", "what is GDPR") -> Use `semantic_data_catalog_lookup`.
    *   **Governance details of a known asset:** (e.g., "tags on table X") -> Use `get_data_governance_for_table`.
*   **Start Broad (if unsure), Then Narrow:** If a user's initial query is vague (e.g., "find sales data"), and it doesn't clearly fit a structured query, consider starting with `semantic_data_catalog_lookup`. Present the results and then allow the user to refine their request, which might then lead to `search_data_catalog` for more specific filtering.
*   **Leverage All Tools:** If you can't find something with `semantic_data_catalog_lookup`, or the results are too broad, consider if `search_data_catalog` with a more constructed query might be better, or if `get_bigquery_table_list()` as a fallback could help.
*   **Be a Guide:** You are not just a search box. Your goal is to help the user navigate a complex data landscape. By showing your search queries (both structured and natural language) and interpreting results clearly, you empower the user.
"""


def search_data_catalog(query: str) -> dict: # Changed to def
    """Searches the data catalog for anything in the Google Data Cloud ecosystem.

    This is the most powerful discovery tool for finding data assets (like BigQuery tables
    or filesets) across a project. It uses a specific key-value query syntax to filter
    results based on metadata like name, description, columns, or custom metadata tags
    (aspects). Refer to the detailed syntax guide below.

    --- Dataplex Query Syntax Guide ---

    A query consists of one or more predicates joined by logical operators.
    NOTE: type=TABLE and system=BIGQUERY are case sensitive and must be uppercase.

    **1. Basic Predicates (Key-Value Search):**
    - `name:x`: Matches substring 'x' in the resource ID (e.g., table name).
    - `displayname:x`: Matches substring 'x' in the resource's display name.
    - `description:x`: Matches token 'x' in the resource's description.
    - `column:x`: Matches substring 'x' in any column name of the resource's schema.
    - `type=TABLE`: Matches resources of a specific type. 
       - Valid values for "type: BUCKET,CLUSTER,CODE_ASSET,CONNECTION,DASHBOARD,DASHBOARD_ELEMENT,DATABASE,DATABASE_SCHEMA,DATASET,DATA_EXCHANGE,DATA_SOURCE_CONNECTION,DATA_STREAM,EXPLORE,FEATURE_GROUP,FEATURE_ONLINE_STORE,FEATURE_VIEW,FILESET,FOLDER,FUNCTION,GLOSSARY,GLOSSARY_CATEGORY,GLOSSARY_TERM,LISTING,LOOK,MODEL,REPOSITORY,RESOURCE,ROUTINE,SERVICE,TABLE,VIEW
    - `system=BIGQUERY`: Matches resources from a specific system. 
       - Valid values for "system": BIGQUERY, CLOUD_STORAGE, ANALYTICS_HUB, CLOUD_BIGTABLE, CLOUD_PUBSUB, CLOUD_SPANNER, CLOUD_SQL, CUSTOM (for user created custom entries), DATAPLEX, DATAPROC_METASTORE, VERTEX_AI
    - `location=us-central1`: Matches resources in an exact location.
    - `projectid:my-project`: Matches substring 'my-project' in the project ID.
    - `fully_qualified_name:path.to.asset`: Matches substring in the FQN.

    **2. Time-Based Search (createtime, updatetime):**
    - Use operators `=`, `>`, `<`, `>=`, `<=`. Timestamps must be GMT (YYYY-MM-DDThh:mm:ss).
    - `createtime>2023-10-01`: Finds resources created after Oct 1, 2023.
    - `updatetime<2023-01-01T12:00:00`: Finds resources updated before noon on Jan 1, 2023.

    **3. Label Search (for BigQuery resources):**
    - `label:my-label`: The key of the label contains 'my-label'.
    - `label=my-label`: The key of the label is exactly 'my-label'.
    - `label:my-label:some-value`: The value of the label with key 'my-label' contains 'some-value'.
    - `label=my-label=exact-value`: The value of the label with key 'my-label' is exactly 'exact-value'.

    **4. Aspect Search (Custom Metadata):**
    - Search based on custom metadata "aspects" attached to an entry.
    - `aspect:path.to.aspect_type`: Matches entries that have this aspect type attached.
    - `aspect:path.to.field=value`: Searches for specific values within an aspect's fields.
      - Example: `aspect:my_project.us.governance.is_sensitive=true`
      - Example: `aspect:governance.owner_email:"data-team@example.com"`

    **5. Logical Operators:**
    - `AND` is the default. `system=bigquery name:orders` finds BigQuery tables with 'orders' in the name.
    - `OR` must be explicit. `name:customers OR name:users`.
    - `NOT` or `-` for negation. `-system:BIGQUERY` finds assets not in BigQuery.
    - `()` for grouping. `system=bigquery AND (name:orders OR name:sales)`.

    --- Common Use Case Examples ---

    - **Find all BigQuery tables with 'customer' in the name or description:**
      `system=bigquery type=table (name:customer OR description:customer)`

    - **Find sensitive financial tables updated this year:**
      `description:financial updatetime>2024-01-01 aspect:governance.sensitivity=PII`

    - **Find tables in the 'sales' dataset owned by 'sales-team@example.com':**
      `fully_qualified_name:sales. aspect:stewardship.owner="sales-team@example.com"`

    When showing the results to the user ALWAYS show the query.      

    Args:
        query (str): The search query string following the Dataplex syntax outlined above.
        
    Returns:
        dict:
          {
            "status": "success",
            "tool_name": "search_data_catalog",
            "query": "The data catalog query used",
            "messages": ["List of messages during processing"]
            "results": [
                            {
                                "linkedResource": "projects/{project-id}/datasets/{dataset-id}/models/gemini_model",
                                "dataplexEntry": {
                                    "name": "projects/{project-number}/locations/us/entryGroups/@bigquery/entries/bigquery.googleapis.com/projects/{project-id}/datasets/{dataset-id}/models/gemini_model",
                                    "entryType": "projects/{project-number}/locations/global/entryTypes/bigquery-model",
                                    "createTime": "2025-06-12T14:00:04.724264Z",
                                    "updateTime": "2025-06-12T14:00:04.724264Z",
                                    "parentEntry": "projects/{project-number}/locations/us/entryGroups/@bigquery/entries/bigquery.googleapis.com/projects/{project-id}/datasets/{dataset-id}",
                                    "fullyQualifiedName": "bigquery:{project-id}.{dataset-id}.gemini_model",
                                    "entrySource": {
                                        "resource": "projects/{project-id}/datasets/{dataset-id}/models/gemini_model",
                                        "system": "BIGQUERY",
                                        "displayName": "gemini_model",
                                        "ancestors": [
                                            {
                                                "name": "projects/{project-id}/datasets/{dataset-id}",
                                                "type": "dataplex-types.global.bigquery-dataset"
                                            }
                                        ],
                                        "createTime": "2025-06-12T14:00:04.232Z",
                                        "updateTime": "2025-06-12T14:00:04.280Z",
                                        "location": "us"
                                    }
                                },
                                "snippets": {}
                            }
                        ]
            }         
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_search_region = os.getenv("AGENT_ENV_DATAPLEX_SEARCH_REGION")
    messages = []

    # The searchEntries endpoint is a POST request with the query in the body
    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_search_region}:searchEntries"

    # The payload for the POST request
    payload = {
        "pageSize": 50,
        "query": query,
        # If you do "True" then you get results that are not specific for specific filters.
        # e.g. it does not obey the exact aspect type search syntax and instead treats it like a string
        "semanticSearch": False,
        "scope": f"projects/{project_id}" # Just to keep it simple just search this project
    }

    messages.append(f"Calling {url} with a payload of {payload}")
 
    try:
        response = rest_api_helper.rest_api_helper(url, "POST", payload) # Added await
        logger.debug(f"search_data_catalog -> response: {json.dumps(response, indent=2)}")

        return_value = { "status": "success", "tool_name": "search_data_catalog", "query": query, "messages": messages, "results": response.get("results", []) } # Safely get results
        logger.debug(f"search_data_catalog -> return_value: {json.dumps(return_value, indent=2)}")
        return return_value            

    except Exception as e:
        messages.append(f"Error when calling rest api: {e}")
        return_value = { "status": "failed", "tool_name": "search_data_catalog", "query": query, "messages": messages, "results": None }   
        return return_value
    


def semantic_data_catalog_lookup(query_string: str) -> dict: # Changed to def
    """Performs a broad, natural language search across the Google Data Catalog,
    ideal for finding glossary terms, general keywords, or when the user doesn't
    provide specific structured search criteria. This search leverages semantic
    matching to interpret less structured queries.

    Args:
        query_string (str): The natural language phrase or keyword to search for,
                            e.g., "knowledge management", "customer data definition".

    Returns:
        dict:
          {
            "status": "success",
            "tool_name": "semantic_data_catalog_lookup",
            "query": "The natural language query used",
            "messages": ["List of messages during processing"]
            "results": [
                            {
                                "linkedResource": "projects/{project-id}/datasets/{dataset-id}/models/gemini_model",
                                "dataplexEntry": {
                                    "name": "projects/{project-number}/locations/us/entryGroups/@bigquery/entries/bigquery.googleapis.com/projects/{project-id}/datasets/{dataset-id}/models/gemini_model",
                                    "entryType": "projects/{project-number}/locations/global/entryTypes/bigquery-model",
                                    "createTime": "2025-06-12T14:00:04.724264Z",
                                    "updateTime": "2025-06-12T14:00:04.724264Z",
                                    "parentEntry": "projects/{project-number}/locations/us/entryGroups/@bigquery/entries/bigquery.googleapis.com/projects/{project-id}/datasets/{dataset-id}",
                                    "fullyQualifiedName": "bigquery:{project-id}.{dataset-id}.gemini_model",
                                    "entrySource": {
                                        "resource": "projects/{project-id}/datasets/{dataset-id}/models/gemini_model",
                                        "system": "BIGQUERY",
                                        "displayName": "gemini_model",
                                        "ancestors": [
                                            {
                                                "name": "projects/{project-id}/datasets/{dataset-id}",
                                                "type": "dataplex-types.global.bigquery-dataset"
                                            }
                                        ],
                                        "createTime": "2025-06-12T14:00:04.232Z",
                                        "updateTime": "2025-06-12T14:00:04.280Z",
                                        "location": "us"
                                    }
                                },
                                "snippets": {}
                            }
                        ]
            }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataplex_search_region = os.getenv("AGENT_ENV_DATAPLEX_SEARCH_REGION")
    messages = []

    url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{dataplex_search_region}:searchEntries"

    payload = {
        "pageSize": 50,
        "query": query_string,      # The natural language query from the user
        "semanticSearch": True,     # Crucial for natural language interpretation
        "scope": f"projects/{project_id}"
    }

    messages.append(f"Calling {url} with a payload of {payload}")

    try:
        response = rest_api_helper.rest_api_helper(url, "POST", payload) # Added await
        logger.debug(f"semantic_data_catalog_lookup -> response: {json.dumps(response, indent=2)}")

        return_value = { "status": "success", "tool_name": "semantic_data_catalog_lookup", "query": query_string, "messages": messages, "results": response.get("results", []) }
        logger.debug(f"semantic_data_catalog_lookup -> return_value: {json.dumps(return_value, indent=2)}")
        return return_value

    except Exception as e:
        messages.append(f"Error when calling rest api: {e}")
        return_value = { "status": "failed", "tool_name": "semantic_data_catalog_lookup", "query": query_string, "messages": messages, "results": None }
        return return_value