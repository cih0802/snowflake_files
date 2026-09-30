#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Semantic View DDL 압축기(O192) — `05_N_SV_DDL_*.sql` · `22_ML_SV_DDL.sql` 을 「머리말 짧게 + SV + GRANT + 스모크」로 정리한다.

하는 일
  · 파일 머리말·SV 내부·말미의 줄 선두 `--` 주석을 부록 md 로 **원문 이관**(삭제 0). 🔴 문자열 안의 줄은 건드리지 않는다
    (문자열 인식 스캐너 — AI_SQL_GENERATION 문안이 여러 줄이고 `--`·`;` 를 담을 수 있다).
  · Agent 가 읽는 문자열(COMMENT · AI_SQL_GENERATION · VQR QUESTION)에서 **세션 태그만** 제거한다:
    `[O191-D]` · `[2026-08-26 O102]` · ` · O190` · `(O190)` · `(R-O191-C 예측)` → `(예측)`. 문안 의미는 바꾸지 않는다.
  · 스모크 SELECT 앞에는 한 줄 라벨만 남긴다.
판정(쓰기 전 자체 대조 · 어긋나면 쓰지 않는다)
  문장 수·종류·순서 동일 · 문자열 밖 SQL 토큰 동일 · 문자열 = 원문에서 태그만 뺀 것 · 태그 잔존 0 · 줄 2000자 이하.
사용법
  python3 scripts/o192_sv_compact.py                 # dry-run(전 파일 · 대조만)
  python3 scripts/o192_sv_compact.py --write --label O192-A
