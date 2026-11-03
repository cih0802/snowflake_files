# O258 증거 — 하드코딩 리터럴 실측 (2026-10-22 · TRIALADMIN(SR61467) · 개발계)

> R1-3-7-c: 판정 전에 원문과 실측을 기록한다. 추출물은 `tmp/o258/literals_dbt.csv`(131행 · `extract_dbt.py`).

## E1. 개발계 상태
- SILVER.CRM_CODE · SILVER.ERP_BUDGET · SILVER.CRM_BIZ_TARGET · GOLD.DIM_SEND_TYPE = **0행**(dbt 미빌드).
- 같은 시점 BRONZE_CRM.TC_CMMN_DTL_CD = 5,903행 · BRONZE_ERP.BDGT_ACMSLT_LEDGER = 405행.
- ⇒ 대조 기준은 **BRONZE 원본**(R2-3)이다. 운영계 값은 미측정(재측정 대기).

## E2. BRONZE distinct 실측
| 축 | 원천 | 값(행수) |
|---|---|---|
| CM003 후원그룹 코드명 | BRONZE_CRM.TC_CMMN_DTL_CD | 결연 · 국내 · 기타 · 북한 · **선물금** · 해외 · 해외구호 |
| CM003 사용(후원사업) | TM_CM_SPNSR_BSNS_INFO | 결연 1 · 국내 17 · 기타 21 · 북한 3 · 해외 2 · 해외구호 6 · 선물금 0 |
| CM019 법인 | TC_CMMN_DTL_CD | 사단 · 사복 · 통합 |
| ERP 예산절차 | BRONZE_ERP.BDGT_ACMSLT_LEDGER.BDGT_PRCD_NM | 연사업 215 · 추가경정 190 |
| 사업목표 예산절차 | BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV.BDGT_PRCD_NM | 연사업 437 |
| 개발목표 DATA_TYPE_NM | SILVER.ANNUAL_DVLP_GOAL_ACMSLT_AGGR_DATA(외부 적재) | 목표 48 · 실적 48 |
| 회비예측 DATA_TYPE_NM | SILVER.ANNUAL_MBRFEE_PRDT_ACTL_DATA(외부 적재) | 예측 528 |
| 후원분류 AGGR_TY_NM | SILVER.MM_SPNSR_CLS_AGGR_DATA(외부 적재) | 감액 · 개발 · 중단 · 활동 · 회비 (각 330) |
| 발송 대분류 | BRONZE_CRM.SND_REQ_MST.SEND_GBN_TOP_NM | 결연 · 기타 · 사업보고 · 서비스 · 참여 · 회비 · 회원 · 회원만족 · 회원서비스 |
| MS049 상위 06/23/24/43 | TC_CMMN_DTL_CD | 장기회원감사서비스(사단/사복/통합) · 개별화 서비스 신규(사단) |

## E3. 원문 인용 (리터럴 ↔ 원천 라벨 직접 비교)
- `gold/dim/DIM_SPONSORSHIP.sql:61-68` = `CASE cd_grp.DTL_CD_NM WHEN '국내' … WHEN '해외구호' THEN '해외프로젝트' … WHEN '기타' THEN '기타' END`
- `gold/fact/FACT_BUDGET.sql:31-34` · `FACT_BUDGET_YEARLY.sql:40-41` = `case BUDGET_PROCEDURE when '추가경정' then 2 when '연사업' then 1 else 0`
- `silver/crm/CRM_BIZ_TARGET.sql:51-54` = `CASE … WHEN '연사업' THEN '당초' WHEN '추가경정' THEN '추경' ELSE COALESCE(…, '당초')`
- `gold/fact/FACT_TARGET_PROJECT.sql:36-37` = `TARGET_TYPE = '당초'` · `TARGET_TYPE LIKE '추경%'`
- `gold/wide/WIDE_DVLP_GOAL_ACMSLT.sql:32-33` = `IFF(DATA_TYPE_NM = '목표' …)` · `IFF(DATA_TYPE_NM = '실적' …)`
- `gold/wide/WIDE_MBRFEE_PRDT_ACTL.sql:30-39` = 예측/실적/연도초예측/연초예측 → DATA_TYPE_STD · IS_FORECAST (O257 추정 처방)
- `gold/wide/WIDE_MEMBER_SERVICE_COHORT.sql:51-62` = 발송 제목 ILIKE 패턴 9종(`'%년%회원%감사%'` 등) · `:77-79` = 코드명 `like '%사복%'`
- `gold/fact/FACT_MESSAGE_DISPATCH.sql:179-180` = `sl.SEND_TYPE_L = '회원서비스'`
- `silver/_sources.yml:79` = `"회원실 연간 회비 예측 실측 데이터(DATA_TYPE_NM = 예측/실측)."` ← 라이브 라벨은 `예측`·`실적`

