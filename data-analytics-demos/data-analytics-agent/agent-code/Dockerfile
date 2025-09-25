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
FROM python:3.11-slim
WORKDIR /app

# Create a non-root user
RUN adduser --disabled-password --gecos "" myuser

# Change ownership of /app to myuser
RUN chown -R myuser:myuser /app

# Switch to the non-root user
USER myuser

# Set up environment variables - Start
ENV PATH="/home/myuser/.local/bin:$PATH"

ENV GOOGLE_GENAI_USE_VERTEXAI=1
ENV GOOGLE_CLOUD_PROJECT=${project_id}
ENV GOOGLE_CLOUD_LOCATION=${cloud_run_region}

# Set up environment variables - End

# Install ADK - Start
#RUN pip install google-adk==1.5.0
# Install ADK - End

# Copy agent - Start
COPY "agents/data_analytics_agent/" "/app/agents/data_analytics_agent/"
COPY "requirements.txt" "/app/requirements.txt"
RUN pip install -r "/app/requirements.txt"
# Copy agent - End

EXPOSE 8000

CMD adk web --port=8000 --host=0.0.0.0 "/app/agents"