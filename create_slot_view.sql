--
-- create_slot_view.sql
-- create logical replication slot, and view
--

-- create slot
SELECT pg_create_logical_replication_slot('logideco_slot', 'wal2json');

-- create view for apply_json() function.
CREATE VIEW logideco_slot AS SELECT * FROM pg_logical_slot_get_changes('logideco_slot', null, null);

