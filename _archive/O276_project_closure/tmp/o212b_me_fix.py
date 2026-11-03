# O212-B — 05_2_SV_DDL_MEMBER_EVENT.sql 분류 축 동의어를 원천 컬럼 COMMENT 명칭 기준으로 교정
# Co-authored with CoCo
import sys
p = '/workspace/05_SV-Agent_ai/05_2_SV_DDL_MEMBER_EVENT.sql'
t = open(p, encoding='utf-8').read()
R = [
    ("WITH SYNONYMS ('세부 브랜드', '캠페인 브랜드', 'CRM 브랜드') COMMENT = '캠페인 세부 브랜드(CRM 원천 · 세부). 🆕 [O212] 「브랜드」·「공통브랜드」 질문은 이 축이 아니라 CMMN_BRND_NM(공통브랜드 · 대분류)이다 — 「세부 브랜드」·「CRM 브랜드」 명시 시만 쓴다',",
     "WITH SYNONYMS ('브랜드', '브랜드명', '캠페인 브랜드') COMMENT = '캠페인 브랜드명(원천 COMMENT = 브랜드). 🆕 [O212-B 원천 컬럼명 원칙] 「브랜드」는 이 축이다 — 「공통브랜드」를 말할 때만 CMMN_BRND_NM 을 쓴다',"),
    ("WITH SYNONYMS ('공통브랜드', '공통 브랜드', '브랜드', '브랜드 대분류') COMMENT = '공통브랜드 라벨(코드사전 MM297). 🆕 [O212] 「브랜드별」·「공통브랜드 기준」 질문의 기본 축(대분류)이다.",
     "WITH SYNONYMS ('공통브랜드', '공통 브랜드') COMMENT = '공통브랜드 라벨(코드사전 MM297). 🆕 [O212-B] 「공통브랜드」를 말할 때 쓴다(「브랜드」는 CAMPAIGN_BRAND)."),
    ("WITH SYNONYMS ('캠페인유형2', '캠페인유형', '캠페인 유형', '캠페인 대분류', '사업사례구분', '사업/사례') COMMENT = '🆕 [O212] **캠페인유형2**(MM296 · 캠페인 대분류) — 「캠페인유형」·「캠페인유형2」 질문의 기본 축이다(세부는 CAMPAIGN_TYPE 캠페인카테고리 · 엄격한 상하위 계층은 아니다).",
     "WITH SYNONYMS ('캠페인유형2', '캠페인유형(사업/사례)', '사업사례구분', '사업/사례') COMMENT = '🆕 [O212-B] **캠페인유형2**(원천 COMMENT = 캠페인유형(사업/사례) · MM296) — 「캠페인유형2」 질문의 축이다. 「캠페인유형」은 DOMESTIC_OVERSEAS(국내/해외)다."),
    ("WITH SYNONYMS ('국내해외', '국내외') COMMENT = '캠페인 국내/해외 구분(MM295).",
     "WITH SYNONYMS ('캠페인유형', '캠페인 유형', '캠페인유형(국내/해외)', '국내해외', '국내외') COMMENT = '🆕 [O212-B] **캠페인유형**(원천 COMMENT = 캠페인유형(국내/해외) · MM295) — 「캠페인유형」 질문의 축이다."),
    ("🆕 [O212] 「캠페인카테고리」·「주요캠페인」을 명시할 때만 쓴다 — 「캠페인유형」은 대분류 BIZ_CASE_TYPE(캠페인유형2) 이다.",
     "🆕 [O212-B] 「캠페인카테고리」·「주요캠페인」을 명시할 때만 쓴다 — 「캠페인유형」은 DOMESTIC_OVERSEAS · 「캠페인유형2」는 BIZ_CASE_TYPE 이다."),
]
for a, b in R:
    n = t.count(a)
    if n != 1:
        sys.exit(f'앵커 {n}회 — 중단: {a[:60]}')
    t = t.replace(a, b)
open(p, 'w', encoding='utf-8').write(t)
print('OK', len(R))
