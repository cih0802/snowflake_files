-- GN_DW.ML 예측결과 테이블 DDL 스냅샷 (데이터 마이그레이션 A→B→로컬→C 용 스키마 정의)
-- Co-authored with CoCo
-- =====================================================================
-- 문서 목적 / PURPOSE
--   원본(A) 계정 GN_DW.ML 스키마 중 **Agent 노출 대상 예측결과 12종**의 구조 스냅샷이다(🆕 2026-10-02 O198 · 17→12).
--   최종 대상(C) 계정에 동일 구조를 재현하기 위한 "적재 전 테이블 생성" 스크립트로 사용한다.
--   04번(브론즈 64 테이블)과 같은 역할이며, 대상 스키마만 ML 이다.
--
-- 연계 문서 / RELATED DOCUMENTS
--   [작업 절차] 50_handoff/01_데이터마이그레이션 20260730.md
--              → 3.1(ML 공유 부여) / 5.1-B(ML DDL 실행) / 5.6(ML 적재·VARIANT 복원) 단계에서 본 파일을 사용.
--   [실행 SQL] 50_handoff/02_데이터마이그 A_PRODUCER.sql   (A: 공유 생성/ML 12종 SELECT 부여 · 제외 4종 REVOKE)
--              50_handoff/03_데이터마이그 B_BROKER.sql     (B: 공유 마운트/CSV 언로드)
--              50_handoff/07_데이터마이그 C_CONSUMER.sql   (C: 파일포맷/프로시저/적재/검증)
--   [브론즈]   50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL.sql  (BRONZE 5스키마 64테이블)
--   [실버]     50_handoff/06_데이터마이그 GN_DW_SILVER_DDL.sql  (SILVER 1테이블 118컬럼)
--              ⚠️ 세 파일을 모두 실행해야 이관 대상 77 테이블이 완성된다(🆕 O198 · 82→77). 선후 관계는 없다.
--              🟢 [2026-09-15] 04·06번 파일명에서 날짜를 뗐다(구 = *_20260730 / *_20260820).
--                 갱신마다 개명하면 참조 문서를 매번 고쳐야 하므로 날짜는 파일 안에만 적는다.
--
-- 원천 정의 문서 / SOURCE OF TRUTH
--   99_provided_definition/20_ML_ddl.sql  (A 계정 GET_DDL('SCHEMA','GN_DW.ML',TRUE) 출력)
--     → 본 파일의 CREATE TABLE 12개 중 **10개**는 위 파일에서 **무변경 발췌**했다(컬럼 순서·타입·COMMENT 포함).
--       🔴 [O198] 신규 2종(MKTG_CHANNEL_MBER_AVG_LTV · CMPGN_SPNSR_AMT_LTV)은 위 파일에 없어 **추정 구조**다 ⇒ 02번 6.3 으로 확정.
--     🔴 줄 수는 여기 적지 않는다 — 적으면 다음 판에서 stale 이 된다.
--        재려면 `wc -l 99_provided_definition/20_ML_ddl.sql` 를 실행한다.
--        (종전 기재 「3,217줄」은 2026-08-29 실측과 어긋났다.)
--   05_SV-Agent_ai/20_ML_SV_설계.md §0-A  (16종 행수·grain 실측 · O74 · ONCE_CONVERSION 미반영)  (🔴 2026-09-28 현행 = 브론즈 64 · CRM 53 · ML 17 · 총계 82)
--
-- 🔴 이관 범위 결정 / SCOPE (사용자 확정 2026-08-14)
--   GN_DW.ML 의 BASE TABLE 은 52개지만 **데이터 이관 대상은 예측결과 12종만**이다(🆕 2026-10-02 O198 사용자 확정 · 종전 17종).
--   제외 대상과 사유:
--     · ML_TRAIN_DATA_* 21종  — 학습용. 사용자 지시로 Agent 노출 금지 대상이며 이관하지 않는다.
--     · 원천 스냅샷 12종      — CMPGN_MBER_SNAPSHOT · MBER_MONTHLY_INFO · MBRFEE_PAY_DTLS 등
--                               학습·예측 입력. 이관 대상 아님.
--     · ML_PROCEDURE_LOG 1종  — 원천 계정의 프로시저 실행 로그.
--     · VIEW 5종              — ML_TRAIN_DATA_*_V · V_TRAIN_ONCE_CONVERSION. 학습 입력 뷰.
--     · PROCEDURE 14종        — SP_*_PREDICT / SP_*_FORECAST.
--     · SNOWFLAKE.ML 모델 14종 — 프로시저 **본문 안에서** CREATE 되므로 독립 DDL 이 아니다.
--                                학습 데이터 없이는 생성 자체가 불가하다.
--   ⇒ 🔴 **C 계정에서 재학습·재예측은 불가하다.** 예측 결과를 데이터로 받아 SERVING/SV 로 소비하는 것까지가 범위다.
--     모델 재실행이 필요하면 원천 계정(성현 프로 소관)에서 수행한 뒤 결과를 재이관한다.
--
-- 메타데이터 / METADATA
--   - Database / Schema : GN_DW / ML
--   - 테이블 수         : 12 (예측 FORECAST 계열 5 · 분류 CLASSIFICATION 계열 5 · 요인분석 2 · 🆕 O198 — 신규 LTV 2종은 추정상 FORECAST 계열)
--   - VARIANT 보유      : 5 (PREDICTION 4 + PREDICT 1 — 전부 **마지막 컬럼**)
--   - 작성일자          : 2026-08-14 (초판)
--   - 갱신일자          : 2026-10-02 (O198 · 이관 범위 17→12 · 신규 LTV 2종 추정 구조)
--
-- 변경 이력 / CHANGES
--   2026-10-02  🆕 O198 · 사용자 지시 — 이관 범위 **17 → 12종**.
--     + [TABLE] ML_RST_DATA_MKTG_CHANNEL_MBER_AVG_LTV · ML_RST_DATA_CMPGN_SPNSR_AMT_LTV (🔴 원천 정의 부재 · 추정 구조 · 02번 6.3 으로 교체)
--     − [TABLE] ML_RST_DATA_UCMPGN_LTV · UCMPGN_LTV_SCORE · CMPGN_LTV · CMPGN_LTV_SCORE (블록 삭제 · 02번 2-C 에서 share REVOKE)
--     · 기획실 3종은 종전대로 주석(O195 DROP) — 개수에서 제외.
--     · VARIANT 대상 5종은 변경 없음.
--   2026-09-29  원천 정의 문서 20_ML_ddl.sql 재갱신분 반영 — 기계 대조(`scripts/handoff_ddl_gate.py` 6축).
--     ~ [TABLE] GN_DW.ML.ML_RST_DATA_ONCE_CONVERSION — 컬럼 COMMENT 4 · 테이블 COMMENT 1 을 원천 문안으로 교체
--        · 🔴 타입 3 도 원천을 따랐다(ONCE_MBER_NO·CONVERSION_YN·DATA_TYPE → VARCHAR) — 종전 판은 원천과 달랐다.
--          ⚠️ 라이브(xf98254)는 아직 VARCHAR(10)·NUMBER(1,0)·VARCHAR(5) 다 ⇒ 재생성 시 하류(SERVING ML 뷰)의 CAST 확인 필요.
--     · 원천에 COMMENT 가 새로 붙은 **이관 범위 밖** 테이블(ML_TRAIN_DATA 등 35종)은 본 파일 대상이 아니다.
--     · ONCE_CONVERSION 외 테이블은 6축 차이 0건(원천 COMMENT 와 본 파일 문안 이미 일치).
--   2026-09-28  원천 정의 문서 20_ML_ddl.sql 갱신분 반영 — 예측결과 **16 → 17종**.
--     + [TABLE] GN_DW.ML.ML_RST_DATA_ONCE_CONVERSION (5컬럼 · 나마본 7 · 일시후원 → 정기후원 전환 예측)
--        · 🔴 VARIANT 컬럼명이 **PREDICT** 다(기존 4종은 PREDICTION). 위치 = 마지막($5).
--          ⇒ 07번 A.5-B.2 의 VARIANT 대상 목록·SERVING 뷰 평탄화 식에 이 테이블을 **추가**해야 한다.
--        · ~~원천에 컬럼·테이블 COMMENT 가 없어 보강했다(현업 확인 대상). 구조(순서·타입)는 무변경.~~ ➔ 2026-09-29 원천 문안으로 교체
--        · 스테이지 ML/ML_RST_DATA_ONCE_CONVERSION/ = 8 파일, CSV 헤더가 본 DDL 과 일치(2026-09-28 실측).
--     · 원천 인벤토리 = BASE TABLE 52 (ML_RST_DATA 17 + ML_TRAIN_DATA 21 + 기타 14) · VIEW 5 · PROCEDURE 14.
--     · 기존 16종은 구조 변경 0건(게이트 6축). 총 이관 대상 78 → **82**(브론즈 61 → 64 · 04번 참조).  (🔴 2026-09-28 현행 = 브론즈 64 · CRM 53 · ML 17 · 총계 82)
--   2026-08-29  원천 정의 문서 20_ML_ddl.sql 과 기계 대조 — **구조 변경 0건**.
--     · 판정 근거 = python3 scripts/handoff_ddl_gate.py (ML_RST_DATA 대상 · 6축 전건 0건)
--       6축 = 테이블집합 · 컬럼이름·순서 · 타입 · DEFAULT · 컬럼COMMENT · 테이블COMMENT.
--       🔴 초판 판정은 **컬럼 COMMENT 와 DEFAULT 를 보지 않는 임시 도구**로 냈다(축 2개 누락).
--          축을 6개로 늘려 재판정한 뒤에도 0건이었다 ⇒ 판정은 유지되고 **근거만 강해졌다**.
--     · 원천 인벤토리도 그대로다 — 실측 분해: BASE TABLE 49 = ML_RST_DATA 16 + ML_TRAIN_DATA 20
--       + 원천 스냅샷 12 + ML_PROCEDURE_LOG 1. 그 밖에 VIEW 4(고유명) · PROCEDURE 14.
--     ⇒ 본 파일의 DDL 본문은 손대지 않았다. 고친 것은 머리말의 참조·수치뿐이다.
--     · 형제 문서 참조 정정: 「06번 C_CONSUMER」 → **07번** · 「04_2번 SILVER」 → **06번**.
--     · 총 이관 대상 67 → **69** (브론즈가 50 → 52 로 늘었다 · 04번 2026-08-29 이력 참조).
--     · 자기참조 오류 정정: 적재 절차 「05번 A.5-B.x」는 실제로 **07번**(C_CONSUMER)의 절이다.
--
-- 스테이지 적재 실측 / STAGE STATE  (2026-08-29 · SANDBOX.TOOLS.MIG_LOAD_STAGE)
--   ML/ 하위 = **16 테이블 / 54 파일 / 약 28.9 MB(gz)** — 본 파일의 16종과 **전건 일치**한다(2026-08-29 시점 · 17번째 ONCE_CONVERSION 은 2026-09-28 업로드 8파일).
--     LIST @SANDBOX.TOOLS.MIG_LOAD_STAGE/ML/;
--   ⇒ ML 축은 언로드가 끝났다. 남은 것은 C 계정에서 DDL 실행 + 07번 A.5-B 적재다.
--   ⚠️ 같은 시점에 BRONZE_CRM · SILVER 는 **업로드 진행 중**이었다(파일이 계속 증가).
--      따라서 ML 이외 스키마의 적재 완료 여부는 이 문서로 판정하지 않는다 — 그때 다시 LIST 한다.
--
-- 사용법 / USAGE (C 계정에서)
--   1) 04번 DDL(브론즈)과 독립적으로 실행할 수 있다. 선후 관계 없음.
--   2) 위에서 아래로 순서대로 실행 ([SCHEMA] → [TABLE] 12).
--   3) 생성 확인 (파일 하단 검증 쿼리 · 기대 12):
--        SELECT COUNT(*) FROM GN_DW.INFORMATION_SCHEMA.TABLES
--        WHERE table_schema='ML' AND table_type='BASE TABLE';
--   4) 이후 01번 문서 5.6(ML 적재) 절차로 데이터 적재.
--
-- 적재 시 주의 / LOAD NOTES
--   - CSV는 위치(순서) 기반 적재이며 MATCH_BY_COLUMN_NAME 미지원 → 본 파일의 컬럼 순서를 반드시 유지.
--   - 🔴 **PREDICTION/PREDICT VARIANT 5종은 일반 COPY 로 적재하면 JSON 이 문자열로 저장된다.**
--     GA4 events_* 와 동일한 함정이며, TRY_PARSE_JSON 변환 COPY 가 필수다(07번 A.5-B.2).
--     컬럼 위치(1-based · 전부 마지막 컬럼):
--       · ML_RST_DATA_SPNSR_CHURN_12M                    18컬럼 → $18
--       · ML_RST_DATA_MBER_CHURN_12M                     18컬럼 → $18
--       · ML_RST_DATA_MBER_INC_12M                       21컬럼 → $21
--       · ML_RST_DATA_LOYAL_MBER                         22컬럼 → $22
--       · ML_RST_DATA_ONCE_CONVERSION                     5컬럼 → $5  (🔴 컬럼명 PREDICT)
--     평탄화 결과(`PREDICTION:probability:"1"`·`PREDICTION:class`)를 SERVING 뷰가 쓰므로,
--     문자열로 적재되면 SV 층에서 조용히 NULL 이 된다.
--   - 스키마 옵션: A 계정 실측 DDL 은 `create schema if not exists GN_DW.ML;`(옵션 없음)이다.
--     본 파일은 C 계정 관례(BRONZE 3스키마 = MANAGED ACCESS · 소유 GN_DW_ADMIN)에 맞췄다.
--     원천과 다른 유일한 지점이며, 테이블 구조는 무변경이다.
--
-- 객체 인덱스 / OBJECT INDEX  (요건 = 260814 기준 머신러닝 개발 내용)
--   [SCHEMA] GN_DW.ML — 머신러닝 예측 결과, 테이블 12개 (🆕 O198)
--     회원실 1    ML_RST_DATA_SPNSR_CHURN_12M                    18컬럼  캠페인별 이탈 예측
--     회원실 2    ML_RST_DATA_MBER_CHURN_12M                     18컬럼  회원별 중단 예측
--     회원실 3    ML_RST_DATA_CMPGN_CTGR_AMT                      6컬럼  캠페인카테고리별 회비 예측
--     회원실 4    ML_RST_DATA_MBER_INC_12M                       21컬럼  회원 단위 증액 가능성 예측
--     회원실 5    ML_RST_DATA_LOYAL_MBER                         22컬럼  충성회원 가능성 예측
--   ⛔ 기획실 1    ML_RST_DATA_MONTHLY_DEPT_DVLP_AMT               6컬럼  부서별 연도말 개발 예측치
--   ⛔ 기획실 2    ML_RST_DATA_MONTHLY_SPNSR_BSNS_ID_DVLP_AMT      6컬럼  후원사업별 연도말 개발 예측치
--   ⛔ 기획실 3    ML_RST_DATA_MONTHLY_NEW_OLD_DVLP_AMT            6컬럼  신규/기존별 개발 건수 예측
--     나마본 1    ML_RST_DATA_MONTHLY_DVLP_AMT                    5컬럼  월별 신규 후원개발 금액 예측
--     나마본 2    ML_RST_DATA_MKTG_CHANNEL_MBER_AVG_LTV           6컬럼  마케팅채널별 회원평균 LTV (🆕 O198 · ⚠️ 추정 구조)
--     나마본 3    ML_RST_DATA_CMPGN_SPNSR_AMT_LTV                 6컬럼  캠페인별 후원금액 LTV (🆕 O198 · ⚠️ 추정 구조)
--     나마본 4    ML_RST_DATA_CHANNEL_NEW_SPNSR_DVLP_CONTRIBUTION  5컬럼  신규 후원 유치 요인 분석
--     나마본 5    ML_RST_DATA_MONTHLY_CMPGN_DVLP_AMT              6컬럼  캠페인별 월별 개발액 예측
--     나마본 6    ML_RST_DATA_DVLP_INC_CONTRIBUTION               5컬럼  증액 개발 요인 분석
--     나마본 7    ML_RST_DATA_ONCE_CONVERSION                     5컬럼  일시후원 정기전환 예측 (VARIANT PREDICT)
-- =====================================================================


