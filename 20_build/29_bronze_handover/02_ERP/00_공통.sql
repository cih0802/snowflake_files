--메일 주소 설정
-- show users;
-- use role securityadmin;
-- alter user RPA_ETL set email='메일주소';


CREATE OR REPLACE NOTIFICATION INTEGRATION email_alert_integration
  TYPE = EMAIL
  ENABLED = TRUE
  COMMENT = '계정 내 모든 유저 대상 이메일 알림 연동';



-- ERP 연동 오류 기록 테이블
CREATE SEQUENCE GN_DW.BRONZE_ERP.SEQ_SYNC_ERR_INFO
    START = 1
    INCREMENT = 1
    ORDER;
    
create TABLE GN_DW.BRONZE_ERP.SYNC_ERR_INFO (
	ERR_SEQ NUMBER(38,0) DEFAULT GN_DW.BRONZE_ERP.SEQ_SYNC_ERR_INFO.NEXTVAL COMMENT '오류 이력 일련번호',
	ERR_DATETIME TIMESTAMP_NTZ(9) COMMENT '오류 발생 일시',
	DATA_TYPE VARCHAR(16777216) COMMENT '오류 데이터 유형',
	ERR_INFO VARCHAR(16777216) COMMENT '오류 상세 내용'
)COMMENT='ERP 외부 파일 업로드 및 데이터 적재 오류 이력'
;