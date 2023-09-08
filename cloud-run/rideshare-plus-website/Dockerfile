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

####################################################################################
# README: This is the same docker image that internal deployment will use to deploy your code
#         This allows you to test your Terraform as close as possible as the internal processes
# Software:                       Install Docker and .NET 7 (core)
# Build Image:                    docker build --pull -t rideshareplus .
# Run Image Locally (Bash):       docker run -it --entrypoint /bin/bash rideshareplus
# Run Image Locally (Terraform):  docker run --rm -it -p 8000:8080 rideshareplus
#                                 localhost:8000
# References:
# https://github.com/dotnet/dotnet-docker/blob/main/samples/README.md
#       https://github.com/dotnet/dotnet-docker/blob/main/samples/aspnetapp/README.md    
####################################################################################
FROM mcr.microsoft.com/dotnet/sdk:7.0-jammy AS build
WORKDIR /source

# Copy source, restore NuGet and publis
COPY RidesharePlus/ /source/
RUN dotnet restore --use-current-runtime
RUN dotnet publish --use-current-runtime --self-contained false --no-restore -o /app

# final stage/image
FROM mcr.microsoft.com/dotnet/aspnet:7.0-jammy
WORKDIR /app
COPY --from=build /app .
ENTRYPOINT ["./RidesharePlus"]