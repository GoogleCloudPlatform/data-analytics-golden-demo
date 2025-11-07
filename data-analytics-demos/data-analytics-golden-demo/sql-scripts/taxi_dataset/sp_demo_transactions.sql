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
    - Transactions let you load your data safely during ETL/ELT jobs
    
Description: 
    - Show BiqQuery Tranasactions
    - BigQuery Transactions can run for 6 hours
    - BigQuery uses snapshot isolation
      - With snapshot isolation, all statements in a transaction only see the state of the tables as of the start of the transaction.
      - Each statement in a transaction also sees the changes that were made by previous statements in the same transaction.
      - In databases, and transaction processing (transaction management), snapshot isolation is a guarantee that all reads made in a transaction will see a consistent snapshot of the database (in practice it reads the last committed values that existed at the time it started), and the transaction itself will successfully commit only if no updates it has made conflict with any concurrent updates made since that snapshot.
      - BigQuery helps ensure optimistic concurrency control (first to commit wins) with snapshot isolation, in which a query reads the last committed data before the query starts. so basically the answer to the 1 hour long question is the query will read the data before the transaction which would delete all the data and then re-insert it
      - BigQuery is a multi-version database. Any transaction that modifies or adds rows to a table is ACID-compliant. BigQuery uses snapshot isolation to handle multiple concurrent operations on a table. Data manipulation language (DML) operations can be submitted to BigQuery by sending a query job containing the DML statement. When a job starts, BigQuery determines the snapshot timestamp to use to read the tables used in the query.

Reference:
    - https://cloud.google.com/bigquery/docs/reference/standard-sql/transactions

Clean up / Reset script:
    n/a
*/

BEGIN
BEGIN TRANSACTION;
  SELECT COUNT(*)
    FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips`;

  DELETE   
    FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips`
   WHERE Pickup_DateTime BETWEEN '2021-01-25'AND '2021-02-10';

  SELECT COUNT(*)
    FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips`;

  -- Trigger an error.
  SELECT 1/0;
  COMMIT TRANSACTION;

EXCEPTION WHEN ERROR THEN
  -- Roll back the transaction inside the exception handler.
  SELECT @@error.message;
  ROLLBACK TRANSACTION;
  SELECT COUNT(*)
    FROM `${project_id}.${bigquery_taxi_dataset}.taxi_trips`;
END;
