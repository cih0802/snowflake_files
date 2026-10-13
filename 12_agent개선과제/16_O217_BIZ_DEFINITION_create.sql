-- O217 — 비즈니스 정의 코퍼스 테이블 + Cortex Search 서비스 (계정 jw08094 · 2026-10-13)
-- 적재 = python3 12_agent개선과제/tools/build_biz_definition_corpus.py --apply (테이블 생성 후)
-- Co-authored with CoCo

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
    SEARCH_TEXT  VARCHAR COMMENT '검색 본문(위 컬럼 합본)'
)
COMMENT = 'O217 비즈니스 정의 코퍼스 — 현업 지표사전·용어·조직·원천 정의 + 라우팅 결정. Cortex Search(SEARCH_BIZ_DEFINITION) 원천. 수치 원천이 아니다.';

CREATE OR REPLACE CORTEX SEARCH SERVICE GN_DW.SERVING.SEARCH_BIZ_DEFINITION
    ON SEARCH_TEXT
    ATTRIBUTES DOC_TYPE, AGENT_SCOPE, TITLE
    WAREHOUSE = GN_DW_ANALYTICS_WH
    TARGET_LAG = '1 day'
    COMMENT = 'O217 비즈니스 정의 검색(지표 정의·계산식·라우팅·용어·조직·원천 참고). 수치는 analyst 도구로만 낸다.'
AS
SELECT DOC_ID, DOC_TYPE, TITLE, SYNONYMS, DEFINITION, FORMULA, AGENT_SCOPE,
       TOOL_NAME, SV_FIELD, LIMITATION, SOURCE_FILE, SEARCH_TEXT
FROM GN_DW.SERVING.BIZ_DEFINITION_CORPUS
-- 원천참고(BRONZE 물리 컬럼·GA4 필드)는 SQL 식별자로 오용되므로 검색 대상에서 뺀다(테이블에는 보존)
WHERE DOC_TYPE <> '원천참고';
