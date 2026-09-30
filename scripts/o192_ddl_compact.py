#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""DDL 정본 압축기(O192) — 새 환경 재구축용으로 DDL 파일을 「CREATE 1벌 + 제약 절」 형태로 정리한다.

하는 일
  · 이관용 `ALTER TABLE … ADD COLUMN` 제거 — CREATE 본문과 타입·COMMENT 가 **완전 일치**할 때만(불일치 1건이면 중단).
  · 설계·실측 이력 주석을 본문에서 빼 **부록 md 로 원문 이관**(정보 소실 0 · 삭제가 아니라 이동).
  · 컬럼 COMMENT 말미의 세션 태그(` · O191-F …`) 제거 · `[원천 COMMENT · X]` → `[원천: X]`.
  · 업무 규칙 주석만 `KEEP_NOTES` 로 짧게 남긴다(사람 판정 등재부).
  · GOLD: 제약(`ADD CONSTRAINT`)은 원문 그대로 파일 말미 제약 절에 모으고, FK 선(先)삭제 멱등 블록은
    **실제 제약 목록에서 재생성**한다(종전 블록은 제약 추가를 따라가지 못해 23건이 빠져 있었다).
판정(쓰기 전 자체 대조 · 하나라도 어긋나면 파일을 쓰지 않는다)
  테이블 집합 · 컬럼 순서·이름·타입/제약 · COMMENT(태그 정리 규칙 적용 후) · 테이블 COMMENT · 제약 문장 집합.
사용법
  python3 scripts/o192_ddl_compact.py --layer gold             # dry-run(tmp/ 에 결과 · 대조만)
  python3 scripts/o192_ddl_compact.py --layer gold --write --label O192-A
Co-authored with CoCo
"""
import argparse
import io
import os
import re
import sys

sys.path.insert(0, '/workspace/scripts')
from snapshot_util import snapshot, ARCHIVE  # noqa: E402

ROOT = '/workspace'

RE_CREATE = re.compile(r'^CREATE OR REPLACE TABLE GN_DW\.(\w+)\.(\w+)\s*\($')
RE_ADDCOL = re.compile(r"^ALTER TABLE GN_DW\.(\w+)\.(\w+) ADD COLUMN IF NOT EXISTS (\w+) (.+?) COMMENT '((?:[^']|'')*)';\s*$")
RE_CONSTR = re.compile(r'^ALTER TABLE GN_DW\.(\w+)\.(\w+) ADD CONSTRAINT (\w+)')
RE_COLLINE = re.compile(r"^(\s+)([A-Z][A-Z0-9_]*)(\s+)(.*?)COMMENT '((?:[^']|'')*)'(,?)(\s*--.*)?$")
RE_TAIL = re.compile(r"\s*·\s*O\d{2,3}(?:-[A-Z]{1,2})?(?:\s[^'·]*)?$")
RE_SRC = re.compile(r"\[원천 COMMENT · ")


def clean_comment(lit):
    """컬럼 COMMENT 리터럴(저장 표현) 정리 — 세션 태그 제거 · 원천 표기 단축."""
    prev = None
    while prev != lit:
        prev = lit
        lit = RE_TAIL.sub('', lit)
    return RE_SRC.sub('[원천: ', lit).rstrip()


# ── 계층별 설정 · 사람 판정 등재부 ─────────────────────────────────────────────
HEADER_SILVER = """\
-- ============================================================================
-- GN_DW.SILVER 테이블 DDL — 구조 정본(타입 · PK · COMMENT)
--   · dbt SILVER 모델과 1:1(구조 = 이 파일 · 데이터 = dbt). 적재 쿼리 = 09_SILVER_적재쿼리.
--   · 실행 = GN_DW_ADMIN · 새 환경은 이 파일 전체 실행 → dbt build.
--   · 🔴 재실행하면 데이터가 비워진다. 증분 모델은 재실행 뒤 반드시 백필한다
--       GA4 = build --select BIGQUERY_BASIC+ --vars '{"bigquery_dt_ranges": [["2024-01-01", "9999-12-31"]]}'
--       그 밖 = build --select <모델>+ --full-refresh
--   · 설계근거·실측 이력 = 08_SILVER_DDL_설계이력_부록.md · 이슈 원장 = 20_issue/00_INDEX_이슈원장.md
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE DATABASE GN_DW;
CREATE SCHEMA IF NOT EXISTS GN_DW.SILVER
    WITH MANAGED ACCESS
    COMMENT = 'Silver 레이어 — Bronze(CRM·BIGQUERY·ERP·AGENCY) 정제/변환 객체 (GOLD 입력용)';
