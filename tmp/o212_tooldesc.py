# O212 — 3종 스펙의 analyst_mstr_spnsr_dvlp 도구 설명에 분류 4축 문장 1개 덧붙이기(멱등)
# Co-authored with CoCo
import yaml
ADD = (' 🆕 [O212-B] 공통브랜드·개발인입경로·캠페인유형(국내/해외)·캠페인유형2(사업/사례)·캠페인카테고리 축도 '
       '이 도구로 분해한다(캠페인 마스터 현재값) — 분류 이름은 원천 컬럼 COMMENT 의 한글 이름 그대로 축에 대응한다.')
for a in ['EXECUTIVE', 'MEMBER', 'MARKETING']:
    p = f'/workspace/cortex_project/agents/AGENT_{a}/agent_spec.yaml'
    d = yaml.safe_load(open(p, encoding='utf-8'))
    n = 0
    for t in d['tools']:
        ts = t.get('tool_spec', t)
        if ts.get('name') == 'analyst_mstr_spnsr_dvlp' and '[O212-B]' not in ts['description']:
            ts['description'] = ts['description'].rstrip() + ADD
            n += 1
    with open(p, 'w', encoding='utf-8') as f:
        yaml.safe_dump(d, f, allow_unicode=True, sort_keys=False, width=200)
    print(a, 'mstr tool updated', n)
