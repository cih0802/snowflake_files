-- ============================================================================
-- 09_SILVER_AD_CREATIVE_CAMPAIGN_MAP_적재.sql — 🆕 O232 · O232-B 미연결 광고 소재 → 캠페인 매핑표 적재 (SQL 전용)
--   · 순서 = 08_SILVER_테이블DDL(표 구조 정본) 다음 · dbt build 앞
--     (FACT_AD_PERFORMANCE 가 source silver_external.AD_CREATIVE_CAMPAIGN_MAP 를 읽는다 — 비어 있으면 CREATIVE_MAP 귀속 0)
--   · 적재 원본 = 12_agent개선과제/output/O232_광고_매핑_추천안.csv (258행 · 사용자 확정 2026-10-15)
--     열 순서: 1 광고구분 · 2 소재명 · 6 추천등급 · 11 현업 확정 · 12 확정 연결수준 · 13 확정 캠페인카테고리
--              · 14 확정 마케팅캠페인 · 15 확정 캠페인카테고리 코드(O232-B)
--   · 워크스페이스 stage 는 COPY INTO 를 직접 지원하지 않는다 ⇒ COPY FILES 로 OPS 스테이지에 복사 후 적재(26_ 과 같은 방식)
--   · 재실행 안전 = INSERT OVERWRITE · 롤백 = Time Travel(AT OFFSET) 또는 이 파일 재실행
-- Co-authored with CoCo
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;

-- [1] 적재용 스테이지·파일 형식(OPS)
CREATE STAGE IF NOT EXISTS GN_DW.OPS.AD_CREATIVE_MAP_STAGE
  COMMENT = 'O232 광고 소재 매핑 CSV 적재용(워크스페이스 → COPY FILES 서버측 복사)';
CREATE OR REPLACE FILE FORMAT GN_DW.OPS.FF_AD_CREATIVE_MAP_CSV
  TYPE = CSV
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  ENCODING = 'UTF8'
  EMPTY_FIELD_AS_NULL = FALSE
  NULL_IF = ()
  COMMENT = 'O232 매핑 CSV(헤더 1행 · 큰따옴표 · UTF-8 BOM · 빈 칸 = 빈 문자열 — 소재명 빈 값 1건 보존 · 나머지 열은 적재 SQL 에서 NULLIF)';

-- [2] 워크스페이스 CSV → OPS 스테이지
COPY FILES INTO @GN_DW.OPS.AD_CREATIVE_MAP_STAGE/
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/12_agent개선과제/output/'
  FILES = ('O232_광고_매핑_추천안.csv');

-- [3] 적재(덮어쓰기) — 확정 연결수준 라벨 → MAP_LEVEL 코드 · 라벨이 3종 밖이면 NULL 이 되어 NOT NULL 위반으로 멈춘다
--   🔴 소재명($2)은 NULLIF 하지 않는다 — 원천에 빈 문자열 소재명 1건(VIDEO · 미연결)이 있고 PK·조인이 빈 문자열로 맞는다.
--   ⚠️ 첫 열 이름에 BOM 이 붙어도 값($1)은 영향이 없다(헤더 행은 건너뛴다).
INSERT OVERWRITE INTO GN_DW.SILVER.AD_CREATIVE_CAMPAIGN_MAP
    (AD_SOURCE_TYPE, CREATIVE_NM, MAP_LEVEL, CMPGN_CTGR_NM, MKTG_CAMPAIGN_NAME,
     MAP_GRADE, CONFIRMED_NOTE, DW_LOAD_TS, CMPGN_CTGR_CD)
SELECT
    t.$1,
    t.$2,
    DECODE(t.$12, '마케팅캠페인', 'MKTG', '캠페인카테고리', 'CTGR', '미연결', 'NONE'),
    NULLIF(t.$13, ''),
    NULLIF(t.$14, ''),
    NULLIF(t.$6, ''),
    NULLIF(t.$11, ''),
    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
    TRY_TO_NUMBER(NULLIF(t.$15, ''))
-- ⚠️ 경로에 한글 파일명이 있어 따옴표로 감싼다(따옴표 없으면 syntax error · 실측 2026-10-15)
FROM '@GN_DW.OPS.AD_CREATIVE_MAP_STAGE/O232_광고_매핑_추천안.csv'
     (FILE_FORMAT => 'GN_DW.OPS.FF_AD_CREATIVE_MAP_CSV') t;

-- [4] 확인 — 기대(2026-10-15) = 258행 · MKTG 53 · CTGR 112 · NONE 93 · 이름 있는데 코드 없음 0
SELECT MAP_LEVEL, COUNT(*) AS N, COUNT(CMPGN_CTGR_NM) AS N_NM, COUNT(CMPGN_CTGR_CD) AS N_CD,
       COUNT(MKTG_CAMPAIGN_NAME) AS N_MK
FROM GN_DW.SILVER.AD_CREATIVE_CAMPAIGN_MAP
GROUP BY ROLLUP(MAP_LEVEL)
ORDER BY 1;
