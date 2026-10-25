### ▣ O261-A-0 🔴 먼저 알아라

- `O261-A` = 새 개발계 UM80684 구축 직후 실측 (2026-10-24 · TRIALADMIN(UM80684) · ㉡ · 사용자 지시 「개발계 측정·적용·개선만」).
- 직전 단위 = `99_NEXT_SESSION-O0260-A.md` — 그 ㉠ ① 은 이 단위가 측정으로 닫았다 · ②③ 과 ㉡ 는 그대로 승계.
- 근거 정본 = `tmp/o261/evidence.md`(E1~E3 · 판정 전 기록) · 측정 도구 = `tmp/o261/*.py`.
- 같은 세션 앞 구간 = 문서실행순서 1~59 신규 구축(80 테이블 적재 · 👤 build PASS=735 WARN=25 ERROR=0 · SV 28+ML 7 · Agent 3 = VERSION$3).
- 신설 도구 = `scripts/run_sql_file.py`(`$$` 블록 인식 SQL 파일 실행기 · 🔴 `python3 -c` 로 `$$` 를 넘기면 셸이 PID 로 치환한다 · R1-7-9).

### ▣ O261-A-1 현재 작업 계정

| 항목 | 값 |
|---|---|
| 계정 | `UM80684`(새 개발계 · 트라이얼) · GN_DW 구축 완료(2026-10-23 PDT) |
| 역할 | 배포 DDL = `GN_DW_ADMIN` · dbt = `GN_DW_DBT` · 적재 = `ACCOUNTADMIN` |
| 이 단위의 라이브 판정 | 전부 이 계정 기준(evidence E1~E3) |

### ▣ O261-A-2 결과 (UM80684)

| 항목 | 결과 |
|---|---|
| 요건3 [D0] | BRONZE 새 이름 2건 실재 · 구 이름 0 |
| 요건3 [D1] | SILVER staging 이미 새 이름(08 DDL) ⇒ 건너뜀 |
| 요건3 [D0-b·c] | VIDEO.UPPER_CMPGN_CD 채움 6,801/47,838 · REBRDC.MKTG_CMPGN_NM 채움 286/2,190 · DIM 이름 일치 286/286 |
| 요건3 [D2] | 재방송 UPPER_CODE 1,809 = O245 기대값 일치 · 고아 0 · VIDEO 165행 차 = staging 전부-NULL 행 제외 |
| O259 확인 | 39 [D3] = CLEAN 1,314 · ACTIVE 223 · picker 폐기 0 · `sv_no_rollup_gate` PASS · 라이브 SV 44 실제 ROLLUP 0(금지 문구 제외) |
| SV COMMENT 대조 | 「실제값 N종」 139 · 일치 137 · 불일치 2(아래 ㉠ ①②) |

### ▣ O261-A-3 ㉠ 잔여 — 이 작업

| 순 | 작업 | 정지점 |
|---|---|---|
| ① | 🔴 GA4 하류 0행 복구 — SILVER BIGQUERY_BASIC·SESSION · GOLD FACT_BIGQUERY_BEHAVIOR·SESSION 전부 0 · 원천 최대 20261005 가 롤링 창(오늘-3일) 밖 ⇒ `02_dbt_parse_compile_build.sql:39` 범위 지정 build(개발계 = 백필 필요 · R2-9) → Step 3-3 일자 수 대조 → `enum_check.py` 재실행 | 👤 build |
| ② | SV_MEMBER_SPONSOR_BIZ `MAP_METHOD` COMMENT 「실제값 8종」 문안 — MANUAL·MANUAL_UNMAPPED 는 seed 0행이라 라이브 6종 · 「가능값 8종(현재 6종 · MANUAL 계열은 seed 입력 시)」 식으로 고칠지 | 👤 승인 |
| ③ | 사용자 결정(O260 ㉠ ② 승계) — REBRDC MKTG_CMPGN_NM 코어 승격 여부 · 근거 = 채움 13.1% · 이름 일치 100% | 👤 결정 |

- 🔴 GA4 공백은 무증상이었다(build ERROR 0) — 개발계 신규 구축 절차에 범위 지정 build 를 필수로 넣을지 검토 대상.

### ▣ O261-A-4 ㉡ 워크스페이스 백로그 (승계)

- O260-A-3 ③(80 패키지 재빌드 · 👤 승인) 그대로.
- O259-A-3 ③④ · O259-A-4 · O258-A-2 ① · O258-A-3 그대로(운영계·현업).
