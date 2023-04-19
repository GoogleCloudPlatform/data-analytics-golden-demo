-- This script is called once when the database is created
-- The script should create all your tables in the "public" schema
-- Comments must start with two dashes. SQL must be 1 per line (no multiline).
CREATE TABLE IF NOT EXISTS entries (guestName VARCHAR(255), content VARCHAR(255), entryID SERIAL PRIMARY KEY);