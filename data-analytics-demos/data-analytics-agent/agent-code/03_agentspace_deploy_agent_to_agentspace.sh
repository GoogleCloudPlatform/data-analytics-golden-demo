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
export PROJECT_ID="data-analytics-agent-00000000"
export AGENT_DISPLAY_NAME="Data Analytics Agent"
export AGENT_DESCRIPTION="The agent automates data analytics."
export LOCATION="us-central1"
export TOOL_DESCRIPTION="Data Analytics Agent for BigQuery, AI Forecast, AI Generate Boolean, Data Profiling, Data Insights"
export AGENTSPACE_APP_ID="adam_agentspace"
export REASONING_ENGINE_ID="0000000000000000000"
export PROJECT_NUMBER="00000000000000"

payload=api_data.json

cat > ${payload} << EOF
{
   "displayName": "${AGENT_DISPLAY_NAME}",
   "description": "${AGENT_DESCRIPTION}",
   "icon": {"uri": "https://fonts.gstatic.com/s/i/short-term/release/googlesymbols/schedule_send/default/24px.svg"},
   "adk_agent_definition": {
       "tool_settings": {
           "tool_description": "${TOOL_DESCRIPTION}"
       },
       "provisioned_reasoning_engine": {
           "reasoning_engine": "projects/${PROJECT_ID}/locations/${LOCATION}/reasoningEngines/${REASONING_ENGINE_ID}"
       }
   }
}
EOF

echo "Data to post:"
cat ${payload}


curl -X POST "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUMBER}/locations/global/collections/default_collection/engines/${AGENTSPACE_APP_ID}/assistants/default_assistant/agents" \
-H "Authorization: Bearer $(gcloud auth print-access-token)" \
-H "Content-Type: application/json" \
-H "x-goog-user-project: ${PROJECT_ID}" \
-d "@${payload}"

Output:
{
  "name": "projects/517693961302/locations/global/collections/default_collection/engines/adam_agentspace/assistants/default_assistant/agents/5968342334904683794",
  "displayName": "Data Analytics Agent 02",
  "description": "The agent automates data analytics.",
  "icon": {
    "uri": "https://fonts.gstatic.com/s/i/short-term/release/googlesymbols/schedule_send/default/24px.svg"
  },
  "createTime": "2025-09-14T14:52:27.584839404Z",
  "adkAgentDefinition": {
    "toolSettings": {
      "toolDescription": "Data Analytics Agent for BigQuery, AI Forecast, AI Generate Boolean, Data Profiling, Data Insights"
    },
    "provisionedReasoningEngine": {
      "reasoningEngine": "projects/data-analytics-agent-00000000/locations/us-central1/reasoningEngines/7872226177945960448"
    }
  },
  "state": "ENABLED"
}
