<!-- LLM-METADATA
doc_id: HANDOFF_O0233_B
doc_role: 인수인계 — 세션 `O233-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-15
created_by: O233-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0233-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O233-B-0 🔴 먼저 알아라

- 개발계 = jw08094 · 2026-10-15 · **운영계 반영 없음** · ㉡ 적용(사용자 승인).
- 확정위반 0(새로 추가) — O233-A 이월분 4는 그쪽 라벨에만 적는다.
- 🔴 `EXECUTE IMMEDIATE` 안의 `USE ROLE GN_DW_ADMIN` 은 세션 롤을 바꾼 채 남긴다(기본 웨어하우스 없음) ⇒ 끝나면 `USE ROLE ACCOUNTADMIN; USE WAREHOUSE COMPUTE_WH;` 따로 실행.

### ▣ O233-B-1 이번 단위 결과

| 순 | 결과 |
|---|---|
| ① dbt build 확인 | 👤 PASS=41 WARN=0 ERROR=0 SKIP=0 — LTV 최종 중단 · 무기한 반영 정상 |
| ② 검색 고도화 | **진짜 원인 = 임베딩 모델** `snowflake-arctic-embed-m-v1.5`(영어 전용) → `snowflake-arctic-embed-l-v2.0`(다국어 · 한국어 의미 유사도 활성) |
| ③ 스키마 확장 | `BIZ_DEFINITION_CORPUS` ADD COLUMN `KEYWORDS`(자동 변형 = 띄어쓰기 제거·율↔률·누계↔누적·단위 괄호 제거) · `IS_ADDITIVE`(N = 원천 「비가산」 명시 행만) · `SEARCH_TEXT` Markdown 포맷 |
| ④ multi-index | 종전 `ON SEARCH_TEXT`(단일 색인 · 영어 벡터) → `TEXT INDEXES TITLE, KEYWORDS, SEARCH_TEXT` + `VECTOR INDEXES SEARCH_TEXT (model='…l-v2.0')` + `PRIMARY KEY (DOC_ID)` |
| ⑤ 평가 | 40문항(띄어쓰기·율/률·구어체·약어·오타) hit@1 20%→30% · **hit@3 33%→45%** · 후퇴 1건 / 전진 6건 ⇒ V2 우세 |
| ⑥ 승격 | V2 → 정본 이름 `SEARCH_BIZ_DEFINITION`(CREATE OR REPLACE · GRANT 3역할 재부여) · Agent 스펙 서비스명 불변 → 버전업 불필요 |
| ⑦ 정본 DDL | `05_SV-Agent_ai/26_BIZ_DEFINITION_CORPUS_DDL_적재.sql` [1] 컬럼 2개 · [5] multi-index DDL 갱신 |
| ⑧ 빌드 스크립트 | `build_biz_definition_corpus.py` = `variants()`·`keywords()`·`is_additive()` 추가 · Markdown SEARCH_TEXT |
| ⑨ 제안 검토 | 채택 = 하이브리드(방식 수정)·Markdown·SSOT · 대체 = DOMAIN→AGENT_SCOPE 배열 · 부분 = IS_ADDITIVE · **기각 = PHYSICAL_TABLE/COLUMN/DEFAULT_WHERE**(SV 우회 금지) |

### ▣ O233-B-2 ㉠ 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 👤 `dbt build` — O233-A ① 과 같음(이번 단위에서 👤 PASS=41 확인) | #32 |
| ② | 👤 현업 = 「80」 의미 · 재후원 공백 · 관측<80 셀 · 스트림릿 실제 소스 · 대행사 코드 보완 | #32 · 광고비 |
| ③ | 평가 miss 분석(채널·부서·달성률·기대유지개월 등 라우팅 행 hit 불량) = 동의어·description 보강 여지 | RAG |
| ④ | 👤 운영계 = O231·O232·O233 덧입힘 + 검색 서비스 재생성(26 DDL) | #35 |
| ⑤ | 👤 현업 = 처리통보 키워드 | #34 |
| ⑥ | CoWork UI Agent 수동 스모크(트라이얼 DATA_AGENT_RUN 차단) | Agent |

### ▣ O233-B-4 ⚪ 결정 완료(재론 금지)

- 검색 모델 = `snowflake-arctic-embed-l-v2.0`(다국어)(사용자 승인).
- PHYSICAL_TABLE/COLUMN/DEFAULT_WHERE 기각 = SV 우회 금지(사용자 승인).
- O233-A-4 결정 전건 유지.

_Co-authored with CoCo_
