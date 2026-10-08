CREATE OR REPLACE PROCEDURE "O213_PROFILE_SCHEMA"("P_SCHEMA" VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT='O213 7차 — 스키마 단위 카테고리 후보 프로파일(임시)'
EXECUTE AS OWNER
AS '
declare
  n number default 0;
  q varchar;
  c1 cursor for
    select table_name,
           listagg(''select '''''' || column_name || '''''' c, '''''' || data_type || '''''' t, '' ||
                   ''count("'' || column_name || ''") nn, approx_count_distinct("'' || column_name || ''") nd from b'', '' union all '')
             within group (order by ordinal_position) sel
    from GN_DW.INFORMATION_SCHEMA.COLUMNS
    where table_schema = ?
      and data_type in (''TEXT'',''NUMBER'',''BOOLEAN'')
      and column_name not like ''DW\\\\_%'' escape ''\\\\''
    group by table_name;
begin
  delete from GN_DW.OPS.O213_CAT_INVENTORY where table_schema = :P_SCHEMA;
  open c1 using (:P_SCHEMA);
  for r in c1 do
    q := ''insert into GN_DW.OPS.O213_CAT_INVENTORY (table_schema, table_name, column_name, data_type, comment, row_cnt, nonnull_cnt, ndv) '' ||
         ''with b as (select * from GN_DW.'' || :P_SCHEMA || ''."'' || r.table_name || ''"), x as ('' || r.sel || '') '' ||
         ''select '''''' || :P_SCHEMA || '''''', '''''' || r.table_name || '''''', x.c, x.t, ic.comment, (select count(*) from b), x.nn, x.nd '' ||
         ''from x left join GN_DW.INFORMATION_SCHEMA.COLUMNS ic on ic.table_schema = '''''' || :P_SCHEMA || '''''' and ic.table_name = '''''' || r.table_name || '''''' and ic.column_name = x.c'';
    begin
      execute immediate :q;
      n := n + 1;
    exception when other then
      insert into GN_DW.OPS.O213_CAT_INVENTORY (table_schema, table_name, column_name, comment) values (:P_SCHEMA, r.table_name, ''#ERROR'', left(:sqlerrm, 500));
    end;
  end for;
  return P_SCHEMA || '' tables='' || n;
end;
';