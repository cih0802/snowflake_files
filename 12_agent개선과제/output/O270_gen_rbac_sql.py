"""O270 W4 — 48_RBAC_SOURCE_ACCESS.sql 생성기(일회성 · 게이트 아님 · 2026-10-29 O270-F).
입력 ① 12_agent개선과제/output/O270_source_class.csv (W1 분류표)
     ② 12_agent개선과제/output/O270_live_object_types_ZS83821_20261029.txt (GOLD·SERVING 실측 유형)
출력 05_SV-Agent_ai/48_RBAC_SOURCE_ACCESS.sql
🔴 분류표에 없는 라이브 객체는 GRANT 하지 않고 「미분류」로 머리 주석에 나열한다(fail-safe).
🆕 [O271-A] 인자 --types <유형 파일> --out <출력 파일> --account <계정 표기>(기본값 = 개발계 · 기본 출력은 종전과 바이트 동일)
    운영계 판 = --types 12_agent개선과제/output/O270_live_object_types_ZL50263.txt
                --out 05_SV-Agent_ai/48_RBAC_SOURCE_ACCESS_ZL50263.sql --account ZL50263
"""
import argparse, csv, os
W = '/workspace'
ap = argparse.ArgumentParser()
ap.add_argument('--types', default='12_agent개선과제/output/O270_live_object_types_ZS83821_20261029.txt')
ap.add_argument('--out', default='05_SV-Agent_ai/48_RBAC_SOURCE_ACCESS.sql')
ap.add_argument('--account', default=None, help='머리 주석 계정 표기(기본 = 생략 · 개발계 판과 동일 출력)')
args = ap.parse_args()
TYPES = args.types if os.path.isabs(args.types) else os.path.join(W, args.types)
OUT = args.out if os.path.isabs(args.out) else os.path.join(W, args.out)
cls = {}
for r in csv.DictReader(open(W + '/12_agent개선과제/output/O270_source_class.csv', encoding='utf-8')):
    cls[(r['layer'], r['object'])] = r['source_class']
live = []
for line in open(TYPES, encoding='utf-8'):
    k, t = line.strip().split('|')
    s, n = k.split('.')
    live.append((s, n, t))
AR = {'COMMON': 'GN_DW_AR_SRC_COMMON', 'AGENCY': 'GN_DW_AR_SRC_AGENCY',
      'ERP': 'GN_DW_AR_SRC_ERP', 'AGENCY+ERP': 'GN_DW_AR_SRC_AGENCY_ERP'}
FR = [  # (기능 역할, 접근 역할 집합, Agent, 설명)
    ('GN_DW_FR_MARKETING', ['COMMON', 'AGENCY', 'ERP', 'AGENCY+ERP'], 'AGENT_MARKETING', '마케팅 분석가 — AGENCY·ERP·공통'),
    ('GN_DW_FR_MEMBER', ['COMMON'], 'AGENT_MEMBER', '회원 분석가 — 공통만'),
    ('GN_DW_FR_EXEC', ['COMMON', 'ERP'], 'AGENT_EXECUTIVE', '기획실(경영·전사) 분석가 — ERP·공통'),
    ('GN_DW_FR_LEAD', [], None, '팀장급 VIEWER — Streamlit 전용 · SV·테이블·Agent GRANT 0'),
]
# 🟠 미배선 예외: 검색 코퍼스(SERVING.BIZ_DEFINITION_CORPUS)는 dbt 밖 · 분류표 미등재 ⇒ C7 점검 전 COMMON 으로 둔다
EXTRA = {('SERVING', 'BIZ_DEFINITION_CORPUS'): 'COMMON',
         ('GOLD', 'ORG_SUCCESSION_MANUAL'): 'COMMON'}  # dbt seed(조직 승계 수기) · 2026-10-29 사용자 승인 일괄
grants = {a: [] for a in AR}
unclassified = []
for s, n, t in live:
    c = cls.get((s, n)) or EXTRA.get((s, n))
    if c is None:
        unclassified.append('%s.%s' % (s, n))
        continue
    grants[c].append('GRANT SELECT ON %s GN_DW.%s.%s TO ROLE %s;' % (t, s, n, AR[c]))
