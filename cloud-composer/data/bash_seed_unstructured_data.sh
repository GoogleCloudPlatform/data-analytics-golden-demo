#!/bin/bash

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

# https://tfhub.dev/tensorflow/resnet_50/classification/1?tf-hub-format=compressed
# https://tfhub.dev/google/imagenet/mobilenet_v3_small_075_224/feature_vector/5?tf-hub-format=compressed
# The first folder "${raw_bucket_name}\biglake-unstructured-data" contains the images we will place a BigQuery Object table over
# The second folder "${code_bucket_name}\tf-models" contains TensorFlow models download from TensorFlow Hub: https://tfhub.dev/

# Change to Airflow data directory
cd /home/airflow/gcs/data

mkdir seed_unstructured_data
cd seed_unstructured_data

RAW_BUCKET_NAME="{{ params.raw_bucket_name }}"
CODE_BUCKET_NAME="{{ params.code_bucket_name }}"

# Copy sample images from public bucket to the Raw bucket so we can place an object table over them
gsutil -m cp -r gs://cloud-samples-data/vision  "gs://${RAW_BUCKET_NAME}/biglake-unstructured-data/"

# Set some meta tags so we can do row level security
gsutil setmeta -h "x-goog-meta-pii:true"  "gs://${RAW_BUCKET_NAME}/biglake-unstructured-data/vision/face/face_no_surprise.jpg"
gsutil setmeta -h "x-goog-meta-pii:true"  "gs://${RAW_BUCKET_NAME}/biglake-unstructured-data/vision/pdf_tiff/census2010.pdf"
gsutil setmeta -h "x-goog-meta-pii:true"  "gs://${RAW_BUCKET_NAME}/biglake-unstructured-data/vision/celebrity_recognition.jpg"
gsutil setmeta -h "x-goog-meta-pii:true"  "gs://${RAW_BUCKET_NAME}/biglake-unstructured-data/vision/document_parsing/key_value_pairs.pdf"
gsutil setmeta -h "x-goog-meta-pii:true"  "gs://${RAW_BUCKET_NAME}/biglake-unstructured-data/vision/text/screen.jpg"


mkdir resnet_50_classification_1
cd resnet_50_classification_1
curl -L https://tfhub.dev/tensorflow/resnet_50/classification/1?tf-hub-format=compressed   --output resnet_50_classification.tar.gz
tar xzf resnet_50_classification.tar.gz
rm resnet_50_classification.tar.gz
cd ..

mkdir imagenet_mobilenet_v3_small_075_224_feature_vector_5
cd imagenet_mobilenet_v3_small_075_224_feature_vector_5
curl -L https://tfhub.dev/google/imagenet/mobilenet_v3_small_075_224/feature_vector/5?tf-hub-format=compressed --output imagenet_mobilenet.tar.gz
tar xzf imagenet_mobilenet.tar.gz
rm imagenet_mobilenet.tar.gz
cd ..

gsutil cp -r ./resnet_50_classification_1  "gs://${CODE_BUCKET_NAME}/tf-models/"
gsutil cp -r ./imagenet_mobilenet_v3_small_075_224_feature_vector_5  "gs://${CODE_BUCKET_NAME}/tf-models/"

cd ..
rm -rf seed_unstructured_data