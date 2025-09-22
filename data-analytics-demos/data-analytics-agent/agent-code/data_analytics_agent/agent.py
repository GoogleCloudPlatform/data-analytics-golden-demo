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
import logging

from dotenv import load_dotenv

from google.adk.agents import LlmAgent
from google.adk.planners import BuiltInPlanner
from google.genai.types import ThinkingConfig
from google.genai import types

# Global Instruction
import data_analytics_agent.global_instruction as global_instruction_helper

# AI.GENERATE_BOOL
import data_analytics_agent.ai_generate_bool.ai_generate_bool as ai_generate_bool_helper

# AI.Forcast
import data_analytics_agent.ai_forecast.ai_forecast as ai_forecast

# BigQuery
import data_analytics_agent.bigquery.get_bigquery_dataset_list as get_bigquery_dataset_list
import data_analytics_agent.bigquery.run_bigquery_sql as run_bigquery_sql
import data_analytics_agent.bigquery.get_bigquery_table_schema as get_bigquery_table_schema
import data_analytics_agent.bigquery.get_bigquery_table_list as get_bigquery_table_list
import data_analytics_agent.bigquery.vector_search_column_values as vector_search_column_values
import data_analytics_agent.bigquery.agent_instructions as bigquery_agent_instructions

# Business Glossary
import data_analytics_agent.business_glossary.business_glossary as business_glossary

# Conversational Analytics
import data_analytics_agent.conversational_analytics.conversational_analytics_auto_create_agent as conversational_analytics_auto_create_agent
import data_analytics_agent.conversational_analytics.conversational_analytics_chat as conversational_analytics_chat
import data_analytics_agent.conversational_analytics.conversational_analytics_conversation as conversational_analytics_conversation
import data_analytics_agent.conversational_analytics.conversational_analytics_data_agent as conversational_analytics_data_agent
import data_analytics_agent.conversational_analytics.agent_instructions as conversational_analytics_agent_instructions

# Data Eng Agent - This is the *original* data_engineering_agent.py (now DataEngineering_OldAgentic)
import data_analytics_agent.data_engineering_agent.data_engineering_agent as data_engineering_helper 

# Data Eng Agent Autonomous
import data_analytics_agent.data_engineering_agent_autonomous.data_engineering_tools as de_tools

# ---- Agentic Approach (still used by DataEngineering in agent.py directly if not workflow)
import data_analytics_agent.data_engineering_agent_autonomous.data_engineering_agent_autonomous as data_engineering_agent_autonomous_helper

# ---- Workflow Approach for DQ Fix (shared session)
import data_analytics_agent.data_engineering_agent_autonomous.data_engineering_workflow_shared_session_agent as de_workflow_shared_session_agent_helper
import data_analytics_agent.data_engineering_agent_autonomous.data_engineering_tool_session as de_tool_session_helper

# ---- NEW: Workflow Approach for Creation/Modification (custom agent, no session tool needed)
import data_analytics_agent.data_engineering_agent.data_engineering_workflow_custom_agent as de_workflow_custom_agent_helper


# Dataform
import data_analytics_agent.dataform.dataform as dataform_helper

# Dataplex
import data_analytics_agent.dataplex.data_governance as data_governance
import data_analytics_agent.dataplex.data_catalog as data_catalog
import data_analytics_agent.dataplex.data_profile as data_profile # Keep this for the other tools in dataprofile_agent
import data_analytics_agent.dataplex.data_insights as data_insights
import data_analytics_agent.dataplex.data_quality as data_quality
import data_analytics_agent.dataplex.data_discovery as data_discovery

# Google Search
import data_analytics_agent.google_search.google_search as google_search

# Knowledge Engine
import data_analytics_agent.knowledge_engine.knowledge_engine as knowledge_engine
import data_analytics_agent.knowledge_engine_business_glossary.knowledge_engine_business_glossary as knowledge_engine_business_glossary

# Time delay
import data_analytics_agent.wait_tool as wait_tool

# --- IMPORTS for the Orchestrator/Workflow patterns ---
# Updated imports to reflect the new proposed filenames for clarity and consistency
import data_analytics_agent.dataplex.data_profile_workflow.data_profile_workflow_isolated_session_agent as data_profile_workflow_isolated_session_agent_helper
import data_analytics_agent.dataplex.data_profile_workflow.data_profile_workflow_shared_session_agent as data_profile_workflow_shared_session_agent_helper
import data_analytics_agent.dataplex.data_profile_workflow.data_profile_workflow_tool_agent as data_profile_workflow_tool_agent_helper

import data_analytics_agent.dataplex.data_profile_workflow.data_profile_tool_session as data_profile_tool_session_helper

import data_analytics_agent.data_engineering_agent_autonomous.data_engineering_reset_demo as data_engineering_reset_demo_helper

# Sample prompts
import data_analytics_agent.sample_prompts.sample_prompts as sample_prompts_helper

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

# This is not using the ADK serach tool, it uses it seperately
search_agent = LlmAgent(name="Search",
                        description="Runs a Google internet search. Returns progress log and final results.",
                        instruction=google_search.search_agent_instruction,
                        global_instruction=global_instruction_helper.global_protocol_instruction,
                        tools=[google_search.google_search], # google_search.py now returns a dict
                        model="gemini-2.5-flash",
                        planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                        generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=65536))


