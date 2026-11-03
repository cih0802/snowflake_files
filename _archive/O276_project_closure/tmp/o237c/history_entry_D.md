## O237-D O237-C 라이브 집행 · 스모크 라우팅 시정 2 · O237 🟢 (2026-10-16 · ua91864 · ㉡ · 사용자 승인(dbt 실행 포함) · 확정위반 0)

- 착수 = 사용자 「GA 백필 완료 · dbt 실행 권한 승인 · 니가 다 해」.
- GA 백필 확인 = SILVER.BIGQUERY_BASIC·EVENT 11,324,179(= 원천) · GOLD.FACT_BIGQUERY_BEHAVIOR 1,708,325 · SESSION 1,254,261 · WARN_BIGQUERY_LOAD_GAP 0.
- [C1] FSM CREATE IF NOT EXISTS → 소유자 ACCOUNTADMIN 으로 생성돼 `GRANT OWNERSHIP … TO GN_DW_ADMIN COPY CURRENT GRANTS` · grant 25행이 FCM 과 동형 · FK 1 · [C2] ALTER 3열.
- dbt = `ALTER DBT PROJECT … ADD VERSION O237C_20261016` → build PASS 48 · WARN 2 · ERROR 1(`accepted_values MKTG_MAP_METHOD` 에 신규값 UPPER_CODE 부재) → yml 값 추가 · 06_DDL·라이브 COMMENT 동기 → 버전 `O237C_20261016_B` → FACT_AD_PERFORMANCE 재 build SUCCESS(테스트 PASS).
- 대사 = FSM 465개월 BAD 0 · DUP 0 · DIM_MEMBER 1,800,737 중 LAST_CAMPAIGN 1,621,462 · FMD 2025~ 클릭 126,799 · D5 377 · D30 1,839 · 영상 NAME 2,474 · UPPER_CODE 3,406(570,290,584.55원) · NONE 42,484(5,924,770,020원) = 사전 측정 일치.
- SV 5종 = `deploy_sv.py --apply`(DDL 8·7·8·8·9) · 코퍼스 = 26 [1]~[6](16문) · COVERAGE 기대 분포 · 검색 「후원사업별 미납율 계산식」 1위 = MET_CMN-79.
- 스모크(DATA_AGENT_RUN):
  - ② 「2026년 9월 후원사업별 미납율」 1차 = analyst_member_fee 청구 대비 14.05%(공79 아님) ⇒ MEMBER·MARKETING orchestration 에 [O237-C 후원사업별 미납율] 1문장 · 2차 = sponsor_biz 15.70% ✅.
  - ① 「최종캠페인별 회원수」 1차 = 타임아웃 · 재시도 = sponsor_biz 대표캠페인 축 ⇒ MEMBER·EXECUTIVE 에 [O237-C 최종캠페인] 1문장 · 2차 = LAST_CAMPAIGN_NAME 25,594명 ✅.
  - ③ 클릭대비 전환 = 5일 0.30% · 30일 1.45% ✅ · 특집 광고비 = RT_TYPE '방송' 14,801,599,992원 ✅.
- Agent 배포 = `tmp/o237c/patch_agents*.py`(앵커 1회 · yaml 파싱 diff = 추가 문장만) → COPY FILES → 스테이지 원문 대조(임시 FF_RAW · CONTAINS TRUE · 길이 일치) → ADD VERSION · 기본 = MEMBER V$6 · MARKETING V$5 · EXECUTIVE V$5.
- 🔴 판정 함정 1 = 스테이지 대조를 기본 CSV 형식으로 읽어 0 이 나왔다(줄·쉼표 분할) — 구분자 NONE 형식으로 재대조해 TRUE.

_Co-authored with CoCo_
