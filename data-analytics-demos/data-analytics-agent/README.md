# Agentic Beans: AI Agents on Google Cloud

*Step into the future of data analytics with autonomous AI Agents.*

<table>
<tr>
<td width="50%">
<a href="images/Architecture.png">
<!-- This image should be in your demo's images subfolder -->
<img src="images/Architecture.png" alt="Agentic Beans Architecture Diagram">
</a>
</td>
<td width="50%">
This demo unveils AI Agents, a transformative approach to data analytics that drives new levels of automation and efficiency. See intelligent agents in action as they proactively detect data inconsistencies, generate precise forecasts, and even find and fix broken data pipelines without human intervention.
<br/><br/>
Move beyond reactive data analytics and learn how AI Agents empower your organization with proactive intelligence and a resilient data foundation.
<br/><br/>
<b>Key Features:</b>
<ul>
  <li><b>Automated Data Quality & Remediation:</b> Watch as an agent autonomously detects, diagnoses, and repairs a broken data pipeline.</li>
  <li><b>Metadata-Powered Agent Building:</b> See how rich metadata enables agents to translate natural language into precise SQL queries.</li>
  <li><b>AI-Driven Forecasting:</b> Turn any user into a data scientist by generating accurate forecasts with foundation models.</li>
  <li><b>Conversational Analytics:</b> Build and interact with agents that can answer questions about your data in plain English.</li>
</ul>
<br/>
<a href="#notebook-deep-dive"><b>Explore the Notebooks Below &darr;</b></a>
</td>
</tr>
</table>

---

### Important Notes
- The Colab notebooks will be deployed **every time** you run the deployment script.
- The Data Analytics Agent itself (Cloud Run service) will also be deployed **every time**. You may need to manually delete prior revisions in the Cloud Run service details page to manage costs and versions.

## Demo Cost and Usage

*   **Idle Cost:** ~$4/day. You can minimize this by deleting the Colab Enterprise Runtime after your session and recreating it when needed.
*   **Notebook Execution:** <$1 per run for most GenAI and BigQuery notebooks. Costs can scale with the volume of data processed.

**Usage Notes:**

*   Notebooks use the latest Gemini models with JSON output. The exact output may vary slightly as models are updated. For production use cases, it's recommended to pin to a specific model version.
*   When using the notebooks, connect to the **"colab-enterprise-runtime"** from within Colab Enterprise.

## Notebook Deep Dive

Each notebook demonstrates a key aspect of the solution. Explore them below to understand the technology behind the agent.

