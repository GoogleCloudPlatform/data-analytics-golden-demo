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
import time

logger = logging.getLogger(__name__)

def wait_for_seconds(duration: int) -> dict:
    """
    Instructs the agent's execution environment to pause for the specified number of seconds.
    This tool acts as a signal to the agent's orchestrator to introduce a delay,
    allowing the UI to remain responsive if handled correctly by the orchestrator.

    Args:
        duration (int): The number of seconds to wait.

    Returns:
        dict: A dictionary indicating the wait was initiated.
        {
            "status": "success",
            "tool_name": "wait_for_seconds",
            "query": None,
            "messages": [f"Instructed to wait for {seconds} seconds."],
            "results": {"waited_for_seconds": seconds}
        }
    """
    messages = [f"Agent is requesting a pause for {duration} seconds."]
    logger.info(messages[0])

    time.sleep(duration)

    return {
        "status": "success",
        "tool_name": "wait_for_seconds",
        "query": None,
        "messages": messages,
        "results": {"waited_for_seconds": duration}
    }