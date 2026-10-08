CREATE OR REPLACE PROCEDURE "O213_TRACE_TEST"()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
begin
  let c1 cursor for
    select ''SILVER'' as ts, ''CRM_CAMPAIGN'' as tn, ''CMPGN_CTGR_NM'' as cn;
  for r in c1 do
    let fqn varchar := ''GN_DW.'' || r.ts || ''.'' || r.tn || ''.'' || r.cn;
    insert into GN_DW.OPS.O213_LINEAGE_GAP (src_schema, src_table, src_column, tgt_schema, tgt_table, tgt_column, distance)
      select r.ts, r.tn, r.cn,
             target_object_schema, target_object_name, target_column_name, distance
      from table(SNOWFLAKE.CORE.GET_LINEAGE(:fqn, ''COLUMN'', ''DOWNSTREAM'', 4))
      where target_object_database = ''GN_DW''
        and target_object_schema in (''GOLD'',''SERVING'',''MSTR'');
  end for;
  return ''ok'';
end;
';