-- MFA 신규 등록 / 재등록 런북 — 패스키 막힘 복구 포함
-- Co-authored with CoCo
-- =====================================================================
-- 문서 목적 / PURPOSE
--   웹 로그인 시 패스키(WebAuthn) 팝업에서 막혀 진행이 불가한 사용자를
--   (1) 즉시 로그인시키고 (2) 인증 앱(TOTP)으로 MFA를 새로 등록시킨다.
--   패스키가 이미 등록돼 있어 재등록이 필요한 경우도 5단계에서 다룬다.
--
-- 배경 / WHY
--   2024_08 번들 이후 생성된 계정은 **비밀번호를 쓰는 사람(PERSON) 사용자에게
--   MFA 등록이 기본 필수**다. 즉 "어제는 됐는데 오늘 막혔다"는 로그인 실패가 아니라
--   대개 **등록 미완료** 상태다. DESC USER 의 HAS_MFA = false 로 구분한다.
--
--   패스키는 브라우저·Windows Hello·블루투스(BLE)에 의존한다.
--   '휴대폰 또는 태블릿 사용'(교차 기기 패스키)은 QR + 블루투스가 **둘 다** 필요하므로
--   블루투스 없는 데스크톱에서는 실패한다. ⇒ 이런 환경에서는 TOTP 를 쓴다.
--
-- 실행 방법 / HOW TO RUN
--   웹 로그인이 막힌 상태이므로 **CLI 연결로 실행**한다(브라우저 불필요).
--     snow sql -c <CONNECTION> -q "<아래 각 문장>"
--   또는 파일째로:
--     snow sql -c <CONNECTION> -f mfa_setup.sql
--   ⚠️ 대용량 업로드(snow stage copy)가 도는 창에서 실행하지 말 것.
--      새 터미널 창에서 실행하면 별개 연결이라 업로드에 영향이 없다.
--
-- 권한 / PRIVILEGES
--   타인의 MFA 속성 변경은 관리자 권한이 필요하다.
--   ACCOUNTADMIN, 또는 대상 사용자에 OWNERSHIP 을 가진 역할(보통 USERADMIN)로 실행한다.
--   본인 스스로는 MINS_TO_BYPASS_MFA 를 설정할 수 없다(그러면 MFA 가 무의미해지므로).
--
-- 🔴 절대 하지 말 것
--   ALTER USER ... SET DISABLE_MFA = TRUE
--     → MFA 를 **영구 무력화**한다. 임시 복구 목적이라면 2단계의
--       MINS_TO_BYPASS_MFA(자동 만료)를 쓴다. 아래 7단계 참조.
--
-- 참고 문서
--   Multi-factor authentication (MFA) https://docs.snowflake.com/en/user-guide/security-mfa
--   ALTER USER                        https://docs.snowflake.com/en/sql-reference/sql/alter-user
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. 대상 확인 — 아래 결과의 U 값을 이후 <USERNAME> 자리에 그대로 쓴다
-- ---------------------------------------------------------------------
SELECT CURRENT_USER()    AS u,
       CURRENT_ACCOUNT() AS locator,
       CURRENT_ROLE()    AS r;

-- 관리자 역할이 아니면 전환한다(권한이 있는 경우)
-- USE ROLE ACCOUNTADMIN;


-- ---------------------------------------------------------------------
-- 1. 진단 — 여기서 원인이 갈린다. 반드시 먼저 읽는다.
-- ---------------------------------------------------------------------

-- 1.1 사용자 상태
--   확인 포인트:
--     HAS_MFA            false → 미등록(등록 강제 화면에서 막힌 것) / true → 이미 등록됨(재등록은 5단계)
--     DEFAULT_MFA_METHOD 기본 방식. PASSKEY 로 잡혀 있으면 매번 패스키가 먼저 뜬다
--     LOCK_DETAILS       isMfaLocked / isMfaTOTPLocked 가 true 면 잠김 → 3단계
--     IS_EMAIL_VERIFIED  true → 4-B 이메일 등록 링크 사용 가능
--     TYPE               PERSON(또는 null) 이어야 MFA 등록 요구 대상이다
--     DISABLED           true 면 MFA 문제가 아니라 계정 비활성이다
DESC USER <USERNAME>;

-- 1.2 등록된 MFA 수단 목록 (0행이면 미등록)
--   재등록(5단계) 때 REMOVE 에 쓸 **method 이름**을 여기서 확보한다.
SHOW MFA METHODS FOR USER <USERNAME>;

