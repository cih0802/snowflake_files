## O245 — 사용자 회신 반영 · ML 특성 배선 · 공112 · W6 (2026-10-18 · trialadmin(iw20760) · ㉡)

- 지시 = 회신 3건(추경 · 공112 · 개발계=운영계 데이터) + ML 예측별 특성 표 「없음」 칸 매핑 가능성 + 승인 전부 · 현업 회신·운영계 반영만 남을 때까지.
- 사용자 결정 = 예산 차수 규칙 현행 유지 · 모델 주석은 「추경은 데이터가 없다」만(원인 문구 금지).
- ㉡ 적용 · 확정위반 0.

### 독해 기록(R1-3-7-b)

- `05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql` 1-472 도착 · ML_SPONSOR_RISK_V · PERCENT_RANK · O241-M.
- `05_SV-Agent_ai/22_ML_SV_DDL.sql` 18-143 · 144-248 · 478-542 도착(수정 대상 SV 3종 블록) · 규칙 (9) · vqr_o198_once_member_div.
- `05_SV-Agent_ai/25_ML_CHURN_CMPGN_CTGR_DDL.sql` 20-130 도착 · vqr_o224_korean_high_risk_list · ACTIVE_SPNSR_CNT.
- `10_dbt_pipeline/models/gold/fact/FACT_AD_PERFORMANCE.sql` 1-198 도착 · video_code_mk · UPPER_CODE.
- `05_SV-Agent_ai/09_2_AGENT_버전업.sql` 174-410 도착 · AGENT_SPEC_STAGE · [0-C].
- read 미반환 0 · 재호출 0.

### 실측 근거(iw20760 · 2026-10-18)

- ERP_BUDGET 2026 추가경정 576행 편성 0 · 연사업 780행 편성 22,554,689,599.
- GA member id ≡ DIM_MEMBER_IDENTITY.MEMBER_DK(불일치 0) · 매칭 세션 58,509 · 회원 36,384 · 센티넬 1행((미매핑)) NULL 처리.
- 공66 원천 MBRFEE_DIV_CD(PM010 E·I·U·G) · SV_MEMBER_FEE.FEE_DIV 라이브 실재.
- W6 = REBRDC_AD_CMPGN_DTLS 상위캠페인코드 방송 165/237 · 재송출 1,722/1,953 · CRM 일치 100% · 캠페인코드 CRM 일치 0.
- 일시전환 대상 8,680명 = CRM_MEMBER 캠페인·상태 0 · DIM_MEMBER 연령·지역 0 · FACT_MEMBER_FEE 8,660 · 법인구분 8,680.
- 뷰 검증 = `tmp/o245/patch_21_test.md`(ONCE 49,858행 = 원천 · ATTR 1,473,162 키 유일 · cs 1,639,419 키 유일).

### 배포(라이브 · GN_DW_ADMIN)

- 05_20 SV_GA_SESSION · 21 뷰 3종(ML_MEMBER_ATTR_ASOF_V · ML_ONCE_CONVERSION_V · 신설 ML_CHURN_BY_SPONSORSHIP_V) · 22 SV 7종 · 25 SV_ML_CHURN_CAMPAIGN.
- AGENT_EXECUTIVE · AGENT_MARKETING VERSION$4(default) · 롤백 VERSION$3.
- dbt 모델 2건(FACT_AD_PERFORMANCE W6 · FACT_BUDGET(_YEARLY) 주석) = 👤 build 대기.
