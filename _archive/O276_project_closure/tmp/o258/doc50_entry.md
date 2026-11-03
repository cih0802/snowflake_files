## 🟡 O258-1 — 원천 라벨 하드코딩 제거 · 라벨 매핑 seed 4종 운영 규칙 (2026-10-22 O258 · 개발계 SR61467 적용 · 운영계 대기)

📏 실측(개발계 BRONZE · 근거 = `tmp/o258/evidence.md` E1~E8) = dbt 모델 한글 리터럴 131행 → 92행.
원천 라벨을 직접 비교하던 모델 8종(FACT_BUDGET · FACT_BUDGET_YEARLY · CRM_BIZ_TARGET · FACT_TARGET_PROJECT ·
DIM_SPONSORSHIP · WIDE_DVLP_GOAL_ACMSLT · WIDE_MBRFEE_PRDT_ACTL · WIDE_MEMBER_SERVICE_COHORT · FACT_MESSAGE_DISPATCH)에서 0건.

### 규칙 (다음 세션이 지킬 것)
- 🔴 **원천 라벨 매핑은 seed CSV 가 정본이다** — `10_dbt_pipeline/seeds/MAP_BUDGET_PROCEDURE.csv` ·
  `MAP_SPONSORSHIP_GROUP4.csv` · `MAP_EXT_DATA_TYPE.csv` · `MAP_SERVICE_GROUP_RULE.csv`.
  라벨이 바뀌면 **모델을 고치지 말고** CSV 에 행을 더한 뒤 `dbt seed` → `build`.
- 🔴 **코드 목록은 `macros/gn_biz_codes.sql` `gn_code` 가 정본이다** — 이번 추가 = SEND_TOP_MEMBER_SERVICE(MS054) ·
  EVT_CRMN_CULTURE · EVT_GENERAL_ONLINE · CPR_TONGHAP/SADAN/SABOK(A/I/S) · 매크로 `gn_cpr_token_match`.
- 🔴 **새 seed 는 테이블 DDL 이 먼저다** — GN_DW_DBT 는 SILVER·GOLD CREATE TABLE 이 없다(의도 · 07 §D.9 [1-f]).
  없이 seed 하면 003001. SILVER seed DDL = `04_silver_design/08_SILVER_테이블DDL_20260714.sql` 끝 ·
  기존 환경 = `05_SV-Agent_ai/38_DEPLOY_MAP_SEEDS.sql` [D1]. 🔴 권한으로 풀지 마라.
- 🟢 감시 = `tests/warn_map_coverage_sponsorship_group4.sql` · `warn_map_coverage_budget_procedure.sql` ·
  `warn_map_coverage_ext_data_type.sql`(warn · 원천에 있고 seed 에 없는 라벨) · yml 허용목록 5곳 → seed `relationships`.
- 🟢 남은 리터럴 92 = 센티넬(`(미매핑)` 등) · dbt 가 스스로 만드는 라벨(서신·선물금·회비 · MATCH_BASIS · 구간) ·
  seed 표준 어휘 비교(`당초`·`추경`·`목표`·`실적`) — 「업무 라벨 0」까지 빼면 열 이름·출력 라벨까지 seed 화해야 해 가독성이 떨어진다(사용자 「최대한 줄이는 방향」).

### 동작 변경 3건
- 법인 판정 = CM019 사전 라벨 **토큰 정확일치**(종전 `LIKE` 순서판정은 `통합재후원감사문자_사단` · `통합후원감사문자_사단` 을
  통합으로 오분류 · 개발계 해당 발송 0건 ⇒ 현재 영향 0).
- 표기 `추경` 차수 순번 0 → 2(현재 원천 0행) · CM003 `선물금` → 4그룹 `기타`(사용자 결정 · 사용 0).

### 검증 (개발계 SR61467 · 2026-10-22)
- 👤 build PASS=721 WARN=23 ERROR=0 · seed 3/7/6/11 · 회원서비스 SERVICE_MEMBERS 746,103 = 종전 라벨 판정 ·
  개발목표 576행 신구 차이 0 · 회비예측 528 동일 · 커버리지 미매핑 0.

### 🟡 열린 항목
- ① 운영계 = 문서실행순서 「기존 환경 갱신」 33(ADMIN [D1] → 👤 dbt 재배포·seed·build → [D3]) · SV 재배포 불요.
- ② SV COMMENT 「실제값 N종」 열거(조직트리 8종 · 지역 19종 · 성별 9종 등) 라이브 대조 — GOLD 원천이라 O258 당시 미측정(개발계 build 후 측정 가능).
- 닫을 때 = 제목 이모지를 🟢 로 바꾸고 이 절에 결과를 덧붙인다.

---
_Co-authored with CoCo_
