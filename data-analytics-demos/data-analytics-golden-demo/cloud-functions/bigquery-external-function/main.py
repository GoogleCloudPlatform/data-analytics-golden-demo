# Copyright 2023 Google LLC
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


import flask
import os
import urllib.request
import functions_framework
from google.cloud import vision
from google.api_core.client_options import ClientOptions
from google.cloud.speech_v2 import SpeechClient
from google.cloud.speech_v2.types import cloud_speech

# Entry point (we recevice an element named "userDefinedContext").  The userDefinedContext 
# tells us which method to call
@functions_framework.http
def bigquery_external_function(request: flask.Request) -> flask.Response:
    print("BEGIN: bigquery_external_function")
    request_json = request.get_json()
    print("request_json: ", request_json)
    mode = request_json['userDefinedContext']['mode']
    print("mode: ", mode)
    calls = request_json['calls']
    print("calls: ", calls)
    print("END: bigquery_external_function")
    if mode == "localize_objects_uri":
        return localize_objects_uri(request)
    elif mode == "detect_labels_uri":
        return detect_labels_uri(request)
    elif mode == "detect_landmarks_uri":
        return detect_landmarks_uri(request)
    elif mode == "detect_logos_uri":
        return detect_logos_uri(request)
    elif mode == "taxi_zone_lookup":
        return taxi_zone_lookup(request)
    elif mode == "extract_text_uri":
        return extract_text_uri(request)

# https://cloud.google.com/vision/docs/object-localizer#vision_localize_objects-python
@functions_framework.http
def localize_objects_uri(request: flask.Request) -> flask.Response:
    try:
        client = vision.ImageAnnotatorClient()
        calls = request.get_json()['calls']
        replies = []
        for call in calls:
            image = vision.Image()
            uri=call[0]
            print("uri: ", uri)
            image.source.image_uri = uri
            results = client.object_localization(image=image)
            replies.append(vision.AnnotateImageResponse.to_dict(results))
        print ("results: " + str(flask.jsonify({'replies': replies})))
        return flask.make_response(flask.jsonify({'replies': replies}))
    except Exception as e:
        return flask.make_response(flask.jsonify({'errorMessage': str(e)}), 400)


@functions_framework.http
def detect_labels_uri(request: flask.Request) -> flask.Response:
    try:
        client = vision.ImageAnnotatorClient()
        calls = request.get_json()['calls']
        replies = []
        for call in calls:
            image = vision.Image()
            uri=call[0]
            print("uri: ", uri)
            image.source.image_uri = uri
            results = client.label_detection(image=image)
            replies.append(vision.AnnotateImageResponse.to_dict(results))
        return flask.make_response(flask.jsonify({'replies': replies}))
    except Exception as e:
        return flask.make_response(flask.jsonify({'errorMessage': str(e)}), 400)



@functions_framework.http
def detect_landmarks_uri(request: flask.Request) -> flask.Response:
    try:
        client = vision.ImageAnnotatorClient()
        calls = request.get_json()['calls']
        replies = []
        for call in calls:
            image = vision.Image()
            uri=call[0]
            print("uri: ", uri)
            image.source.image_uri = uri
            results = client.landmark_detection(image=image)
            replies.append(vision.AnnotateImageResponse.to_dict(results))
        return flask.make_response(flask.jsonify({'replies': replies}))
    except Exception as e:
        return flask.make_response(flask.jsonify({'errorMessage': str(e)}), 400)


@functions_framework.http
def detect_logos_uri(request: flask.Request) -> flask.Response:
    try:
        client = vision.ImageAnnotatorClient()
        calls = request.get_json()['calls']
        replies = []
        for call in calls:
            image = vision.Image()
            uri=call[0]
            print("uri: ", uri)
            image.source.image_uri = uri
            results = client.logo_detection(image=image)
            replies.append(vision.AnnotateImageResponse.to_dict(results))
        return flask.make_response(flask.jsonify({'replies': replies}))
    except Exception as e:
        return flask.make_response(flask.jsonify({'errorMessage': str(e)}), 400)


