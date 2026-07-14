-- BRONZE_ERP 스키마 예산 실적 원장 테이블의 물리 DDL을 11_crm 스타일로 정리.
-- Co-authored with CoCo
-- =============================================================================
-- BRONZE_ERP 물리 DDL (정본 / source of truth for physical types)
-- doc_id: BRONZE_ERP_DDL
-- project: GN_DW (굿네이버스)
-- source: SnowSQL `create or replace` 출력
-- scope: BRONZE_ERP 스키마 + 1 테이블 (ERP 예산/실적 원천 적재, managed access)
-- note:
--   - 컬럼 한글 설명은 각 컬럼의 COMMENT 참조.
--   - 본 파일은 **물리 데이터타입의 정본**.
--   - 월별 금액 컬럼(_01 ~ _12)은 각 월의 예산/집행 실적.
-- =============================================================================

create or replace schema GN_DW.BRONZE_ERP with managed access
  COMMENT='원천 데이터 적재 - ERP (예산/실적)';

-- -----------------------------------------------------------------------------
-- 1. BDGT_ACMSLT_LEDGER  (예산 실적 원장)
-- -----------------------------------------------------------------------------
create or replace TABLE GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER (
  -- 분류 차원
  YEAR                VARCHAR(16777216) COMMENT '연도',
  INCOME_EXPS_DIV_NM  VARCHAR(16777216) COMMENT '수지구분',
  BDGT_UNIT_NM        VARCHAR(16777216) COMMENT '예산단위',
  JANG_NM             VARCHAR(16777216) COMMENT '장',
  KWAN_NM             VARCHAR(16777216) COMMENT '관',
  HANG_NM             VARCHAR(16777216) COMMENT '항',
  MOK_NM              VARCHAR(16777216) COMMENT '목',
  DTL_ITEM_NM         VARCHAR(16777216) COMMENT '세목',
  SUBDTL_ITEM_NM      VARCHAR(16777216) COMMENT '세세목',
  FUND_SOURCE_NM      VARCHAR(16777216) COMMENT '재원',

  -- 합계 금액
  YEAR_BDGT_TOT_AMT   NUMBER(38,0)      COMMENT '연예산_합계',
  CHN_BDGT_TOT_AMT    NUMBER(38,0)      COMMENT '변경예산_합계',
  ADJ_BDGT_TOT_AMT    NUMBER(38,0)      COMMENT '조정예산_합계',
  EXEC_TOT_AMT        NUMBER(38,0)      COMMENT '집행금액_합계',

  -- 01월
  YEAR_BDGT_AMT_1     NUMBER(38,0)      COMMENT '연예산_01',
  CHN_BDGT_AMT_1      NUMBER(38,0)      COMMENT '변경예산_01',
  ADJ_BDGT_AMT_1      NUMBER(38,0)      COMMENT '조정예산_01',
  EXEC_AMT_1          NUMBER(38,0)      COMMENT '집행금액_01',

  -- 02월
  YEAR_BDGT_AMT_2     NUMBER(38,0)      COMMENT '연예산_02',
  CHN_BDGT_AMT_2      NUMBER(38,0)      COMMENT '변경예산_02',
  ADJ_BDGT_AMT_2      NUMBER(38,0)      COMMENT '조정예산_02',
  EXEC_AMT_2          NUMBER(38,0)      COMMENT '집행금액_02',

  -- 03월
  YEAR_BDGT_AMT_3     NUMBER(38,0)      COMMENT '연예산_03',
  CHN_BDGT_AMT_3      NUMBER(38,0)      COMMENT '변경예산_03',
  ADJ_BDGT_AMT_3      NUMBER(38,0)      COMMENT '조정예산_03',
  EXEC_AMT_3          NUMBER(38,0)      COMMENT '집행금액_03',

  -- 04월
  YEAR_BDGT_AMT_4     NUMBER(38,0)      COMMENT '연예산_04',
  CHN_BDGT_AMT_4      NUMBER(38,0)      COMMENT '변경예산_04',
  ADJ_BDGT_AMT_4      NUMBER(38,0)      COMMENT '조정예산_04',
  EXEC_AMT_4          NUMBER(38,0)      COMMENT '집행금액_04',

  -- 05월
  YEAR_BDGT_AMT_5     NUMBER(38,0)      COMMENT '연예산_05',
  CHN_BDGT_AMT_5      NUMBER(38,0)      COMMENT '변경예산_05',
  ADJ_BDGT_AMT_5      NUMBER(38,0)      COMMENT '조정예산_05',
  EXEC_AMT_5          NUMBER(38,0)      COMMENT '집행금액_05',

  -- 06월
  YEAR_BDGT_AMT_6     NUMBER(38,0)      COMMENT '연예산_06',
  CHN_BDGT_AMT_6      NUMBER(38,0)      COMMENT '변경예산_06',
  ADJ_BDGT_AMT_6      NUMBER(38,0)      COMMENT '조정예산_06',
  EXEC_AMT_6          NUMBER(38,0)      COMMENT '집행금액_06',

  -- 07월
  YEAR_BDGT_AMT_7     NUMBER(38,0)      COMMENT '연예산_07',
  CHN_BDGT_AMT_7      NUMBER(38,0)      COMMENT '변경예산_07',
  ADJ_BDGT_AMT_7      NUMBER(38,0)      COMMENT '조정예산_07',
  EXEC_AMT_7          NUMBER(38,0)      COMMENT '집행금액_07',

  -- 08월
  YEAR_BDGT_AMT_8     NUMBER(38,0)      COMMENT '연예산_08',
  CHN_BDGT_AMT_8      NUMBER(38,0)      COMMENT '변경예산_08',
  ADJ_BDGT_AMT_8      NUMBER(38,0)      COMMENT '조정예산_08',
  EXEC_AMT_8          NUMBER(38,0)      COMMENT '집행금액_08',

  -- 09월
  YEAR_BDGT_AMT_9     NUMBER(38,0)      COMMENT '연예산_09',
  CHN_BDGT_AMT_9      NUMBER(38,0)      COMMENT '변경예산_09',
  ADJ_BDGT_AMT_9      NUMBER(38,0)      COMMENT '조정예산_09',
  EXEC_AMT_9          NUMBER(38,0)      COMMENT '집행금액_09',

  -- 10월
  YEAR_BDGT_AMT_10    NUMBER(38,0)      COMMENT '연예산_10',
  CHN_BDGT_AMT_10     NUMBER(38,0)      COMMENT '변경예산_10',
  ADJ_BDGT_AMT_10     NUMBER(38,0)      COMMENT '조정예산_10',
  EXEC_AMT_10         NUMBER(38,0)      COMMENT '집행금액_10',

  -- 11월
  YEAR_BDGT_AMT_11    NUMBER(38,0)      COMMENT '연예산_11',
  CHN_BDGT_AMT_11     NUMBER(38,0)      COMMENT '변경예산_11',
  ADJ_BDGT_AMT_11     NUMBER(38,0)      COMMENT '조정예산_11',
  EXEC_AMT_11         NUMBER(38,0)      COMMENT '집행금액_11',

  -- 12월
  YEAR_BDGT_AMT_12    NUMBER(38,0)      COMMENT '연예산_12',
  CHN_BDGT_AMT_12     NUMBER(38,0)      COMMENT '변경예산_12',
  ADJ_BDGT_AMT_12     NUMBER(38,0)      COMMENT '조정예산_12',
  EXEC_AMT_12         NUMBER(38,0)      COMMENT '집행금액_12'
) COMMENT='예산 실적 원장'
;
