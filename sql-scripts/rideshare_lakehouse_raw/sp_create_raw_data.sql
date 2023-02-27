 /*##################################################################################
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
  ###################################################################################*/
  
  
  /*
  Use Cases:
      - Export existing data as raw data for loading into the raw zone.  BigQuery can export, CVS, Json, Orc, Parquet, etc.
  
  Description: 
      - Export data with different formats
  
  Reference:
      - SQL EXPORT command: https://cloud.google.com/bigquery/docs/reference/standard-sql/other-statements#export_data_statement
      - Command Line: https://cloud.google.com/bigquery/docs/bq-command-line-tool#loading_data
  
  Clean up / Reset script:
      -  n/a      
  */
  

-- Export Taxi Trips Data (parquet)
EXPORT DATA
  OPTIONS (
    uri = 'gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_trip/parquet/*.parquet',
    format = 'PARQUET',
    overwrite = true)
AS (
  SELECT GENERATE_UUID() AS rideshare_trip_id,
         PULocationID AS pickup_location_id,
         Pickup_DateTime AS pickup_datetime,
         DOLocationID	AS dropoff_location_id,
         Dropoff_DateTime AS dropoff_datetime,

         Trip_Distance AS ride_distance,

         CASE WHEN Rate_Code_Id = 2 OR Rate_Code_Id = 3 
              THEN TRUE
              ELSE FALSE
         END AS is_airport,

         Payment_Type_Id AS payment_type_id,

         Fare_Amount AS fare_amount,
         Tip_Amount AS tip_amount,
         IFNULL(Surcharge,0) +
                IFNULL(MTA_Tax,0) +
                IFNULL(Tolls_Amount,0) +
                IFNULL(Improvement_Surcharge,0) +
                IFNULL(Congestion_Surcharge,0) +
                IFNULL(Ehail_Fee,0) AS taxes_amount,
         Total_Amount AS total_amount,

         PartitionDate AS partition_date
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips`
  WHERE PartitionDate >= '2022-01-01'
);

-- Export Taxi Trips Data (avro)
EXPORT DATA
  OPTIONS (
    uri = 'gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_trip/avro/*.avro',
    format = 'AVRO',
    overwrite = true)
AS (
  SELECT GENERATE_UUID() AS rideshare_trip_id,
         PULocationID AS pickup_location_id,
         Pickup_DateTime AS pickup_datetime,
         DOLocationID	AS dropoff_location_id,
         Dropoff_DateTime AS dropoff_datetime,

         Trip_Distance AS ride_distance,

         CASE WHEN Rate_Code_Id = 2 OR Rate_Code_Id = 3 
              THEN TRUE
              ELSE FALSE
         END AS is_airport,

         Payment_Type_Id AS payment_type_id,

         Fare_Amount AS fare_amount,
         Tip_Amount AS tip_amount,
         IFNULL(Surcharge,0) +
                IFNULL(MTA_Tax,0) +
                IFNULL(Tolls_Amount,0) +
                IFNULL(Improvement_Surcharge,0) +
                IFNULL(Congestion_Surcharge,0) +
                IFNULL(Ehail_Fee,0) AS taxes_amount,
         Total_Amount AS total_amount,

         PartitionDate AS partition_date
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips`
  WHERE PartitionDate >= '2021-01-01' AND PartitionDate < '2022-01-01'
);


-- Export Taxi Trips Data (json)
EXPORT DATA
  OPTIONS (
    uri = 'gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_trip/json/*.json',
    format = 'JSON',
    overwrite = true)
