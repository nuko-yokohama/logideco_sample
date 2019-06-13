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
SELECT pg_create_logical_replication_slot('srv1_slot', 'wal2json');
```

* 論理スロットから変分を取り出す、pg_logical_slot_get_changes()を実行するSQLをVIEWとして登録する。（この後登録する。apply_json() 関数で使うためのビューなので）

```
CREATE VIEW srv1_slot AS SELECT * FROM pg_logical_slot_get_changes('srv1_slot', null, null);
```

* 論理スロットからのWAL取得＆INSERT文生成のpl/pgsql関数を登録する。

```
psql testdb -f apply_json.sql
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

この状態で、testdnにログインし、table_xとhistoryの内容を確認する。

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
* 第1引数は反映元のテーブル名
* 第2引数は反映先のテーブル名

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
$ psql -U postgres -p 10001 testdb -c "TABLE history"
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

UPDATEによって更新された情報はhistoryテーブルにそれぞれINSEERTされている。
