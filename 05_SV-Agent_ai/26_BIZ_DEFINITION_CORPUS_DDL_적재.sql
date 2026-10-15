-- ============================================================================
-- 24_BIZ_DEFINITION_CORPUS_DDL_적재.sql — 🆕 10차(O217) 비즈니스 정의 코퍼스 + Cortex Search (SQL 전용 · python 불필요)
--   · 순서 = 22_ML_SV_DDL.sql 다음 · 23_ML_INC_MKTG_CMPGN_DDL.sql · 09_1/09_2(Agent) 앞
--     (Agent spec 의 search_biz_definition 도구가 이 Search 서비스를 참조한다 — 없으면 죽은 도구)
--   · 적재 원본 = 12_agent개선과제/output/O217_biz_definition_corpus.csv (2,145행)
--     🔴 CSV 를 고쳤으면 먼저 재생성한다: python3 12_agent개선과제/tools/build_biz_definition_corpus.py
--        (라우팅 원본 = 12_agent개선과제/tools/O217_routing_curated.csv · 지표 원본 = 90_provided_definition/)
--   · 워크스페이스 stage 는 COPY INTO 를 직접 지원하지 않는다(실측: 'WORKSPACE' not supported)
--     ⇒ COPY FILES 로 OPS 스테이지에 서버측 복사 후 적재한다(09_2 [0-B] 와 같은 방식).
--   · 재실행 안전 = TRUNCATE + COPY(FORCE) · Search 는 CREATE OR REPLACE
--   · 롤백 = DROP CORTEX SEARCH SERVICE GN_DW.SERVING.SEARCH_BIZ_DEFINITION; DROP TABLE GN_DW.SERVING.BIZ_DEFINITION_CORPUS;
-- Co-authored with CoCo
-- ============================================================================
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_DEV_WH;
USE SCHEMA GN_DW.SERVING;

-- [1] 테이블
CREATE TABLE IF NOT EXISTS GN_DW.SERVING.BIZ_DEFINITION_CORPUS (
    DOC_ID       VARCHAR COMMENT '문서 ID(원천약어-순번 · RT=라우팅 · MET=지표 · TERM=용어 · ORG=조직 · SRC=원천참고)',
    DOC_TYPE     VARCHAR COMMENT '라우팅 · 지표 · 용어 · 조직 · 원천참고',
    TITLE        VARCHAR COMMENT '지표명·용어·부서명·원천 객체명',
    SYNONYMS     VARCHAR COMMENT '한글 별칭(쉼표)',
    DEFINITION   VARCHAR COMMENT '정의 원문(요약 없음)',
    FORMULA      VARCHAR COMMENT '계산식 원문',
    AGENT_SCOPE  VARCHAR COMMENT '적용 Agent(MARKETING|MEMBER|EXECUTIVE)',
    TOOL_NAME    VARCHAR COMMENT '답을 내는 analyst 도구명(라우팅·확정 지표 행만)',
    SV_FIELD     VARCHAR COMMENT 'SV 논리 테이블.필드명(라우팅·확정 지표 행만)',
    LIMITATION   VARCHAR COMMENT '산출 범위·불가 사유·데이터 출처·합의 필요사항',
    SOURCE_FILE  VARCHAR COMMENT '90_provided_definition 파일:행 또는 사용자 결정 출처',
    SEARCH_TEXT  VARCHAR COMMENT '검색 본문(위 컬럼 합본 · 🆕 O233-B Markdown 포맷)',
    -- 🆕 [O233-B] 검색 품질용 파생 열 · 원천 내용 창작 없음
    KEYWORDS     VARCHAR COMMENT '🆕 O233-B 검색 키워드 변형(제목·동의어의 띄어쓰기 제거·율↔률·누계↔누적·단위 괄호 제거 · 규칙 생성)',
    IS_ADDITIVE  VARCHAR COMMENT '🆕 O233-B 가산성. N = 원천 문구에 「비가산」 명시 · 빈 값 = 근거 없음'
)
COMMENT = '비즈니스 정의 코퍼스 — 현업 지표사전·용어·조직·원천 정의 + 라우팅 결정. Cortex Search(SEARCH_BIZ_DEFINITION) 원천. 수치 원천이 아니다.';

-- [2] 적재용 스테이지·파일 형식(OPS)
CREATE STAGE IF NOT EXISTS GN_DW.OPS.BIZ_DEFINITION_STAGE
  COMMENT = 'O217 비즈니스 정의 코퍼스 CSV 적재용(워크스페이스 → COPY FILES 서버측 복사)';
CREATE FILE FORMAT IF NOT EXISTS GN_DW.OPS.FF_BIZ_DEFINITION_CSV
  TYPE = CSV
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  ENCODING = 'UTF8'
  EMPTY_FIELD_AS_NULL = FALSE
  NULL_IF = ()
  COMMENT = 'O217 코퍼스 CSV(헤더 1행 · 큰따옴표 · 빈 칸은 빈 문자열 — build_biz_definition_corpus.py 와 같다)';

