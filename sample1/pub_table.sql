-- pub用DDL

DROP TABLE IF EXISTS table_x;
DROP TABLE IF EXISTS table_y;

-- ロジデコ対象テーブル
-- table_x
CREATE TABLE table_x (
  device_id int primary key, 
  update_time timestamp, 
  status varchar(16), 
  latitude float, 
  longitude float,
  memo text
);
CREATE INDEX x_updt_idx ON table_x USING btree (update_time);


-- 2つ目のテーブル
-- table_y
CREATE TABLE table_y (device_id bigint primary key, update_time timestamp, kind char(4), memo text);

-- 反映対象外の3つ目のテーブル
-- table_z
CREATE TABLE table_z (device_id integer primary key, status text, memo text);

