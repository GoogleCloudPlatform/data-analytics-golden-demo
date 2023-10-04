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
# Summary: Sample data generation for "fake" data.

# To setup your environemtn
# python3 -m venv .venv
# source .venv/bin/activate
# pip install --only-binary :all: greenlet
# pip install langchain pip install langchain==0.0.307
# pip install google-cloud-aiplatform 
# run it: python sample-synthetic-data-generation.py
# deactivate

import json
import langchain
from langchain.llms import VertexAI


################################################################################################
# Generate Driver data
################################################################################################
llm = VertexAI(
    model_name="text-bison@001",
    max_output_tokens=1024,
    temperature=0.25,
    top_p=0,
    top_k=1,
    verbose=True,
)

prompt="""Generate a list of json for the following JSON structure.
Avoid using newlines or special characters in the JSON structure.
The list should contain 5 elements.
For the field driver_id create a random UUID.
For the field driver_name create a random first and last name.
For the field trunk_space randomly assign it a value of null, "small" or "large". 25% of the values should be "small" or "large".
For the field driving_speed randomly assign it a value of null, "slow" or "fast". 25% of the values should be "slow" or "fast".
For the field hours_type randomly assign it a value of null, "weekday", "weekend", "rushhour" or "nighttime". 25% of the values should be null.
For the field nbr_pickup_locations randomly assign it a value of null, "few", "average" or "many". 25% of the values should be null.
For the field avg_trip_distance randomly assign it a value of null, "short", "medium" or "long". 50% of of the values should be null.


JSON structure: [ { "driver_id": "value","driver_name": "value", "trunk_space" : null, "driving_speed" : null, "hours_type" : null, "nbr_pickup_locations" : null, "avg_trip_distance" : null } ]
"""
result = llm(prompt)
print("Output for generated Driver data:")
print(result)
print()
print()


# Hopefully it is valid JSON
json_data = str(result)
json_object = json.loads(json_data)
json_formatted_str = json.dumps(json_object, indent=2)
print(json_formatted_str)
print()
print()


################################################################################################
# Generate Trip Data (start/end address, geo information, distances)
################################################################################################
llm = VertexAI(
    model_name="text-bison@001",
    max_output_tokens=1024,
    temperature=0.5,
    top_p=.5,
    top_k=20,
    verbose=True,
)


prompt="""
Goal:
Generate a JSON object using the below JSON structure.
Avoid using newlines or special characters in the JSON structure.

Elements:
- For the field trip_id create a random UUID.
- For the field driver_id create a random number between 1 and 1000.
- For the field customer_id create a random number between 1 and 5000.
- For the field passenger_count generate a random number between 1 and 4.
- For the field pickup_address generate a random address in New York City.
- For the field pickup_latitude get the latitude of the pickup_address.
- For the field pickup_longitude get the longitude of the pickup_address.
- For the field pickup_time select a random day, hour, minute and second in January 2023 and format the value as a timestamp.
- For the field dropoff_address generate a random address in New York City.
- For the field dropoff_latitude get the latitude of the dropoff_address.
- For the field dropoff_longitude get the longitude of the dropoff_address.
- For the field dropoff_time compute the average driving time between the pickup_address and the dropoff_address.
- For the field distance compute the distance in miles between the pickup_address and the dropoff_address.
- For the field fare_amount compute this by the distance multiplied by $2.15, add $3.00 per passenger_count and round to two decimal places.
- For the field tip_amount generate a random amount between 0% and 25% of the fare_amount and round to two decimal places.

JSON structure: { "trip_id": null,"driver_id": null, "customer_id": null, "passenger_count": null, "pickup_address": null, "pickup_latitude": null, "pickup_longitude" : null, "pickup_time": null, "dropoff_address": null, "dropoff_latitude": null, "dropoff_longitude": null, "dropoff_time": null, "distance": null, "fare_amount": null, "tip_amount": null }
"""
result = llm(prompt)
print("Output for generated Trip data:")
print(result)
print()
print()


# Hopefully it is valid JSON
json_data = str(result)
json_object = json.loads(json_data)
json_formatted_str = json.dumps(json_object, indent=2)
print(json_formatted_str)
print()
print()



