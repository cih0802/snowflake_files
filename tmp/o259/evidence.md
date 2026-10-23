# O259 근거 (R1-3-7-c · 판정 전 기록)

- 환경 = 개발계 SR61467 · TRIALADMIN · ACCOUNTADMIN · 2026-10-23
- 라벨 = `id_collision_gate.py --next O` → 「O 최대 = 정의 196 · 참조 258 ⇒ 다음 발급 = O259」(rc=0)
- DEC = 「DEC 최대 = 정의 36 · 참조 63 ⇒ 다음 발급 = DEC64」(rc=0 · 미발급 — 아래 D1 확정 시 발급)

## E1. 요건 3 — 개발계 BRONZE 원천 개명 미반영 (INFORMATION_SCHEMA.COLUMNS)

| TABLE_NAME | COLUMN_NAME | COMMENT |
|---|---|---|
| REBRDC_AD_CMPGN_DTLS | CMPGN_CD | 캠페인코드 |
| REBRDC_AD_CMPGN_DTLS | UPPER_CMPGN_CD | 상위캠페인코드 |
| VIDEO_AD_CMPGN_DTLS | UPPER_CMPGN_NM | 상위캠페인 |

- 신규 컬럼 `VIDEO.UPPER_CMPGN_CD` · `REBRDC.MKTG_CMPGN_NM` 부재 ⇒ D4 에 따라 코드 변경 보류.

## E2. 요건 2 — ROLLUP 유도 문구 전수(python 스캔 · `_archive` 제외)

- 치환 전 = 78줄 · 36파일(`tmp/o259/scan_rollup.py` · rc=0).
- 치환 스크립트 `tmp/o259/apply_no_rollup.py` 기대 건수 전건 OK(R1 31 · R2 5 · R4 6 · R5 7 · VQR 12 등) → 29파일.
- 2차 `tmp/o259/apply_total_column.py`(O241-T 1회 호출 원칙과 정합 · 전체 합 = 열) → 31파일.
- Agent 정본 3종 `apply_agent_spec.py` A1 3 · A2 3 · A3 2.
- 게이트 `sv_no_rollup_gate` = 「🟢 PASS — 소계/합계 행 유도 0건 · 분모 34 파일」 · 음성 테스트 FAIL 0.
- 분모 밖(Agent 출력 아님) = 26~29 운영자 점검 SQL · 37 주석 · `04_SV_설계.md` · `08_AGENT_spec.md`(이력 사본).

## E3. 요건 1 — 렌더 대조(dbt 미실행 · `tmp/o259/compare.sql` · TEMP 테이블)

| K | N |
|---|---|
| DIM_ORG new-old | 0 |
| DIM_ORG old-new | 0 |
| DIM_ORG rows new / old | 1315 / 1315 |
| SUCC new-old | 0 |
| SUCC old-new | 0 |
| SUCC rows new | 1314 |
| CLEAN rows | 1314 |
| CLEAN ACTIVE | 223 |
| RR SELF_USE_YN | 764 |
| RR SELF_LAST_UPDT | 260 |
| RR UPPER_RETIRED | 67 |
| UPPER_CUR filled | 629 |

- 판정: Gold 슬림화는 출력 무변경(메타 4컬럼 제외 전 컬럼 MINUS 0). D1(활성 트리 단일화)은 현 Gold 규칙과 동일하므로 바뀌는 행 0.

## E4. 개발계 DDL 적용 (39_DEPLOY_SILVER_ORG_CLEAN.sql 전체 · 2026-10-23)

| TABLE_NAME | TABLE_TYPE | TABLE_OWNER | ROW_COUNT |
|---|---|---|---|
| CRM_ORG_CLEAN | BASE TABLE | GN_DW_ADMIN | 0 |
| CRM_ORG_SUCCESSION | BASE TABLE | GN_DW_ADMIN | 0 |
| V_ORG_PICKER | VIEW | GN_DW_ADMIN | NULL |

- SILVER FUTURE GRANTS = TABLE(DBT SELECT·INSERT·DELETE·TRUNCATE · ANALYST/ENGINEER SELECT) · VIEW(ANALYST/ENGINEER SELECT).
- 잔여 = 👤 dbt build → [D3] 재실행(기대 CLEAN 1,314 · ACTIVE 223 · SUCC 1,314 · PICKER_RETIRED 0).

## E5. 👤 build 후 라이브 대사 (사용자 보고 PASS=35 WARN=0 ERROR=0 SKIP=0 TOTAL=35 · 2026-10-23)

| K | N |
|---|---|
| CLEAN / CLEAN_ACTIVE | 1314 / 223 |
| SUCC | 1314 |
| PICKER / PICKER_RETIRED | 223 / 0 |
| DIM_ORG / DIM_ORG_ACTIVE | 1315 / 223 |
| DIM_SUCC | 1314 |
| GOLD_vs_SILVER_ACTIVE_DIFF | 0 |
| SUCC_CUR_DIFF | 0 |
| MAP SELF · AUTO_NAME · AUTO_MEMBER_FLOW · AUTO_ACMSLT_PARENT · AUTO_ORG_PARENT · UNMAPPED | 223 · 109 · 72 · 135 · 222 · 553 |

