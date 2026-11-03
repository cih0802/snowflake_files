<!-- LLM-METADATA
doc_id: O193B_EVIDENCE
doc_role: O193-B 라이브 실측 근거(판정보다 먼저 기록 · R1-3-7-c)
project: GN_DW (굿네이버스)
created: 2026-10-01
created_by: O193-B
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

# O193-B 실측 근거 — 계정 pw69582 · 2026-09-30 19:25 PDT(= 10-01 KST) · 데이터 입고 후

> 🔴 이 파일의 수치는 **이 계정·이 시각** 실측이다. 다른 계정의 기준선이 아니다(`R2-8-4`).

## E1. 0단계 착수 판정 (O192-A ▣2)

- 0-1 = `PW69582 · AWS_EU_WEST_1 · ACCOUNTADMIN`
- 0-2 BRONZE·계층 테이블/행(INFORMATION_SCHEMA.TABLES · BASE TABLE):

| 스키마 | 테이블 | 행 | 0행 테이블 |
|---|---|---|---|
| BRONZE_AGENCY | 4 | 271,218 | 0 |
| BRONZE_CRM | 53 | 122,485,444 | 0 |
| BRONZE_ERP | 2 | 62,043 | 0 |
| BRONZE_GA4 | 2 | 45,841 | 1 (`SYNC_ERR_INFO`) |
| BRONZE_GSC | 3 | 1,911,077 | 1 (`SYNC_ERR_INFO`) |
| SILVER | 58 | 151,223,698 | 1 (`AGENCY_AD_BROADCAST_CASE`) |
| GOLD | 46 | 153,389,010 | 1 (`FACT_AD_BROADCAST_CASE`) |
| ML | 17 | 1,093,258 | 0 |

- 0-3 🔴 **O192-A 「운영계 삭제 3종」이 이 계정에는 실재한다** — 기록만(▣0 · D-3 규칙 · 주석 유지):
  `ML_RST_DATA_MONTHLY_DEPT_DVLP_AMT` 360 · `ML_RST_DATA_MONTHLY_SPNSR_BSNS_ID_DVLP_AMT` 228 · `ML_RST_DATA_MONTHLY_NEW_OLD_DVLP_AMT` 24.
- 라이브 객체: SV 19 · Agent 3(AGENT_MEMBER default `VERSION$3` = O193 스펙 토큰 `[2026-10-01 O193]` 포함).
- `ML_DVLP_FORECAST_V` SERIES_TYPE = `CAMPAIGN` 1,200 · `TOTAL` 12 ⇒ **2행**(통과).

## E2. ① 판정

- `FACT_EVENT_ATTENDANCE.SELF_PART_FLAG` = TRUE 162,441 · FALSE 387 · NULL 1,085,899 (종전 전건 NULL ⇒ 해소).
- `DIM_ORG.ACMSLT_DIV_*` 4컬럼 실재(GROUP_ID · GROUP_NM · ID · NM).
- GOLD 2차-B 전파 38컬럼(명세 = `scripts/_scratch_o191g_gold.py` SPEC): **실재 38/38 · 0건 컬럼 0**.
  행 = DIM_EVENT 3,937 · DIM_CAMPAIGN 36,769 · DIM_MEMBER 1,785,299 · DIM_SPONSORSHIP 51 · FEA 1,248,727 · FMD 41,935,344.
- 🔴 SILVER 99컬럼 태그 판정식(`_scratch_o191g_fill.py` · COMMENT `O191-E/F 2차-B`)은 **0건** —
  O192-B 가 COMMENT 세션 태그를 제거했기 때문이다(판정식 소멸 · J1). ⇒ GOLD 38 명세로 대체 판정.
- ①-b ML 권한(DEC-57) = `GN_DW_ANALYST` 에 ML USAGE + 17테이블 SELECT 부여 실재.

## E3. 라이브 게이트 (rc 는 파일 리다이렉트로 수집)

| 게이트 | rc | 결론 |
|---|---|---|
| table_ddl_column_gate | 0 | 집합 불일치 0 · 순서 드리프트(advisory) 2 / 103 |
| gold_erd_coverage_gate | 0 | 미분류 고립 0 (분류 28 · ERD 표기 15) |
| sv_unit_gate | 0 | 위반 0 · 예외 3 |
| sv_code_label_gate | 0 | blocking 0 · advisory(열거누락) 16 |
| agent_object_ref_gate | 0 | blocking 0 |
| agent_source_lineage_gate | 0 | blocking 0 |
| comment_drift_gate | 0 | GOLD 994/994 · SILVER 1319 · 뷰 583 위반 0 |
| sv_identifier_gate | 0 | blocking 0 |
| agent_tool_claim_gate | 0 | 모순 0 · 규칙7 0 |