bigquery_agent = LlmAgent(name="BigQuery",
                          description="Runs BigQuery queries.",
                          instruction=bigquery_agent_instructions.bigquery_agent_instruction,
                          global_instruction=global_instruction_helper.global_protocol_instruction,
                          tools=[ get_bigquery_table_list.get_bigquery_table_list,
                                  get_bigquery_table_schema.get_bigquery_table_schema,
                                  vector_search_column_values.vector_search_column_values,
                                  vector_search_column_values.find_best_table_column_for_string,
                                  run_bigquery_sql.run_bigquery_sql,
                                  get_bigquery_dataset_list.get_bigquery_dataset_list
                                ],
                          model="gemini-2.5-flash",
                          planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                          generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=65536))


datacatalog_agent = LlmAgent(name="DataCatalog",
                             description="Searches the data catalog.",
                             instruction=data_catalog.datacatalog_agent_instruction,
                             global_instruction=global_instruction_helper.global_protocol_instruction,
                             tools=[ get_bigquery_table_list.get_bigquery_table_list,
                                     data_catalog.search_data_catalog,
                                     data_governance.get_data_governance_for_table
                                   ],
                             model="gemini-2.5-pro",
                             planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                             generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=65536))


dataprofile_agent = LlmAgent(name="DataProfile_Agentic_Workflow",
                             description="Provides the ability to manage individual data profile scan operations.", # Clarified description
                             instruction=data_profile.dataprofile_agent_instruction,
                             global_instruction=global_instruction_helper.global_protocol_instruction,
                             tools=[ data_profile.create_data_profile_scan,
                                     data_profile.start_data_profile_scan,
                                     data_profile.exists_data_profile_scan,
                                     data_profile.get_data_profile_scans,
                                     data_profile.update_bigquery_table_dataplex_labels,
                                     data_profile.get_data_profile_scans_for_table,
                                     data_profile.list_data_profile_scan_jobs,
                                     data_profile.delete_data_profile_scan_job,
                                     data_profile.delete_data_profile_scan,
                                     data_profile.get_data_profile_scan_job_full_details,
                                     data_profile.get_data_profile_scan_state,
                                     get_bigquery_table_list.get_bigquery_table_list,
                                     get_bigquery_dataset_list.get_bigquery_dataset_list,
                                     wait_tool.wait_for_seconds,
                                   ],
                             model="gemini-2.5-flash",
                             planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                             generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=65536))


datainsight_agent = LlmAgent(name="DataInsight",
                             description="Provides the ability to manage data insights.",
                             instruction=data_insights.datainsight_agent_instruction,
                             global_instruction=global_instruction_helper.global_protocol_instruction,
                             tools=[ data_insights.create_data_insight_scan,
                                     data_insights.start_data_insight_scan,
                                     data_insights.exists_data_insight_scan,
                                     data_insights.get_data_insight_scan_state,
                                     data_insights.get_data_insight_scans,
                                     data_insights.update_bigquery_table_dataplex_labels_for_insights,
                                     data_insights.get_data_insight_scans_for_table,
                                     data_insights.list_data_insight_scan_jobs,
                                     data_insights.delete_data_insight_scan_job,
                                     data_insights.delete_data_insight_scan,
                                     data_insights.get_data_insight_scan_job_full_details,
                                     get_bigquery_table_list.get_bigquery_table_list,
                                     get_bigquery_dataset_list.get_bigquery_dataset_list ,
                                     wait_tool.wait_for_seconds
                                   ],
                             model="gemini-2.5-flash",
                             planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                             generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=65536))


dataquality_agent = LlmAgent(name="DataQuality",
                             description="Provides the ability to manage data quality scans.",
                             instruction=data_quality.dataquality_agent_instruction,
                             global_instruction=global_instruction_helper.global_protocol_instruction,
                             tools=[ data_quality.create_data_quality_scan,
                                     data_quality.start_data_quality_scan,
                                     data_quality.exists_data_quality_scan,
                                     data_quality.get_data_quality_scans,
                                     data_quality.get_data_quality_scan_state,
                                     data_quality.update_bigquery_table_dataplex_labels_for_quality,
                                     data_quality.get_data_quality_scans_for_table,
                                     data_quality.list_data_quality_scan_jobs,
                                     data_quality.delete_data_quality_scan_job,
                                     data_quality.delete_data_quality_scan,
                                     data_quality.get_data_quality_scan_job_full_details,
                                     get_bigquery_table_list.get_bigquery_table_list,
                                     get_bigquery_dataset_list.get_bigquery_dataset_list,
                                     wait_tool.wait_for_seconds
                                   ],
                             model="gemini-2.5-flash",
                             planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                             generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=65536))


