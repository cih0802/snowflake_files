<!-- LLM-METADATA
doc_id: HANDOFF_O0232_B
doc_role: 인수인계 — 세션 `O232-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-15
created_by: O232-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0232-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O232-B-0 🔴 먼저 알아라

- 개발계 = jw08094 · 2026-10-15 · **운영계 반영 없음** · 지시 = 「원천 카테고리는 SILVER·GOLD 까지 전부 올리고 SV 에 배선」(사용자).
- 확정위반 0 — dbt 는 사용자가 실행(R4-1 준수) · 쓰기 뒤 `line_len.py` 실행(SV_AD 2,308자 1회 적발 → 줄 분리 후 PASS).
- ⚠️ 함정 2 = ① `python3 - <<EOF </dev/null` 은 heredoc 을 `/dev/null` 이 덮어 **스크립트가 빈 채로 rc=0** 이다(두 번 겪음 · 파일 수정 없음) ⇒ 스크립트는 파일로 쓰고 실행한다.
  ② 스테이지 경로에 한글 파일명이 있으면 `FROM '@stage/한글.csv'` 처럼 **따옴표 필수**(없으면 syntax error).
- 👤 build PASS=119 WARN=2 ERROR=0 — WARN 2건 이름은 확인 못 함(`target/run_results.json` 이 이전 실행분 · 클라이언트 실행 로그 미동기). 신규 테스트 조건은 SQL 로 직접 대조해 위반 0.

### ▣ O232-B-1 이번 단위 결과

| 순 | 결과 |
|---|---|
| ① 검증(O232) | FAP 소재 매핑 build = 사전계산 일치 48.6 · 157.8 · 22.1 · 20.3억 · 행 271,489 불변 |
| ② SILVER | `AD_CREATIVE_CAMPAIGN_MAP.CMPGN_CTGR_CD` 추가(08 DDL 맨 끝 · ADMIN ALTER · 165/165 · 이름↔코드 1:1 실측 59/59) · CSV 15열째 `확정 캠페인카테고리 코드` |
| ③ 적재 SQL | 🆕 `04_silver_design/09_SILVER_AD_CREATIVE_CAMPAIGN_MAP_적재.sql`(COPY FILES → INSERT OVERWRITE) · 재실행 전후 내용 HASH_AGG 동일 7963618648146738709 · 빈 문자열 소재명 1건(VIDEO −1,750만) 보존 |
| ④ GOLD | DIM_MARKETING_CAMPAIGN `CMPGN_CTGR_CD/NM/IS_MULTI`(대표 = 매핑 행수 최다 → 코드 오름차순 · 다중 273/590) · FAP `AD_CTGR_CD/NM/SRC/IS_MULTI`(이름매칭 → 그 캠페인 · UTM → 그 캠페인 · 그 밖 → 소재 매핑 확정 · iff 우선순위) · WIDE·yml · 06_DDL · ADMIN ALTER 7컬럼 |
| ⑤ 테스트 | `AD_CTGR_SRC` accepted_values · `AD_CTGR_CD` relationships(CRM_CAMPAIGN) · 🆕 `tests/assert_fap_ad_ctgr_consistency.sql`(출처↔값 · CREATIVE_MAP 다중 FALSE · 코드↔이름 · 차원 대표 = 팩트) |
| ⑥ SV_AD 배포 | ad 차원 4(AD_CTGR_*) · mktg 차원 2(CMPGN_CTGR_NM·IS_MULTI) · VQR `vqr_o232b_ad_cost_by_category` · 규칙 「카테고리별 광고비 금지」(O225-C) → 「ad.AD_CTGR_NM + 다중 대표 광고비 + 귀속 없음 광고비 동반 · 배분 금지」(인입경로·채널 금지는 유지) · 스모크 = GOLD 와 일치 |
| ⑦ 실측 | MKTG_REP 307.4억(다중 대표 221.1 = 72%) · CREATIVE_MAP 206.5 · NONE 42.5 · 합 556.3억(SV = GOLD) |
| ⑧ 문서 | `문서실행순서.md` 개발계·운영계에 적재 SQL 단계 삽입(재번호 51·47) · O231·O232 주석 · 「O231·O232 만 덧입힐 때」 4단계 · 백로그 #35(✅)·#36(⚪) |

### ▣ O232-B-2 ㉠ 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 👤 다중 카테고리 캠페인 = 카테고리명 나열 컬럼 착수 여부(표시 전용 · 그루핑·합산 금지 · 최대 21개 212자) | #36 |
| ② | 👤 운영계 = 문서실행순서 「O231·O232 덧입힐 때」 ①~④ | #35 · 런북 §7-A |
| ③ | 👤 LTV 상한·학습기간·셀최소 결정 → vars → build | #32 |
| ④ | 👤 WARN 2건 이름 확인(클라이언트 build 로그) — 종전 상시 WARN(FMF·FMM relationships 등)인지 대조 | 이번 단위 |

### ▣ O232-B-4 ⚪ 결정 완료(재론 금지)

- 카테고리 축은 원천(CRM 캠페인카테고리) 그대로 SILVER·GOLD·SV 까지 올린다 · 대표값은 숨기지 않고 `*_IS_MULTI` 와 함께 쓴다(사용자 O232-B).
- 카테고리별 광고비는 ad 축(`AD_CTGR_NM`)으로 낸다 — mktg 축은 미연결 재방송·영상을 놓친다.
- O232-A-4 결정 전건 유지.

_Co-authored with CoCo_