Co-authored with CoCo
"""
import argparse
import glob
import io
import os
import re
import sys

sys.path.insert(0, '/workspace/scripts')
from snapshot_util import snapshot, ARCHIVE  # noqa: E402

DIR = '/workspace/05_SV-Agent_ai'
APPX = f'{DIR}/05_SV_DDL_설계이력_부록.md'

TAG_RULES = [
    (re.compile(r'\s*\[(?:20\d\d-\d\d-\d\d\s*)?O\d{2,3}(?:-[A-Z]{1,2})?(?:[^\]\']{0,40})\]'), ''),
    (re.compile(r'\(R-O\d{2,3}(?:-[A-Z]{1,2})?\s+([^)\']{1,30})\)'), r'(\1)'),
    (re.compile(r'\s*\(R-O\d{2,3}(?:-[A-Z]{1,2})?\)'), ''),
    (re.compile(r'\s*\(O1\d\d(?:-[A-Z]{1,2})?\)'), ''),
    (re.compile(r'🆕\s*O1\d\d(?:-[A-Z]{1,2})?\s*·?\s*'), ''),                 # 「(🆕 O190 · X)」 → 「(X)」
    (re.compile(r'\((?:O1\d\d(?:-[A-Z]{1,2})?)\s+(?=[^)\'])'), '('),          # 「(O182 원천 재편)」 → 「(원천 재편)」
    (re.compile(r'\s*·\s*O1\d\d(?:-[A-Z]{1,2})?(?=[\s)\].,·]|$)'), ''),
]
# VQR `VERIFIED_BY '(DW = O191)'` = 검증 주체 메타데이터(태그 아님) · `§O105` = 원장 좌표(참조) ⇒ 둘 다 보존
KEEP_LIT = re.compile(r"^'\(DW = O\d{2,3}(?:-[A-Z])?\)'$")
RE_TAG_LEFT = re.compile(r'(?<!§)\bO1\d\d(?:-[A-Z])?\b|\[20\d\d-\d\d-\d\d|R-O\d{3}')


def clean_str(s):
    if KEEP_LIT.match(s):
        return s
    for rx, rep in TAG_RULES:
        s = rx.sub(rep, s)
    return s


def scan(text):
    """문자열 인식 분할 — [(kind, text)] · kind ∈ code|str|comment_line.
    comment_line = 문자열 밖에서 줄 선두(공백 뒤)가 `--` 인 한 줄(개행 포함)."""
    out, i, n, buf, line_start = [], 0, len(text), '', True
    while i < n:
        ch = text[i]
        if line_start and text[i:].lstrip(' \t').startswith('/*'):
            j = text.index('*/', i) + 2
            j = text.find('\n', j - 1)
            j = n if j < 0 else j + 1
            if buf:
                out.append(('code', buf))
                buf = ''
            out.append(('comment_line', text[i:j]))
            i, line_start = j, True
            continue
        if line_start and text[i:].lstrip(' \t').startswith('--'):
            j = text.find('\n', i)
            j = n if j < 0 else j + 1
            if buf:
                out.append(('code', buf))
                buf = ''
            out.append(('comment_line', text[i:j]))
            i, line_start = j, True
            continue
        if ch == "'":
            if buf:
                out.append(('code', buf))
                buf = ''
            j = i + 1
            while True:
                k = text.index("'", j)
                if text[k + 1:k + 2] == "'":
                    j = k + 2
                    continue
                break
            out.append(('str', text[i:k + 1]))
            i, line_start = k + 1, False
            continue
        if ch == '-' and text[i:i + 2] == '--':          # 줄 끝 주석(코드 뒤) — 원문 유지
            j = text.find('\n', i)
            j = n if j < 0 else j
            buf += text[i:j]
            i = j
            continue
        buf += ch
        line_start = ch == '\n' or (line_start and ch in ' \t')
        i += 1
    if buf:
        out.append(('code', buf))
    return out


def statements(parts):
    """code/str 조각으로 문장을 복원한다(주석 제외) — 대조용."""
    s, cur = [], ''
    for k, t in parts:
        if k == 'comment_line':
            continue
        if k == 'str':
            cur += t
            continue
        for ch in t:
            cur += ch
            if ch == ';':
                s.append(re.sub(r'\s+', ' ', cur).strip())
                cur = ''
    if cur.strip():
        s.append(re.sub(r'\s+', ' ', cur).strip())
    return s


def sv_desc(parts):
    """SV 수준 COMMENT(마지막 `COMMENT =` 앞의 첫 SV) 첫 문장 — 머리말용."""
    txt = ''.join(t for k, t in parts if k != 'comment_line')
    names = re.findall(r'^CREATE OR ALTER SEMANTIC VIEW\s+(\S+)', txt, re.M)
    return [x.split('.')[-1] for x in names]


def compact(path):
    old = io.open(path, encoding='utf-8').read()
    parts = scan(old)
    svs = sv_desc(parts)
    fname = os.path.basename(path)
    removed, out, seen_code, prev_smoke = [], [], False, False
    for k, t in parts:
        if k == 'comment_line':
            removed.append(t.rstrip('\n'))
            continue
        if k == 'str':
            out.append(('str', clean_str(t)))
            continue
        out.append(('code', t))
        seen_code = True
    body = ''.join(t for _, t in out)
    body = re.sub(r'\n{3,}', '\n\n', body).strip('\n') + '\n'
    # 스모크 SELECT 앞 라벨 · GRANT 앞 라벨
    body = re.sub(r'\n\n(?=SELECT |SHOW |DESCRIBE |DESC )', '\n\n-- 스모크(배포 확인 · 배포 러너는 실행하지 않는다)\n', body, count=1)
    body = re.sub(r'\n\n(?=GRANT )', '\n\n-- GRANT — SV 재배포(CREATE OR ALTER) 뒤에도 함께 실행\n', body, count=1)
    head = ('-- ============================================================================\n'
            f'-- {fname} — Semantic View DDL 정본: {" · ".join(svs) if svs else "(SV 정의 없음)"}\n'
            '--   · 구성 = USE → CREATE OR ALTER SEMANTIC VIEW → GRANT → 스모크. 파일 단독 실행 가능(파일 간 순서 없음).\n'
            '--   · 🔴 SV 의 규칙·주의는 SV COMMENT · AI_SQL_GENERATION 안에 있다(Agent 가 읽는 곳) — 이 주석에 두지 않는다.\n'
            '--   · 공통 규약 = 05_0_SV_DDL.sql · 설계·실측 이력 = 05_SV_DDL_설계이력_부록.md\n'
            '-- ============================================================================\n')
    new = head + body
    return old, new, removed, svs


def verify(old, new):
    errs = []
    po, pn = scan(old), scan(new)
    so, sn = statements(po), statements(pn)
    if len(so) != len(sn):
        errs.append(f'문장 수 {len(so)} → {len(sn)}')
    for a, b in zip(so, sn):
        if clean_str_stmt(a) != b:
            errs.append('문장 불일치: ' + a[:80])
            break
    left = [t for k, t in pn if k == 'str' and not KEEP_LIT.match(t) and RE_TAG_LEFT.search(t)]
    if left:
        errs.append(f'태그 잔존 {len(left)}: ' + RE_TAG_LEFT.search(left[0]).group(0))
    if any(len(x) > 2000 for x in new.split('\n')):
        errs.append('2000자 초과 줄')
    return errs


def clean_str_stmt(stmt):
    parts = scan(stmt)
    return re.sub(r'\s+', ' ', ''.join(clean_str(t) if k == 'str' else t for k, t in parts if k != 'comment_line')).strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--write', action='store_true')
    ap.add_argument('--label')
    a = ap.parse_args()
    files = sorted(glob.glob(f'{DIR}/05_[1-9]*_SV_DDL_*.sql')) + [f'{DIR}/22_ML_SV_DDL.sql']
    results, bad = [], 0
    for f in files:
        old, new, removed, svs = compact(f)
        errs = verify(old, new)
        oc = sum(1 for x in old.split('\n') if x.strip().startswith('--'))
        nc = sum(1 for x in new.split('\n') if x.strip().startswith('--'))
        tags = sum(len(RE_TAG_LEFT.findall(t)) for k, t in scan(old) if k == 'str')
        state = '🔴 ' + '; '.join(errs) if errs else ('🟢 변경 없음' if old == new else '🟢')
        print(f'{os.path.basename(f):40} 줄 {old.count(chr(10)):4} → {new.count(chr(10)):4} · 주석 {oc:3} → {nc:2} · '
              f'문자열 태그 {tags:2} → 0 · {state}')
        bad += bool(errs)
        results.append((f, old, new, removed))
    if bad:
        print('🔴 대조 실패 — 쓰지 않는다')
        return 1
    appx = ['# 05_N_SV_DDL · 22_ML_SV_DDL — 설계·실측 이력 부록\n',
            '> O192 에서 SV DDL 을 압축하며 **본문에서 뺀 주석을 원문 그대로** 옮긴 것이다(삭제 0).',
            '> 🔴 여기 수치는 **그 시점 · 그 계정의 기록**이다 — 현재값으로 인용하지 마라(`R2-8-4`).',
            '> SV 문자열에서 뺀 것은 세션 태그뿐이다(`[O191-D]` · `· O190` · `(R-O191 …)` 등) — 원문은 `_archive/` 스냅샷.\n']
    for f, old, new, removed in results:
        if removed:
            appx.append(f'## {os.path.basename(f)}\n\n```text\n' + '\n'.join(removed) + '\n```\n')
    app_text = '\n'.join(appx) + '\n_Co-authored with CoCo_\n'
    if not a.write:
        io.open('/workspace/tmp/o192_sv_부록.md', 'w', encoding='utf-8').write(app_text)
        for f, old, new, _ in results:
            io.open('/workspace/tmp/o192_' + os.path.basename(f), 'w', encoding='utf-8').write(new)
        print('dry-run → tmp/o192_<파일> · tmp/o192_sv_부록.md')
        return 0
    if os.path.exists(APPX):
        raise SystemExit('🔴 부록이 이미 있다 — 덮지 않는다')
    for f, old, new, _ in results:
        if old == new:
            continue
        snapshot(f, 'o192-compact', label=a.label, archive=ARCHIVE, quiet=True)
        io.open(f, 'w', encoding='utf-8').write(new)
        if io.open(f, encoding='utf-8').read() != new:
            raise SystemExit(f'🔴 되읽기 불일치: {f}')
    io.open(APPX, 'w', encoding='utf-8').write(app_text)
    print('🟢 쓰기 완료 · 되읽기 일치')
    return 0


if __name__ == '__main__':
    sys.exit(main())