-- #####################################################################
-- # SCHEMA : GN_DW.ML  (머신러닝 예측 결과)
-- #####################################################################
-- 전제: 04번 DDL 또는 기존 환경에서 DB GN_DW 와 역할 GN_DW_ADMIN 이 이미 존재한다.
--       없으면 04번 DDL 상단(USE ROLE SYSADMIN → CREATE DATABASE → GRANT OWNERSHIP)을 먼저 실행한다.
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
-- drop schema GN_DW.ML;
create schema if not exists GN_DW.ML with managed access
  COMMENT='머신러닝 예측 결과 — 원천 계정 산출물 이관 대상. 학습·중간 테이블은 이관하지 않는다.';

-- ---------------------------------------------------------------------
-- [TABLE] 예측결과 12종  (10종 = 20_ML_ddl.sql 무변경 발췌 · 2종 = 추정 구조 O198)
-- ---------------------------------------------------------------------

--  1/12 · 회원실 1 · 캠페인별 이탈 예측 (18컬럼 · VARIANT $18)
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

--  2/12 · 회원실 2 · 회원별 중단 예측 (18컬럼 · VARIANT $18)
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

--  3/12 · 회원실 3 · 캠페인카테고리별 회비 예측 (6컬럼)
create or replace TABLE GN_DW.ML.ML_RST_DATA_CMPGN_CTGR_AMT (
	STDR_MT VARCHAR(16777216) COMMENT '예측 실행 기준월 (YYYYMM)',
	SERIES VARCHAR(16777216) COMMENT '캠페인카테고리코드 (CMPGN_CTGR_CD)',
	TS TIMESTAMP_NTZ(9) COMMENT '예측 기준일 (월 시작일)',
	FORECAST FLOAT COMMENT '예측 회비금액',
	LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
	UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
)COMMENT='캠페인카테고리별 향후 12개월 월간 회비(후원금액) 예측 결과'
;

