-- This script is called once to configure the replication for Datastram
-- Comments must start with two dashes. SQL must be 1 per line (no multiline).
-- The POSTGRES_USER and DATABASE_PASSWORD will be replaced
CREATE PUBLICATION datastream_publication FOR ALL TABLES;
ALTER USER <<POSTGRES_USER>> with replication;
SELECT PG_CREATE_LOGICAL_REPLICATION_SLOT('datastream_replication_slot', 'pgoutput');
CREATE USER datastream_user WITH REPLICATION IN ROLE cloudsqlsuperuser LOGIN PASSWORD '<<DATABASE_PASSWORD>>';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO datastream_user;
GRANT USAGE ON SCHEMA public TO datastream_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO datastream_user;