#!/usr/bin/env python3
"""n05_report_build 음성·양성 테스트 — 판정 규칙 계약(ERROR/SKIP · V02 전건 PASS · 평가셋은 관측) · 입력 부재 rc.

실행 = python3 scripts/test_n05_report_build.py   (rc=0 전부 통과 · rc=1 실패 있음)
"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import n05_report_build as n  # noqa: E402

FAIL = []


def check(name, cond):
    print(('🟢 ' if cond else '🔴 ') + name)
    if not cond:
        FAIL.append(name)


def d(done, v02, ev):
    return {'Q02': [['KIND', 'LINE'], ['DONE', done], ['WARN', 'Warning in test x']],
            'Q03': [['TABLE_NAME', 'ROW_COUNT', 'LAST_ALTERED'], ['A', '2', ''], ['B', '0', '']],
            'Q04': [['DVLP_DIV_CD', 'RESULT']] + [[str(i), r] for i, r in enumerate(v02)],
            'Q05': [['ID', 'RESULT']] + [[str(i), r] for i, r in enumerate(ev)]}


ok = dict((k, (v, e)) for k, v, e in n.judge(d('Done. PASS=10 WARN=3 ERROR=0 SKIP=0 TOTAL=13', ['PASS', 'PASS'], ['PASS', 'FAIL'])))
check('양성: ERROR 0 · SKIP 0 → dbt 합격(WARN 은 판정 제외)', ok['dbt 전체 build'][0] == '합격')
check('양성: V02 전건 PASS → 합격', ok['MSTR 고정 기준값 V02'][0] == '합격')
check('음성: 평가셋 FAIL 을 불합격으로 단정하지 않는다(관측)', ok['평가셋 단일값 재실행'][0] == '관측' and 'PASS 1/2' in ok['평가셋 단일값 재실행'][1])
check('양성: 실패 저장 행 있는 테이블 수', ok['dbt 실패 저장 테이블'][1].startswith('1/2'))

bad = dict((k, (v, e)) for k, v, e in n.judge(d('Done. PASS=10 WARN=0 ERROR=0 SKIP=4 TOTAL=14', ['PASS', 'FAIL'], [])))
check('음성: SKIP>0 → dbt 불합격(SKIP 은 무해하지 않다 · RUNBOOK §11.4)', bad['dbt 전체 build'][0] == '불합격')
check('음성: V02 FAIL 1건 → 불합격', bad['MSTR 고정 기준값 V02'][0] == '불합격')

none = dict((k, (v, e)) for k, v, e in n.judge({'Q02': [['KIND', 'LINE']]}))
check('음성: Done 줄 없음 → TBD(합격으로 넘기지 않는다)', none['dbt 전체 build'][0] == 'TBD(미검증)')
check('음성: Agent 점수는 항상 TBD(미수집)', none['Agent 평가 점수'][0] == 'TBD(미검증)')

me = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'n05_report_build.py')
p2 = subprocess.run([sys.executable, me], capture_output=True, text=True, stdin=subprocess.DEVNULL, timeout=60)
check('음성: 무인자 rc=2', p2.returncode == 2)
p1 = subprocess.run([sys.executable, me, '__NO_SUCH_ACCOUNT__'], capture_output=True, text=True, stdin=subprocess.DEVNULL, timeout=60)
check('음성: 입력 부재 rc=1(빈 xlsx 를 만들지 않는다)', p1.returncode == 1)

print(f'{10 - len(FAIL)}/10 통과')
sys.exit(1 if FAIL else 0)
