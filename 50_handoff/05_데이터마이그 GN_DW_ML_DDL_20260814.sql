-- GN_DW.ML 예측결과 테이블 DDL 스냅샷 (데이터 마이그레이션 A→B→로컬→C 용 스키마 정의)
-- Co-authored with CoCo
-- =====================================================================
-- 문서 목적 / PURPOSE
--   원본(A) 계정 GN_DW.ML 스키마 중 **Agent 노출 대상 예측결과 16종**의 구조 스냅샷이다.
--   최종 대상(C) 계정에 동일 구조를 재현하기 위한 "적재 전 테이블 생성" 스크립트로 사용한다.
--   04번(브론즈 53 테이블)과 같은 역할이며, 대상 스키마만 ML 이다.
--
-- 연계 문서 / RELATED DOCUMENTS
--   [작업 절차] 50_handoff/01_데이터마이그레이션 20260730.md
--              → 3.1(ML 공유 부여) / 5.1-B(ML DDL 실행) / 5.6(ML 적재·VARIANT 복원) 단계에서 본 파일을 사용.
--   [실행 SQL] 50_handoff/02_데이터마이그 A_PRODUCER.sql   (A: 공유 생성/ML 16종 SELECT 부여)
--              50_handoff/03_데이터마이그 B_BROKER.sql     (B: 공유 마운트/CSV 언로드)
--              50_handoff/05_데이터마이그 C_CONSUMER.sql   (C: 파일포맷/프로시저/적재/검증)
--   [브론즈]   50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL_20260730.sql  (BRONZE 4스키마 53테이블)
--
-- 원천 정의 문서 / SOURCE OF TRUTH
--   99_provided_definition/20_ML_ddl.sql  (3,217줄 · A 계정 GET_DDL('SCHEMA','GN_DW.ML',TRUE) 출력)
--     → 본 파일의 16개 CREATE TABLE 문은 위 파일에서 **무변경 발췌**했다(컬럼 순서·타입·COMMENT 포함).
--   05_SV-Agent_ai/20_ML_SV_설계.md §0-A  (16종 행수·grain 실측 · O74)
--
-- 🔴 이관 범위 결정 / SCOPE (사용자 확정 2026-08-14)
--   GN_DW.ML 의 BASE TABLE 은 49개지만 **데이터 이관 대상은 예측결과 16종만**이다.
--   제외 대상과 사유:
--     · ML_TRAIN_DATA_* 20종  — 학습용. 사용자 지시로 Agent 노출 금지 대상이며 이관하지 않는다.
--     · 원천 스냅샷 12종      — CMPGN_MBER_SNAPSHOT · MBER_MONTHLY_INFO · MBRFEE_PAY_DTLS 등
--                               학습·예측 입력. 이관 대상 아님.
--     · ML_PROCEDURE_LOG 1종  — 원천 계정의 프로시저 실행 로그.
--     · VIEW 4종              — ML_TRAIN_DATA_*_V. 학습 입력 뷰.
--     · PROCEDURE 14종        — SP_*_PREDICT / SP_*_FORECAST.
--     · SNOWFLAKE.ML 모델 14종 — 프로시저 **본문 안에서** CREATE 되므로 독립 DDL 이 아니다.
--                                학습 데이터 없이는 생성 자체가 불가하다.
--   ⇒ 🔴 **C 계정에서 재학습·재예측은 불가하다.** 예측 결과를 데이터로 받아 SERVING/SV 로 소비하는 것까지가 범위다.
--     모델 재실행이 필요하면 원천 계정(성현 프로 소관)에서 수행한 뒤 결과를 재이관한다.
--
-- 메타데이터 / METADATA
--   - Database / Schema : GN_DW / ML
--   - 테이블 수         : 16 (예측 FORECAST 계열 8 · 분류 CLASSIFICATION 계열 4 · 스코어 2 · 요인분석 2)
--   - VARIANT 보유      : 4 (PREDICTION 컬럼 — 전부 **마지막 컬럼**)
--   - 작성일자          : 2026-08-14 (초판)
--
-- 사용법 / USAGE (C 계정에서)
--   1) 04번 DDL(브론즈)과 독립적으로 실행할 수 있다. 선후 관계 없음.
--   2) 위에서 아래로 순서대로 실행 ([SCHEMA] → [TABLE] 16).
--   3) 생성 확인 (파일 하단 검증 쿼리 · 기대 16):
--        SELECT COUNT(*) FROM GN_DW.INFORMATION_SCHEMA.TABLES
--        WHERE table_schema='ML' AND table_type='BASE TABLE';
--   4) 이후 01번 문서 5.6(ML 적재) 절차로 데이터 적재.
--
-- 적재 시 주의 / LOAD NOTES
--   - CSV는 위치(순서) 기반 적재이며 MATCH_BY_COLUMN_NAME 미지원 → 본 파일의 컬럼 순서를 반드시 유지.
--   - 🔴 **PREDICTION VARIANT 4종은 일반 COPY 로 적재하면 JSON 이 문자열로 저장된다.**
--     GA4 events_* 와 동일한 함정이며, TRY_PARSE_JSON 변환 COPY 가 필수다(05번 A.5-B.2).
--     컬럼 위치(1-based · 전부 마지막 컬럼):
--       · ML_RST_DATA_SPNSR_CHURN_12M                    18컬럼 → $18
--       · ML_RST_DATA_MBER_CHURN_12M                     18컬럼 → $18
--       · ML_RST_DATA_MBER_INC_12M                       21컬럼 → $21
--       · ML_RST_DATA_LOYAL_MBER                         22컬럼 → $22
--     평탄화 결과(`PREDICTION:probability:"1"`·`PREDICTION:class`)를 SERVING 뷰가 쓰므로,
--     문자열로 적재되면 SV 층에서 조용히 NULL 이 된다.
--   - 스키마 옵션: A 계정 실측 DDL 은 `create or replace schema GN_DW.ML;`(옵션 없음)이다.
--     본 파일은 C 계정 관례(BRONZE 4스키마 = MANAGED ACCESS · 소유 GN_DW_ADMIN)에 맞췄다.
--     원천과 다른 유일한 지점이며, 테이블 구조는 무변경이다.
--
-- 객체 인덱스 / OBJECT INDEX  (요건 = 260814 기준 머신러닝 개발 내용)
--   [SCHEMA] GN_DW.ML — 머신러닝 예측 결과, 테이블 16개
--     회원실 1    ML_RST_DATA_SPNSR_CHURN_12M                    18컬럼  캠페인별 이탈 예측
--     회원실 2    ML_RST_DATA_MBER_CHURN_12M                     18컬럼  회원별 중단 예측
--     회원실 3    ML_RST_DATA_CMPGN_CTGR_AMT                      6컬럼  캠페인카테고리별 회비 예측
--     회원실 4    ML_RST_DATA_MBER_INC_12M                       21컬럼  회원 단위 증액 가능성 예측
--     회원실 5    ML_RST_DATA_LOYAL_MBER                         22컬럼  충성회원 가능성 예측
--     기획실 1    ML_RST_DATA_MONTHLY_DEPT_DVLP_AMT               6컬럼  부서별 연도말 개발 예측치
--     기획실 2    ML_RST_DATA_MONTHLY_SPNSR_BSNS_ID_DVLP_AMT      6컬럼  후원사업별 연도말 개발 예측치
--     기획실 3    ML_RST_DATA_MONTHLY_NEW_OLD_DVLP_AMT            6컬럼  신규/기존별 개발 건수 예측
--     나마본 1    ML_RST_DATA_MONTHLY_DVLP_AMT                    5컬럼  월별 신규 후원개발 금액 예측
--     나마본 2    ML_RST_DATA_UCMPGN_LTV                          6컬럼  채널 단위 월간 회원평균 후원 LTV 예측
--     나마본 2    ML_RST_DATA_UCMPGN_LTV_SCORE                    8컬럼  〃 스코어
--     나마본 3    ML_RST_DATA_CMPGN_LTV                           6컬럼  캠페인 단위 월간 후원 LTV 예측
--     나마본 3    ML_RST_DATA_CMPGN_LTV_SCORE                     8컬럼  〃 스코어
--     나마본 4    ML_RST_DATA_CHANNEL_NEW_SPNSR_DVLP_CONTRIBUTION  5컬럼  신규 후원 유치 요인 분석
--     나마본 5    ML_RST_DATA_MONTHLY_CMPGN_DVLP_AMT              6컬럼  캠페인별 월별 개발액 예측
--     나마본 6    ML_RST_DATA_DVLP_INC_CONTRIBUTION               5컬럼  증액 개발 요인 분석
-- =====================================================================