--  4/12 · 회원실 4 · 회원 단위 증액 가능성 예측 (21컬럼 · VARIANT $21)
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

--  5/12 · 회원실 5 · 충성회원 가능성 예측 (22컬럼 · VARIANT $22)
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

-- ⛔ [2026-10-01 O195] 운영계·개발계 모두 DROP 완료(사용자 지시) — 재생성하지 않는다. 재활성은 O192-A D-3 사용자 결정
--  (제외) · 기획실 1 · 부서별 연도말 개발 예측치 (6컬럼)
-- create or replace TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_DEPT_DVLP_AMT (
-- 	STDR_MT VARCHAR(16777216) COMMENT '예측 실행 기준월 (YYYYMM)',
-- 	SERIES VARCHAR(16777216) COMMENT '부서코드 (ACMSLT_DEPT_CD)',
-- 	TS TIMESTAMP_NTZ(9) COMMENT '예측 기준일 (월 시작일)',
-- 	FORECAST FLOAT COMMENT '예측 개발금액 (만원 단위, 신규+증액+재후원)',
-- 	LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
-- 	UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
-- )COMMENT='부서(ACMSLT_DEPT_CD)별 월간 후원개발 금액(만원) 향후 12개월 예측 결과'
-- ;

--  (제외) · 기획실 2 · 후원사업별 연도말 개발 예측치 (6컬럼)
-- create or replace TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_SPNSR_BSNS_ID_DVLP_AMT (
-- 	STDR_MT VARCHAR(16777216) COMMENT '예측 실행 기준월 (YYYYMM)',
-- 	SERIES VARCHAR(16777216) COMMENT '후원사업ID (SPNSR_BSNS_ID)',
-- 	TS TIMESTAMP_NTZ(9) COMMENT '예측 기준일 (월 시작일)',
-- 	FORECAST FLOAT COMMENT '예측 개발금액 (만원 단위, 신규+증액+재후원)',
-- 	LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
-- 	UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
-- )COMMENT='후원사업(SPNSR_BSNS_ID)별 월간 후원개발 금액(만원) 향후 12개월 예측 결과'
-- ;

