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
import yaml 
import logging
import asyncio

import data_analytics_agent.utils.rest_api.rest_api_helper as rest_api_helper 

import data_analytics_agent.tools.bigquery.bigquery_table_tools as bigquery_table_tools

import data_analytics_agent.utils.gemini.gemini_helper as gemini_helper

logger = logging.getLogger(__name__)


async def conversational_analytics_data_agent_list() -> dict: 
    """
    Lists all available Conversational Analytics Data Agents in the configured project and region.

    This tool is useful for discovering which agents have already been created.

    Returns:
        dict: A standard agent tool dictionary containing the status and results.
        {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_list",
            "query": None,
            "messages": ["Successfully listed conversational data agents."],
            "results": {
                "dataAgents": [
                    {
                        "name": "projects/your-project/locations/global/dataAgents/sales-agent-1",
                        "createTime": "2024-01-01T12:00:00Z",
                        "data_analytics_agent": {
                            "published_context": {
                                "datasource_references": {"bq": {"tableReferences": [{"tableId": "sales"}]}},
                                "system_instruction": "You are a sales analyst..."
                            }
                        }
                    },
                    {
                        "name": "projects/your-project/locations/global/dataAgents/support-agent-2",
                        "createTime": "2024-01-02T14:30:00Z",
                        "data_analytics_agent": {
                            "published_context": {
                                "datasource_references": {"bq": {"tableReferences": [{"tableId": "tickets"}]}},
                                "system_instruction": "You are a customer support analyst..."
                            }
                        }
                    }
                ]
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    global_location = os.getenv("AGENT_ENV_CONVERSATIONAL_ANALYTICS_REGION")
    messages = []
    url = f"https://geminidataanalytics.googleapis.com/v1alpha/projects/{project_id}/locations/{global_location}/dataAgents"

    try:
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) 
        messages.append("Successfully listed conversational data agents.")
        return {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_list",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while listing data agents: {e}")
        return {
            "status": "failed",
            "tool_name": "conversational_analytics_data_agent_list",
            "query": None,
            "messages": messages,
            "results": None
        }


async def conversational_analytics_data_agent_exists(data_agent_id: str) -> dict: 
    """
    Checks if a Conversational Analytics Data Agent with a specific ID already exists.

    This is a key utility to prevent errors when attempting to create a data agent with
    an ID that is already in use.

    Args:
        data_agent_id (str): The short, unique identifier for the data agent to check.

    Returns:
        dict: A standard agent tool dictionary containing the status and a boolean result.
        {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_exists",
            "query": None,
            "messages": ["Data agent 'sales-agent-1' already exists."],
            "results": {
                "exists": True
            }
        }
    }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    global_location = os.getenv("AGENT_ENV_CONVERSATIONAL_ANALYTICS_REGION")

    list_result = await conversational_analytics_data_agent_list() 
    messages = list_result.get("messages", [])

    if list_result["status"] == "failed":
        return list_result

    try:
        agent_exists = False
        full_agent_name = f"projects/{project_id}/locations/{global_location}/dataAgents/{data_agent_id}"
        for item in list_result.get("results", {}).get("dataAgents", []):
            if item.get("name") == full_agent_name:
                agent_exists = True
                messages.append(f"Data agent '{data_agent_id}' already exists.")
                break
        
        if not agent_exists:
            messages.append(f"Data agent '{data_agent_id}' does not exist.")

        return {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_exists",
            "query": None,
            "messages": messages,
            "results": {"exists": agent_exists}
        }
    except Exception as e:
        messages.append(f"An error occurred while checking for data agent existence: {e}")
        return {
            "status": "failed",
            "tool_name": "conversational_analytics_data_agent_exists",
            "query": None,
            "messages": messages,
            "results": None
        }