datadiscovery_agent = LlmAgent(name="DataDiscovery",
                             description="Provides the ability to manage data discovery of files on Google Cloud Storage scans.",
                             instruction=data_discovery.datadiscovery_agent_instruction,
                             global_instruction=global_instruction_helper.global_protocol_instruction,
                             tools=[ data_discovery.create_data_discovery_scan,
                                     data_discovery.start_data_discovery_scan,
                                     data_discovery.exists_data_discovery_scan,
                                     data_discovery.get_data_discovery_scans,
                                     data_discovery.get_data_discovery_scan_state,
                                     data_discovery.get_data_discovery_scans_for_bucket,

                                     data_discovery.list_data_discovery_scan_jobs,
                                     data_discovery.delete_data_discovery_scan_job,
                                     data_discovery.delete_data_discovery_scan,
                                     data_discovery.get_data_discovery_scan_job_full_details,
                                     data_discovery.list_gcs_buckets,

                                     get_bigquery_dataset_list.get_bigquery_dataset_list,
                                     wait_tool.wait_for_seconds
                                   ],
                             model="gemini-2.5-flash",
                             planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                             generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=65536))


conversational_analytics_agent = LlmAgent(name="ConversationalAnalyticsAPI",
                             description="This agent is used manage and create Google Conversational Analytics API resources.",
                             instruction=conversational_analytics_agent_instructions.conversational_analytics_agent_instruction,
                             global_instruction=global_instruction_helper.global_protocol_instruction,
                             tools=[ get_bigquery_table_list.get_bigquery_table_list,
                                     conversational_analytics_auto_create_agent.create_conversational_analytics_data_agent,
                                     conversational_analytics_conversation.conversational_analytics_data_agent_conversations_list,
                                     conversational_analytics_conversation.conversational_analytics_data_agent_conversations_get,
                                     conversational_analytics_conversation.conversational_analytics_data_agent_conversations_exists,
                                     conversational_analytics_conversation.conversational_analytics_data_agent_conversations_create,
                                     conversational_analytics_data_agent.conversational_analytics_data_agent_list,
                                     conversational_analytics_data_agent.conversational_analytics_data_agent_exists,
                                     conversational_analytics_data_agent.conversational_analytics_data_agent_get,
                                     conversational_analytics_data_agent.conversational_analytics_data_agent_create,
                                     conversational_analytics_data_agent.conversational_analytics_data_agent_delete
                                   ],
                             model="gemini-2.5-flash",
                             planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                             generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=65536))


dataform_agent = LlmAgent(name="Dataform",
                             description="Provides the ability to manage dataform repositories and pipelines.",
                             instruction=dataform_helper.dataform_agent_instruction,
                             global_instruction=global_instruction_helper.global_protocol_instruction,
                             tools=[ dataform_helper.exists_dataform_repository,
                                     dataform_helper.exists_dataform_workspace,
                                     dataform_helper.create_bigquery_pipeline,
                                     dataform_helper.create_dataform_pipeline,
                                     dataform_helper.create_workspace,
                                     dataform_helper.does_workspace_file_exist,
                                     dataform_helper.write_workflow_settings_file,
                                     dataform_helper.write_actions_yaml_file,
                                     dataform_helper.commit_workspace,
                                     dataform_helper.rollback_workspace,
                                     dataform_helper.compile_and_run_dataform_workflow,
                                     dataform_helper.get_worflow_invocation_status,
                                     dataform_helper.get_repository_id_based_upon_display_name,
                                     dataform_helper.list_dataform_respositories,
                                     dataform_helper.get_workspace_id_based_upon_display_name,
                                     dataform_helper.list_dataform_workspaces_in_a_repository,
                                     dataform_helper.write_dataform_file
                                   ],
                             model="gemini-2.5-flash",
                             planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                             generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=65536))

################################################################################
# Data Engineering Agent
################################################################################
# Agentic workflow
data_engineering_agent_agentic_workflow = LlmAgent(name="DataEngineering_OldAgentic",
                             description="Provides the ability to create and update data engineering pipelines using natural language prompts (older agentic approach).",
                             instruction=data_engineering_helper.data_engineering_agent_instruction,
                             global_instruction=global_instruction_helper.global_protocol_instruction,
                             tools=[ dataform_helper.get_worflow_invocation_status,
                                     dataform_helper.create_bigquery_pipeline,
                                     dataform_helper.create_dataform_pipeline,
                                     dataform_helper.create_workspace,
                                     dataform_helper.does_workspace_file_exist,
                                     dataform_helper.write_workflow_settings_file,
                                     dataform_helper.commit_workspace,
                                     dataform_helper.write_actions_yaml_file,
                                     dataform_helper.compile_and_run_dataform_workflow,
                                     dataform_helper.rollback_workspace,
                                     dataform_helper.get_repository_id_based_upon_display_name,
                                     dataform_helper.get_workspace_id_based_upon_display_name,
                                     data_engineering_helper.call_bigquery_data_engineering_agent,
                                     data_engineering_helper.llm_as_a_judge,
                                     data_engineering_helper.normalize_bigquery_resource_names,
                                     wait_tool.wait_for_seconds
                                   ],
                             model="gemini-2.5-pro",
                             planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                             generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=65536))

