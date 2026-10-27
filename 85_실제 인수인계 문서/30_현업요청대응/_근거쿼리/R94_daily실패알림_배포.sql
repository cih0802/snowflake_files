-- doc_id: R94 · A8-10 "daily" Task 실패 알림 — 🔁 2026-10-27 정본 이관: 배포 SQL 은 08_mornitoring/09_OPS_dbt경고_이메일알림_구축.sql §7
-- 이력: 10-27 운영계 [2-a] 시험 호출 실패(query 01c800f8-0002-403c-0001-72de08680026 · 인덱스 1,2,4~8 불허)
--   원인 = category 인자를 'PIPELINE_ADMIN' 대신 'CHOIH' 로 호출 → 07 §4 send_alert 가 모르는 값에 필터를 안 걸어 활성 수신자 9명 전원 발송 → 미인증 7명으로 전체 실패.
--   조치 = ① 07 §3 PIPELINE_ADMIN_RECIPIENTS 변수(운영 CHOIH · 개발 TRIALADMIN) ② 07 §4 모르는 category 거부 ③ Alert 는 09 §7 로 이관.
--   별도 메일 프로시저(USP_SEND_DAILY_FAIL_MAIL)안은 폐기 — 수신자 관리가 07 표와 둘로 갈라지기 때문.
-- 운영계 실행 순서(GN_DW_ADMIN): 07 §3(수신자) → 07 §4 → 07 §6(GRANT 재부여) → 09 §7

-- 판정용 읽기 전용 확인 (09 §7 RESUME 뒤)
-- 감지 조건: 10-22~26 실패를 조건식이 잡는가(5행 기대 · 14일 내에만 유효)
SELECT SCHEDULED_TIME, COMPLETED_TIME, STATE
FROM TABLE(GN_DW.INFORMATION_SCHEMA.TASK_HISTORY(
       TASK_NAME => 'daily',
       SCHEDULED_TIME_RANGE_START => '2026-10-21 00:00:00 +0900'::TIMESTAMP_LTZ,
       ERROR_ONLY => TRUE))
WHERE DATABASE_NAME = 'GN_DW' AND SCHEMA_NAME = 'OPS';
-- 발송 이력: 시험 발송 SUCCESS 1행 이상
SELECT CREATED, INTEGRATION_NAME, STATUS, ERROR_MESSAGE
FROM TABLE(GN_DW.INFORMATION_SCHEMA.NOTIFICATION_HISTORY(START_TIME => DATEADD('day', -1, CURRENT_TIMESTAMP())))
ORDER BY CREATED;
