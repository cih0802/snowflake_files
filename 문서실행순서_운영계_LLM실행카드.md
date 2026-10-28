<!-- LLM-METADATA
doc_id: OPS_LLM_RUN_CARD_43_58
doc_role: 운영계 실행 카드 — 저가형 LLM 이 읽고 그대로 실행하는 단계표(기존 환경 갱신 43~58)
project: GN_DW (굿네이버스)
created: 2026-10-28
created_by: O268
index: 문서실행순서.md
END-METADATA -->

# 운영계 실행 카드 — 기존 환경 갱신 43~58

> **이 카드만 읽고 실행한다.** 순서의 정본 = `문서실행순서.md` 「기존 환경 갱신」 43~58.
> 일반 규칙(실행기·예외·확인 쿼리)의 정본 = `문서실행순서_llm실행.md`.
> 이 카드와 정본이 다르면 **실행하지 말고 사용자에게 묻는다.**

## 0. 읽는 법 (반드시 지킨다)

1. 단계는 **위에서부터 한 개씩** 한다. 다음 단계는 앞 단계의 「확인」이 맞을 때만 한다.
2. 「확인」이 맞지 않으면 **멈추고** 아래 「보고 양식」으로 사용자에게 알린다. 스스로 고치지 않는다.
3. 👤 표시 단계는 **사람이 실행**한다. 너는 명령을 그대로 보여 주고 「완료」라는 답을 기다린다.
4. 파일을 고치지 않는다. 문장을 바꾸지 않는다. 표에 없는 파일을 실행하지 않는다.
5. 단계 하나가 끝날 때마다 대화에 한 줄을 남긴다: `[단계 번호] OK · 걸린 시간 · 핵심 확인값`.

## 1. 금지 (하나라도 해당하면 즉시 멈춘다)

| 금지 | 이유 |
|---|---|
| `GN_DW.BRONZE_*` 에 쓰는 문장(INSERT·UPDATE·DELETE·MERGE·TRUNCATE·COPY INTO·DROP·CREATE OR REPLACE TABLE·ALTER TABLE) | 원천이다. 지우면 되돌릴 수 없다 |
| `03_top-down_gold/06_DDL.sql`·`04_silver_design/08_SILVER_테이블DDL_20260714.sql` **파일 전체** 실행 | GOLD·SILVER 테이블을 비운다 |
| 백필·기간 지정 재적재(`bigquery_dt_ranges` 전 구간 · MSTR 과거 월 루프) | 운영계에는 과거 데이터가 이미 있다(지침 `R2-9`) |
| dbt 명령(`EXECUTE DBT PROJECT …`)을 네가 실행 | 사람만 실행한다(지침 `R4-1`) |
| 같은 단계를 실패 직후 그대로 재실행 | 서버에서 아직 돌고 있을 수 있다 — 먼저 2-③ 을 본다 |

## 2. 시작 전 확인 (전부 맞아야 3 으로 간다)

| 순 | 할 일 | 맞는 결과 |
|---|---|---|
| ① | 사용자에게 「대상이 운영계인가」를 묻는다 | 사용자가 「운영계」라고 답한다 |
| ② | `SELECT CURRENT_ACCOUNT(), CURRENT_USER();` | 사용자가 알려 준 운영계 계정 |
| ③ | 실행 중 쿼리 확인(아래 SQL) | 0행 |
| ④ | `ls /workspace/문서실행순서.md` | 파일이 있다 · 없으면 `문서실행순서_llm실행.md` §5 |
| ⑤ | `60_repeat_어카운트시작/13_운영계_반영_20261005이후.md` §13 의 마지막 행 번호 | 42 · 다르면 멈추고 묻는다 |

```sql
SELECT query_id, LEFT(query_text,120) q, execution_status, start_time
FROM TABLE(GN_DW.INFORMATION_SCHEMA.QUERY_HISTORY(RESULT_LIMIT=>2000))
WHERE execution_status IN ('RUNNING','QUEUED','BLOCKED') AND query_text NOT ILIKE '%QUERY_HISTORY%';
```

## 3. 실행 도구 (이 두 개만 쓴다)

| 도구 | 언제 | 형식 |
|---|---|---|
| 블록 실행기 | 표에 「블록」이 적힌 단계 | `python3 scripts/run_sql_block.py <파일> --blocks <표지,…>` 로 **먼저 미리 보기** → 원천 쓰기가 없으면 같은 명령 끝에 `--apply` |
| 파일 실행기 | 표에 「파일 전체」가 적힌 단계 | `python3 scripts/run_sql_file.py <파일>` |

