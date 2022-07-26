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
    - You need to encrypt data at the column level
    - You want to implement crypto-shredding
    - You want column level encryption with Cloud KMS

Description: 
    - Shows using Advanced Encryptoin with Additional Data (AEAD) for column level encrpytion
    - Shows using a table to store the keys with row level security to hide disabled/destroyed keys
    - Shows using Cloud KMS to encrypt the encryptoin key.  Extra layer of security.

Reference:
    - https://cloud.google.com/bigquery/docs/reference/standard-sql/aead_encryption_functions

Terms:
    - AEAD    - Authenticated encryption with associated data
              - AEAD encryption functions allow you to create keysets that contain keys for encryption and decryption, use these keys to encrypt and decrypt individual values in a table, and rotate keys within a keyset.
    - DEK     - data encryption key - used to encrypt and decrypt data
    - KEK     - key encryption key - used to encrypt and decrypt the DEK (this is done via Cloud KMS in this example)
    - KMS     - Key Management System - is the system that hosts the key management software (Cloud KMS)
    - Keysets - contain keys for encryption and decryption
    - Tink - Tink is an open-source cryptography library written by cryptographers and security engineers at Google
           - You can use Tink to encrypt data outside of BigQuery

Cloud KMS protection
    - BigQuery supports AEAD functions with Cloud KMS keys to further secure your data. 
      This additional layer of protection encrypts your data encryption key (DEK) with a key encryption key (KEK). 
      The KEK is a symmetric encryption keyset that is stored securely in the Cloud Key Management Service (KMS) and managed 
      using Identity and Access Management (IAM) roles and permissions.

    - At query execution time, use the KEYS.KEYSET_CHAIN function to provide the KMS resource path of the KEK and the 
      ciphertext from the wrapped DEK. BigQuery calls Cloud KMS to unwrap the DEK, and then uses that key to decrypt the 
      data in your query. The unwrapped version of the DEK is only stored in memory for the duration of the query, and then destroyed.

Notes:
    - Encrypting plaintext more than once using the same keyset will generally return different ciphertext values due to different initializ  ation vectors (IVs), which are chosen using the pseudo-random number generator provided by OpenSSL.
    - Users must have role roles/cloudkms.cryptoKeyDecrypter to decrypt data.  Not granting this role means they can never decrypt the data.
    - Your KMS should be in the same region/multi-region as BigQuery.
    - You should use parameterized queries to avoid keysets being logged.  If using KMS even if the key is logged it is still of little use.

Clean up / Reset script:
    DROP TABLE IF EXISTS  `${project_id}.${bigquery_taxi_dataset}.pii_customers`;
    DROP TABLE IF EXISTS  `${project_id}.${bigquery_taxi_dataset}.pii_taxi_trips`;
    DROP TABLE IF EXISTS  `${project_id}.${bigquery_taxi_dataset}.pii_customers_ahed_keys`;
    DROP TABLE IF EXISTS  `${project_id}.${bigquery_taxi_dataset}.pii_customers_tbl_approach`;
    DROP TABLE IF EXISTS  `${project_id}.${bigquery_taxi_dataset}.pii_taxi_trips_tbl_approach`;
    DROP TABLE IF EXISTS  `${project_id}.${bigquery_taxi_dataset}.pii_customers_kms_keys`;
    DROP TABLE IF EXISTS  `${project_id}.${bigquery_taxi_dataset}.pii_customers_kms_approach`;
    DROP ALL ROW ACCESS POLICIES ON `${project_id}.${bigquery_taxi_dataset}.pii_customers_ahed_keys`;

    You cannot delete your KMS entries.
    Do a search and replace (in this entire procedure) for "bq-aead" and replace with "bq-aead-1" or "bq-aead-2" (this will generate unique values)
*/

-- Scenerio:
-- Customer data is captured and customers are tracked
-- Customer driver license is captured
   -- Each customer trip is captured with the pickup and dropoff being protected fields
-- GDPR / customer privacy of this data needs to be implemented
-- Customers have the right to be forgotten

-- Set below (inline)
DECLARE keyset BYTES;

