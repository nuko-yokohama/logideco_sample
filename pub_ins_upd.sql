TRUNCATE table_x;
TRUNCATE table_y;

INSERT INTO table_x VALUES (101, now(), 'running', 35.44778, 139.6425, 'first insert');
INSERT INTO table_x (device_id, update_time, status, latitude, longitude) VALUES (102, now(), 'running', 35.44500, 139.4000);

UPDATE table_x SET update_time = now(), memo = 'updated'  WHERE device_id = 101;
UPDATE table_x SET update_time = now(), latitude = 35.44600, longitude = 139.3000 WHERE device_id = 102;

INSERT INTO table_x VALUES (103, now(), 'running', 35.44900, 139.2000, NULL);

-- device_id not exsists case.
UPDATE table_x SET update_time = now() WHERE device_id = -999; 

-- multi statement
BEGIN;
UPDATE table_x SET status = 'stop', update_time = now() WHERE device_id = 101;
UPDATE table_x SET update_time = now() WHERE device_id = 102;
UPDATE table_x SET update_time = now(), latitude = 35.44700, longitude = 139.1000 WHERE device_id = 103;
END;

-- delete case (skip)
DELETE FROM table_x WHERE device_id = 103;

