CREATE OR REPLACE TABLE `${project_id}.${bigquery_governed_data_enriched_dataset}.customer` 
CLUSTER BY customer_id
AS
WITH random_credit_card AS 
(
  SELECT customer_id, 
         CAST(ROUND(1 + RAND() * (4 - 1)) AS INT64) as fake_credit_card_random
    FROM `${project_id}.${bigquery_governed_data_raw_dataset}.customer`

)
SELECT customer.customer_id, 
       customer.first_name, 
       customer.last_name, 
       customer.email, 
       CONCAT(SUBSTRING(customer.phone,1,5), ' ', SUBSTRING(customer.phone,7,3), '-', SUBSTRING(customer.phone,10,4)) AS phone, 
       CASE WHEN customer.gender = 'Male'   THEN 'M'
            WHEN customer.gender = 'Female' THEN 'F'
            ELSE 'U'
       END as gender,
       customer.ip_address, 
       customer.ssn, 
       customer.address, 
       customer.city, 
       customer.state, 
       customer.zip,
       CASE random_credit_card.fake_credit_card_random
            WHEN 1 THEN '371449635398431' -- American Express test number
            WHEN 2 THEN '30569309025904' -- Diners Club test number
            WHEN 3 THEN '5555555555554444' -- MasterCard test number
            WHEN 4 THEN '4111111111111111' -- Visa test number
       END AS credit_card_number
	
  FROM `${project_id}.${bigquery_governed_data_raw_dataset}.customer` AS customer
       INNER JOIN random_credit_card
               ON customer.customer_id = random_credit_card.customer_id;