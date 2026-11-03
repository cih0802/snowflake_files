# O227-B 근거 — C3 단계 ① 기준선 · 단계 ② GOLD 컬럼 298 (xh20001 · 2026-10-14)

## ① 반영 확인 + 기준선

- 👤 dbt build PASS=14 · 라이브 뷰 COMMENT 12 = 잔여 이슈ID 0 · 휴일 주장 0(INFORMATION_SCHEMA).
- eval V4 `o227s1`(DEFAULT = EXEC V$7 · MEMBER V$9 · MKT V$8):

| Agent | 비교 | AC | TS | 문항 |Δ|≥0.3 |
|---|---|---|---|---|
| EXEC | o226v4 → o227s1 | 0.9524 → 0.9524 | 0.9524 → 0.9524 | Q12 1.0 → 0.67 · Q13 0.67 → 1.0 |
| MEMBER | o227v4 → o227s1 | 0.9231 → 0.9746 | 0.4323 → 0.4762 | D3 0.33 → 1.0(⇒ O227-A D3 하락 = 실행 변동) |
| MKT | o226v4 → o227s1 | 0.9764 → 0.8814 | 0.8271 → 0.8929 | 🟠 Q31 1.0 → 0(LTV 캠페인 예측 · 기지 불안정 TS 0.25) · Q17·Q21 1.0 → 0.67 · Q22 0.67 → 1.0 |

- 🟠 MKT 하락 = ① 은 SV·Agent 스펙을 바꾸지 않았다(테이블·뷰 레벨 COMMENT 만) ⇒ 원인 단정 보류 · ② build 후 재측정에서 판정.

## ② GOLD 컬럼 298 = 테이블 29(라이브) + 뷰 269(👤 build 대기)

- 도구 = `tmp/o227/fix_c3_col.py`(규칙 scrub + 덮어쓰기 36) → `fix_c3_col2.py`(잔재 정리) → `fix_c3_col_live.py`(테이블 ALTER 29).
- 전후 대조 = `tmp/o227/c3_col_diff.md`(1차 기준) · 잔여 이슈ID 0 · 결함 패턴 0 · line_len PASS · jinja PASS.
- comment_drift_gate = GOLD 테이블 일치 · GOLD 뷰 🟡 PENDING 269(= 이번 변경분 정확히) · 금지 문안 0.

### 라이브 실측으로 거짓 판명 → 덮어쓴 주장 (36)

| 뷰 | 컬럼 | 옛 주장 | 실측 |
|---|---|---|---|
| WIDE_MEMBER_MONTHLY | AMOUNT_BAND1·2 · INCREASE_FLAG · JOIN_DATE · NEW_EXISTING_FLAG · NEW_FLAG · PERIOD_BAND1·2 · REDONATE_FLAG | 전건 NULL 미적재 | non-null 41,070,345~42,737,755 / 42,737,755 |
| WIDE_MEMBER_MONTHLY | DEV_TYPE · STOP_DATE | 전건 NULL | 2,042,263 · 3,101,854 행 채움 |
| WIDE_MEMBER_MONTHLY | CAMPAIGN_* 6 | 전건 센티넬 | 캠페인명 12,350종 · '(미매핑)' 4,190,545 |
| WIDE_MEMBER_MONTHLY | SPONSORSHIP_* 5 | 전건 센티넬 | 후원사업 34종 · 미연결 4,481,197(이름 '(미매핑)' · 분류 NULL) |
| WIDE_MEMBER_EVENT | NEW_EXISTING_FLAG | 전건 NULL | 4,764,367 / 4,764,367 |
| WIDE_SERVICE_EVENT | CAMPAIGN_* 5 | 전건 센티넬 | 캠페인명 10,142종 · 연결 4,931,547 / 43,919,141 |
| WIDE_EVENT_PARTICIPATION | EVENT_BK · EVENT_NAME | '(미매핑)' 다수 | EVENT_BK '(미매핑)' 0 |
| WIDE_AD_* 3 · WIDE_BIGQUERY_BEHAVIOR | PERF_IS_HOLIDAY · IS_HOLIDAY | 전건 FALSE | TRUE 12,254 · 66,725 · DIM_DATE 251 |
| WIDE_BIGQUERY_BEHAVIOR | YEAR | 단일값 | 3종(2024·2025·2026) |
| WIDE_BIGQUERY_BEHAVIOR | IDENTITY_MEMNUM | FK 센티넬 원인 | 뷰 전건 NULL 유지 · FACT IDENTITY_SK≠0 1,273,055 ⇒ 원인 문장 삭제 |

### 유지(재확인)

- 광고 CAMPAIGN_SK·AD_CREATIVE_SK ≠0 0 · AD_TARGET_GROUP·PLATFORM_TYPE 0 · CONV_CALL_CNT·MEDIA_POTENTIAL_CUST_CNT 0.
- 예산 ORG·SPONSORSHIP_SK ≠0 0 · EXEC_BUDGET_EST 0 · DIM_ORG.CORP 0 · DIM_EVENT.APPLY_CHANNEL 0.
- FMM PAYMENT_SK ≠0 0 · FMD MAIL_RECEIVE_FLAG 0 · BQ 캠페인 '(미매핑)' 전건 · 세션지표 0 · SEND_TYPE_L '(미매핑)' 73.7%.

### 사고 1건(복구 완료)

- `fix_c3_col.py --apply` 가 블록 스칼라(`description: >-` · WIDE_BUDGET.PLAN_BUDGET_MONTH)의 머리줄만 덮어써 YAML 이 깨졌다(전체 파싱 실패 · 라이브 ALTER 는 실행 전 중단).
- 복구 = `tmp/o227/repair_plan_budget.py`(헤더 `>-` = `_archive/_wide_schema.yml.O174-precpcrename` 확인 → 본문 9줄 접어 원문 535자 복원 → scrub → 1줄) · YAML PASS.
- 원인 = 단일 줄 전제 · 사전 dry-run 은 yaml 개별 줄만 검증 · 처방 = 이후 스크립트는 다음 줄 형식 assert(`fix_c3_col2.py`).

_Co-authored with CoCo_