--  (제외) · 기획실 3 · 신규/기존별 개발 건수 예측 (6컬럼)
-- create or replace TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_NEW_OLD_DVLP_AMT (
-- 	STDR_MT VARCHAR(16777216) COMMENT '예측 실행 기준월 (YYYYMM)',
-- 	SERIES VARCHAR(16777216) COMMENT '개발 유형 (NEW=신규, OLD=기존 증액+재후원)',
-- 	TS TIMESTAMP_NTZ(9) COMMENT '예측 기준일 (월 시작일)',
-- 	FORECAST FLOAT COMMENT '예측 개발금액 (만원 단위)',
-- 	LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
-- 	UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
-- )COMMENT='신규/기존별 월간 후원개발 금액(만원) 향후 12개월 예측 결과'
-- ;

--  6/12 · 나마본 1 · 월별 신규 후원개발 금액 예측 (5컬럼)
create or replace TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_DVLP_AMT (
	STDR_MT VARCHAR(16777216) COMMENT '예측 실행 기준월 (YYYYMM)',
	TS TIMESTAMP_NTZ(9) COMMENT '예측 기준일 (월 시작일)',
	FORECAST FLOAT COMMENT '예측 개발금액 (만원 단위, 신규+증액+재후원)',
	LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
	UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
)COMMENT='월별 전체 신규 후원개발 금액(만원) 향후 12개월 예측 결과'
;