-- 1.3 🔴 가장 중요 — 인증 정책이 방식을 제한하는지 확인
--   0행이면 정책 없음 ⇒ 기본값이므로 PASSKEY·TOTP·DUO 모두 선택 가능(TOTP 로 가면 된다).
--   정책이 있으면 1.4 로 내려가 MFA_POLICY 를 확인한다.
SHOW AUTHENTICATION POLICIES IN ACCOUNT;

-- 1.4 정책이 있을 때만 실행 — ALLOWED_METHODS 에 TOTP 가 빠져 있으면
--     "인증 앱" 선택지가 화면에 아예 안 나온다. 그게 패스키를 강요당하는 진짜 원인이다.
--     MFA_ENROLLMENT 값('REQUIRED' | 'REQUIRED_PASSWORD_ONLY' | 'OPTIONAL')도 같이 본다.
-- DESC AUTHENTICATION POLICY <POLICY_NAME>;


-- ---------------------------------------------------------------------
-- 2. 즉시 로그인 확보 — MFA 임시 우회 (권장 복구 경로)
-- ---------------------------------------------------------------------
--   60분간 비밀번호만으로 웹 로그인이 된다. **자동 만료**되므로 되돌릴 작업이 없다.
--   이 창으로 로그인한 뒤 4단계에서 TOTP 를 여유 있게 등록한다.
ALTER USER <USERNAME> SET MINS_TO_BYPASS_MFA = 60;

-- 적용 확인 (MINS_TO_BYPASS_MFA 가 60 근처로 보이면 성공. 시간이 지나면 값이 줄어든다)
DESC USER <USERNAME>;

-- 우회를 조기에 회수하려면 0 으로 설정한다(등록 완료 후 8단계에서 실행)
-- ALTER USER <USERNAME> SET MINS_TO_BYPASS_MFA = 0;


-- ---------------------------------------------------------------------
-- 3. 잠긴 경우만 — 1.1 의 LOCK_DETAILS 에 isMfaLocked=true 였을 때
-- ---------------------------------------------------------------------
--   MFA 실패 누적으로 걸린 임시 잠금은 시간이 지나면 자동 해제된다.
--   즉시 풀어야 하면 잠금 해제 대기시간을 0 으로 만든다.
-- ALTER USER <USERNAME> SET MINS_TO_UNLOCK = 0;


-- ---------------------------------------------------------------------
-- 4. MFA 등록 — 두 경로 중 하나. 4-A 를 우선한다.
-- ---------------------------------------------------------------------

-- 4-A (권장) 화면에서 직접 등록 — 2단계 우회로 로그인한 상태에서
--   ① 브라우저 **시크릿 창**으로 접속한다
--      (저장된 패스키 자동 제안을 차단해야 팝업이 안 뜬다. 일반 창이면 계속 가로챈다)
--   ② 패스키 팝업이 뜨면 Esc 또는 '취소'
--   ③ 우하단 사용자 이름 » Settings » Authentication
--   ④ Multi-factor authentication » **Authenticator app** 추가
--   ⑤ QR 코드를 인증 앱으로 스캔 (Google/Microsoft Authenticator, 1Password 등)
--   ⑥ 6자리 코드 입력 → 등록 완료
--   ⇒ TOTP 는 블루투스·Windows Hello 를 쓰지 않으므로 지금 막힌 원인을 우회한다.

-- 4-B 화면 진행조차 안 될 때 — 관리자가 등록 절차를 발송
--   동작이 이메일 인증 여부로 갈린다:
--     IS_EMAIL_VERIFIED = true  → 사용자 EMAIL 주소로 등록 링크 **메일 발송**
--     IS_EMAIL_VERIFIED = false → 등록 페이지 **URL 을 명령 결과로 반환**
--                                 (관리자가 메신저 등 아무 수단으로 전달 가능)
--   ⚠️ 링크는 항상 그 사용자 계정에 등록된 **본인 EMAIL** 로만 간다.
--      임의의 제3의 주소로 돌릴 수 없다. 주소를 바꾸려면 아래처럼 EMAIL 을 변경하되,
--      새 주소는 미인증 상태가 되므로 그다음부터는 메일이 아니라 URL 이 반환된다.
-- ALTER USER <USERNAME> SET EMAIL = 'someone@example.com';
ALTER USER <USERNAME> ENROLL MFA;


