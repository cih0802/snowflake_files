# O216 — 8차 4.3 · SV AI_SQL_GENERATION 공통 규칙 보강(O214-A-1 #3 · NL MARKETING_14 CAL_YEAR 오류 등)
# 방식 = 각 SV DDL 의 「AI_SQL_GENERATION '[O206 출력 규칙 · 전 SV 공통]」 앞에 O216 규칙 1줄 삽입(멱등 · 해시 선확인)
#        → --deploy 면 파일에서 CREATE OR ALTER 문을 잘라 GN_DW_ADMIN 으로 실행(권한 보존 · 비파괴)
# 사용: python3 tmp/o216_sv_sqlgen.py [--apply] [--deploy]
# Co-authored with CoCo
import glob, hashlib, io, os, re, sys

D = '/workspace/05_SV-Agent_ai/'
ANCHOR = "AI_SQL_GENERATION '[O206 출력 규칙 · 전 SV 공통]"
RULE = ("AI_SQL_GENERATION '[O216 SQL 작성 규칙 · 전 SV 공통] "
        "(가) 지표(metric) 이름을 컬럼처럼 SELECT·WHERE·GROUP BY 에 쓰지 않는다 — 지표는 집계 결과이며 "
        "`__` 접두 CTE 에는 베이스 컬럼만 있다 ⇒ CTE 안에서는 베이스 컬럼을 SUM·COUNT 로 직접 집계한다. "
        "(나) CTE 를 거쳐 바깥 SELECT·GROUP BY·ORDER BY 에서 쓰는 차원은 반드시 그 CTE 의 SELECT 목록에 먼저 넣는다 "
        "(CTE 에 선택하지 않은 차원을 바깥에서 참조하면 invalid identifier 다). "
        "(다) 연·월·일 필터와 그룹은 이 시맨틱 뷰에 선언된 날짜 차원 이름만 쓴다 — CAL_YEAR·FULL_DATE 같은 물리 컬럼명이나 "
        "다른 시맨틱 뷰의 차원 이름을 추측해 쓰지 않는다. 연도가 차원으로 없으면 날짜 차원에 YEAR() 를 적용한다.\n  ")
RULE_SQL = RULE.replace("AI_SQL_GENERATION '", '', 1)
assert "'" not in RULE_SQL.replace('\n', '')
files = sorted(glob.glob(D + '05_*_SV_DDL_*.sql')) + [D + '22_ML_SV_DDL.sql', D + '23_MSTR_SV_DDL.sql']


def h(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


tot = 0
for p in files:
    h0 = h(p); assert h0 == h(p), p + ' 해시 불안정'
    t = io.open(p, encoding='utf-8').read()
    n = t.count(ANCHOR)
    if '[O216 SQL 작성 규칙' in t:
        print('skip(이미 적용)', os.path.basename(p)); continue
    new = t.replace(ANCHOR, "AI_SQL_GENERATION '" + RULE_SQL + "[O206 출력 규칙 · 전 SV 공통]")
    assert new.count('[O216 SQL 작성 규칙') == n
    tot += n
    print(os.path.basename(p), 'insert', n)
    if '--apply' in sys.argv:
        assert h(p) == h0, p + ' 편집 중 변경됨'
        io.open(p, 'w', encoding='utf-8', newline='').write(new)
print('삽입 합계', tot, '· mode =', 'APPLY' if '--apply' in sys.argv else 'DRY-RUN')

if '--deploy' in sys.argv:
    import snowflake.connector
    tok = open(os.environ.get('SNOWFLAKE_TOKEN_FILE_PATH', '/snowflake/session/token')).read().strip()
    con = snowflake.connector.connect(account=os.environ['SNOWFLAKE_ACCOUNT'], host=os.environ.get('SNOWFLAKE_HOST'),
                                      authenticator='oauth', token=tok, role='GN_DW_ADMIN', warehouse='GN_DW_DEV_WH',
                                      database='GN_DW', schema='SERVING')
    cur = con.cursor(); bad = 0; ok = 0
    for p in files:
        t = io.open(p, encoding='utf-8').read()
        for m in re.finditer(r'CREATE OR ALTER SEMANTIC VIEW GN_DW\.SERVING\.([A-Z_0-9]+)\b', t):
            q, j = False, m.start()
            while j < len(t):
                c = t[j]
                if c == "'":
                    q = not q
                elif c == ';' and not q:
                    break
                j += 1
            try:
                cur.execute(t[m.start():j]); ok += 1
                print('🟢', m.group(1))
            except Exception as e:  # noqa: BLE001
                bad += 1; print('🔴', m.group(1), str(e)[:300])
    con.close()
    print('deploy OK', ok, 'FAIL', bad)
    sys.exit(1 if bad else 0)