-- Geneate a customer table with sensitive data (base table for showing sensitive data)
CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.pii_customers` AS
SELECT element AS Customer_Id,
       CONCAT(CAST(ROUND(100 + RAND() * (100 - 1)) AS STRING) ,'-',
              CAST(ROUND(1000 + RAND() * (100 - 1)) AS STRING) ,'-',
              CAST(ROUND(1000 + RAND() * (100 - 1)) AS STRING)) AS Drivers_License_Number,
       CAST(CONCAT(CAST(ROUND(1975 + RAND() * (30 - 1)) AS STRING) ,'-',
                   CAST(ROUND(1 + RAND() * (12 - 1)) AS STRING) ,'-',
                   CAST(ROUND(1 + RAND() * (28 - 1)) AS STRING)) AS DATE) AS Customer_Date_Of_Birth,
       'Static Text' AS Static_Text
FROM UNNEST(GENERATE_ARRAY(1, 100)) AS element
ORDER BY element;

SELECT * FROM `${project_id}.${bigquery_taxi_dataset}.pii_customers`;


-- Generate some taxi trips with sensitive data - Strat tracking customer trips.
CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.pii_taxi_trips` AS
SELECT GENERATE_UUID() AS taxi_trip_id,
       CAST(ROUND(1 + RAND() * (100 - 1)) AS INT64) AS Customer_Id,
       TaxiCompany,		
       Vendor_Id,
       Pickup_DateTime,
       Dropoff_DateTime,
       PULocationID,
       DOLocationID,
       Total_Amount
  FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips`
WHERE PartitionDate = '2021-12-01' 
  AND Total_Amount > 0
LIMIT 20000;

SELECT * FROM `${project_id}.${bigquery_taxi_dataset}.pii_taxi_trips` ;


--------------------------------------------------------------------------------
-- A new law is passed and customers demand the data is protected
-- Customer drivers license and DOB need protecting
-- Customer demand the right to be forgotten for their Trips
-- NOTE: This is an example and not a certified legal approach
--------------------------------------------------------------------------------

-- **********************************************************
-- First approach - Keep the keys in a BigQuery table
-- **********************************************************

-- Create a table to hold the encryption keys per customer
-- Have logically deleted fields in the table so we can un-disable/delete the key (some places require recovering data for a specific period of time)
CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.pii_customers_ahed_keys` AS
SELECT element AS Customer_Id,
       KEYS.NEW_KEYSET('AEAD_AES_GCM_256') AS keyset,
       FALSE AS key_disabled,
       CAST(NULL AS DATE) AS key_disabled_date,  -- the date the key was disabled
       FALSE AS key_destroyed,
       CAST(NULL AS DATE) AS key_destroyed_date  -- the date the key wad requested to be shredded, we will really delete after {x} days of this date
FROM UNNEST(GENERATE_ARRAY(1, 100)) AS element
ORDER BY element;

SELECT * FROM `${project_id}.${bigquery_taxi_dataset}.pii_customers_ahed_keys`;


-- Encrypt the data per customer
CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.pii_customers_tbl_approach` AS
SELECT pii_customers.Customer_Id,
       AEAD.ENCRYPT(pii_customers_ahed_keys.keyset, pii_customers.Drivers_License_Number, CAST(pii_customers.Customer_Id AS STRING)) AS Encrypted_Drivers_License_Number,
       AEAD.ENCRYPT(pii_customers_ahed_keys.keyset, CAST(pii_customers.Customer_Date_Of_Birth AS STRING), CAST(pii_customers.Customer_Id AS STRING)) AS Encrypted_Customer_Date_Of_Birth,
       AEAD.ENCRYPT(pii_customers_ahed_keys.keyset, pii_customers.Static_Text, CAST(pii_customers.Customer_Id AS STRING)) AS Encrypted_Static_Text,
  FROM `${project_id}.${bigquery_taxi_dataset}.pii_customers` AS pii_customers
       INNER JOIN `${project_id}.${bigquery_taxi_dataset}.pii_customers_ahed_keys` AS pii_customers_ahed_keys
       ON pii_customers.Customer_Id = pii_customers_ahed_keys.Customer_Id;

-- NOTE: "Static Text"is encrypted to different values (non-deterministic)
SELECT * FROM `${project_id}.${bigquery_taxi_dataset}.pii_customers_tbl_approach`;


-- Encrypt the trip data
CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.pii_taxi_trips_tbl_approach` AS
SELECT pii_taxi_trips.taxi_trip_id,
       pii_taxi_trips.Customer_Id,
       pii_taxi_trips.TaxiCompany,
       pii_taxi_trips.Vendor_Id,
       pii_taxi_trips.Pickup_DateTime,
       pii_taxi_trips.Dropoff_DateTime,
       AEAD.ENCRYPT(pii_customers_ahed_keys.keyset, CAST(pii_taxi_trips.PULocationID AS STRING), CAST(pii_taxi_trips.Customer_Id AS STRING)) AS Encrypted_PULocationID,
       AEAD.ENCRYPT(pii_customers_ahed_keys.keyset, CAST(pii_taxi_trips.DOLocationID AS STRING), CAST(pii_taxi_trips.Customer_Id AS STRING)) AS Encrypted_DOLocationID,
       pii_taxi_trips.Total_Amount
  FROM `${project_id}.${bigquery_taxi_dataset}.pii_taxi_trips` AS pii_taxi_trips
       INNER JOIN `${project_id}.${bigquery_taxi_dataset}.pii_customers_ahed_keys` AS pii_customers_ahed_keys
       ON pii_taxi_trips.Customer_Id = pii_customers_ahed_keys.Customer_Id;

