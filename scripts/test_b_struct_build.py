#!/usr/bin/env python3
"""b_struct_build 음성 테스트 (R3-2) — 입력 부재 rc=1 · 사용법 rc=2 · dbt 계보 파서가 ref/source·dev2 분기를 해석."""
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import b_struct_build as b  # noqa: E402

fails = 0


def check(name, cond):
    global fails
    print(('🟢 ' if cond else '🔴 ') + name)
    fails += 0 if cond else 1


here = os.path.dirname(os.path.abspath(__file__))
p = subprocess.run([sys.executable, os.path.join(here, 'b_struct_build.py')], capture_output=True, text=True,
                   stdin=subprocess.DEVNULL, cwd=os.path.dirname(here))
check('무인자 = rc 2', p.returncode == 2)
p = subprocess.run([sys.executable, os.path.join(here, 'b_struct_build.py'), 'NO_SUCH_ACCOUNT'], capture_output=True,
                   text=True, stdin=subprocess.DEVNULL, cwd=os.path.dirname(here))
check('입력 부재 = rc 1 · 부재 목록 출력', p.returncode == 1 and '입력 부재' in p.stdout)

with tempfile.TemporaryDirectory() as d:
    os.makedirs(os.path.join(d, 'models', 'silver'))
    os.makedirs(os.path.join(d, 'models', 'gold'))
    open(os.path.join(d, 'models', 'silver', '_sources.yml'), 'w').write(
        "sources:\n  - name: bronze_crm\n    schema: \"{{ 'BRONZE_CRM_2' if target.name == 'dev2' else 'BRONZE_CRM' }}\"\n"
        "    tables:\n      - name: T_SRC\n")
    open(os.path.join(d, 'models', 'silver', 'S1.sql'), 'w').write("select * from {{ source('bronze_crm', 'T_SRC') }}")
    open(os.path.join(d, 'models', 'gold', 'G1.sql'), 'w').write("select * from {{ ref('S1') }}")
    b.DBT = d
    models, edges = b.dbt_lineage()
    check('모델 2 인식', set(models) == {'S1', 'G1'})
    check('source 간선 = dev2 분기 기본값 BRONZE_CRM', ('S1', 'source', 'BRONZE_CRM.T_SRC') in edges)
    check('ref 간선', ('G1', 'ref', 'S1') in edges)
    open(os.path.join(d, 'models', 'gold', 'G2.sql'), 'w').write("select * from {{ source('nope', 'X') }}")
    models, edges = b.dbt_lineage()
    check('알 수 없는 source 는 ? 접두로 드러난다', ('G2', 'source', '?nope.X') in edges)

check('레이어 판정', b.layer('BRONZE_CRM') == 'BRONZE' and b.layer('DBT_TEST__AUDIT') == 'ETC')
check('cut 개행 치환·절단', b.cut('a\nb' + 'x' * 400, 10).endswith('…') and '⏎' in b.cut('a\nb'))

sys.exit(1 if fails else 0)
