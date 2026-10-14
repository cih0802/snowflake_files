#!/usr/bin/env python3
"""O228 ⑥ C3 잔여 — SILVER·SERVING 테이블/뷰/컬럼 COMMENT 의 이슈ID·경위 서사 제거(대상 = 라이브 실측).
흐름 = 라이브 COMMENT(이슈ID 포함) → scrub(tmp/o228/fix_c3_sv.py 규칙) → 정본 파일에서 같은 리터럴을 찾아 치환
      → 라이브 ALTER(COMMENT 만 · REPLACE 없음). 파일 리터럴이 0회·2회 이상이면 그 건은 ABORT 목록.
사용: python3 tmp/o228/fix_c3_tail.py [--apply] [--sql]   · --sql = 👤 실행용 tmp/o228/c3_tail_alter.sql 만 쓴다
산출 = tmp/o228/c3_tail_diff.md
Co-authored with CoCo
"""
import glob, hashlib, io, re, sys
sys.path.insert(0, '/workspace/scripts')
from sfconn import conn

src = io.open('/workspace/tmp/o228/fix_c3_sv.py', encoding='utf-8').read()
ns = {}
exec(compile(src[:src.index('FILES = sorted')], 'sv', 'exec'), ns)
IDR = re.compile(r'\b' + ns['ID'] + r'\b')
scrub_sv = ns['scrub']


def scrub(t):
    # 「(O182 신규)」에서 ID 만 빠진 잔재 — 컬럼 신설 경위라 통째로 지운다(「신규회원」 같은 낱말은 건드리지 않는다)
    t = scrub_sv(t)
    t = re.sub(r'\s*\(신규\)', '', t)
    t = re.sub(r'\(신규 · ', '(', t)
    return t.strip()


NARR = re.compile(r'종전|거짓이었다|철회|이슈원장|문서\d0 §')
FILES = (['/workspace/04_silver_design/08_SILVER_테이블DDL_20260714.sql']
         + sorted(glob.glob('/workspace/05_SV-Agent_ai/*.sql'))
         + ['/workspace/15_MSTR 이관 PoC/snowflake 적용 ddl/05_MSTR_SV_DDL.sql'])
OUT = '/workspace/tmp/o228/c3_tail_diff.md'
apply, sqlonly = '--apply' in sys.argv, '--sql' in sys.argv

c = conn().cursor()
c.execute('USE ROLE GN_DW_ADMIN'); c.execute('USE WAREHOUSE GN_DW_ETL_WH')
c.execute("SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE, COMMENT FROM GN_DW.INFORMATION_SCHEMA.TABLES "
          "WHERE TABLE_SCHEMA IN ('SILVER','SERVING')")
kind = {}
tg = []
for s, n, ty, cm in c.fetchall():
    kind[(s, n)] = 'VIEW' if ty == 'VIEW' else 'TABLE'
    if cm and (IDR.search(cm) or NARR.search(cm)):
        tg.append((s, n, None, cm))
c.execute("SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, COMMENT FROM GN_DW.INFORMATION_SCHEMA.COLUMNS "
          "WHERE TABLE_SCHEMA IN ('SILVER','SERVING')")
tg += [(s, n, col, cm) for s, n, col, cm in c.fetchall() if cm and (IDR.search(cm) or NARR.search(cm))]

text = {}
for p in FILES:
    h = [hashlib.sha256(open(p, 'rb').read()).hexdigest() for _ in range(2)]
    assert h[0] == h[1], 'hash unstable ' + p
    text[p] = io.open(p, encoding='utf-8').read()
diff, bad, alters, filehits = [], [], [], {}
for s, n, col, old in tg:
    new = scrub(old)
    if IDR.search(new):
        bad.append(f'잔여ID {s}.{n}.{col}')
        continue
    lit = "'" + old.replace("'", "''") + "'"
    where = [(p, t.count(lit)) for p, t in text.items() if lit in t]
    cnt = sum(k for _, k in where)
    if cnt == 1:
        p = where[0][0]
        text[p] = text[p].replace(lit, "'" + new.replace("'", "''") + "'")
        filehits[p] = filehits.get(p, 0) + 1
        loc = p.split('/')[-1]
    else:
        loc = f'파일 리터럴 {cnt}회'
        if cnt > 1:
            bad.append(f'중복 리터럴 {s}.{n}.{col} {cnt}')
            continue
    q = new.replace("'", "''")
    obj = f'GN_DW.{s}.{n}'
    if col:
        alters.append(f"ALTER {kind[(s, n)]} {obj} MODIFY COLUMN {col} COMMENT '{q}';")
    else:
        alters.append(f"ALTER {kind[(s, n)]} {obj} SET COMMENT = '{q}';")
    diff.append(f'### {s}.{n}.{col or "(객체)"} · {loc}\n- 전: {old}\n- 후: {new}\n')
if diff:
    io.open(OUT, 'w', encoding='utf-8').write('# O228 C3 잔여(SILVER·SERVING) 전후 대조\n\n' + '\n'.join(diff) + '\n_Co-authored with CoCo_\n')
print('대상', len(tg), '· 처리', len(diff), '· ABORT', len(bad), '· 파일 반영', filehits and {k.split('/')[-1]: v for k, v in filehits.items()})
nofile = [d.split('\n')[0] for d in diff if '파일 리터럴 0회' in d]
print('파일 정본 없음(라이브만)', len(nofile))
for x in nofile:
    print('  ', x)
for b in bad:
    print('  🔴', b)
if bad:
    sys.exit('ABORT')
if sqlonly:
    io.open('/workspace/tmp/o228/c3_tail_alter.sql', 'w', encoding='utf-8').write(
        '-- O228 C3 잔여 라이브 COMMENT 갱신(SILVER·SERVING · COMMENT 만) · 👤 GN_DW_ADMIN 전체 실행\n'
        '-- 생성 = tmp/o228/fix_c3_tail.py --sql · Co-authored with CoCo\n'
        'USE ROLE GN_DW_ADMIN;\nUSE WAREHOUSE GN_DW_ETL_WH;\n\n' + '\n'.join(alters) + '\n')
    print('SQL', len(alters))
elif apply:
    from snapshot_util import snapshot
    for p in filehits:
        snapshot(p, 'prec3tail', label='O228', archive='/workspace/tmp/o228/bak')
        io.open(p, 'w', encoding='utf-8').write(text[p])
    ok = fail = 0
    for a in alters:
        try:
            c.execute(a); ok += 1
        except Exception as e:  # noqa: BLE001
            fail += 1
            if fail <= 2:
                print('  🔴', str(e)[:200])
    print('APPLIED 파일', len(filehits), '· ALTER 성공', ok, '· 실패', fail)
else:
    print('DRY-RUN')
