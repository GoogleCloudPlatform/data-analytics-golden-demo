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
import asyncio
from vertexai import agent_engines

# https://cloud.google.com/vertex-ai/generative-ai/docs/agent-engine/use/adk
# Ensure you have authenticated with Google Cloud CLI:
# gcloud auth application-default login

project_id = "data-analytics-agent-00000000"
location = "us-central1"
reasoning_engine_id = "0000000000000000000"
REASONING_ENGINE_NAME = f"projects/{project_id}/locations/{location}/reasoningEngines/{reasoning_engine_id}"
user_id = "adam-test-01"

async def main():
    """
    Asynchronous function to interact with the Vertex AI Agent Engine.
    """
    remote_app = agent_engines.get(REASONING_ENGINE_NAME)

    remote_session = await remote_app.async_create_session(user_id=user_id)
    print(f"Session object: {remote_session}")
    session_id = remote_session["id"]
    print(f"Session created with ID: {session_id}")

    async for event in remote_app.async_stream_query(
        user_id=user_id,
        session_id=session_id,
        message="Count the taxi trips by borough",
    ):
        print(event)


if __name__ == "__main__":
    asyncio.run(main())