async def conversational_analytics_data_agent_get(data_agent_id: str) -> dict: 
    """
    Retrieves the full configuration and details of a single, specified data agent.

    Use this tool when you need to inspect the system instructions or data sources
    of a known data agent.

    Args:
        data_agent_id (str): The short, unique identifier for the data agent to retrieve.

    Returns:
        dict: A standard agent tool dictionary containing the status and the full agent resource.
        {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_get",
            "query": None,
            "messages": ["Successfully retrieved data agent 'sales-agent-1'."],
            "results": {
                "name": "projects/your-project/locations/global/dataAgents/sales-agent-1",
                "createTime": "2024-01-01T12:00:00Z",
                "data_analytics_agent": {
                    "published_context": {
                        "datasource_references": {"bq": {"tableReferences": [{"tableId": "sales"}]}},
                        "system_instruction": "You are a sales analyst..."
                    }
                }
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    global_location = os.getenv("AGENT_ENV_CONVERSATIONAL_ANALYTICS_REGION")
    messages = []
    url = f"https://geminidataanalytics.googleapis.com/v1alpha/projects/{project_id}/locations/{global_location}/dataAgents/{data_agent_id}"

    try:
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None)
        messages.append(f"Successfully retrieved data agent '{data_agent_id}'.")
        return {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_get",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while getting data agent '{data_agent_id}': {e}")
        return {
            "status": "failed",
            "tool_name": "conversational_analytics_data_agent_get",
            "query": None,
            "messages": messages,
            "results": None
        }


async def conversational_analytics_data_agent_create(data_agent_id: str, system_instruction: str, bigquery_data_source: dict, enable_python: bool = False) -> dict: 
    """
    Creates a new Conversational Analytics Data Agent if it does not already exist.

    This tool requires a pre-formatted system instruction (often YAML) and a dictionary
    defining the BigQuery data sources the agent can access.

    Args:
        data_agent_id (str): The desired unique ID for the new data agent.
        system_instruction (str): The detailed prompt and configuration (e.g., in YAML format)
                                  that defines the agent's persona, knowledge, and rules.
        bigquery_data_source (dict): A dictionary specifying the BigQuery tables.
                                     Example: {"bq": {"tableReferences": [{"tableId": "sales"}]}}
        enable_python (bool, optional): Flag to enable Python code generation. Defaults to False.

    Returns:
        dict: A standard agent tool dictionary with the status and API response.
        {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_create",
            "query": None,
            "messages": ["Successfully created data agent 'new-sales-agent'."],
            "results": {
                "name": "operations/12345",
                "metadata": {
                    "@type": "type.googleapis.com/google.cloud.gemini.v1alpha.OperationMetadata",
                    "target": "projects/your-project/locations/global/dataAgents/new-sales-agent"
                }
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    global_location = os.getenv("AGENT_ENV_CONVERSATIONAL_ANALYTICS_REGION")

    existence_check = await conversational_analytics_data_agent_exists(data_agent_id)
    messages = existence_check.get("messages", [])

    if existence_check["status"] == "failed":
        return existence_check

    if existence_check["results"]["exists"]:
        return {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_create",
            "query": None,
            "messages": messages,
            "results": {"created": False, "reason": "Data agent already exists."}
        }

    url = f"https://geminidataanalytics.googleapis.com/v1alpha/projects/{project_id}/locations/{global_location}/dataAgents?data_agent_id={data_agent_id}"
    request_body = {
        "data_analytics_agent": {
            "published_context": {
                "datasource_references": bigquery_data_source,
                "system_instruction": system_instruction,
                "options": {"analysis": {"python": {"enabled": enable_python}}}
            }
        }
    }

    try:
        json_result = await rest_api_helper.rest_api_helper(url, "POST", request_body)
        messages.append(f"Successfully created data agent '{data_agent_id}'.")
        return {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_create",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while creating data agent '{data_agent_id}': {e}")
        return {
            "status": "failed",
            "tool_name": "conversational_analytics_data_agent_create",
            "query": None,
            "messages": messages,
            "results": None
        }


async def conversational_analytics_data_agent_delete(data_agent_id: str) -> dict: 
    """
    Permanently deletes a specified Conversational Analytics Data Agent.

    Warning: This action is irreversible and will remove the agent and its configuration.

    Args:
        data_agent_id (str): The short, unique identifier of the data agent to delete.

    Returns:
        dict: A standard agent tool dictionary indicating the outcome.
        {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_delete",
            "query": None,
            "messages": ["Successfully deleted data agent 'old-agent'."],
            "results": {}
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    global_location = os.getenv("AGENT_ENV_CONVERSATIONAL_ANALYTICS_REGION")
    messages = []
    url = f"https://geminidataanalytics.googleapis.com/v1alpha/projects/{project_id}/locations/{global_location}/dataAgents/{data_agent_id}"

    try:
        # A successful DELETE often returns an empty JSON object.
        json_result = await rest_api_helper.rest_api_helper(url, "DELETE", None) 
        messages.append(f"Successfully deleted data agent '{data_agent_id}'.")
        return {
            "status": "success",
            "tool_name": "conversational_analytics_data_agent_delete",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        messages.append(f"An error occurred while deleting data agent '{data_agent_id}': {e}")
        return {
            "status": "failed",
            "tool_name": "conversational_analytics_data_agent_delete",
            "query": None,
            "messages": messages,
            "results": None
        }


async def create_conversational_analytics_data_agent(conversational_analytics_data_agent_id:str, bigquery_table_list: list[dict]) -> dict: 
    """
    Orchestrates the creation of a complete Conversational Analytics Data Agent.
    
    This high-level workflow performs the following steps:
    1. Checks if the agent already exists.
    2. Gathers BigQuery schema information for the provided tables.
    3. Uses a Large Language Model (LLM) to generate a comprehensive system instruction YAML.
    4. Creates the data agent using the generated instruction and data sources.
    
    Args:
        conversational_analytics_data_agent_id (str): The desired ID for the new data agent.
        bigquery_table_list (list[dict]): A list of dictionaries, each specifying a 
                                           BigQuery table with 'dataset_name' and 'table_name'.
                                           e.g.:
                                           {
                                                "dataset_name" : "governed_data_curated",
                                                "table_name" : "customer",
                                           }

    Returns:
        dict: A dictionary containing the status, a log of messages, and the results of the operation.
              {
                  "status": "success" or "failed",
                  "tool_name": "create_conversational_analytics_data_agent",
                  "query": None,
                  "messages": ["List of messages during processing"],
                  "results": { ... response from the API call or status info ... }
              }
    """
    tool_name = "create_conversational_analytics_data_agent"
    messages = []
    
    # --- Step 1: Check if the data agent already exists ---
    # this call as conversational_analytics_data_agent_exists should be async
    existence_check = await conversational_analytics_data_agent_exists(conversational_analytics_data_agent_id)
    messages.extend(existence_check.get("messages", []))

    if existence_check["status"] == "failed":
        return {
            "status": "failed", "tool_name": tool_name, "query": None, 
            "messages": messages, "results": None
        }

    if existence_check["results"]["exists"]:
        # This is a successful outcome, but no creation occurred.
        return {
            "status": "success", "tool_name": tool_name, "query": None,
            "messages": messages, "results": {"created": False, "reason": "Data agent already exists."}
        }

    # --- Step 2: Prepare data sources and prompts ---
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    table_references = []
    table_descriptions = ""
    table_names = ""

    if bigquery_table_list is None or len(bigquery_table_list) == 0:
        messages.append("The bigquery_table_list is empty or null.")
        return {
            "status": "failed", "tool_name": tool_name, "query": None,
            "messages": messages, "results": None
        }
    
    messages.append("Preparing data sources and gathering table schemas.")
    
    schema_fetch_tasks = []
    for item in bigquery_table_list:
        table_id_full = f"{project_id}.{item['dataset_name']}.{item['table_name']}"
        table_names += f"- {table_id_full}\n"
        table_references.append({
            "projectId": project_id,
            "datasetId": item["dataset_name"],
            "tableId": item["table_name"],
        })
        # Create a task for each schema fetch
        schema_fetch_tasks.append(
            bigquery_table_tools.get_bigquery_table_schema(item['dataset_name'], item['table_name'])
        )
    
    # all schema fetch tasks
    all_schemas_results = await asyncio.gather(*schema_fetch_tasks)

    for i, schema_result in enumerate(all_schemas_results):
        item = bigquery_table_list[i] # Get the corresponding table info
        table_id_full = f"{project_id}.{item['dataset_name']}.{item['table_name']}"
        if schema_result["status"] == "success":
            table_descriptions += f"- {table_id_full}: {json.dumps(schema_result['results'], indent=2)}\n"
        else:
            table_descriptions += f"- {table_id_full}: Error fetching schema - {'; '.join(schema_result['messages'])}\n"
            messages.append(f"Warning: Failed to retrieve schema for {table_id_full}. Error: {'; '.join(schema_result['messages'])}")


    bigquery_data_source = {"bq": {"tableReferences": table_references}}
    messages.append("Successfully prepared BigQuery data source references.")

    # --- Step 3: Use Gemini to generate the system instruction YAML ---
    # The full, long prompt from your original code goes here.
    conversational_analytics_prompt = f"""I need to create a model that will be used for natural language to SQL.

        Goal:
        - Generate a valid Yaml file that is based upon the example provided.

        Tables to include in the model:
        {table_names}

        Descriptions and Schema for each table:
        {table_descriptions}

        Break the problem down into steps.
        - Think through each table one by one.
        - Think through how the tables can join.
        - Create some valid golden queries.

        Example Yaml file:

        - system_description:
            You are an expert sales analyst and understand how to answer questions about
            the sales data for a fictitious e-commence store.
        - tables:
            - table:
                - name: project-id.dataset-id.orders
                - description: orders for The Look fictitious e-commerce store.
                - synonyms: sales
                - tags: 'sale, order, sales_order'
                - fields:
                    - field:
                        - name: order_id
                        - description: unique identifier for each order
                    - field:
                        - name: user_id
                        - description: unique identifier for each user
                    - field:
                        - name: status
                        - description: status of the order
                        - sample_values:
                            - complete
                            - shipped
                            - returned
                    - field:
                        - name: created_at
                        - description: date and time when the order was created in timestamp format
                    - field:
                        - name: returned_at
                        - description: >-
                            date and time when the order was returned in timestamp
                            format
                    - field:
                        - name: num_of_item
                        - description: number of items in the order
                        - aggregations: 'sum, avg'
                    - field:
                        - name: earnings
                        - description: total sales from the order
                        - aggregations: 'sum, avg'
                    - field:
                        - name: cost
                        - description: total cost to get the items for the order
                        - aggregations: 'sum, avg'
                - measures:
                    - measure:
                        - name: profit
                        - description: raw profit
                        - exp: cost - earnings
                        - synonyms: gains
            - table:
                - name: project-id.dataset-id..users
                - description: user of The Look fictitious e-commerce store.
                - synonyms: customers
                - tags: 'user, customer, buyer'
                - fields:
                    - field:
                        - name: id
                        - description: unique identifier for each user
                    - field:
                        - name: first_name
                        - description: first name of the user
                        - tag: person
                        - sample_values: 'graham, sara, brian'
                    - field:
                        - name: last_name
                        - description: first name of the user
                        - tag: person
                        - sample_values: 'warmer, stilles, smith'
                    - field:
                        - name: region
                        - description: region of the user
                        - sample_values:
                            - west
                            - east
                            - northwest
                            - south
                    - field:
                        - name: email
                        - description: email of the user
                        - tag: contact
                        - sample_values: '222larabrown@gmail.com, cloudysanfrancisco@gmail.com'
        - golden_queries:
        - golden_query:
            - natural_language_query: How many orders are there?
            - sql_query: SELECT COUNT(*) FROM project-id.dataset-id..orders
        - golden_query:
            - natural_language_query: How many orders were shipped?
            - sql_query: >-
                        SELECT COUNT(*) FROM project-id.dataset-id..orders
                        WHERE status = 'shipped'
        - golden_query:
            - natural_language_query: How many unique customers are there?
            - sql_query: >-
                        SELECT COUNT(DISTINCT id) FROM
                            project-id.dataset-id..users
        - golden_query:
            - natural_language_query: How many southern users have cymbalgroup email id?
            - sql_query: >-
                        SELECT COUNT(DISTINCT id) FROM
                        project-id.dataset-id..users WHERE users.region =
                        'south' AND users.email LIKE '%@cymbalgroup.com';
        - golden_action_plans:
        - golden_action_plan:
            - natural_language_query: Show me the number of orders broken down by status.
            - action_plan:
            - step: >-
                    Run a SQL query on the table
                    project-id.dataset-id..orders to get a
                    breakdown of order count by status.
            - step: >-
                    Create a vertical bar plot using the retrieved data,
                    with one bar per status.
        - relationships:
        - relationship:
            - name: earnings_to_user
            - description: >-
                        Sales table is related to the users table and can be joined for
                        aggregated view.
            - relationship_type: many-to-one
            - join_type: left
            - left_table: project-id.dataset-id..orders
            - right_table: project-id.dataset-id..users
            - relationship_columns: '// Join columns - left_column:''user_id'' - right_column:''id'''
        - glossaries:
            - glossary:
                - term: complete
                - description: complete status
                - synonyms: 'finish, done, fulfilled'
            - glossary:
                - term: shipped
                - description: shipped status
            - glossary:
                - term: returned
                - description: returned status
            - glossary:
                - term: OMPF
                - description: Order Management and Product Fulfillment
        - additional_instructions:
            - text: All the sales data is for Looker organization.
            - text: Orders can be of three categories food, clothes, electronics.
        """

    response_schema = {
        "type": "object",
        "properties": {"generated_yaml": {"type": "string"}},
        "required": ["generated_yaml"]
    }

    messages.append("Generating system instruction YAML with Gemini...")
    try:
        logger.debug(conversational_analytics_prompt)
        # this call as gemini_helper.gemini_llm should be async
        gemini_response = await gemini_helper.gemini_llm(conversational_analytics_prompt, response_schema=response_schema)
        gemini_response_json = json.loads(gemini_response)
        system_instruction = gemini_response_json["generated_yaml"]
        logger.debug("*** system_instruction ***")
        logger.debug(system_instruction)
        logger.debug("*************************")
        yaml.safe_load(system_instruction) # Validate YAML syntax (synchronous, but fast)
        messages.append("✅ Generated System prompt YAML syntax is valid.")
    except Exception as e:
        messages.append(f"❌ ERROR: Failed to generate or validate system instruction YAML: {e}")
        return {
            "status": "failed", "tool_name": tool_name, "query": None,
            "messages": messages, "results": None
        }

    # --- Step 4: Create the Conversational Agent using the agent tool ---
    messages.append("Creating the Conversational Agent...")
    # this call as conversational_analytics_data_agent_create should be async
    create_result = await conversational_analytics_data_agent_create(
        data_agent_id=conversational_analytics_data_agent_id,
        system_instruction=system_instruction,
        bigquery_data_source=bigquery_data_source,
        enable_python=False
    )
    messages.extend(create_result.get("messages", []))

    # Return the final result, packaging it in the standard format.
    return {
        "status": create_result["status"],
        "tool_name": tool_name,
        "query": None,
        "messages": messages,
        "results": create_result.get("results")
    }