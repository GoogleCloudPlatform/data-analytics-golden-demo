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

# cd agent-code
# pip install --upgrade vertexai
# pip install --upgrade  google-cloud-aiplatform[agent_engines,adk]
# python -m 01_agentspace_deploy_agent_to_agent_engine.py
# https://cloud.google.com/vertex-ai/generative-ai/docs/agent-engine/deploy

import vertexai
from data_analytics_agent.agent import root_agent
from vertexai import agent_engines

PROJECT_ID = "data-analytics-agent-00000000"
LOCATION = "us-central1" 
STAGING_BUCKET = "gs://data-analytics-agent-code-00000000"

# Initialize the Vertex AI SDK
vertexai.init(
    project=PROJECT_ID,
    location=LOCATION,
    staging_bucket=STAGING_BUCKET,
)

# Wrap the agent in an AdkApp object
app = agent_engines.AdkApp(
    agent=root_agent,
    enable_tracing=True,
)

# Create Agent Engine
remote_app = agent_engines.create(
    agent_engine=app,
    requirements=[
        "google-cloud-aiplatform[adk,agent_engines]",
        "json-stream",
        "tenacity",
        "cloudpickle", 
        "pydantic"
    ],
    extra_packages=["data_analytics_agent"], 
    gcs_dir_name=None,
    display_name="Data Analytics Agent",  
    description="Agent for Google Cloud Data Analytics",  
    env_vars={
        "GOOGLE_GENAI_USE_VERTEXAI": "TRUE",
        # "GOOGLE_CLOUD_PROJECT": "data-analytics-agent-00000000",  # RESERVED ENV (cannot send to agent engine)
        # "GOOGLE_CLOUD_LOCATION": "us-central1",                   # RESERVED ENV (cannot send to agent engine)
        "AGENT_ENV_PROJECT_ID": "data-analytics-agent-00000000",
        "AGENT_ENV_BIGQUERY_REGION": "us-central1",
        "AGENT_ENV_DATAPLEX_SEARCH_REGION": "global",
        "AGENT_ENV_GOOGLE_API_KEY": "REDACTED",
        "AGENT_ENV_DATAPLEX_REGION": "us-central1",
        "AGENT_ENV_CONVERSATIONAL_ANALYTICS_REGION": "global",
        "AGENT_ENV_VERTEX_AI_REGION": "us-central1",
        "AGENT_ENV_BUSINESS_GLOSSARY_REGION": "global",
        "AGENT_ENV_DATAFORM_REGION": "us-central1",
        "AGENT_ENV_DATAFORM_AUTHOR_NAME": "Adam Paternostro",
        "AGENT_ENV_DATAFORM_AUTHOR_EMAIL": "google-user@paternostro.altostrat.com",
        "AGENT_ENV_DATAFORM_WORKSPACE_DEFAULT_NAME": "default",
        "AGENT_ENV_DATAFORM_SERVICE_ACCOUNT": "bigquery-pipeline-sa@data-analytics-agent-00000000.iam.gserviceaccount.com",
        "VERTEX_AI_ENDPOINT": "gemini-2.5-flash",
        "VERTEX_AI_CONNECTION_NAME": "vertex-ai",
        },
    service_account="agent-engine-service-account@data-analytics-agent-00000000.iam.gserviceaccount.com"
)

print(f"Deployment finished!")
print(f"Resource Name: {remote_app.resource_name}")