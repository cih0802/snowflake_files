CREATE OR REPLACE PROCEDURE "O213_TRACE_STATUS"("P_SCHEMA" VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
begin
  create table if not exists GN_DW.OPS.O213_TRACE_STATUS_T (
    src_schema varchar, src_table varchar, src_column varchar,
    status varchar, hit_cnt number, err_msg varchar,
    traced_at timestamp_ntz default current_timestamp());
  delete from GN_DW.OPS.O213_TRACE_STATUS_T where src_schema = :P_SCHEMA;
  let n number := 0;
  let c1 cursor for
    select table_schema, table_name, column_name
    from GN_DW.OPS.O213_CAT_INVENTORY
    where table_schema = ?
      and ndv between 2 and 500 and row_cnt > 100 and data_type = ''TEXT''
      and column_name not like ''_STDR_%'' and column_name not like ''_BATCH_%''
      and column_name not like ''FRST_RGSTR%'' and column_name not like ''LAST_UPDUSR%''
      and column_name not in (''USE_YN'',''STDR_MT'',''STDR_DE'');
  open c1 using (:P_SCHEMA);
  for r in c1 do
    let s varchar := r.table_schema;
    let t varchar := r.table_name;
    let c varchar := r.column_name;
    let fqn varchar := ''GN_DW.'' || :s || ''.'' || :t || ''.'' || :c;
    begin
      let k number := (select count(*) from table(SNOWFLAKE.CORE.GET_LINEAGE(:fqn, ''COLUMN'', ''DOWNSTREAM'', 4))
                       where target_object_database = ''GN_DW''
                         and target_object_schema in (''GOLD'',''SERVING'',''MSTR''));
      insert into GN_DW.OPS.O213_TRACE_STATUS_T (src_schema, src_table, src_column, status, hit_cnt)
        values (:s, :t, :c, iff(:k > 0, ''REACHED'', ''NONE''), :k);
    exception when other then
      insert into GN_DW.OPS.O213_TRACE_STATUS_T (src_schema, src_table, src_column, status, err_msg)
        values (:s, :t, :c, ''ERROR'', left(:sqlerrm, 300));
    end;
    n := n + 1;
  end for;
  return :P_SCHEMA || '' n='' || n;
end;
';