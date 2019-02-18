-- pub用DDL

DROP TABLE IF EXISTS table_x;
DROP TABLE IF EXISTS table_y;

-- ロジデコ対象テーブル
-- table_x
CREATE TABLE table_x (
  device_id int primary key, 
  update_time timestamp, 
  status text, 
  latitude float, 
  longitude float
);
CREATE INDEX updt_idx ON table_x USING btree (update_time);


-- ロジデコ対象外のダミーテーブル
-- table_y
CREATE TABLE table_y (device_id int, dummy text);

