#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ML SERVING 뷰 DDL 압축기(O192) — `21_ML_SERVING_뷰_DDL.sql` 을 「뷰 1문 = 정의 + 컬럼 COMMENT」 로 정리한다.

하는 일
  · 파일 말미 `ALTER VIEW … MODIFY COLUMN … COMMENT` 를 뷰 컬럼 목록(`CREATE OR REPLACE VIEW v (C COMMENT '…', …)`)
    으로 접는다 ⇒ 뷰를 재생성해도 컬럼 COMMENT 가 사라지지 않는다(종전 규약 「이 절까지 함께 돌린다」가 불필요).
  · `/* */` 설명 블록과 전체 줄 `--` 이력 주석을 부록 md 로 원문 이관한다(삭제 0).
  · `-- ⛔` 비활성 구간(주석 처리된 UNION 분기 등)은 **그대로 남긴다** — 재적재 시 되살릴 코드다.
  · `[원천 COMMENT]` → `[원천]` 단축.
판정(쓰기 전 자체 대조 · 어긋나면 쓰지 않는다)
  뷰 집합 · 컬럼 목록 = 기존 ALTER 대상과 이름·순서 일치 · 컬럼 COMMENT 값 · 뷰 COMMENT · SELECT 본문(주석 제거 후) ·
  GRANT 집합 · 비활성(⛔) 줄 보존.
사용법
  python3 scripts/o192_ml_serving_compact.py                      # dry-run(tmp/ 에 결과 · 대조만)
  python3 scripts/o192_ml_serving_compact.py --write --label O192-A
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
PATH = f'{ROOT}/05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql'
APPX = f'{ROOT}/05_SV-Agent_ai/21_ML_SERVING_뷰_설계이력_부록.md'
RE_VIEW = re.compile(r'^CREATE OR REPLACE VIEW GN_DW\.SERVING\.(\w+)\s*\(?\s*$')
RE_ALTER = re.compile(r"^ALTER VIEW GN_DW\.SERVING\.(\w+) MODIFY COLUMN (\w+) COMMENT '((?:[^']|'')*)';\s*$")

HEADER = """\
-- ============================================================================
-- GN_DW.SERVING ML 예측 뷰 DDL — Semantic View(22_ML_SV_DDL) 의 base 계층 · 구조 정본
--   · GN_DW.ML 예측결과 테이블만 감싼다(학습·중간 테이블 비노출). SV 는 이 뷰만 base 로 쓴다.
--   · 뷰를 끼우는 이유 = ML 테이블 교체 내성 · VARIANT(PREDICTION) 평탄화 · 회원 예측 dedup.
--   · 실행 = GN_DW_ADMIN · 선행 = GN_DW.ML 결과 테이블 적재(dbt 무관).
--   · 컬럼 COMMENT 는 뷰 정의 안에 있다 — 재생성해도 유지된다. GRANT 는 재생성 시 사라지므로 같은 파일 말미에 있다.
--   · 🔴 ⛔ 표식 구간 = 원천 삭제로 비활성인 코드(재적재 시 주석 해제로 복구).
--   · 설계근거·실측 이력 = 21_ML_SERVING_뷰_설계이력_부록.md · 설계 = 20_ML_SV_설계.md
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;
"""

# 뷰 앞에 남길 업무 규칙(사람 판정 등재부 · 짧게)
KEEP = {
    'ML_MEMBER_RISK_V': ['원천이 회원당 여러 행 — 그 달 마지막 상태 spell 로 dedup(값이 움직이는 판정 · 임의 tiebreaker 금지).',
                         '중단 예측 지평은 발행하지 않는다(테이블명 12M · 실제 6개월 근거 3중 · 확인 전 기간 미기재).',
                         '충성회원은 모집단이 다르다 — FULL OUTER 결합 · NULL 허용.'],
    'ML_DVLP_FORECAST_V': ['단위 = 만원(회비·LTV 는 원 — 섞지 않는다) · SERIES_TYPE 간 합산은 중복계상.'],
    'ML_FEE_FORECAST_V': ['단위 = 원(개발금액 예측 만원과 다른 뷰에 둔 이유).'],
}


def unq(s):
    return s.replace("''", "'")


def strip_sql_comments(s):
    s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    return '\n'.join(re.sub(r'\s+$', '', ln) for ln in s.split('\n') if not ln.strip().startswith('--')).strip()


