# O209 X6 — 기준선(tmp/o208_baseline/_judge.csv) ↔ 재측정(tmp/o209_x6/_judge.csv) 비교
# 비교 단위 = 문항의 「정답 Agent」 쌍(기준선 = 현행 정답 · 재측정 = 수정안 단위) · 같은 판정 규칙
# 사용: python3 tmp/o209_x6_compare.py [AGENT_EXECUTIVE]
# Co-authored with CoCo
import csv, sys
sys.path.insert(0, '/workspace/tmp')
UNIT = {'경영·기획': 'AGENT_EXECUTIVE', '회원': 'AGENT_MEMBER', '마케팅': 'AGENT_MARKETING'}
rows = {r['문항ID']: r for r in csv.DictReader(open('/workspace/12_agent개선과제/06_O208_문항코퍼스.csv', encoding='utf-8'))}
old = {(r['문항ID'], r['Agent']): r for r in csv.DictReader(open('/workspace/tmp/o208_baseline/_judge.csv', encoding='utf-8'))}
new = {(r['문항ID'], r['Agent']): r for r in csv.DictReader(open('/workspace/tmp/o209_x6/_judge.csv', encoding='utf-8'))}
only = sys.argv[1] if len(sys.argv) > 1 else None
T = lambda v: v == 'True'
agg = {'라우팅': [0, 0], '확인': [0, 0, 0], '영문': [0, 0], 'MSTR표기': [0, 0, 0]}
reg, imp = [], []
for k, r in rows.items():
    na = UNIT[r['질문단위_수정안']]
    if only and na != only:
        continue
    oa = r['정답 Agent(현행)'].split('(')[0]
    o, n = old.get((k, oa)), new.get((k, na))
    if not o or not n or n.get('사용도구') == 'MISSING':
        print('MISSING', k, oa, na); continue
    agg['라우팅'][0] += T(o['라우팅판정']); agg['라우팅'][1] += T(n['라우팅판정'])
    if r['계산 전 확인'] == 'Y':
        agg['확인'][0] += T(o['계산전확인']); agg['확인'][1] += T(n['계산전확인']); agg['확인'][2] += 1
    if r['기대 기준'] == 'MSTR':
        agg['MSTR표기'][0] += T(o['MSTR기준']); agg['MSTR표기'][1] += T(n['MSTR기준']); agg['MSTR표기'][2] += 1
    agg['영문'][0] += T(o['영문사고문']); agg['영문'][1] += T(n['영문사고문'])
    if T(o['라우팅판정']) and not T(n['라우팅판정']):
        reg.append((k, oa, na, n['사용도구']))
    if not T(o['라우팅판정']) and T(n['라우팅판정']):
        imp.append((k, oa, na, n['사용도구']))
print('기준선 → 재측정', agg)
print('회귀', reg)
print('개선', imp)