# NEW: Custom Workflow for Data Engineering creation/modification from prompt
# This agent handles user-driven pipeline creation/modification and does its own prompt parsing.
data_engineering_agent_custom_workflow = de_workflow_custom_agent_helper.DataEngineeringWorkflowCustomAgent(
    name="DataEngineeringPipelineOrchestrator", 
    agent_parse_initial_prompt=de_workflow_custom_agent_helper.agent_parse_initial_prompt,
    agent_normalize_bq_names=de_workflow_custom_agent_helper.agent_normalize_bq_names,
    agent_de_get_repo_id=de_workflow_custom_agent_helper.agent_de_get_repo_id,
    agent_de_create_bq_repo=de_workflow_custom_agent_helper.agent_de_create_bq_repo,
    agent_de_create_dataform_repo=de_workflow_custom_agent_helper.agent_de_create_dataform_repo,
    agent_de_get_workspace_id=de_workflow_custom_agent_helper.agent_de_get_workspace_id,
    agent_de_create_workspace=de_workflow_custom_agent_helper.agent_de_create_workspace,
    agent_de_check_workflow_settings=de_workflow_custom_agent_helper.agent_de_check_workflow_settings,
    agent_de_write_workflow_settings=de_workflow_custom_agent_helper.agent_de_write_workflow_settings,
    agent_de_commit_workspace=de_workflow_custom_agent_helper.agent_de_commit_workspace,
    agent_de_call_bq_de_agent=de_workflow_custom_agent_helper.agent_de_call_bq_de_agent,
    agent_de_llm_judge=de_workflow_custom_agent_helper.agent_de_llm_judge,
    agent_de_rollback_workspace=de_workflow_custom_agent_helper.agent_de_rollback_workspace,
    agent_de_check_actions_yaml=de_workflow_custom_agent_helper.agent_de_check_actions_yaml,
    agent_de_write_actions_yaml=de_workflow_custom_agent_helper.agent_de_write_actions_yaml,
    agent_de_compile_and_run=de_workflow_custom_agent_helper.agent_de_compile_and_run,
    agent_de_check_job_state=de_workflow_custom_agent_helper.agent_de_check_job_state,
    agent_de_time_delay_job=de_workflow_custom_agent_helper.agent_de_time_delay_job,
)


################################################################################
# Data Engineering Agent Autonomous
################################################################################
# Agentic Workflow
data_engineering_autonomous_agent = LlmAgent(
    name="AutonomousDataEngineering_Agentic_Workflow",
    description="Provides the ability to autonomously fix data engineering pipelines based on data quality issues (agentic approach).",
    instruction=data_engineering_agent_autonomous_helper.data_engineering_autonomous_agent_instruction,
    global_instruction=global_instruction_helper.global_protocol_instruction,
    tools=[
        dataform_helper.get_worflow_invocation_status,
        dataform_helper.create_bigquery_pipeline,
        dataform_helper.create_dataform_pipeline,
        dataform_helper.create_workspace,
        dataform_helper.does_workspace_file_exist,
        dataform_helper.write_workflow_settings_file,
        dataform_helper.commit_workspace,
        dataform_helper.write_actions_yaml_file,
        dataform_helper.compile_and_run_dataform_workflow,
        dataform_helper.rollback_workspace,
        dataform_helper.get_repository_id_based_upon_display_name,
        dataform_helper.get_workspace_id_based_upon_display_name,
        de_tools.call_bigquery_data_engineering_agent, # Still using this one if it's a wrapper
        de_tools.llm_as_a_judge, # Still using this one if it's a wrapper
        de_tools.check_data_quality_failures, # Now from the new tools module
        de_tools.get_data_quality_failure_analysis, # Now from the new tools module
        de_tools.generate_data_engineering_fix_prompt, # Now from the new tools module
        data_engineering_helper.normalize_bigquery_resource_names, # From existing helper if needed
        wait_tool.wait_for_seconds,
    ],
    model="gemini-2.5-pro", # smarter for advanced agentic workflow
    planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
    generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=65536)
)

# Custom workflow
data_engineering_workflow_shared_session_agent_instance = de_workflow_shared_session_agent_helper.DataEngineeringWorkflowSharedSessionAgent(
    name="AutonomousDataEngineering_Custom_Agentic_Workflow", # This name is for the DQ fix flow
    agent_de_check_dq_failures=de_workflow_shared_session_agent_helper.agent_de_check_dq_failures,
    agent_de_get_dq_analysis=de_workflow_shared_session_agent_helper.agent_de_get_dq_analysis,
    agent_de_generate_fix_prompt=de_workflow_shared_session_agent_helper.agent_de_generate_fix_prompt,
    agent_de_get_repo_id=de_workflow_shared_session_agent_helper.agent_de_get_repo_id,
    agent_de_create_bq_repo=de_workflow_shared_session_agent_helper.agent_de_create_bq_repo,
    agent_de_create_dataform_repo=de_workflow_shared_session_agent_helper.agent_de_create_dataform_repo,
    agent_de_get_workspace_id=de_workflow_shared_session_agent_helper.agent_de_get_workspace_id,
    agent_de_create_workspace=de_workflow_shared_session_agent_helper.agent_de_create_workspace,
    agent_de_check_workflow_settings=de_workflow_shared_session_agent_helper.agent_de_check_workflow_settings,
    agent_de_write_workflow_settings=de_workflow_shared_session_agent_helper.agent_de_write_workflow_settings,
    agent_de_commit_workspace=de_workflow_shared_session_agent_helper.agent_de_commit_workspace,
    agent_de_call_bq_de_agent=de_workflow_shared_session_agent_helper.agent_de_call_bq_de_agent,
    agent_de_llm_judge=de_workflow_shared_session_agent_helper.agent_de_llm_judge,
    agent_de_rollback_workspace=de_workflow_shared_session_agent_helper.agent_de_rollback_workspace,
    agent_de_check_actions_yaml=de_workflow_shared_session_agent_helper.agent_de_check_actions_yaml,
    agent_de_write_actions_yaml=de_workflow_shared_session_agent_helper.agent_de_write_actions_yaml,
    agent_de_compile_and_run=de_workflow_shared_session_agent_helper.agent_de_compile_and_run,
    agent_de_check_job_state=de_workflow_shared_session_agent_helper.agent_de_check_job_state,
    agent_de_time_delay_job=de_workflow_shared_session_agent_helper.agent_de_time_delay_job,
)

