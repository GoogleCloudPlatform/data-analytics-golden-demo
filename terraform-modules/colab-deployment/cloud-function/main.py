####################################################################################
# Copyright 2024 Google LLC
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

from google.cloud import dataform_v1beta1
import google.auth
import google.auth.transport.requests
import requests
import os

# Commit the notebook files to the repositories created by Terraform
def commit_repository_changes(client, project, region, gcp_account_name) -> str:

    # Get auth of service account
    creds, project = google.auth.default()
    auth_req = google.auth.transport.requests.Request() # required to acess access token
    creds.refresh(auth_req)
    access_token=creds.token
    auth_header = { 'Authorization'   : "Bearer " + access_token ,
                    'Content-Type'    : 'application/json'
    }

    directory = f"{os.path.dirname(__file__)}/notebooks/"
    for file in os.listdir(directory):
        with open(os.path.join(directory, file), 'rb') as f:
            encoded_string = f.read()
        file_base_name = os.path.basename(file).removesuffix(".ipynb")
        print(f"file_base_name: {file_base_name}")
        repo_id = f"projects/{project}/locations/{region}/repositories/{file_base_name}"
        print(f"repo_id: {repo_id}")
        request = dataform_v1beta1.CommitRepositoryChangesRequest()
        request.name = repo_id
        request.commit_metadata = dataform_v1beta1.CommitMetadata(
            author=dataform_v1beta1.CommitAuthor(
                name="Google Data Beans",
                email_address="no-reply@google.com"
            ),
            commit_message="Committing Data Beans notebook"
        )
        request.file_operations = {}
        request.file_operations["content.ipynb"] = \
            dataform_v1beta1.\
            CommitRepositoryChangesRequest.\
            FileOperation(write_file=dataform_v1beta1.
                          CommitRepositoryChangesRequest.
                          FileOperation.
                          WriteFile(contents=encoded_string)
                          )
        print(request.file_operations)
        client.commit_repository_changes(request=request)
        print(f"Committed changes to {repo_id}")

        # change the IAM permissions so the user owns the notebook and it shows in Colab correctly
        uri=f"https://dataform.googleapis.com/v1beta1/projects/{project}/locations/{region}/repositories/{file_base_name}:setIamPolicy"
        json = '{ "policy": { "bindings": [ { "role": "roles/dataform.admin", "members": [ "user:' + gcp_account_name + '" ] } ] } }'

        # curl -X POST "https://dataform.googleapis.com/v1beta1/projects/data-beans-xxxx/locations/us-central1/repositories/Event-Populate-Table:setIamPolicy" \
        # --header "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
        # --header "Content-Type: application/json" \
        # --data "${json}" \
        # --compressed

        try:
            print (f"Setting Policy URI: {uri}")
            print (f"Setting Policy JSON: {json}")
            response = requests.post(uri, headers=auth_header, data=json)
            response.raise_for_status()
            print(f"SUCCESS: Set IAM Policy for Notebook: {file_base_name}")
        except requests.exceptions.RequestException as err:
            print(f"FAILED: Set IAM Policy for Notebook: {file_base_name}")
            print(err)
            raise err
        
    return ("Committed changes to all repos")

def run_it(request) -> str:
    dataform_client = dataform_v1beta1.DataformClient()
    project_id = os.environ.get("PROJECT_ID")
    region_id = os.environ.get("DATAFORM_REGION")
    gcp_account_name = os.environ.get("GCP_ACCOUNT_NAME")
    commit_changes = commit_repository_changes(
        dataform_client, project_id, region_id, gcp_account_name)
    print("Notebooks created!")
    return commit_changes
