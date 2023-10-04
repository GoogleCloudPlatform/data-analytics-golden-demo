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
# Summary: Samples for langchain with vertex ai

# To setup your environemtn
# python3 -m venv .venv
# source .venv/bin/activate
# pip install --only-binary :all: greenlet
# pip install langchain pip install langchain==0.0.307
# pip install google-cloud-aiplatform 
# run it: python sample-prompt-json-output.py
# deactivate

import langchain
from langchain.llms import VertexAI
from langchain.embeddings import VertexAIEmbeddings

llm = VertexAI(
    model_name="text-bison@001",
    max_output_tokens=1024,
    temperature=0,
    top_p=0,
    top_k=1,
    verbose=True,
)

prompt="""For the below review peform the following:
1. Determine the sentitment of the review using the values of "Positive", "Neutral" or "Negative"
2. Classify the review as one or more of the below classifications.
3. Output the results in the below JSON format.

Classifications:
- "driver likes music"
- "driver has a dirty car"
- "driver has a clear car"
- "driver drives fast"
- "driver drives slow"

JSON format: { "sentiment" : null, [{ "classification" : null}] }
Sample JSON Response: { "sentiment" : "Positive", [{ "classification" : "driver likes music", "classification" : "driver drives slow" }] }

Review: I was taking a rideshare ride and the drivers car was spotless.  Not a spec of dirt could be found.  I could eat off the seats.  
I cannot believe how quickly he got me to my destination.  It was like taking a rocketship.  I was so scared!
"""
result = llm(prompt)
print (result)


#embeddings = VertexAIEmbeddings()
#text = "Embeddings are a way of data representation."
#text_embedding = embeddings.embed_query(text)
#print(text_embedding)
