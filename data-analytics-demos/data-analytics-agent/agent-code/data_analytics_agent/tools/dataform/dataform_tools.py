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
import base64 

import data_analytics_agent.utils.rest_api.rest_api_helper as rest_api_helper 
import logging

logger = logging.getLogger(__name__)


async def exists_dataform_repository(repository_id: str) -> dict: # Changed to def
    """
    Checks if a Dataplex repository with a specific ID already exists.

    Args:
        repository_id (str): The ID of the repository to check for. This corresponds to the
                    last segment of the repository's full resource name.

    Returns:
        dict: A dictionary containing the status and a boolean result.
        {
            "status": "success" or "failed",
            "tool_name": "exists_dataform_repository",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "exists": True or False,
                "name": "Full resource name of the repository if it exists"
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataform_region = os.getenv("AGENT_ENV_DATAFORM_REGION")
    messages = []

    # The URL to list all repositories in the specified project and region. [1]
    url = f"https://dataform.googleapis.com/v1/projects/{project_id}/locations/{dataform_region}/repositories"

    try:
        messages.append(f"Checking for existence of BigQuery Pipeline (Dataform Repository) with ID: '{repository_id}'.")
        # Call the REST API to get the list of all existing repositories. [1]
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        messages.append("Successfully retrieved list of all repositories from the API.")

        repo_exists = False
        repo_full_name = None

        for repo in json_result.get("repositories", []):
            # The full name is in the format: projects/{p}/locations/{l}/repositories/{id}
            full_name_from_api = repo.get("name", "")            

            if full_name_from_api == f"projects/{project_id}/locations/{dataform_region}/repositories/{repository_id}":
                repo_exists = True
                repo_full_name = full_name_from_api
                messages.append(f"Found matching repository: '{repo_full_name}'.")
                break
        
        if not repo_exists:
            messages.append(f"Repository with ID '{repository_id}' does not exist.")

        return {
            "status": "success",
            "tool_name": "exists_dataform_repository",
            "query": None,
            "messages": messages,
            "results": {"exists": repo_exists, "name": repo_full_name}
        }

    except Exception as e:
        error_message = f"An error occurred while listing repositories: {e}"
        messages.append(error_message)
        return {
            "status": "failed",
            "tool_name": "exists_dataform_repository",
            "query": None,
            "messages": messages,
            "results": None
        }


async def exists_dataform_workspace(repository_name: str, workspace_name: str) -> dict: # Changed to def
    """
    Checks if a Dataform workspace with a specific name exists within a repository.

    Args:
        repository_name (str): The ID of the repository to check within.
        workspace_name (str): The ID of the workspace to look for.

    Returns:
        dict: A dictionary containing the status and a boolean result.
        {
            "status": "success" or "failed",
            "tool_name": "exists_dataform_workspace",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "exists": True or False,
                "name": "Full resource name of the workspace if it exists"
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    location = os.getenv("AGENT_ENV_DATAFORM_REGION")
    dataform_region = os.getenv("AGENT_ENV_DATAFORM_REGION", "us-central1")
    messages = []

    # The URL to list all workspaces in the specified repository. [1]
    url = f"https://dataform.googleapis.com/v1/projects/{project_id}/locations/{dataform_region}/repositories/{repository_name}/workspaces"

    try:
        messages.append(f"Checking for existence of workspace '{workspace_name}' in repository '{repository_name}'.")
        # Call the REST API to get the list of all existing workspaces. [1]
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        messages.append("Successfully retrieved list of workspaces from the API.")

        workspace_exists = False
        workspace_full_name = None

        for ws in json_result.get("workspaces", []):
            full_name_from_api = ws.get("name", "")

            if full_name_from_api == f"projects/{project_id}/locations/{location}/repositories/{repository_name}/workspaces/{workspace_name}":
                workspace_exists = True
                workspace_full_name = full_name_from_api
                messages.append(f"Found matching workspace: '{workspace_full_name}'.")
                break
        
        if not workspace_exists:
            messages.append(f"Workspace with ID '{workspace_name}' does not exist in repository '{repository_name}'.")

        return {
            "status": "success",
            "tool_name": "exists_dataform_workspace",
            "query": None,
            "created" : True, # This 'created' key seems like a leftover from 'create' tools. It might be better to remove if not directly used for this tool's purpose. Keeping as-is per instruction.
            "messages": messages,
            "results": {"exists": workspace_exists, "name": workspace_full_name}
        }

    except Exception as e:
        error_message = f"An error occurred while listing workspaces: {e}"
        messages.append(error_message)
        return {
            "status": "failed",
            "tool_name": "exists_dataform_workspace",
            "query": None,
            "messages": messages,
            "results": None
        }


async def create_bigquery_pipeline(pipeline_name: str, display_name:str) -> dict: # Changed to def
    """
    Creates a new Dataform repository, referred to as a BigQuery Pipeline, if it does not already exist.

    This function uses a specific label '{"bigquery-workflow":"preview"}' which
    is a temporary method until an official API is released for this functionality.

    Args:
        pipeline_name (str): The name/ID for the new repository. This will be used as the
                    repositoryId,  and name.
        display_name (str): The display name seen in the user interface.

    Returns:
        dict: A dictionary containing the status and results of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "create_bigquery_pipeline",
            "query": None,
            "created": True / False if the workspace was created,
            "messages": ["List of messages during processing"],
            "results": { ... API response from Dataform ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataform_region = os.getenv("AGENT_ENV_DATAFORM_REGION")
    service_account = os.getenv("AGENT_ENV_DATAFORM_SERVICE_ACCOUNT")

    # Check if the repository already exists before attempting to create it.
    existence_check = await exists_dataform_repository(pipeline_name) # Added await
    messages = existence_check.get("messages", [])

    if existence_check["status"] == "failed":
        return existence_check

    if existence_check["results"]["exists"]:
        # If the repository exists, return a success message indicating it wasn't re-created.
        return {
            "status": "success",
            "tool_name": "create_bigquery_pipeline",
            "query": None,
            "created": False,
            "messages": messages,
            "results": {"name": existence_check["results"]["name"]}
        }

    messages.append(f"Creating BigQuery Pipeline (Dataform Repository) '{pipeline_name}' in region '{dataform_region}'.")
    # The repositoryId is passed as a query parameter. [2]
    url = f"https://dataform.googleapis.com/v1/projects/{project_id}/locations/{dataform_region}/repositories?repositoryId={pipeline_name}"

    # The request body contains the configuration for the new repository.
    request_body = {
        "serviceAccount": service_account,
        "displayName": display_name,
        "name": pipeline_name,
        # This label is a temporary "hack" until a formal API is available.
        "labels": {"bigquery-workflow": "preview"}
    }

    logger.debug(f"request_body: {request_body}")

    try:
        # Call the REST API helper to execute the POST request. [2]
        json_result = await rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await

        messages.append(f"Successfully initiated the creation of repository '{pipeline_name}'.")
        logger.debug(f"create_bigquery_pipeline json_result: {json_result}")

        return {
            "status": "success",
            "tool_name": "create_bigquery_pipeline",
            "query": None,
            "created": True,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        error_message = f"An error occurred while creating the BigQuery Pipeline '{pipeline_name}': {e}"
        messages.append(error_message)
        logger.debug(error_message)
        return {
            "status": "failed",
            "tool_name": "create_bigquery_pipeline",
            "query": None,
            "created": False,
            "messages": messages,
            "results": None
        }


async def create_dataform_pipeline(repository_id: str, display_name: str) -> dict: # Changed to def
    """
    Creates a new, standard Dataform repository if it does not already exist.

    Args:
        name (str): The name/ID for the new repository. This will be used as the
                    repositoryId and name.
        display_name (str): The display name for the repository.

    Returns:
        dict: A dictionary containing the status and results of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "create_dataform_pipeline",
            "query": None,
            "created": True / False if the workspace was created,
            "messages": ["List of messages during processing"],
            "results": { ... API response from Dataform ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataform_region = os.getenv("AGENT_ENV_DATAFORM_REGION")
    service_account = os.getenv("AGENT_ENV_DATAFORM_SERVICE_ACCOUNT")

    # Check if the repository already exists before attempting to create it.
    existence_check = await exists_dataform_repository(repository_id) # Added await
    messages = existence_check.get("messages", [])

    if existence_check["status"] == "failed":
        return existence_check

    if existence_check["results"]["exists"]:
        # If the repository exists, return a success message indicating it wasn't re-created.
        return {
            "status": "success",
            "tool_name": "create_dataform_pipeline",
            "query": None,
            "created": False,
            "messages": messages,
            "results": {"name": existence_check["results"]["name"]}
        }

    messages.append(f"Creating standard Dataform Repository '{repository_id}' in region '{dataform_region}'.")
    # The repositoryId is passed as a query parameter. [2]
    url = f"https://dataform.googleapis.com/v1/projects/{project_id}/locations/{dataform_region}/repositories?repositoryId={repository_id}"

    # The request body for a standard Dataform repository.
    request_body = {
        "serviceAccount": service_account,
        "displayName": display_name,
        "name": repository_id,
    }

    try:
        # Call the REST API helper to execute the POST request. [2]
        json_result = await rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await

        messages.append(f"Successfully initiated the creation of repository '{repository_id}'.")
        logger.debug(f"create_dataform_pipeline json_result: {json_result}")

        return {
            "status": "success",
            "tool_name": "create_dataform_pipeline",
            "query": None,
            "created": True,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        error_message = f"An error occurred while creating the Dataform repository '{repository_id}': {e}"
        messages.append(error_message)
        logger.debug(error_message)
        return {
            "status": "failed",
            "tool_name": "create_dataform_pipeline",
            "query": None,
            "created": False,            
            "messages": messages,
            "results": None
        }


async def create_workspace(repository_id: str, workspace_id: str) -> dict: # Changed to def
    """
    Creates a new Dataform workspace in a repository if it does not already exist.

    Args:
        repository_id (str): The ID of the repository where the workspace will be created.
        workspace_id (str): The ID for the new workspace.  The workspace display name will also be the workspace id.

    Returns:
        dict: A dictionary containing the status and results of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "create_workspace",
            "query": None,
            "created": True / False if the workspace was created,
            "messages": ["List of messages during processing"],
            "results": { ... API response from Dataform ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataform_region = os.getenv("AGENT_ENV_DATAFORM_REGION", "us-central1")

    # Check if the workspace already exists before attempting to create it.
    existence_check = await exists_dataform_workspace(repository_id, workspace_id) # Added await
    messages = existence_check.get("messages", [])

    if existence_check["status"] == "failed":
        return existence_check

    if existence_check["results"]["exists"]:
        # If the workspace exists, return a success message indicating it wasn't re-created.
        return {
            "status": "success",
            "tool_name": "create_workspace",
            "query": None,
            "created": False,
            "messages": messages,
            "results": {"name": existence_check["results"]["name"]}
        }

    messages.append(f"Creating workspace '{workspace_id}' in repository '{repository_id}'.")
    # The workspaceId is passed as a query parameter. [2]
    url = f"https://dataform.googleapis.com/v1/projects/{project_id}/locations/{dataform_region}/repositories/{repository_id}/workspaces?workspaceId={workspace_id}"

    # The request body for creating a workspace.
    request_body = {
        "name": workspace_id
    }

    try:
        # Call the REST API helper to execute the POST request. [2]
        json_result = await rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await

        messages.append(f"Successfully initiated the creation of workspace '{workspace_id}'.")
        #logger.debug(f"create_workspace json_result: {json_result}")

        return {
            "status": "success",
            "tool_name": "create_workspace",
            "query": None,
            "created": True,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        error_message = f"An error occurred while creating the workspace '{workspace_id}': {e}"
        messages.append(error_message)
        logger.debug(error_message)
        return {
            "status": "failed",
            "tool_name": "create_workspace",
            "query": None,
            "created": False,
            "messages": messages,
            "results": None
        }    


async def does_workspace_file_exist(repository_id: str, workspace_id: str, file_path: str) -> dict: # Changed to def
    """
    Checks if a Dataplex file already exists

    Args:
        repository_id (str): The ID of the repository where the workspace will be created.
        workspace_id (str): The name/ID for the new workspace.
        file_path (str): The full path to the file

    Returns:
        dict: A dictionary containing the status and a boolean result.
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataform_region = os.getenv("AGENT_ENV_DATAFORM_REGION")
    messages = []

    url = f"https://dataform.googleapis.com/v1/projects/{project_id}/locations/{dataform_region}/repositories/{repository_id}/workspaces/{workspace_id}:readFile?path={file_path}"

    try:
        messages.append(f"Checking for existence of file '{file_path}' in workspace '{workspace_id}'.")
        await rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        messages.append("Successfully called the check for existence of file.")

        return {
            "status": "success",
            "tool_name": "does_workspace_file_exist",
            "query": None,
            "messages": messages,
            "results": {"exists": True}
        }

    except Exception as e:
        # Check if the string representation of the error contains '404'
        if '404' in str(e):
            messages.append(f"File '{file_path}' not found in workspace '{workspace_id}'. This is an expected outcome.")
            return {
                "status": "success",
                "tool_name": "does_workspace_file_exist",
                "query": None,
                "messages": messages,
                "results": {"exists": False}
            }
        else:
            # Handle all other errors as failures
            error_message = f"An unexpected error occurred while checking for existence of file: {e}"
            messages.append(error_message)
            return {
                "status": "failed",
                "tool_name": "does_workspace_file_exist",
                "query": None,
                "messages": messages,
                "results": None
            }


async def write_workflow_settings_file(repository_id: str, workspace_id: str) -> dict: # Changed to def
    """
    Writes the 'workflow_settings.yaml' file to a Dataform workspace.

    This function creates the 'workflow_settings.yaml' file with a predefined
    template, populating it with the current project ID and location. This is
    a standard initialization step for Dataform workspaces.

    Args:
        repository_id (str): The ID of the repository containing the workspace.
        workspace_id (str): The ID of the workspace where the file will be written.

    Returns:
        dict: A dictionary containing the status and the result of the writeFile operation.
        {
            "status": "success" or "failed",
            "tool_name": "write_workflow_settings_file",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": { ... API response from the writeFile operation ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataform_region = os.getenv("AGENT_ENV_DATAFORM_REGION", "us-central1")
    messages = []

    # Define the specific file path and content template within the function
    file_path = "workflow_settings.yaml"
    file_content_template = """defaultProject: {project_id}
defaultLocation: {location}
defaultDataset: dataform
defaultAssertionDataset: dataform_assertions
dataformCoreVersion: 3.0.16"""

    try:
        messages.append(f"Preparing to write file '{file_path}' to workspace '{workspace_id}'.")

        # Populate the template with the project and location details.
        final_file_contents = file_content_template.format(
            project_id=project_id,
            location=dataform_region
        )
        messages.append("Successfully formatted file content template.")

        # Base64 encode the populated string.
        encoded_contents = base64.b64encode(final_file_contents.encode('utf-8')).decode('utf-8')
        messages.append("Successfully Base64 encoded file contents.")

        write_url = f"https://dataform.googleapis.com/v1/projects/{project_id}/locations/{dataform_region}/repositories/{repository_id}/workspaces/{workspace_id}:writeFile"
        
        write_request_body = {
            "path": file_path,
            "contents": encoded_contents
        }

        # Execute the writeFile request
        write_result = await rest_api_helper.rest_api_helper(write_url, "POST", write_request_body) # Added await
        messages.append(f"Successfully wrote file '{file_path}'.")
        #logger.debug(f"write_workflow_settings_file result: {write_result}")

        return {
            "status": "success",
            "tool_name": "write_workflow_settings_file",
            "query": None,
            "messages": messages,
            "results": write_result 
        }

    except Exception as e:
        error_message = f"An error occurred during the write_workflow_settings_file process: {e}"
        messages.append(error_message)
        logger.debug(error_message)
        return {
            "status": "failed",
            "tool_name": "write_workflow_settings_file",
            "query": None,
            "messages": messages,
            "results": None
        }
       

async def write_actions_yaml_file(repository_id: str, workspace_id: str) -> dict: # Changed to def
    """
    Writes a placeholder 'actions.yaml' file to a Dataform workspace.

    This function is specifically designed to create the 'definitions/actions.yaml'
    file with the content 'actions: []', which is often required for initializing
    BigQuery Pipelines.

    Args:
        repository_id (str): The ID of the repository containing the workspace.
        workspace_id (str): The ID of the workspace where the file will be written.

    Returns:
        dict: A dictionary containing the status and the result of the writeFile operation.
        {
            "status": "success" or "failed",
            "tool_name": "write_actions_yaml_file",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": { ... API response from the writeFile operation ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataform_region = os.getenv("AGENT_ENV_DATAFORM_REGION", "us-central1")
    messages = []
    
    # Define the specific file path and content within the function
    file_path = "definitions/actions.yaml"
    file_contents = "actions: []"

    try:
        messages.append(f"Writing placeholder file '{file_path}' to workspace '{workspace_id}'.")
        
        write_url = f"https://dataform.googleapis.com/v1/projects/{project_id}/locations/{dataform_region}/repositories/{repository_id}/workspaces/{workspace_id}:writeFile"
        
        # Base64 encode the predefined file contents
        encoded_contents = base64.b64encode(file_contents.encode('utf-8')).decode('utf-8')

        write_request_body = {
            "path": file_path,
            "contents": encoded_contents
        }

        # Execute the writeFile request
        write_result = await rest_api_helper.rest_api_helper(write_url, "POST", write_request_body) # Added await
        messages.append(f"Successfully wrote file '{file_path}'.")
        #logger.debug(f"write_actions_yaml_file result: {write_result}")

        return {
            "status": "success",
            "tool_name": "write_actions_yaml_file",
            "query": None,
            "messages": messages,
            "results": write_result 
        }

    except Exception as e:
        error_message = f"An error occurred during the write_actions_yaml_file process: {e}"
        messages.append(error_message)
        logger.debug(error_message)
        return {
            "status": "failed",
            "tool_name": "write_actions_yaml_file",
            "query": None,
            "messages": messages,
            "results": None
        }   


async def write_dataform_file(repository_id: str, workspace_id: str, file_contents: str, file_path: str) -> dict: # Changed to def
    """
    This writes a file. It assumes the folder/path exist.

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
    
    # Define the specific file path and content within the function
    try:
        messages.append(f"Writing placeholder file '{file_path}' to workspace '{workspace_id}'.")
        
        write_url = f"https://dataform.googleapis.com/v1/projects/{project_id}/locations/{dataform_region}/repositories/{repository_id}/workspaces/{workspace_id}:writeFile"
        
        # Base64 encode the predefined file contents
        encoded_contents = base64.b64encode(file_contents.encode('utf-8')).decode('utf-8')

        write_request_body = {
            "path": file_path,
            "contents": encoded_contents
        }

        # Execute the writeFile request
        write_result = await rest_api_helper.rest_api_helper(write_url, "POST", write_request_body) # Added await
        messages.append(f"Successfully wrote file '{file_path}'.")
        #logger.debug(f"write_actions_yaml_file result: {write_result}")

        return {
            "status": "success",
            "tool_name": "write_dataform_file",
            "query": None,
            "messages": messages,
            "results": write_result 
        }

    except Exception as e:
        error_message = f"An error occurred during the write_dataform_file process: {e}"
        messages.append(error_message)
        logger.debug(error_message)
        return {
            "status": "failed",
            "tool_name": "write_dataform_file",
            "query": None,
            "messages": messages,
            "results": None
        }   


async def commit_workspace(repository_id: str, workspace_id: str, author_name: str, author_email: str, commit_message: str) -> dict: # Changed to def
    """
    Commits pending changes in a Dataform workspace.

    Args:
        repository_id (str): The ID of the repository containing the workspace.
        workspace_id (str): The ID of the workspace with pending changes to commit.
        author_name (str): The name of the user to be credited as the author of the commit.
        author_email (str): The email address of the commit author.
        commit_message (str): The message describing the changes being committed.

    Returns:
        dict: A dictionary containing the status and results of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "commit_workspace",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": { ... API response from Dataform ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataform_region = os.getenv("AGENT_ENV_DATAFORM_REGION", "us-central1")
    messages = []

    # The API endpoint for committing to a workspace.
    url = f"https://dataform.googleapis.com/v1/projects/{project_id}/locations/{dataform_region}/repositories/{repository_id}/workspaces/{workspace_id}:commit"

    # The request body containing the author and commit message.
    request_body = {
        "author": {
            "name": author_name,
            "emailAddress": author_email
        },
        "commitMessage": commit_message
    }

    try:
        messages.append(f"Attempting to commit changes to workspace '{workspace_id}' in repository '{repository_id}'.")

        # Call the REST API helper to execute the POST request.
        json_result = await rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await
        
        messages.append(f"Successfully committed changes with message: '{commit_message}'.")
        #logger.debug(f"commit_workspace json_result: {json_result}")

        return {
            "status": "success",
            "tool_name": "commit_workspace",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        error_message = f"An error occurred while committing to the workspace '{workspace_id}': {e}"
        messages.append(error_message)
        logger.debug(error_message)
        return {
            "status": "failed",
            "tool_name": "commit_workspace",
            "query": None,
            "messages": messages,
            "results": None
        }
    

async def rollback_workspace(repository_id: str, workspace_id: str) -> dict: # Changed to def
    """
    Rollsback pending changes in a Dataform workspace.

    Args:
        repository_id (str): The ID of the repository containing the workspace.
        workspace_id (str): The ID of the workspace with pending changes to commit.


    Returns:
        dict: A dictionary containing the status and results of the operation.
        {
            "status": "success" or "failed",
            "tool_name": "commit_workspace", # Typo: Should be rollback_workspace
            "query": None,
            "messages": ["List of messages during processing"],
            "results": { ... API response from Dataform ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataform_region = os.getenv("AGENT_ENV_DATAFORM_REGION", "us-central1")
    messages = []

    # The API endpoint for committing to a workspace.
    url = f"https://dataform.googleapis.com/v1/projects/{project_id}/locations/{dataform_region}/repositories/{repository_id}/workspaces/{workspace_id}:reset"

    # The request body containing the author and commit message.
    request_body = {
        "clean": True
    }

    try:
        messages.append(f"Attempting to rollback changes to workspace '{workspace_id}' in repository '{repository_id}'.")

        # Call the REST API helper to execute the POST request.
        json_result = await rest_api_helper.rest_api_helper(url, "POST", request_body) # Added await
        
        messages.append(f"Successfully rolled back changes'.")
        #(f"commit_workspace json_result: {json_result}") # This comment seems to reference a different tool.

        return {
            "status": "success",
            "tool_name": "rollback_workspace",
            "query": None,
            "messages": messages,
            "results": json_result
        }
    except Exception as e:
        error_message = f"An error occurred while rolling back the workspace '{workspace_id}': {e}"
        messages.append(error_message)
        logger.debug(error_message)
        return {
            "status": "failed",
            "tool_name": "rollback_workspace",
            "query": None,
            "messages": messages,
            "results": None
        }
    

async def compile_and_run_dataform_workflow(repository_id: str, workspace_id: str) -> dict: # Changed to def
    """
    Compiles a Dataform repository from a workspace and then runs the resulting workflow.

    This function performs two sequential operations:
    1. It creates a compilation result from the specified workspace.
    2. It starts a workflow invocation using the successful compilation result.

    Args:
        repository_id (str): The ID of the Dataform repository to compile and run.
        workspace_id (str): The ID of the workspace containing the code to be compiled.

    Returns:
        dict: A dictionary containing the status and the final response from the workflow invocation API call.
        {
            "status": "success" or "failed",
            "tool_name": "compile_and_run_dataform_workflow",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": { ... API response from the workflow invocation ... }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataform_region = os.getenv("AGENT_ENV_DATAFORM_REGION", "us-central1")
    dataform_service_account = os.getenv("AGENT_ENV_DATAFORM_SERVICE_ACCOUNT")
    messages = []

    try:
        # --- Step 1: Compile the repository from the workspace ---
        messages.append(f"Step 1: Compiling repository '{repository_id}' from workspace '{workspace_id}'.")
        
        compile_url = f"https://dataform.googleapis.com/v1/projects/{project_id}/locations/{dataform_region}/repositories/{repository_id}/compilationResults"
        
        workspace_full_path = f"projects/{project_id}/locations/{dataform_region}/repositories/{repository_id}/workspaces/{workspace_id}"
        
        compile_request_body = {
            "workspace": workspace_full_path
        }

        compile_result = await rest_api_helper.rest_api_helper(compile_url, "POST", compile_request_body) # Added await
        compilation_result_name = compile_result.get("name")

        # You might want to check the status of the compilation and only start it if it is "success"!
        
        if not compilation_result_name:
            raise Exception("Failed to get compilation result name from the compilation API response.")

        messages.append(f"Successfully compiled. Compilation result name: {compilation_result_name}")

        # --- Step 2: Run the workflow using the compilation result ---
        messages.append(f"Step 2: Starting workflow execution for compilation '{compilation_result_name}'.")

        invoke_url = f"https://dataform.googleapis.com/v1/projects/{project_id}/locations/{dataform_region}/repositories/{repository_id}/workflowInvocations"
        
        invoke_request_body = {
            "compilationResult": compilation_result_name,
              "invocationConfig": {
                "serviceAccount": dataform_service_account
              }
        }

        invoke_result = await rest_api_helper.rest_api_helper(invoke_url, "POST", invoke_request_body) # Added await
        
        messages.append("Successfully initiated workflow invocation.")
        #logger.debug(f"compile_and_run_dataform_workflow invoke_result: {invoke_result}") # This comment had (f"...")

        return {
            "status": "success",
            "tool_name": "compile_and_run_dataform_workflow",
            "query": None,
            "messages": messages,
            "workflow_invocation_id": invoke_result["name"].rsplit('/', 1)[-1],
            "results": invoke_result 
        }

    except Exception as e:
        error_message = f"An error occurred during the compile and run process: {e}"
        messages.append(error_message)
        logger.debug(error_message)
        return {
            "status": "failed",
            "tool_name": "compile_and_run_dataform_workflow",
            "query": None,
            "messages": messages,
            "results": None
        }    


async def get_worflow_invocation_status(repository_id: str, workflow_invocation_id: str) -> dict: # Changed to def
    """
    Checks on the execution status of a workflow.

    Args:
        repository_id (str): The ID of the Dataform repository to compile and run.
        workflow_invocation_id (str): The ID (guid) of workflow invocations id executing a pipeline.  It will return 
            a workflow_invocation_id value which can be used to check on the execution status.

    Returns:
        dict: A dictionary containing the status and a boolean result.
        {
            "status": "success" or "failed",
            "tool_name": "get_worflow_invocation_status",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "name": "projects/{project-id}/locations/us-central1/repositories/adam-agent-10-workflow/workflowInvocations/1752598992-06e003bc-aad3-477f-b761-02629a4d554f",
                "compilationResult": "projects/{project-number}/locations/us-central1/repositories/adam-agent-10-workflow/compilationResults/d4a2fa7c-c546-428a-814a-b8eece65a559",
                "state": "SUCCEEDED",
                "invocationTiming": {
                    "startTime": "2025-07-15T17:03:12.313196Z",
                    "endTime": "2025-07-15T17:03:17.650637343Z"
                },
                "resolvedCompilationResult": "projects/{project-number}/locations/us-central1/repositories/adam-agent-10-workflow/compilationResults/d4a2fa7c-c546-428a-814a-b8eece65a559",
                "internalMetadata": "{\"db_metadata_insert_time\":\"2025-07-15T17:03:12.321373Z\",\"quota_server_enabled\":true,\"service_account\":\"service-{project-number}@gcp-sa-dataform.iam.gserviceaccount.com\"}"
                }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataform_region = os.getenv("AGENT_ENV_DATAFORM_REGION")
    messages = []

    # The URL to list all repositories in the specified project and region. [1]
    url = f"https://dataform.googleapis.com/v1/projects/{project_id}/locations/{dataform_region}/repositories/{repository_id}/workflowInvocations/{workflow_invocation_id}"
    logger.debug(url)

    try:
        messages.append(f"Checkin on workflow invoation status with workflow_invocation_id: '{workflow_invocation_id}'.")
        # Call the REST API to get the list of all existing repositories. [1]
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        logger.debug(json_result)

        return {
            "status": "success",
            "tool_name": "get_worflow_invocation_status",
            "query": None,
            "messages": messages,
            "results": json_result
        }

    except Exception as e:
        logger.debug(e)
        # Check if the string representation of the error contains '404'
        if '404' in str(e):
            messages.append(f"Workflow Invocation not found for '{workflow_invocation_id}'. This is an expected outcome.")
            return {
                "status": "success",
                "tool_name": "get_worflow_invocation_status",
                "query": None,
                "messages": messages,
                "results": { "state" : "NOT_FOUND" }
            }
        else:
            # Handle all other errors as failures
            error_message = f"An unexpected error occurred while checking for existence of file: {e}"
            messages.append(error_message)
            return {
                "status": "failed",
                "tool_name": "get_worflow_invocation_status",
                "query": None,
                "messages": messages,
                "results": None
            }


async def get_repository_id_based_upon_display_name(repository_display_name: str) -> dict: # Changed to def
    """
    Gets a repository id based upon the display name.

    Args:
        repository_display_name (str): The repository display name shown in the Google Cloud Console

    Returns:
        dict: A dictionary containing the status and a boolean result.
        {
            "status": "success" or "failed",
            "tool_name": "get_repository_id_based_upon_display_name",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "exists": True or False,
                "repository_id": "The id of the repository" 
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataform_region = os.getenv("AGENT_ENV_DATAFORM_REGION")
    messages = []

    # The URL to list all repositories in the specified project and region. [1]
    url = f"https://dataform.googleapis.com/v1/projects/{project_id}/locations/{dataform_region}/repositories"

    try:
        messages.append(f"Looking up repository id based upon display name of: '{repository_display_name}'.")
        # Call the REST API to get the list of all existing repositories. [1]
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        messages.append("Successfully retrieved list of all repositories from the API.")

        repository_exists = False
        repository_id = ""

        for repo in json_result.get("repositories", []):
            # The full name is in the format: projects/{p}/locations/{l}/repositories/{id}
            name = repo.get("name", "")            
            displayName = repo.get("displayName", "")
            # Ensure repository_id is extracted from the matched repo's name
            repo_extracted_id = name.split("/")[-1]

            # Check the display name and the actual repo id for a match
            if displayName.lower()    == repository_display_name.lower() or \
               repo_extracted_id.lower() == repository_display_name.lower(): # Using extracted id
                repository_exists = True
                repository_id = repo_extracted_id # Assign the extracted ID
                messages.append(f"Found matching repository: '{repository_id}'.")
                break
        
        if not repository_exists:
            messages.append(f"repository with display name '{repository_display_name}' does not exist.")

        return {
            "status": "success",
            "tool_name": "get_repository_id_based_upon_display_name",
            "query": None,
            "messages": messages,
            "results": {"exists": repository_exists, "repository_id": repository_id}
        }

    except Exception as e:
        error_message = f"An error occurred while listing repositories: {e}"
        messages.append(error_message)
        return {
            "status": "failed",
            "tool_name": "get_repository_id_based_upon_display_name",
            "query": None,
            "messages": messages,
            "results": None
        }


async def list_dataform_respositories() -> dict: # Changed to def
    """
    Returns a list of the dataform repositories.

    Args:        

    Returns:
        dict: A dictionary containing the status and results
        {
            "status": "success" or "failed",
            "tool_name": "list_dataform_respositories",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                    "repositories": [
                        {
                            "name": "projects/{project-id}/locations/{location}/repositories/{repository-id}",
                            "labels": {
                            },
                            "displayName": "",
                            "createTime": "",
                            "internalMetadata": "dates and time in text encoded json"
                            }
                        ]
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataform_region = os.getenv("AGENT_ENV_DATAFORM_REGION")
    messages = []

    # The URL to list all repositories in the specified project and region. [1]
    url = f"https://dataform.googleapis.com/v1/projects/{project_id}/locations/{dataform_region}/repositories"

    try:
        # Call the REST API to get the list of all existing repositories. [1]
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        messages.append("Successfully retrieved list of all repositories from the API.")

        return {
            "status": "success",
            "tool_name": "list_dataform_respositories",
            "query": None,
            "messages": messages,
            "results": json_result
        }

    except Exception as e:
        error_message = f"An error occurred while listing repositories: {e}"
        messages.append(error_message)
        return {
            "status": "failed",
            "tool_name": "list_dataform_respositories",
            "query": None,
            "messages": messages,
            "results": None
        }


async def get_workspace_id_based_upon_display_name(repository_id:str, workspace_display_name: str) -> dict: # Changed to def
    """
    Gets a workspace id, within a repository, based upon the display name.

    Args:
        repository_id (str): The ID of the Dataform repository to use for the pipeline. 
        workspace_display_name (str): The workspace display name shown in the Google Cloud Console

    Returns:
        dict: A dictionary containing the status and a boolean result.
        {
            "status": "success" or "failed",
            "tool_name": "get_workspace_id_based_upon_display_name",
            "query": None,
            "messages": ["List of messages during processing"],
            "discovered-workspaces": ["List of workspaces that might be a match"],
            "results": {
                "exists": True or False,
                "workspace_id": "The id of the workspace"
            }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataform_region = os.getenv("AGENT_ENV_DATAFORM_REGION")
    messages = []
    discovered_workspaces = []

    # The URL to list all repositories in the specified project and region. [1]
    url = f"https://dataform.googleapis.com/v1/projects/{project_id}/locations/{dataform_region}/repositories/{repository_id}/workspaces"

    try:
        messages.append(f"Looking up workspace id based upon display name of: '{workspace_display_name}'.")
        # Call the REST API to get the list of all existing repositories. [1]
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        messages.append(f"Successfully retrieved list of all workspaces in the repository ({repository_id}) from the API.")

        #print(f"TTT repos: {json_result}")       
        workspace_exists = False
        workspace_id = ""

        for repo in json_result.get("workspaces", []):
            # The full name is in the format: projects/{p}/locations/{l}/repositories/{r}/workspaces/{w}
            name = repo.get("name", "") 
            current_workspace_id = name.split("/")[-1] # Extracted ID from current workspace
            #print(f"TTT workspace_id: {current_workspace_id}")                  

            if current_workspace_id.lower() == workspace_display_name.lower() or \
               current_workspace_id.lower() == workspace_display_name.lower().replace(" ", "-") :
                workspace_exists = True
                workspace_id = current_workspace_id # Assign the matched ID
                messages.append(f"Found matching workspace: '{workspace_id}'.")
                discovered_workspaces.append(current_workspace_id) # Add all discovered IDs
                break
            
            discovered_workspaces.append(current_workspace_id) # Add all discovered IDs

        if not workspace_exists:
            messages.append(f"Workspace with display name '{workspace_display_name}' does not exist.")

        #print(f"discovered-workspaces: {discovered_workspaces}")

        return {
            "status": "success",
            "tool_name": "get_workspace_id_based_upon_display_name",
            "query": None,
            "messages": messages,
            "discovered-workspaces": discovered_workspaces,
            "results": {"exists": workspace_exists, "workspace_id": workspace_id}
        }

    except Exception as e:
        error_message = f"An error occurred while listing repositories: {e}" # Message mentions repositories, but refers to workspaces
        messages.append(error_message)
        return {
            "status": "failed",
            "tool_name": "get_workspace_id_based_upon_display_name",
            "query": None,
            "messages": messages,
            "results": None
        } 


async def list_dataform_workspaces_in_a_repository(repository_id:str) -> dict: # Changed to def
    """
    Gets the workspaces under a repository

    Args:
        repository_id (str): The ID of the Dataform repository to get the respositories for.

    Returns:
        dict: A dictionary containing the status and a boolean result.
        {
            "status": "success" or "failed",
            "tool_name": "list_dataform_workspaces_in_a_repository",
            "query": None,
            "messages": ["List of messages during processing"],
            "results": {
                "workspaces": [
                    {
                    "name": "projects/{project-id}/locations/{location}/repositories/{repository-id}/workspaces/{workspace-id}",
                    "createTime": "",
                    "internalMetadata": "dates and time in text encoded json"
                    }
                ]
                }
        }
    """
    project_id = os.getenv("AGENT_ENV_PROJECT_ID")
    dataform_region = os.getenv("AGENT_ENV_DATAFORM_REGION")
    messages = []

    # The URL to list all workspaces in the specified repository.
    url = f"https://dataform.googleapis.com/v1/projects/{project_id}/locations/{dataform_region}/repositories/{repository_id}/workspaces"

    try:
        # Call the REST API to get the list of all existing workspaces.
        json_result = await rest_api_helper.rest_api_helper(url, "GET", None) # Added await
        messages.append(f"Successfully retrieved list of all workspaces in the repository ({repository_id}) from the API.")

        return {
            "status": "success",
            "tool_name": "list_dataform_workspaces_in_a_repository",
            "query": None,
            "messages": messages,
            "results": json_result
        }

    except Exception as e:
        error_message = f"An error occurred while listing workspaces: {e}" # Message mentions repositories, but refers to workspaces
        messages.append(error_message)
        return {
            "status": "failed",
            "tool_name": "list_dataform_workspaces_in_a_repository",
            "query": None,
            "messages": messages,
            "results": None
        }