"""O275-C mstr-migration 스킬 옛 경로 해석(읽기 전용) — MOVE_MAP_files.csv 기준."""
import csv
ROOT = '/workspace'
rows = list(csv.DictReader(open(f'{ROOT}/MOVE_MAP_files.csv', encoding='utf-8-sig')))
summ = list(csv.DictReader(open(f'{ROOT}/MOVE_MAP.csv', encoding='utf-8-sig')))
print('summary cols', list(summ[0].keys()))
Q = [
    '15_MSTR 이관 PoC/tools/README.md',
    '15_MSTR 이관 PoC/tools/manifests/1차.json',
    '15_MSTR 이관 PoC/tools/mstr_pipeline.py',
    '05_SV-Agent_ai/23_MSTR_SV_DDL.sql',
    '05_SV-Agent_ai/09_2_AGENT_버전업.sql',
    '05_SV-Agent_ai/09_0_AGENT_정의서.md',
    '05_SV-Agent_ai/41_현업요청서_MSTR반영_누계개발.md',
    'cortex_project/agents/AGENT_MEMBER/agent_spec.yaml',
    'tmp/o207_agent_patch.py',
]
m = {r['old_path']: r for r in rows}
for q in Q:
    r = m.get(q)
    print(q, '->', (r['new_path'], r['action']) if r else 'NOT IN MAP')
for r in rows:
    if 'MSTR_1차이관_Snowflake전환_작업계획' in r['old_path'] or '적용 ddl' in r['old_path'] and r['old_path'].count('/') == 1:
        print('MATCH', r['old_path'], '->', r['new_path'])
for r in summ:
    if r['old_path'].startswith(('15_MSTR', '05_SV', 'cortex_project')):
        print('SUMM', r['old_path'], '->', r['new_path'], r['action'])
