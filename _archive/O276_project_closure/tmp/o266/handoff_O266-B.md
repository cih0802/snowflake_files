### ▣ O266-B-0 🔴 먼저 알아라

- `O266-B` = O266-A 후속(같은 날 2026-10-28 · TRIALADMIN · 개발계 ZS83821 · ㉡ 적용). O266-A 의 결과·근거는 그대로 유효하다.
- 🟢 사용자 dbt build 완료 → 개발계 45~52 **전부 반영**(46 [D2] 일치 · SV 3종 재배포 · `AGENT_MARKETING` VERSION$3 → **VERSION$4** · 라이브 = 정본 불일치 키 0).
- 게이트 = sv_identifier PASS(15초) · agent_object_ref PASS(5초) · line_len PASS · test_sv_enum_newvalue 실패 0 · 🔴 sv_enum_newvalue NEW 7(아래 B-3 · 기존 결손).
- 확정위반 0 · read 미반환 0.

### ▣ O266-B-1 결과

| 영역 | 결과 | 정본 좌표 |
|---|---|---|
| LTV 무기한 | 원인 = 관측 기간 < 상한인 셀은 무기한 창(관측 최대월)이 상한 창보다 **짧았다**(RMST 는 창에 단조 증가) ⇒ 무기한 = max(관측 최대월, 상한) 창 = 두 RMST 중 큰 값 · 모델·테이블 무변경 · SV 지표 2종 · 98셀 중 무기한 < 상한 0(종전 37) | `05_03` `EXP_TENURE_MONTHS_CAP`·`_UNLIMITED` · VQR · 규칙 O266 |
| 현업 안내 | 이전 = 무조건 관측 최대 기간 · 변경 = 관측 최대 기간 또는 상한(평균) 중 긴 쪽 · 예시 5그룹 · 해석 유의 | `98_현업요청인수인계/20261028_마케팅Agent_피드백_회신.md` |
| 제작비 사유 | 「제작비 세세목 정의가 없어 코드 기재 지출 전체 집계」를 COMMENT·규칙(5)에 명시 · 수치(약 99%) 제거(R2-6) · 라이브 COMMENT = 46 [D1-b] | `05_31` · `06_DDL` · `46` |
| 질문·답변 원천 | `CORTEX_AGENT_REQUEST`(EVENT)의 **VALUE** = `request_body`·`response` 전문 · 스레드 = `GET_AI_AGENT_MONITORING_DATA`(FIRST_INPUT·피드백) · ③ 에서 빠진 이유 = EVENT 행은 trace 접두 필터 밖 | `agent 사용 이력 조회.sql` ⑤⑥ |
| 게이트 분해 | `sv_enum_newvalue_gate` = 컬럼별 2회 전체 스캔 → 테이블당 2회(APPROX_COUNT_DISTINCT + ARRAY_UNIQUE_AGG) + `--shard k/n` · 세션 브리핑 4조각 순차 · 102/149/71/21초(종전 단일 300초 timeout · 6분+ 미완) | `scripts/sv_enum_newvalue_gate.py` · `scripts/session_brief.py` GATES |

### ▣ O266-B-2 ㉠ 이 작업의 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | Agent 로 피드백 4문항 재현(광고비+정산 · 캠페인 한 표 · 캠페인명 · LTV 6열) | 다음 |
| ② | 현업 회신 발송(안내문) · 제작비 세세목 목록 요청 | 사용자 |
| ③ | 운영계 반영 = 기존 환경 갱신 43~52(운영계 질문·답변 확인은 ⑤⑥ 쿼리) | ① 후 |
| ④ | 허브 색인 `split_doc.py 99_NEXT_SESSION.md --republish`(다중 파일 재작성 · 별도 승인) | 승인 대기 |
| ⑤ | 🟠 O265 잔여 = A 합 16 차 · SND GA 7,610 ↔ 4,893 · 현업 회신 3건 | 미착수 |

### ▣ O266-B-3 🆕 새로 발견

- 🔴 `sv_enum_newvalue_gate` NEW 7(처음으로 끝까지 판정됨 · 종전 timeout 으로 가려져 있었다):
  `SV_AD.CMPGN_TYPE1_BSN_NM`·`CMPGN_TYPE_BSN_NM` = `-`·`0`·`전체사업` · `SV_EXPENSE_RESOLUTION.DTL_ITEM_NM` = 업무추진비·운영비 ·
  `SV_GA_SESSION.DEVICE_OPERATING_SYSTEM` = PalmOS·UNIX · `SV_MSTR_SPNSR_DVLP.DEPT4_NM` 외 = 없음 — 결과 CSV = `tmp/sv_enum_newvalue_*of4.csv`
  ⇒ 처방 = 각 SV 소스 COMMENT 목록에 값 추가 후 재배포(`-`·`0` 은 원천 센티넬 여부 실측 후 결정 · R2-7).
- 🟠 상한보다 관측 기간이 짧은 셀의 상한·무기한 값은 마지막 유지율을 이어 쓴 가정값이다(안내문에 명시).