-- #####################################################################
-- # SCHEMA : GN_DW.ML  (머신러닝 예측 결과)
-- #####################################################################
-- 전제: 04번 DDL 또는 기존 환경에서 DB GN_DW 와 역할 GN_DW_ADMIN 이 이미 존재한다.
--       없으면 04번 DDL 상단(USE ROLE SYSADMIN → CREATE DATABASE → GRANT OWNERSHIP)을 먼저 실행한다.
USE ROLE GN_DW_ADMIN;

-- drop schema GN_DW.ML;
create or replace schema GN_DW.ML with managed access
  COMMENT='머신러닝 예측 결과 — 원천 계정 산출물 이관 대상. 학습·중간 테이블은 이관하지 않는다.';

-- ---------------------------------------------------------------------
-- [TABLE] 예측결과 16종  (20_ML_ddl.sql 무변경 발췌)
-- ---------------------------------------------------------------------

--  1/16 · 회원실 1 · 캠페인별 이탈 예측 (18컬럼 · VARIANT $18)
create or replace TABLE GN_DW.ML.ML_RST_DATA_SPNSR_CHURN_12M (
	STDR_MT VARCHAR(16777216) COMMENT '기준월 (YYYYMM)',
	MBER_NO VARCHAR(16777216) COMMENT '회원번호',
	SPNSR_BSNS_ID VARCHAR(16777216) COMMENT '후원사업ID',
	SPNSR_BSNS_NO VARCHAR(16777216) COMMENT '후원사업번호',
	CMPGN_CD VARCHAR(16777216) COMMENT '캠페인코드',
	STDR_MT_SPNSR_AMT NUMBER(38,0) COMMENT '기준월 후원금액',
	TENURE_MONTHS NUMBER(38,0) COMMENT '후원 유지기간 (월)',
	CHN_CNT NUMBER(38,0) COMMENT '변경 건수',
	INC_CNT NUMBER(38,0) COMMENT '증액 건수',
	DEC_CNT NUMBER(38,0) COMMENT '감액 건수',
	RE_CNT NUMBER(38,0) COMMENT '재후원 건수',
	CANCL_CNT NUMBER(38,0) COMMENT '해지 건수',
	INC_SPNSR_AMT NUMBER(38,0) COMMENT '증액 금액',
	DEC_SPNSR_AMT NUMBER(38,0) COMMENT '감액 금액',
	CANCL_SPNSR_AMT NUMBER(38,0) COMMENT '해지 금액',
	PAY_RATE FLOAT COMMENT '납입 성공률',
	SETLE_CD VARCHAR(16777216) COMMENT '결제수단코드',
	PREDICTION VARIANT COMMENT '예측 결과 (VARIANT: probability, class 포함)'
)COMMENT='후원건(SPNSR_BSNS_ID) 단위 향후 12개월 내 중단확률 예측 결과'
;

