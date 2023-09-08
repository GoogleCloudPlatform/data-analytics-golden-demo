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

--Steps to run website
cd RidesharePlus
dotnet run --urls=http://localhost:8080