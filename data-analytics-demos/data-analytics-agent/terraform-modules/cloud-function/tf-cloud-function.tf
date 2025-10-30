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

####################################################################################
# Deploys a Google Cloud Function, Pub/Sub Topic, and Log-based Alert for Dataform Failures
#
# Author: Your Name
####################################################################################

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = "6.40.0" # Using the version from your provided code
    }
  }
}


####################################################################################
# Variables
####################################################################################
variable "project_id" {}
variable "cloud_run_region" {}
variable "multi_region" {}
variable "function_entry_point" {}
variable "function_source_dir" {
description = "Relative path to the Cloud Function source code directory."
type        = string
default     = "../agent-code-zip/agents/data_analytics_agent/cloud_function/source_files/"
}
variable "project_number" {}
variable "dataform_region" {}
variable "cloud_run_service_data_analytics_agent_api" {}

data "google_project" "current_project" {
  project_id = var.project_id
}

####################################################################################
# Pub/Sub Topic for Alerting and Cloud Function Trigger
####################################################################################

resource "google_pubsub_topic" "dataform_alert_topic" {
  project = var.project_id
  name    = "dataform-failed-alerts-topic-${random_id.suffix.hex}" # Making it unique and descriptive
  labels = {
    "purpose" = "dataform-failed-workflow-alerts"
  }
}

resource "google_project_service_identity" "monitoring_notification_identity" {
  project = var.project_id
  service = "monitoring.googleapis.com" # Target the Monitoring service
}

# Introduce a small delay to allow the service account to fully propagate
resource "time_sleep" "monitoring_identity_creation_delay" {
  depends_on      = [google_project_service_identity.monitoring_notification_identity]
  create_duration = "60s" # 30-60 seconds is a common recommendation for propagation
}

# Now, ensure the Monitoring API is enabled (if not already)
resource "google_project_service" "monitoring_api" {
  project = var.project_id
  service = "monitoring.googleapis.com"
  disable_on_destroy = false
  # It's good practice to depend on the identity being created first, though API activation often
  # happens logically before identity creation in Google's internal processes.
  # Depends_on is more critical for the IAM binding.
  depends_on = [google_project_service_identity.monitoring_notification_identity]
}

resource "google_pubsub_topic_iam_member" "monitoring_notification_publisher" {
  topic   = google_pubsub_topic.dataform_alert_topic.id # Reference your existing or new Pub/Sub topic
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.current_project.number}@gcp-sa-monitoring-notification.iam.gserviceaccount.com"
  depends_on = [
    time_sleep.monitoring_identity_creation_delay,
    google_project_service.monitoring_api # Also depend on the API being enabled
  ]
}

####################################################################################
# Cloud Function (Gen 2) Deployment
####################################################################################


resource "local_file" "function_main_file" {
  filename = "../agent-code-zip/agents/data_analytics_agent/cloud_function/source_files/main.py" 
  content = templatefile("../cloud-function/main.py",
   {
    project_id = var.project_id
    project_number = var.project_number
    dataform_region = var.dataform_region
    cloud_run_service_data_analytics_agent_api = var.cloud_run_service_data_analytics_agent_api
    project_num = data.google_project.current_project.number
    }
  )
}


resource "local_file" "function_requirement_file" {
  filename = "../agent-code-zip/agents/data_analytics_agent/cloud_function/source_files/requirements.txt" 
  content = templatefile("../cloud-function/requirements.txt",
   {
    }
  )
}

