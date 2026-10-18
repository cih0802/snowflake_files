# O245 — Agent 스펙 추경 문안 교체(사용자 2026-10-18: 원인 없이 「추경 데이터 없음」만 쓴다 · 공153·155 산출 불가)
import io
OLD = '추경이 아직 편성되지 않은 연도(2026)는 연사업 편성 기준 집행율이다 — 「추경 미편성 · 연사업 기준」을 밝힌다.'
NEW = ('추경 편성 데이터가 없는 연도(2026)는 연사업 편성 기준 집행율이다 — 「추경 데이터 없음 · 연사업 기준」을 밝힌다. '
       '추경목표·추경 누계목표(공153·공155)는 데이터가 없다 — 「산출 불가(추경 목표 데이터 없음)」로 답한다.')
for a in ('AGENT_EXECUTIVE', 'AGENT_MARKETING'):
    p = '/workspace/cortex_project/agents/%s/agent_spec.yaml' % a
    s = io.open(p, encoding='utf-8', newline='').read()
    assert s.count(OLD) == 1, a
    io.open(p, 'w', encoding='utf-8', newline='').write(s.replace(OLD, NEW))
    print('OK', a)