USE SCHEMA GN_DW.SILVER;
"""

HEADER_GOLD = """\
-- ============================================================================
-- GN_DW.GOLD 테이블 DDL — 구조 정본(타입 · COMMENT · PK/FK)
--   · 구성 = CREATE(DIM → FACT) → 제약 절(PK 보강 · 정보성 FK · NOT ENFORCED).
--   · 실행 = GN_DW_ADMIN · 새 환경은 이 파일 전체 실행 → dbt build.
--   · 🔴 적재된 환경에서 전체 재실행 금지 — CREATE OR REPLACE 가 데이터·FK·GRANT 를 지운다.
--       FK 만 다시 걸 때는 제약 절만 실행한다(선삭제 블록이 있어 멱등).
--   · 🔴 FK 는 참조 PK 와 타입이 정확히 같아야 한다(폭이 넓어도 실패):
--       *_DATE_SK NUMBER(8,0) · MONTH_KEY NUMBER(6,0) · *_SK NUMBER(38,0) · MEMBER_DK VARCHAR(10).
--   · 뷰(WIDE_* · DIM_MEMBER_ACQUISITION 계열 뷰)는 dbt 모델 소관 — 이 파일에서 만들지 않는다.
--   · 설계근거·실측 이력 = 06_DDL_설계이력_부록.md · 이슈 원장 = 20_issue/00_INDEX_이슈원장.md
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE DATABASE GN_DW;
CREATE SCHEMA IF NOT EXISTS GN_DW.GOLD
    WITH MANAGED ACCESS
    COMMENT = '분석 View + Semantic View + Agent + 예측 테이블 + Streamlit';
