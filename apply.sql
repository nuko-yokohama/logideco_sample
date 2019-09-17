--
-- apply.sql
--

--
-- internal:create_insert_statement_from_json(j jsonb, tn t text)
-- j JSONB object by created wal2json
-- t Table name to be inserted.
--
-- TODO:Correspondence of quoted table names.
--

CREATE OR REPLACE FUNCTION create_insert_statement_from_json( j jsonb, t text ) RETURNS text
AS $$
DECLARE
  sql text;
  elms integer;
  i integer; -- loop counter
  typ text;
  val text;
BEGIN
  sql := 'INSERT INTO ' || t || ' VALUES (';
  elms := jsonb_array_length(j->'columnvalues');
  FOR i IN 0 .. (elms - 1) LOOP
    IF i <> 0 THEN
      sql := sql || ',';
    END IF;
    -- RAISE NOTICE 'val[%]=%', i, (j->'columnvalues')->>i ;
    -- RAISE NOTICE 'typ[%]=%', i, (j->'columntypes')->>i ;
    val := ((j->'columnvalues')->>i) ;

    IF val is NULL THEN
      sql := sql || 'NULL' ;
    ELSE
      typ := (j->'columntypes')->>i;
      CASE 
        WHEN typ ~ '(smallint|integer|bigint|numeric|real|double precision|money).*' THEN
          -- no quote value
          sql := sql || val ;
        ELSE
          -- need quote value
          sql := sql || '''' || val || '''' ;
      END CASE;
    END IF;

  END LOOP;

  sql := sql || ')';

  RETURN sql;
END;
$$ 
LANGUAGE plpgsql;

--
-- external:apply_json(pt1 text, st1 text, pt2 text, st2 text)
-- pt1, pt2 publish Table name.
-- st1, st2 subscribe Table name to be inserted.
--
CREATE OR REPLACE FUNCTION apply_json2(pt1 text, st1 text, pt2 text, st2 text) RETURNS integer
AS $$
DECLARE
 r logideco_slot%rowtype;
 elms integer;
 kind text;
 sql text;
 created_num integer := 0;
 t_name text;
BEGIN
  FOR r IN
    SELECT * FROM logideco_slot
  LOOP
    elms := jsonb_array_length((r.data::jsonb)->'change');
    -- RAISE NOTICE 'elms=%', elms;
    FOR i IN 0 .. (elms - 1) LOOP
      t_name := (((r.data::jsonb)->'change')-> i )->>'table';
      CONTINUE WHEN t_name <> pt1 AND t_name <> pt2;

      kind := (((r.data::jsonb)->'change')-> i )->>'kind';
      -- RAISE NOTICE 'kind=%', kind;
      CASE kind 
        WHEN 'insert', 'update' THEN
          -- Create insert statement
          IF t_name = pt1 THEN
            sql := create_insert_statement_from_json( (((r.data::jsonb)->'change')-> i ), st1 );
          ELSIF t_name = pt2 THEN
            sql := create_insert_statement_from_json( (((r.data::jsonb)->'change')-> i ), st2 );
          ELSE
           -- bug path
            RAISE EXCEPTION 'invalid table name, table name = %', t_name;
          END IF;
          -- RAISE NOTICE 'sql=%', sql;
          -- execute insert statement.
          EXECUTE sql;
          created_num := created_num + 1;
        ELSE
          -- nop
      END CASE;
    END LOOP;
  END LOOP;
  RETURN created_num;
END;
$$
LANGUAGE plpgsql;

--
-- external:apply_json(pt1 text, st1 text)
-- pt1 publish Table name.
-- st1 subscribe Table name to be inserted.
--
CREATE OR REPLACE FUNCTION apply_json(pt1 text, st1 text) RETURNS integer
AS $$
DECLARE
 r logideco_slot%rowtype;
 elms integer;
 kind text;
 sql text;
 created_num integer := 0;
 t_name text;
BEGIN
  FOR r IN
    SELECT * FROM logideco_slot
  LOOP
    elms := jsonb_array_length((r.data::jsonb)->'change');
    -- RAISE NOTICE 'elms=%', elms;
    FOR i IN 0 .. (elms - 1) LOOP
      t_name := (((r.data::jsonb)->'change')-> i )->>'table';
      CONTINUE WHEN t_name <> pt1; 

      kind := (((r.data::jsonb)->'change')-> i )->>'kind';
      -- RAISE NOTICE 'kind=%', kind;
      CASE kind 
        WHEN 'insert', 'update' THEN
          -- Create insert statement
          IF t_name = pt1 THEN
            sql := create_insert_statement_from_json( (((r.data::jsonb)->'change')-> i ), st1 );
          ELSE
           -- bug path
            RAISE EXCEPTION 'invalid table name, table name = %', t_name;
          END IF;
          -- RAISE NOTICE 'sql=%', sql;
          -- execute insert statement.
          EXECUTE sql;
          created_num := created_num + 1;
        ELSE
          -- nop
      END CASE;
    END LOOP;
  END LOOP;
  RETURN created_num;
END;
$$
LANGUAGE plpgsql;