--  2/16 · 회원실 2 · 회원별 중단 예측 (18컬럼 · VARIANT $18)
create or replace TABLE GN_DW.ML.ML_RST_DATA_MBER_CHURN_12M (
	STDR_MT VARCHAR(16777216) COMMENT '기준월 (YYYYMM)',
	MBER_NO VARCHAR(16777216) COMMENT '회원번호',
	MBER_STAT_CD VARCHAR(16777216) COMMENT '회원 상태코드',
	MONTHS_SINCE_JOIN NUMBER(38,0) COMMENT '가입 후 경과 월수',
	ACTIVE_SPNSR_CNT NUMBER(38,0) COMMENT '활성 후원건 수',
	TOTAL_SPNSR_AMT NUMBER(38,0) COMMENT '총 후원금액',
	TOTAL_INC_CNT NUMBER(38,0) COMMENT '총 증액 건수',
	TOTAL_DEC_CNT NUMBER(38,0) COMMENT '총 감액 건수',
	TOTAL_CANCL_CNT NUMBER(38,0) COMMENT '총 해지 건수',
	TOTAL_INC_AMT NUMBER(38,0) COMMENT '총 증액 금액',
	TOTAL_DEC_AMT NUMBER(38,0) COMMENT '총 감액 금액',
	TOTAL_CANCL_AMT NUMBER(38,0) COMMENT '총 해지 금액',
	DNST_RT FLOAT COMMENT '중단율 (금액 기준)',
	PAY_RATE FLOAT COMMENT '납입 성공률',
	PAY_REQ_CNT NUMBER(38,0) COMMENT '납입 요청 건수',
	SETLE_CD VARCHAR(16777216) COMMENT '결제수단코드',
	CPR_DIV_CD VARCHAR(16777216) COMMENT '법인/개인 구분코드',
	PREDICTION VARIANT COMMENT '예측 결과 (VARIANT: probability, class 포함)'
)COMMENT='회원(MBER_NO) 단위 향후 6개월 내 중단확률 예측 결과'
;

