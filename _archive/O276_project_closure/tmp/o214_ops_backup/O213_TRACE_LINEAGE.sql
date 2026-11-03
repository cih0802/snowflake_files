CREATE OR REPLACE PROCEDURE "O213_TRACE_LINEAGE"()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
begin
  create table if not exists GN_DW.OPS.O213_LINEAGE_GAP (
    src_schema varchar, src_table varchar, src_column varchar,
    tgt_schema varchar, tgt_table varchar, tgt_column varchar,
    distance number, traced_at timestamp_ntz default current_timestamp()
  );
  delete from GN_DW.OPS.O213_LINEAGE_GAP;

  let n number := 0;
  let err number := 0;
  let c1 cursor for
    select table_schema, table_name, column_name
    from GN_DW.OPS.O213_CAT_INVENTORY
    where table_schema in (''BRONZE_CRM'',''BRONZE_AGENCY'',''BRONZE_ERP'',''BRONZE_GA4'',''BRONZE_GSC'',''SILVER'',''ML'')
      and ndv between 2 and 500 and row_cnt > 100
      and data_type = ''TEXT''
      and column_name not like ''_STDR_%'' and column_name not like ''_BATCH_%''
      and column_name not like ''FRST_RGSTR%'' and column_name not like ''LAST_UPDUSR%''
      and column_name not in (''USE_YN'',''STDR_MT'',''STDR_DE'')
    order by row_cnt desc;

  for r in c1 do
    begin
      let fqn varchar := ''GN_DW.'' || r.table_schema || ''.'' || r.table_name || ''.'' || r.column_name;
      insert into GN_DW.OPS.O213_LINEAGE_GAP (src_schema, src_table, src_column, tgt_schema, tgt_table, tgt_column, distance)
        select r.table_schema, r.table_name, r.column_name,
               target_object_schema, target_object_name, target_column_name, distance
        from table(SNOWFLAKE.CORE.GET_LINEAGE(:fqn, ''COLUMN'', ''DOWNSTREAM'', 4))
        where target_object_database = ''GN_DW''
          and target_object_schema in (''GOLD'',''SERVING'',''MSTR'');
      n := n + 1;
    exception when other then
      err := err + 1;
    end;
  end for;
  return ''traced='' || n || '' err='' || err;
end;
';