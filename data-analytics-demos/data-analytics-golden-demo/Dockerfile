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
# Software:                       Install Docker
# Build Image:                    docker build -t terraform-deploy-image .
# Run Image Locally (Bash):       docker run -it --entrypoint /bin/bash -v $PWD:$PWD -w $PWD/terraform terraform-deploy-image
# Run Image Locally (Terraform):  docker run -it --entrypoint terraform -v $PWD:$PWD -w $PWD/terraform terraform-deploy-image init
#                                 docker run -it --entrypoint terraform -v $PWD:$PWD -w $PWD/terraform terraform-deploy-image validate
####################################################################################

FROM debian:stable-slim

RUN apt-get update && apt-get install git bash openssh-server curl python2 jq gnupg software-properties-common wget ca-certificates zip -y

##########################################################################################
# Install gcloud
##########################################################################################
RUN curl https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz > /tmp/google-cloud-sdk.tar.gz

# Install the package
RUN mkdir -p /usr/local/gcloud \
  && tar -C /usr/local/gcloud -xvf /tmp/google-cloud-sdk.tar.gz \
  && /usr/local/gcloud/google-cloud-sdk/install.sh

##########################################################################################
# Install terraform, kubectl, helm, KPT
##########################################################################################

ENV KUBE_LATEST_VERSION="v1.23.2"
ENV HELM_VERSION="v3.0.0"
ENV TERRAFORM_VERSION="1.1.7"
ENV KPT_VERSION="latest"

RUN wget -q https://storage.googleapis.com/kubernetes-release/release/${KUBE_LATEST_VERSION}/bin/linux/amd64/kubectl -O /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl \
    && wget -q https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -O - | tar -xzO linux-amd64/helm > /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm  \
    && wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && unzip terraform* && mv terraform /usr/local/bin/terraform \
    && chmod +x /usr/local/bin/terraform && rm terraform* \
    && wget https://storage.googleapis.com/kpt-dev/${KPT_VERSION}/linux_amd64/kpt -O /usr/local/bin/kpt \
    && chmod +x /usr/local/bin/kpt

##########################################################################################
# Clean Up Containeer
##########################################################################################
RUN apt-get clean autoclean && apt-get autoremove --yes && rm -rf /var/lib/{apt,dpkg,cache,log}/

ENV PATH $PATH:/usr/local/gcloud/google-cloud-sdk/bin