################################################################################################
# Trip data (London £ and kilometers) - List of 2 objects
################################################################################################
llm = VertexAI(
    model_name="text-bison@001",
    max_output_tokens=1024,
    temperature=0.5,
    top_p=.5,
    top_k=20,
    verbose=True,
)

prompt="""
Goal:
Generate a JSON list of two JSON objects using the below JSON structure.
Avoid using newlines or special characters in the JSON structure.
The JSON list should not be formated with ```.

Elements:
- For the field trip_id create a random UUID.
- For the field driver_id create a random number between 1 and 1000.
- For the field customer_id create a random number between 1 and 5000.
- For the field passenger_count generate a random number between 1 and 4.
- For the field pickup_address generate a random address in London England.
- For the field pickup_latitude get the latitude of the pickup_address.
- For the field pickup_longitude get the longitude of the pickup_address.
- For the field pickup_time select a random day, hour, minute and second in January 2023 and format the value as a timestamp.
- For the field dropoff_address generate a random address in London England.
- For the field dropoff_latitude get the latitude of the dropoff_address.
- For the field dropoff_longitude get the longitude of the dropoff_address.
- For the field dropoff_time compute the average driving time between the pickup_address and the dropoff_address.
- For the field distance compute the distance in miles between the pickup_address and the dropoff_address.
- For the field fare_amount compute this by the distance multiplied by £2.15, add £3.00 per passenger_count and round to two decimal places.
- For the field tip_amount generate a random amount between 0% and 25% of the fare_amount and round to two decimal places.

JSON structure: { "trip_id": null,"driver_id": null, "customer_id": null, "passenger_count": null, "pickup_address": null, "pickup_latitude": null, "pickup_longitude" : null, "pickup_time": null, "dropoff_address": null, "dropoff_latitude": null, "dropoff_longitude": null, "dropoff_time": null, "distance": null, "fare_amount": null, "tip_amount": null }
"""
result = llm(prompt)
print("Output for generated Trip (London) data:")
print(result)
print()
print()


# Hopefully it is valid JSON
json_data = str(result)
json_object = json.loads(json_data)
json_formatted_str = json.dumps(json_object, indent=2)
print(json_formatted_str)
print()
print()


################################################################################################
# Assignment
################################################################################################
llm = VertexAI(
    model_name="text-bison@001",
    max_output_tokens=1024,
    temperature=0,
    top_p=0,
    top_k=1,
    verbose=True,
)


prompt="""
Goal:
I need you to help me write a SQL statement to update the driver_id field.
I have a table named "trips" which has the following fields:
- trip_id int - the primary key
- driver_id int - the driver who makes the trip
- pickup_time timestamp - the pickup time of a trip
- dropoff_time timestamp - the drip off time of a trip

Output:
The SQL statement should not be formated with ```.

Use the following rules when writing the SQL statement:
Rule: Generate a random number for the driver_id between 1 and 1000 and assign it to the driver_id field.
Rule: The driver can only make one trip at a time; therefore, they may not have any overlapping pickup_time and dropoff_time.
"""
result = llm(prompt)
print("Output for generated Assignment data:")
print(result)
print()
print()






################################################################################################
# Fake Data (Credit Card numbers)
################################################################################################
llm = VertexAI(
    model_name="text-bison@001",
    max_output_tokens=1024,
    temperature=1,
    top_p=.5,
    top_k=40,
    verbose=True,
)


prompt="""I need you to generate some credit card numbers and return the response in the below JSON structure.
Avoid using newlines or special characters in the JSON structure.
Generate 25 random Visa credit card numbers. 
Randomly sort the list.
Randomly select one of the values.
Do not preface the response with any special characters or 'json'.
Do not include the credit card number 4111111111111111.

JSON structure:{ "credit_card_number": null }
"""
result = llm(prompt)
print("Output for generated Credit Card data:")
print(result)
print()
print()


# Hopefully it is valid JSON
json_data = str(result)
json_object = json.loads(json_data)
json_formatted_str = json.dumps(json_object, indent=2)
print(json_formatted_str)
print()
print()