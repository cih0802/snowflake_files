------------------------------------------------------------
-- 프로시져 중 익셉션 발생시 아래 에러 테이블에 데이터 인입
------------------------------------------------------------
CREATE SEQUENCE GN_DW.BRONZE_AGENCY.SEQ_SYNC_ERR_INFO START = 1 INCREMENT = 1 ORDER;
create  TABLE GN_DW.BRONZE_AGENCY.SYNC_ERR_INFO (
    ERR_SEQ NUMBER(38,0) DEFAULT GN_DW.BRONZE_AGENCY.SEQ_SYNC_ERR_INFO.NEXTVAL COMMENT '오류 이력 일련번호',
    ERR_DATETIME TIMESTAMP_NTZ(9) COMMENT '오류 발생 일시',
    DATA_TYPE VARCHAR(16777216) COMMENT '오류 데이터 유형',
    ERR_INFO VARCHAR(16777216) COMMENT '오류 상세 내용'
)COMMENT='대행사 외부 데이터 적재 오류 이력';