################################################################################
# AI Generate Bool (text and images)
################################################################################
ai_generate_bool_agent = LlmAgent(
    name="AIGenerateBool",
    description="Filters rows in BigQuery tables based on semantic content. Use for questions that require understanding the meaning of text or images, like 'Which x contain y?' or 'Find reviews that are negative in sentiment.'",
    instruction=ai_generate_bool_helper.ai_generate_bool_agent_instruction,
    global_instruction=global_instruction_helper.global_protocol_instruction,
    tools=[
        get_bigquery_table_list.get_bigquery_table_list,
        get_bigquery_table_schema.get_bigquery_table_schema,
        ai_generate_bool_helper.execute_ai_generate_bool, 
    ],
    model="gemini-2.5-flash",
    planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
    generate_content_config=types.GenerateContentConfig(temperature=0.1, max_output_tokens=65536)
)

################################################################################
# AI Forecast
################################################################################
ai_forecast_agent = LlmAgent(name="AIForecast",
                             description="Provides the ability to perform timeseries forecasting using BigQuery.",
                             instruction=ai_forecast.ai_forecast_agent_instruction,
                             global_instruction=global_instruction_helper.global_protocol_instruction,
                             tools=[ get_bigquery_table_list.get_bigquery_table_list,
                                     get_bigquery_table_schema.get_bigquery_table_schema,
                                     ai_forecast.get_timeseries_sample_data,
                                     ai_forecast.time_unit_converter,
                                     ai_forecast.infer_time_series_granularity,
                                     ai_forecast.execute_ai_forecast,
                                     vector_search_column_values.vector_search_column_values,
                                     run_bigquery_sql.run_bigquery_sql,
                                   ],
                             model="gemini-2.5-flash", # gemini-2.5-pro cloud be better, but flash seems to be doing fine.
                             planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                             generate_content_config=types.GenerateContentConfig(temperature=0.1, max_output_tokens=65536))

################################################################################
# Business Glossary
################################################################################
business_glossary_agent = LlmAgent(name="BusinessGlossary",
                             description="Provides business glossary (data catalog) interactions.",
                             instruction=business_glossary.business_glossary_agent_instruction,
                             global_instruction=global_instruction_helper.global_protocol_instruction,
                             tools=[ business_glossary.get_business_glossaries,
                                    business_glossary.create_business_glossary,
                                    business_glossary.get_business_glossary,
                                    business_glossary.get_business_glossary_categories,
                                    business_glossary.get_business_glossary_category,
                                    business_glossary.create_business_glossary_category,
                                    business_glossary.get_business_glossary_term,
                                    business_glossary.list_business_glossary_terms,
                                    business_glossary.create_business_glossary_term,
                                    business_glossary.update_business_glossary_term,
                                    business_glossary.delete_business_glossary,
                                    business_glossary.delete_business_glossary_category,
                                    business_glossary.delete_business_glossary_term,
                                   ],
                             model="gemini-2.5-flash",
                             planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                             generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=65536))

################################################################################
# Knowledge Agents
################################################################################
knowledge_engine_agent = LlmAgent(name="KnowledgeEngine",
                             description="Provides access to BigQuery knowledge engine which can extract insights to metadata in BigQuery.",
                             instruction=knowledge_engine.knowledge_engine_agent_instruction,
                             global_instruction=global_instruction_helper.global_protocol_instruction,
                             tools=[ knowledge_engine.get_knowledge_engine_scans,
                                    knowledge_engine.get_knowledge_engine_scans_for_dataset,
                                    knowledge_engine.exists_knowledge_engine_scan,
                                    knowledge_engine.create_knowledge_engine_scan,
                                    knowledge_engine.start_knowledge_engine_scan,
                                    knowledge_engine.get_knowledge_engine_scan_state,
                                    knowledge_engine.update_bigquery_dataset_dataplex_labels,
                                    knowledge_engine.get_knowledge_engine_scan,
                                    get_bigquery_dataset_list.get_bigquery_dataset_list ,
                                    wait_tool.wait_for_seconds
                                   ],
                             model="gemini-2.5-flash",
                             planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                             generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=65536))

