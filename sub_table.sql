-- sub用DDL(history)

-- ロジデコ対象テーブル
DROP TABLE IF EXISTS history;
CREATE TABLE history (device_id int, update_time timestamp, status text, latitude float, longitude float);
CREATE INDEX history_devid_idx ON history USING btree (device_id);
CREATE INDEX history_updt_idx ON history USING btree (update_time);