## E4. 추가 실측
- BRONZE TM_CM_MBER_DVLP_GOAL_DIV: GOAL_TYPE_NM 9종(회원개발 136 · 후원사업 154 · 정기회비 33 …) ·
  NEW_OLD_DIV_NM = 기존 · 신규 · 신규합계 · 합계 · NULL · CPR_DIV_NM = 사단 · 사복 · ORG_DIV_NM = 대면 · 본부 · 지부 · NULL
- BRONZE_ERP BDGT_UNIT_NM = 마케팅기획1팀 · 마케팅기획2팀 · 매체운영팀 · 사회복지법인예산 · 컬쳐콘텐츠팀
  (accepted 7종 중 데이터분석센터 · 콘텐츠기획팀 은 현재 0행 = 상위집합 · 무해)
- 중단경로 코드명 = CRM · SYSTEM · 홈페이지 (accepted 일치)
- SILVER.BIGQUERY_REFINED_DATA.EP_EVENT_CATEGORY: `후원창` 292,908 · `캠페인스크롤깊이` 1,007,935 · `나의후원` 134,265 (GTM 수기 라벨)
- SV 서술형 `''값''` 324종 798회(`sv_literals_distinct.csv`) → 사전/dbt 대조 = 사전 일치 171 · dbt 생성 30 ·
  미일치 123(대부분 정규식이 서술 조각을 잡은 것 · 실값은 GOLD 조직트리·GA·사업목표 라벨)
- SV 필터형(연산자) 16건 · 13쌍(`literals_sv.csv`) — 전부 실측 값과 일치
- Agent 라이브 3종 instructions 리터럴 22건 · 필터형 2건(`ACQ_CPR_DIV`·`SPONSORSHIP_CPR_DIV_NM` = `사단`) = CM019 일치
- yml accepted_values 112건 = error 81(한글 0) · warn 한글 21 · error 한글 7 · warn 3

## E5. 판정 (위 근거 기준 · 개발계 BRONZE)
### ㉠ 이미 어긋남 (1)
- `_sources.yml:79` 설명 `예측/실측` ↔ 라벨 `예측`·`실적`·`연도초예측` (문서만 · 실행 영향 0)

### ㉡ 앞으로 어긋날 위험 (원천 라벨을 여러 곳에서 직접 비교)
| # | 개념 | 위치 | 위험 |
|---|---|---|---|
| A | 예산절차 | FACT_BUDGET:31 · FACT_BUDGET_YEARLY:40 · CRM_BIZ_TARGET:51 · FACT_TARGET_PROJECT:36-37 | 같은 개념이 4곳 · 어휘 2벌(`추가경정`↔`추경`) · 미지 라벨은 SEQ 0 / 원문 통과 · accepted 불일치(SILVER warn 3종 ↔ GOLD error 2종) |
| B | 후원그룹 4분류 | DIM_SPONSORSHIP:61-68 | CM003 `선물금` 미규칙 → NULL(현재 사용 0) |
| C | 외부 적재 구분 | WIDE_DVLP_GOAL_ACMSLT:32-33 | `목표`/`실적` 원문 비교 · MBRFEE 와 달리 표준화 없음 |
| D | 서비스 그룹 판정 | WIDE_MEMBER_SERVICE_COHORT:51-62 | 발송 제목 ILIKE 9종 인라인 · O205-B 에 이미 한 번 어긋났다 |
| E | 법인 | WIDE_MEMBER_SERVICE_COHORT:77-79·138-140 | 코드명 부분일치(`%사복%`) · 코드(I/S/A) 대신 라벨 |
| F | 발송 대분류 | FACT_MESSAGE_DISPATCH:179-180 | `SEND_TYPE_L = '회원서비스'` 라벨 비교(코드 MS054 있음) |

### ㉢ 안전
- 센티넬 `(미매핑)`·`(해당없음)`·`(unknown)` · dbt 가 스스로 만드는 라벨(서신·선물금·회비·기부금 · 일반행사/캠페인행사 · 신규/기존 · 상계사유 · 구간 라벨 · 생존 AXIS_TYPE)
- SV 필터형 16건 · Agent 필터형 2건 = 현재 실측 일치