--  3/16 · 회원실 3 · 캠페인카테고리별 회비 예측 (6컬럼)
create or replace TABLE GN_DW.ML.ML_RST_DATA_CMPGN_CTGR_AMT (
	STDR_MT VARCHAR(16777216) COMMENT '예측 실행 기준월 (YYYYMM)',
	SERIES VARCHAR(16777216) COMMENT '캠페인카테고리코드 (CMPGN_CTGR_CD)',
	TS TIMESTAMP_NTZ(9) COMMENT '예측 기준일 (월 시작일)',
	FORECAST FLOAT COMMENT '예측 회비금액',
	LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
	UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
)COMMENT='캠페인카테고리별 향후 12개월 월간 회비(후원금액) 예측 결과'
;

--  4/16 · 회원실 4 · 회원 단위 증액 가능성 예측 (21컬럼 · VARIANT $21)
create or replace TABLE GN_DW.ML.ML_RST_DATA_MBER_INC_12M (
	STDR_MT VARCHAR(16777216) COMMENT '기준월 (YYYYMM)',
	MBER_NO VARCHAR(16777216) COMMENT '회원번호',
	MBER_STAT_CD VARCHAR(16777216) COMMENT '회원 상태코드',
	MONTHS_SINCE_JOIN NUMBER(38,0) COMMENT '가입 후 경과 월수',
	ACTIVE_SPNSR_CNT NUMBER(38,0) COMMENT '활성 후원건 수',
	TOTAL_SPNSR_AMT NUMBER(38,0) COMMENT '총 후원금액',
	TOTAL_NEW_CNT NUMBER(38,0) COMMENT '총 신규 건수',
	TOTAL_INC_CNT NUMBER(38,0) COMMENT '총 증액 건수',
	TOTAL_DEC_CNT NUMBER(38,0) COMMENT '총 감액 건수',
	TOTAL_RE_CNT NUMBER(38,0) COMMENT '총 재후원 건수',
	TOTAL_CANCL_CNT NUMBER(38,0) COMMENT '총 해지 건수',
	TOTAL_INC_AMT NUMBER(38,0) COMMENT '총 증액 금액',
	TOTAL_DEC_AMT NUMBER(38,0) COMMENT '총 감액 금액',
	TOTAL_CANCL_AMT NUMBER(38,0) COMMENT '총 해지 금액',
	DNST_RT FLOAT COMMENT '중단율 (금액 기준)',
	PAY_RATE FLOAT COMMENT '납입 성공률',
	PAY_REQ_CNT NUMBER(38,0) COMMENT '납입 요청 건수',
	TOTAL_PAY_AMT NUMBER(38,0) COMMENT '총 납입 금액',
	SETLE_CD VARCHAR(16777216) COMMENT '결제수단코드',
	CPR_DIV_CD VARCHAR(16777216) COMMENT '법인/개인 구분코드',
	PREDICTION VARIANT COMMENT '예측 결과 (VARIANT: probability, class 포함)'
)COMMENT='회원(MBER_NO) 단위 향후 12개월 내 증액 가능성 예측 결과'
;