-- ---------------------------------------------------------------------
-- 5. 재등록 — 기존 패스키를 버리고 새로 등록할 때만
-- ---------------------------------------------------------------------
--   <METHOD_NAME> 은 1.2 SHOW MFA METHODS 결과의 이름을 그대로 쓴다.
--   🔴 순서 주의: 반드시 **새 수단(TOTP)을 먼저 등록**하고 나서 기존 것을 제거한다.
--      마지막 남은 수단을 먼저 지우면 등록 강제 화면으로 되돌아가 다시 막힌다.
-- ALTER USER <USERNAME> REMOVE MFA METHOD <METHOD_NAME>;

-- 기본 방식을 TOTP 로 바꾼다 → 로그인 시 패스키가 먼저 뜨지 않는다
--   (이 문장은 해당 수단이 이미 등록된 뒤에 의미가 있다)
ALTER USER <USERNAME> SET DEFAULT_MFA_METHOD = TOTP;

-- 수단에 메모를 남겨 구분하기 (선택)
-- ALTER USER <USERNAME> MODIFY MFA METHOD <METHOD_NAME> SET COMMENT = 'work laptop TOTP';


-- ---------------------------------------------------------------------
-- 6. 복구용 일회성 코드(OTP) 발급 — 선택, 재발 방지에 유용
-- ---------------------------------------------------------------------
--   휴대폰 분실·앱 초기화로 또 막히는 상황을 대비한 일회용 코드다.
--   결과로 나온 코드를 사용자에게 안전한 경로로 전달하고 보관하게 한다.
-- ALTER USER <USERNAME> ADD MFA METHOD OTP COUNT = 5;


-- ---------------------------------------------------------------------
-- 7. 정책 조정 — 1.4 에서 TOTP 가 막혀 있었던 경우에만
-- ---------------------------------------------------------------------
--   ALLOWED_METHODS 지정 가능 값: 'ALL' | 'PASSKEY' | 'TOTP' | 'OTP' | 'DUO'
--   패스키만 허용돼 있었다면 TOTP 를 함께 허용한다.
-- ALTER AUTHENTICATION POLICY <POLICY_NAME>
--   SET MFA_POLICY = ( ALLOWED_METHODS = ( 'PASSKEY', 'TOTP' ) );

--   MFA 등록 강제 자체를 풀어야 할 때(권장하지 않음, 보안 저하).
--   MFA_ENROLLMENT 값: 'REQUIRED' | 'REQUIRED_PASSWORD_ONLY' | 'OPTIONAL'
-- ALTER AUTHENTICATION POLICY <POLICY_NAME> SET MFA_ENROLLMENT = 'OPTIONAL';

--   정책이 아예 없는 계정에서 MFA 강제를 끄고 싶다면 정책을 만들어 계정에 붙인다.
--   🔴 계정 전체에 영향을 준다. 트라이얼·개인 계정 외에는 쓰지 말 것.
-- CREATE AUTHENTICATION POLICY mfa_optional_policy
--   MFA_ENROLLMENT = 'OPTIONAL'
--   COMMENT = 'temporary: relax MFA enrollment';
-- ALTER ACCOUNT SET AUTHENTICATION POLICY mfa_optional_policy;
-- ALTER ACCOUNT UNSET AUTHENTICATION POLICY;   -- 원복


-- ---------------------------------------------------------------------
-- 8. 검증 및 정리 (등록 완료 후 반드시 실행)
-- ---------------------------------------------------------------------

-- 8.1 등록 확인 — 1행 이상 나와야 한다
SHOW MFA METHODS FOR USER <USERNAME>;

-- 8.2 속성 확인 — HAS_MFA = true, DEFAULT_MFA_METHOD = TOTP 를 기대한다
DESC USER <USERNAME>;

-- 8.3 🔴 임시 우회 회수 — 2단계를 실행했다면 반드시 0 으로 되돌린다
--     (60분 뒤 자동 만료되지만, 등록이 끝났으면 즉시 닫는 것이 맞다)
ALTER USER <USERNAME> SET MINS_TO_BYPASS_MFA = 0;

-- 8.4 최종 확인 — 시크릿 창에서 로그아웃 후 재로그인해
--     인증 앱 6자리 코드로 통과되는지 실제로 확인한다.
--     여기까지 통과하면 복구 완료다.
