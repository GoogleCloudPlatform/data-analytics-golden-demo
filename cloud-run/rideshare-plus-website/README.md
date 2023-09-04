# https://codelabs.developers.google.com/codelabs/cloud-app-engine-aspnetcore
# https://cloud.google.com/run/docs/quickstarts/build-and-deploy/deploy-dotnet-service

gcloud auth list
gcloud config set project data-analytics-preview

# Install .net core 6.0.413

dotnet --list-sdks

dotnet new mvc -o RidesharePlus -lang "C#" -f net6.0

cd RidesharePlus

dotnet run --urls=http://localhost:8080

dotnet publish -c Release

cp ../app.yaml ./bin/Release/net6.0/publish/app.yaml

cd ./bin/Release/net6.0/publish

PROJECT_ID="data-analytics-preview"

gcloud services enable \
--project ${PROJECT_ID} \
run.googleapis.com \
cloudbuild.googleapis.com \
clouddeploy.googleapis.com \
artifactregistry.googleapis.com

gcloud builds submit \
--project ${PROJECT_ID} \
--pack image=us-central1-docker.pkg.dev/${PROJECT_ID}/cloud-run-source-deploy/rideshareplus \
/Users/paternostro/cloud-run-app/RidesharePlus

gcloud run deploy demo-rideshare-plus-website \
--project ${PROJECT_ID} \
--image us-central1-docker.pkg.dev/${PROJECT_ID}/cloud-run-source-deploy/rideshareplus \
--region us-central1 \
--cpu=1 \
--allow-unauthenticated \
--set-env-vars "KEY1=${PROJECT_ID}" \
--set-env-vars "KEY2=VALUE2" \
--set-env-vars "KEY3=VALUE3"


-- Install NuGet
dotnet add package Newtonsoft.Json --version 13.0.3
dotnet add package Google.Cloud.Storage.V1 --version 4.6.0
dotnet add package Google.Cloud.BigQuery.V2 --version 3.4.0
dotnet add package System.ComponentModel.Annotations --version 5.0.0
NO NO NO: dotnet remove package Microsoft.AspNet.WebApi.Cors --version 5.2.9

--Steps to run website
cd RidesharePlus
dotnet run --urls=http://localhost:8080


gcloud artifacts repositories create quickstart-docker-repo --repository-format=docker     \
--location=us-west2 --description="Docker repository" --project=data-analytics-demo-u0i2dr3u3j

-- set cloud build as writer
gcloud builds submit \
 --project=data-analytics-demo-u0i2dr3u3j \
 --region=us-west2 \
 --tag us-west2-docker.pkg.dev/data-analytics-demo-u0i2dr3u3j/quickstart-docker-repo/quickstart-image:tag1


gcloud builds submit "gs://code-data-analytics-demo-u0i2dr3u3j/cloud-build/rideshare-zip.zip" \
 --project=data-analytics-demo-u0i2dr3u3j \
 --region=us-west2 \
 --config=cloudbuild.yaml 
 
#### TF #####
json=$(curl --request POST \
  'https://cloudbuild.googleapis.com/v1/projects/data-analytics-demo-u0i2dr3u3j/builds' \
  --header "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --data '{"source":{"storageSource":{"bucket":"code-data-analytics-demo-u0i2dr3u3j","object":"cloud-build/rideshare-zip.zip"}},"steps":[{"name":"gcr.io/cloud-builders/docker","args":["build","-t","us-west2-docker.pkg.dev/data-analytics-demo-u0i2dr3u3j/quickstart-docker-repo/quickstart-image","./rideshare-zip"]},{"name":"gcr.io/cloud-builders/docker","args":["push","us-west2-docker.pkg.dev/data-analytics-demo-u0i2dr3u3j/quickstart-docker-repo/quickstart-image"]}]}' \
  --compressed)

build_id=$(echo $json | jq .metadata.build.id --raw-output)
echo "build_id: $build_id"

# Loop while it creates
build_status_id="PENDING"
while [[ "$build_status_id" == *"PENDING"* || "$build_status_id" == *"QUEUED"* || "$build_status_id" == *"WORKING"* ]]
    do
    sleep 5
    build_status_json=$(curl \
    "https://cloudbuild.googleapis.com/v1/projects/data-analytics-demo-u0i2dr3u3j/builds/$build_id" \
    --header "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
    --header 'Accept: application/json' \
    --compressed)

    build_status_id=$(echo $build_status_json | jq .status --raw-output)
    echo "build_status_id: $build_status_id"
    done

if [[ "${build_status_id}" != "SUCCESS" ]]; 
then
    echo "Could not build the RidesharePlus Docker image with Cloud Build"
    exit 1;
else
    echo "Cloud Build Successful"
fi


project_id="data-analytics-demo-u0i2dr3u3j"
google_storage_bucket="code-data-analytics-demo-u0i2dr3u3j"
curl_impersonation=""
cloud_function_region="us-central1"

json=$(curl --request POST \
  "https://cloudbuild.googleapis.com/v1/projects/${project_id}/builds" \
  --header "Authorization: Bearer $(gcloud auth print-access-token ${curl_impersonation})" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data '{"source":{"storageSource":{"bucket":"code-data-analytics-demo-u0i2dr3u3j","object":"cloud-build/rideshare-zip.zip"}},"steps":[{"name":"gcr.io/cloud-builders/docker","args":["build","-t","us-west2-docker.pkg.dev/data-analytics-demo-u0i2dr3u3j/quickstart-docker-repo/quickstart-image","./rideshare-zip"]},{"name":"gcr.io/cloud-builders/docker","args":["push","us-west2-docker.pkg.dev/data-analytics-demo-u0i2dr3u3j/quickstart-docker-repo/quickstart-image"]}]}' \
  --compressed)

build_id=$(echo ${json} | jq .metadata.build.id --raw-output)
echo "build_id: ${build_id}"

# Loop while it creates
build_status_id="PENDING"
while [[ "${build_status_id}" == *"PENDING"* || "${build_status_id}" == *"QUEUED"* || "${build_status_id}" == *"WORKING"* ]]
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
    exit 1;
else
    echo "Cloud Build Successful"
fi
