-- This script is called once when the database is created
-- The script should create all your tables in the "public" schema
-- Comments must start with two dashes. SQL must be 1 per line (no multiline).
CREATE TABLE IF NOT EXISTS driver  (driver_id  SERIAL PRIMARY KEY, driver_name VARCHAR(255), license_number VARCHAR(255), license_plate VARCHAR(255) );
CREATE TABLE IF NOT EXISTS review  (review_id  SERIAL PRIMARY KEY, driver_id INTEGER, passenger_id INTEGER, review_date DATE, ride_date DATE, pickup_location_id INTEGER, dropoff_location_id INTEGER, total_amount MONEY, review_rating INTEGER);
CREATE TABLE IF NOT EXISTS payment (payment_id SERIAL PRIMARY KEY, driver_id INTEGER, ride_date DATE, passenger_id INTEGER, credit_card_number VARCHAR(255), credit_card_expiration_date DATE, credit_card_security_code VARCHAR(255), pickup_location_id INTEGER, dropoff_location_id INTEGER, total_amount MONEY);

-- Seed data so we can see things working
INSERT INTO driver  (driver_name, license_number, license_plate) VALUES ('Data Analytics Golden Demo','0000-00-0000-0','000-000');
INSERT INTO review  (driver_id, passenger_id, review_date, ride_date, pickup_location_id, dropoff_location_id, total_amount, review_rating) VALUES (0,0,'2099-06-01','2099-06-01',0, 0, 0, 10);
INSERT INTO payment (driver_id, ride_date, passenger_id, credit_card_number, credit_card_expiration_date, credit_card_security_code, pickup_location_id, dropoff_location_id, total_amount) VALUES (0,'2099-06-01',0,'4111-1111-1111-1111','2099-06-01','379', 0, 0, 0);
