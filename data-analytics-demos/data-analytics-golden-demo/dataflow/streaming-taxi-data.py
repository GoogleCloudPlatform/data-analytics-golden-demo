##################################################################################
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
###################################################################################

# Author: Wei Hsia

# TEMP_BUCKET=gs://your-gcs-bucket/dataflow-temp/
# REGION=your-region
# PROJECT=your-gcp-project
# DATASET=your-dataset
# TABLE=your-table
# OUTPUT=${PROJECT}:${DATASET}.${TABLE}

# python -m streaming-taxi-data \
#     --region $REGION \
#     --project $PROJECT \
#     --output $OUTPUT \
#     --runner DataflowRunner \
#     --temp_location $TEMP_BUCKET \
#     --streaming

import argparse
import logging
import re
import random
import json
import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions
from apache_beam.options.pipeline_options import SetupOptions
from apache_beam.options.pipeline_options import StandardOptions

class add_product_id(beam.DoFn):
    def process(self, element):
        element['product_id'] = round(1 + random.random() * (29120 - 1))
        yield element


def run(argv=None, save_main_session=True):
    """Main entry point; defines and runs the wordcount pipeline."""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--output',
        dest='output',
        required=True,
        help='BQ Destination Table specified as: PROJECT:DATASET.TABLE or DATASET.TABLE.')
    known_args, pipeline_args = parser.parse_known_args(argv)

    # Pub/Sub information: https://github.com/googlecodelabs/cloud-dataflow-nyc-taxi-tycoon
    input = "projects/pubsub-public-data/topics/taxirides-realtime"

    # We use the save_main_session option because one or more DoFn's in this
    # workflow rely on global context (e.g., a module imported at module level).
    pipeline_options = PipelineOptions(pipeline_args)
    pipeline_options.view_as(SetupOptions).save_main_session = save_main_session
    pipeline_options.view_as(StandardOptions).streaming = True

    # The pipeline will be run on exiting the with block.
    p = beam.Pipeline(options=pipeline_options)

    # Read the PubSub messages
    messages = (
        p | beam.io.ReadFromPubSub(topic=input)
        .with_output_types(bytes))

    # Translate to text
    json_messages = messages | "Parse JSON payload" >> beam.Map(json.loads)
    product_id_messages = json_messages | "Add Product ID" >> beam.ParDo(add_product_id())
    product_id_messages | 'Write to Table' >> beam.io.WriteToBigQuery(
            known_args.output,
            schema='ride_id:STRING, point_idx:INTEGER, latitude:FLOAT, longitude:FLOAT, timestamp:TIMESTAMP, '
                    'meter_reading:FLOAT ,meter_increment:FLOAT, ride_status:STRING, passenger_count:INTEGER, '
                    'product_id:INTEGER',
            write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND)

    p.run()



if __name__ == '__main__':
    logging.getLogger().setLevel(logging.INFO)
    run()