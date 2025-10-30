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

# Sample Prompts
import data_analytics_agent.tools.sample_prompts.sample_prompts_tools as sample_prompts_tools

# ADK
from google.adk.agents import LlmAgent
from google.adk.planners import BuiltInPlanner
from google.genai.types import ThinkingConfig
from google.genai import types


logger = logging.getLogger(__name__)

# This module contains a curated and complete dictionary of sample prompts for the Agentic Beans Agent demo.
# Prompts are categorized and include explanations to help users understand the agent's capabilities.
# The structure supports multi-line prompts, explanations, and follow-up questions.

sample_prompts_agent_instruction = """
# ROLE
You are a highly specialized, single-purpose agent known as the "Sample Prmompts Agent".

# DIRECTIVE
Your sole responsibility is to show the user sample prompts for this agent.

# TRIGGER
You will activate when the user's intent is to show sample prompts, capalbilites or if they ask questions like what can you do?

# CONSTRAINTS
- You MUST NOT engage in any other conversation.
- You MUST NOT answer any questions.
- You MUST NOT attempt to use any other tools.
- If the user's request is NOT about resetting the demo, you will not respond. Control should be handled by the coordinator.

# POST-ACTION
After successfully invoking the tool, your task is complete and you will return control to the coordinator agent.
"""

def get_sample_prompts_agent():
    return LlmAgent(name="SamplePrompts_Agent",
                    global_instruction=global_instruction.global_protocol_instruction,
                    description="Shows sample prompts to the user by various categories.",
                    instruction=sample_prompts_agent_instruction,
                    tools=[
                        sample_prompts_tools.get_prompt_categories,
                        sample_prompts_tools.get_prompts_for_category,  ],
                    model="gemini-2.5-flash",  
                    planner=BuiltInPlanner(thinking_config=ThinkingConfig(include_thoughts=True)),
                    generate_content_config=types.GenerateContentConfig(temperature=0.0, max_output_tokens=65536)
    )