--  5/16 · 회원실 5 · 충성회원 가능성 예측 (22컬럼 · VARIANT $22)
create or replace TABLE GN_DW.ML.ML_RST_DATA_LOYAL_MBER (
	STDR_MT VARCHAR(16777216) COMMENT '기준월 (YYYYMM)',
	MBER_NO VARCHAR(16777216) COMMENT '회원번호',
	CURRENT_TENURE NUMBER(38,0) COMMENT '현재 가입 경과 월수',
	ACTIVE_MONTHS_24 NUMBER(38,0) COMMENT '초기 24개월 중 활성 월수',
	SPNSR_CNT_24 NUMBER(38,0) COMMENT '초기 24개월 후원건 수',
	TOTAL_AMT_24 NUMBER(38,0) COMMENT '초기 24개월 총 후원금액',
	AVG_AMT_24 FLOAT COMMENT '초기 24개월 평균 후원금액',
	INC_CNT_24 NUMBER(38,0) COMMENT '초기 24개월 증액 건수',
	DEC_CNT_24 NUMBER(38,0) COMMENT '초기 24개월 감액 건수',
	CANCL_CNT_24 NUMBER(38,0) COMMENT '초기 24개월 해지 건수',
	RE_CNT_24 NUMBER(38,0) COMMENT '초기 24개월 재후원 건수',
	INC_AMT_24 NUMBER(38,0) COMMENT '초기 24개월 증액 금액',
	DEC_AMT_24 NUMBER(38,0) COMMENT '초기 24개월 감액 금액',
	CANCL_AMT_24 NUMBER(38,0) COMMENT '초기 24개월 해지 금액',
	DNST_RT_24 FLOAT COMMENT '초기 24개월 중단율 (금액 기준)',
	AMT_STDDEV_24 FLOAT COMMENT '초기 24개월 후원금액 표준편차',
	PAY_RATE_24 FLOAT COMMENT '초기 24개월 납입 성공률',
	PAY_REQ_CNT_24 NUMBER(38,0) COMMENT '초기 24개월 납입 요청 건수',
	TOTAL_PAY_AMT_24 NUMBER(38,0) COMMENT '초기 24개월 총 납입 금액',
	SETLE_CD VARCHAR(16777216) COMMENT '결제수단코드',
	CPR_DIV_CD VARCHAR(16777216) COMMENT '법인/개인 구분코드',
	PREDICTION VARIANT COMMENT '예측 결과 (VARIANT: probability, class 포함)'
)COMMENT='회원(MBER_NO) 단위 충성회원 성장 가능성 예측 결과'
;

--  6/16 · 기획실 1 · 부서별 연도말 개발 예측치 (6컬럼)
create or replace TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_DEPT_DVLP_AMT (
	STDR_MT VARCHAR(16777216) COMMENT '예측 실행 기준월 (YYYYMM)',
	SERIES VARCHAR(16777216) COMMENT '부서코드 (ACMSLT_DEPT_CD)',
	TS TIMESTAMP_NTZ(9) COMMENT '예측 기준일 (월 시작일)',
	FORECAST FLOAT COMMENT '예측 개발금액 (만원 단위, 신규+증액+재후원)',
	LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
	UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
)COMMENT='부서(ACMSLT_DEPT_CD)별 월간 후원개발 금액(만원) 향후 12개월 예측 결과'
;

--  7/16 · 기획실 2 · 후원사업별 연도말 개발 예측치 (6컬럼)
create or replace TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_SPNSR_BSNS_ID_DVLP_AMT (
	STDR_MT VARCHAR(16777216) COMMENT '예측 실행 기준월 (YYYYMM)',
	SERIES VARCHAR(16777216) COMMENT '후원사업ID (SPNSR_BSNS_ID)',
	TS TIMESTAMP_NTZ(9) COMMENT '예측 기준일 (월 시작일)',
	FORECAST FLOAT COMMENT '예측 개발금액 (만원 단위, 신규+증액+재후원)',
	LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
	UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
)COMMENT='후원사업(SPNSR_BSNS_ID)별 월간 후원개발 금액(만원) 향후 12개월 예측 결과'
;

