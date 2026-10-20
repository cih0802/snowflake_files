#!/usr/bin/env python3
"""N05 테스트 결과서 xlsx 생성 — _ENV/<계정>/N05_*.csv 를 시트별로 모아 합격/불합격 요약

🆕 [UNLABELED 신설 · `new_tool.py` 경유 ⇒ `gate_census` 등재 완료]
🔴 분류 = `GEN`. 이 분류의 계약을 지켜라(정본 = `scripts/gate_census.py`).
🔴 산출물은 자동 생성물이다 — 손으로 고치면 다음 생성에서 사라진다.

사용법
    python3 scripts/n05_report_build.py <계정>        # 예: IW20760
    선행 = python3 scripts/env_capture.py --id N05 "85_실제 인수인계 문서/_근거쿼리/N05_테스트결과_근거.sql"

입력 = 85_실제 인수인계 문서/_ENV/<계정>/N05_Q01_1 ~ N05_Q07_1.csv
출력 = 85_실제 인수인계 문서/20_정식산출물/N05_테스트결과서.xlsx
    시트 = 요약 · dbt실행 · dbt결과 · 실패저장 · MSTR_V02 · 평가셋 · 예산분해 · Agent평가
요약 판정 규칙(계약)
    · dbt      = 마지막 전체 build 의 ERROR=0 이고 SKIP=0 이면 합격(WARN 은 관측 · 판정 제외)
    · 실패저장  = ROW_COUNT>0 테이블 수(관측 · 0 이 기대값)
    · MSTR_V02 = RESULT 전부 PASS 면 합격
    · 평가셋    = PASS/전체(🔴 FAIL 은 「기대값과 다름」 — 결함 판정은 N05 §4 사람 분류)
    · Agent평가 = 점수 미수집(TBD) · 실행 흔적만

종료코드 = 0 성공 · 1 입력 부재 · 2 사용법 오류.
"""
import csv
import datetime
import io
import os
import re
import sys

BASE = '85_실제 인수인계 문서'
OUT = os.path.join(BASE, '20_정식산출물', 'N05_테스트결과서.xlsx')
SHEETS = [('dbt실행', 'Q01'), ('dbt결과', 'Q02'), ('실패저장', 'Q03'), ('MSTR_V02', 'Q04'),
          ('평가셋', 'Q05'), ('예산분해', 'Q06'), ('Agent평가', 'Q07')]


def read_rows(path):
    with open(path, encoding='utf-8') as f:
        return [r for r in csv.reader(f) if r and not r[0].startswith('#')]


def judge(data):
    """data = {QID: rows(헤더 포함)} → 요약 행 [(항목, 판정, 근거)]."""
    out = []
    done = next((r[1] for r in data.get('Q02', [])[1:] if r and r[0] == 'DONE'), '')
    m = re.search(r'PASS=(\d+) WARN=(\d+) ERROR=(\d+) SKIP=(\d+)', done)
    if m:
        p, w, e, s = map(int, m.groups())
        out.append(('dbt 전체 build', '합격' if e == 0 and s == 0 else '불합격', f'PASS {p} · WARN {w} · ERROR {e} · SKIP {s}'))
    else:
        out.append(('dbt 전체 build', 'TBD(미검증)', 'Done 줄 없음'))
    fs = data.get('Q03', [])
    if fs:
        h = fs[0]
        i = h.index('ROW_COUNT')
        bad = [r[0] for r in fs[1:] if r[i] not in ('', '0')]
        out.append(('dbt 실패 저장 테이블', '관측', f'{len(bad)}/{len(fs) - 1} 테이블에 행 있음'))
    for key, qid in (('MSTR 고정 기준값 V02', 'Q04'), ('평가셋 단일값 재실행', 'Q05')):
        rows = data.get(qid, [])
        if not rows:
            out.append((key, 'TBD(미검증)', '입력 없음'))
            continue
        i = rows[0].index('RESULT')
        res = [r[i] for r in rows[1:]]
        n_pass = res.count('PASS')
        if qid == 'Q04':
            out.append((key, '합격' if res and n_pass == len(res) else '불합격', f'PASS {n_pass}/{len(res)}'))
        else:
            out.append((key, '관측', f'PASS {n_pass}/{len(res)} · FAIL 원인은 N05 §4'))
    out.append(('Agent 평가 점수', 'TBD(미검증)', f'실행 흔적 {max(len(data.get("Q07", [])) - 1, 0)}회 · 점수 미수집'))
    return out


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 2
    env = os.path.join(BASE, '_ENV', argv[1])
    data = {}
    for _, qid in SHEETS:
        p = os.path.join(env, f'N05_{qid}_1.csv')
        if os.path.exists(p):
            data[qid] = read_rows(p)
    if not data:
        print(f'🔴 입력 부재: {env}/N05_Q*_1.csv → env_capture --id N05 선행')
        return 1
    import openpyxl
    ts = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).strftime('%Y-%m-%d %H:%M KST')
    note = f'# 생성 = scripts/n05_report_build.py {argv[1]} · {ts} · 입력 = _ENV/{argv[1]}/N05_*.csv · 손으로 고치지 말 것'
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = '요약'
    ws.append([note])
    ws.append(['항목', '판정', '근거'])
    summary = judge(data)
    for r in summary:
        ws.append(list(r))
    for name, qid in SHEETS:
        sh = wb.create_sheet(name)
        sh.append([note])
        for r in data.get(qid, [['입력 없음']]):
            sh.append(r)
    b = io.BytesIO()
    wb.save(b)
    with open(OUT, 'wb') as f:   # 스테이지 마운트 = seek 불가 ⇒ 메모리에서 완성 후 1회 쓰기
        f.write(b.getvalue())
    for r in summary:
        print(' · '.join(r))
    print(f'🟢 {OUT}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