SELECT * FROM `${project_id}.${bigquery_taxi_dataset}.pii_taxi_trips_tbl_approach`;


-- Show how to un-encrypt data
-- NOTE: Users who cannot decrypt data will not have access to the keys table
SELECT pii_customers_tbl_approach.Customer_Id,
       AEAD.DECRYPT_STRING(pii_customers_ahed_keys.keyset,
                           pii_customers_tbl_approach.Encrypted_Drivers_License_Number,
                           CAST(pii_customers_tbl_approach.customer_id AS STRING) ) AS Drivers_License_Number,
       AEAD.DECRYPT_STRING(pii_customers_ahed_keys.keyset,
                           pii_customers_tbl_approach.Encrypted_Customer_Date_Of_Birth,
                           CAST(pii_customers_tbl_approach.customer_id AS STRING) ) AS Customer_Date_Of_Birth
 FROM `${project_id}.${bigquery_taxi_dataset}.pii_customers_tbl_approach` AS pii_customers_tbl_approach
      INNER JOIN `${project_id}.${bigquery_taxi_dataset}.pii_customers_ahed_keys` AS pii_customers_ahed_keys
              ON pii_customers_tbl_approach.Customer_Id = pii_customers_ahed_keys.Customer_Id;


-- NOTES: You can logically delete data in the pii_customers_ahed_keys
--        You can add row level filtering so that users do not have access (only admins can see/update the data)
UPDATE `${project_id}.${bigquery_taxi_dataset}.pii_customers_ahed_keys`
   SET key_disabled = TRUE
 WHERE Customer_Id <= 50;
 

-- Hide rows that are disabled or destroyed from users 
 CREATE OR REPLACE ROW ACCESS POLICY pii_customers_ahed_keys_rls
    ON `${project_id}.${bigquery_taxi_dataset}.pii_customers_ahed_keys`
    GRANT TO ("user:${gcp_account_name}") 
FILTER USING (key_disabled = FALSE AND key_destroyed = FALSE);


-- Try to un-delete Customer Id = 1 (should return nothing)
SELECT pii_customers_tbl_approach.Customer_Id,
       AEAD.DECRYPT_STRING(pii_customers_ahed_keys.keyset,
                           pii_customers_tbl_approach.Encrypted_Drivers_License_Number,
                           CAST(pii_customers_tbl_approach.customer_id AS STRING) ) AS Drivers_License_Number,
       AEAD.DECRYPT_STRING(pii_customers_ahed_keys.keyset,
                           pii_customers_tbl_approach.Encrypted_Customer_Date_Of_Birth,
                           CAST(pii_customers_tbl_approach.customer_id AS STRING) ) AS Customer_Date_Of_Birth
 FROM `${project_id}.${bigquery_taxi_dataset}.pii_customers_tbl_approach` AS pii_customers_tbl_approach
      INNER JOIN `${project_id}.${bigquery_taxi_dataset}.pii_customers_ahed_keys` AS pii_customers_ahed_keys
              ON pii_customers_tbl_approach.Customer_Id = pii_customers_ahed_keys.Customer_Id
             AND pii_customers_tbl_approach.Customer_Id = 1;


