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

# Global instruction
import data_analytics_agent.agents.global_instruction as global_instruction

# Conversational Analytics Chat
import data_analytics_agent.tools.conversational_analytics.conversational_analytics_chat_tools as conversational_analytics_chat_tools
import data_analytics_agent.tools.conversational_analytics.conversational_analytics_conversation_tools as conversational_analytics_conversation_tools

# BigQuery
import data_analytics_agent.tools.bigquery.bigquery_table_tools as bigquery_table_tools

# ADK
from google.adk.agents import LlmAgent
from google.adk.planners import BuiltInPlanner
from google.genai.types import ThinkingConfig
from google.genai import types


logger = logging.getLogger(__name__)


conversational_analytics_agent_chat_instruction="""You are an agent that will chat with the conversational analytics API.

The user must provide a conversational_analytics_data_agent_id and then a prompt which will be passed to the API directly as is.

Do not confused this with NL2SQL.  You only call this for when the user specifically wants to chat with the conversational analytics API.

You may also create and manage stateful conversations.

*   **To list all conversation histories:** Call `conversational_analytics_data_agent_conversations_list()`.
*   **To set up a named conversation thread for future use:** Call `conversational_analytics_data_agent_conversations_create(data_agent_id=..., conversation_id=...)`.

"""


def get_conversational_analytics_chat_agent():
    return LlmAgent(name="ConversationalAnalyticsChat_Agent",
                             description="This agent is used to chat with an already created Conversational Analytics Agent.",
                             instruction=conversational_analytics_agent_chat_instruction,
                             global_instruction=global_instruction.global_protocol_instruction,
                             tools=[ conversational_analytics_chat_tools.conversational_analytics_data_agent_chat_stateful,
                                     conversational_analytics_chat_tools.conversational_analytics_data_agent_chat_stateless,

                                     conversational_analytics_conversation_tools.conversational_analytics_data_agent_conversations_create,
                                     conversational_analytics_conversation_tools.conversational_analytics_data_agent_conversations_exists,
                                     conversational_analytics_conversation_tools.conversational_analytics_data_agent_conversations_get,
                                     conversational_analytics_conversation_tools.conversational_analytics_data_agent_conversations_list,
                                   ],
                             model="gemini-2.5-flash",
                             planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                             generate_content_config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=65536))