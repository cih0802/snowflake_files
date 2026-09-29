> #### 🟠 [2026-09-29 O188] 문서20 회신 7건 처분 · 사업목표·공휴일·REBRDC 비용 배선 · Agent 3종 규칙 추가 + 스모크 36/36

- ㉡ 적용(지시 동봉) · 확정위반 0 · 계정 xf98254 · 사용자 포괄 승인
- 문서20 판정 기록 7건(D·E·SVL·AD-2·AD-3·AD-5·F-5) ⇒ 공란 36→29 · 「추가 인입 없음」 사용자 결정으로 D 2건·E·SVL-1~3 = 원천 부재 불가
- AD-3 = `DVLP_UNIT_PRICE = AD_COST ÷ CONV_VU_CNT` 99.90% · 97,906원(이전 114,870) · 「÷10000」 근거는 사용자 정정으로 철회(개발금액÷10000=개발건수 · AD-3 무관)
- 🔴 신규 발견 = DGT 원천이 BRONZE·SILVER 모두 **2026-06 이후만** 존재(6월 이전 개발건수 이력 소실)
- SVL-4 `MS002` 확정 · J3 = **이미 배선**(`CRM_EVENT.sql:42` · 캠페인행사 3,553/3,553)
- 공휴일 = `TM_CM_SCHDUL_MNG` SCHDUL_DIV_CD='0' · 251일 → `DIM_DATE.IS_HOLIDAY` · source `bronze_crm_ref`(BRONZE_CRM_2 부재)
  · 🔴 사용자 build PASS 13 이었으나 `IS_HOLIDAY=TRUE` **0건** — 실행 MERGE 에 조인 없음 ⇒ **DW_PIPELINE 미재배포**(재배포 후 재build 대기)
- 사업목표 = `CRM_BIZ_TARGET` 스캐폴드 → 원천 3,480행(290×12) · GOLD grain 에 GOAL_TYPE_NM·CPR_DIV_NM(이중계상 가드) · WIDE 전파
  · 🔴 `DIM_ORG.DEPARTMENT` 중복 4명(최대 6행) ⇒ 이름 조인 6배 복제 위험 ⇒ 유일 부서만 매칭 · 모의 합계 348,024·348,000 보존
- REBRDC 비용 3컬럼(CONTENTS_PUR_COST·CALL_CTR_OPER_COST·TOT_COST) SILVER·GOLD ALTER 승격 · 근거 = 신규지표 #9 직접모금비
- J5 = GOLD yml 4곳 · `_crm_schema.yml:537` 「error 복귀」 예약 폐기 표기 · 08 DDL 머리 「재실행 후 증분 백필 필수」 경고
- WARN 「BigQuery 적재 공백」 = `OPS.WARN_BIGQUERY_LOAD_GAP` **0행**(백필 반영 확인)
- Agent 3종 orchestration 에 「`__` CTE 에는 metric 없음」 1줄 → MEMBER V6 · EXEC V5 · MKT V5(is_default) ·
  스모크 36/36 · SQL 33 · 중간 invalid identifier 2문항(둘 다 복구) ⇒ 처방 효과 부분적
- `agent_tool_claim_gate` FAIL 1 = 기존 설명 「회원당 1행」(AGENT_MEMBER:318 · 이번 편집 무관 · grain 정의 문구)
- read 미반환 0 · 재호출 0
