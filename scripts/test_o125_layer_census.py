# -*- coding: utf-8 -*-
"""[2026-08-31 O125-B] `o125_layer_census` 음성 테스트 — **판정식이 못 보는 축을 오염으로 만든다**.
# Co-authored with CoCo

🔴🔴 왜 필요한가: 이 도구의 **초판이 SERVING 분모를 0 으로 냈다.** 정본 DDL 이
   `CREATE OR ALTER SEMANTIC VIEW` 인데 추출기가 `OR REPLACE` 만 봤고, 출력은
   「설계 0 · 라이브 17 · 미생성 0」으로 **✅ 를 냈다** — 분모가 비면 「누락 0」은
   자동으로 참이 된다(`O111 ㉠`). 🟢 그래서 이 테스트는 **비어 있음 자체를 FAIL** 로 만든다.

🔴 이 테스트가 지키는 계약 6개
   ㉠ SV 추출기가 `CREATE OR ALTER` 를 본다(정본 문법 · 오염하면 0 이 되는 것을 실증).
   ㉡ SERVING 뷰 추출은 **스키마 한정**이다 — GOLD 뷰를 SERVING 미생성으로 오탐하지 않는다.
   ㉢ DDL 컬럼 파서는 **빈 집합을 내지 않는다**(빈 집합이면 「불일치 0」이 거짓으로 참이 된다).
   ㉣ 주석 처리된 `CREATE TABLE` 은 분모에 들어가지 않는다.
   ㉤ `column_report` 는 라이브 부재·컬럼 누락을 **양쪽 방향으로** 잡는다.
   ㉥ 분모 3종(SILVER·GOLD·SV)은 **하나라도 0 이면 FAIL** 이다.

🟢 라이브 접속 없이 돈다 — 파일 파싱과 집합 대조만 시험한다.
"""
import io
import re
import sys
import contextlib
import tempfile
from pathlib import Path

sys.path.insert(0, '/workspace/scripts')
import o125_layer_census as C  # noqa: E402

ROOT = Path('/workspace')
results = []


def check(name, cond, detail=''):
    results.append((name, cond, detail))
    print(('  🟢 PASS  ' if cond else '  🔴 FAIL  ') + name
          + ('  — %s' % detail if detail else ''))


def quiet(fn, *a, **kw):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        out = fn(*a, **kw)
    return out, buf.getvalue()


print('=' * 72)
print('축1 — SV 추출기가 정본 문법(CREATE OR ALTER)을 보는가')
print('=' * 72)
sv = C.sv_names_from_files()
check('SV 분모가 비어 있지 않다', len(sv) > 0, f'{len(sv)}종')
check('실적 SV 표본이 잡힌다', 'SV_MEMBER_MONTHLY' in sv and 'SV_BUDGET' in sv)
check('ML SV 표본이 잡힌다', 'SV_ML_MEMBER_RISK' in sv)

# 오염: 정본 문법을 못 보게 만들면 분모가 무너지는가(초판 재현)
orig_files = C.SV_DIR
with tempfile.TemporaryDirectory() as td:
    src = (ROOT / '05_SV-Agent_ai' / '05_1_SV_DDL_MEMBER_MONTHLY.sql').read_text(
        encoding='utf-8', errors='replace')
    poisoned = re.sub(r'CREATE OR ALTER SEMANTIC VIEW', 'CREATE SEMANTIC_VIEW_X', src)
    (Path(td) / 'poison.sql').write_text(poisoned, encoding='utf-8')
    C.SV_DIR = Path(td)
    try:
        sv_poison = C.sv_names_from_files()
    finally:
        C.SV_DIR = orig_files
check('오염(문법 변형) 시 그 파일에서 SV 가 0 이 된다 — 초판 결함 재현',
      len(sv_poison) == 0, f'{len(sv_poison)}종')

print('=' * 72)
print('축2 — SERVING 뷰 추출은 스키마 한정인가')
print('=' * 72)
views = C.serving_view_names()
check('SERVING 뷰 분모가 비어 있지 않다', len(views) > 0, f'{len(views)}종')
check('GOLD WIDE 뷰가 섞여 들어오지 않는다',
      not any(v.startswith('WIDE_') for v in views), ','.join(sorted(views))[:60])

print('=' * 72)
print('축3·4 — DDL 컬럼 파서(빈 집합 금지 · 주석 CREATE 제외)')
print('=' * 72)
gold = C.ddl_table_columns(ROOT / '03_top-down_gold' / '06_DDL.sql', 'GOLD')
silver = C.ddl_table_columns(
    ROOT / '04_silver_design' / '08_SILVER_테이블DDL_20260714.sql', 'SILVER')
check('GOLD DDL 분모가 비어 있지 않다', len(gold) > 0, f'{len(gold)}개')
check('SILVER DDL 분모가 비어 있지 않다', len(silver) > 0, f'{len(silver)}개')
check('GOLD 테이블 중 컬럼 빈 집합 0',
      all(len(v) > 0 for v in gold.values()))
check('SILVER 테이블 중 컬럼 빈 집합 0',
      all(len(v) > 0 for v in silver.values()))
check('주석 처리된 CREATE TABLE 은 분모에 없다(BIGQUERY_REFINED_DATA)',
      'BIGQUERY_REFINED_DATA' not in silver)
check('표본 컬럼수가 다른 게이트 실측과 일치한다(37·38)',
      len(gold.get('DIM_MEMBER_ACQUISITION', ())) == 37
      and len(gold.get('FACT_SERVICE_EVENT', ())) == 38)

print('=' * 72)
print('축5 — column_report 가 누락·부재를 양방향으로 잡는가')
print('=' * 72)
bad_missing, _ = quiet(C.column_report, 'T', {'A': {'X', 'Y'}}, {'A': {'X'}})
check('라이브에 컬럼이 없으면 불일치로 센다', bad_missing == 1, f'{bad_missing}')
bad_extra, _ = quiet(C.column_report, 'T', {'A': {'X'}}, {'A': {'X', 'Z'}})
check('DDL 밖 컬럼도 불일치로 센다', bad_extra == 1, f'{bad_extra}')
bad_absent, _ = quiet(C.column_report, 'T', {'A': {'X'}}, {})
check('라이브 테이블 부재를 잡는다', bad_absent == 1, f'{bad_absent}')
bad_ok, _ = quiet(C.column_report, 'T', {'A': {'X'}}, {'A': {'X'}})
check('일치는 0 을 낸다(재현율 축)', bad_ok == 0, f'{bad_ok}')

print('=' * 72)
print('축6 — 모델 분모 3종이 하나라도 0 이면 FAIL')
print('=' * 72)
for sub in ('silver', 'gold/dim', 'gold/fact', 'gold/wide'):
    n = len(C.model_names(sub))
    check(f'models/{sub} 분모 > 0', n > 0, f'{n}개')

print('=' * 72)
fails = [r for r in results if not r[1]]
print(f'단정 {len(results)}개 · 실패 {len(fails)}개')
if fails:
    for name, _, detail in fails:
        print(f'  🔴 {name} {detail}')
    print('🔴 FAIL')
    sys.exit(1)
print('🟢 PASS')
