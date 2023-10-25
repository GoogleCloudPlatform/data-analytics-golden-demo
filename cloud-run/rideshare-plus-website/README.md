# Steps to run website
```
Make sure you have .NET 7 (dotnet core) installed
cd cloud-run
cd rideshare-plus-website
dotnet run --urls=http://localhost:8080
```

# To updatet the website on an existing deployment
```
cd cloud-run
Open deploy-website.sh and change the project ids and items (I probably could grab these from the state files...)
source deploy-website.sh
```

# Install NuGet Packages
```
dotnet add package Newtonsoft.Json --version 13.0.3
dotnet add package Google.Cloud.Storage.V1 --version 4.6.0
dotnet add package Google.Cloud.BigQuery.V2 --version 3.4.0
dotnet add package System.ComponentModel.Annotations --version 5.0.0
```

# .Net Core References
- https://codelabs.developers.google.com/codelabs/cloud-app-engine-aspnetcore
- https://cloud.google.com/run/docs/quickstarts/build-and-deploy/deploy-dotnet-service

```
PROJECT_ID="data-analytics-preview-001"
gcloud auth list
gcloud config set project ${PROJECT_ID}
```

# Original setup 
- Install .net core 7
- dotnet --list-sdks
- dotnet new mvc -o RidesharePlus -lang "C#" -f net7.0
- cd RidesharePlus
- dotnet run --urls=http://localhost:8080
- dotnet publish -c Release
- cp ../app.yaml ./bin/Release/net7.0/publish/app.yaml
- cd ./bin/Release/net7.0/publish

# To use cloud run and cloud build to deploy (already done in Terraform)
```
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
```