knowledge_engine_business_glossary_agent = LlmAgent(name="KnowledgeEngineBusinessGlossary",
                             description="Builds a business glossary by leveraging knowledge engine insights and direct glossary interactions.",
                             instruction=knowledge_engine_business_glossary.knowledge_engine_business_glossary_instruction,
                             global_instruction=global_instruction_helper.global_protocol_instruction,
                             tools=[ knowledge_engine.get_knowledge_engine_scans,
                                     knowledge_engine.get_knowledge_engine_scans_for_dataset,
                                     knowledge_engine.get_knowledge_engine_scan,
                                     knowledge_engine_business_glossary.derive_business_glossary_from_knowledge_engine,
                                     business_glossary.get_business_glossaries,
                                     business_glossary.create_business_glossary,
                                     business_glossary.get_business_glossary,
                                     business_glossary.get_business_glossary_categories,
                                     business_glossary.get_business_glossary_category,
                                     business_glossary.create_business_glossary_category,
                                     business_glossary.get_business_glossary_term,
                                     business_glossary.list_business_glossary_terms,
                                     business_glossary.create_business_glossary_term,
                                     business_glossary.update_business_glossary_term,
                                     get_bigquery_dataset_list.get_bigquery_dataset_list
                                   ],
                             model="gemini-2.5-pro",  # more complex workflow
                             planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                             generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=65536))


################################################################################
# Data Profile Create: Show the 3 different types of workflows
################################################################################
# Instantiate all three data profile workflow orchestrator agents
data_profile_workflow_isolated_session_agent_instance = data_profile_workflow_isolated_session_agent_helper.OrchestratingDataProfileWorkflowIsolatedSessionAgent(
    name="DataProfile_Custom_Agentic_Workflow_Isolated"
)

data_profile_workflow_shared_session_agent_instance = data_profile_workflow_shared_session_agent_helper.DataProfileWorkflowSharedSessionAgent(
    name="DataProfile_Custom_Agentic_Workflow",
    agent_data_profile_create_scan=data_profile_workflow_shared_session_agent_helper.agent_data_profile_create_scan,
    agent_data_profile_link_to_bigquery=data_profile_workflow_shared_session_agent_helper.agent_data_profile_link_to_bigquery,
    agent_data_profile_check_scan_exists=data_profile_workflow_shared_session_agent_helper.agent_data_profile_check_scan_exists,
    agent_data_profile_scan_job_start=data_profile_workflow_shared_session_agent_helper.agent_data_profile_scan_job_start,
    agent_data_profile_scan_job_state=data_profile_workflow_shared_session_agent_helper.agent_data_profile_scan_job_state,
    agent_time_delay_create=data_profile_workflow_shared_session_agent_helper.agent_time_delay_create,
    agent_time_delay_job=data_profile_workflow_shared_session_agent_helper.agent_time_delay_job,
)

data_profile_workflow_tool_agent_instance = data_profile_workflow_tool_agent_helper.DataProfileWorkflowToolAgentOrchestrator(
    name="DataProfile_Tool_Driven_Workflow"
)


