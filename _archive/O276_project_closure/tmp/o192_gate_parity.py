"""O192 오프라인 등가 검사 — 게이트 파서들이 정리 전(스냅샷)과 후에 같은 결과를 내는가."""
import sys, re, importlib
sys.path.insert(0, '/workspace/scripts')
import table_ddl_column_gate as g, comment_drift_gate as c
layer, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
schema = layer.upper()
names = sorted(set(re.findall(rf'CREATE OR REPLACE TABLE GN_DW\.{schema}\.(\w+)', open(old, encoding='utf-8').read())))
fn = g.silver_ddl_columns if layer == 'silver' else g.gold_ddl_columns
attr = 'SILVER_DDL' if layer == 'silver' else 'GOLD_DDL'
def run(p):
    setattr(g, attr, p); return {n: fn(n) for n in names}
a, b = run(old), run(new)
print('table_ddl_column_gate 파서:', '일치' if a == b else [n for n in names if a[n] != b[n]], f'({len(names)}테이블)')
rx = c.RE_SILVER if layer == 'silver' else c.RE_TABLE
pa, pb = c.parse_ddl(old, rx), c.parse_ddl(new, rx)
diff = [k for k in pa if pa.get(k) != pb.get(k)]
print('comment_drift_gate 컬럼 COMMENT: 키', len(pa), '→', len(pb), '· 값 변경', len(diff), '· 예', diff[:3])
ta, tb = c.parse_ddl_table_level(old, rx), c.parse_ddl_table_level(new, rx)
print('comment_drift_gate 테이블 COMMENT: 키', len(ta), '→', len(tb), '· 값 변경', sum(ta.get(k) != tb.get(k) for k in ta))
