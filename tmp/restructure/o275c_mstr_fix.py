"""O275-C mstr-migration SKILL.md 옛 경로 → MOVE_MAP 새 경로(정확 치환 · 건수 단정)."""
import io
P = '/workspace/.snowflake/cortex/skills/mstr-migration/SKILL.md'
R = [
    ('`15_MSTR 이관 PoC/tools/`', '`20_build/25_mstr_migration/tools/`', 1),
    ('cd "15_MSTR 이관 PoC/tools"', 'cd 20_build/25_mstr_migration/tools', 1),
    ('`snowflake 적용 ddl/`', '`snowflake_적용_ddl/`', 2),
    ('`05_SV-Agent_ai/23_MSTR_SV_DDL.sql` 형식', '`20_build/23_sv_agent/_archive/23_MSTR_SV_DDL.sql` 형식', 1),
    ('`cortex_project/agents/', '`20_build/28_cortex_project/agents/', 1),
    ('`05_SV-Agent_ai/09_2_AGENT_버전업.sql`', '`20_build/23_sv_agent/09_2_AGENT_버전업.sql`', 1),
    ('`05_SV-Agent_ai/09_0_AGENT_정의서.md`', '`20_build/23_sv_agent/09_0_AGENT_정의서.md`', 1),
    ('`05_SV-Agent_ai/41_현업요청서_MSTR반영_누계개발.md`', '`20_build/23_sv_agent/41_현업요청서_MSTR반영_누계개발.md`', 1),
]
t = io.open(P, encoding='utf-8').read()
for a, b, n in R:
    c = t.count(a)
    if c != n:
        raise SystemExit(f'count mismatch {a!r}: {c} != {n}')
    t = t.replace(a, b)
for old in ('15_MSTR 이관', '05_SV-Agent_ai', '`cortex_project', 'snowflake 적용'):
    if old in t:
        raise SystemExit(f'residual {old!r}')
io.open(P, 'w', encoding='utf-8').write(t)
assert io.open(P, encoding='utf-8').read() == t
print('OK', sum(n for *_, n in R), 'replacements')
