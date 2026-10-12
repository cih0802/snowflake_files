<!-- LLM-METADATA
doc_id: GN_DW_REBUILD_ORDER
doc_role: GN_DW 구조 전체 재구축 — 실행 순서표(주기적 재실행 절차 · 사람+에이전트)
project: GN_DW (굿네이버스)
created: 2026-10-03
created_by: O201 (D4 처방)
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

# 12_GN_DW_재구축_실행순서 — 신규 계정 구조 재구축 런북

> ## ▣ 이 절차는 어떤 작업의 재실행인가
>
> | 축 | 내용 |
> |---|---|
> | **재실행 대상 작업** | GN_DW **구조 전체 재구축** — 스키마·BRONZE·SILVER·ML·GOLD(dbt)·MSTR·SERVING 뷰·SV·Agent 4종 |
> | **원래 작업 단위** | O199 재구축(pw69582) · 2026-10-03 JU93656 재구축(사람 실행 · 기록 = 이 문서 §1 실측) |
> | **왜 재실행이 필요한가** | 개발 계정이 교체·재구축된다. 종전 런북 경로(`readme.md:12` 「커밋 `20260825_가오픈정리` 에서 복원」)는 **워크스페이스에 git 저장소가 없어 실행 불가**다(O201 실측 `fatal: not a git repository`). |
> | 🔴 **재실행 트리거** | ㉠ 신규·trial→paid 계정 ㉡ 리전 이전 ㉢ GN_DW DROP 후 재생성 |
> | 🔴 **선행 조건 판정** | `SELECT CURRENT_ACCOUNT()` 를 기록하고, §1 재측정 SQL 로 「GN_DW 부재 또는 비어 있음」을 확인한다. 객체가 있으면 이 절차가 아니라 개별 재배포다. |
> | 🔴 **하지 말 것** | dbt 명령을 에이전트가 실행하지 마라(`R4-1`) · `CREATE OR REPLACE AGENT` 금지(버전 소실 · `09_1` 규약) · 다른 계정의 수치를 이 계정 완료 근거로 쓰지 마라(`R2-8-4-d`) |
> | 🔴 **성공 판정식** | §3 의 판정 SQL 이 기대값과 일치 · `09_1 [6]` owner mismatch 0 · Agent 4종 tool_resources 의 SV 가 **전건 실재** · NL 스모크 「최종 응답 실패 0」 |
> | 실행 주체 | 사람(dbt · 데이터 적재) + 에이전트(DDL 실행 · 판정) |

## 1. 라이브 실측 — JU93656 재구축의 실제 순서 (2026-10-03 · `created` 기준 · 시각 −07:00)

> 🔴 아래 수는 **그 시점 그 계정의 값**이다. 다음 재구축에서는 아래 SQL 로 다시 재라(`R3-9 ㉦`).
> 재측정 SQL = `SELECT TABLE_SCHEMA, TABLE_TYPE, COUNT(*), MIN(CREATED), MAX(CREATED)`
> `FROM GN_DW.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA <> 'INFORMATION_SCHEMA' GROUP BY 1,2 ORDER BY 4;`

| 순 | 시각 | 생성된 객체 | 실측 |
|---|---|---|---|
| 1 | 01:26 | 스키마(PUBLIC · BRONZE_CRM/AGENCY/ERP/BIGQUERY · SILVER · GOLD · SERVING · OPS · ML · SECURITY) | owner GN_DW_ADMIN(PUBLIC 만 SYSADMIN) |
| 2 | 01:28 | DBT_TEST__AUDIT 스키마 | dbt 가 만든다 |
| 3 | 01:29~01:30 | BRONZE_CRM 테이블 · ML 테이블 · SILVER 테이블 착수 | BRONZE_CRM 53 · ML 12 |
| 4 | 01:30 | BRONZE_AGENCY · ERP · GA4 · GSC 테이블 (GA4·GSC 스키마도 이때 생성) | 4 · 2 · 2 · 3 · BRONZE_BIGQUERY 0 |
| 5 | 01:29~01:33 | SILVER 테이블 | 61 |
| 6 | 01:32~01:33 | GOLD 테이블(dbt) | 48 |
| 7 | 01:46~01:48 | MSTR 스키마 → 테이블 → 프로시저 → 뷰 → 함수 | 10 · 13 · 13 · 2 |
| 8 | 01:47~01:56 | GOLD 뷰(WIDE_*) · OPS 테스트·경고 테이블(dbt) | 17 · 9 |
| 9 | 01:55~01:56 | 실적·부서집계 SV · SV_MSTR_SPNSR_DVLP | `05_*` · `23` |
| 10 | 01:56 | SERVING 뷰(ML 7 + MSTR 1) | 8 |
| 11 | 01:56:53~57 | AGENT_MEMBER · EXECUTIVE · MARKETING | VERSION$3 default |
| 12 | 01:57:45~01:58:12 | ML SV 7종 | 🔴 **Agent 생성보다 늦다**(순서 역전 — §2 순 11·12) |
| 13 | 01:57:56 | AGENT_MSTR | |

