# 운영도구 — SV 게이트 · SQL 실행기 · 접속 헬퍼 (O262 편입)

> 인수인계 사본 위치 = `10_운영도구_scripts/scripts/`. 모든 도구는 **자기 폴더 기준**으로 서로를 찾는다(폴더째 옮겨도 된다).

## 1. 접속 (`sfconn.py`)

| 환경 | 방법 |
|---|---|
| Snowsight 워크스페이스·컨테이너 | 토큰 파일(`SNOWFLAKE_TOKEN_FILE_PATH`, 기본 `/snowflake/session/token`)이 있으면 OAuth 로 자동 접속 |
| 로컬·운영 PC | `~/.snowflake/connections.toml` 에 항목을 만들고 `SNOWFLAKE_CONNECTION_NAME=<항목명>` |

- 역할·웨어하우스 덮어쓰기 = `GN_DW_ROLE` · `GN_DW_WAREHOUSE` 환경변수(미설정이면 각 도구의 기본값).
- 접속 확인 = `python3 sfconn.py` (현재 계정·역할·웨어하우스 출력).

## 2. 도구와 실행 순서

| 순 | 도구 | 대상 | 언제 |
|---|---|---|---|
| 1 | `sv_no_rollup_gate.py` | 소스(SV DDL 파일) | SV DDL 을 고친 뒤 · 배포 전 |
| 2 | `sv_common_block_gate.py` | 소스 + 라이브 | SV 지시문(AI_SQL_GENERATION)을 고친 뒤 · 배포 후 |
| 3 | `run_sql_file.py <파일.sql> --apply` | 라이브 | 배포 SQL 집행(문장 단위 · 첫 실패에서 멈춤) · 🆕 O270 `--apply` 없으면 dry-run(접속 없음 · 문장 목록만) |
| 4 | `sv_code_label_gate.py` | 라이브 | SV 배포 후 · 원천 코드값이 바뀐 뒤 |
| 5 | `sv_enum_newvalue_gate.py [--out 파일.csv]` | 라이브 | 정기 점검(월 1회 권장) · 원천 신규 값 유입 의심 시 |

- SV 폴더 자동 탐지 = `../../01_실행순서_배포SQL/05_SV-Agent_ai/`(사본) · 다르면 `--sv-dir <폴더>`.
- 사본에서 MSTR SV 정본(`15_MSTR 이관 PoC/…/05_MSTR_SV_DDL.sql`)이 없으면 그 파일만 🟠 건너뛴다.
- 접속 없이 사용법 확인 = 각 도구 `--help`.

## 3. 종료코드

| rc | 뜻 | 대응 |
|---|---|---|
| 0 | 통과 | — |
| 1 | 위반(또는 SQL 실패) | 출력된 파일:줄 / SV.차원 을 고치고 재실행 |
| 2 | 실행 오류 = **미판정** | 접속·권한·경로를 확인한다. 🔴 「위반 0」으로 읽지 마라 |
