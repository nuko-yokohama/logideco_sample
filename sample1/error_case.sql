--
-- error_case.sql
--

TRUNCATE table_x;
TRUNCATE table_y;

INSERT INTO table_x VALUES (104, now(), 'running', 35.44778, 139.6425, 'first insert');
INSERT INTO table_x (device_id, update_time, status, latitude, longitude) VALUES (105, now(), 'running', 35.44500, 139.4000);
UPDATE table_x SET update_time = now(), memo = 'updated'  WHERE device_id = 104;
UPDATE table_x SET update_time = now(), latitude = 35.44600, longitude = 139.3000 WHERE device_id = 105;

INSERT INTO table_y VALUES (103, now(), 'S', 'first insert');
INSERT INTO table_y (device_id, kind, update_time) VALUES (104, 'S', now());


