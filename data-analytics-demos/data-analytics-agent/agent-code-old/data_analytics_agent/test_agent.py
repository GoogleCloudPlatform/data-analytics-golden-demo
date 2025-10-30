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
# source .venv/bin/activate 
# cd /Users/paternostro/adk-web/
# python -m data_analytics_agent.test_agent test-data-eng-agent

import argparse

from dotenv import load_dotenv

from google.adk.agents import LlmAgent
from google.adk.planners import BuiltInPlanner
from google.genai.types import ThinkingConfig

import data_analytics_agent.bigquery.run_bigquery_sql as run_bigquery_sql 
import data_analytics_agent.bigquery.get_bigquery_table_schema as get_bigquery_table_schema
import data_analytics_agent.bigquery.get_bigquery_table_list as get_bigquery_table_list

import data_analytics_agent.google_search.google_search as google_search

import data_analytics_agent.dataplex.data_governance as data_governance
import data_analytics_agent.dataplex.data_catalog as data_catalog
import data_analytics_agent.dataplex.data_profile as data_profile
import data_analytics_agent.dataplex.data_insights as data_insights
import data_analytics_agent.dataplex.data_quality as data_quality
import data_analytics_agent.dataplex.data_discovery as data_discovery

import data_analytics_agent.conversational_analytics.conversational_analytics_auto_create_agent as conversational_analytics_auto_create_agent
import data_analytics_agent.conversational_analytics.conversational_analytics_chat as conversational_analytics_chat
import data_analytics_agent.conversational_analytics.conversational_analytics_conversation as conversational_analytics_conversation
import data_analytics_agent.conversational_analytics.conversational_analytics_data_agent as conversational_analytics_data_agent
import data_analytics_agent.data_engineering_agent.data_engineering_agent as data_engineering_agent


if __name__ == "__main__":
    load_dotenv()

    print()
    print()
    print("===================================================================================================")
    print()
    print()

    # Set up argument parser
    parser = argparse.ArgumentParser(description="Run tests for the data analytics agent.")
    parser.add_argument("test_name", type=str, help="The name of the test to run.")

    args = parser.parse_args()

    if args.test_name == "test-data-eng-agent":
        repository_name = "auto-agent-21"
        workspace_name = "default"
        dataform_repo_or_bigquery_pipeline = "PIPELINE" # "DATAFORM" # PIPELINE
        prompt = """Create a bigquery pipeline named "auto-agent-21"
        Make the files fields (borough, zone and service_zone) all uppercase in the
        dataset:data_eng_dataset table:location and saved to a new table in the same dataset named: auto_agent_21"""

        # prompt = "bla bla bla"  # cause error for rollback

        execute_data_engineering_task_result = data_engineering_agent.execute_data_engineering_task(repository_name, dataform_repo_or_bigquery_pipeline, prompt)

        print()
        print()
        print(f"execute_data_engineering_task_result: {execute_data_engineering_task_result}")

        if execute_data_engineering_task_result["status"] == "success":
            clean_workflow_name = execute_data_engineering_task_result["workflow_name"]
            workflow_invocation_id = execute_data_engineering_task_result["workflow_invocation_id"]
            get_worflow_invocation_status_result = data_engineering_agent.get_worflow_invocation_status(clean_workflow_name, workflow_invocation_id)

            print()
            print()
            print(f"get_worflow_invocation_status_result: {get_worflow_invocation_status_result}")      

    else:
        print(f"Error: Test '{args.test_name}' not found.")
    

    print()
    print()
    print("===================================================================================================")
    print()
    print()    