#!/bin/sh

# logideco_sample_test.sh

DBMAME=testdb
DBUSER=postgres

echo "===="
echo "test database name = " ${DBNAME}
echo "test database user = " ${DBUSER}
echo "===="

dropdb -U ${DBUSER} ${DBNAME}
createdb -U ${DBUSER} ${DBNAME} 

# Setup
psql -U ${DBUSER} ${DBNAME} -e -f pub_table.sql
psql -U ${DBUSER} ${DBNAME} -e -f sub_table.sql
psql -U ${DBUSER} ${DBNAME} -e -f create_slot_view.sql

# install apply_json()
psql -U ${DBUSER} ${DBNAME} -e -f apply.sql

# test
psql -U ${DBUSER} ${DBNAME} -e -f pub_ins_upd.sql
psql -U ${DBUSER} ${DBNAME} -e -c "TABLE table_x"
psql -U ${DBUSER} ${DBNAME} -e -c "SELECT apply_json('table_x', 'history_x')"
psql -U ${DBUSER} ${DBNAME} -e -c "TABLE history_x"