GRANT CREATE VIEW ON SCHEMA GN_DW.GOLD TO ROLE GN_DW_ENGINEER;
USE SCHEMA GOLD;
"""

GOLD_CONSTRAINT_NOTES = [
    'FK 미선언 축(참조 대상이 비유일) — 조인 경로를 지킨다:',
    '  · MEMBER_DK → DIM_MEMBER_STATUS_HISTORY(SCD2 다중버전) = IS_CURRENT 또는 유효구간 매칭. 현재행은 DIM_MEMBER.',
    '  · MONTH_KEY → DIM_MONTH(월 conform). DIM_DATE 직접 조인은 월당 일수만큼 증폭된다.',
    '  · 이 축의 논리 관계 정본 = scripts/gold_erd_coverage_gate.py 의 LOGICAL_FK.',
    '위성 광고 팩트 → 코어 FACT_AD_PERFORMANCE FK 는 수직 분할이라 선언한다(FAD_B·FAD_D 1:1 · FAD_BC 1:N).',
]
GOLD_VERIFY = """\
-- 검증(값이 아니라 방법이 정본이다 — 기대 건수를 여기 적지 않는다)
--   파일 선언 테이블 = grep -oE 'CREATE OR REPLACE TABLE GN_DW\\.GOLD\\.[A-Z_]+' 06_DDL.sql | sort -u | wc -l
--   파일 FK/PK      = grep -cE '^ALTER TABLE GN_DW\\.GOLD\\.[A-Z_]+ ADD CONSTRAINT' 06_DDL.sql
--   라이브 대조     = python3 scripts/gold_erd_coverage_gate.py
SHOW IMPORTED KEYS IN SCHEMA GN_DW.GOLD;
"""

CFG = {
    'silver': dict(
        ddl=f'{ROOT}/04_silver_design/08_SILVER_테이블DDL_20260714.sql',
        appendix=f'{ROOT}/04_silver_design/08_SILVER_DDL_설계이력_부록.md',
        schema='SILVER', header=HEADER_SILVER,
        groups=[('CRM', 'CRM_'), ('ERP', 'ERP_'), ('AGENCY', 'AGENCY_'), ('BIGQUERY', 'BIGQUERY_'),
                ('IDENTITY', 'IDENTITY_')],
        titles={'CRM': 'CRM', 'ERP': 'ERP', 'AGENCY': 'AGENCY (코어·staging·위성)',
                'BIGQUERY': 'BIGQUERY (GA4)', 'IDENTITY': '신원 브리지 (교차소스 유일 예외)'},
        section_notes={
            'AGENCY': [
                'AD_PERF_DK 는 staging 3종(AGENCY_AD_ROW_*)에서만 발급한다 — 코어·위성·GOLD 는 승계만(재계산 금지).',
                'staging 은 BRONZE 컬럼명·타입을 그대로 보존한다(개명·형변환 금지 · 정제는 코어/위성).',
                '텍스트 시간축(YEAR·MONTH 등) 파싱 금지 — DATE 컬럼에서 파생. 예외 DGT 는 코어에서만 '
                'COALESCE(DATE, TRY_TO_DATE(…)) 폴백. DATE_FROM_PARTS 금지(불량 월/일 롤오버).',
            ],
            'BIGQUERY': [
                '입력 = source(silver_external.BIGQUERY_REFINED_DATA) — 외부 Python 적재 테이블이라 이 파일에서 만들지 않는다.',
            ],
        },
        keep_notes={
            'CRM_CAMPAIGN': ['유형1 = 국내/통합/해외 · 유형2 = 굿즈/기타/사례/사업 — 혼동 금지.',
                             '코드사전 미등재(고아) 코드는 라벨 NULL 로 둔다.'],
            'CRM_SEND_REQUEST': ['복합 PK 전환은 09 적재쿼리 상단 ALTER 가 한다(이 파일은 단일 PK).'],
            'CRM_SEND_MEMBER': ['복합 PK 전환은 09 적재쿼리 상단 ALTER 가 한다(이 파일은 단일 PK).',
                                'OPEN_DT = SND_MEMBER_OPEN_LOG 의 회원×발송별 MIN(OPEN_DT).'],
            'CRM_BIZ_TARGET': ['GOAL_TYPE_NM 유형(연사업·팀)은 같은 목표의 다른 분해다 — 섞어 합산 금지.'],
            'CRM_MEMBER_SPONSOR_SPAN': ['월말활동회원(#51) as-of 판정용 활동구간.'],
            'ERP_BUDGET_YEARLY': ['연 총액 grain — 월 grain 인 ERP_BUDGET 에 합치면 12배 과대.'],
            'AGENCY_AD_PERFORMANCE': ['상위캠페인 자리에 utm 을 넣지 않는다(utm 은 AGENCY_AD_ROW_DGT 에 보존).'],
            'AGENCY_AD_BROADCAST': ['[VIDEO 전용]/[REBRDC 전용] 컬럼의 NULL = 해당 원천에 항목 없음 — 비율 분모는 해당 원천 행만.',
                                    '시간 파싱에 TRY_TO_TIME 금지(값을 조용히 바꾼다) · 숫자 3종은 단위 미확정이라 NULL.'],
            'BIGQUERY_BASIC': ['EVENT_SEQ 는 PK 유일성만 보장 — 재실행 간 순번 안정성은 미보장(GA4-SEQ-1).'],
            'BIGQUERY_EVENT': ['EVENT_SEQ 는 PK 유일성만 보장 — 재실행 간 순번 안정성은 미보장(GA4-SEQ-1).'],
            'IDENTITY_MEMBER_XREF': ['grain = 1행/USER_PSEUDO_ID(회원 grain 아님) — GOLD 는 MEMBER_DK DISTINCT + UNMATCHED 제외.',
                                     'FACT 결합은 LEFT JOIN(익명 세션이 대부분).'],
        },
    ),
    'gold': dict(
        ddl=f'{ROOT}/03_top-down_gold/06_DDL.sql',
        appendix=f'{ROOT}/03_top-down_gold/06_DDL_설계이력_부록.md',
        schema='GOLD', header=HEADER_GOLD,
        # 사람 판정(O192): CREATE 문안이 O190 에서 개정됐고 ALTER 는 O188-E 옛 문안 · 타입 동일
        stale_alter_ok={('FACT_TARGET_PROJECT', 'SRC_SPONSOR_BIZ_NM'), ('FACT_TARGET_PROJECT', 'NEW_OLD_DIV_NM'),
                        ('FACT_TARGET_PROJECT', 'DTL_DIV_NM')},
        groups=[('DIM', 'DIM_'), ('FACT', 'FACT_')],
        titles={'DIM': 'DIM — 차원', 'FACT': 'FACT — 팩트'},
        section_notes={
            'DIM': ['완전 재산출 차원(DIM_MONTH·DIM_MEMBER·DIM_MEMBER_ACQUISITION 등)에 merge 금지 — grain 이동 시 구 행이 남는다.'],
            'FACT': ['분석축 SK 의 0 = (미매핑) 센티넬 멤버다 — 「없음」이 아니다.'],
        },
        keep_notes={
            'DIM_MONTH': ['월 팩트는 DIM_DATE 를 직접 조인하지 말고 이 차원을 쓴다(일 grain 증폭 방지).'],
            'DIM_MEMBER_ACQUISITION': ['1행 = 1회원 — 팩트 조인은 MEMBER_DK LEFT JOIN(INNER 는 회원을 잃는다).'],
            'DIM_MARKETING_CAMPAIGN': ['광고(AGENCY) ↔ CRM 결합이 성립하는 유일한 grain.',
                                       'DEV_CAMPAIGN_CNT > 1 이면 개발캠페인 단위로 광고비를 내릴 때 그 배수만큼 복제된다.'],
            'DIM_SEND_TYPE': ['자연키 = (대,중,소) 전체 경로 — 중분류 코드 단독은 모호하다.'],
            'FACT_MEMBER_EVENT': ['SPONSORSHIP_SK · ORG_SK 는 DEV 사건 전용 배선 — STOP 행은 0(부서별 중단건을 이 축으로 내지 않는다).'],
            'FACT_MESSAGE_DISPATCH': ['SEND_STATUS 는 채널별 코드체계가 한 컬럼에 섞여 있다 — SEND_TYPE 동반 필수.'],
            'FACT_AD_BROADCAST': ['코어와 1:1(AD_PERF_DK) · NULL = 두 방송 원천 중 한쪽 전용 속성(결측 아님).'],
            'FACT_AD_DIGITAL': ['코어와 1:1(AD_PERF_DK) · _SRC 컬럼 = 대행사 계산값(비율·단가) — 재합산 금지.'],
            'FACT_AD_BROADCAST_CASE': ['코어에 1:N(AD_PERF_DK × CASE_SEQ) — 코어 measure 와 함께 집계하면 사례 수만큼 중복.'],
            'FACT_MEMBER_FEE': ['PK 미선언 — grain 키 FEE_DIV_CD 가 기부금 행에서 NULL. 유일성은 dbt GROUP BY 가 보증.'],
        },
    ),
}


def parse(path, schema):
    """파일을 테이블 · ALTER ADD · 제약 · 기타로 나눈다. 테이블 앞 주석은 그 테이블의 이력으로 묶는다."""
    lines = io.open(path, encoding='utf-8').read().split('\n')
    tables, order, adds, constrs, header, other = {}, [], [], [], [], []
    pending, i, seen_create = [], 0, False
    while i < len(lines):
        ln = lines[i]
        m = RE_CREATE.match(ln)
        if m and m.group(1) == schema:
            seen_create = True
            name, body = m.group(2), [ln]
            i += 1
            while True:
                body.append(lines[i])
                s = lines[i].strip()
                if (s.startswith(')') or s.startswith('COMMENT')) and s.endswith(';'):
                    break
                i += 1
            assert name not in tables, name
            tables[name] = dict(body=body, notes=pending)
            order.append(name)
            pending = []
        elif RE_ADDCOL.match(ln):
            adds.append(RE_ADDCOL.match(ln).groups())
        elif RE_CONSTR.match(ln):
            stmt = [ln]
            while not stmt[-1].rstrip().endswith(';'):
                i += 1
                stmt.append(lines[i])
            constrs.append('\n'.join(x.rstrip() for x in stmt))
        elif not seen_create:
            header.append(ln)
        elif ln.startswith(('EXECUTE IMMEDIATE', 'SELECT', 'SHOW ')):
            stmt = [ln]
            end = '$$;' if ln.startswith('EXECUTE') else ';'
            while not stmt[-1].rstrip().endswith(end):
                i += 1
                stmt.append(lines[i])
            other.append('\n'.join(stmt))
        elif ln.startswith('USE ROLE') or ln.strip() == '':
            pass
        else:
            pending.append(ln)
        i += 1
    return tables, order, adds, constrs, header, other, pending


def cols(body):
    out = []
    for ln in body[1:-1]:
        m = RE_COLLINE.match(ln)
        if m:
            out.append((m.group(2), re.sub(r'\s+', ' ', m.group(4)).strip(), m.group(5)))
        elif ln.strip() and not ln.strip().startswith('--'):
            out.append(('#', re.sub(r'\s+', ' ', ln).strip(), ''))
    return out


def table_comment(body):
    m = re.search(r"COMMENT\s*=\s*'((?:[^']|'')*)'", '\n'.join(body[-2:]))
    return m.group(1) if m else ''


def rebuild_body(body, dropped):
    """본문 속 주석 줄·줄끝 주석을 걷어내고 컬럼 COMMENT 를 정리한다(순서 불변)."""
    out = [body[0]]
    for ln in body[1:-1]:
        if ln.strip().startswith('--'):
            dropped.append(ln)
            continue
        m = RE_COLLINE.match(ln)
        if m:
            if m.group(7):
                dropped.append(f'{m.group(2)}:{m.group(7).strip()}')
            ln = f"{m.group(1)}{m.group(2)}{m.group(3)}{m.group(4)}COMMENT '{clean_comment(m.group(5))}'{m.group(6)}"
        out.append(ln.rstrip())
    out.append(body[-1])
    return out


def keep_body_notes(notes, cfg):
    """이미 압축된 파일을 다시 돌릴 때(멱등) — 테이블 앞 `--   ⚠️` 줄은 등재부 밖 문안도 보존한다.
    🔴 섹션 주석은 제외한다 — 섹션 머리가 첫 테이블 앞 주석으로 흡수돼 재실행마다 복제된다(O192 자기적발)."""
    section = {x for v in cfg['section_notes'].values() for x in v}
    out = []
    for x in notes:
        s = x.strip()
        if s.startswith('--   ⚠️ ') or s.startswith('-- ⚠️ '):
            body = s.split('⚠️ ', 1)[1]
            if body not in section:
                out.append(body)
    return out


def is_generated(line, cfg):
    """압축기가 만든 줄인가(섹션 괘선·제목) — 부록 이력에 넣지 않는다."""
    s = line.strip()
    return (s.startswith('-- ===') or s[3:] in cfg['titles'].values() or s.startswith('-- ⚠️ ')
            or s.startswith('--   ⚠️ '))


def fk_drop_block(constrs):
    rows = []
    for c in constrs:
        _, t, name = RE_CONSTR.match(c).groups()
        rows.append(f'  BEGIN ALTER TABLE GN_DW.GOLD.{t} DROP CONSTRAINT {name}; EXCEPTION WHEN OTHER THEN NULL; END;')
    return ('-- 멱등화: 같은 이름 제약을 먼저 지운다(Snowflake 는 DROP CONSTRAINT IF EXISTS 미지원 · 목록 = 아래 ADD 전건)\n'
            'EXECUTE IMMEDIATE $$\nBEGIN\n' + '\n'.join(rows) + "\n  RETURN 'constraint drop (idempotent) done';\nEND;\n$$;")


def build(layer):
    cfg = CFG[layer]
    tables, order, adds, constrs, header, other, tail = parse(cfg['ddl'], cfg['schema'])
    bad, stale = [], []
    for sch, t, c, ty, cm in adds:
        hit = [x for x in cols(tables[t]['body']) if x[0] == c]
        if not hit or not hit[0][1].upper().startswith(ty.upper().split()[0]):
            bad.append((t, c))
        elif hit[0][2] != cm:
            # 타입은 같고 COMMENT 만 다르다 = CREATE 가 뒤에 개정됐다. `ADD COLUMN IF NOT EXISTS` 는 기존 컬럼에
            # 아무것도 하지 않으므로 ALTER 문안은 적용된 적이 없다 ⇒ CREATE 가 정본 · 사람 판정 등재분만 허용.
            if (t, c) not in cfg.get('stale_alter_ok', set()):
                bad.append((t, c))
            stale.append(f'- `{t}.{c}` — ALTER 문안(버림): {cm}')
    if bad:
        raise SystemExit(f'🔴 ALTER ADD ↔ CREATE 불일치 {len(bad)}건 — 중단: {bad[:5]}')
    unknown = set(cfg['keep_notes']) - set(tables)
    if unknown:
        raise SystemExit(f'🔴 keep_notes 에 없는 테이블: {unknown}')
    out, appendix = [cfg['header'].rstrip('\n')], []
    # 이미 압축된 판본(머리말 표지 = 「구조 정본」)을 다시 돌릴 때만 본문 `⚠️` 줄을 보존한다.
    # 🔴 원본에 적용하면 이력 태그·수치가 섞인 옛 경고가 그대로 따라온다(O192 자기적발).
    compacted = any('구조 정본' in x for x in header)
    if any(x.strip() for x in header) and not compacted:
        appendix.append('## 0. 파일 머리말(원문)\n\n```sql\n' + '\n'.join(header).strip('\n') + '\n```\n')
    placed = set()
    for g, prefix in cfg['groups']:
        names = [n for n in order if n.startswith(prefix)]
        if not names:
            continue
        out += ['', '-- ' + '=' * 76, f"-- {cfg['titles'][g]}", '-- ' + '=' * 76]
        for note in cfg['section_notes'].get(g, []):
            out.append(f'--   ⚠️ {note}')
        for n in names:
            tb, dropped = tables[n], []
            body = rebuild_body(tb['body'], dropped)
            desc = table_comment(tb['body']).split('. [')[0].replace("''", "'")
            notes = list(cfg['keep_notes'].get(n, []))
            if compacted:
                notes += [x for x in keep_body_notes(tb['notes'], cfg) if x not in notes]
            out += ['', f'-- {n} — {desc}'] + [f'--   ⚠️ {x}' for x in notes] + body
            hist = [x for x in tb['notes'] if x.strip() and not (compacted and is_generated(x, cfg))
                    and not x.startswith(f'-- {n} — ')] + dropped
            if hist:
                appendix.append(f'## {n}\n\n```text\n' + '\n'.join(hist) + '\n```\n')
            placed.add(n)
    if placed != set(order):
        raise SystemExit(f'🔴 그룹 미정 테이블: {set(order) - placed}')
    if constrs:
        out += ['', '-- ' + '=' * 76, '-- 제약 — PK 보강 · 정보성 FK (NOT ENFORCED · CREATE 전량 뒤에 실행)', '-- ' + '=' * 76]
        out += [f'--   ⚠️ {x}' if not x.startswith('  ') else f'--     {x.strip()}' for x in GOLD_CONSTRAINT_NOTES]
        out += ['', fk_drop_block(constrs), ''] + constrs
    if layer == 'gold':
        out += ['', GOLD_VERIFY.rstrip('\n')]
    if other:
        appendix.append('## 실행문(원문 · 제약 선삭제 블록 · 검증 쿼리)\n\n```sql\n' + '\n\n'.join(other) + '\n```\n')
    if [x for x in tail if x.strip()]:
        appendix.append('## 파일 말미(원문)\n\n```text\n' + '\n'.join(tail) + '\n```\n')
    if stale:
        appendix.append('## ALTER ADD 옛 문안(CREATE 가 뒤에 개정 · 적용된 적 없음)\n\n' + '\n'.join(stale) + '\n')
    new = '\n'.join(out).rstrip('\n') + '\n'
    return tables, adds, constrs, new, appendix


def verify(old_tables, old_constrs, new_text, schema):
    """쓰기 전 대조 — 테이블·컬럼·타입·순서·COMMENT(정리 규칙 적용)·테이블 COMMENT·제약."""
    tmp = '/workspace/tmp/_o192_verify.sql'
    io.open(tmp, 'w', encoding='utf-8').write(new_text)
    new_tables, _, adds, constrs, _, _, _ = parse(tmp, schema)
    errs = []
    if adds:
        errs.append(f'새 파일에 ALTER ADD {len(adds)}건 잔존')
    if set(old_tables) != set(new_tables):
        errs.append(f'테이블 집합 불일치 {set(old_tables) ^ set(new_tables)}')
    for n in old_tables:
        if n not in new_tables:
            continue
        a = [(c, t, clean_comment(m)) for c, t, m in cols(old_tables[n]['body'])]
        if a != cols(new_tables[n]['body']):
            errs.append(f'{n} 컬럼 불일치')
        if table_comment(old_tables[n]['body']) != table_comment(new_tables[n]['body']):
            errs.append(f'{n} 테이블 COMMENT 불일치')
    if sorted(old_constrs) != sorted(constrs):
        errs.append(f'제약 문장 불일치 {len(old_constrs)} → {len(constrs)}')
    if re.search(r'^ALTER TABLE \S+ ADD COLUMN', new_text, re.M):
        errs.append('ALTER ADD COLUMN 잔존')
    long_ = [i + 1 for i, ln in enumerate(new_text.split('\n')) if len(ln) > 2000]
    if long_:
        errs.append(f'2000자 초과 줄 {long_[:5]}')
    return errs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--layer', required=True, choices=sorted(CFG))
    ap.add_argument('--write', action='store_true')
    ap.add_argument('--label')
    a = ap.parse_args()
    cfg = CFG[a.layer]
    old = io.open(cfg['ddl'], encoding='utf-8').read()
    tables, adds, constrs, new, appendix = build(a.layer)
    errs = verify(tables, constrs, new, cfg['schema'])
    oldc = sum(1 for ln in old.split('\n') if ln.strip().startswith('--'))
    newc = sum(1 for ln in new.split('\n') if ln.strip().startswith('--'))
    print(f'테이블 {len(tables)} · ALTER ADD 제거 {len(adds)} · 제약 {len(constrs)} · 줄 {old.count(chr(10))} → '
          f'{new.count(chr(10))} · 주석 줄 {oldc} → {newc} · 부록 절 {len(appendix)}')
    if errs:
        print('🔴 대조 실패 — 쓰지 않는다:', *errs, sep='\n  ')
        return 1
    print('🟢 대조 PASS(테이블·컬럼·타입·순서·COMMENT·테이블 COMMENT·제약)')
    if new == old:
        print('🟢 변경 없음(이미 압축된 판본)')
        return 0
    app_text = ('# ' + os.path.basename(cfg['ddl']) + ' — 설계·실측 이력 부록\n\n'
                '> O192 에서 DDL 본문을 압축하며 **본문에서 뺀 주석을 원문 그대로** 옮긴 것이다(삭제 0).\n'
                '> 🔴 여기 수치는 **그 시점 · 그 계정의 기록**이다 — 현재값으로 인용하지 마라(`R2-8-4`).\n'
                '> 원본 전체 = `_archive/` 스냅샷(O192-A).\n\n' + '\n'.join(appendix) + '\n_Co-authored with CoCo_\n')
    if not a.write:
        io.open(f'/workspace/tmp/o192_{a.layer}.sql', 'w', encoding='utf-8').write(new)
        io.open(f'/workspace/tmp/o192_{a.layer}_부록.md', 'w', encoding='utf-8').write(app_text)
        print(f'dry-run → tmp/o192_{a.layer}.sql · tmp/o192_{a.layer}_부록.md')
        return 0
    if os.path.exists(cfg['appendix']):
        raise SystemExit(f"🔴 부록이 이미 있다 — 덮지 않는다: {cfg['appendix']}")
    print('스냅샷:', snapshot(cfg['ddl'], 'o192-compact', label=a.label, archive=ARCHIVE))
    io.open(cfg['ddl'], 'w', encoding='utf-8').write(new)
    io.open(cfg['appendix'], 'w', encoding='utf-8').write(app_text)
    back = io.open(cfg['ddl'], encoding='utf-8').read()
    print('🟢 쓰기 완료 · 되읽기 일치' if back == new else '🔴 되읽기 불일치')
    return 0


if __name__ == '__main__':
    sys.exit(main())