def parse(text):
    """뷰 블록 · ALTER · GRANT · 그 밖으로 나눈다."""
    lines = text.split('\n')
    views, order, alters, grants, notes_before, header = {}, [], [], [], {}, []
    pending, in_block, i, seen = [], False, 0, False
    while i < len(lines):
        ln = lines[i]
        if in_block:
            pending.append(ln)
            if '*/' in ln:
                in_block = False
            i += 1
            continue
        if ln.lstrip().startswith('/*'):
            pending.append(ln)
            in_block = '*/' not in ln
            i += 1
            continue
        m = RE_VIEW.match(ln)
        if m:
            seen = True
            name, body = m.group(1), [ln]
            i += 1
            while True:
                body.append(lines[i])
                if lines[i].rstrip().endswith(';') and not lines[i].lstrip().startswith('--'):
                    break
                i += 1
            views[name], notes_before[name] = body, pending
            order.append(name)
            pending = []
        elif RE_ALTER.match(ln):
            alters.append(RE_ALTER.match(ln).groups())
        elif ln.startswith('GRANT '):
            grants.append(ln.rstrip())
        elif not seen:
            header.append(ln)
        elif ln.strip() and not ln.startswith('USE '):
            pending.append(ln)
        i += 1
    return views, order, alters, grants, notes_before, header, pending


def split_view(body):
    """(뷰 COMMENT 리터럴, AS 이후 본문 줄들)."""
    txt = '\n'.join(body)
    m = re.search(r"^\s*COMMENT = '((?:[^']|'')*)'\s*\n\s*AS\s*\n", txt, re.M)
    if not m:
        raise SystemExit(f'🔴 뷰 COMMENT/AS 형식 예외: {body[0]}')
    return m.group(1), txt[m.end():].split('\n')


def clean_body(lines, dropped):
    """AS 이후 본문: 전체 줄 `--` 주석은 부록으로 · ⛔ 구간(표식 줄 + 바로 뒤 주석 처리된 코드)은 보존."""
    out, keep_run = [], False
    for ln in lines:
        s = ln.strip()
        if s.startswith('-- ⛔'):
            out.append(ln.rstrip())
            keep_run = True
            continue
        if s.startswith('--'):
            if keep_run and not s.startswith('-- 🆕') and not s.startswith('-- 🔴'):
                out.append(ln.rstrip())            # ⛔ 구간의 주석 처리된 SQL
            else:
                dropped.append(ln)
            continue
        keep_run = False
        m = re.match(r'^(.*?\S)\s+--\s(.*)$', ln)
        if m and "'" not in m.group(2) and m.group(1).count("'") % 2 == 0:
            dropped.append(ln)
            ln = m.group(1)
        out.append(ln.rstrip())
    return out


def build(text):
    views, order, alters, grants, notes, header, tail = parse(text)
    by_view = {}
    for v, c, cm in alters:
        by_view.setdefault(v, []).append((c, cm.replace('[원천 COMMENT]', '[원천]')))
    missing = [v for v in order if v not in by_view]
    if missing or set(by_view) - set(order):
        raise SystemExit(f'🔴 ALTER ↔ 뷰 불일치: 누락 {missing} · 여분 {set(by_view) - set(order)}')
    out, appx = [HEADER.rstrip('\n')], []
    appx.append('## 0. 파일 머리말(원문)\n\n```sql\n' + '\n'.join(header).strip('\n') + '\n```\n')
    for n, v in enumerate(order, 1):
        vc, body = split_view(views[v])
        dropped = []
        new_body = clean_body(body, dropped)
        cl = by_view[v]
        w = max(len(c) for c, _ in cl)
        out += ['', f'-- [{n}] {v} — {unq(vc).split(". ")[0]}']
        out += [f'--   ⚠️ {x}' for x in KEEP.get(v, [])]
        out.append(f'CREATE OR REPLACE VIEW GN_DW.SERVING.{v} (')
        out += [f"    {c.ljust(w)} COMMENT '{cm}'{',' if k < len(cl) - 1 else ''}" for k, (c, cm) in enumerate(cl)]
        out += [')', f"  COMMENT = '{vc}'", 'AS'] + new_body
        hist = [x for x in notes[v] if x.strip()] + dropped
        if hist:
            appx.append(f'## [{n}] {v}\n\n```text\n' + '\n'.join(hist) + '\n```\n')
    out += ['', '-- ' + '=' * 76, '-- GRANT — 뷰 SELECT(재생성 시 사라지므로 함께 실행) · GN_DW.ML 직접 조회는 ANALYST 한정(DEC-57)',
            '-- ' + '=' * 76] + grants
    rest = [x for x in tail if x.strip()]
    if rest:
        appx.append('## 파일 말미(원문)\n\n```text\n' + '\n'.join(rest) + '\n```\n')
    return views, order, by_view, grants, '\n'.join(out).rstrip('\n') + '\n', appx


