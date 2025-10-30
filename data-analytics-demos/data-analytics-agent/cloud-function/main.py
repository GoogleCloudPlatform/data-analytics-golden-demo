import base64
import functions_framework
import json

import json
import os
import html
from datetime import datetime
import requests
import uuid
import google.auth
import google.auth.transport.requests
import pandas as pd




global_cloud_run_endpoint = "${cloud_run_service_data_analytics_agent_api}"
global_service_account_to_impersonate = "${project_num}-compute@developer.gserviceaccount.com"



# Get some values using gcloud
project_id = "${project_id}"
dataform_region="${dataform_region}"



# --- DataAnalyticsAgent Class (with MODIFIED __init__ and ask methods) ---
class DataAnalyticsAgent:
  def __init__(self, user_id, session_id):
    self.user_id, self.session_id, self.agent_name = user_id, session_id, "data_analytics_agent"
    self.cloud_run_endpoint = global_cloud_run_endpoint
    self.service_account_to_impersonate = global_service_account_to_impersonate
    self.bearer_token, self.bearer_token_timestamp = "", datetime.min
    self.conversation_list, self.conversation_id, self.message_id = [], 0, 0
    self.dataframe = pd.DataFrame() # This is NEW
    if self.get_session(): print("Session already exists.")
    else: self.create_session()

  def get_session(self):
    url = f"{self.cloud_run_endpoint}/apps/{self.agent_name}/users/{self.user_id}/sessions/{self.session_id}"
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {self.get_bearer_token()}"}
    try:
        with requests.get(url, headers=headers) as response: response.raise_for_status(); return "id" in json.loads(response.content)
    except (requests.exceptions.RequestException, json.JSONDecodeError): return False

  def create_session(self):
    url = f"{self.cloud_run_endpoint}/apps/{self.agent_name}/users/{self.user_id}/sessions/{self.session_id}"
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {self.get_bearer_token()}"}
    try:
        with requests.post(url, json={"state": {}}, headers=headers) as r: r.raise_for_status(); print(f"Session created.")
    except Exception as e: print(f"create_session error: {e}")
  
  def delete_session(self):
        """Deletes an existing session for the user."""
        url = f"{self.cloud_run_endpoint}/apps/{self.agent_name}/users/{self.user_id}/sessions/{self.session_id}"
        headers = {
            "Authorization": f"Bearer {self.get_bearer_token()}"
        }

        try:
            # Use requests.delete to destroy the resource
            with requests.delete(url, headers=headers) as r:
                r.raise_for_status() # Will raise a 404 error if the session doesn't exist
                print(f"Session '{self.session_id}' deleted successfully. Status: {r.status_code}")
                return r.json() # The ADK returns a small JSON status on success
        except requests.exceptions.HTTPError as http_err:
            print(f"delete_session HTTP error: {http_err} - Response: {r.text}")
        except Exception as e:
            print(f"delete_session unexpected error: {e}")

  def get_bearer_token(self):
    if (datetime.now() - self.bearer_token_timestamp).total_seconds() > 2700:
        print("Getting new identity token...")
        creds, _ = google.auth.default(); creds.refresh(google.auth.transport.requests.Request())
        url = f"https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/{self.service_account_to_impersonate}:generateIdToken"
        headers = {"Authorization": f"Bearer {creds.token}", "Content-Type": "application/json"}
        response = requests.post(url, json={"audience": self.cloud_run_endpoint}, headers=headers)
        response.raise_for_status()
        self.bearer_token, self.bearer_token_timestamp = response.json()["token"], datetime.now()
    return self.bearer_token

  def rest_api_sse_endpoint(self, human_message):
    headers = {"Accept": "text/event-stream", "Authorization": f"Bearer {self.get_bearer_token()}"}
    payload = {"appName": self.agent_name, "userId": self.user_id, "sessionId": self.session_id, "newMessage": {"role": "user", "parts": [{"text": human_message}]}, "streaming": True}
    url = f"{self.cloud_run_endpoint}/run_sse"
    try:
        with requests.post(url, headers=headers, json=payload, stream=True) as response:
            response.raise_for_status()
            for line in response.iter_lines(decode_unicode=True):
                if line and line.startswith('data:'): self.message_id += 1; yield {"message_id": self.message_id, "message_content": line[len('data: '):]}
    except Exception as e: print(f"\nError: {e}"); yield None

  def ask(self, human_input: str, show_details: bool = True) -> None:
    final_deferred_output_html, current_conversation_messages, final_text_content, final_answer_author = "", [], "", "Agent"

    for message in self.rest_api_sse_endpoint(human_input):
        if message is None: break
        current_conversation_messages.append(message)
        try:
            data = json.loads(message.get('message_content', '{}'))
            is_partial = data.get("partial", False)
            is_final_answer_chunk = any('text' in p and 'thought' not in p for p in data.get('content', {}).get('parts', []))
        except (json.JSONDecodeError, TypeError):
            continue

        if is_final_answer_chunk:
            if not is_partial:
                for part in data.get('content', {}).get('parts', []):
                    if 'text' in part:
                        final_text_content = part.get('text', '')
                final_answer_author = data.get('author', 'Agent')
        else:
            message

    if final_text_content:
        final_text_content
        

    if final_deferred_output_html:
        final_deferred_output_html

    if current_conversation_messages:
        self.conversation_id += 1
        self.conversation_list.append({"conversation_id": self.conversation_id, "conversation_messages": current_conversation_messages})

    # This is NEW and what I want
    # This new block iterates through the messages from the last interaction,
    # finds the BigQuery tool response, and populates the dataframe.
    for message in current_conversation_messages:
        try:
            data = json.loads(message.get('message_content', '{}'))
            if 'content' not in data or 'parts' not in data.get('content', {}):
                continue
            for part in data.get('content', {}).get('parts', []):
                if 'functionResponse' in part:
                    response_data = part.get('functionResponse', {}).get('response', {})
                    if response_data.get("tool_name") == "run_bigquery_sql":
                        results = response_data.get('results')
                        if results:
                            self.dataframe = pd.DataFrame(results)
                            return
        except (json.JSONDecodeError, TypeError):
            continue