- 블록 실행기는 `--apply` 가 없으면 아무것도 바꾸지 않는다. 미리 보기에 `BLOCKED` 가 나오면 **멈춘다**.
- 블록 실행기·파일 실행기가 `FAIL` 을 내면 **멈춘다**(다음 문장으로 넘어가지 않는다).
- 1분 넘게 걸리는 단계(표의 「백그라운드」)는 백그라운드로 띄우고, 결과는 끝난 뒤 읽는다.
- 🔴 `GN_DW_ADMIN` 으로 바꾼 직후 웨어하우스가 풀린다 — 확인 SELECT 전에 `USE WAREHOUSE GN_DW_ANALYTICS_WH;` 를 건다.

## 4. 단계표

> 「확인」의 수치는 **개발계 값이 아니다** — 운영계는 등식(0행 · 같다 · 부분집합)으로만 판정한다.

| 단계 | 할 일 | 실행 | 확인(맞으면 다음) |
|---|---|---|---|
| 43-1 | 발송구분·메시지 형식 구조 | 블록 `05_SV-Agent_ai/45_DEPLOY_SEND_GBN_AT_OPEN.sql` · `D0,D1` | `OK` 만 나온다 · `FAIL` 0 |
| 43-2 👤 | dbt 재배포 + build | 사람에게 보여 줄 명령 = `10_dbt_pipeline/01_deploy_dbt_project.sql` 의 (2-B) 실행 → `EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select CRM_SEND_REQUEST+';` | 사람이 「완료 · ERROR=0」이라고 답한다 |
| 43-3 | 대사 | 블록 `05_SV-Agent_ai/45_DEPLOY_SEND_GBN_AT_OPEN.sql` · `D2-0,D2,D2-1` | 중복 0 · 고아 0 · A 회원수 ≤ B 회원수 |
| 43-4 | SV 2개 | 파일 전체 `05_SV-Agent_ai/05_04_SV_DDL_SERVICE.sql` → `05_SV-Agent_ai/05_28_SV_DDL_MEMBER_EVENT_COHORT.sql` | `FAIL` 0 |
| 43-5 | 확인 | 블록 `05_SV-Agent_ai/45_DEPLOY_SEND_GBN_AT_OPEN.sql` · `D3` | 결과 행이 나온다 · 오류 0 |
| 44-1 | 알림톡 링크 매핑 구조 | 블록 `05_SV-Agent_ai/45_DEPLOY_SEND_GBN_AT_OPEN.sql` · `D1-C` | `FAIL` 0 |
| 44-2 👤 | seed + build | 사람에게 보여 줄 명령 = `10_dbt_pipeline/01_deploy_dbt_project.sql` 의 (2-B) 실행 → `EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='seed --select MAP_AT_GA_LINK';` → `EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select MAP_AT_GA_LINK+';` | 「완료 · ERROR=0」 |
| 44-3 | 대사 | 블록 `05_SV-Agent_ai/45_DEPLOY_SEND_GBN_AT_OPEN.sql` · `D2-2` | 템플릿당 출처 1 · A ⊆ B |
| 44-4 | SV 재배포 | 파일 전체 `05_SV-Agent_ai/05_04_SV_DDL_SERVICE.sql` | `FAIL` 0 |
| 45 | 정산액·결합 팩트 구조 | 블록 `05_SV-Agent_ai/46_DEPLOY_AD_SETTLE_CAMPAIGN_COST.sql` · `D0,D0-b,D1,D1-b` | `FAIL` 0 |
| 46 👤 | dbt build | 사람에게 보여 줄 명령 = `10_dbt_pipeline/01_deploy_dbt_project.sql` 의 (2-B) 실행 → `EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select FACT_AD_PERFORMANCE+ FACT_MKTG_CAMPAIGN_MONTHLY_COST';` | 「완료 · ERROR=0」 |
| 47 | 대사 | 블록 `05_SV-Agent_ai/46_DEPLOY_AD_SETTLE_CAMPAIGN_COST.sql` · `D2` | PK 중복 0 |
| 48~50 | SV 3개 | 파일 전체 `05_SV-Agent_ai/05_07_SV_DDL_AD.sql` → `05_SV-Agent_ai/05_31_SV_DDL_MKTG_CAMPAIGN_COST.sql` → `05_SV-Agent_ai/05_03_SV_DDL_MEMBER_COHORT.sql` | `FAIL` 0 |
| 51 | Agent 3종 새 버전 | 블록 `05_SV-Agent_ai/09_2_AGENT_버전업.sql` · `0,0-B,0-C,1,2,3` | [0] 결과 0행(1행이라도 나오면 멈춘다) · [0-C] verdict 전부 `OK` · Agent 답변 확인은 5-② 에서 한다 |
| 52 | 확인 | 블록 `05_SV-Agent_ai/46_DEPLOY_AD_SETTLE_CAMPAIGN_COST.sql` · `D3` | 오류 0 |
| 53~55 | SV 3개 | 파일 전체 `05_SV-Agent_ai/05_20_SV_DDL_GA_SESSION.sql` → `05_SV-Agent_ai/05_23_SV_DDL_EXPENSE_RESOLUTION.sql` → `15_MSTR 이관 PoC/snowflake 적용 ddl/05_MSTR_SV_DDL.sql` | `FAIL` 0 |
| 56 | SV 1개 | 파일 전체 `05_SV-Agent_ai/05_13_SV_DDL_DEPT_AGGR.sql` | `FAIL` 0 |
| 57-1 | GOLD COMMENT 동기화 | `python3 scripts/apply_table_comment_drift.py` 로 미리 보기 → `python3 scripts/apply_table_comment_drift.py --apply` | 「ALTER 완료」 |
| 57-2 | SILVER COMMENT 동기화 | `python3 scripts/apply_silver_comment_drift.py` → 같은 명령 `--apply` | 「ALTER 완료」 |
| 57-3 | SILVER 표 COMMENT 1문장 | 아래 SQL | `Statement executed successfully` |
| 57-4 | 확인 | `python3 scripts/comment_drift_gate.py` | rc=0 |
| 58 | 확인 게이트(백그라운드) | 아래 5-① | 전부 rc=0 |

