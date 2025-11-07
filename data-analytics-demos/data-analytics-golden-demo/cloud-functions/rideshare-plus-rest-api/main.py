# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# https://cloud.google.com/bigquery/docs/remote-function-tutorial
# import urllib.request

import flask
import functions_framework
from google.cloud import bigquery
from google.cloud import storage
import json
import os


@functions_framework.http
def entrypoint(request: flask.Request) -> flask.Response:
    print("BEGIN: entrypoint")
    try:
        # Set CORS headers for the preflight request
        if request.method == 'OPTIONS':
            # Allows all requests from any origin with any header
            # header and caches preflight response for an 3600s
            headers = {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': '*',
                'Access-Control-Allow-Headers': '*',
                'Access-Control-Max-Age': '3600'
            }
            print("END: entrypoint request.method == OPTIONS")
            return ('', 204, headers)

        request_json = request.get_json()
        print("request_json: ", request_json)
        mode = request_json['mode']
        print("mode: ", mode)
        print("END: entrypoint")
        
        if mode == "predict":
            return generate_predictions(request)
        elif mode == "streaming_data":
            return get_streaming_data(request)
        elif mode == "save_configuration":
            return save_configuration(request)
        elif mode == "get_configuration":
            return get_configuration(request)
        else:
            flask_response = flask.make_response(flask.jsonify({'Usage: mode not specified: predict or streaming_data'}), 200)
            flask_response.headers['Access-Control-Allow-Origin'] = '*'
            return flask_response

    except Exception as e:
        print ("Exception (entrypoint): " + str(e))
        flask_response_error =  flask.make_response(flask.jsonify({'errorMessage': str(e)}), 400)
        flask_response_error.headers['Access-Control-Allow-Origin'] = '*'
        return flask_response_error


def generate_predictions(request: flask.Request) -> flask.Response:
    try:
        print("BEGIN: generate_predictions")
        # {'mode': 'predict', 'ride_distance': 'short', 'is_raining': False, 'is_snowing': False}
        request_json = request.get_json()
        print("request_json: ", request_json)
        ride_distance = str(request_json['ride_distance']).lower()
        is_raining = str(request_json['is_raining']).upper()
        is_snowing = str(request_json['is_snowing']).upper()
        print("ride_distance: ", ride_distance)
        print("is_raining: ", is_raining)
        print("is_snowing: ", is_snowing)      
        project_id = os.environ['PROJECT_ID']
        print("project_id: ", project_id)      

        client = bigquery.Client()
        sql = "CALL `" + project_id + ".rideshare_lakehouse_curated.sp_website_score_data`('" + \
                ride_distance + "', " + is_raining + ", " + is_snowing + ", 0, 0);"
        print("sql: ", sql)
        query_job = client.query(sql);
        results = query_job.result()
        replies = []
        row_dict = { "success" : True}
        replies.append(row_dict)
        flask_response = flask.make_response(flask.jsonify({'data': replies}), 200)
        flask_response.headers['Access-Control-Allow-Origin'] = '*'
        print("END: generate_predictions")
        return flask_response
    except Exception as e:
        print ("Exception (generate_predictions): " + str(e))
        flask_response_error =  flask.make_response(flask.jsonify({'errorMessage': str(e)}), 400)
        flask_response_error.headers['Access-Control-Allow-Origin'] = '*'
        return flask_response_error