svs = sorted((k[1], v) for k, v in cls.items() if k[0] == 'SERVING' and k[1].startswith('SV_'))
for n, c in svs:
    grants[c].append('GRANT SELECT, REFERENCES ON SEMANTIC VIEW GN_DW.SERVING.%s TO ROLE %s;' % (n, AR[c]))
L = []
A = L.append
A('-- =============================================================================')
A('-- 48_RBAC_SOURCE_ACCESS.sql — 원천별 접근통제(접근 역할 4 · 기능 역할 4)')
A('-- O270-F · 2026-10-29 · 생성기 = 12_agent개선과제/output/O270_gen_rbac_sql.py (손으로 고치지 말고 재생성)')
A('-- 정본 분류표 = 12_agent개선과제/output/O270_source_class.csv (W1 · dbt ref/source + OBJECT_DEPENDENCIES)')
A('-- 계획서 = 12_agent개선과제/O270_원천별_접근통제_작업계획.md (C1~C9 · W4)')
if args.account:
    A('-- 🔴 계정 판 = %s · 유형 파일 = %s · 개발계 판(48_RBAC_SOURCE_ACCESS.sql)과 별도 파일'
      % (args.account, os.path.relpath(TYPES, W)))
    A('-- 🔴 미분류 객체는 원천 판정(R98) 결정 전까지 GRANT 하지 않는다 — 이름으로 분류하지 마라')
A('--')
A('-- 블록 = [1] 역할 생성 [2] 접근 역할 GRANT [3] 기능 역할 조립 [4] 사용자 배정 템플릿')
A('--        [5] 검증 [6] 기존 역할 회수(🔴 W8 전 실행 금지) [7] 롤백')
A('-- 🔴 실행 = SECURITYADMIN · 블록 [1]~[3] 만 개발계 승인 후 실행(R4-4-3) · [6] 은 운영계 실측(W8) 전 금지')
A('-- 🔴 FUTURE GRANT 는 쓰지 않는다 — GOLD·SERVING 에 AGENCY·ERP·공통 객체가 섞여 있어 스키마 단위로 가를 수 없다')
A('--    ⇒ 재빌드 유지는 W5(㉢) = dbt grants config(dbt 객체) + SV·SERVING 뷰 DDL 파일 GRANT 줄')
A('-- 🔴 BRONZE·SILVER·ML·MSTR 스키마는 기능 역할에 주지 않는다 — SERVING 뷰는 소유자 권한으로 하위를 읽는다')
A('--    · Agent(Analyst)는 SV base 테이블(GOLD·SERVING 뷰)에 SQL 을 직접 실행하므로 SV 와 base 를 같은 분류로 준다(C3)')
A('-- 미분류(라이브에 있으나 분류표에 없음 · GRANT 하지 않음) = %d건' % len(unclassified))
for u in unclassified:
    A('--   · ' + u)
A('-- =============================================================================')
A('')
A('USE ROLE SECURITYADMIN;')
A('')
A('-- [1] 역할 생성 ---------------------------------------------------------------')
for c, a in AR.items():
    A("CREATE ROLE IF NOT EXISTS %s COMMENT = 'O270 접근 역할 — 원천 %s 유래 객체 SELECT';" % (a, c))
for f, ars, ag, d in FR:
    A("CREATE ROLE IF NOT EXISTS %s COMMENT = 'O270 기능 역할 — %s · 1인 1기능역할';" % (f, d))
for f, *_ in FR:
    A('GRANT ROLE %s TO ROLE SYSADMIN;' % f)
A('')
A('-- [2] 접근 역할 GRANT ---------------------------------------------------------')
for c, a in AR.items():
    A('-- %s (%s) · 객체 %d' % (a, c, len(grants[c])))
    A('GRANT USAGE ON DATABASE GN_DW TO ROLE %s;' % a)
    A('GRANT USAGE ON SCHEMA GN_DW.GOLD TO ROLE %s;' % a)
    A('GRANT USAGE ON SCHEMA GN_DW.SERVING TO ROLE %s;' % a)
    if c == 'COMMON':
        A('-- 🟠 C7 점검 전 잠정: 지표사전 검색 코퍼스는 3 Agent 공용')
        A('GRANT USAGE ON CORTEX SEARCH SERVICE GN_DW.SERVING.SEARCH_BIZ_DEFINITION TO ROLE %s;' % a)
    L.extend(grants[c])
    A('')