--  8/16 · 기획실 3 · 신규/기존별 개발 건수 예측 (6컬럼)
create or replace TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_NEW_OLD_DVLP_AMT (
	STDR_MT VARCHAR(16777216) COMMENT '예측 실행 기준월 (YYYYMM)',
	SERIES VARCHAR(16777216) COMMENT '개발 유형 (NEW=신규, OLD=기존 증액+재후원)',
	TS TIMESTAMP_NTZ(9) COMMENT '예측 기준일 (월 시작일)',
	FORECAST FLOAT COMMENT '예측 개발금액 (만원 단위)',
	LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
	UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
)COMMENT='신규/기존별 월간 후원개발 금액(만원) 향후 12개월 예측 결과'
;

--  9/16 · 나마본 1 · 월별 신규 후원개발 금액 예측 (5컬럼)
create or replace TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_DVLP_AMT (
	STDR_MT VARCHAR(16777216) COMMENT '예측 실행 기준월 (YYYYMM)',
	TS TIMESTAMP_NTZ(9) COMMENT '예측 기준일 (월 시작일)',
	FORECAST FLOAT COMMENT '예측 개발금액 (만원 단위, 신규+증액+재후원)',
	LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
	UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
)COMMENT='월별 전체 신규 후원개발 금액(만원) 향후 12개월 예측 결과'
;

-- 10/16 · 나마본 2 · 채널 단위 월간 회원평균 후원 LTV 예측 (6컬럼)
create or replace TABLE GN_DW.ML.ML_RST_DATA_UCMPGN_LTV (
	STDR_MT VARCHAR(16777216) COMMENT '예측 실행 기준월 (YYYYMM)',
	SERIES VARCHAR(16777216) COMMENT '상위캠페인코드 (UPPER_CMPGN_CD)',
	TS TIMESTAMP_NTZ(9) COMMENT '예측 기준일 (월 시작일)',
	FORECAST FLOAT COMMENT '예측 회원평균 후원금액',
	LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
	UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
)COMMENT='상위캠페인(UPPER_CMPGN_CD)별 회원평균 후원금액 향후 12개월 예측 결과'
;

-- 11/16 · 나마본 2 · 〃 스코어 (8컬럼)
create or replace TABLE GN_DW.ML.ML_RST_DATA_UCMPGN_LTV_SCORE (
	STDR_MT VARCHAR(16777216) COMMENT '예측 실행 기준월 (YYYYMM)',
	UPPER_CMPGN_CD VARCHAR(16777216) COMMENT '상위캠페인코드',
	HIST_TOTAL_AMT FLOAT COMMENT '과거 누적 회원평균 금액 합계 (학습 기간 전체)',
	FUTURE_TOTAL_AMT FLOAT COMMENT '향후 12개월 예측 금액 합계',
	LTV FLOAT COMMENT '장기가치 (과거 누적 + 향후 예측)',
	AVG_MONTHLY_FORECAST FLOAT COMMENT '향후 월평균 예측 금액',
	ACTIVE_MONTHS NUMBER(38,0) COMMENT '과거 활성 월수',
	AVG_MONTHLY_ACTUAL FLOAT COMMENT '과거 월평균 실제 금액'
)COMMENT='상위캠페인(UPPER_CMPGN_CD)별 LTV(장기가치) 산출 결과 (과거 누적 + 향후 예측)'
;

-- 12/16 · 나마본 3 · 캠페인 단위 월간 후원 LTV 예측 (6컬럼)
create or replace TABLE GN_DW.ML.ML_RST_DATA_CMPGN_LTV (
	STDR_MT VARCHAR(16777216) COMMENT '예측 실행 기준월 (YYYYMM)',
	SERIES VARCHAR(16777216) COMMENT '캠페인코드 (CMPGN_CD)',
	TS TIMESTAMP_NTZ(9) COMMENT '예측 기준일 (월 시작일)',
	FORECAST FLOAT COMMENT '예측 월간 후원금액',
	LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
	UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
)COMMENT='캠페인(CMPGN_CD)별 월간 후원금액 향후 12개월 예측 결과'
;

