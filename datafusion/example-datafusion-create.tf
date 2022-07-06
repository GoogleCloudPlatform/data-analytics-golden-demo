####################################################################################
# Copyright 2022 Google LLC
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

# Author: Eden Nuriel

locals {
  datafusion_name = "${var.demo_prefix}-${var.datafusion_name}"
}

resource "google_data_fusion_instance" "df" {
  provider                      = google-beta
  name                          = local.datafusion_name
  description                   = "My Data Fusion instance"
  region                        = var.datafusion_location
  type                          = "BASIC"
  enable_stackdriver_logging    = true
  enable_stackdriver_monitoring = true
  version                       = "6.6.0"
  # dataproc_service_account = "${google_project.prj.number}-compute@developer.gserviceaccount.com"
  depends_on = [module.project-services]
}

data "google_app_engine_default_service_account" "default" {
  provider = google-beta
}

# allow datafusion managed service account (from google tenent) to use datafusion agent in this project
resource "google_project_iam_binding" "fusion-dataproc" {
  project = google_project.prj.project_id
  role    = "roles/datafusion.serviceAgent"

  members = [
    "serviceAccount:service-${google_project.prj.number}@gcp-sa-datafusion.iam.gserviceaccount.com"
  ]
}


# allow data fusion default service account to impersonate compute engine default service account
resource "google_service_account_iam_binding" "df-dce" {
  service_account_id = data.google_compute_default_service_account.default.id
  role               = "roles/iam.serviceAccountUser"

  members = [
    "serviceAccount:service-${google_project.prj.number}@gcp-sa-datafusion.iam.gserviceaccount.com"
  ]

}

# Deploy your items (assuming you have them downloaded from source control)
resource "null_resource" "upload-df-pipeline" {
  provisioner "local-exec" {
    command = "datafusion-deploy.sh"
  }
  depends_on = [
    google_data_fusion_instance.df[0]
  ]
}

