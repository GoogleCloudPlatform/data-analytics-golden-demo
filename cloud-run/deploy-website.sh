project_id="data-analytics-demo-3npnp3v78u"
google_storage_bucket="code-data-analytics-demo-3npnp3v78u"
curl_impersonation=""
region="us-central1"

rm rideshare-plus-website.zip
zip -r rideshare-plus-website.zip ./rideshare-plus-website/*
gcloud storage cp rideshare-plus-website.zip "gs://${google_storage_bucket}/cloud-run/rideshare-plus-website/rideshare-plus-website.zip"

json=$(curl --request POST \
  "https://cloudbuild.googleapis.com/v1/projects/${project_id}/builds" \
  --header "Authorization: Bearer $(gcloud auth print-access-token ${curl_impersonation})" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data "{\"source\":{\"storageSource\":{\"bucket\":\"${google_storage_bucket}\",\"object\":\"cloud-run/rideshare-plus-website/rideshare-plus-website.zip\"}},\"steps\":[{\"name\":\"gcr.io/cloud-builders/docker\",\"args\":[\"build\",\"-t\",\"${region}-docker.pkg.dev/${project_id}/cloud-run-source-deploy/rideshareplus\",\"./rideshare-plus-website\"]},{\"name\":\"gcr.io/cloud-builders/docker\",\"args\":[\"push\",\"${region}-docker.pkg.dev/${project_id}/cloud-run-source-deploy/rideshareplus\"]}]}" \
  --compressed)

build_id=$(echo ${json} | jq .metadata.build.id --raw-output)
echo "build_id: ${build_id}"

# Loop while it creates
build_status_id="PENDING"
while [[ "${build_status_id}" == "PENDING" || "${build_status_id}" == "QUEUED" || "${build_status_id}" == "WORKING" ]]
    do
    sleep 5
    build_status_json=$(curl \
    "https://cloudbuild.googleapis.com/v1/projects/${project_id}/builds/${build_id}" \
    --header "Authorization: Bearer $(gcloud auth print-access-token ${curl_impersonation})" \
    --header "Accept: application/json" \
    --compressed)

    build_status_id=$(echo ${build_status_json} | jq .status --raw-output)
    echo "build_status_id: ${build_status_id}"
    done

if [[ "${build_status_id}" != "SUCCESS" ]]; 
then
    echo "Could not build the RidesharePlus Docker image with Cloud Build"
    # exit 1;
else
    echo "Cloud Build Successful"
    gcloud run services update demo-rideshare-plus-website \
      --image="${region}-docker.pkg.dev/${project_id}/cloud-run-source-deploy/rideshareplus" \
      --project="${project_id}" \
      --region="${region}"
fi