################################################################################
# Main Agent - Supervisor Pattern using Sub-Agents
################################################################################
coordinator_system_prompt = f"""You are the **Data Analytics Agent**, a master AI coordinator for Google Cloud. Your purpose is to understand a user's request, identify the core intent, and delegate the task to the correct specialist agent from your team. You do not perform tasks yourself; you are the intelligent router.

**Your First Step is Always to Triage the User's Intent.**

---
**Internal Capabilities (Handled Directly by You, the Coordinator):**

*   **Sample Prompts:** If a user asks for "sample prompts," "examples," "what can I ask," or something similar, you MUST handle it directly without delegation.
    1.  **First, list the categories:** Your initial response MUST be to call the `get_prompt_categories()` tool and present the resulting list to the user. Ask them which category they are interested in.
    2.  **Second, show the prompts:** Once the user specifies a category, you MUST call the `get_prompts_for_category(category_name)` tool with their selection and display the formatted string output directly to them.
---

**Delegation Rules:**

1.  **Is the user ASKING A GENERAL QUESTION that requires querying the *content* of their data?**
    *   This involves ad-hoc data queries like "how many," "what is the sum of," "show me sales figures."
    *   **Delegate to:** `BigQuery` (The NL2SQL Agent).

2.  **Is the user asking to FILTER data based on its SEMANTIC CONTENT, such as text or images?**
    *   Keywords: "Which 'x' contain 'y'?", "find all items that are...", "show me products which are...", "which images contain...". This is for filtering rows by understanding the meaning in natural language, rather than precise numerical or string matching.
    *   **Delegate to:** `AIGenerateBool` (The Generative Filter Agent).

3.  **Is the user trying to CREATE or MODIFY the LOGIC of a data pipeline?**
    *   This involves defining new data transformation logic, like "create a pipeline to uppercase a column," or "modify my ETL to join tables."
    *   **Action:** You **MUST** call `transfer_to_agent(agent_name="DataEngineeringPipelineOrchestrator", initial_data_engineering_query_param=ctx.last_message.content.parts[0].text)`.
    *   **You MUST NOT generate any conversational text or explanation in this turn; your entire output MUST be solely the `transfer_to_agent` tool call.**
    *   **Delegate to:** `DataEngineeringPipelineOrchestrator` (The Pipeline Creation/Modification Agent). This agent will interpret the prompt and orchestrate the full pipeline lifecycle from creation/modification to deployment.

4.  **Is the user trying to AUTONOMOUSLY FIX a data pipeline based on data quality issues?**
    *   This involves diagnosing and correcting pipeline errors identified by data quality scans, like "fix my pipeline based on a DQ scan" or "correct the data quality errors in the telemetry pipeline."
    *   **Your action flow for this intent is critical and MUST be followed precisely:**
        1.  **First action:** You **MUST** call `parse_and_set_data_engineering_params_tool`. Pass the *entire original user prompt* as the `prompt` argument to this tool. This tool will extract and store all necessary parameters into the **Coordinator's session state** and **MUST set `_awaiting_data_engineering_workflow_selection` to `True`** in the session state upon successful completion, while **setting `_awaiting_data_profile_workflow_selection` to `False`**.
        2.  **After `parse_and_set_data_engineering_params_tool` has completed (in a subsequent turn) AND IF `_awaiting_data_engineering_workflow_selection` is `True` in the session state:**
            *   You **MUST** output a message to the user asking them to select one of the following data engineering autonomous workflow approaches. Provide ONLY the exact names as choices:
                *   `AutonomousDataEngineering_Custom_Agentic_Workflow` (for a custom orchestrated agentic workflow that performs an autonomous fix based on data quality)
                *   `AutonomousDataEngineering_Agentic_Workflow` (for an agentic workflow that performs an autonomous fix directly)
            *   Wait for the user's response, which will be their chosen agent name.
        3.  **After the user has provided their choice AND `_awaiting_data_engineering_workflow_selection` is `True`:**
            *   You **MUST** set `_awaiting_data_engineering_workflow_selection` to `False` in the session state to prevent re-prompting.
            *   You **MUST** `transfer_to_agent` to the chosen agent. The agent name you use in `transfer_to_agent` MUST be one of the two exact names listed above. Do NOT include any additional parameters in the `transfer_to_agent` call itself, as the required parameters are already in the session state.
            *   **You MUST NOT generate any conversational text or explanation in this turn; your entire output MUST be solely the `transfer_to_agent` tool call.**

5.  **Is the user trying to MANAGE THE INFRASTRUCTURE of a Dataform pipeline?**
    *   This is about the *structure*, not the logic. Keywords include "create a repository," "make a new workspace," "run the pipeline," or "check the status of a job."
    *   **Delegate to:** `Dataform` (The DevOps Agent).

6.  **Is the user trying to DISCOVER or UNDERSTAND their data assets?**
    *   **To find or look up data assets, definitions, glossary terms, or *governance metadata/tags* using search terms (structured or natural language):** "find all tables with 'customer' in the name," "show me sensitive PII data," "what is knowledge management?","**what are the governance tags on table X?**"
        *   **For specific governance information about a *known* table, like tags, labels, or policies:** "What are the governance tags for the `customer` table?"
        *   **Delegate to:** `DataCatalog` (The Search Agent).
    *   **To scan GCS files and create BigLake tables:** "scan my bucket," "make my GCS files queryable."
        *   **Delegate to:** `DataDiscovery` (The GCS Scanner).
    *   **To initiate the multi-step workflow selection process.**
            *   **CRITICAL TRIGGER:** You **MUST** only activate this multi-step process if the user's verbatim prompt is **exactly** "Create a scan workflow". For all other requests related to creating or managing data profiles, you must delegate to the `DataProfile_Agentic_Workflow` agent.
            *   **Your action flow for this intent is critical and MUST be followed precisely:**
                1.  **First action:** You **MUST** call `parse_and_set_data_profile_params_tool`. Pass the *entire original user prompt* as the `prompt` argument to this tool. This tool will extract and store all necessary parameters into the **Coordinator's session state** and **MUST set `_awaiting_data_profile_workflow_selection` to `True`** in the session state upon successful completion, while **setting `_awaiting_data_engineering_workflow_selection` to `False`**.
                2.  **After `parse_and_set_data_profile_params_tool` has completed (in a subsequent turn) AND IF `_awaiting_data_profile_workflow_selection` is `True` in the session state:**
                    *   You **MUST** output a message to the user asking them to select one of the following data profiling workflow approaches. Provide ONLY the exact names as choices:
                        *   `DataProfile_Custom_Agentic_Workflow` (for workflows that operate within the current shared session)
                        *   `DataProfile_Custom_Agentic_Workflow_Isolated` (for workflows where the agent manages an isolated child session)
                        *   `DataProfile_Tool_Driven_Workflow` (for workflows where the agent orchestrates a streaming Python tool that emits UI messages)
                        *   `DataProfile_Agentic_Workflow` (for an agentic workflow using the DataProfile agent's own instructions)
                    *   Wait for the user's response, which will be their chosen agent name.
                3.  **After the user has provided their choice AND `_awaiting_data_profile_workflow_selection` is `True`:**
                    *   You **MUST** set `_awaiting_data_profile_workflow_selection` to `False` in the session state to prevent re-prompting.
                    *   You **MUST** `transfer_to_agent` to the chosen agent. The agent name you use in `transfer_to_agent` MUST be one of the four exact names listed above. Do NOT include any additional parameters in the `transfer_to_agent` call itself, as the required parameters are already in the session state.
        *   **To directly manage data profiling operations (the default action for data profiles).** This includes requests like: "Create a data profile scan...", "check if data profile scan X exists," "start data profile job Y," or "list my data profile scans."
            *   **Delegate to:** `DataProfile_Agentic_Workflow` (The Profiling Agent).
    *   **To automatically generate documentation for a table:** "document my table," "get insights for `dataset.table`."
        *   **Delegate to:** `DataInsight` (The Documentation Agent).
    *   **To create data quality rules for a table:** "create a quality scan," "validate my data."
        *   **Delegate to:** `DataQuality` (The Validation Agent).

7.  **Is the user asking for a PREDICTION or FORECAST for future values or events?**
    *   Keywords: "predict," "forecast," "will I run out of," "what will be," "future trends," "estimate."
    *   **Delegate to:** `AIForecast` (The Forecasting Agent).

8.  **Is the user trying to BUILD A REUSABLE CONVERSATIONAL MODEL?**
    *   Keywords: "build a chat model," "create a conversational agent," "set up a chat interface." This is about creating a persistent NL2SQL model, not asking a one-off question.
    *   **Delegate to:** `ConversationalAnalyticsAPI` (The Model Manager).

9.  **Does the user need UP-TO-DATE, external information?**
    *   This includes news, current events, weather, or technical documentation not specific to your project's data.
    *   **Delegate to:** `Search` (The Google Search Agent).

10. **Is the user trying to MANAGE BUSINESS GLOSSARIES, CATEGORIES, or TERMS?**
    *   This involves operations like "create a business glossary," "list categories in glossary 'X'," "add a term to 'Y' category," "update term 'Z'," or "get details for glossary 'A'."
    *   **Delegate to:** `BusinessGlossary` (The Business Glossary Agent).

11. **Is the user trying to MANAGE KNOWLEDGE ENGINE SCANS?**
    *   This involves operations like "list knowledge engine scans," "create a knowledge scan," "start scan 'X'," "check status of scan job 'Y'," or "get details for scan 'Z'."
    *   **Delegate to:** `KnowledgeEngine` (The Knowledge Engine Agent).

- You can reset the data engineering autonomous demo by calling the tool `data_engineering_reset_demo`.

---
**Core Operating Rules:**

*   **Trust, but Verify:** Always assume the user might misspell table or dataset names. Before delegating a task that needs a table name, first consider having the relevant agent (e.g., `BigQuery`, `AIForecast`) call `get_bigquery_table_list` to get the exact names.
*   **Gather Information:** Before delegating, ensure you have all the necessary parameters for the target agent's task. Ask the user for clarification if needed.
*   **Avoid Loops:** Do not call the same agent with the exact same inputs repeatedly. If a task fails, analyze the error message and decide on a different course of action.
*   **Communicate Clearly:** Introduce yourself as the "Data Analytics Agent." Explain which specialist you are delegating to and report the final results back to the user in a clear, summarized format.
"""