-- [3] 워크스페이스 CSV → OPS 스테이지
COPY FILES INTO @GN_DW.OPS.BIZ_DEFINITION_STAGE/
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/12_agent개선과제/output/'
  FILES = ('O217_biz_definition_corpus.csv');

-- [4] 적재(덮어쓰기)
TRUNCATE TABLE GN_DW.SERVING.BIZ_DEFINITION_CORPUS;
COPY INTO GN_DW.SERVING.BIZ_DEFINITION_CORPUS
  FROM @GN_DW.OPS.BIZ_DEFINITION_STAGE/O217_biz_definition_corpus.csv
  FILE_FORMAT = (FORMAT_NAME = 'GN_DW.OPS.FF_BIZ_DEFINITION_CSV')
  ON_ERROR = ABORT_STATEMENT
  FORCE = TRUE;

-- [5] 🆕 [O233-B] Cortex Search — multi-index 하이브리드(다국어 벡터 + 제목·키워드·본문 키워드 색인)
--     원천참고 = BRONZE 물리명은 SQL 식별자로 오용되므로 검색에서 뺀다(테이블에는 보존)
--     모델 = snowflake-arctic-embed-l-v2.0(다국어) · 종전 = snowflake-arctic-embed-m-v1.5(영어)
--     평가(40문항) = V1 hit@3=33% → V2 hit@3=45% (jw08094 · 2026-10-15)
CREATE OR REPLACE CORTEX SEARCH SERVICE GN_DW.SERVING.SEARCH_BIZ_DEFINITION
    TEXT INDEXES TITLE, KEYWORDS, SEARCH_TEXT
    VECTOR INDEXES SEARCH_TEXT (model='snowflake-arctic-embed-l-v2.0')
    PRIMARY KEY (DOC_ID)
    ATTRIBUTES DOC_TYPE, AGENT_SCOPE_ARR
    WAREHOUSE = GN_DW_ANALYTICS_WH
    TARGET_LAG = '1 day'
    COMMENT = 'O233-B 비즈니스 정의 검색(다국어 임베딩 · 제목·키워드·본문 키워드 색인 하이브리드 · hit@3 33→45%). 수치는 analyst 도구로만 낸다.'
AS
SELECT DOC_ID, DOC_TYPE, TITLE, SYNONYMS, DEFINITION, FORMULA, AGENT_SCOPE,
       SPLIT(AGENT_SCOPE, '|') AS AGENT_SCOPE_ARR,
       TOOL_NAME, SV_FIELD, LIMITATION, SOURCE_FILE, SEARCH_TEXT, KEYWORDS, IS_ADDITIVE
FROM GN_DW.SERVING.BIZ_DEFINITION_CORPUS
WHERE DOC_TYPE <> '원천참고';

-- [6] 권한
GRANT SELECT ON TABLE GN_DW.SERVING.BIZ_DEFINITION_CORPUS TO ROLE GN_DW_ANALYST;
GRANT SELECT ON TABLE GN_DW.SERVING.BIZ_DEFINITION_CORPUS TO ROLE GN_DW_VIEWER;
GRANT SELECT ON TABLE GN_DW.SERVING.BIZ_DEFINITION_CORPUS TO ROLE GN_DW_SERVICE;
GRANT USAGE ON CORTEX SEARCH SERVICE GN_DW.SERVING.SEARCH_BIZ_DEFINITION TO ROLE GN_DW_ANALYST;
GRANT USAGE ON CORTEX SEARCH SERVICE GN_DW.SERVING.SEARCH_BIZ_DEFINITION TO ROLE GN_DW_VIEWER;
GRANT USAGE ON CORTEX SEARCH SERVICE GN_DW.SERVING.SEARCH_BIZ_DEFINITION TO ROLE GN_DW_SERVICE;

-- [7] 검증(ua91864 2026-10-13 기대값 = 라우팅 16 · 지표 236 · 용어 517 · 조직 222 · 원천참고 1,154 · 1순위 RT-19 · RT-14)
SELECT DOC_TYPE, COUNT(*) AS N FROM GN_DW.SERVING.BIZ_DEFINITION_CORPUS GROUP BY DOC_TYPE ORDER BY DOC_TYPE;
SELECT 'Q_INC' AS Q, PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW('GN_DW.SERVING.SEARCH_BIZ_DEFINITION',
  '{"query":"10월 증액개발이 높을 것으로 보이는 마케팅캠페인 예측","columns":["DOC_ID"],"limit":1}')):results[0]:DOC_ID::STRING AS TOP1
UNION ALL
SELECT 'Q_LTV', PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW('GN_DW.SERVING.SEARCH_BIZ_DEFINITION',
  '{"query":"캠페인별 LTV 계산식","columns":["DOC_ID"],"limit":1}')):results[0]:DOC_ID::STRING;
