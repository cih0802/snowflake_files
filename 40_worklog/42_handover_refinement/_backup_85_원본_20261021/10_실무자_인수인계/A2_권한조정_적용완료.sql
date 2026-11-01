-- 🟢 적용 완료 — 2026-10-20 O247 · 개발계 IW20760 · GN_DW_ADMIN(선행 권한 ACCOUNTADMIN) · [1] VIEWER·SERVICE SELECT · [2] 90일 접근 0 확인 후 ANALYST OPS 회수 · 운영계는 [2] 앞 확인 SELECT 부터
-- doc_id: A2-ADJ · as_of: 2026-10-20 · 🔴 미실행 · 목적: 2026-10-20 사용자 결정 2건 권한 조정 + 롤백 · 설명: A2_롤별_접근권한_매트릭스.md §7 · A8-07·A8-08
-- 🔴 개발계·운영계 모두 승인 후 실행한다. 실행 롤 = GN_DW_ADMIN(객체 소유자).
-- 🔴 원본(80번) 배포 SQL 은 고치지 않는다 ⇒ 아래 「재실행 함정」을 지켜야 결정이 유지된다.

USE ROLE GN_DW_ADMIN;

-- =====================================================================
-- [1] 결정 A8-07 — 시뮬레이터 base 뷰를 VIEWER·SERVICE 에도 연다 (SV·Agent 배선과 정합)
-- =====================================================================
GRANT SELECT ON VIEW GN_DW.SERVING.ML_REALTIME_SIMULATOR_V TO ROLE GN_DW_VIEWER;
GRANT SELECT ON VIEW GN_DW.SERVING.ML_REALTIME_SIMULATOR_V TO ROLE GN_DW_SERVICE;
SHOW GRANTS ON VIEW GN_DW.SERVING.ML_REALTIME_SIMULATOR_V;          -- 기대: SELECT = ADMIN·ENGINEER·ANALYST·VIEWER·SERVICE
-- ⚠️ base 뷰 SELECT 만으로 시뮬레이터 전체가 동작하는지는 미확인이다 —
--    24_ML_REALTIME_SIMULATOR_DDL 의 프로시저 SP_SIMULATE_CAMPAIGN_DVLP USAGE 는 ANALYST 만 있다(A2 설계 csv).
--    VIEWER 계정으로 Agent 시뮬레이터 질문 1회를 실행해 확인한다(운영계 · VIEWER 사용자 필요).
-- 재실행 함정: 24_ML_REALTIME_SIMULATOR_DDL.sql 을 다시 돌리면 CREATE OR REPLACE VIEW 로 이 2건이 사라진다 ⇒ 그 뒤 [1] 재실행.

-- [1-R] 롤백
-- REVOKE SELECT ON VIEW GN_DW.SERVING.ML_REALTIME_SIMULATOR_V FROM ROLE GN_DW_VIEWER;
-- REVOKE SELECT ON VIEW GN_DW.SERVING.ML_REALTIME_SIMULATOR_V FROM ROLE GN_DW_SERVICE;

-- =====================================================================
-- [2] 결정 A8-08 — ANALYST 의 OPS 접근 회수 (OPS COMMENT「소비 역할 권한 없음」과 정합)
--     근거(2026-10-20 개발계 실측): OPS 객체를 참조하는 SV·뷰·Agent 0건(OBJECT_DEPENDENCIES) ·
--     최근 30일 ANALYST 의 OPS 접근 0건(ACCESS_HISTORY · 단 개발계 ANALYST 사용자 0명) ·
--     부여 출처 07_OPS_알림 :334·:338 에 사유 기재 없음. 알림 「수신」은 표의 IS_ANALYST_YN 플래그로 하며 표 SELECT 권한과 무관.
-- =====================================================================
-- 운영계 실행 전 확인: 최근 90일 ANALYST 의 OPS 접근이 0 인지
SELECT COUNT(*) AS N_ACCESS
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY a, LATERAL FLATTEN(a.BASE_OBJECTS_ACCESSED) f
WHERE a.QUERY_START_TIME > DATEADD(day, -90, CURRENT_TIMESTAMP())
  AND f.value:objectName::STRING ILIKE 'GN_DW.OPS.%'
  AND a.QUERY_ID IN (SELECT QUERY_ID FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
                     WHERE ROLE_NAME = 'GN_DW_ANALYST'
                       AND START_TIME > DATEADD(day, -90, CURRENT_TIMESTAMP()));

REVOKE SELECT ON TABLE GN_DW.OPS.ALERT_RECIPIENT_CONFIG FROM ROLE GN_DW_ANALYST;
REVOKE USAGE ON SCHEMA GN_DW.OPS FROM ROLE GN_DW_ANALYST;
SHOW GRANTS ON SCHEMA GN_DW.OPS;                                    -- 기대: ANALYST 행 없음
-- ⚠️ ADMIN 은 ANALYST 를 상속하지만 OPS 소유자라 영향 없다. VIEWER 는 원래 OPS 권한이 없다.
-- 재실행 함정: 🟢 해소(2026-10-20) — 07_OPS_알림 원본·80번 사본 2개·tmp 스냅샷의 ANALYST GRANT 2줄을 주석 처리했다
--    ⇒ 원본을 다시 돌려도 ANALYST 권한이 되살아나지 않는다. 이 [2] 는 이미 부여된 계정(개발계·운영계)에서 회수만 한다.

-- [2-R] 롤백
-- GRANT USAGE ON SCHEMA GN_DW.OPS TO ROLE GN_DW_ANALYST;
-- GRANT SELECT ON TABLE GN_DW.OPS.ALERT_RECIPIENT_CONFIG TO ROLE GN_DW_ANALYST;

-- =====================================================================
-- [3] 반영 확인 — 설계 csv 갱신 후 매트릭스 재생성(사람 실행)
-- =====================================================================
-- python3 scripts/env_capture.py --id A2 "85_실제 인수인계 문서/10_실무자_인수인계/A2_롤별_접근권한_근거.sql"
-- python3 scripts/a2_matrix_build.py <CURRENT_ACCOUNT>
--   기대: VIEWER·SERVICE SERVING 뷰 19/19 OK · 설계외부여 0 · ANALYST OPS 행 없음
