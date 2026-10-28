### ▣ O268-A-0 🔴 먼저 알아라

- `O268` = 선택 게이트 실패 처리 · 미결 3건 · 운영계 LLM 실행카드(2026-10-28 · TRIALADMIN · ZS83821 개발계 · ㉡).
- 🔴 운영계 반영은 **`문서실행순서_운영계_LLM실행카드.md` 1개로 한다**(43~58 · 블록 실행기 `scripts/run_sql_block.py` · dbt 는 👤).
- 🔴 개발계 라이브 미반영 2건(승인 대기 · `CREATE OR REPLACE` = R4-4-3) = `05_04_SV_DDL_SERVICE.sql`(템플릿 ID 질문 = `CLICK_MAP_MATCHED = 1`) · `05_13_SV_DDL_DEPT_AGGR.sql`(「통합」 제거). 소스는 고쳤다 — 운영계는 카드 44-4·56 이 집어간다.

### ▣ O268-A-1 결과 — 선택 게이트

| 게이트 | 원인(실측) | 처방 | 판정 |
|---|---|---|---|
| `sv_code_label_gate` | 무조각 900초 초과(rc=143) | `--shard k/n`(기반 테이블 단위) · `optional_gates.sh` 등록표 `sv_code_label_gate:8` · 조각 출력 파일 분리(마운트 append 미지원) | 8조각 완주 · 🔴 5 = 「통합」 1(실결함 · 소스 수정) + GA 채널·회원유형 4(개발계 표본 부재 · 운영계에서 재판정) |
| `comment_drift_gate` | 45 [D1]/[D1-C] 의 `CREATE TABLE IF NOT EXISTS` 가 컬럼 COMMENT 없이 생성 | `apply_table_comment_drift --apply`(29열+1표) · `apply_silver_comment_drift --apply`(7열) · SILVER 표 1문장 | rc=0 |
| `live_change_gate` | ZS83821 신규 구축(16시 KST · SV 43·Agent 3) 기록에 `REBUILD:ALL` 표지 누락 | O265 원장 행에 표지 보정 | rc=0 |
| `rename_stale_gate` | `30_output_share/_ENV/` 계정 측정 원문(as_of 복사물) | `SNAPSHOT` 버킷 편입(고치면 측정 위조) | rc=0 · 테스트 PASS |
| `sv_unit_gate` | ㉠ 단가 3(원/건) ㉡ 열거 리터럴 「'+100% 2배 증액'」 ㉢ Agent 종수 선언 요구 ↔ 결정 O250-C-4 충돌 | ㉠ `NOT_RATIO` 3 ㉡ `NUM_EXEMPT` 리터럴 면제(공백 경계) ㉢ 선언 부재 = 통과 · 선언 있으면 정합 계속 | rc=0 · 테스트 2종 갱신 PASS |
| `table_ddl_column_gate` | 파서 ㉠ `) CLUSTER BY` 종료 미인식(다음 블록까지 읽음) ㉡ `CREATE TABLE IF NOT EXISTS` 미인식 ㉢ seed 표 | 종료 = 첫 열0 `)` · 정규식 확장 · seed = ⚪ 대상 밖 | rc=0 |

### ▣ O268-A-2 결과 — 미결 3건

| 건 | 원인 | 처방 | 판정 |
|---|---|---|---|
| 중간 문장 노출 | Analyst 1차 SQL 이 물리명 `a.template_id` → invalid identifier → 재시도 사이 모델 문장 | AGENT_MEMBER orchestration 「재시도 무음」 + 논리 차원명 · 09_2 [0-B]→[0-C]→ADD VERSION = **VERSION$4** | 재실행 2문항 중간 문장 0 · 오류 0 |
| T1(14) ↔ T2(12) | T1 = 템플릿 수신자의 **모든** 클릭(MAP_MATCHED 미적용) · T2 = 같은 utm 을 쓴 템플릿 4종 수신자 클릭 | 05_04 (아) ①-a/b/c 규칙 · 정답 A = 9(O265 [D2-2] 일치) | 🟡 소스 수정 · 라이브 재배포 승인 대기 |
| CP949 csv | `line_len` UTF-8 고정 | `--encoding` 명시 인자(자동 추정 금지 · 손상 검출력 보존) | `--encoding cp949` PASS |

### ▣ O268-A-3 ㉠ 이 작업의 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 개발계 05_04·05_13 SV 재배포 → T1 재질문 = 9 확인 → `sv_code_label_gate --shard 0/8` 재실행 | R4-4-3 승인 대기 |
| ② | 👤 운영계 = 실행카드 43~58 | 사용자 |
| ③ | `01_세션이력` O268 항목 롤오버(`tmp/o268/history_O268.md`) | R4-4-3 승인 대기 |

### ▣ O268-A-4 🆕 새로 발견

- `run_sql_block.py` 음성 축 ④ 가 초판 결함을 실측으로 잡았다 — 문장 앞 표지 주석 때문에 `^\s*DELETE` 원천 쓰기 검사가 빗나갔다(주석 제거 후 검사로 시정).
- `sv_code_label_gate` 는 데이터 표본 계정(ZS83821)에서 GA 계열 「코드값 부재」를 낸다 — 운영계 판정이 정본이다.
- `SV_SERVICE.GA_CLICK_MAP_SRC` 열거는 「값:」 형식이라 게이트가 「주요 값」으로 읽지 못해 🟠 열거 누락으로 잡는다(advisory).

### ▣ O268-A-5 ㉡ 워크스페이스 백로그

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 기지 실패 2종(`test_mutating_tool_safety` run_sql_file · `test_pipeline_erd`) 결정 | 사용자 결정 |
| ② | 🟠 열거 누락 2(GA_CLICK_MAP_SRC 「값:」 형식 · EVENT_CATEGORY_NAME 19종) | 미착수 |
