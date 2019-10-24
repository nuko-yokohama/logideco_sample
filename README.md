# logideco_sample

これは、wal2jsonで作られたJSON形式の論理ログから、plpgsql使ってINSERT文を作成するサンプルコードです。
Sample code to create an INSERT statement using plpgsql from the JSON format logical log created by wal2json.

## 依存するプラグイン
wal2json - JSON output plugin for changeset extraction

https://github.com/eulerto/wal2json

## 説明
* このサンプルでは、wal2jsonで生成されたJSON形式の論理ログから、更新情報を読み取り、INSERT文を生成します。
* そして、引数で指定したテーブルに対して、そのINSERT文を実行します。
* このサンプルでは、論理ログ生成元で、実行したINSERT文もUPDATE文も、両方ともINSERT文に変換します。これによりログのヒストリテーブルを作成します。

## 準備
* 事前にPostgreSQLをソースからビルドします。（PostgreSQL 11.x)
* wal2jsonをGithubからDLして、``make USE_PGXS=1``オプションつきでビルドします。
    * 注意：2019年2月時点では、PostgreSQL 12(開発版だとビルド時にエラーになってしまいます。PostgreSQL 12 beta1リリースのタイムングで再度確認してみますが、必要があれば、wal2jsonのコードの修正も必要かもしれません。
    * PostgreSQL 12-beta1上で、wal2jsonモジュールのビルドができることを確認しました。(警告は出ている。gcc (GCC) 7.3.1 20180303 (Red Hat 7.3.1-5)で確認）
* wal_levelをlogicalに設定して、論理ログを出力可能にします。
* wal2jsonによって生成される論理ログ格納用のレプリケーションスロットを、生成する。
```
SELECT pg_create_logical_replication_slot('logideco_slot', 'wal2json');
```

* 論理スロットから変分を取り出す、pg_logical_slot_get_changes()を実行するSQLをVIEWとして登録する。（この後登録する。apply_json() 関数で使うためのビューなので）

```
CREATE VIEW logideco_slot AS SELECT * FROM pg_logical_slot_get_changes('logideco_slot', null, null);
```

* 上記の2つのDDLは、``create_slot_view.sql``に書かれているので、以下のようにすれば登録できる。

```
psql testdb -f create_slot_view.sql
```

* 生成したINSERT文が失敗した場合、そのSQL文を格納するためのテーブル ``__sql_table`` を定義する。

```
CREATE TABLE IF NOT EXISTS __sql_table (id bigserial primary key, ts timestamp, sql text);
```

上記のDDLは、``__sql_table.sql``に書かれているので、以下のようにすれば登録できる。

* 論理スロットからのWAL取得＆INSERT文生成のpl/pgsql関数を登録する。

```
psql testdb -f apply.sql
```

## 検証
反映元のテーブルを作成する。

```
$ cat pub_table.sql
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
```

```
$ psql testdb -f pub_table.sql
```

反映先のテーブル(history)を作成する。

```
$ cat sub_table.sql
-- sub用DDL(history)

-- ロジデコ対象テーブル
DROP TABLE IF EXISTS history;
CREATE TABLE history (device_id int, update_time timestamp, status text, latitude float, longitude float);
CREATE INDEX history_devid_idx ON history USING btree (device_id);
CREATE INDEX history_updt_idx ON history USING btree (update_time);
```

```
$ psql testdb -f sub_table.sql
```

反映元のテーブルへのINSERT/UPDATE/DELETE文を発行する。

```
$ cat pub_ins_upd.sql
TRUNCATE table_x;

INSERT INTO table_x VALUES (101, now(), 'running', 35.44778, 139.6425);
INSERT INTO table_x VALUES (102, now(), 'running', 35.44500, 139.4000);

UPDATE table_x SET update_time = now() WHERE device_id = 101;
UPDATE table_x SET update_time = now(), latitude = 35.44600, longitude = 139.3000 WHERE device_id = 102;

INSERT INTO table_x VALUES (103, now(), 'running', 35.44900, 139.2000);

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

$
```

```
$ psql testdb -f sub_table.sql
```

この状態で、testdbにログインし、table_xとhistoryの内容を確認する。

```
$ psql testdb -c "TABLE table_x"
 device_id |        update_time         | status  | latitude | longitude
-----------+----------------------------+---------+----------+-----------
       101 | 2019-02-18 20:30:28.955218 | stop    | 35.44778 |  139.6425
       102 | 2019-02-18 20:30:28.955218 | running |   35.446 |     139.3
(2 rows)

$ psql testdb -c "TABLE history"
$ psql -U postgres -p 10001 testdb -c "TABLE history"
 device_id | update_time | status | latitude | longitude
-----------+-------------+--------+----------+-----------
(0 rows)
```

さきほど登録した、apply_json()関数を実行する。
* apply_json(pt1 text, st1 text)
    * 第1引数(pt1)は反映元のテーブル名
    * 第2引数(st1)は反映先のテーブル名
* apply_json(pt1 text, st1 text, pt2 text, st2 text)
    * 第1引数(pt1)は反映元1のテーブル名
    * 第2引数(st1)は反映先1のテーブル名
    * 第3引数(pt2)は反映元2のテーブル名
    * 第4引数(st2)は反映先2のテーブル名


```
$ psql testdb -c "SELECT apply_json('table_x', 'history')"
NOTICE:  sql=INSERT INTO history VALUES (101,'2019-02-18 20:30:28.947094','running',35.44778,139.6425)
NOTICE:  sql=INSERT INTO history VALUES (102,'2019-02-18 20:30:28.949321','running',35.445,139.4)
NOTICE:  sql=INSERT INTO history VALUES (101,'2019-02-18 20:30:28.950322','running',35.44778,139.6425)
NOTICE:  sql=INSERT INTO history VALUES (102,'2019-02-18 20:30:28.952682','running',35.446,139.3)
NOTICE:  sql=INSERT INTO history VALUES (103,'2019-02-18 20:30:28.953942','running',35.449,139.2)
NOTICE:  sql=INSERT INTO history VALUES (101,'2019-02-18 20:30:28.955218','stop',35.44778,139.6425)
NOTICE:  sql=INSERT INTO history VALUES (102,'2019-02-18 20:30:28.955218','running',35.446,139.3)
NOTICE:  sql=INSERT INTO history VALUES (103,'2019-02-18 20:30:28.955218','running',35.447,139.1)
 apply_json
------------
          8
(1 row)
```

この状態で、historyテーブルの内容を確認する。

```
$ psql testdb -c "TABLE history"
 device_id |        update_time         | status  | latitude | longitude
-----------+----------------------------+---------+----------+-----------
       101 | 2019-02-18 20:30:28.947094 | running | 35.44778 |  139.6425
       102 | 2019-02-18 20:30:28.949321 | running |   35.445 |     139.4
       101 | 2019-02-18 20:30:28.950322 | running | 35.44778 |  139.6425
       102 | 2019-02-18 20:30:28.952682 | running |   35.446 |     139.3
       103 | 2019-02-18 20:30:28.953942 | running |   35.449 |     139.2
       101 | 2019-02-18 20:30:28.955218 | stop    | 35.44778 |  139.6425
       102 | 2019-02-18 20:30:28.955218 | running |   35.446 |     139.3
       103 | 2019-02-18 20:30:28.955218 | running |   35.447 |     139.1
(8 rows)
```

INSERTによって挿入された情報および、UPDATEによって更新された情報はhistoryテーブルにそれぞれINSEERTされている。

## サンプル

``sample1``フォルダに、``logideco_sample_test.sh``を実行すると、``apply_json2()``を使った2つのヒストリテーブルへの反映と、
反映先へのINSERTに失敗した場合（history_x テーブルのRENAMEで失敗させている）、``__sql_table``テーブルへの生成INSERT文の格納が確認できる。

以下は、``logodemo_sample_test.sh``の実行例となる。

```
$ ./logideco_sample_test.sh 
====
test database name =  testdb
test database user =  postgres
====
==== create publish tables ====
DROP TABLE IF EXISTS table_x;
psql:pub_table.sql:3: NOTICE:  table "table_x" does not exist, skipping
DROP TABLE
DROP TABLE IF EXISTS table_y;
psql:pub_table.sql:4: NOTICE:  table "table_y" does not exist, skipping
DROP TABLE
DROP TABLE IF EXISTS table_z;
psql:pub_table.sql:5: NOTICE:  table "table_z" does not exist, skipping
DROP TABLE
CREATE TABLE table_x (
  device_id int primary key, 
  update_time timestamp, 
  status varchar(16), 
  latitude float, 
  longitude float,
  memo text
);
CREATE TABLE
CREATE INDEX x_updt_idx ON table_x USING btree (update_time);
CREATE INDEX
CREATE TABLE table_y (device_id bigint primary key, update_time timestamp, kind char(4), memo text);
CREATE TABLE
CREATE TABLE table_z (device_id integer primary key, status text, memo text);
CREATE TABLE
==== create subscribe tables ====
DROP TABLE IF EXISTS history_x;
psql:sub_table.sql:4: NOTICE:  table "history_x" does not exist, skipping
DROP TABLE
DROP TABLE IF EXISTS history_y;
psql:sub_table.sql:5: NOTICE:  table "history_y" does not exist, skipping
DROP TABLE
CREATE TABLE history_x (device_id int, update_time timestamp, status text, latitude float, longitude float, memo text);
CREATE TABLE
CREATE INDEX history_x_idx ON history_x USING btree (device_id);
CREATE INDEX
CREATE INDEX history_x_updt_idx ON history_x USING btree (update_time);
CREATE INDEX
CREATE TABLE history_y (device_id int, update_time timestamp, status varchar(16), memo text);
CREATE TABLE
CREATE INDEX history_y_idx ON history_y USING btree (device_id);
CREATE INDEX
==== create error sql table ====
DROP TABLE IF EXISTS __sql_table CASCADE;
psql:../__sql_table.sql:5: NOTICE:  table "__sql_table" does not exist, skipping
DROP TABLE
CREATE TABLE IF NOT EXISTS __sql_table (id bigserial primary key, ts timestamp, sql text);
CREATE TABLE
==== create slot and view====
SELECT pg_create_logical_replication_slot('logideco_slot', 'wal2json');
 pg_create_logical_replication_slot 
------------------------------------
 (logideco_slot,0/1D05F70)
(1 row)

CREATE VIEW logideco_slot AS SELECT * FROM pg_logical_slot_get_changes('logideco_slot', null, null);
CREATE VIEW
==== install apply_json() ====
CREATE FUNCTION
CREATE FUNCTION
CREATE FUNCTION
==== insert and update for publish tables ====
TRUNCATE table_x;
TRUNCATE TABLE
TRUNCATE table_y;
TRUNCATE TABLE
INSERT INTO table_x VALUES (101, now(), 'running', 35.44778, 139.6425, 'first insert');
INSERT 0 1
INSERT INTO table_x (device_id, update_time, status, latitude, longitude) VALUES (102, now(), 'running', 35.44500, 139.4000);
INSERT 0 1
INSERT INTO table_y VALUES (101, now(), 'S', 'first insert');
INSERT 0 1
INSERT INTO table_y (device_id, kind, update_time) VALUES (102, 'S', now());
INSERT 0 1
UPDATE table_x SET update_time = now(), memo = 'updated'  WHERE device_id = 101;
UPDATE 1
UPDATE table_x SET update_time = now(), latitude = 35.44600, longitude = 139.3000 WHERE device_id = 102;
UPDATE 1
INSERT INTO table_x VALUES (103, now(), 'running', 35.44900, 139.2000, NULL);
INSERT 0 1
UPDATE table_x SET update_time = now() WHERE device_id = -999;
UPDATE 0
BEGIN;
BEGIN
UPDATE table_x SET status = 'stop', update_time = now() WHERE device_id = 101;
UPDATE 1
UPDATE table_x SET update_time = now() WHERE device_id = 102;
UPDATE 1
UPDATE table_x SET update_time = now(), latitude = 35.44700, longitude = 139.1000 WHERE device_id = 103;
UPDATE 1
END;
COMMIT
UPDATE table_y SET kind = 'R';
UPDATE 2
INSERT INTO table_z VALUES (101, 'Stoped', NULL);
INSERT 0 1
UPDATE table_z SET status = 'Running' WHERE device_id = 101;
UPDATE 1
DELETE FROM table_x WHERE device_id = 103;
DELETE 1
==== check publish tables ====
TABLE table_x
 device_id |        update_time         | status  | latitude | longitude |  memo   
-----------+----------------------------+---------+----------+-----------+---------
       101 | 2019-10-24 07:23:34.629496 | stop    | 35.44778 |  139.6425 | updated
       102 | 2019-10-24 07:23:34.629496 | running |   35.446 |     139.3 | 
(2 rows)

TABLE table_y
 device_id |        update_time         | kind |     memo     
-----------+----------------------------+------+--------------
       101 | 2019-10-24 07:23:34.625301 | R    | first insert
       102 | 2019-10-24 07:23:34.626139 | R    | 
(2 rows)

TABLE table_z
 device_id | status  | memo 
-----------+---------+------
       101 | Running | 
(1 row)

==== check subscribe tables 1 ====
TABLE history_x
 device_id | update_time | status | latitude | longitude | memo 
-----------+-------------+--------+----------+-----------+------
(0 rows)

TABLE history_y
 device_id | update_time | status | memo 
-----------+-------------+--------+------
(0 rows)

==== apply logical wal ====
SELECT apply_json2('table_x', 'history_x', 'table_y', 'history_y')
 apply_json2 
-------------
          12
(1 row)

==== check subscribe tables 2 ====
TABLE history_x
 device_id |        update_time         | status  | latitude | longitude |     memo     
-----------+----------------------------+---------+----------+-----------+--------------
       101 | 2019-10-24 07:23:34.623388 | running | 35.44778 |  139.6425 | first insert
       102 | 2019-10-24 07:23:34.624527 | running |   35.445 |     139.4 | 
       101 | 2019-10-24 07:23:34.626839 | running | 35.44778 |  139.6425 | updated
       102 | 2019-10-24 07:23:34.62784  | running |   35.446 |     139.3 | 
       103 | 2019-10-24 07:23:34.628578 | running |   35.449 |     139.2 | 
       101 | 2019-10-24 07:23:34.629496 | stop    | 35.44778 |  139.6425 | updated
       102 | 2019-10-24 07:23:34.629496 | running |   35.446 |     139.3 | 
       103 | 2019-10-24 07:23:34.629496 | running |   35.447 |     139.1 | 
(8 rows)

TABLE history_y
 device_id |        update_time         | status |     memo     
-----------+----------------------------+--------+--------------
       101 | 2019-10-24 07:23:34.625301 | S      | first insert
       102 | 2019-10-24 07:23:34.626139 | S      | 
       101 | 2019-10-24 07:23:34.625301 | R      | first insert
       102 | 2019-10-24 07:23:34.626139 | R      | 
(4 rows)

TABLE __sql_table
 id | ts | sql 
----+----+-----
(0 rows)

==== error case test ====
ALTER TABLE history_x RENAME TO history_foo
ALTER TABLE
TRUNCATE table_x;
TRUNCATE TABLE
TRUNCATE table_y;
TRUNCATE TABLE
INSERT INTO table_x VALUES (104, now(), 'running', 35.44778, 139.6425, 'first insert');
INSERT 0 1
INSERT INTO table_x (device_id, update_time, status, latitude, longitude) VALUES (105, now(), 'running', 35.44500, 139.4000);
INSERT 0 1
UPDATE table_x SET update_time = now(), memo = 'updated'  WHERE device_id = 104;
UPDATE 1
UPDATE table_x SET update_time = now(), latitude = 35.44600, longitude = 139.3000 WHERE device_id = 105;
UPDATE 1
INSERT INTO table_y VALUES (103, now(), 'S', 'first insert');
INSERT 0 1
INSERT INTO table_y (device_id, kind, update_time) VALUES (104, 'S', now());
INSERT 0 1
SELECT apply_json2('table_x', 'history_x', 'table_y', 'history_y')
 apply_json2 
-------------
           6
(1 row)

TABLE history_x
ERROR:  relation "history_x" does not exist
LINE 1: TABLE history_x
              ^
TABLE history_y
 device_id |        update_time         | status |     memo     
-----------+----------------------------+--------+--------------
       101 | 2019-10-24 07:23:34.625301 | S      | first insert
       102 | 2019-10-24 07:23:34.626139 | S      | 
       101 | 2019-10-24 07:23:34.625301 | R      | first insert
       102 | 2019-10-24 07:23:34.626139 | R      | 
       103 | 2019-10-24 07:23:34.697917 | S      | first insert
       104 | 2019-10-24 07:23:34.698859 | S      | 
(6 rows)

==== history_x insert query only =====
TABLE __sql_table
 id |             ts             |                                                    sql                             
                        
----+----------------------------+------------------------------------------------------------------------------------
------------------------
  1 | 2019-10-24 07:23:34.70859  | INSERT INTO history_x VALUES (104,'2019-10-24 07:23:34.694129','running',35.44778,139.6425,'first insert')
  2 | 2019-10-24 07:23:34.708894 | INSERT INTO history_x VALUES (105,'2019-10-24 07:23:34.695248','running',35.445,139.4,NULL)
  3 | 2019-10-24 07:23:34.709046 | INSERT INTO history_x VALUES (104,'2019-10-24 07:23:34.696074','running',35.44778,139.6425,'updated')
  4 | 2019-10-24 07:23:34.70917  | INSERT INTO history_x VALUES (105,'2019-10-24 07:23:34.696979','running',35.446,139.3,NULL)
(4 rows)

ALTER TABLE history_foo RENAME TO history_x
ALTER TABLE
$ 
```
