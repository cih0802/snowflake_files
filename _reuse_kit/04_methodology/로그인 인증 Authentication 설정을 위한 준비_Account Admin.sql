-- Strong Authentication 준비를 위한 사용자 설정 쿼리
-- Co-authored with CoCo

-- 1단계: 사용자 타입 설정 (Human 사용자는 PERSON, 서비스 계정은 SERVICE로 설정)
-- 현재 TRIALADMIN은 사람 사용자이므로 TYPE=PERSON으로 설정
ALTER USER TRIALADMIN SET TYPE = PERSON;

-- 2단계: MFA를 필수로 요구하는 인증 정책 생성
CREATE OR REPLACE AUTHENTICATION POLICY require_mfa_policy
  MFA_ENROLLMENT = 'REQUIRED';

-- 3단계: 계정 전체에 인증 정책 적용
ALTER ACCOUNT SET AUTHENTICATION POLICY = require_mfa_policy;

-- (참고) 서비스 사용자가 있는 경우, 비밀번호 대신 키페어 인증으로 전환 필요:
-- ALTER USER <service_user> SET TYPE = SERVICE;
-- ALTER USER <service_user> SET RSA_PUBLIC_KEY = '<public_key_value>';

-- (참고) 정책 적용 후 사용자가 다음 로그인 시 MFA 등록 화면이 표시됩니다.
