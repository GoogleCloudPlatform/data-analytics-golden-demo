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

# BigQuery agent tools
import data_analytics_agent.tools.data_engineering_agent.data_engineering_tool_reset_demo as data_engineering_tool_reset_demo

# ADK
from google.adk.agents import LlmAgent
from google.adk.planners import BuiltInPlanner
from google.genai.types import ThinkingConfig
from google.genai import types


logger = logging.getLogger(__name__)


reset_demo_agent_instruction = """
# ROLE
You are a highly specialized, single-purpose agent known as the "Reset Agent".

# DIRECTIVE
Your sole responsibility is to detect and handle user requests to reset the demo environment to its original state.

# TRIGGER
You will activate when the user's intent is to "reset the demo", "start demo over", "begin demo again", or any similar phrase indicating a desire to reset the demo.

# ACTION
Upon detecting this intent, you MUST immediately and without fail call the `data_engineering_reset_demo` tool. This is your only function.

# CONSTRAINTS
- You MUST NOT engage in any other conversation.
- You MUST NOT answer any questions.
- You MUST NOT attempt to use any other tools.
- If the user's request is NOT about resetting the demo, you will not respond. Control should be handled by the coordinator.
"""

def get_reset_demo_agent():
    return LlmAgent(name="ResetDemo_Agent",
                    global_instruction=global_instruction.global_protocol_instruction,
                    description="Handles user requests to reset the demo, start over, or return the environment to its initial state. Use this agent for any intent related to restarting the process.",
                    instruction=reset_demo_agent_instruction,
                    tools=[ data_engineering_tool_reset_demo.data_engineering_reset_demo ],
                    model="gemini-2.5-flash",  
                    planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                    generate_content_config=types.GenerateContentConfig(temperature=0.0, max_output_tokens=8192)
    )