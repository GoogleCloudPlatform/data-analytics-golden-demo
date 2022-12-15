# Data-Analytics-Golden-Demo
Deploys a end to end working demo of a Data Analytics / Data Processing using Google Cloud.  All the services are connected, configured and ready to run.  All the artifacts are deployed and you can immedately start using.


![alt tag](./images/Architecture-Diagram.png)

![alt tag](./images/Technical-Architecture.png)

![alt tag](./images/Sample-Architecture.png)


## Deploying using Cloud Shell
You can deploy this to a new project or an existing project.
- New Project:
  - This requires you to be an Org Admin.  This is a great for personal projects or if IT is running the script.
- Existing Project:
  - This requires a project to be created in advance.  IT typically will create and provide a service account which is used to deploy.  Or IT can allow you to impersonate the service account (more secure then exporting a JSON credential file)


### To deploy to New Project (Preferred method)
1. Open a Google Cloud Shell: http://shell.cloud.google.com/ 
2. Type: git clone https://github.com/GoogleCloudPlatform/data-analytics-golden-demo
3. Switch the prompt to the directory: cd data-analytics-golden-demo
4. Run the deployment script: source deploy.sh  
5. Authorize the login (a popup will appear)
6. Follow the prompts: Answer “Yes” for each.


### To deploy to an Existing Project
1. Review the code in the deploy-use-existing-project.sh
2. You should have a project and a service account with the Owner role
3. You will just hard code the project and service account information into the script.  The script has code in it to "emualte" someone else creating a project.  


### After the deployment
- Open Cloud Composer.  You will see the Run-All-Dags DAG running.  This will run the DAGs needed to see the project with data.  Once this is done you can run the BigQuery stored procedures and other items in the demo.


### Possible Errors:
1. If the script fails to enable a service or timeouts, you can rerun and if that does not work, run "source clean-up.sh" and start over
2. If the script has security type message (unauthorized), then double check the configure roles/IAM security.
3. If you get the error "Error: Error when reading or editing Project Service : Request `List Project Services data-analytics-demo-xxxxxxxxx` returned error: Failed to list enabled services for project data-analytics-demo-xxxxxxxxx: Get "https://serviceusage.googleapis.com/v1/projects/data-analytics-demo-xxxxxxxxx/services?alt=json&fields=services%2Fname%2CnextPageToken&filter=state%3AENABLED&prettyPrint=false".  You need to start over.  Run "source clean-up.sh" and then run source deploy.sh again.  This is due to the service usage api not getting propagated with 4 minutes...
  - Delete your failed project
4. If you get a "networking error" with some dial tcp message [2607:f8b0:4001:c1a::5f], then your cloud shell had a networking glitch, not the Terraform network.  Restart the deployment "source deploy.sh". (e.g. Error creating Network: Post "https://compute.googleapis.com/compute/beta/projects/bigquery-demo-xvz1143xu9/global/networks?alt=json": dial tcp [2607:f8b0:4001:c1a::5f]:443: connect: cannot assign requested address)



## Folders
- cloud-composer
  - dags - all the DAGs for Airflow which run the system and seed the data
  - data - all the bash and SQL scripts to deploy
- dataflow
  - Dataflow job that connects to the public Pub/Sub sample streaming taxi data.  You start this using composer.
- dataproc
  - Spark code to that is used to process the initial downloaded data
- notebooks
  - Sample notebooks that can be run in Vertex AI.  To create the managed notebook, use the DAG in composer.
- sql-scripts
  - The BigQuery SQL sample scripts. These are currently deployed as stored procedures.  You can edit each stored procedure and run the sample code query by query.
- terraform
  - the entry point for when deploying via cloud shell or your local machine.  This uses service account impersonation
- terraform-modules
  - api - enables the GCP apis
  - org-policies - sets organization policies at the project level that have to be "disabled" to deploy the resources.
  - org-policies-deprecated - an older apporach for org policies and is needed when your cloud build account is in a different domain
  - project - creates the cloud project if a project number is not provided
  - resouces - the main set of resources to deploy
  - service-account - creates a service account if a project numnber is not provided.  The service account will be impersonated during the deployment.
  - service-usage - enables the service usage API as the main user (non-impersonated)
  - sql-scripts - deploys the sql scripts
