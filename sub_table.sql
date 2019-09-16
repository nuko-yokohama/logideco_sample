-- sub用DDL(history_x, history_y)

-- ロジデコ対象テーブル
DROP TABLE IF EXISTS history_x;
DROP TABLE IF EXISTS history_y;
CREATE TABLE history_x (device_id int, update_time timestamp, status text, latitude float, longitude float, memo text);
CREATE INDEX history_x_devid_idx ON history_x USING btree (device_id);
CREATE INDEX history_x_updt_idx ON history_x USING btree (update_time);

CREATE TABLE history_y (device_id int, update_time timestamp, status varchar(16), memo text);
CREATE INDEX history_y_devid_idx ON history_y USING btree (device_id);