# Hard coded lookup that could contain any custom code
# Look through the "calls" and process each element
@functions_framework.http
def taxi_zone_lookup(request: flask.Request) -> flask.Response:
    try:
        print("BEGIN: taxi_zone_lookup")
        replies = []
        lookup_dict = load_lookups()
        calls = request.get_json()['calls']
        for call in calls:
            locationCode=int(str(call[0]))
            print("locationCode: ", locationCode)
            results=(list(filter(lambda o: o['LocationId'] == locationCode, lookup_dict)))
            if len(results) == 1:
                replies.append(results[0])
            else:
                replies.append('{ "LocationID" : ' + str(call[0]) + ', "Borough" : "(unknown)", "Zone": "(unknown)", "service_zone":"(unknown)" }')

        print("END: taxi_zone_lookup")
        return flask.make_response(flask.jsonify({'replies': replies}))
    except Exception as e:
        return flask.make_response(flask.jsonify({'errorMessage': str(e)}), 400)


# Created using a spreadsheet from the NYC download
# https://d37ci6vzurychx.cloudfront.net/misc/taxi+_zone_lookup.csv
# =CONCATENATE("lookup_dict[",A2,"] = ","'", "{",CHAR(34),"LocationId", CHAR(34),":",A2,",",CHAR(34),"Borough",CHAR(34),":",CHAR(34),B2,CHAR(34),  ,",",CHAR(34),"Zone",CHAR(34),":",CHAR(34),C2,CHAR(34),",",CHAR(34),"ServiceZone",CHAR(34),":",CHAR(34),D2,CHAR(34),   "}","'")
def load_lookups():
    lookup_dict = []
    print("BEGIN: load_lookups")
    try:
        lookup_dict.append({"LocationId":1,"Borough":"EWR","Zone":"Newark Airport","ServiceZone":"EWR"})
        lookup_dict.append({"LocationId":2,"Borough":"Queens","Zone":"Jamaica Bay","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":3,"Borough":"Bronx","Zone":"Allerton/Pelham Gardens","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":4,"Borough":"Manhattan","Zone":"Alphabet City","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":5,"Borough":"Staten Island","Zone":"Arden Heights","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":6,"Borough":"Staten Island","Zone":"Arrochar/Fort Wadsworth","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":7,"Borough":"Queens","Zone":"Astoria","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":8,"Borough":"Queens","Zone":"Astoria Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":9,"Borough":"Queens","Zone":"Auburndale","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":10,"Borough":"Queens","Zone":"Baisley Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":11,"Borough":"Brooklyn","Zone":"Bath Beach","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":12,"Borough":"Manhattan","Zone":"Battery Park","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":13,"Borough":"Manhattan","Zone":"Battery Park City","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":14,"Borough":"Brooklyn","Zone":"Bay Ridge","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":15,"Borough":"Queens","Zone":"Bay Terrace/Fort Totten","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":16,"Borough":"Queens","Zone":"Bayside","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":17,"Borough":"Brooklyn","Zone":"Bedford","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":18,"Borough":"Bronx","Zone":"Bedford Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":19,"Borough":"Queens","Zone":"Bellerose","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":20,"Borough":"Bronx","Zone":"Belmont","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":21,"Borough":"Brooklyn","Zone":"Bensonhurst East","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":22,"Borough":"Brooklyn","Zone":"Bensonhurst West","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":23,"Borough":"Staten Island","Zone":"Bloomfield/Emerson Hill","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":24,"Borough":"Manhattan","Zone":"Bloomingdale","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":25,"Borough":"Brooklyn","Zone":"Boerum Hill","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":26,"Borough":"Brooklyn","Zone":"Borough Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":27,"Borough":"Queens","Zone":"Breezy Point/Fort Tilden/Riis Beach","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":28,"Borough":"Queens","Zone":"Briarwood/Jamaica Hills","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":29,"Borough":"Brooklyn","Zone":"Brighton Beach","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":30,"Borough":"Queens","Zone":"Broad Channel","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":31,"Borough":"Bronx","Zone":"Bronx Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":32,"Borough":"Bronx","Zone":"Bronxdale","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":33,"Borough":"Brooklyn","Zone":"Brooklyn Heights","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":34,"Borough":"Brooklyn","Zone":"Brooklyn Navy Yard","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":35,"Borough":"Brooklyn","Zone":"Brownsville","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":36,"Borough":"Brooklyn","Zone":"Bushwick North","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":37,"Borough":"Brooklyn","Zone":"Bushwick South","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":38,"Borough":"Queens","Zone":"Cambria Heights","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":39,"Borough":"Brooklyn","Zone":"Canarsie","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":40,"Borough":"Brooklyn","Zone":"Carroll Gardens","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":41,"Borough":"Manhattan","Zone":"Central Harlem","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":42,"Borough":"Manhattan","Zone":"Central Harlem North","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":43,"Borough":"Manhattan","Zone":"Central Park","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":44,"Borough":"Staten Island","Zone":"Charleston/Tottenville","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":45,"Borough":"Manhattan","Zone":"Chinatown","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":46,"Borough":"Bronx","Zone":"City Island","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":47,"Borough":"Bronx","Zone":"Claremont/Bathgate","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":48,"Borough":"Manhattan","Zone":"Clinton East","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":49,"Borough":"Brooklyn","Zone":"Clinton Hill","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":50,"Borough":"Manhattan","Zone":"Clinton West","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":51,"Borough":"Bronx","Zone":"Co-Op City","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":52,"Borough":"Brooklyn","Zone":"Cobble Hill","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":53,"Borough":"Queens","Zone":"College Point","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":54,"Borough":"Brooklyn","Zone":"Columbia Street","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":55,"Borough":"Brooklyn","Zone":"Coney Island","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":56,"Borough":"Queens","Zone":"Corona","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":57,"Borough":"Queens","Zone":"Corona","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":58,"Borough":"Bronx","Zone":"Country Club","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":59,"Borough":"Bronx","Zone":"Crotona Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":60,"Borough":"Bronx","Zone":"Crotona Park East","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":61,"Borough":"Brooklyn","Zone":"Crown Heights North","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":62,"Borough":"Brooklyn","Zone":"Crown Heights South","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":63,"Borough":"Brooklyn","Zone":"Cypress Hills","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":64,"Borough":"Queens","Zone":"Douglaston","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":65,"Borough":"Brooklyn","Zone":"Downtown Brooklyn/MetroTech","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":66,"Borough":"Brooklyn","Zone":"DUMBO/Vinegar Hill","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":67,"Borough":"Brooklyn","Zone":"Dyker Heights","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":68,"Borough":"Manhattan","Zone":"East Chelsea","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":69,"Borough":"Bronx","Zone":"East Concourse/Concourse Village","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":70,"Borough":"Queens","Zone":"East Elmhurst","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":71,"Borough":"Brooklyn","Zone":"East Flatbush/Farragut","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":72,"Borough":"Brooklyn","Zone":"East Flatbush/Remsen Village","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":73,"Borough":"Queens","Zone":"East Flushing","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":74,"Borough":"Manhattan","Zone":"East Harlem North","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":75,"Borough":"Manhattan","Zone":"East Harlem South","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":76,"Borough":"Brooklyn","Zone":"East New York","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":77,"Borough":"Brooklyn","Zone":"East New York/Pennsylvania Avenue","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":78,"Borough":"Bronx","Zone":"East Tremont","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":79,"Borough":"Manhattan","Zone":"East Village","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":80,"Borough":"Brooklyn","Zone":"East Williamsburg","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":81,"Borough":"Bronx","Zone":"Eastchester","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":82,"Borough":"Queens","Zone":"Elmhurst","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":83,"Borough":"Queens","Zone":"Elmhurst/Maspeth","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":84,"Borough":"Staten Island","Zone":"Eltingville/Annadale/Prince's Bay","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":85,"Borough":"Brooklyn","Zone":"Erasmus","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":86,"Borough":"Queens","Zone":"Far Rockaway","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":87,"Borough":"Manhattan","Zone":"Financial District North","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":88,"Borough":"Manhattan","Zone":"Financial District South","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":89,"Borough":"Brooklyn","Zone":"Flatbush/Ditmas Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":90,"Borough":"Manhattan","Zone":"Flatiron","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":91,"Borough":"Brooklyn","Zone":"Flatlands","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":92,"Borough":"Queens","Zone":"Flushing","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":93,"Borough":"Queens","Zone":"Flushing Meadows-Corona Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":94,"Borough":"Bronx","Zone":"Fordham South","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":95,"Borough":"Queens","Zone":"Forest Hills","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":96,"Borough":"Queens","Zone":"Forest Park/Highland Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":97,"Borough":"Brooklyn","Zone":"Fort Greene","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":98,"Borough":"Queens","Zone":"Fresh Meadows","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":99,"Borough":"Staten Island","Zone":"Freshkills Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":100,"Borough":"Manhattan","Zone":"Garment District","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":101,"Borough":"Queens","Zone":"Glen Oaks","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":102,"Borough":"Queens","Zone":"Glendale","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":103,"Borough":"Manhattan","Zone":"Governor's Island/Ellis Island/Liberty Island","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":104,"Borough":"Manhattan","Zone":"Governor's Island/Ellis Island/Liberty Island","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":105,"Borough":"Manhattan","Zone":"Governor's Island/Ellis Island/Liberty Island","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":106,"Borough":"Brooklyn","Zone":"Gowanus","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":107,"Borough":"Manhattan","Zone":"Gramercy","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":108,"Borough":"Brooklyn","Zone":"Gravesend","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":109,"Borough":"Staten Island","Zone":"Great Kills","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":110,"Borough":"Staten Island","Zone":"Great Kills Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":111,"Borough":"Brooklyn","Zone":"Green-Wood Cemetery","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":112,"Borough":"Brooklyn","Zone":"Greenpoint","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":113,"Borough":"Manhattan","Zone":"Greenwich Village North","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":114,"Borough":"Manhattan","Zone":"Greenwich Village South","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":115,"Borough":"Staten Island","Zone":"Grymes Hill/Clifton","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":116,"Borough":"Manhattan","Zone":"Hamilton Heights","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":117,"Borough":"Queens","Zone":"Hammels/Arverne","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":118,"Borough":"Staten Island","Zone":"Heartland Village/Todt Hill","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":119,"Borough":"Bronx","Zone":"Highbridge","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":120,"Borough":"Manhattan","Zone":"Highbridge Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":121,"Borough":"Queens","Zone":"Hillcrest/Pomonok","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":122,"Borough":"Queens","Zone":"Hollis","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":123,"Borough":"Brooklyn","Zone":"Homecrest","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":124,"Borough":"Queens","Zone":"Howard Beach","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":125,"Borough":"Manhattan","Zone":"Hudson Sq","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":126,"Borough":"Bronx","Zone":"Hunts Point","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":127,"Borough":"Manhattan","Zone":"Inwood","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":128,"Borough":"Manhattan","Zone":"Inwood Hill Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":129,"Borough":"Queens","Zone":"Jackson Heights","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":130,"Borough":"Queens","Zone":"Jamaica","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":131,"Borough":"Queens","Zone":"Jamaica Estates","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":132,"Borough":"Queens","Zone":"JFK Airport","ServiceZone":"Airports"})
        lookup_dict.append({"LocationId":133,"Borough":"Brooklyn","Zone":"Kensington","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":134,"Borough":"Queens","Zone":"Kew Gardens","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":135,"Borough":"Queens","Zone":"Kew Gardens Hills","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":136,"Borough":"Bronx","Zone":"Kingsbridge Heights","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":137,"Borough":"Manhattan","Zone":"Kips Bay","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":138,"Borough":"Queens","Zone":"LaGuardia Airport","ServiceZone":"Airports"})
        lookup_dict.append({"LocationId":139,"Borough":"Queens","Zone":"Laurelton","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":140,"Borough":"Manhattan","Zone":"Lenox Hill East","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":141,"Borough":"Manhattan","Zone":"Lenox Hill West","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":142,"Borough":"Manhattan","Zone":"Lincoln Square East","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":143,"Borough":"Manhattan","Zone":"Lincoln Square West","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":144,"Borough":"Manhattan","Zone":"Little Italy/NoLiTa","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":145,"Borough":"Queens","Zone":"Long Island City/Hunters Point","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":146,"Borough":"Queens","Zone":"Long Island City/Queens Plaza","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":147,"Borough":"Bronx","Zone":"Longwood","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":148,"Borough":"Manhattan","Zone":"Lower East Side","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":149,"Borough":"Brooklyn","Zone":"Madison","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":150,"Borough":"Brooklyn","Zone":"Manhattan Beach","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":151,"Borough":"Manhattan","Zone":"Manhattan Valley","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":152,"Borough":"Manhattan","Zone":"Manhattanville","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":153,"Borough":"Manhattan","Zone":"Marble Hill","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":154,"Borough":"Brooklyn","Zone":"Marine Park/Floyd Bennett Field","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":155,"Borough":"Brooklyn","Zone":"Marine Park/Mill Basin","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":156,"Borough":"Staten Island","Zone":"Mariners Harbor","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":157,"Borough":"Queens","Zone":"Maspeth","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":158,"Borough":"Manhattan","Zone":"Meatpacking/West Village West","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":159,"Borough":"Bronx","Zone":"Melrose South","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":160,"Borough":"Queens","Zone":"Middle Village","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":161,"Borough":"Manhattan","Zone":"Midtown Center","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":162,"Borough":"Manhattan","Zone":"Midtown East","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":163,"Borough":"Manhattan","Zone":"Midtown North","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":164,"Borough":"Manhattan","Zone":"Midtown South","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":165,"Borough":"Brooklyn","Zone":"Midwood","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":166,"Borough":"Manhattan","Zone":"Morningside Heights","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":167,"Borough":"Bronx","Zone":"Morrisania/Melrose","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":168,"Borough":"Bronx","Zone":"Mott Haven/Port Morris","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":169,"Borough":"Bronx","Zone":"Mount Hope","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":170,"Borough":"Manhattan","Zone":"Murray Hill","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":171,"Borough":"Queens","Zone":"Murray Hill-Queens","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":172,"Borough":"Staten Island","Zone":"New Dorp/Midland Beach","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":173,"Borough":"Queens","Zone":"North Corona","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":174,"Borough":"Bronx","Zone":"Norwood","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":175,"Borough":"Queens","Zone":"Oakland Gardens","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":176,"Borough":"Staten Island","Zone":"Oakwood","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":177,"Borough":"Brooklyn","Zone":"Ocean Hill","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":178,"Borough":"Brooklyn","Zone":"Ocean Parkway South","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":179,"Borough":"Queens","Zone":"Old Astoria","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":180,"Borough":"Queens","Zone":"Ozone Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":181,"Borough":"Brooklyn","Zone":"Park Slope","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":182,"Borough":"Bronx","Zone":"Parkchester","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":183,"Borough":"Bronx","Zone":"Pelham Bay","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":184,"Borough":"Bronx","Zone":"Pelham Bay Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":185,"Borough":"Bronx","Zone":"Pelham Parkway","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":186,"Borough":"Manhattan","Zone":"Penn Station/Madison Sq West","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":187,"Borough":"Staten Island","Zone":"Port Richmond","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":188,"Borough":"Brooklyn","Zone":"Prospect-Lefferts Gardens","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":189,"Borough":"Brooklyn","Zone":"Prospect Heights","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":190,"Borough":"Brooklyn","Zone":"Prospect Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":191,"Borough":"Queens","Zone":"Queens Village","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":192,"Borough":"Queens","Zone":"Queensboro Hill","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":193,"Borough":"Queens","Zone":"Queensbridge/Ravenswood","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":194,"Borough":"Manhattan","Zone":"Randalls Island","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":195,"Borough":"Brooklyn","Zone":"Red Hook","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":196,"Borough":"Queens","Zone":"Rego Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":197,"Borough":"Queens","Zone":"Richmond Hill","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":198,"Borough":"Queens","Zone":"Ridgewood","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":199,"Borough":"Bronx","Zone":"Rikers Island","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":200,"Borough":"Bronx","Zone":"Riverdale/North Riverdale/Fieldston","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":201,"Borough":"Queens","Zone":"Rockaway Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":202,"Borough":"Manhattan","Zone":"Roosevelt Island","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":203,"Borough":"Queens","Zone":"Rosedale","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":204,"Borough":"Staten Island","Zone":"Rossville/Woodrow","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":205,"Borough":"Queens","Zone":"Saint Albans","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":206,"Borough":"Staten Island","Zone":"Saint George/New Brighton","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":207,"Borough":"Queens","Zone":"Saint Michaels Cemetery/Woodside","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":208,"Borough":"Bronx","Zone":"Schuylerville/Edgewater Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":209,"Borough":"Manhattan","Zone":"Seaport","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":210,"Borough":"Brooklyn","Zone":"Sheepshead Bay","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":211,"Borough":"Manhattan","Zone":"SoHo","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":212,"Borough":"Bronx","Zone":"Soundview/Bruckner","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":213,"Borough":"Bronx","Zone":"Soundview/Castle Hill","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":214,"Borough":"Staten Island","Zone":"South Beach/Dongan Hills","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":215,"Borough":"Queens","Zone":"South Jamaica","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":216,"Borough":"Queens","Zone":"South Ozone Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":217,"Borough":"Brooklyn","Zone":"South Williamsburg","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":218,"Borough":"Queens","Zone":"Springfield Gardens North","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":219,"Borough":"Queens","Zone":"Springfield Gardens South","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":220,"Borough":"Bronx","Zone":"Spuyten Duyvil/Kingsbridge","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":221,"Borough":"Staten Island","Zone":"Stapleton","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":222,"Borough":"Brooklyn","Zone":"Starrett City","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":223,"Borough":"Queens","Zone":"Steinway","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":224,"Borough":"Manhattan","Zone":"Stuy Town/Peter Cooper Village","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":225,"Borough":"Brooklyn","Zone":"Stuyvesant Heights","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":226,"Borough":"Queens","Zone":"Sunnyside","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":227,"Borough":"Brooklyn","Zone":"Sunset Park East","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":228,"Borough":"Brooklyn","Zone":"Sunset Park West","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":229,"Borough":"Manhattan","Zone":"Sutton Place/Turtle Bay North","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":230,"Borough":"Manhattan","Zone":"Times Sq/Theatre District","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":231,"Borough":"Manhattan","Zone":"TriBeCa/Civic Center","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":232,"Borough":"Manhattan","Zone":"Two Bridges/Seward Park","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":233,"Borough":"Manhattan","Zone":"UN/Turtle Bay South","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":234,"Borough":"Manhattan","Zone":"Union Sq","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":235,"Borough":"Bronx","Zone":"University Heights/Morris Heights","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":236,"Borough":"Manhattan","Zone":"Upper East Side North","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":237,"Borough":"Manhattan","Zone":"Upper East Side South","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":238,"Borough":"Manhattan","Zone":"Upper West Side North","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":239,"Borough":"Manhattan","Zone":"Upper West Side South","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":240,"Borough":"Bronx","Zone":"Van Cortlandt Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":241,"Borough":"Bronx","Zone":"Van Cortlandt Village","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":242,"Borough":"Bronx","Zone":"Van Nest/Morris Park","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":243,"Borough":"Manhattan","Zone":"Washington Heights North","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":244,"Borough":"Manhattan","Zone":"Washington Heights South","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":245,"Borough":"Staten Island","Zone":"West Brighton","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":246,"Borough":"Manhattan","Zone":"West Chelsea/Hudson Yards","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":247,"Borough":"Bronx","Zone":"West Concourse","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":248,"Borough":"Bronx","Zone":"West Farms/Bronx River","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":249,"Borough":"Manhattan","Zone":"West Village","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":250,"Borough":"Bronx","Zone":"Westchester Village/Unionport","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":251,"Borough":"Staten Island","Zone":"Westerleigh","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":252,"Borough":"Queens","Zone":"Whitestone","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":253,"Borough":"Queens","Zone":"Willets Point","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":254,"Borough":"Bronx","Zone":"Williamsbridge/Olinville","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":255,"Borough":"Brooklyn","Zone":"Williamsburg (North Side)","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":256,"Borough":"Brooklyn","Zone":"Williamsburg (South Side)","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":257,"Borough":"Brooklyn","Zone":"Windsor Terrace","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":258,"Borough":"Queens","Zone":"Woodhaven","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":259,"Borough":"Bronx","Zone":"Woodlawn/Wakefield","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":260,"Borough":"Queens","Zone":"Woodside","ServiceZone":"Boro Zone"})
        lookup_dict.append({"LocationId":261,"Borough":"Manhattan","Zone":"World Trade Center","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":262,"Borough":"Manhattan","Zone":"Yorkville East","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":263,"Borough":"Manhattan","Zone":"Yorkville West","ServiceZone":"Yellow Zone"})
        lookup_dict.append({"LocationId":264,"Borough":"Unknown","Zone":"NV","ServiceZone":"N/A"})
        lookup_dict.append({"LocationId":265,"Borough":"Unknown","Zone":"NA","ServiceZone":"N/A"})
    except Exception as ex:
        print ("Exception (load_lookups): ", str(ex))
    print("END: load_lookups")
    return lookup_dict


@functions_framework.http
def extract_text_uri(request: flask.Request) -> flask.Response:
    try:
        project_id = os.environ['PROJECT_ID']
        region = os.environ['ENV_CLOUD_FUNCTION_REGION']
        client = SpeechClient(client_options=ClientOptions(api_endpoint=f"{region}-speech.googleapis.com"))
        config = cloud_speech.RecognitionConfig(
            auto_decoding_config=cloud_speech.AutoDetectDecodingConfig(),
            language_codes=["en-US"],
            model="chirp"
        )
        calls = request.get_json()['calls']
        replies = []
        for call in calls:
            uri=call[0]
            print("uri: ", uri)
            content = urllib.request.urlopen(uri).read()
            request = cloud_speech.RecognizeRequest(
                recognizer=f"projects/{project_id}/locations/{region}/recognizers/_",
                config=config,
                content=content)
            response = client.recognize(request=request)
            partial_result = ""
            for result in response.results:
                partial_result = partial_result + result.alternatives[0].transcript
            replies.append(partial_result)    
        return flask.make_response(flask.jsonify({'replies': replies}))
    except Exception as e:
        return flask.make_response(flask.jsonify({'errorMessage': str(e)}), 400)