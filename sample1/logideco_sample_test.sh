#!/bin/sh

# logideco_sample_test.sh

DBNAME=testdb
DBUSER=postgres

echo "===="
echo "test database name = " ${DBNAME}
echo "test database user = " ${DBUSER}
echo "===="

dropdb -U ${DBUSER} ${DBNAME}
createdb -U ${DBUSER} ${DBNAME} 

# Setup
echo "==== create publish tables ===="
psql -U ${DBUSER} ${DBNAME} -e -f pub_table.sql
echo "==== create subscribe tables ===="
psql -U ${DBUSER} ${DBNAME} -e -f sub_table.sql


echo "==== create error sql table ===="
psql -U ${DBUSER} ${DBNAME} -e -f ../__sql_table.sql

echo "==== create slot and view===="
psql -U ${DBUSER} ${DBNAME} -e -f ../create_slot_view.sql

echo "==== install apply_json() ===="
psql -U ${DBUSER} ${DBNAME} -f ../apply.sql

# test
echo "==== insert and update for publish tables ===="
psql -U ${DBUSER} ${DBNAME} -e -f pub_ins_upd.sql
echo "==== check publish tables ===="
psql -U ${DBUSER} ${DBNAME} -e -c "TABLE table_x"
psql -U ${DBUSER} ${DBNAME} -e -c "TABLE table_y"
psql -U ${DBUSER} ${DBNAME} -e -c "TABLE table_z"

echo "==== check subscribe tables 1 ===="
psql -U ${DBUSER} ${DBNAME} -e -c "TABLE history_x"
psql -U ${DBUSER} ${DBNAME} -e -c "TABLE history_y"

echo "==== apply logical wal ===="
psql -U ${DBUSER} ${DBNAME} -e -c "SELECT apply_json2('table_x', 'history_x', 'table_y', 'history_y')"

echo "==== check subscribe tables 2 ===="
psql -U ${DBUSER} ${DBNAME} -e -c "TABLE history_x"
psql -U ${DBUSER} ${DBNAME} -e -c "TABLE history_y"
psql -U ${DBUSER} ${DBNAME} -e -c "TABLE __sql_table"


echo "==== error case test ===="

psql -U ${DBUSER} ${DBNAME} -e -c "ALTER TABLE history_x RENAME TO history_foo"
psql -U ${DBUSER} ${DBNAME} -e -f error_case.sql
psql -U ${DBUSER} ${DBNAME} -e -c "SELECT apply_json2('table_x', 'history_x', 'table_y', 'history_y')"
psql -U ${DBUSER} ${DBNAME} -e -c "TABLE history_x"
psql -U ${DBUSER} ${DBNAME} -e -c "TABLE history_y"
echo "==== history_x insert query only ====="
psql -U ${DBUSER} ${DBNAME} -e -c "TABLE __sql_table"
psql -U ${DBUSER} ${DBNAME} -e -c "ALTER TABLE history_foo RENAME TO history_x"