def get_streaming_data(request: flask.Request) -> flask.Response:
    try:     
        print("BEGIN: get_streaming_data")
        project_id = os.environ['PROJECT_ID']
        print("project_id: ", project_id) 

        client = bigquery.Client()
        sql = "SELECT * FROM `" + project_id + ".rideshare_lakehouse_curated.website_realtime_dashboard`"
        query_job = client.query(sql);
        results = query_job.result()
        replies = []
        for row in results:
            row_dict = { "ride_count": row.ride_count,
            "average_ride_duration_minutes": row.average_ride_duration_minutes, 
            "average_total_amount": row.average_total_amount, 
            "average_ride_distance": row.average_ride_distance, 
            "max_pickup_location_zone": row.max_pickup_location_zone, 
            "max_pickup_ride_count": row.max_pickup_ride_count, 
            "max_dropoff_location_zone": row.max_dropoff_location_zone, 
            "max_dropoff_ride_count": row.max_dropoff_ride_count
            }
            replies.append(row_dict)
            # print("{} : {} ".format(row.urride_countl, row.average_ride_duration_minutes))
       
        flask_response = flask.make_response(flask.jsonify({'data': replies}), 200)
        flask_response.headers['Access-Control-Allow-Origin'] = '*'
        print("END: get_streaming_data")
        return flask_response

    except Exception as e:
        print ("Exception (get_streaming_data): " + str(e))
        flask_response_error =  flask.make_response(flask.jsonify({'errorMessage': str(e)}), 400)
        flask_response_error.headers['Access-Control-Allow-Origin'] = '*'
        return flask_response_error


def save_configuration(request: flask.Request) -> flask.Response:
    try:
        print("BEGIN: save_configuration")
        # {'mode': 'predict', 'ride_distance': 'short', 'is_raining': False, 'is_snowing': False}
        request_json = request.get_json()
        print("request_json: ", request_json)
        looker_url = str(request_json['looker_url']).lower()
        print("looker_url: ", looker_url)
        project_id = os.environ['PROJECT_ID']
        print("project_id: ", project_id) 
        code_bucket = os.environ['ENV_CODE_BUCKET']
        print("code_bucket: ", code_bucket) 

        filename = "website/rideshareplusconfig.json";
        config_value = {
            "looker_url" : looker_url
        }
        default_json = json.dumps(config_value) 
       
        storage_client = storage.Client()
        bucket = storage_client.get_bucket(code_bucket)
        blob = bucket.blob(filename)
        blob.upload_from_string(default_json, content_type='application/json', num_retries=3)

        replies = []
        row_dict = { "success" : True}
        replies.append(row_dict)
        flask_response = flask.make_response(flask.jsonify({'data': replies}), 200)
        flask_response.headers['Access-Control-Allow-Origin'] = '*'
        print("END: save_configuration")
        return flask_response
    except Exception as e:
        print ("Exception (save_configuration): " + str(e))
        flask_response_error =  flask.make_response(flask.jsonify({'errorMessage': str(e)}), 400)
        flask_response_error.headers['Access-Control-Allow-Origin'] = '*'
        return flask_response_error


def get_configuration(request: flask.Request) -> flask.Response:
    try:
        print("BEGIN: get_configuration")
        filename = "website/rideshareplusconfig.json";
        default_config = {
            "looker_url" : "https://REPLACE-ME"
        }
        default_json = json.dumps(default_config) 
        project_id = os.environ['PROJECT_ID']
        print("project_id: ", project_id) 
        code_bucket = os.environ['ENV_CODE_BUCKET']
        print("code_bucket: ", code_bucket) 

        storage_client = storage.Client()
        bucket = storage_client.get_bucket(code_bucket)
        blob = bucket.blob(filename)
        if blob.exists() == False:
            print("Creating default configuration file.")
            blob.upload_from_string(default_json, content_type='application/json', num_retries=3)

        contents = blob.download_as_text() 

        config_dict = json.loads(contents)
        print(config_dict['looker_url'])
         
        replies = []
        row_dict = { "looker_url" : config_dict['looker_url']}
        replies.append(row_dict)
        flask_response = flask.make_response(flask.jsonify({'data': replies}), 200)
        flask_response.headers['Access-Control-Allow-Origin'] = '*'
        print("END: get_configuration")
        return flask_response
    except Exception as e:
        print ("Exception (get_configuration): " + str(e))
        flask_response_error =  flask.make_response(flask.jsonify({'errorMessage': str(e)}), 400)
        flask_response_error.headers['Access-Control-Allow-Origin'] = '*'
        return flask_response_error