- 판정: 요건 1 개발계 완료(SR61467 · 2026-10-23). Gold 출력은 E3 렌더 대조로 무변경 ⇒ 연결률(O252 기준)도 불변.

## E6. SV·Agent 재배포 (사용자 승인 「전부 승인」 · SR61467 · 2026-10-23)

- SV 재배포 = 05_01~05_26 → 22 → 25 → 34 → MSTR `05_MSTR_SV_DDL.sql`(전건 성공).
- 1차 라이브 스캔(GET_DDL · 44 SV) = 「SV=44 O259=37 ROLLUP_LEFT=1 [SV_MSTR_SPNSR_DVLP ]」 ⇒ MSTR 정본이 05 폴더 밖 → 개정 + gate 분모 편입(35).
- 2차 = 「SV=44 O259=38 ROLLUP_LEFT=0 []」 · O259 미포함 6종은 O206-C 블록 자체가 없음.
- Agent 스테이지 대조 = EXECUTIVE 91360/91360 · MARKETING 118624/118624 · MEMBER 136896/136896 · 전건 OK.
- default 버전 = MEMBER VERSION$6 · EXECUTIVE VERSION$6 · MARKETING VERSION$7.
- Analyst 재질의(SV_CAMPAIGN_CUM_STOP · SV_CAMPAIGN_MONTHLY · SV_MEMBER_SPONSOR_BIZ) = 3/3 `GROUP BY <차원>` 평면 · ROLLUP/GROUPING SETS/CUBE 0.

## E7. 세션 정리 (사용자 승인 · SR61467 · 2026-10-23 · 계정 결제수단 정지 없음 = 전 단계 완료)

- rollover = `01_세션이력` 「O259」 · 문서50 「🟡 O259-1」 · 두 건 🟢 PASS(본문 바이트 동일 · 유실 0 · 상한 초과 0).
- `gen_measure_backlog --write` rc=0 · 음성 테스트 전건 = 1차 FAIL 2(`test_gate_census` · `test_tool_registration` · 원인 = `sv_no_rollup_gate` 가 `gate_census` 미분류) → JUDGE 등재 후 11/11 · 전건 통과.
- 선택 게이트 13종(`sh scripts/optional_gates.sh` · 「OPTIONAL_GATES_DONE fail=5」):

| 게이트 | rc | 판정 · O259 관련 |
|---|---|---|
| comment_drift · decision_closure · doc_line_length · handoff_ddl · rename_stale · stage_mount_size · sv_comment_object · wide_select_yml | 0 | PASS |
| gold_erd_coverage | 1 | 미분류 6 = `FACT_AD_INFLOW_ALLOC`(O248) 등 · O259 무관 |
| live_change | 1 | SV·Agent created_on(10-20·10-22) 에 원장 §1 날짜+객체명 행 없음 · 10-20 분은 기존 · 10-22(PT) 분은 O259 재배포(원장 O259 행은 객체명 미열거) |
| sv_code_label | 143 | 900초 timeout ⇒ **미판정**(R0-8-1) |
| sv_unit | 1 | `SV_AD_INFLOW_ALLOC.COST_PER_DEV`(O249) · Agent 3종 COMMENT 「소관 SV 종수」 부재(O250 「수치 없음」 결정과 충돌 · 기존) |
| table_ddl_column | 1 | `DIM_ORG_SUCCESSION` DDL block not found(O252 유래 · 이번에 GOLD DDL 무변경) |

## E8. 후속 2건 (SR61467 · 2026-10-23 · 사용자 지시 「남은 작업 진행」)

- live_change: 원장 O259 행에 `2026-10-22(PT) … REBUILD:ALL` 표기 추가.
  - 1차로 객체명 41종을 나열했으나 조각 -002 가 41,326 B(상한 초과 366 B)가 되어 `REBUILD:ALL` 표지로 대체 → 40,492 B.
  - 재판정 = 「무기록 라이브 변경 35건」(rc=1 · 종전 78) · 10-22·10-21 분 0 · 잔여 35건 전부 2026-10-20(O248·O249 세션 · O259 무관).
  - 🟠 10-21(PT) 분 2건(SV_MEMBER_SPONSOR_BIZ · SV_MSTR_SPNSR_DVLP)은 「날짜+1」 경계로 O259 행에 인정됐다 — 실제 소관 세션 미확인.
  - line_len PASS · index_row_gate PASS · doc_census stale 0.
- sv_code_label: `timeout 3500` 단독 재실행 → rc=1(판정 완료 · 미판정 해소).
  - 「SV 44종 · 컬럼 배킹 차원 898개」 · blocking 4 · advisory(열거누락) 270 · 정보 16.
  - blocking = SV_AD.DEVICE_TYPE 열거 ['M','PC'] vs 실제 ['(unknown)','(해당없음)'] · SV_GA_BEHAVIOR.DEFAULT_CHANNEL_GROUP 열거 10 vs 실제 0종(코드값·종수 2건) · SV_MEMBER_SPONSOR_BIZ.MAP_METHOD COMMENT 「실제값 8종」 vs 실제 6종.
  - 🟠 MAP_METHOD 6종은 E5 의 MAP 6분류와 같은 수 ⇒ O259 유래 가능성(미확정 · COMMENT 수정 시 SV 재배포 필요).
