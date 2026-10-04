#!/usr/bin/env python3
# O201-B — EXEC·MKT 스펙의 「BRONZE_GA4 실재하지 않는다」 사실 오류 교정(JU93656 실측: 스키마 실재 · 미배선)
import io, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R = {
    'AGENT_EXECUTIVE': [('`BRONZE_GA4` 라는 스키마는 실재하지 않는다',
                         '`BRONZE_GA4` 는 GA4 인구통계 원천만 담고 광고 SV 에 배선되지 않았다')],
    'AGENT_MARKETING': [('`BRONZE_GA4` 스키마는 실재하지 않는다',
                         '`BRONZE_GA4` 는 GA4 인구통계 원천만 담고 광고 SV 에 배선되지 않았다'),
                        ('BRONZE_GA4 라는 스키마는 존재하지 않는다',
                         'BRONZE_GA4 는 GA4 인구통계 원천만 담고 이 도구에 배선되지 않았다')],
}
for a, pairs in R.items():
    p = os.path.join(ROOT, 'cortex_project', 'agents', a, 'agent_spec.yaml')
    s = io.open(p, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (a, old)
        s = s.replace(old, new, 1)
    io.open(p, 'w', encoding='utf-8').write(s)
    assert io.open(p, encoding='utf-8').read() == s
    print(a, 'OK')