-- 13/16 · 나마본 3 · 〃 스코어 (8컬럼)
create or replace TABLE GN_DW.ML.ML_RST_DATA_CMPGN_LTV_SCORE (
	STDR_MT VARCHAR(16777216) COMMENT '예측 실행 기준월 (YYYYMM)',
	CMPGN_CD VARCHAR(16777216) COMMENT '캠페인코드',
	HIST_TOTAL_AMT FLOAT COMMENT '과거 누적 후원금액 합계 (학습 기간 전체)',
	FUTURE_TOTAL_AMT FLOAT COMMENT '향후 12개월 예측 금액 합계',
	LTV FLOAT COMMENT '장기가치 (과거 누적 + 향후 예측)',
	AVG_MONTHLY_FORECAST FLOAT COMMENT '향후 월평균 예측 금액',
	ACTIVE_MONTHS NUMBER(38,0) COMMENT '과거 활성 월수',
	AVG_MONTHLY_ACTUAL FLOAT COMMENT '과거 월평균 실제 금액'
)COMMENT='캠페인(CMPGN_CD)별 LTV(장기가치) 산출 결과 (과거 누적 + 향후 예측)'
;

-- 14/16 · 나마본 4 · 신규 후원 유치 요인 분석 (5컬럼)
create or replace TABLE GN_DW.ML.ML_RST_DATA_CHANNEL_NEW_SPNSR_DVLP_CONTRIBUTION (
	STDR_MT VARCHAR(16777216) COMMENT '분석 실행 기준월 (YYYYMM)',
	RANK NUMBER(38,0) COMMENT '피처 중요도 순위',
	FEATURE VARCHAR(16777216) COMMENT '피처명',
	SCORE FLOAT COMMENT '피처 중요도 점수 (0~1, 합계=1)',
	FEATURE_TYPE VARCHAR(16777216) COMMENT '피처 유형 (user_provided)'
)COMMENT='신규 후원 유치 상위 채널 결정 요인 (피처 중요도) 분석 결과'
;

-- 15/16 · 나마본 5 · 캠페인별 월별 개발액 예측 (6컬럼)
create or replace TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_CMPGN_DVLP_AMT (
	STDR_MT VARCHAR(16777216) COMMENT '예측 실행 기준월 (YYYYMM)',
	SERIES VARCHAR(16777216) COMMENT '캠페인코드 (CMPGN_CD)',
	TS TIMESTAMP_NTZ(9) COMMENT '예측 기준일 (월 시작일)',
	FORECAST FLOAT COMMENT '예측 개발금액 (만원 단위, 신규+증액+재후원)',
	LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
	UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
)COMMENT='캠페인(CMPGN_CD)별 월간 후원개발 금액(만원) 향후 12개월 예측 결과'
;

-- 16/16 · 나마본 6 · 증액 개발 요인 분석 (5컬럼)
create or replace TABLE GN_DW.ML.ML_RST_DATA_DVLP_INC_CONTRIBUTION (
	STDR_MT VARCHAR(16777216) COMMENT '분석 실행 기준월 (YYYYMM)',
	RANK NUMBER(38,0) COMMENT '피처 중요도 순위',
	FEATURE VARCHAR(16777216) COMMENT '피처명',
	SCORE FLOAT COMMENT '피처 중요도 점수 (0~1, 합계=1)',
	FEATURE_TYPE VARCHAR(16777216) COMMENT '피처 유형 (user_provided)'
)COMMENT='후원개발 20% 증가를 위한 우선 개선 요인 (피처 중요도) 분석 결과'
;


-- #####################################################################
-- # 생성 확인 / VERIFY
-- #####################################################################
-- (1) 테이블 수 — 기대 16
SELECT COUNT(*) AS n_tables
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'ML' AND table_type = 'BASE TABLE';

-- (2) 테이블별 컬럼 수 — 위 객체 인덱스와 대조
SELECT table_name, COUNT(*) AS n_cols
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'ML'
GROUP BY 1 ORDER BY 1;

-- (3) VARIANT 컬럼 위치 확인 — 기대 4행, 전부 ordinal_position = 해당 테이블 컬럼 수
SELECT table_name, column_name, ordinal_position, data_type
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'ML' AND data_type = 'VARIANT'
ORDER BY 1;

-- (4) 적재 전이므로 전 테이블 0행이 정상이다. 적재 후에는 05번 A.5-B.4 로 검증한다.