```sql
-- 57-3 (정본 = 04_silver_design/08_SILVER_테이블DDL_20260714.sql 의 MAP_AT_GA_LINK 블록 끝 문안)
ALTER TABLE GN_DW.SILVER.MAP_AT_GA_LINK SET COMMENT = '알림톡 템플릿 → GA 최종 랜딩 패턴 고정 매핑(O265-C). [Grain: 템플릿 × 패턴]. [주의: dbt seed 적재 · DIRECT·INFER 보다 우선]. [원천: 10_dbt_pipeline/seeds/MAP_AT_GA_LINK.csv].';
```

## 5. 마무리 확인

① 게이트 — 한 줄씩 백그라운드로 실행하고 rc 를 파이프 없이 받는다(`> 파일 2>&1; echo rc=$?`).

| 게이트 | 명령 | 맞는 결과 |
|---|---|---|
| 값 목록 신규값 | `python3 scripts/sv_enum_newvalue_gate.py --shard k/4` (k = 0·1·2·3 각각) | 4번 모두 rc=0 |
| 코드값·라벨 | `python3 scripts/sv_code_label_gate.py --shard k/8` (k = 0~7 각각) | 8번 모두 rc=0 |
| 단위 | `python3 scripts/sv_unit_gate.py` | rc=0 |
| COMMENT | `python3 scripts/comment_drift_gate.py` | rc=0 |
| DDL ↔ 모델 | `python3 scripts/table_ddl_column_gate.py` | rc=0 |

- 🔴 `sv_code_label_gate` 의 「코드값 부재」는 운영계 데이터 기준 판정이다 — 개발계는 표본 데이터라 GA 계열 값이 빠져 rc=1 이 났었다(O268). **운영계에서 rc=1 이면 그 줄을 그대로 보고하고 고치지 않는다.**

② Agent 확인 — 사용자에게 아래 2문장을 Snowflake Intelligence 「회원 분석」에서 물어 달라고 한다.

| 질문 | 맞는 결과 |
|---|---|
| 알림톡 템플릿 AT006040 을 받은 회원 중 수신 후 5일 이내에 그 템플릿 링크를 클릭한 회원 수를 알려줘. | 답변 앞에 영어 문장이 없다 · 「그 템플릿 링크 클릭」 기준이라고 밝힌다 |
| 알림톡 링크 utm_campaign=25acpi_om_gift 를 클릭한 회원 수를 수신 후 5일 이내 기준으로 알려줘. | 「같은 링크를 쓴 다른 템플릿 수신자의 클릭도 포함」이라고 밝힌다 |

③ 기록 — 사용자에게 `60_repeat_어카운트시작/13_운영계_반영_20261005이후.md` §13 에 43~58 행 추가를 요청한다(너는 쓰지 않는다).

## 6. 보고 양식 (멈출 때와 끝날 때 모두)

```
대상 = 운영계 · 계정 <값> · 시작 <시각> · 종료 <시각>
완료 단계 = <번호 목록>
멈춘 단계 = <번호> · 실행한 명령 = <그대로> · 받은 메시지 = <그대로 · 앞 400자>
게이트 = <게이트별 rc>
사람이 할 일 = <다음 👤 단계 명령 또는 「없음」>
```

_Co-authored with CoCo_