### 재측정 대기 (R2-8-4-c)
- SV COMMENT 「실제값 N종」 열거(조직트리 8종 · 지역 19종 · 성별 9종 등) = GOLD 원천 → 개발계 GOLD 83개 중 1개만 데이터가 있음 ⇒ build 후 또는 운영계에서 대조

## E6. 처방 설계 근거 (사용자 결정 2026-10-22 = 범위 ㉠·A~F 전부 · seed CSV · 선물금 → 기타)
- CM019 = A 통합 · I 사단 · S 사복 · 발송 대분류 MS054 = 회원서비스(1:1) · BRONZE SND_REQ_MST 실측
- E 법인 판정 실측(MS049 코드명 414종):
  · 종전 `LIKE` 순서판정 vs **토큰 정확일치**(구분자 `_ ( ) +` 로 자른 토큰 = CM019 라벨) =
    토큰 0개 137 · 토큰 1개 277(사단 92 · 사복 95 · 통합 88 · 통합→사단 2) · 2개 이상 0
  · 🔴 ㉠ 추가 = `통합재후원감사문자_사단` · `통합후원감사문자_사단` 은 종전 판정이 **통합**(오분류) · 새 판정 = 사단
  · 접미만 보는 규칙은 `신규_사단_기타` · `신규_결연+사복` 등 27건을 놓친다 ⇒ 기각
- 역할 분담 = 코드 목록은 `macros/gn_biz_codes.sql` `gn_code`(O-HC·O232 기존 규약) · 라벨 매핑은 seed CSV

## E7. seed 권한 오류와 처방 (2026-10-22 · 사용자 보고)
- 1차 `dbt seed` = 003001 「Your primary role GN_DW_DBT must have CREATE TABLE granted on SCHEMA GN_DW.SILVER」 4건
- 실측 = GN_DW_DBT 스키마 권한: SILVER = USAGE 뿐 · GOLD = USAGE·CREATE VIEW · OPS·DBT_TEST__AUDIT = CREATE TABLE
- 설계 근거 = `07_ENVIRONMENT_RBAC_setup.sql:670-676` · `08_SILVER_테이블DDL:1681` · `37_DEPLOY_ORG_SUCCESSION.sql:44`
- 처방 = 권한 추가 없음 · ADMIN DDL 선생성(`38_DEPLOY_MAP_SEEDS.sql` [D1] · 개발계 SR61467 실행 rc=0 · 4 테이블 생성)
  · SHOW GRANTS = OWNERSHIP GN_DW_ADMIN · GN_DW_DBT DELETE·INSERT·SELECT·TRUNCATE(FUTURE GRANT 자동)

## E8. 사용자 build 후 라이브 대조 (개발계 SR61467 · 2026-10-22 · build PASS=721 WARN=23 ERROR=0 · 사용자 보고)
- seed 행수 = MAP_BUDGET_PROCEDURE 3 · MAP_SPONSORSHIP_GROUP4 7 · MAP_EXT_DATA_TYPE 6 · MAP_SERVICE_GROUP_RULE 11 (CSV 일치)
- DIM_SPONSORSHIP 4그룹 = 결연 1 · 국내 17 · 기타 24 · 해외프로젝트 8 · 그룹 있음+4그룹 NULL = 0
- FACT_BUDGET_YEARLY 차수 = 연사업 63 · 추가경정 105 · CRM_BIZ_TARGET TARGET_TYPE = 당초 5,244
- WIDE_MBRFEE = 예측/TRUE 528 · WIDE_DVLP 목표합 = 348,000.0000024370 (빌드 전 대조값과 동일)
- F = FACT_MESSAGE_DISPATCH SERVICE_MEMBERS=1 행 746,103 = 종전 라벨 판정(DIM_SEND_TYPE.SEND_TYPE_L='회원서비스') 746,103
- 커버리지 3종 직접 재현 = 미매핑 0
- E 오분류 2종 서비스코드의 발송요청 = 0건(개발계) ⇒ 현재 데이터 영향 0 · 규칙만 교정
- WIDE_MEMBER_SERVICE_COHORT 수신 행 = LONGTERM_THANKS 485,829 · PERSONAL_NEW_SADAN 258,731 · LUCKY_CARD 35,881 · SNG_INSTANT 4,204
