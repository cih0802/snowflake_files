#!/usr/bin/env python3
"""현업요청 대응(R 문서) 근거 캡처를 한 계정(운영계) 안에서만 점검한다 — 읽기 전용(파일만 읽고 md 1개를 쓴다)

사용법 (워크스페이스 루트에서)
    python3 "85_실제 인수인계 문서/30_현업요청대응/_도구/r_env_check.py" --account ZL50263

입력  = 85_실제 인수인계 문서/_ENV/<계정>/<ID>_manifest.csv · <ID>_<Qnn>_<k>.csv (scripts/env_capture.py 생성물)
출력  = 85_실제 인수인계 문서/30_현업요청대응/91_운영계_점검결과.md (자동 생성 · 손으로 고치지 않는다 · 판정 메모는 90 가이드 §4 표에 쓴다)

판정 규칙 (다른 계정과 비교하지 않는다 · 값은 기록만 한다)
    · ERROR = 🔴 (R90 Q01 = ORGADMIN 필요 → 🟠)
    · DIFF* 열이 0 이 아닌 행 = 🔴. 단 ALLOWED_DIFF 열은 사유가 확인된 차이(R10 §4)라 🟢사유
    · RULES 의 개별 기준(Task state · Task 실행 오류 · NULL/중복)을 어기면 🔴
    · 그 밖 = 🟢 (값 기록)
"""
import argparse
import csv
import os
import sys

ROOT = os.path.join('85_실제 인수인계 문서', '_ENV')
OUT = os.path.join('85_실제 인수인계 문서', '30_현업요청대응', '91_운영계_점검결과.md')
IDS = ['R00', 'R06', 'R09', 'R10', 'R90']
ALLOWED_DIFF = {('R10', 'Q02', 'DIFF_PAID'), ('R10', 'Q03', 'DIFF_EXEC'), ('R10', 'Q09', 'DIFF_VS_MONTH_SUM')}
SOFT_ERROR = {('R90', 'Q01')}


def _rule_task_started(rows):
    bad = [r.get('name', '') for r in rows if r.get('state') and r['state'].lower() != 'started']
    return f'started 아님: {", ".join(bad)}' if bad else ''


def _rule_task_history(rows):
    bad = [f"{r.get('NAME')}={r.get('STATE')}" for r in rows if r.get('STATE') not in ('SUCCEEDED', 'SKIPPED', 'SCHEDULED', 'EXECUTING')]
    return f'실패 실행: {", ".join(bad)}' if bad else ''


def _rule_all_zero(col):
    def f(rows):
        bad = [f"{r.get('CHK')}={r.get(col)}" for r in rows if r.get(col) not in ('0', '0.0', '', None)]
        return f'0 아님: {", ".join(bad)}' if bad else ''
    return f


RULES = {
    ('R00', 'Q08'): _rule_task_started,      # SHOW TASKS
    ('R00', 'Q09'): _rule_task_started,      # SHOW ALERTS
    ('R90', 'Q10'): _rule_task_history,      # 최근 7일 Task 실행
    ('R10', 'Q07'): _rule_all_zero('V'),     # NULL · 중복
}


def read_csv(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding='utf-8') as f:
        return list(csv.DictReader(line for line in f if not line.startswith('#')))


def check(acct, rid, qid, fname):
    rows = read_csv(os.path.join(ROOT, acct, fname)) or []
    bad, ok = [], []
    for col in (rows[0].keys() if rows else []):
        if not col.upper().startswith('DIFF'):
            continue
        n = sum(1 for r in rows if r[col] not in ('', '0', '0.0', '0.00', 'None', None))
        if n:
            (ok if (rid, qid, col.upper()) in ALLOWED_DIFF else bad).append(f'{col}≠0 {n}행')
    rule = RULES.get((rid, qid))
    if rule:
        msg = rule(rows)
        if msg:
            bad.append(msg)
    return bad, [f'{x}(사유 확인 · R10 §4)' for x in ok]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--account', required=True)
    ap.add_argument('--ids', nargs='*', default=IDS)
    a = ap.parse_args()
    if not os.path.isdir(os.path.join(ROOT, a.account)):
        print(f'🔴 {a.account} 캡처 폴더 없음 — 먼저 가이드 §2 를 실행한다', file=sys.stderr)
        return 2

    lines = [f'# 91. 운영계 점검 결과 (자동 생성 · r_env_check.py · 계정 {a.account})', '',
             '- 판정 규칙 = 스크립트 머리말 · 값은 각 csv 에 있다(이 표는 판정만)', '',
             '| ID | Q | k | 내용 | 실행 시각 | 상태 · 행 | 판정 | 비고 | 근거 파일 |',
             '|---|---|---|---|---|---|---|---|---|']
    summary = {'🟢': 0, '🟠': 0, '🔴': 0}
    for rid in a.ids:
        path = os.path.join(ROOT, a.account, f'{rid}_manifest.csv')
        rows = read_csv(path)
        if not rows:
            lines.append(f'| {rid} | — | — | 캡처 없음 | | | 🔴 | 가이드 §2 실행 필요 | |')
            summary['🔴'] += 1
            continue
        with open(path, encoding='utf-8') as f:
            head = f.readline()
        as_of = head.split('as_of:')[1].split('·')[0].strip() if 'as_of:' in head else ''
        for r in rows:
            qid = r['QID']
            note = (r.get('NOTE') or '').replace('|', '/')[:70]
            if r['STATUS'] != 'OK':
                mark = '🟠' if (rid, qid) in SOFT_ERROR else '🔴'
                memo = '권한(ORGADMIN) 필요' if mark == '🟠' else '오류 확인 후 재실행'
            else:
                bad, ok = check(a.account, rid, qid, r['FILE'])
                mark = '🔴' if bad else '🟢'
                memo = ' · '.join(bad + ok)
            summary[mark] += 1
            lines.append(f"| {rid} | {qid} | {r['K']} | {note} | {as_of} | {r['STATUS']} {r['ROWS']} | {mark} | {memo} | `_ENV/{a.account}/{r['FILE']}` |")
    lines += ['', f"- 합계: 🟢 {summary['🟢']} · 🟠 {summary['🟠']} · 🔴 {summary['🔴']}",
              '- 🔴·🟠 행과 「값 기록」 항목은 90 가이드 §4 판정표에 적는다.']
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')
    print(f"🟢 {summary['🟢']} · 🟠 {summary['🟠']} · 🔴 {summary['🔴']} → {OUT}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