def verify(views, order, by_view, grants, new_text, old_text):
    errs = []
    nv, norder, nalters, ngrants, _, _, _ = parse(new_text)
    if nalters:
        errs.append(f'ALTER {len(nalters)}건 잔존')
    if norder != order:
        errs.append('뷰 순서/집합 불일치')
    if sorted(ngrants) != sorted(grants):
        errs.append('GRANT 불일치')
    norm = lambda s: re.sub(r'\s+', ' ', re.sub(r'\s*--\s.*$', '', s, flags=re.M))  # noqa: E731
    for v in order:
        if v not in nv:
            errs.append(f'{v} 새 파일에 없음')
            continue
        txt = '\n'.join(nv[v])
        m = re.search(r'\((.*?)\n\)\n', txt, re.S)
        got = re.findall(r"^\s+(\w+)\s+COMMENT '((?:[^']|'')*)',?$", m.group(1), re.M) if m else []
        if got != by_view[v]:
            errs.append(f'{v} 컬럼 목록/COMMENT 불일치')
        oc, ob = split_view(views[v])
        nm = re.search(r"\n\)\n  COMMENT = '((?:[^']|'')*)'\nAS\n", txt)
        if not nm or nm.group(1) != oc:
            errs.append(f'{v} 뷰 COMMENT 불일치')
            continue
        if norm(strip_sql_comments('\n'.join(ob))) != norm(strip_sql_comments(txt[nm.end():])):
            errs.append(f'{v} SELECT 본문 불일치')
    old_off = [ln.strip() for ln in old_text.split('\n') if ln.strip().startswith('-- ⛔')]
    new_off = [ln.strip() for ln in new_text.split('\n') if ln.strip().startswith('-- ⛔')]
    if old_off != new_off:
        errs.append(f'⛔ 표식 불일치 {len(old_off)} → {len(new_off)}')
    for ln in old_text.split('\n'):
        if re.match(r'^\s*--\s+(UNION ALL|SELECT|FROM|LEFT JOIN|CASE)', ln) and ln.strip() not in new_text:
            errs.append(f'⛔ 비활성 코드 유실: {ln.strip()[:60]}')
    if any(len(x) > 2000 for x in new_text.split('\n')):
        errs.append('2000자 초과 줄')
    return errs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--write', action='store_true')
    ap.add_argument('--label')
    a = ap.parse_args()
    old = io.open(PATH, encoding='utf-8').read()
    if not re.search(r'^ALTER VIEW ', old, re.M):
        print('🟢 변경 없음(이미 압축된 판본)')
        return 0
    views, order, by_view, grants, new, appx = build(old)
    errs = verify(views, order, by_view, grants, new, old)
    oc = sum(1 for x in old.split('\n') if x.strip().startswith(('--', '/*')))
    ncm = sum(1 for x in new.split('\n') if x.strip().startswith('--'))
    print(f'뷰 {len(order)} · ALTER 접기 {sum(map(len, by_view.values()))} · GRANT {len(grants)} · '
          f'줄 {old.count(chr(10))} → {new.count(chr(10))} · 주석 줄 {oc} → {ncm}')
    if errs:
        print('🔴 대조 실패 — 쓰지 않는다:', *errs, sep='\n  ')
        return 1
    print('🟢 대조 PASS(뷰·컬럼 목록·COMMENT·SELECT 본문·GRANT·⛔ 구간)')
    app_text = ('# 21_ML_SERVING_뷰_DDL.sql — 설계·실측 이력 부록\n\n'
                '> O192 에서 본문을 압축하며 **뺀 주석을 원문 그대로** 옮긴 것이다(삭제 0).\n'
                '> 🔴 여기 수치는 **그 시점 · 그 계정의 기록**이다 — 현재값으로 인용하지 마라(`R2-8-4`).\n\n'
                + '\n'.join(appx) + '\n_Co-authored with CoCo_\n')
    if not a.write:
        io.open(f'{ROOT}/tmp/o192_21.sql', 'w', encoding='utf-8').write(new)
        io.open(f'{ROOT}/tmp/o192_21_부록.md', 'w', encoding='utf-8').write(app_text)
        print('dry-run → tmp/o192_21.sql')
        return 0
    if os.path.exists(APPX):
        raise SystemExit('🔴 부록이 이미 있다 — 덮지 않는다')
    print('스냅샷:', snapshot(PATH, 'o192-compact', label=a.label, archive=ARCHIVE))
    io.open(PATH, 'w', encoding='utf-8').write(new)
    io.open(APPX, 'w', encoding='utf-8').write(app_text)
    back = io.open(PATH, encoding='utf-8').read()
    print('🟢 쓰기 완료 · 되읽기 일치' if back == new else '🔴 되읽기 불일치')
    return 0


if __name__ == '__main__':
    # 🔴 [O196] MUTATES 가드 — `--write` 는 `--apply` 를 함께 줘야 집행된다(R4-4-3)
    if '--write' in sys.argv:
        from mutating_guard import require_apply  # noqa: E402
        require_apply(__file__, '21_ML_SERVING_뷰_DDL 정본 재작성 + 부록 생성')
        sys.argv = [x for x in sys.argv if x != '--apply']
    sys.exit(main())