-- 🆕 [2026-10-02 O198 · 사용자 지시] 구 LTV 4종(UCMPGN_LTV · UCMPGN_LTV_SCORE · CMPGN_LTV · CMPGN_LTV_SCORE) 제외 · 신규 2종으로 대체.
--   🔴🔴 아래 2종은 **원천 정의(20_ML_ddl.sql)에 아직 없다** — 구조는 구 LTV 예측 테이블(6컬럼 시계열 예측형)에서 **추정**했다.
--      ⇒ A 계정에서 02번 6.3(GET_DDL) 결과로 **반드시 교체한 뒤** C 에서 실행한다. 추정 그대로 적재하면 위치 기반 CSV 가 밀린다.
--      ⇒ 교체 후 이 경고 블록과 각 표의 「⚠️ 추정」 표기를 지운다.

--  7/12 · 나마본 2 · 마케팅채널별 회원평균 LTV (⚠️ 추정 구조 · 원천 확인 필요)
create or replace TABLE GN_DW.ML.ML_RST_DATA_MKTG_CHANNEL_MBER_AVG_LTV (
  STDR_MT VARCHAR(16777216) COMMENT '예측 실행 기준월 (YYYYMM)',
  SERIES VARCHAR(16777216) COMMENT '마케팅채널 (⚠️ 추정 — 원천 확인 필요)',
  TS TIMESTAMP_NTZ(9) COMMENT '예측 기준일 (월 시작일)',
  FORECAST FLOAT COMMENT '예측 회원평균 후원금액',
  LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
  UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
)COMMENT='마케팅채널별 회원평균 후원 LTV 예측 결과 (⚠️ 추정 구조 · O198 · 02번 6.3 으로 교체)'
;

