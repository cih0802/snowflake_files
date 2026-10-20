#!/usr/bin/env python3
"""n03_catalog_build 음성·양성 테스트 — 계보 상향 추적 · 순환 차단 · 누락 표기 · HTML 이스케이프 · 사용법 rc.

실행 = python3 scripts/test_n03_catalog_build.py   (rc=0 전부 통과 · rc=1 실패 있음)
"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import n03_catalog_build as n  # noqa: E402

FAIL = []


def check(name, cond):
    print(('🟢 ' if cond else '🔴 ') + name)
    if not cond:
        FAIL.append(name)


D06 = [
    {'EDGE_TYPE': 'SV base', 'UPSTREAM': 'GOLD.FACT_X', 'DOWNSTREAM': 'SERVING.SV_A (FX)'},
    {'EDGE_TYPE': 'SV base', 'UPSTREAM': 'GOLD.DIM_Y', 'DOWNSTREAM': 'SERVING.SV_A (DY)'},
    {'EDGE_TYPE': 'dbt ref', 'UPSTREAM': 'SILVER.S1', 'DOWNSTREAM': 'GOLD.FACT_X'},
    {'EDGE_TYPE': 'dbt source', 'UPSTREAM': 'BRONZE_CRM.B1', 'DOWNSTREAM': 'SILVER.S1'},
    {'EDGE_TYPE': 'dbt ref', 'UPSTREAM': 'SILVER.S2', 'DOWNSTREAM': 'GOLD.DIM_Y'},
    # 순환(실데이터에는 없어야 하지만 생성기가 멈추면 안 된다)
    {'EDGE_TYPE': 'dbt ref', 'UPSTREAM': 'GOLD.FACT_X', 'DOWNSTREAM': 'SILVER.S1'},
]
D08 = [{'SV_NAME': 'SV_A', 'TABLE': 'FX', 'METRIC': 'M1', 'EXPRESSION': 'SUM(fx.V) <b>'}]
D09 = [{'TOOL_NAME': 't_a', 'TOOL_TYPE': 'cortex_analyst_text_to_sql', 'TARGET': 'SV_A'},
       {'TOOL_NAME': 'search', 'TOOL_TYPE': 'cortex_search', 'TARGET': 'X'}]
D01 = [
    {'DOC_ID': 'K1', 'METRIC': '필드 메트릭', 'TOOL_NAME': 't_a', 'SV_FIELD': 'SV_A.FX.M1'},
    {'DOC_ID': 'K2', 'METRIC': '필드 차원', 'TOOL_NAME': 't_a', 'SV_FIELD': 'SV_A.DY.NAME'},
    {'DOC_ID': 'K3', 'METRIC': 'SV 만', 'TOOL_NAME': 't_a', 'SV_FIELD': ''},
    {'DOC_ID': 'K4', 'METRIC': '배선 없음', 'TOOL_NAME': '', 'SV_FIELD': ''},
    {'DOC_ID': 'K5', 'METRIC': '테이블명 오타', 'TOOL_NAME': 't_a', 'SV_FIELD': 'SV_A.NOPE.M1'},
]

rows = {r['DOC_ID']: r for r in n.build(D01, D08, D09, D06)}

k1 = rows['K1']
check('양성: 필드 메트릭 → GOLD·SILVER·BRONZE 전 단 도달',
      k1['GOLD'] == 'GOLD.FACT_X' and k1['SILVER'] == 'SILVER.S1' and k1['BRONZE'] == 'BRONZE_CRM.B1')
check('양성: 메트릭 식 연결 · 필드종류=메트릭', k1['SV식'].startswith('SUM(') and k1['필드종류'] == '메트릭')
check('음성: 순환 간선이 있어도 종료하고 중복 없음', k1['GOLD'].count('GOLD.FACT_X') == 1)
k2 = rows['K2']
check('양성: 차원 필드 → 식 없음 · 그 논리테이블 계보만', k2['필드종류'] == '차원·사실' and k2['SILVER'] == 'SILVER.S2'
      and 'B1' not in k2['BRONZE'])
k3 = rows['K3']
check('양성: SV 필드 없음 → 도구 대상 SV 전체 base', k3['추적범위'] == 'SV 전체' and k3['대상SV'] == 'SV_A'
      and k3['GOLD'] == 'GOLD.DIM_Y | GOLD.FACT_X')
k4 = rows['K4']
check('음성: 배선 없음 → 계보 비움 · 추적범위=없음', k4['추적범위'] == '없음' and not (k4['GOLD'] or k4['SILVER'] or k4['BRONZE']))
k5 = rows['K5']
check('음성: 논리테이블 불일치를 「필드」로 숨기지 않는다', k5['추적범위'] == '필드(base 미해결)' and not k5['GOLD'])

h = n.render_html(list(rows.values()), 'note <x>')
check('음성: HTML 이스케이프(식의 <b> 가 태그로 렌더되지 않음)', '<b>' not in h.split('<tbody>')[1] and '&lt;b&gt;' in h)

sm = dict(n.summary(list(rows.values())))
check('양성: 요약 합 = 지표 수', sm['추적범위=필드'] + sm['추적범위=필드(base 미해결)'] + sm['추적범위=SV 전체'] + sm['추적범위=없음'] == 5)

long = ' | '.join(f'BRONZE_CRM.T{i:03d}_XXXXXXXXXXXXXXXX' for i in range(60))
c = n.clip_list(long)
check('음성: 긴 계보 목록은 csv 에서 잘리고 남은 개수를 표기(한 줄 2000자 상한)',
      len(c) < 500 and c.endswith('개(전체 = xlsx·html)') and n.clip_list('A | B') == 'A | B')

p = subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'n03_catalog_build.py')],
                   capture_output=True, text=True, stdin=subprocess.DEVNULL, timeout=60)
check('음성: 무인자 실행 rc=2(사용법)', p.returncode == 2)

print(f'{11 - len(FAIL)}/11 통과')
sys.exit(1 if FAIL else 0)
