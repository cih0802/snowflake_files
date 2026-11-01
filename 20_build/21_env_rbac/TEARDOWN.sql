-- TEARDOWN
USE ROLE ACCOUNTADMIN;

-- Stage를 저장할 DB/Schema 생성 (없는 경우)
CREATE DATABASE IF NOT EXISTS SANDBOX;
CREATE SCHEMA IF NOT EXISTS SANDBOX.TOOLS;
USE SCHEMA SANDBOX.TOOLS;

-- 임시 Stage 생성
CREATE OR REPLACE STAGE my_export_stage;

-- 워크스페이스 전체 파일을 Stage로 복사
COPY FILES INTO @my_export_stage
FROM 'snow://workspace/USER$.PUBLIC.DEFAULT$/versions/live';

LIST @my_export_stage;