## 2. 실행 순서표 — 정본 파일 매핑

| 순 | 단계 | 정본 파일 | 주체 | 판정 |
|---|---|---|---|---|
| 1 | 역할·웨어하우스·DB·스키마 | `02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql` | 에이전트 | 스키마 목록 = §1 순1 |
| 2 | BRONZE DDL | `50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL.sql` | 에이전트 | BRONZE 6 스키마 |
| 3 | ML DDL | `50_handoff/05_데이터마이그 GN_DW_ML_DDL_20260814.sql` | 에이전트 | ML 테이블 수 = DDL CREATE 수 |
| 4 | SILVER DDL | `50_handoff/06_데이터마이그 GN_DW_SILVER_DDL.sql` | 에이전트 | SILVER 테이블 수 = DDL CREATE 수 |
| 5 | 데이터 적재 | `50_handoff/07_데이터마이그 C_CONSUMER.sql` 등 | 👤 사람 | BRONZE 행수 > 0 |
| 6 | GOLD · WIDE · 테스트 | `dbt build --project-dir 10_dbt_pipeline` | 👤 사람(`R4-1`) | `08_After_Deploy_DBT.sql` |
| 7 | MSTR | `15_MSTR 이관 PoC/snowflake 적용 ddl/00~04` 또는 `tools/mstr_pipeline.py` | 에이전트 | 매니페스트 ↔ 라이브 일치 |
| 8 | SERVING 기반 | `05_SV-Agent_ai/02_SERVING_setup.sql` | 에이전트 | — |
| 9 | ML SERVING 뷰 | `05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql` | 에이전트 | 뷰 7 |
| 10 | 실적·부서집계 SV | `05_SV-Agent_ai/05_0`·`05_1`~`05_17`(🆕 O203 · `05_14` KPI · `05_15` GA 행동 · `05_16` 연 예산 · `05_17` 회원상태 as-of) · `13_SV_AD_배포_추가작업.sql` | 에이전트 | `sv_identifier_gate` |
| 11 | 🔴 ML SV · MSTR SV | `22_ML_SV_DDL.sql` · `23_MSTR_SV_DDL.sql` | 에이전트 | **Agent 보다 먼저**(아래 주) |
| 12 | Agent 3종 | `09_1_AGENT_생성.sql` → `09_2_AGENT_버전업.sql` | 에이전트 | `09_1 [6]` · 참조 SV 전건 실재 |
| 13 | AGENT_MSTR | `24_MSTR_AGENT_배포.sql` | 에이전트 | `24 [3]`·`[8]` |
| 14 | NL 스모크 | `scripts/nl_routing_smoke.py --apply` + `10_NL스모크_재실행_절차.md` | 에이전트 + 👤 CoWork | 최종 응답 실패 0 |

> 🔴 순 11 → 12 순서를 지켜라. JU93656 에서는 ML SV 가 Agent 보다 **늦게** 생성됐다(§1 순11·12).
> `09_2` 의 버전 추가 시점에 참조 SV 가 없으면 그 도구가 죽은 채로 버전이 굳는다(`09_1 [1-C]` 주석과 같은 축).

### 2-1. 🆕 [O216 · 2026-10-12 · CK24285] 재구축 반영분

> 근거 = `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0216-A.md` ▣ O216-A-1 · 라이브 실측 = CK24285(2026-10-12).