# You can now use this variable in your code, for example:
# print(global_protocol_instruction)
# --- 4. Main Agent using Gemini Pro as coordinator ---
root_agent = LlmAgent(
    name="Coordinator",
    model="gemini-2.5-pro",
    instruction=coordinator_system_prompt,
    description="Expert coordinator for Google Cloud data analytics and BigQuery tasks.",
    sub_agents=[search_agent,
                bigquery_agent,
                datacatalog_agent,
                dataprofile_agent, # The single-step DataProfile agent
                datainsight_agent,
                dataquality_agent,
                datadiscovery_agent,
                conversational_analytics_agent,
                dataform_agent,

                # Data enginneering agent (Create / Modify pipelines)
                data_engineering_agent_agentic_workflow, # Currently not in coordinator prompt (might do as a selection)
                data_engineering_agent_custom_workflow,

                # Data Engineering Agent - Autonomous (Data Quality fix)
                data_engineering_autonomous_agent, 
                data_engineering_workflow_shared_session_agent_instance,

                ai_generate_bool_agent,
                ai_forecast_agent,
                business_glossary_agent,
                knowledge_engine_agent,
                knowledge_engine_business_glossary_agent,

                # Data profile "create" workflow agents
                data_profile_workflow_isolated_session_agent_instance,
                data_profile_workflow_shared_session_agent_instance,
                data_profile_workflow_tool_agent_instance,
                
               ],
    tools=[
        # The parsing tool is required for both workflows
        data_profile_tool_session_helper.parse_and_set_data_profile_params_tool,

        # The parsing tool for autonomous data engineering workflow (still needed for DQ fix flow)
        de_tool_session_helper.parse_and_set_data_engineering_params_tool, 
        data_engineering_reset_demo_helper.data_engineering_reset_demo,

        # Sample prompts
        sample_prompts_helper.get_prompt_categories,
        sample_prompts_helper.get_prompts_for_category,        
    ],
    planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
    generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=65536)
)