AS (
  SELECT GENERATE_UUID() AS rideshare_trip_id,
         PULocationID AS pickup_location_id,
         Pickup_DateTime AS pickup_datetime,
         DOLocationID	AS dropoff_location_id,
         Dropoff_DateTime AS dropoff_datetime,

         Trip_Distance AS ride_distance,

         CASE WHEN Rate_Code_Id = 2 OR Rate_Code_Id = 3 
              THEN TRUE
              ELSE FALSE
         END AS is_airport,

         Payment_Type_Id AS payment_type_id,

         Fare_Amount AS fare_amount,
         Tip_Amount AS tip_amount,
         IFNULL(Surcharge,0) +
                IFNULL(MTA_Tax,0) +
                IFNULL(Tolls_Amount,0) +
                IFNULL(Improvement_Surcharge,0) +
                IFNULL(Congestion_Surcharge,0) +
                IFNULL(Ehail_Fee,0) AS taxes_amount,
         Total_Amount AS total_amount,

         PartitionDate AS partition_date
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips`
  WHERE PartitionDate >= '2020-01-01' AND PartitionDate < '2021-01-01'
);


-- Export Payment Type
EXPORT DATA
  OPTIONS (
    uri = 'gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_payment_type/*.json',
    format = 'JSON',
    overwrite = true)
AS (
  SELECT Payment_Type_Id AS payment_type_id,
         Payment_Type_Description AS payment_type_description
  FROM `${project_id}.${bigquery_taxi_dataset}.payment_type`
);

-- Export Rideshare Zones
EXPORT DATA
  OPTIONS (
    uri = 'gs://${gcs_rideshare_lakehouse_raw_bucket}/rideshare_zone/*.csv',
    format = 'CSV',
    overwrite = true,
    header = true,
    field_delimiter = '|')
AS (
  SELECT 1 AS location_id,'EWR' AS borough,'Newark Airport' AS zone,'EWR' AS service_zone UNION ALL
  SELECT 2 AS location_id,'Queens' AS borough,'Jamaica Bay' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 3 AS location_id,'Bronx' AS borough,'Allerton/Pelham Gardens' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 4 AS location_id,'Manhattan' AS borough,'Alphabet City' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 5 AS location_id,'Staten Island' AS borough,'Arden Heights' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 6 AS location_id,'Staten Island' AS borough,'Arrochar/Fort Wadsworth' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 7 AS location_id,'Queens' AS borough,'Astoria' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 8 AS location_id,'Queens' AS borough,'Astoria Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 9 AS location_id,'Queens' AS borough,'Auburndale' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 10 AS location_id,'Queens' AS borough,'Baisley Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 11 AS location_id,'Brooklyn' AS borough,'Bath Beach' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 12 AS location_id,'Manhattan' AS borough,'Battery Park' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 13 AS location_id,'Manhattan' AS borough,'Battery Park City' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 14 AS location_id,'Brooklyn' AS borough,'Bay Ridge' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 15 AS location_id,'Queens' AS borough,'Bay Terrace/Fort Totten' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 16 AS location_id,'Queens' AS borough,'Bayside' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 17 AS location_id,'Brooklyn' AS borough,'Bedford' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 18 AS location_id,'Bronx' AS borough,'Bedford Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 19 AS location_id,'Queens' AS borough,'Bellerose' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 20 AS location_id,'Bronx' AS borough,'Belmont' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 21 AS location_id,'Brooklyn' AS borough,'Bensonhurst East' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 22 AS location_id,'Brooklyn' AS borough,'Bensonhurst West' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 23 AS location_id,'Staten Island' AS borough,'Bloomfield/Emerson Hill' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 24 AS location_id,'Manhattan' AS borough,'Bloomingdale' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 25 AS location_id,'Brooklyn' AS borough,'Boerum Hill' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 26 AS location_id,'Brooklyn' AS borough,'Borough Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 27 AS location_id,'Queens' AS borough,'Breezy Point/Fort Tilden/Riis Beach' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 28 AS location_id,'Queens' AS borough,'Briarwood/Jamaica Hills' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 29 AS location_id,'Brooklyn' AS borough,'Brighton Beach' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 30 AS location_id,'Queens' AS borough,'Broad Channel' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 31 AS location_id,'Bronx' AS borough,'Bronx Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 32 AS location_id,'Bronx' AS borough,'Bronxdale' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 33 AS location_id,'Brooklyn' AS borough,'Brooklyn Heights' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 34 AS location_id,'Brooklyn' AS borough,'Brooklyn Navy Yard' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 35 AS location_id,'Brooklyn' AS borough,'Brownsville' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 36 AS location_id,'Brooklyn' AS borough,'Bushwick North' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 37 AS location_id,'Brooklyn' AS borough,'Bushwick South' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 38 AS location_id,'Queens' AS borough,'Cambria Heights' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 39 AS location_id,'Brooklyn' AS borough,'Canarsie' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 40 AS location_id,'Brooklyn' AS borough,'Carroll Gardens' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 41 AS location_id,'Manhattan' AS borough,'Central Harlem' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 42 AS location_id,'Manhattan' AS borough,'Central Harlem North' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 43 AS location_id,'Manhattan' AS borough,'Central Park' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 44 AS location_id,'Staten Island' AS borough,'Charleston/Tottenville' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 45 AS location_id,'Manhattan' AS borough,'Chinatown' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 46 AS location_id,'Bronx' AS borough,'City Island' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 47 AS location_id,'Bronx' AS borough,'Claremont/Bathgate' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 48 AS location_id,'Manhattan' AS borough,'Clinton East' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 49 AS location_id,'Brooklyn' AS borough,'Clinton Hill' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 50 AS location_id,'Manhattan' AS borough,'Clinton West' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 51 AS location_id,'Bronx' AS borough,'Co-Op City' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 52 AS location_id,'Brooklyn' AS borough,'Cobble Hill' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 53 AS location_id,'Queens' AS borough,'College Point' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 54 AS location_id,'Brooklyn' AS borough,'Columbia Street' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 55 AS location_id,'Brooklyn' AS borough,'Coney Island' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 56 AS location_id,'Queens' AS borough,'Corona' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 57 AS location_id,'Queens' AS borough,'Corona' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 58 AS location_id,'Bronx' AS borough,'Country Club' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 59 AS location_id,'Bronx' AS borough,'Crotona Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 60 AS location_id,'Bronx' AS borough,'Crotona Park East' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 61 AS location_id,'Brooklyn' AS borough,'Crown Heights North' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 62 AS location_id,'Brooklyn' AS borough,'Crown Heights South' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 63 AS location_id,'Brooklyn' AS borough,'Cypress Hills' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 64 AS location_id,'Queens' AS borough,'Douglaston' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 65 AS location_id,'Brooklyn' AS borough,'Downtown Brooklyn/MetroTech' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 66 AS location_id,'Brooklyn' AS borough,'DUMBO/Vinegar Hill' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 67 AS location_id,'Brooklyn' AS borough,'Dyker Heights' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 68 AS location_id,'Manhattan' AS borough,'East Chelsea' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 69 AS location_id,'Bronx' AS borough,'East Concourse/Concourse Village' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 70 AS location_id,'Queens' AS borough,'East Elmhurst' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 71 AS location_id,'Brooklyn' AS borough,'East Flatbush/Farragut' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 72 AS location_id,'Brooklyn' AS borough,'East Flatbush/Remsen Village' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 73 AS location_id,'Queens' AS borough,'East Flushing' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 74 AS location_id,'Manhattan' AS borough,'East Harlem North' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 75 AS location_id,'Manhattan' AS borough,'East Harlem South' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 76 AS location_id,'Brooklyn' AS borough,'East New York' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 77 AS location_id,'Brooklyn' AS borough,'East New York/Pennsylvania Avenue' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 78 AS location_id,'Bronx' AS borough,'East Tremont' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 79 AS location_id,'Manhattan' AS borough,'East Village' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 80 AS location_id,'Brooklyn' AS borough,'East Williamsburg' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 81 AS location_id,'Bronx' AS borough,'Eastchester' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 82 AS location_id,'Queens' AS borough,'Elmhurst' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 83 AS location_id,'Queens' AS borough,'Elmhurst/Maspeth' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 84 AS location_id,'Staten Island' AS borough,'Eltingville/Annadale/Princes Bay' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 85 AS location_id,'Brooklyn' AS borough,'Erasmus' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 86 AS location_id,'Queens' AS borough,'Far Rockaway' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 87 AS location_id,'Manhattan' AS borough,'Financial District North' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 88 AS location_id,'Manhattan' AS borough,'Financial District South' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 89 AS location_id,'Brooklyn' AS borough,'Flatbush/Ditmas Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 90 AS location_id,'Manhattan' AS borough,'Flatiron' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 91 AS location_id,'Brooklyn' AS borough,'Flatlands' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 92 AS location_id,'Queens' AS borough,'Flushing' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 93 AS location_id,'Queens' AS borough,'Flushing Meadows-Corona Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 94 AS location_id,'Bronx' AS borough,'Fordham South' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 95 AS location_id,'Queens' AS borough,'Forest Hills' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 96 AS location_id,'Queens' AS borough,'Forest Park/Highland Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 97 AS location_id,'Brooklyn' AS borough,'Fort Greene' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 98 AS location_id,'Queens' AS borough,'Fresh Meadows' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 99 AS location_id,'Staten Island' AS borough,'Freshkills Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 100 AS location_id,'Manhattan' AS borough,'Garment District' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 101 AS location_id,'Queens' AS borough,'Glen Oaks' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 102 AS location_id,'Queens' AS borough,'Glendale' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 103 AS location_id,'Manhattan' AS borough,'Governors Island/Ellis Island/Liberty Island' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 104 AS location_id,'Manhattan' AS borough,'Governors Island/Ellis Island/Liberty Island' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 105 AS location_id,'Manhattan' AS borough,'Governors Island/Ellis Island/Liberty Island' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 106 AS location_id,'Brooklyn' AS borough,'Gowanus' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 107 AS location_id,'Manhattan' AS borough,'Gramercy' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 108 AS location_id,'Brooklyn' AS borough,'Gravesend' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 109 AS location_id,'Staten Island' AS borough,'Great Kills' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 110 AS location_id,'Staten Island' AS borough,'Great Kills Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 111 AS location_id,'Brooklyn' AS borough,'Green-Wood Cemetery' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 112 AS location_id,'Brooklyn' AS borough,'Greenpoint' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 113 AS location_id,'Manhattan' AS borough,'Greenwich Village North' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 114 AS location_id,'Manhattan' AS borough,'Greenwich Village South' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 115 AS location_id,'Staten Island' AS borough,'Grymes Hill/Clifton' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 116 AS location_id,'Manhattan' AS borough,'Hamilton Heights' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 117 AS location_id,'Queens' AS borough,'Hammels/Arverne' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 118 AS location_id,'Staten Island' AS borough,'Heartland Village/Todt Hill' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 119 AS location_id,'Bronx' AS borough,'Highbridge' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 120 AS location_id,'Manhattan' AS borough,'Highbridge Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 121 AS location_id,'Queens' AS borough,'Hillcrest/Pomonok' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 122 AS location_id,'Queens' AS borough,'Hollis' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 123 AS location_id,'Brooklyn' AS borough,'Homecrest' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 124 AS location_id,'Queens' AS borough,'Howard Beach' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 125 AS location_id,'Manhattan' AS borough,'Hudson Sq' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 126 AS location_id,'Bronx' AS borough,'Hunts Point' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 127 AS location_id,'Manhattan' AS borough,'Inwood' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 128 AS location_id,'Manhattan' AS borough,'Inwood Hill Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 129 AS location_id,'Queens' AS borough,'Jackson Heights' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 130 AS location_id,'Queens' AS borough,'Jamaica' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 131 AS location_id,'Queens' AS borough,'Jamaica Estates' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 132 AS location_id,'Queens' AS borough,'JFK Airport' AS zone,'Airports' AS service_zone UNION ALL
  SELECT 133 AS location_id,'Brooklyn' AS borough,'Kensington' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 134 AS location_id,'Queens' AS borough,'Kew Gardens' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 135 AS location_id,'Queens' AS borough,'Kew Gardens Hills' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 136 AS location_id,'Bronx' AS borough,'Kingsbridge Heights' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 137 AS location_id,'Manhattan' AS borough,'Kips Bay' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 138 AS location_id,'Queens' AS borough,'LaGuardia Airport' AS zone,'Airports' AS service_zone UNION ALL
  SELECT 139 AS location_id,'Queens' AS borough,'Laurelton' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 140 AS location_id,'Manhattan' AS borough,'Lenox Hill East' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 141 AS location_id,'Manhattan' AS borough,'Lenox Hill West' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 142 AS location_id,'Manhattan' AS borough,'Lincoln Square East' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 143 AS location_id,'Manhattan' AS borough,'Lincoln Square West' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 144 AS location_id,'Manhattan' AS borough,'Little Italy/NoLiTa' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 145 AS location_id,'Queens' AS borough,'Long Island City/Hunters Point' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 146 AS location_id,'Queens' AS borough,'Long Island City/Queens Plaza' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 147 AS location_id,'Bronx' AS borough,'Longwood' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 148 AS location_id,'Manhattan' AS borough,'Lower East Side' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 149 AS location_id,'Brooklyn' AS borough,'Madison' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 150 AS location_id,'Brooklyn' AS borough,'Manhattan Beach' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 151 AS location_id,'Manhattan' AS borough,'Manhattan Valley' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 152 AS location_id,'Manhattan' AS borough,'Manhattanville' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 153 AS location_id,'Manhattan' AS borough,'Marble Hill' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 154 AS location_id,'Brooklyn' AS borough,'Marine Park/Floyd Bennett Field' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 155 AS location_id,'Brooklyn' AS borough,'Marine Park/Mill Basin' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 156 AS location_id,'Staten Island' AS borough,'Mariners Harbor' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 157 AS location_id,'Queens' AS borough,'Maspeth' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 158 AS location_id,'Manhattan' AS borough,'Meatpacking/West Village West' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 159 AS location_id,'Bronx' AS borough,'Melrose South' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 160 AS location_id,'Queens' AS borough,'Middle Village' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 161 AS location_id,'Manhattan' AS borough,'Midtown Center' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 162 AS location_id,'Manhattan' AS borough,'Midtown East' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 163 AS location_id,'Manhattan' AS borough,'Midtown North' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 164 AS location_id,'Manhattan' AS borough,'Midtown South' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 165 AS location_id,'Brooklyn' AS borough,'Midwood' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 166 AS location_id,'Manhattan' AS borough,'Morningside Heights' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 167 AS location_id,'Bronx' AS borough,'Morrisania/Melrose' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 168 AS location_id,'Bronx' AS borough,'Mott Haven/Port Morris' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 169 AS location_id,'Bronx' AS borough,'Mount Hope' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 170 AS location_id,'Manhattan' AS borough,'Murray Hill' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 171 AS location_id,'Queens' AS borough,'Murray Hill-Queens' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 172 AS location_id,'Staten Island' AS borough,'New Dorp/Midland Beach' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 173 AS location_id,'Queens' AS borough,'North Corona' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 174 AS location_id,'Bronx' AS borough,'Norwood' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 175 AS location_id,'Queens' AS borough,'Oakland Gardens' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 176 AS location_id,'Staten Island' AS borough,'Oakwood' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 177 AS location_id,'Brooklyn' AS borough,'Ocean Hill' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 178 AS location_id,'Brooklyn' AS borough,'Ocean Parkway South' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 179 AS location_id,'Queens' AS borough,'Old Astoria' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 180 AS location_id,'Queens' AS borough,'Ozone Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 181 AS location_id,'Brooklyn' AS borough,'Park Slope' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 182 AS location_id,'Bronx' AS borough,'Parkchester' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 183 AS location_id,'Bronx' AS borough,'Pelham Bay' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 184 AS location_id,'Bronx' AS borough,'Pelham Bay Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 185 AS location_id,'Bronx' AS borough,'Pelham Parkway' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 186 AS location_id,'Manhattan' AS borough,'Penn Station/Madison Sq West' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 187 AS location_id,'Staten Island' AS borough,'Port Richmond' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 188 AS location_id,'Brooklyn' AS borough,'Prospect-Lefferts Gardens' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 189 AS location_id,'Brooklyn' AS borough,'Prospect Heights' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 190 AS location_id,'Brooklyn' AS borough,'Prospect Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 191 AS location_id,'Queens' AS borough,'Queens Village' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 192 AS location_id,'Queens' AS borough,'Queensboro Hill' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 193 AS location_id,'Queens' AS borough,'Queensbridge/Ravenswood' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 194 AS location_id,'Manhattan' AS borough,'Randalls Island' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 195 AS location_id,'Brooklyn' AS borough,'Red Hook' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 196 AS location_id,'Queens' AS borough,'Rego Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 197 AS location_id,'Queens' AS borough,'Richmond Hill' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 198 AS location_id,'Queens' AS borough,'Ridgewood' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 199 AS location_id,'Bronx' AS borough,'Rikers Island' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 200 AS location_id,'Bronx' AS borough,'Riverdale/North Riverdale/Fieldston' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 201 AS location_id,'Queens' AS borough,'Rockaway Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 202 AS location_id,'Manhattan' AS borough,'Roosevelt Island' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 203 AS location_id,'Queens' AS borough,'Rosedale' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 204 AS location_id,'Staten Island' AS borough,'Rossville/Woodrow' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 205 AS location_id,'Queens' AS borough,'Saint Albans' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 206 AS location_id,'Staten Island' AS borough,'Saint George/New Brighton' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 207 AS location_id,'Queens' AS borough,'Saint Michaels Cemetery/Woodside' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 208 AS location_id,'Bronx' AS borough,'Schuylerville/Edgewater Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 209 AS location_id,'Manhattan' AS borough,'Seaport' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 210 AS location_id,'Brooklyn' AS borough,'Sheepshead Bay' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 211 AS location_id,'Manhattan' AS borough,'SoHo' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 212 AS location_id,'Bronx' AS borough,'Soundview/Bruckner' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 213 AS location_id,'Bronx' AS borough,'Soundview/Castle Hill' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 214 AS location_id,'Staten Island' AS borough,'South Beach/Dongan Hills' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 215 AS location_id,'Queens' AS borough,'South Jamaica' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 216 AS location_id,'Queens' AS borough,'South Ozone Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 217 AS location_id,'Brooklyn' AS borough,'South Williamsburg' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 218 AS location_id,'Queens' AS borough,'Springfield Gardens North' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 219 AS location_id,'Queens' AS borough,'Springfield Gardens South' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 220 AS location_id,'Bronx' AS borough,'Spuyten Duyvil/Kingsbridge' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 221 AS location_id,'Staten Island' AS borough,'Stapleton' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 222 AS location_id,'Brooklyn' AS borough,'Starrett City' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 223 AS location_id,'Queens' AS borough,'Steinway' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 224 AS location_id,'Manhattan' AS borough,'Stuy Town/Peter Cooper Village' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 225 AS location_id,'Brooklyn' AS borough,'Stuyvesant Heights' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 226 AS location_id,'Queens' AS borough,'Sunnyside' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 227 AS location_id,'Brooklyn' AS borough,'Sunset Park East' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 228 AS location_id,'Brooklyn' AS borough,'Sunset Park West' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 229 AS location_id,'Manhattan' AS borough,'Sutton Place/Turtle Bay North' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 230 AS location_id,'Manhattan' AS borough,'Times Sq/Theatre District' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 231 AS location_id,'Manhattan' AS borough,'TriBeCa/Civic Center' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 232 AS location_id,'Manhattan' AS borough,'Two Bridges/Seward Park' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 233 AS location_id,'Manhattan' AS borough,'UN/Turtle Bay South' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 234 AS location_id,'Manhattan' AS borough,'Union Sq' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 235 AS location_id,'Bronx' AS borough,'University Heights/Morris Heights' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 236 AS location_id,'Manhattan' AS borough,'Upper East Side North' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 237 AS location_id,'Manhattan' AS borough,'Upper East Side South' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 238 AS location_id,'Manhattan' AS borough,'Upper West Side North' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 239 AS location_id,'Manhattan' AS borough,'Upper West Side South' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 240 AS location_id,'Bronx' AS borough,'Van Cortlandt Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 241 AS location_id,'Bronx' AS borough,'Van Cortlandt Village' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 242 AS location_id,'Bronx' AS borough,'Van Nest/Morris Park' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 243 AS location_id,'Manhattan' AS borough,'Washington Heights North' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 244 AS location_id,'Manhattan' AS borough,'Washington Heights South' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 245 AS location_id,'Staten Island' AS borough,'West Brighton' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 246 AS location_id,'Manhattan' AS borough,'West Chelsea/Hudson Yards' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 247 AS location_id,'Bronx' AS borough,'West Concourse' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 248 AS location_id,'Bronx' AS borough,'West Farms/Bronx River' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 249 AS location_id,'Manhattan' AS borough,'West Village' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 250 AS location_id,'Bronx' AS borough,'Westchester Village/Unionport' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 251 AS location_id,'Staten Island' AS borough,'Westerleigh' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 252 AS location_id,'Queens' AS borough,'Whitestone' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 253 AS location_id,'Queens' AS borough,'Willets Point' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 254 AS location_id,'Bronx' AS borough,'Williamsbridge/Olinville' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 255 AS location_id,'Brooklyn' AS borough,'Williamsburg (North Side)' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 256 AS location_id,'Brooklyn' AS borough,'Williamsburg (South Side)' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 257 AS location_id,'Brooklyn' AS borough,'Windsor Terrace' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 258 AS location_id,'Queens' AS borough,'Woodhaven' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 259 AS location_id,'Bronx' AS borough,'Woodlawn/Wakefield' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 260 AS location_id,'Queens' AS borough,'Woodside' AS zone,'Boro Zone' AS service_zone UNION ALL
  SELECT 261 AS location_id,'Manhattan' AS borough,'World Trade Center' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 262 AS location_id,'Manhattan' AS borough,'Yorkville East' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 263 AS location_id,'Manhattan' AS borough,'Yorkville West' AS zone,'Yellow Zone' AS service_zone UNION ALL
  SELECT 264 AS location_id,'Unknown' AS borough,'NV' AS zone,'N/A' AS service_zone UNION ALL
  SELECT 265 AS location_id,'Unknown' AS borough,'NA' AS zone,'N/A' AS service_zone
);
