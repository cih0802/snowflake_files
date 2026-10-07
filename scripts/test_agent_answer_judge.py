#!/usr/bin/env python3
"""음성 테스트 — scripts/agent_answer_judge.py (O207 신설 · R3-2)

축
    ㉠ 오염 = 영문 헤더 표 → header FAIL · rc=1
    ㉡ 오염 = 본문 수치가 표 어디에도 없음 → num CHECK · rc=1
    ㉢ 역방향 오탐 = 한글 헤더 + 본문 수치 = 셀 값/열 합 → PASS · rc=0
    ㉣ 무인자 → rc=2

Co-authored with CoCo
"""
import json
import os
import subprocess
import sys
import tempfile

TOOL = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'agent_answer_judge.py')


def table(names, rows):
    return {'type': 'table', 'table': {'result_set': {
        'resultSetMetaData': {'rowType': [{'name': n} for n in names]},
        'data': rows}}}


def case(dirpath, content):
    os.makedirs(dirpath, exist_ok=True)
    with open(os.path.join(dirpath, 'C1.json'), 'w', encoding='utf-8') as f:
        json.dump({'content': content}, f, ensure_ascii=False)


def run(args):
    r = subprocess.run([sys.executable, TOOL] + args, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    return r.returncode, r.stdout


def main():
    fails = []
    with tempfile.TemporaryDirectory() as t:
        d1 = os.path.join(t, 'eng')
        case(d1, [table(['DEPT_NM', '개발(건)'], [['A', '1200'], ['B', '800']]),
                  {'type': 'text', 'text': '합계 2,000건입니다.'}])
        rc, out = run([d1, '--axis', 'header'])
        if rc != 1 or 'FAIL' not in out:
            fails.append(f'㉠ 영문 헤더를 못 잡음 rc={rc}')

        d2 = os.path.join(t, 'num')
        case(d2, [table(['부서', '개발(건)'], [['A', '1200'], ['B', '800']]),
                  {'type': 'text', 'text': '합계 2,345건입니다.'}])
        rc, out = run([d2, '--axis', 'num'])
        if rc != 1 or 'CHECK' not in out:
            fails.append(f'㉡ 근거 없는 수치를 못 잡음 rc={rc}')

        d3 = os.path.join(t, 'ok')
        case(d3, [table(['부서', '개발(건)'], [['A', '1200'], ['B', '800']]),
                  {'type': 'text', 'text': 'A 1,200건 · 합계 2,000건입니다.'}])
        rc, out = run([d3])
        if rc != 0:
            fails.append(f'㉢ 정상 답변을 오탐 rc={rc} {out[-200:]}')

    rc, _ = run([])
    if rc != 2:
        fails.append(f'㉣ 무인자 rc={rc} (기대 2)')

    for f in fails:
        print('FAIL', f)
    print('PASS' if not fails else f'FAIL {len(fails)}')
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