## E4. SV 반영 대기분 값 실측 (O191-G 잔여 2 · COMMENT 열거 근거)

FEA (EVENT_KIND_NAME × SELF_PARTCPT_CD × SELF_PART_FLAG · 행 · ACMPNY_PARTCPT_CO 채움):

| 행사종류 | SELF_CD | FLAG | 행 | 동반수 채움 |
|---|---|---|---|---|
| 일반행사 | NULL | NULL | 1,085,872 | 0 |
| 캠페인행사 | 0 | false | 387 | 387 |
| 캠페인행사 | 1 | true | 34,835 | 30,071 |
| 캠페인행사 | 2 | true | 127,606 | 127,606 |
| 캠페인행사 | NULL | NULL | 27 | 9 |

DIM_EVENT.CRMN_PLACE_NM 채움 = 일반행사 0/383 · 캠페인행사 413/3,553 · (미매핑) 0/1.

FMD (SEND_TYPE × ALTRTV_MSG_SNDNG_YN × RESPONSED_YN):

| 발송유형 | 대체문자 | 확인여부 | 행 |
|---|---|---|---|
| EMAIL | NULL | NULL | 7,823,562 |
| MSG_AT | NULL | NULL | 21,082,065 |
| MSG_AT | Y | NULL | 876,141 |
| PSTMTR | NULL | NULL | 1,969,939 |
| SND | NULL | N | 275,413 |
| SND | NULL | NULL | 1,103 |
| SND | NULL | Y | 9,907,121 |

DIM_MEMBER.CHRCTR_RECPTN_YN = Y 1,536,784 · N 186,228 · NULL 62,287.

⇒ 코드값 집합(열거용): 본인참여코드 {0,1,2} · 대체문자 {Y} · 확인여부 {Y,N} · 문자수신 {Y,N}.
⇒ 구조: 본인참여·동반수 = **캠페인행사 전용**(일반행사 전건 NULL) · 대체문자 = **MSG_AT 전용** · 확인여부 = **SND 전용**.

라이브 GOLD COMMENT(INFORMATION_SCHEMA.COLUMNS 원문):
- `CRMN_PLACE_NM` = 「행사장소명 [SILVER.CRM_EVENT 승계 · 원천 BRONZE_CRM.TM_MS_CRMN]」
- `CHRCTR_RECPTN_YN` = 「문자수신여부 [SILVER.CRM_MEMBER 승계 · 원천 BRONZE_CRM.TM_MM_FDRM_MBER_INFO · BRONZE_CRM.TM_MM_ONCE_MBER_INFO]」
- `ACMPNY_PARTCPT_CO` = 「동반참여수 [SILVER.CRM_EVENT_PARTICIPATION 승계 · 원천 BRONZE_CRM.TD_MS_CRMN_PRTCPNT]」
- `SELF_PARTCPT_CD` = 「자기참여코드 [SILVER.CRM_EVENT_PARTICIPATION 승계 · 원천 BRONZE_CRM.TD_MS_CRMN_PRTCPNT]」
- `SELF_PART_FLAG` = 「본인참여. [사유:규칙 미확정]」 ← 🔴 stale(아래 E5)
- `ALTRTV_MSG_SNDNG_YN` = 「대체문자 발송 여부 [SILVER.CRM_SEND_MEMBER 승계 · 원천 BRONZE_CRM.TD_MS_MSG_AT_SNDNG_DTLS]」
- `RESPONSED_YN` = 「발송확인여부 [SILVER.CRM_SEND_MEMBER 승계 · 원천 BRONZE_CRM.SND_MEMBER_LIST]」

코드사전 `SILVER.CRM_CODE` CD_ID='MS060'(전건 USE_YN=Y): `0`=동반자만 · `1`=본인만 · `2`=함께.

## E5. 신규 발견 — SELF_PART_FLAG COMMENT stale 2곳

- 규칙 실재 = `10_dbt_pipeline/models/gold/fact/FACT_EVENT_ATTENDANCE.sql:67`
  「`CASE p.SELF_PARTCPT_CD WHEN '1' THEN TRUE WHEN '2' THEN TRUE WHEN '0' THEN FALSE END as SELF_PART_FLAG`」
- stale ① `03_top-down_gold/06_DDL.sql:929` 「`SELF_PART_FLAG      BOOLEAN         COMMENT '본인참여. [사유:규칙 미확정]',`」
- stale ② `10_dbt_pipeline/models/gold/wide/_wide_schema.yml:910` 「본인참여여부 🔴🔴[O51-D 실측] **전건 NULL** …」
- `comment_drift_gate` 가 PASS 인 이유 = 파일과 라이브가 **같이 낡았다**(드리프트가 아니라 내용 오류 · J2).

_Co-authored with CoCo_
