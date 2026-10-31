--PUBLISHED STREAMLIT OBJECT BACKUP
EXECUTE IMMEDIATE $$
DECLARE
  rs RESULTSET;
  d  RESULTSET;
  v_src VARCHAR;
  v_fqn VARCHAR;
  v_sql VARCHAR;
  v_cnt INT DEFAULT 0;
  v_log VARCHAR DEFAULT '';
BEGIN
  SHOW STREAMLITS IN ACCOUNT;
  rs := (SELECT '"' || "database_name" || '"."' || "schema_name" || '"."' || "name" || '"' AS fqn,
                "name" AS app_name
         FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));
  FOR r IN rs DO
    v_fqn := r.fqn;
    v_src := NULL;
    EXECUTE IMMEDIATE 'DESCRIBE STREAMLIT ' || :v_fqn;
    d := (SELECT COALESCE(o:"live_version_location_uri"::VARCHAR,
                          o:"default_version_location_uri"::VARCHAR,
                          o:"root_location"::VARCHAR) AS src
          FROM (SELECT OBJECT_CONSTRUCT(*) AS o FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))));
    FOR x IN d DO
      v_src := x.src;
    END FOR;
    IF (v_src IS NOT NULL) THEN
      v_src := RTRIM(v_src, '/') || '/';
      v_sql := 'COPY FILES INTO ''snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/09_STREAMLIT/'
               || REPLACE(r.app_name, '''', '') || '/'' FROM ' ||
               IFF(STARTSWITH(v_src, '@'), v_src, '''' || v_src || '''');
      EXECUTE IMMEDIATE :v_sql;
      v_cnt := v_cnt + 1;
    ELSE
      v_log := v_log || v_fqn || ' (no location); ';
    END IF;
  END FOR;
  RETURN 'Copied apps: ' || v_cnt || ' | skipped: ' || v_log;
END;
$$;