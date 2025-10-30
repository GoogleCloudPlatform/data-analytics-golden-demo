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
import os
import json
import re
import logging

import data_analytics_agent.dataform.dataform as dataform_helper

logger = logging.getLogger(__name__)


def data_engineering_reset_demo() -> dict:
    """
    Resets the telemetry_coffee_machine.sqlx in the agentic-beans-repo and workspace telemetry-coffee-machine-original.

    Args:
        repository_id (str): The ID of the repository containing the workspace.
        workspace_id (str): The ID of the workspace where the file will be written.
        file_contents (str): The content to be written to the file (not base64 encoded)
        file_path (str): The path of the file, no starting forward slash.

    Returns:
        dict: A dictionary containing the status and the result of the writeFile operation.
        {
            "status": "success" or "failed",
            "tool_name": "write_dataform_file",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": { ... API response from the writeFile operation ... }
        }
    """    
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataform_region = os.getenv("AGENT_ENV_DATAFORM_REGION", "us-central1")
    messages = []

    repository_id = "agentic-beans-repo"
    workspace_id = "telemetry-coffee-machine-auto" 
    author_name = "Agentic Beans Agent"
    author_email = "data-beans-agent@example.com"
    commit_message = "Resetting data eng autonomous demo."
    file_path = "definitions/agentic_beans_raw/telemetry_coffee_machine.sqlx"

    try:
        # upload file (assuming the folders exists)
        file_contents = """config {
    type: "incremental",
    database:"""
        
        file_contents += f""" "{project_id}","""

        file_contents += """
    schema: "agentic_beans_raw",
    name: "telemetry_coffee_machine",
    bigquery: {
        clusterBy: ["machine_id", "telemetry_timestamp"]
        }
    }

    SELECT
    telemetry_coffee_machine_id,
    telemetry_load_id,
    CAST(machine_id AS INTEGER) AS machine_id,
    CAST(truck_id AS INTEGER) AS truck_id,
    CAST(telemetry_timestamp AS TIMESTAMP) AS telemetry_timestamp,
    CAST(boiler_temperature_celsius AS NUMERIC) AS boiler_temperature_celsius,
    CAST(brew_pressure_bar AS NUMERIC) AS brew_pressure_bar,
    CAST(water_flow_rate_ml_per_sec AS NUMERIC) AS water_flow_rate_ml_per_sec,
    CAST(grinder_motor_rpm AS INTEGER) AS grinder_motor_rpm,
    CAST(grinder_motor_torque_nm AS NUMERIC) AS grinder_motor_torque_nm,
    CAST(water_reservoir_level_percent AS NUMERIC) AS water_reservoir_level_percent,
    CAST(bean_hopper_level_grams AS NUMERIC) AS bean_hopper_level_grams,
    CAST(total_brew_cycles_counter AS INTEGER) AS total_brew_cycles_counter,
    last_error_code,
    last_error_description,
    CAST(power_consumption_watts AS NUMERIC) AS power_consumption_watts,
    cleaning_cycle_status
    FROM
    ${ref("agentic_beans_raw_staging_load", "telemetry_coffee_machine")}
    """
        write_dataform_file_respone = dataform_helper.write_dataform_file(repository_id, workspace_id, file_contents, file_path)
        messages.extend(write_dataform_file_respone.get("messages", []))

        if write_dataform_file_respone["status"] == "failed":
            return {
                "status": "failed",
                "tool_name": "data_engineering_reset_demo",
                "query": None,
                "messages": messages,
                "results": write_dataform_file_respone["results"]
            }
        
        # commit change
        commit_workspace_response = dataform_helper.commit_workspace(repository_id, workspace_id, author_name, author_email, commit_message)
        messages.extend(commit_workspace_response.get("messages", []))
        if commit_workspace_response["status"] == "failed":
            return {
                "status": "failed",
                "tool_name": "data_engineering_reset_demo",
                "query": None,
                "messages": messages,
                "results": write_dataform_file_respone["results"]
            }        
        
        return {
            "status": "success",
            "tool_name": "data_engineering_reset_demo",
            "query": None,
            "messages": messages,
            "results": { "status_message": "Successfully reset the Data Eng Autonomous Dataform pipelie." } 
        }

    except Exception as e:
        error_message = f"An error occurred during the data_engineering_reset_demo process: {e}"
        messages.append(error_message)
        logger.debug(error_message)
        return {
            "status": "failed",
            "tool_name": "data_engineering_reset_demo",
            "query": None,
            "messages": messages,
            "results": None
        }   


