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
# run it: python sample-synthetic-data-generation.py
# deactivate

import langchain
from langchain.llms import VertexAI
import json


llm = VertexAI(
    model_name="text-bison@001",
    max_output_tokens=1024,
    temperature=0.25,
    top_p=0,
    top_k=1,
    verbose=True,
)

prompt="""Generate a list of json for the following JSON structure.
Avoid using newlines in the output.
The list should contain 5 elements.
For the field driver_id create a random UUID.
For the field driver_name create a random first and last name.
For the field trunk_space randomly assign it a value of null, "small" or "large". 25% of the values should be "small" or "large".
For the field driving_speed randomly assign it a value of null, "slow" or "fast". 25% of the values should be "slow" or "fast".
For the field hours_type randomly assign it a value of null, "weekday", "weekend", "rushhour" or "nighttime". 25% of the values should be null.
For the field nbr_pickup_locations randomly assign it a value of null, "few", "average" or "many". 25% of the values should be null.
For the field avg_trip_distance randomly assign it a value of null, "short", "medium" or "long". 50% of of the values should be null.


JSON format: [ { "driver_id": "value","driver_name": "value", "trunk_space" : null, "driving_speed" : null, "hours_type" : null, "nbr_pickup_locations" : null, "avg_trip_distance" : null } ]
"""
result = llm(prompt)
print()
print(result)
print()
print()


# Hopefully it is valid JSON
json_data = str(result)
json_object = json.loads(json_data)
json_formatted_str = json.dumps(json_object, indent=2)
print(json_formatted_str)