| 순 | 단계 | 정본 파일 | 주체 | 판정 |
|---|---|---|---|---|
| 4·6 | BIGQUERY_SESSION COMMENT | `04_silver_design/08_SILVER_테이블DDL_20260714.sql`(SILVER.BIGQUERY_SESSION) · `03_top-down_gold/06_DDL.sql`(GOLD.FACT_BIGQUERY_SESSION) | 에이전트 | 🟢 파일 정본에 이미 반영 · 두 테이블 모두 **선생성 금지**(range 모델) ⇒ dbt 가 만든 뒤 `comment_drift_gate --apply` · 드리프트 0 |
| 10·11 | SV `AI_SQL_GENERATION` [O216 SQL 작성 규칙] | `05_*_SV_DDL_*.sql` · `22_ML_SV_DDL.sql` · `23_MSTR_SV_DDL.sql` | 에이전트 | 🟢 파일에 이미 들어 있다 ⇒ 순 10·11 을 그대로 실행하면 반영된다 · `sv_identifier_gate` PASS |
| 10 | `05_18` 장문 행 | `05_SV-Agent_ai/05_18_SV_DDL_MEMBER_SERVICE_COHORT.sql` | 에이전트 | 🟢 2,007자 행 분할 완료 · `line_len.py` PASS |
| 12 | Agent 3종 8·9차 | `cortex_project/agents/<AGENT>/agent_spec.yaml`(O216 · O216-C · O216-D · O216-F 블록 포함) → `09_2_AGENT_버전업.sql` | 에이전트 | 새 버전 default · 도구 수 22·12·20 무변경 · 🔴 버전 번호는 계정마다 다르다(CK24285 = **VERSION$7** · 롤백 VERSION$6 · 이력 = `12_agent개선과제/00_작업계획.md` §14) |
| 15 | eval 인프라 | `tmp/o216_eval_ds.py v2` · `tmp/o216_eval_ds.py v3` | 에이전트 | `SERVING.EVAL_CONFIG_STAGE` · 입력 테이블 6종(`EVAL_O211_*` 3 · `EVAL_O216_*_V3` 3) · 데이터셋 6종 |
| 16 | eval 기준선 | `tmp/o216_eval.py start <VERSION> v3 <tag>` → `status` | 에이전트(과금 승인) | 기준선 = **DS V3** · 같은 데이터셋끼리만 비교(O215-A-2) |
| 17 | 🆕 OPS 수기 객체(O216-G) | `08_mornitoring/08_OPS_컬럼NULL사유_등록부_및_OPS객체목록.sql`(NULL 사유 코드 · 등록부 · OPS 객체 목록 뷰) | 에이전트 | `SELECT * FROM GN_DW.OPS.V_OPS_OBJECT_INVENTORY WHERE MANAGED_BY = '수기' AND DDL_FILE IS NULL` = 0행 |
| 18 | 🟠 모니터링·비용 가드(미배포) | `08_mornitoring/05_AI비용가드_구축.sql` · `06_웨어하우스비용가드_구축.sql` · `07_OPS_알림수신자관리_…sql` | 👤 사람(ACCOUNTADMIN · 알림 이메일 결정) | 🔴 CK24285 에 **0건**(O216-G 실측 · 이 런북 §2 에 단계가 없었다) — 배포 여부는 사용자 결정 |

- 🟢 [O216-B] eval 스크립트 2종의 실행 롤 = **GN_DW_ADMIN**(`o216_eval_ds.py:20` · `o216_eval.py:21` · 종전 ACCOUNTADMIN).
  CK24285 실측상 GN_DW_ADMIN 이 요건을 전부 갖는다 ⇒ 재구축·운영계에서도 그대로 실행한다.
  · CORTEX_USER · USE AI FUNCTIONS = PUBLIC 경유 · EXECUTE TASK = GN_DW_DBT 상속 · SERVING 스키마·Agent = owner.
  · 🟢 [O216-B] CK24285 eval 객체 13종(테이블 6 · 스테이지 1 · 데이터셋 6) owner → GN_DW_ADMIN 이관 완료 · 스크립트 2종 롤도 GN_DW_ADMIN 으로 수정.
- 🔴 eval 데이터셋 원천 = `12_agent개선과제/06_O208_문항코퍼스.csv` · resolved.yaml 원본 = `tmp/o215/`(파일 이관 필수).

## 3. 완료 판정 SQL

```sql
SHOW AGENTS IN SCHEMA GN_DW.SERVING;            -- owner 전건 GN_DW_ADMIN
SHOW SEMANTIC VIEWS IN DATABASE GN_DW;          -- Agent tool_resources 의 SV 전건 실재
SELECT TABLE_SCHEMA, TABLE_TYPE, COUNT(*)
FROM GN_DW.INFORMATION_SCHEMA.TABLES
GROUP BY 1, 2 ORDER BY 1, 2;                    -- §1 표와 대조(값은 재측정값으로 기록)
```

## 4. 🟠 장기 처방 — 실행 가능한 단일 경로 (설계안 · 미집행)

- 문제 = 정본이 6개 폴더에 흩어져 있고 순서는 사람 기억과 이 표에만 있다.
- 안 A (DCM 프로젝트) = 순 1~4·8~11 을 `DEFINE` 정의로 묶고 `snow dcm` plan/deploy 로 배포한다.
  Agent·dbt·데이터 적재는 DCM 밖에 두고 순 12~14 는 스크립트로 남긴다.
- 안 B (Task 그래프) = 순 7·9~13 을 프로시저로 감싼 뒤 루트 Task → 자식 Task 로 체인한다.
  dbt 는 `EXECUTE DBT PROJECT` 자식 Task 로 둔다(사람 승인 후 수동 트리거).
- 🔴 결정·집행은 사용자 승인 사안이다(이 문서는 설계안만 담는다).

_Co-authored with CoCo_