--  8/12 · 나마본 3 · 캠페인별 후원금액 LTV (⚠️ 추정 구조 · 원천 확인 필요)
create or replace TABLE GN_DW.ML.ML_RST_DATA_CMPGN_SPNSR_AMT_LTV (
  STDR_MT VARCHAR(16777216) COMMENT '예측 실행 기준월 (YYYYMM)',
  SERIES VARCHAR(16777216) COMMENT '캠페인코드 (CMPGN_CD · ⚠️ 추정 — 원천 확인 필요)',
  TS TIMESTAMP_NTZ(9) COMMENT '예측 기준일 (월 시작일)',
  FORECAST FLOAT COMMENT '예측 월간 후원금액',
  LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
  UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
)COMMENT='캠페인별 후원금액 LTV 예측 결과 (⚠️ 추정 구조 · O198 · 02번 6.3 으로 교체)'
;

--  9/12 · 나마본 4 · 신규 후원 유치 요인 분석 (5컬럼)
create or replace TABLE GN_DW.ML.ML_RST_DATA_CHANNEL_NEW_SPNSR_DVLP_CONTRIBUTION (
	STDR_MT VARCHAR(16777216) COMMENT '분석 실행 기준월 (YYYYMM)',
	RANK NUMBER(38,0) COMMENT '피처 중요도 순위',
	FEATURE VARCHAR(16777216) COMMENT '피처명',
	SCORE FLOAT COMMENT '피처 중요도 점수 (0~1, 합계=1)',
	FEATURE_TYPE VARCHAR(16777216) COMMENT '피처 유형 (user_provided)'
)COMMENT='신규 후원 유치 상위 채널 결정 요인 (피처 중요도) 분석 결과'
;

