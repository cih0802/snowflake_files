import io
p = '/workspace/20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md'
L = io.open(p, encoding='utf-8').read().split('\n')
i = next(k for k, l in enumerate(L) if l.startswith('| 🟢 **`O201-C`**'))
row = ('| 🟢 **`O201-D`** — MSTR 운영계 적재 범위(2026-01~) 전환 + 누계개발 확정 반영(공45~47) (2026-10-03 · **JU93656**) '
       '| 🟢 SUM 후원금액대2 원천 직접 조회(조회 2,092,147건 일치 · baseline PASS) · 06 운영 루프 10개월 OK(≈29초/월) · '
       'KPI 뷰·SV 작성(사전 검증) · 🟠 dbt build 대기 · 현업 확인 3(단위·공46·공54) | 근거철 §E16 '
       '| `99_NEXT_SESSION-O0201-D.md` · `05_SV-Agent_ai/41_현업요청서_MSTR반영_누계개발.md` |')
L.insert(i, row)
io.open(p, 'w', encoding='utf-8').write('\n'.join(L))
print('ok', i + 1)
