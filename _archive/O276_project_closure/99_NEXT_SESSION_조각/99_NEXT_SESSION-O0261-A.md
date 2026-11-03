<!-- LLM-METADATA
doc_id: HANDOFF_O0261_A
doc_role: 인수인계 — 세션 `O261-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-24
created_by: O261-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0261-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
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
| ~~①~~ | ~~GA4 하류 0행 복구~~ ➔ 🟢 👤 범위 build 완료 · 원천·BASIC·FACT 34일 일치(evidence E4) | 종결 |
| ~~②~~ | ~~SV COMMENT 문안 2건~~ ➔ 🟢 사용자 승인 「종 수 폐지 · 신규값 목록 반영」 · 148건 치환 · 신규값 10 · 라이브 STALE 0 · NEW 0(evidence E5) | 종결 |
| ~~③~~ | ~~REBRDC 승격~~ ➔ 🟢 👤 build 완료 · NAME 286 · UPPER_CODE 1,808 · NONE 96 · 다른 캠페인 0(evidence E4) | 종결 |
| ④ | ✅ 완료(2026-10-24) — `scripts/sv_enum_newvalue_gate.py`(JUDGE · `new_tool.py` 등재) + 음성 `scripts/test_sv_enum_newvalue_gate.py`(12축 · 변이 구현 FAIL 실증 2회) + `session_brief` GATES 편입. 운영 규칙 = 게이트 ❌ NEW 시 해당 SV 소스 COMMENT 목록에 값 추가 후 재배포 · 종 수는 적지 않는다(「값 N종」 변형도 STALE). 부수: `run_sql_file` MUTATES 등재(census PASS) | ✅ |
| ~~⑥~~ | ~~검토거리(사용자 승인 「전부」)~~ ➔ 🟢 종결(evidence E6) — 범위 build 필수화(개발계·신규 · 운영계 R2-9 제외 · Step 3-3 정지점 공통) · 열거 보강 253 + 정규화 15 + 변형 종 수 18 · 🔴 `sv_code_label_gate` 「주요 값」 미인식 회귀 시정(109 차원 검사 복귀) · MAP_METHOD seed 의존 값 분리 · 🔴 `34_` → 22·25 정본 이식(신규 구축 각주 누락 결함) · 색인 밀도 축소(35,195 → 21,507 B) · `11_O누적작업` 폴더 분할 · jinja 축5 0 | 종결 |
| ⑤ | 운영계 반영 = 문서실행순서 「기존 환경 갱신」 37(👤 `build --select AGENCY_AD_PERFORMANCE+`) → 38(SV 34파일 · 순서 = 05_01~05_30 → 22 → 23 → 24 → 25 → 34 → MSTR 05) · 확인 = 게이트 3종 rc=0 · 🔴 운영계 원천 값이 다르면 `sv_enum_newvalue_gate` NEW → COMMENT 추가 | 👤 운영계 |

- 🟢 라이브(UM80684 · 최종) = `sv_code_label_gate` 🔴 0 · 🟠 1(`SV_EVENT_PARTICIPATION.EVENT_CATEGORY_NAME` — 값 1개에 따옴표 `I'm your pen` 이라 게이트가 산문 나열을 못 읽는다 · 정보는 COMMENT 에 있음 · 별건) · 열거 누락 413 → 1 · `sv_enum_newvalue_gate` 대조 차원 422 · STALE 0 · NEW 0 · `sv_no_rollup_gate` PASS · `sv_identifier_gate` blocking 0.
- 🟢 유지 연산(사용자 승인) = 원장 `--rebalance`(여유 36 B → 최소 12,409 B · PASS) · 99_NEXT·01_세션이력 허브 `--republish` PASS · 색인 재생성 · 80 재빌드(542파일 · MISSING 0 · 비운영 계정 값 0 · 실행순서 경로 2줄 = 「05_01~05_NN」이 경로로 오인돼 MISSING 2 → 실파일명으로 교정).
- 🔴 80 재빌드 1차에서 새 개발계 `UM80684` 가 사본에 남았다 — 스크럽 목록 `95_작업기록_인수인계정제/tools/scrub_acct.ACC` 에 없었다 ⇒ 편입 후 재빌드 0. **새 계정이 생기면 이 목록에 먼저 넣는다.**
- 🟠 80 패키지 MANIFEST 에 `scripts/`(게이트·`run_sql_file.py`)가 없다 — 문서실행순서 §3.7 이 이름으로 가리키지만 80 사본만 받은 담당자는 못 쓴다(워크스페이스 `sfconn` 의존 · 포함 여부 = 👤 결정).

### ▣ O261-A-4 ㉡ 워크스페이스 백로그 (승계 · 2026-10-25 재점검)

- ~~O260-A-3 ③ 80 패키지 재빌드~~ ➔ 🟢 사용자 승인 · 집행(O261 마지막 단계).
- ~~O260-A-3 ① · ②㉠~~ · ~~O259-A-3 ①②~~ · ~~O258-A-2 ②~~ ➔ 🟢 O261 이 측정·적용으로 닫았다(E1~E6).
- ~~O258-A-3 jinja 축5 경고 1~~ ➔ 🟢 0.
- 남음 = O260-A-3 ②㉡ 코어 `UPPER_CAMPAIGN_NM` 개명(👤 결정) · O259-A-3 ③④(운영계·현업) · O259-A-4 SV 6종 공통 블록(별건) · O256-B-2(운영계·현업).
- 👤 dbt 확인 1건 = `FACT_MEMBER_COHORT_SURVIVAL` Jinja 주석 1줄 수정(출력 무변경) — 다음 build 때 `parse` 통과만 보면 된다.

_Co-authored with CoCo_