-- 10/12 · 나마본 5 · 캠페인별 월별 개발액 예측 (6컬럼)
create or replace TABLE GN_DW.ML.ML_RST_DATA_MONTHLY_CMPGN_DVLP_AMT (
	STDR_MT VARCHAR(16777216) COMMENT '예측 실행 기준월 (YYYYMM)',
	SERIES VARCHAR(16777216) COMMENT '캠페인코드 (CMPGN_CD)',
	TS TIMESTAMP_NTZ(9) COMMENT '예측 기준일 (월 시작일)',
	FORECAST FLOAT COMMENT '예측 개발금액 (만원 단위, 신규+증액+재후원)',
	LOWER_BOUND FLOAT COMMENT '95% 신뢰구간 하한',
	UPPER_BOUND FLOAT COMMENT '95% 신뢰구간 상한'
)COMMENT='캠페인(CMPGN_CD)별 월간 후원개발 금액(만원) 향후 12개월 예측 결과'
;

-- 11/12 · 나마본 6 · 증액 개발 요인 분석 (5컬럼)
create or replace TABLE GN_DW.ML.ML_RST_DATA_DVLP_INC_CONTRIBUTION (
	STDR_MT VARCHAR(16777216) COMMENT '분석 실행 기준월 (YYYYMM)',
	RANK NUMBER(38,0) COMMENT '피처 중요도 순위',
	FEATURE VARCHAR(16777216) COMMENT '피처명',
	SCORE FLOAT COMMENT '피처 중요도 점수 (0~1, 합계=1)',
	FEATURE_TYPE VARCHAR(16777216) COMMENT '피처 유형 (user_provided)'
)COMMENT='후원개발 20% 증가를 위한 우선 개선 요인 (피처 중요도) 분석 결과'
;


-- 12/12 · 나마본 7 · 일시후원 → 정기후원 전환 예측 (5컬럼 · VARIANT $5)
--   🔴 2026-09-28 신규. VARIANT 컬럼명이 **PREDICT** 다(다른 4종은 PREDICTION) — 원천 무변경.
--   🆕 2026-09-29 원천 20번 갱신 — 컬럼·테이블 COMMENT 가 원천에 생겼다 ⇒ 종전 보강 문안을 **원천 문안으로 교체**.
--      🔴 타입도 원천을 따른다: ONCE_MBER_NO VARCHAR(10)→VARCHAR · CONVERSION_YN NUMBER(1,0)→VARCHAR · DATA_TYPE VARCHAR(5)→VARCHAR.
create or replace TABLE GN_DW.ML.ML_RST_DATA_ONCE_CONVERSION (
  ONCE_MBER_NO VARCHAR(16777216) COMMENT '회원번호',
  STDR_MT VARCHAR(16777216) COMMENT '기준월 (YYYYMM)',
  CONVERSION_YN VARCHAR(16777216) COMMENT '회원 전환여부',
  DATA_TYPE VARCHAR(16777216) COMMENT '데이터유형',
  PREDICT VARIANT COMMENT '예측결과'
)COMMENT='일시회원 향후 6개월 내 전환 가능성 예측 결과'
;


-- #####################################################################
-- # 생성 확인 / VERIFY
-- #####################################################################
-- (1) 테이블 수 — 기대 12
SELECT COUNT(*) AS n_tables
FROM GN_DW.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'ML' AND table_type = 'BASE TABLE';

-- (2) 테이블별 컬럼 수 — 위 객체 인덱스와 대조
SELECT table_name, COUNT(*) AS n_cols
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'ML'
GROUP BY 1 ORDER BY 1;

-- (3) VARIANT 컬럼 위치 확인 — 기대 5행, 전부 ordinal_position = 해당 테이블 컬럼 수
SELECT table_name, column_name, ordinal_position, data_type
FROM GN_DW.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'ML' AND data_type = 'VARIANT'
ORDER BY 1;

-- (4) 적재 전이므로 전 테이블 0행이 정상이다. 적재 후에는 07번 A.5-B.4 로 검증한다.
