import io,json
d=json.load(io.open('/workspace/tmp/o262_audit/category_gap_xref.json',encoding='utf-8'))
G=[('A. GOLD 모델 SQL 이 원천 컬럼을 참조 + 이슈 기록 있음 — 개명 승격·조인키·보류 기재 중 하나(감사기 이름매칭 한계 · P13)', lambda r: r['gold_ref'] and r['n_doc_hits']),
   ('B. GOLD 모델 SQL 이 원천 컬럼을 참조 + 기록 없음 — 조인·필터·파생에만 쓰고 열로는 미노출 가능성', lambda r: r['gold_ref'] and not r['n_doc_hits']),
   ('C. GOLD 참조 없음 + 이슈 기록 있음 — 의도적 보류(현업 확인·코드군 미확정 등)', lambda r: not r['gold_ref'] and r['n_doc_hits']),
   ('D. GOLD 참조 없음 + 기록 없음 — 🔴 사유 미기재 누락 후보(승격 여부 결정 필요)', lambda r: not r['gold_ref'] and not r['n_doc_hits'])]
L=['<!-- LLM-METADATA','doc_id: O262_CATEGORY_GAP_AUDIT','doc_role: BRONZE 카테고리성 컬럼 중 GOLD 미반영 점검(O262 · 사용자 지시 · 증거 산출물)','project: GN_DW (굿네이버스)','created: 2026-10-25','created_by: O262','index: 20_issue/00_INDEX_이슈원장.md','END-METADATA -->','',
   '# O262 — BRONZE 카테고리성 컬럼 GOLD 미반영 점검','',
   '> 계정 = UM80684(개발계) · 2026-10-25 · TRIALADMIN / GN_DW_DBT.',
   '> 입력 = `tmp/o262_audit/06_BRONZE노출감사.csv`(생성기 `scripts/run_bronze_audit_host.py` 재실행 · 공유본 30_output_share 는 덮지 않음).',
   '> 분모 = 판정 「SILVER까지만」·「미노출(검토대상)」 611건 → BRONZE 라이브 실측(APPROX_COUNT_DISTINCT · 채움) 611/611 · 미측정 0.',
   '> 카테고리 판정 = 금액·수·일자·ID·본문 이름 제외 후 고유값 ≤60 이고(고유 ≤20 또는 고유/채움 ≤5%) · 또는 고유 ≤200 이고 ≤1%.',
   '> 결과 = **96건**(CATEGORY 90 · CATEGORY? 6). 🔴 APPROX 값이라 경계(60·200) 근처는 근사다.',
   '> 대조 = ① GOLD 모델 SQL 토큰 참조 ② 이슈 문서(10·20·30·50·90 조각 · 31·32·40) 중 보류·결정 어휘가 있는 줄.','']
for title,f in G:
    rs=[r for r in d if f(r)]
    L+=['## %s — %d건'%(title,len(rs)),'','| 원천 | 테이블 | 컬럼 | 고유 | 채움/전체 | 감사 판정 | GOLD 참조 | 기록 좌표 |','|---|---|---|---|---|---|---|---|']
    for r in sorted(rs,key=lambda r:(r['원천시스템'],r['BRONZE_테이블'],r['BRONZE_컬럼'])):
        L.append('| %s | %s | `%s` | %s | %s/%s | %s | %s | %s |'%(r['원천시스템'],r['BRONZE_테이블'],r['BRONZE_컬럼'],r['_d'],r['_f'],r['_n'],r['판정'],', '.join(r['gold_ref'][:2]) or '-',' · '.join('`%s`'%x for x in r['doc_hits'][:2]) or '-'))
    L.append('')
L+=['_Co-authored with CoCo_','']
io.open('/workspace/tmp/o262_audit/O262_카테고리_GOLD미반영_점검.md','w',encoding='utf-8').write('\n'.join(L))
print('ok',len(L))
