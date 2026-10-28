## O266 — 마케팅 Agent 피드백 대응 · LTV 무기한 정정 · 열거 게이트 분해 · O265 잔여 규명 (2026-10-28 · TRIALADMIN · ZS83821 개발계)

- 단위 = O266-A(정산액·결합 팩트·SV·Agent 코드) · O266-B(build 후 배포 · LTV 무기한 · 제작비 COMMENT · 질문답변 원천 · 게이트 분해) · O266-C(NEW 7 처방 · Agent 4문항 · O265 잔여 · 허브) · O266-D(정리 · 다음 착수).
- ㉡ 적용(지시 동봉 즉시 수행) · 사용자 승인 = 재배포·GRANT·Agent 버전업·허브 갱신 등 전부. dbt build 는 사용자 실행(R4-1 준수 · 2회).
- 확정위반 1(유실 0) = R1-7-8 성격(보조주석 edit 앵커가 「바꾸지 않은 것」 1줄 삼킴 · 즉시 복원). read 미반환 0.
- 핵심 판정
  - 피드백 1 = 디지털 `LAST_STMT_AMT`(광고비+마크업+부가세) GOLD 미배선이 원인 · 영상·재방송은 정산 개념 컬럼 없음 ⇒ 디지털만 병기(결정 ㉠-b).
  - 피드백 2 = SV 3개로 나뉜 것이 원인 ⇒ `FACT_MKTG_CAMPAIGN_MONTHLY_COST` + `SV_MKTG_CAMPAIGN_COST`(결정 ㉡-a · 개발 = MSTR · dbt 롤 MSTR 읽기 = 00_mstr [4-b]).
  - 피드백 3 = Analyst CTE `mx` 관계 검증 실패(데이터 결손 아님) · 피드백 4 = LTV 답변 도구 0회 ⇒ Agent 규칙·VQR.
  - LTV 무기한 = 종전 「관측 최대월」 창이 상한보다 짧은 셀(37/98)에서 무기한 < 상한 ⇒ max(관측 최대월, 상한) 창(SV 지표 2종 · 모델 무변경).
  - 질문·답변 원문 = `CORTEX_AGENT_REQUEST`(EVENT) VALUE · 스레드 = `GET_AI_AGENT_MONITORING_DATA`.
  - `sv_enum_newvalue_gate` = 컬럼별 2회 스캔 → 테이블당 2회 + 4조각(102/149/71/21초) · 처음 끝까지 돌아 NEW 7 발견 → 처방 후 0.
  - O265 잔여 = SND 7,610↔4,893(귀속 대상 SND 전체 → 알림톡만 · 정의 변경) · A 16(GA 시작 직전 발송 경계 NULL) — 결함 아님.
- 근거 좌표 = `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0266-A~D.md` · `05_SV-Agent_ai/46_DEPLOY_AD_SETTLE_CAMPAIGN_COST.sql` · `45_…` [D2]·[D2-2] 주석 · `tmp/o266/agent_test/`.