resource "google_project_iam_member" "service_account_token_creator" {
  project = var.project_id # Replace with your actual project ID
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${data.google_project.current_project.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "cloud_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${data.google_project.current_project.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "dataform_viewer_role" {
  project = var.project_id
  role    = "roles/dataform.viewer"
  member  = "serviceAccount:${data.google_project.current_project.number}-compute@developer.gserviceaccount.com"
}



resource "random_id" "suffix" {
  byte_length = 4 # Shorter suffix for bucket name to avoid hitting max length
}

resource "google_storage_bucket" "function_source_bucket" {
  project                     = var.project_id
  name                        = "${var.project_id}-gcf-source-${random_id.suffix.hex}" # Globally unique and descriptive
  location                    = var.multi_region
  uniform_bucket_level_access = true
  force_destroy               = true # Be cautious with this in production; useful for dev/test
}

data "archive_file" "function_source_zip" {
  type        = "zip"
  #output_path = "/tmp/function-source-${random_id.suffix.hex}.zip" # Unique temp file 
  output_path = "../agent-code-zip/agents/data_analytics_agent/cloud_function/function-source-${random_id.suffix.hex}.zip"
  source_dir  = var.function_source_dir
  depends_on = [
   local_file.function_main_file,
   local_file.function_requirement_file,
  ]
}

resource "google_storage_bucket_object" "function_zip_object" {
  name   = "function-source-${data.archive_file.function_source_zip.output_md5}.zip"
  bucket = google_storage_bucket.function_source_bucket.name
  source = data.archive_file.function_source_zip.output_path
}

resource "google_cloudfunctions2_function" "dataform_failure_function" {
  project     = var.project_id
  name        = "dataform-failure-handler-function-${random_id.suffix.hex}"
  location    = var.cloud_run_region
  description = "Handles notifications for Dataform failed workflows."

  build_config {
    runtime     = "python313"
    entry_point = var.function_entry_point
    source {
      storage_source {
        bucket = google_storage_bucket.function_source_bucket.name
        object = google_storage_bucket_object.function_zip_object.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 540
    # Ensure the Cloud Function's service account has permissions to logs/monitoring if it needs to interact with them
    # For a Pub/Sub triggered function, it needs `pubsub.subscriber` role on the topic if not using default GCF service account.
  }

  event_trigger {
    trigger_region = var.cloud_run_region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.dataform_alert_topic.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }
  depends_on = [
   google_storage_bucket_object.function_zip_object,
  ]
}

####################################################################################
# Log-based Alert Policy for Dataform Failed Workflows
####################################################################################

resource "google_monitoring_notification_channel" "pubsub_notification_channel" {
  project      = var.project_id
  display_name = "Dataform Failed Workflow Pub/Sub Channel"
  type         = "pubsub"
  labels = {
    "topic" = google_pubsub_topic.dataform_alert_topic.id # Changed from .name to .id
  }
  description = "Notification channel for Dataform failed workflow alerts, sending to Pub/Sub topic."
  enabled     = true
}

resource "google_logging_metric" "dataform_failed_workflow_metric" {
  project = var.project_id
  name    = "dataform-failed-workflow-metric-${random_id.suffix.hex}"
  description = "Logs of Dataform workflow invocations that failed."
  filter      = "resource.type=\"dataform.googleapis.com/Repository\" jsonPayload.@type=\"type.googleapis.com/google.cloud.dataform.logging.v1.WorkflowInvocationCompletionLogEntry\" jsonPayload.terminalState=\"FAILED\""
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

resource "google_monitoring_alert_policy" "dataform_failed_workflow_alert" {
  project      = var.project_id
  display_name = "Dataform Failed Workflow Alert"
  combiner     = "OR"
  enabled      = true
  severity    = "ERROR"

  notification_channels = [
    google_monitoring_notification_channel.pubsub_notification_channel.id,
  ]

  conditions {
    display_name = "Failed Dataform Workflow Detected"
    condition_matched_log {
      filter = google_logging_metric.dataform_failed_workflow_metric.filter
      label_extractors = {
        "workflow_inv_id" = "EXTRACT(jsonPayload.workflowInvocationId)"
      }
    }
  }

  alert_strategy {
    auto_close = "604800s" # 7 days
    notification_rate_limit {
      period = "300s" # Example: Limit notifications to once every 5 minutes (300 seconds)
                      # Adjust this period based on how frequently you want to be notified.
                      # Common values are "60s" (1 minute), "300s" (5 minutes), "600s" (10 minutes), etc.
    }
  }

  documentation {
    content   = "A Dataform workflow invocation has failed. Check the Dataform logs and the Cloud Function logs for details. The Pub/Sub message contains the original log entry."
    mime_type = "text/markdown"
  }

  user_labels = {
    "severity" = "critical"
    "service"  = "dataform"
  }
}

####################################################################################
# Outputs
####################################################################################

output "pubsub_topic_name" {
  description = "The name of the Pub/Sub topic created for Dataform alerts."
  value       = google_pubsub_topic.dataform_alert_topic.name
}

output "function_uri" {
  description = "The URI of the deployed Cloud Function."
  value       = google_cloudfunctions2_function.dataform_failure_function.service_config[0].uri
}

output "alert_policy_name" {
  description = "The display name of the created Alert Policy."
  value       = google_monitoring_alert_policy.dataform_failed_workflow_alert.display_name
}