def rest_api_helper(url: str, http_verb: str, request_body: str) -> str:
  """Calls the Google Cloud REST API passing in the current users credentials"""

  import google.auth.transport.requests
  import requests
  import google.auth
  import json

  # Get an access token based upon the current user
  creds, project = google.auth.default()
  auth_req = google.auth.transport.requests.Request()
  creds.refresh(auth_req)
  access_token=creds.token

  headers = {
    "Content-Type" : "application/json",
    "Authorization" : "Bearer " + access_token
  }

  if http_verb == "GET":
    response = requests.get(url, headers=headers)
  elif http_verb == "POST":
    response = requests.post(url, json=request_body, headers=headers)
  elif http_verb == "PUT":
    response = requests.put(url, json=request_body, headers=headers)
  elif http_verb == "PATCH":
    response = requests.patch(url, json=request_body, headers=headers)
  elif http_verb == "DELETE":
    response = requests.delete(url, headers=headers)
  else:
    raise RuntimeError(f"Unknown HTTP verb: {http_verb}")

  if response.status_code == 200:
      return json.loads(response.content)
  else:
    error = f"Error rest_api_helper -> ' Status: '{response.status_code}' Text: '{response.text}'"
    raise RuntimeError(error)

def get_workflow_failure_reason(repository_id: str, workflow_invocation_id: str,dataform_region,project_id) -> dict: # Changed to def
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
    messages = []

    # The URL to list all repositories in the specified project and region. [1]
    url = f"https://dataform.googleapis.com/v1/projects/{project_id}/locations/{dataform_region}/repositories/{repository_id}/workflowInvocations/{workflow_invocation_id}:query"
    #logger.debug(url)

    try:
        messages.append(f"Checkin on workflow invoation status with workflow_invocation_id: '{workflow_invocation_id}'.")
        # Call the REST API to get the list of all existing repositories. [1]
        json_result = rest_api_helper(url, "GET", None) # Added await
        #logger.debug(json_result)

        return json_result['workflowInvocationActions'][0]['failureReason']

    except Exception as e:
        #logger.debug(e)
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

random_session_id = str(uuid.uuid4())
da_agent = DataAnalyticsAgent("cloud_user", random_session_id)
#da_agent = DataAnalyticsAgent("cloud_user","session_119")
print(f"Generated Session ID: {random_session_id}")



# Triggered from a message on a Cloud Pub/Sub topic.
@functions_framework.cloud_event
def hello_pubsub(cloud_event):
    # Print out the data from Pub/Sub, to prove that it worked
    print(f"cloud event data: {cloud_event}")
    pubsub_message_data = cloud_event.data["message"]["data"]
    print(f"pubsub_message_data: {pubsub_message_data}")
    # Decode the base64 encoded data
    decoded_payload_bytes = base64.b64decode(pubsub_message_data)
    print(f"decoded_payload_bytes: {decoded_payload_bytes}")

    # Decode bytes to string
    decoded_payload_str = decoded_payload_bytes.decode('utf-8')
    print(f"decoded_payload_str: {decoded_payload_str}")
    # Parse the JSON string into a Python dictionary
    data = json.loads(decoded_payload_str)
    print(f"full json payload data: {data}")
    # Now you can access the workflow_inv_id
    summary = data['incident']['summary']
    print(f"summary: {summary}")
    start_index = summary.find("workflow_inv_id=") + len("workflow_inv_id=")
    end_index = summary.find("}", start_index)
    workflow_inv_id = summary[start_index:end_index]
    repository_id = data['incident']['resource']['labels']['repository_id']
    #repository_id="sales"
    failure_reason=get_workflow_failure_reason(repository_id, workflow_inv_id,dataform_region,project_id)
    print(f"Failure reason for the workflow: {failure_reason}")
    #failure_reason='Query error: Name cust_name not found inside c at [48:5]'
    fix_pipeline_prompt=f"""Fix the bigquery pipeline {repository_id}, I'm getting this error while executing it: {failure_reason}, don't use Automated data quality fix to fix the pipeline, use data engineering agent"""
    da_agent.ask(fix_pipeline_prompt)
    print(f"Fixed   and executed the pipeline  :  {repository_id}")
    print(f"The workflow_inv_id is: {workflow_inv_id}")
    print("Full decoded payload:", decoded_payload_str)
    da_agent.delete_session()
    print(f"Deleted session ID: {random_session_id}")
