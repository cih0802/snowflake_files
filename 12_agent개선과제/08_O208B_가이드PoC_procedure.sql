-- 08_O208B_가이드PoC_procedure.sql — O208-B X3 위임형 PoC 프로시저 보존본(라이브 객체는 O208-C 에서 DROP · 사용자 일괄 승인)
--   · 재생성 = 이 파일 실행 후 08_O208B_가이드PoC_spec.yaml 로 CREATE AGENT GN_DW.SERVING.AGENT_GUIDE_POC FROM SPECIFICATION
--   · 🔴 운영계·정식 도입 시 소유 역할 = GN_DW_ADMIN(PoC 는 ACCOUNTADMIN 소유였다) · 허용 Agent 화이트리스트 유지
-- Co-authored with CoCo
CREATE OR REPLACE PROCEDURE GN_DW.SERVING.USP_ASK_AGENT_POC(AGENT_NAME VARCHAR, QUESTION VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'O208-B X3 PoC — 하위 Agent 1회 호출 후 답변 텍스트 반환(허용 = AGENT_EXECUTIVE·AGENT_MEMBER·AGENT_MARKETING) · 임시 객체'
EXECUTE AS OWNER
AS
$$
DECLARE
  fqn VARCHAR;
  body VARCHAR;
  resp VARIANT;
  ans VARCHAR;
BEGIN
  IF (UPPER(:AGENT_NAME) NOT IN ('AGENT_EXECUTIVE','AGENT_MEMBER','AGENT_MARKETING')) THEN
    RETURN 'ERROR 허용되지 않은 Agent: ' || :AGENT_NAME;
  END IF;
  fqn := 'GN_DW.SERVING.' || UPPER(:AGENT_NAME);
  body := TO_JSON(OBJECT_CONSTRUCT('messages', ARRAY_CONSTRUCT(OBJECT_CONSTRUCT('role','user','content',
            ARRAY_CONSTRUCT(OBJECT_CONSTRUCT('type','text','text', :QUESTION))))));
  resp := PARSE_JSON(SNOWFLAKE.CORTEX.DATA_AGENT_RUN(:fqn, :body));
  SELECT LISTAGG(c.value:text::STRING, '\n') INTO :ans
    FROM TABLE(FLATTEN(INPUT => :resp:content)) c
   WHERE c.value:type::STRING = 'text';
  RETURN '[' || UPPER(:AGENT_NAME) || ' 답변]\n' || COALESCE(:ans, '(텍스트 없음)');
END;
$$;
