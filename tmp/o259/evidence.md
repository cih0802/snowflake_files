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