| Title | Description | Technology | Video | Link |
|---|---|---|---|---|
| Demo-Agent-Agentspace | Configures Gemini Enterprise (formerly Agentspace) to use the custom Data Analytics Agent. | ADK, Gemini Enterprise, BigQuery | [Link](https://storage.googleapis.com/data-analytics-golden-demo/colab-videos/Demo-Agent-Agentspace.mp4) | [Link](colab-enterprise/Demo-Agent-Agentspace.ipynb) |
| Demo-Agent-Data-Analytics-Agent | Showcases how to use the custom Data Analytics Agent in a notebook. It allows you to talk to the agent and construct data frames from the results. | ADK, Notebooks, Dataform | [Link](https://storage.googleapis.com/data-analytics-golden-demo/colab-videos/Demo-Agent-Data-Analytics-Agent.mp4) | [Link](colab-enterprise/Demo-Agent-Data-Analytics-Agent.ipynb) |
| Demo-Agent-Self-Healing-Pipeline | Demonstrates some of the code behind the self-healing data pipeline using data quality and the data engineering agent. | Data Engineering Agent, Data Quality, Dataform | [Link](https://storage.googleapis.com/data-analytics-golden-demo/colab-videos/Demo-Agent-Self-Healing-Pipeline.mp4) | [Link](colab-enterprise/Demo-Agent-Self-Healing-Pipeline.ipynb) |
| Demo-Conversational-Analytics | A demo of the Conversational Analytics API in a custom UI (Colab notebook). See how to create, query, and manage conversational agents. | Knowledge Engine, Conversational Analytics | [Link](https://storage.googleapis.com/data-analytics-golden-demo/colab-videos/Demo-Conversational-Analytics.mp4) | [Link](colab-enterprise/Demo-Conversational-Analytics.ipynb) |
| Demo-Data-Engineering-Agent-Spark-Conversion | See notebook for details on converting data pipelines. | Data Engineering Agent | [Link](https://storage.googleapis.com/data-analytics-golden-demo/colab-videos/Demo-Data-Engineering-Agent-Spark-Conversion.mp4) | [Link](colab-enterprise/Demo-Data-Engineering-Agent-Spark-Conversion.ipynb) |
| Demo-Data-Engineering-Agent | A step-by-step guide to using the Data Engineering Agent REST API directly. | Data Engineering Agent, Dataform | [Link](https://storage.googleapis.com/data-analytics-golden-demo/colab-videos/Demo-Data-Engineering-Agent.mp4) | [Link](colab-enterprise/Demo-Data-Engineering-Agent.ipynb) |
| Demo-Knowledge-Engine | This will create knowledge engine scans and business glossaries from the output of the knowledge engine scan. | Knowledge Engine, Dataplex Business Glossary | [Link](https://storage.googleapis.com/data-analytics-golden-demo/colab-videos/Demo-Knowledge-Engine.mp4) | [Link](colab-enterprise/Demo-Knowledge-Engine.ipynb) |

---

## How to Deploy

There are two options to deploy the demo, depending on your access privileges to your Google Cloud organization.

### Require Permissions to Deploy (2 Options)
1. **Elevated Privileges - Org Level**
   - **The following IAM roles are required to deploy the solution:**
      - Prerequisite: `Billing Account User` (to create the project with billing)
   - **To deploy the code you will:**
      - Run ```source deploy.sh```

2. **Owner Project Privileges - Typically Requires Assistance from IT**
   - **The following items are required to deploy the solution:**
      - Prerequisite: You will need a project created for you (IT can do this for you).
      - Prerequisite: You will need to be an `Owner` (IAM role) of the project to run the below script.
   - **To deploy the code you will:**
      - Update the hard-coded values in `deploy-use-existing-project-non-org-admin.sh`
      - Run ```source deploy-use-existing-project-non-org-admin.sh```

### Using your Local machine (Assuming Linux based)
1. Install Git (might already be installed)
2. Install Curl (might already be installed)
3. Install `jq` (might already be installed) - https://jqlang.github.io/jq/download/
4. Install Google Cloud CLI (`gcloud`) - https://cloud.google.com/sdk/docs/install
5. Install Terraform - https://developer.hashicorp.com/terraform/install
6. Login:   
   ```
   gcloud auth login
   gcloud auth application-default login
   ```
7. Clone the repository:
   ```
   git clone https://github.com/GoogleCloudPlatform/data-analytics-golden-demo.git
   ```
8. Switch to the demo directory:
   ```
   cd data-analytics-golden-demo/data-analytics-demos/data-analytics-agent
   ```
9. Run the deployment script based on your permission level:
   #### If using Elevated Privileges:
   ```
   source deploy.sh
   ```

   #### If using Owner Project Privileges:
   - First, update the hard-coded values in the script
   ```
   source deploy-use-existing-project-non-org-admin.sh
   ```
10. Authorize the login when a popup appears in your browser.
11. Follow the prompts in your terminal: Answer “Yes” for the Terraform approval.

### To deploy through a Google Cloud Compute VM
1. Create a new Compute VM with a Public IP address or Internet access on a Private IP
   - The default VM is fine (e.g.)
      - EC2 machine is fine for size
      - OS: Debian GNU/Linux 12 (bookworm)
2. SSH into the machine.  You might need to create a firewall rule (it will prompt you with the rule if it times out)   
3. Run these commands on the machine one by one:
   ```
   sudo apt update
   sudo apt upgrade -y
   sudo apt install git
   git config --global user.name "FirstName LastName"
   git config --global user.email "your@email-address.com"
   git clone https://github.com/GoogleCloudPlatform/data-analytics-golden-demo
   cd data-analytics-golden-demo/
   sudo apt-get install apt-transport-https ca-certificates gnupg curl
   sudo apt-get install jq
   gcloud auth login
   gcloud auth application-default login
   sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
   wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
   gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
   https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt update
   sudo apt-get install terraform

   source deploy.sh 
   # Or 
   # Update the hard coded values in deploy-use-existing-project-non-org-admin.sh
   # Run source deploy-use-existing-project-non-org-admin.sh
   ```