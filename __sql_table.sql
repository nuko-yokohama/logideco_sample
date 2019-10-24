--
-- __sql_table.sql
-- Store the failed INSERT statement.
--
DROP TABLE IF EXISTS __sql_table CASCADE;
CREATE TABLE IF NOT EXISTS __sql_table (id bigserial primary key, ts timestamp, sql text);