A('-- [3] 기능 역할 조립 ----------------------------------------------------------')
for f, ars, ag, d in FR:
    A('-- %s = %s' % (f, d))
    for c in ars:
        A('GRANT ROLE %s TO ROLE %s;' % (AR[c], f))
    if ag:
        A('GRANT USAGE ON WAREHOUSE GN_DW_ANALYTICS_WH TO ROLE %s;' % f)
        A('GRANT USAGE ON AGENT GN_DW.SERVING.%s TO ROLE %s;' % (ag, f))
    else:
        A('-- Streamlit USAGE 는 W8 실측(소유자/호출자 권한 · 앱 목록) 후 추가 · 개발계 Streamlit 0')
        A('-- 🔴 SV·테이블·Agent GRANT 0 유지 — CORTEX_USER(PUBLIC 기본)가 있어도 조회할 객체가 없다(C5)')
    A('')
A('-- [4] 사용자 배정 템플릿(🔴 1인 1기능역할 · C1) — 개발계 배정 사용자 0 · 운영계는 W8 실행카드에서 채운다')
A('-- GRANT ROLE GN_DW_FR_MEMBER TO USER <사용자>;')
A("-- ALTER USER <사용자> SET DEFAULT_ROLE = 'GN_DW_FR_MEMBER';")
A('-- ALTER USER <사용자> SET DEFAULT_SECONDARY_ROLES = ();   -- 🔴 보조 역할 합집합 차단(정책 결정 필요)')
A('')
A('-- [5] 검증(개발계 W6) — 보조 역할 끈 상태와 켠 상태 두 번')
for f, ars, ag, d in FR:
    A('-- SHOW GRANTS TO ROLE %s;' % f)
A('-- USE ROLE GN_DW_FR_MEMBER; USE SECONDARY ROLES NONE;')
A('-- SELECT COUNT(*) FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY;          -- 기대 OK')
A('-- SELECT COUNT(*) FROM GN_DW.GOLD.WIDE_AD_COMBINED;             -- 기대 권한 없음')
A('-- SELECT COUNT(*) FROM GN_DW.GOLD.FACT_BUDGET;                  -- 기대 권한 없음')
A('-- USE ROLE GN_DW_FR_EXEC; USE SECONDARY ROLES NONE;')
A('-- SELECT COUNT(*) FROM GN_DW.GOLD.FACT_BUDGET;                  -- 기대 OK')
A('-- SELECT COUNT(*) FROM GN_DW.SERVING.ML_REALTIME_SIMULATOR_V;   -- 기대 권한 없음')
A('-- USE ROLE GN_DW_FR_MARKETING; USE SECONDARY ROLES NONE;')
A('-- SELECT COUNT(*) FROM GN_DW.GOLD.FACT_MKTG_CAMPAIGN_MONTHLY_COST; -- 기대 OK')
A('-- USE ROLE GN_DW_FR_LEAD; USE SECONDARY ROLES NONE;')
A('-- SELECT COUNT(*) FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY;          -- 기대 권한 없음')
A('')
A('-- [6] 기존 역할 회수 — 🔴🔴 W8(운영계 사용자·GN_DW_SERVICE 의존·Streamlit 권한 방식) 실측 전 실행 금지')
A('-- 순서 = 신 역할 배정 → W6 검증 → dbt grants 에서 구 역할 제거 → 아래 회수')
A('-- REVOKE SELECT ON ALL TABLES IN SCHEMA GN_DW.BRONZE_AGENCY FROM ROLE GN_DW_ANALYST;')
A('-- REVOKE SELECT ON ALL TABLES IN SCHEMA GN_DW.BRONZE_ERP FROM ROLE GN_DW_ANALYST;')
A('-- (GN_DW_VIEWER · GN_DW_ANALYST 의 GOLD·SERVING·SV 회수 목록은 W8 실행카드에서 확정)')
A('')
A('-- [7] 롤백 — 이 파일이 만든 역할만 제거(구 역할 무변경) · 🔴 별도 승인')
for f, *_ in FR:
    A('-- DROP ROLE IF EXISTS %s;' % f)
for a in AR.values():
    A('-- DROP ROLE IF EXISTS %s;' % a)
open(OUT, 'w', encoding='utf-8').write('\n'.join(L) + '\n')
print({c: len(g) for c, g in grants.items()}, 'unclassified', unclassified, 'lines', len(L))
