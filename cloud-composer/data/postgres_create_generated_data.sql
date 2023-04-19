-- This script is called over and over by the Airflow DAG (sample-datastream-xxxxxx-ip-generate-data) to generated mock data
-- Comments must start with two dashes. SQL must be 1 per line (no multiline).
INSERT INTO entries (guestName, content) VALUES (CONCAT('Guest ',  CAST(random() * 1000 + 1 AS VARCHAR(255))), CONCAT('Arrived at ', CAST(random() * 23 + 1 AS VARCHAR(255))));
INSERT INTO entries (guestName, content) VALUES (CONCAT('Person ', CAST(random() * 1000 + 1 AS VARCHAR(255))), CONCAT('Ate at ',     CAST(random() * 23 + 1 AS VARCHAR(255))));
INSERT INTO entries (guestName, content) VALUES (CONCAT('Cat ',    CAST(random() * 1000 + 1 AS VARCHAR(255))), CONCAT('Meowed at ',  CAST(random() * 23 + 1 AS VARCHAR(255))));
INSERT INTO entries (guestName, content) VALUES (CONCAT('Dog ',    CAST(random() * 1000 + 1 AS VARCHAR(255))), CONCAT('Barked at ',  CAST(random() * 23 + 1 AS VARCHAR(255))));
INSERT INTO entries (guestName, content) VALUES (CONCAT('Pet ',    CAST(random() * 1000 + 1 AS VARCHAR(255))), CONCAT('Relaxed at ', CAST(random() * 23 + 1 AS VARCHAR(255))));
INSERT INTO entries (guestName, content) VALUES (CONCAT('Wolf ',   CAST(random() * 1000 + 1 AS VARCHAR(255))), CONCAT('Pack at ',    CAST(random() * 23 + 1 AS VARCHAR(255))));