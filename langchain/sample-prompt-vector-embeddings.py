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

# Author:  Adam Paternostro
# Summary: Create vector embeddings using Vertex AI

# To setup your environemtn
# python3 -m venv .venv
# source .venv/bin/activate
# pip install --only-binary :all: greenlet
# pip install langchain pip install langchain==0.0.307
# pip install google-cloud-aiplatform 
# run it: python sample-prompt-vector-embeddings.py
# deactivate

import langchain
from langchain.llms import VertexAI
from langchain.embeddings import VertexAIEmbeddings

# https://github.com/GoogleCloudPlatform/vertex-ai-samples/blob/main/notebooks/official/matching_engine/sdk_matching_engine_create_stack_overflow_embeddings_vertex.ipynb


embeddings = VertexAIEmbeddings()
text = "This text will be encoded for semantic search."
text_embedding = embeddings.embed_query(text)
print(text_embedding)
