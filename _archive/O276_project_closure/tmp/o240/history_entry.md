## O240-A 운영계 실데이터 지표 계산 가능성·이상치 점검 → 파이프라인·SV·Agent 보강 (2026-10-16 · ua91864 · ㉡ · 사용자 승인(전부 진행) · 확정위반 1)

- 착수 = 사용자 「운영계 데이터 끌어옴 · 지표사전대로 Agent 계산 가능한지 · 이상치 정리」 → 「번호 선점 · 분석 검토 · 계획」 → 「멈출 것 없이 다 진행」.
- 🔴 확정위반 1 = 1차 분석(같은 세션 직전 턴)에서 stale CSV(10-07)·잘못된 SV 조회 문법(`SELECT *`)·채널 혼합 비교로
  거짓 이상치 6건(SV 15종 FAIL · 신27~29·신44·49 산출불가 · 오픈율>100% · 집행율 250% · 신10)을 보고했다 → 재측정으로 철회.
- 실재 이상치(실측 ua91864 2026-10-16):
  - VIDEO 원천 `BRDC_DATE` = 1970-01-01 1,573행(2.25억 원) — DIGITAL 은 O182 에서 처리됐고 VIDEO 는 누락.
  - 회비원장 `TM_PM_MBRFEE_ACMSLT` = 2021년 6,319행 → 2022년 9,559,984행 ⇒ FMM 1월 스파인 2021 25,074 vs 2022 639,941
    ⇒ 캠페인 누계중단율 201912 85.61 · 202012 98.76 · 202112 87.57(2022~ 14~19) · 202109 캠페인 미납율 0 · 활동율 10.49 · 중단율 59.38.
  - 미래 회비월 202611~202911 1,197행(정기 회비 선납 · 납입일 ≤ 20261015) · 회비월 0 138행.
  - GA `FACT_BIGQUERY_BEHAVIOR.AVG_SESSION_DURATION·BOUNCE_RATE` 전건 NULL → 세션 팩트 파생 32.9초 · 53.82%.
  - 2026 연 편성예산 0(SV_BUDGET_YEARLY 집행율 NULL) · 2024 98.11 · 2025 99.69.
  - CTR 분모 0 클릭 DIGITAL 3,190행 · 음수 광고비 DIGITAL 23 · VIDEO 3.
- 집행(파일) = AGENCY_AD_PERFORMANCE·AGENCY_AD_BROADCAST(NULLIF 에포크) · FCM·FCCS 기준월 = var `billing_coverage_start_month`(202201) ~ 당월 ·
  SV_GA_SESSION metric 2 · SV_AD CTR 분자 가드 · Agent 3종 orchestration [O240] 규칙 · 배포순서 `05_SV-Agent_ai/30_O240_실데이터이상치_배포순서.sql`.
- 🔴 라이브 미집행 = Restricted Session Scope 가 DBT PROJECT·SEMANTIC VIEW OWNERSHIP 과 `DATA_AGENT_RUN` 을 거부(함수 실재는 SHOW 로 확인 · J6).
  ⇒ D1~D5 는 사용자 실행 대기 · Agent 실질의 미실행(SV 직접 조회로 대체 검증).
- 코퍼스 = 오버레이·CSV 재생성 결과 바이트 동일(공91·98·108 사전 FORMULA 공란 → 오버레이 비대상) ⇒ 재적재 불필요.
- 게이트 = agent_object_ref·agent_tool_claim·agent_source_lineage·sv_identifier·sv_unit·jinja PASS · line_len PASS · index_row PASS.

### 독해 기록(`R1-3-7-b`)

- `00_guides/00_작업지침_세션운영규칙.md` 1~304 · 도착 · `R0-8-4` · `R4-4-4`.
- `20_issue/00_BRIEF.md` 1~129 · 도착 · `O0239-A` · `조문 112개`.
- `99_NEXT_SESSION-O0239-A.md` 1~49 · 도착 · `VERSION$7` · `O239_unmatched_link_values`.
- `FACT_CAMPAIGN_CUM_STOP.sql` 1~99 · `AGENCY_AD_PERFORMANCE.sql` 55~80 · `AGENCY_AD_BROADCAST.sql` 1~36 · `05_20_SV_DDL_GA_SESSION.sql` 57~97 · 도착 · `ys_by_month` · `AD_DATE_RESOLVED` · `vqr_o213f_donor_type`.
- read 미반환 0 · 재호출 0.

_Co-authored with CoCo_