-- Drop the row level policy for next test
DROP ALL ROW ACCESS POLICIES ON `${project_id}.${bigquery_taxi_dataset}.pii_customers_ahed_keys`;


-- **********************************************************
-- Second approach - Now use Key Management (Cloud KMS) for the keys (not a table)
-- **********************************************************

-- The BigQuery function KEYS.NEW_KEYSET is used to generate a keyset
-- Cloud KMS is used to encrypt the encryption key.
-- The enveloped encrypted key is stored in this table.
-- This key is passed to KMS so that it can be decrypted in order to get the data encryption key
CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.pii_customers_kms_keys`
(
  Customer_Id INTEGER,
  keyset      STRING
);


/* 
# Run this in Cloud Shell
# https://cloud.google.com/sdk/gcloud/reference/kms/keys/create

project_id="${project_id}"
region="${bigquery_region}"
keyring_name="bq-key-ring"
key_name="bq-aead"
table_name="${project_id}:${bigquery_taxi_dataset}.pii_customers_kms_keys"

gcloud config set project $${project_id}

# Create a Key Ring and Key
gcloud kms keyrings create $${keyring_name} --location=$${region} --project=$${project_id}


for i in {1..5}
do
   echo "i: $${i}"
   gcloud kms keys create "$${key_name}-$${i}" --keyring=$${keyring_name} --location=$${region} --purpose=encryption --protection-level=software --project=$${project_id}

   # Generate the keyset (you would want to do this per customer)
   bq_result_json=$(bq --project_id=$${project_id} query --format=json --use_legacy_sql=false "SELECT KEYS.NEW_KEYSET('AEAD_AES_GCM_256') AS raw_keyset")
   echo "bq_result_json: $${bq_result_json}"

   # Get the raw keyset value
   raw_keyset=$(echo $${bq_result_json} | jq .[0].raw_keyset --raw-output)
   echo "raw_keyset: $${raw_keyset}"

   # Encode to base64
   echo $${raw_keyset} | base64 --decode > /tmp/raw_keyset_base_64

   # Encrypt the encrption key
   gcloud kms encrypt --plaintext-file=/tmp/raw_keyset_base_64 \
   --key="projects/$${project_id}/locations/$${region}/keyRings/$${keyring_name}/cryptoKeys/$${key_name}-$${i}" \
   --ciphertext-file=/tmp/raw_keyset_encrypted

   # Works on Linux (not Mac) so run in Cloud Shell
   # Not really needed, but shows how you can copy and paste the value into the BQ UI
   first_level_keyset=$(od -An --format=o1 /tmp/raw_keyset_encrypted |tr -d '\n'|tr ' ' '\\')
   echo "first_level_keyset=$${first_level_keyset}"

   # Better solution, place the value in a table (or secret store)
   first_level_keyset_base64=$(cat /tmp/raw_keyset_encrypted | base64 -w 0)
   echo "first_level_keyset_base64=$${first_level_keyset_base64}"

   # Place tke keyset in a BigQuery table so we can retreive it when running SQL
   echo "first_level_keyset_base64=$${first_level_keyset_base64}"
   echo "{ \"Customer_Id\": \"$${i}\", \"keyset\": \"$${first_level_keyset_base64}\" }" | bq insert $${table_name}
done

*/

-- Encrypt the data per customer (You must HIGHLIGHT the DECLARE for running inline)
-- DECLARE keyset BYTES DEFAULT (SELECT FROM_BASE64(keyset) FROM `${bigquery_taxi_dataset}.pii_customers_kms_keys` WHERE Customer_Id = 1);
CREATE OR REPLACE TABLE `${project_id}.${bigquery_taxi_dataset}.pii_customers_kms_approach` AS
SELECT pii_customers.Customer_Id,
       AEAD.ENCRYPT(KEYS.KEYSET_CHAIN('gcp-kms://projects/${project_id}/locations/us/keyRings/bq-key-ring/cryptoKeys/bq-aead-1',keyset), 
                    pii_customers.Drivers_License_Number,
                    CAST(customer_id AS STRING)) AS Encrypted_Drivers_License_Number,
       AEAD.ENCRYPT(KEYS.KEYSET_CHAIN('gcp-kms://projects/${project_id}/locations/us/keyRings/bq-key-ring/cryptoKeys/bq-aead-1',keyset), 
                    CAST(pii_customers.Customer_Date_Of_Birth AS STRING),
                    CAST(customer_id AS STRING)) AS Encrypted_Customer_Date_Of_Birth,
       AEAD.ENCRYPT(KEYS.KEYSET_CHAIN('gcp-kms://projects/${project_id}/locations/us/keyRings/bq-key-ring/cryptoKeys/bq-aead-1',keyset), 
                    pii_customers.Static_Text,
                    CAST(customer_id AS STRING)) AS Encrypted_Static_Text
  FROM `${project_id}.${bigquery_taxi_dataset}.pii_customers` AS pii_customers
WHERE pii_customers.Customer_Id = 1;


-- Decrypt the data per customer (You must HIGHLIGHT the DECLARE for running inline)
-- DECLARE keyset BYTES DEFAULT (SELECT FROM_BASE64(keyset) FROM `${bigquery_taxi_dataset}.pii_customers_kms_keys` WHERE Customer_Id = 1);
SELECT pii_customers_kms_approach.Customer_Id,
       AEAD.DECRYPT_STRING(KEYS.KEYSET_CHAIN('gcp-kms://projects/${project_id}/locations/us/keyRings/bq-key-ring/cryptoKeys/bq-aead-1',keyset), 
                           pii_customers_kms_approach.Encrypted_Drivers_License_Number,
                           CAST(pii_customers_kms_approach.Customer_id AS STRING)) AS Drivers_License_Number,
       AEAD.DECRYPT_STRING(KEYS.KEYSET_CHAIN('gcp-kms://projects/${project_id}/locations/us/keyRings/bq-key-ring/cryptoKeys/bq-aead-1',keyset), 
                           pii_customers_kms_approach.Encrypted_Customer_Date_Of_Birth,
                           CAST(pii_customers_kms_approach.Customer_id AS STRING)) AS Customer_Date_Of_Birth,
       AEAD.DECRYPT_STRING(KEYS.KEYSET_CHAIN('gcp-kms://projects/${project_id}/locations/us/keyRings/bq-key-ring/cryptoKeys/bq-aead-1',keyset), 
                           pii_customers_kms_approach.Encrypted_Static_Text,
                           CAST(pii_customers_kms_approach.Customer_id AS STRING)) AS Static_Text
  FROM `${project_id}.${bigquery_taxi_dataset}.pii_customers_kms_approach` AS pii_customers_kms_approach
WHERE pii_customers_kms_approach.Customer_Id = 1;


-- Go over to KMS and disable or destroy the key "bq-aead-1"
-- NOTE: You will need to turn off cached query results and wait a few minutes 

-- Decrypt the data per customer (You must HIGHLIGHT the DECLARE for running inline)
-- DECLARE keyset BYTES DEFAULT (SELECT FROM_BASE64(keyset) FROM `${bigquery_taxi_dataset}.pii_customers_kms_keys` WHERE Customer_Id = 1);
SELECT pii_customers_kms_approach.Customer_Id,
       AEAD.DECRYPT_STRING(KEYS.KEYSET_CHAIN('gcp-kms://projects/${project_id}/locations/us/keyRings/bq-key-ring/cryptoKeys/bq-aead-1',keyset), 
                           pii_customers_kms_approach.Encrypted_Drivers_License_Number,
                           CAST(pii_customers_kms_approach.Customer_id AS STRING)) AS Drivers_License_Number,
       AEAD.DECRYPT_STRING(KEYS.KEYSET_CHAIN('gcp-kms://projects/${project_id}/locations/us/keyRings/bq-key-ring/cryptoKeys/bq-aead-1',keyset), 
                           pii_customers_kms_approach.Encrypted_Customer_Date_Of_Birth,
                           CAST(pii_customers_kms_approach.Customer_id AS STRING)) AS Customer_Date_Of_Birth,
       AEAD.DECRYPT_STRING(KEYS.KEYSET_CHAIN('gcp-kms://projects/${project_id}/locations/us/keyRings/bq-key-ring/cryptoKeys/bq-aead-1',keyset), 
                           pii_customers_kms_approach.Encrypted_Static_Text,
                           CAST(pii_customers_kms_approach.Customer_id AS STRING)) AS Static_Text
  FROM `${project_id}.${bigquery_taxi_dataset}.pii_customers_kms_approach` AS pii_customers_kms_approach
WHERE pii_customers_kms_approach.Customer_Id = 1;


