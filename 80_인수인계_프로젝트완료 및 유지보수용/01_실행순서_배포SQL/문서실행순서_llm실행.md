# 문서실행순서 — LLM 실행 지침

> 대상: 이 문서를 읽고 `문서실행순서.md` 의 SQL 을 실행하는 LLM 에이전트.
> 정본 순서 = `문서실행순서.md`. 이 문서는 **실행 방법·병렬화·예외 처리·금지 사항**만 정한다.
> 근거 = 2026-10-16 개발계 실측 · 🆕 §3.4 = 2026-10-18 개발계(데이터 = 운영계와 같음 · 사용자 확인) 실측.

---

## 0. 먼저 확인할 것 (실행 전)

1. **대상 환경을 사용자에게 확인한다** — 개발계인가, 운영계인가. 답이 없으면 실행하지 않는다.
2. 계정·사용자: `SELECT CURRENT_ACCOUNT(), CURRENT_USER(), CURRENT_AVAILABLE_ROLES();`
   - ACCOUNTADMIN · SYSADMIN · SECURITYADMIN 사용 가능해야 한다(1번 파일이 셋 다 쓴다).
3. `02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql` 46~47행의
   `alter user identifier('TRIALADMIN') set default_secondary_roles=();` 는 **사용자명이 하드코딩**돼 있다.
   대상 계정의 실행 사용자와 다르면 사용자에게 알리고 지시를 받는다.
4. 워크스페이스 경로가 샌드박스에 마운트돼 있는지 확인한다(`ls /workspace/문서실행순서.md`).
   마운트가 없으면 §5 의 「stage 에서 내려받기」로 진행한다.

---

## 1. 운영계 금지 사항 (🔴 필수)

운영계에는 원천(BRONZE)이 이미 있다. **원천을 만들거나 바꾸거나 지우는 쿼리는 절대 실행하지 않는다.**

| 금지 대상 | 이유 |
|---|---|
| `50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL.sql` | `CREATE OR REPLACE TABLE GN_DW.BRONZE_*` — **원천 테이블 전체 재생성(데이터 소실)** |
| `50_handoff/05_데이터마이그 GN_DW_ML_DDL_20260814.sql` | `CREATE OR REPLACE TABLE GN_DW.ML.*` — 운영 ML 결과 소실 |
| `50_handoff/06_데이터마이그 GN_DW_SILVER_DDL.sql` | `CREATE OR REPLACE TABLE GN_DW.SILVER.*` — 운영 SILVER 소실 |
| `50_handoff/07_데이터마이그 C_CONSUMER.sql` | 개발계용 마이그 데이터 `COPY INTO` |
| 위 목록에 없더라도 `GN_DW.BRONZE_*` 대상 `INSERT/UPDATE/DELETE/MERGE/TRUNCATE/COPY INTO/DROP/CREATE OR REPLACE TABLE` | 원천 변경 |

- 운영계 순서표(`문서실행순서.md` 「# 운영계」)에는 위 4개 파일이 이미 빠져 있다. **개발계 목록을 운영계에 쓰지 않는다.**
- 🔴 **운영계 백필 및 기간 지정 실행 제외 (2026-10-19 신설 · 지침 `R2-9`)**:
  - 운영계는 raw data·과거 데이터가 이미 있으므로 **백필 목적 전 구간 재적재·기간 지정 소급 적재는 전부 건너뛴다.**
  - 예: `10_dbt_pipeline/02_dbt_parse_compile_build.sql` 의 `bigquery_dt_ranges` 전 구간 재적재(`1945-01-01~9999-12-31`) ·
    `15_MSTR 이관 PoC/snowflake 적용 ddl/06_MSTR_적재_실행.sql` 의 과거 34개월(`202401~현재월`) 루프 적재.
  - 운영계 배포·갱신은 구조 배포(DDL)와 정규 증분(일일/당월) 파이프라인만 수행한다.
- 실행 직전, 각 파일에 원천 쓰기 문장이 있는지 검사한다(§3 실행기에 내장). 걸리면 **실행하지 말고 멈춰 사용자에게 보고**한다.
- `GRANT ... ON ... SCHEMA GN_DW.BRONZE_*`(1번 파일)는 권한 부여일 뿐 데이터를 바꾸지 않으므로 허용한다.

---

## 2. 소요 시간과 병렬화

### 2.1 실측 소요 (개발계 · 2026-10-16)

| 구간 | 소요 | 비고 |
|---|---|---|
| 1 ~ 16 (RBAC·DDL·MSTR 객체) | 수 분 | — |
| 17 `01_deploy_dbt_project.sql` | 1~2분 | — |
| 19 `02_dbt_parse_compile_build.sql` | **약 13분** | `build` 단일문 ≈ 13분(700 노드) + BigQuery 범위 build ≈ 2분 |
| 21 `06_MSTR_적재_실행.sql` | **약 21분** | 202401~현재월 34개월 × 약 38초. 서버측 단일 `EXECUTE IMMEDIATE` 블록 |
| 22 ~ 59 (SV·ML·Agent) | 약 3분 | — (🆕 [O250-E] SV 정본 05_27~05_30 추가로 55 → 59 · 실측은 55 시점) |

### 2.2 병렬 실행 (총 소요를 줄이는 핵심)

**MSTR 적재(21)는 dbt 와 무관하다** — 파일 주석: 「dbt 모델·dbt build 와 무관 · 선행 = BRONZE_CRM 적재 + 00~04 배포」.
`05_SV-Agent_ai/*` 는 `GN_DW.MSTR.*` 를 참조하지 않는다(grep 확인).

```
[직렬] 1 → … → 16(05_MSTR_SV_DDL) → 17(deploy dbt)
          ├─ 레인 A: 18 → 19(dbt build) → 20
          └─ 레인 B: 21(MSTR 적재)            ← 16 완료 직후 별도 세션으로 시작
[합류] 레인 A 완료 후 22 ~ 59 진행 (레인 B 는 22~59 에 불필요 — 59 완료 후 레인 B 종료만 확인)
```
(운영계 번호로는 21 → 17, 19 → 15, 18 → 14, 20 → 16, 22~59 → 18~55.)

- 레인 B 는 **반드시 별도 Snowflake 연결(별도 프로세스)** 로 실행한다. 세션의 `USE ROLE` 이 섞이면 안 된다.
- 기대 효과: 13분 + 21분 직렬 → 약 21분으로 단축.

---

## 3. 실행 방법 (🔴 지난 실행의 지연 원인을 막는 규칙)

### 3.1 지난 실행에서 시간이 오래 걸린 원인 — 반복 금지

1. **도구 호출 시간 제한 안에서 장시간 SQL 을 동기 실행했다** → 클라이언트는 끊겼지만 Snowflake 쿼리는 계속 돌았다.
   그 상태로 재실행해서 **dbt build 가 2개 동시에** 돌았고, 결과가 오염돼 다시 build 했다(+13분 × 2).
   - 규칙: 1개 파일 이상을 실행할 때는 **항상 백그라운드 프로세스**로 실행하고, 로그 파일을 폴링한다.
   - 규칙: `timeout` 으로 실행기를 감싸지 않는다(서버측 쿼리는 계속 돈다).
   - 규칙: 재실행 전에 **반드시 실행 중인 쿼리를 확인**한다(§6.1). 돌고 있으면 기다리거나 `SYSTEM$CANCEL_QUERY` 한다.
2. **`conn.execute_stream(str)` 에 문자열을 넘겼다** → 실행 0건으로 실패. 파일 객체 또는 `io.StringIO` 를 넘겨야 한다.
3. **로그·상태를 `/tmp` 에 두었다가 샌드박스 재시작으로 잃었다.** 상태 파일은 `/tmp` 와 함께
   **진행 요약을 매 파일 완료 시 대화에 한 줄로 남긴다**(재시작 후 재개 기준).
   - 🆕 [2026-10-16 O241] 상태·로그를 **`/workspace/tmp/runner/`** 에 두면 재시작 후에도 남는다(실측 · 쓰는 중 읽기 제약은 §4).
     단 `/tmp/census.json` 처럼 `/tmp` 에만 있는 생성기 입력은 재시작 시 사라진다 — 생성기 실행 전 존재를 확인한다.
4. 폴링 간격이 짧고 잦았다. dbt build·MSTR 은 **2분 간격**으로 `QUERY_HISTORY` 를 보면 충분하다.

### 3.2 실행기 (문장 단위 · 재개 가능 · 원천 쓰기 차단)

`/tmp/runner/run.py` 로 저장하고 **백그라운드**로 실행한다.

```python
import os, sys, json, re, io, warnings
warnings.filterwarnings('ignore')
import snowflake.connector
from snowflake.connector.util_text import split_statements

BASE   = os.environ.get('WS_BASE', '/workspace/')      # 마운트 없으면 /tmp/ws/
ENV    = os.environ['TARGET_ENV']                     # 'DEV' 또는 'PROD'
FILES  = os.environ['RUN_FILES'].split('|')            # 이 레인이 실행할 파일(순서대로, 상대경로)
STATE  = os.environ.get('STATE', '/tmp/runner/state.json')
SKIPS  = json.load(open('/tmp/runner/skips.json')) if os.path.exists('/tmp/runner/skips.json') else {}
SRC_WRITE = re.compile(r'^\s*(INSERT|UPDATE|DELETE|MERGE|TRUNCATE|COPY\s+INTO|DROP|CREATE\s+OR\s+REPLACE\s+(TRANSIENT\s+)?TABLE|ALTER\s+TABLE)\b[^;]*\bBRONZE_', re.I | re.S)

state = json.load(open(STATE)) if os.path.exists(STATE) else {'file': 0, 'stmt': 0}
conn = snowflake.connector.connect(connection_name=os.environ.get('SNOWFLAKE_CONNECTION_NAME', 'default'))
cur = conn.cursor()

for fi in range(state['file'], len(FILES)):
    rel = FILES[fi]
    stmts = [s for s, _ in split_statements(io.StringIO(open(BASE + rel, encoding='utf-8').read()),
                                            remove_comments=True) if s.strip()]
    if ENV == 'PROD':
        bad = [i for i, s in enumerate(stmts) if SRC_WRITE.search(s)]
        if bad:
            print(f'BLOCKED {rel}: 원천 쓰기 문장 {bad} — 실행 중단, 사용자 확인 필요', flush=True); sys.exit(2)
    start = state['stmt'] if fi == state['file'] else 0
    print(f'=== [{rel}] {len(stmts)} stmts from {start}', flush=True)
    for si, s in enumerate(stmts):
        if si < start:                       # 재개 시 세션 컨텍스트만 복원
            if re.match(r'^\s*USE\s', s, re.I): cur.execute(s)
            continue
        key = f'{rel}:{si}'
        if key in SKIPS:
            print(f'SKIP {key}: {SKIPS[key]}', flush=True); continue
        json.dump({'file': fi, 'stmt': si}, open(STATE, 'w'))
        try:
            cur.execute(s)
        except Exception as e:
            print(f'FAIL {key}: {e}\n--- SQL ---\n{s[:1500]}', flush=True); sys.exit(1)
    print(f'OK [{rel}]', flush=True)
    json.dump({'file': fi + 1, 'stmt': 0}, open(STATE, 'w'))
print('ALL DONE', flush=True)
```

실행 예(레인별로 STATE·로그를 분리):
```bash
TARGET_ENV=DEV RUN_FILES='02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql|...' \
STATE=/tmp/runner/state_main.json python3 /tmp/runner/run.py > /tmp/runner/main.log 2>&1   # run_in_background
```
- `split_statements` 는 `$$ … $$` 블록(EXECUTE IMMEDIATE·프로시저)을 한 문장으로 처리한다(실측 정상).
- 파일 하나 = 문장 여러 개. 실패하면 `STATE` 에 실패 문장 번호가 남는다 → 원인 수정 후 같은 명령으로 재개.
- 실패 문장이 **서버에서 아직 실행 중**일 수 있다(클라이언트만 죽은 경우). §6.1 로 확인 후 재개 위치를 정한다.
- 🆕 [O241] 샌드박스에 `connections.toml` 이 없으면 `connection_name=` 대신 `scripts/sfconn.py` 의 `conn()`(세션 OAuth 토큰)을 쓴다.
  `EXECUTE`·`CALL` 문은 반환값을 로그에 남긴다(MSTR 블록의 `ERROR` 판정 근거).

### 3.3 🆕 dbt 이후만 실행할 때 (기존 환경 · O241 실측)

dbt build(개발계 19 · 운영계 15)가 이미 끝났으면 그 **다음 번호부터** 두 레인으로 돌린다.

| 레인 | 개발계 번호 | 운영계 번호 | 실측 소요(개발계 2026-10-16) |
|---|---|---|---|
| A | 20 · 22 ~ 59 (39파일) | 16 · 18 ~ 55 | 약 4분 · 35/35 OK · FAIL 0 · SKIP 0(실측은 35파일 시점 · 🆕 O250-E 이후 39파일) |
| B | 21 (MSTR 적재) | 17 | 약 18분(1,096초) · 34/34개월 · 반환 문자열 `ERROR` 없음 |

- 실측 기준 = 2026-10-16 15:33~15:52(PDT) · 실행 전 §6.1 실행 중 쿼리 0건 · 두 레인 별도 프로세스·별도 연결.
- 결과 확인(O241) = `SV_SERVICE.D5_GIFT_AMT` 1,303,750,000 · `SV_GA_SESSION` 2026-09 A 31.87초 · B 90.27초 ·
  지표번호 토큰 동의어가 있는 metric 87개 · AGENT_MEMBER·AGENT_MARKETING 기본 = VERSION$4(O241 규칙 포함 · 롤백 = VERSION$3).

- 🔴 SV·Agent 파일은 `CREATE OR ALTER`·`ADD VERSION` 이라 재실행해도 데이터·이전 버전이 사라지지 않는다 — 롤백 = 직전 Agent VERSION.
- 🟢 GOLD·SILVER 를 `CREATE OR REPLACE` 로 비워도 dbt 모델이 TRUNCATE → INSERT(전량 재적재)라 다음 build 로 복구된다(사용자 확인 2026-10-16).
  🔴 단 **BRONZE 는 예외** — 원천이라 dbt 가 다시 만들지 못한다(§1 금지 유지).
  🔴 **GA(BigQuery) 범위 재적재 모델도 예외** — `BIGQUERY_*`·`FACT_BIGQUERY_*` 는 TRUNCATE 가 아니라 **창(기본 최근 3일)만 DELETE→INSERT** 한다.
     비워졌으면 일반 build 로는 최근 3일치만 채워진다(O237-C 실측 = 0행 사고) ⇒ `--vars '{"bigquery_dt_ranges": [["1945-01-01", "9999-12-31"]]}'` 로 전량 백필한다
     (정본 명령 = `10_dbt_pipeline/02_dbt_parse_compile_build.sql` 의 BigQuery 범위 build).
- 완료 확인 = 배포순서 파일의 `[D3]` 확인 SELECT · Agent 기본 버전에 그 회차 규칙 문자열이 있는가(`SHOW VERSIONS IN AGENT … ->> SELECT "name", "is_default", CONTAINS("agent_spec", '<규칙 표지>') FROM $1`).

### 3.4 🆕 O243~O245 증분(`문서실행순서.md` 「기존 환경 갱신」 14~19 2026-10-18 실측)

| 순 | 실행 방식 | 실측 |
|---|---|---|
| 14 · 15 · 17 · 18 | 각 파일을 **첫 줄 ~ 마지막 `GRANT` 줄**까지 실행(뒤의 스모크 SELECT 제외) | 18 = 21 → 22 → 25 순서 필수(22·25 의 SV 가 21 의 뷰를 참조 · 신설 `ML_CHURN_BY_SPONSORSHIP_V`) · 84문 OK |
| 16 | `dbt_build_fact_ad_performance_budget.sql` = dbt 재배포 + build | 🔴 dbt 는 사용자가 실행한다(에이전트 정지점) |
| 19 | 09_2 의 [0-B] COPY FILES → [0-C] 크기 대조 → [2] live 소진 → [3] ADD VERSION | Agent 3종 신규 기본 버전 · 롤백 = 직전 버전 |

- 🔴 `USE ROLE GN_DW_ADMIN` 직후 **웨어하우스가 풀린다**(`000606 No active warehouse`) ⇒ 확인 SELECT·Agent 호출 전에 `USE WAREHOUSE GN_DW_ANALYTICS_WH` 를 다시 건다(SV DDL 파일은 파일 안에 이미 있다).
- 🔴 `SHOW VERSIONS IN AGENT` 행 순서는 생성순이 아니다 ⇒ `created_on` 으로 정렬해 최신 버전과 `is_default` 를 판정한다.
- 🔴 `ACCOUNTADMIN` 에서도 `GN_DW` 객체가 보이는 경우가 있으나 배포·판정은 `GN_DW_ADMIN` 으로 한다(소유자 일치 · `sfconn` 기본 역할은 ACCOUNTADMIN).
- 확인 = `문서실행순서.md` 19번 아래 확인 수치. Agent 응답 확인 문항 = `tmp/o245/agent_test.py`(17문항 · 기대값 = SV 직접 질의 · 판정 = `tmp/o245/agent_judge.py`).
  🔴 러너 자체 판정(`err`·`tok`)은 쓰지 마라 — `err` 는 SV 지침 안의 「invalid identifier」 문구를 오류로 잡는다(전건 오탐).
- Agent 호출(`DATA_AGENT_RUN`)은 1문항 약 1분이다 ⇒ 백그라운드로 돌리고 `QUERY_HISTORY` 로 진행을 본다(마운트 파일 목록은 수 분 늦게 반영된다 · 실측).

### 3.5 🆕 O249~O250 증분(`문서실행순서.md` 「기존 환경 갱신」 20~28 2026-10-20~21 실측)

| 순 | 실행 방식 | 실측 |
|---|---|---|
| 20 | `06_DDL.sql` 의 `RENAME COLUMN LTV_CAP_MONTHS TO LTV_CAP_AVG_ACTIVE_MONTHS` **1문장만** — 이미 바뀌었으면(`invalid identifier`) 건너뛴다 | 🔴 파일 전체 실행 금지(GOLD `CREATE OR REPLACE` 가 섞여 있다) |
| 21 | dbt 재배포 + `build --select FACT_MEMBER_COHORT_SURVIVAL DIM_SEND_REQUEST DIM_MSG_TEMPLATE DIM_MSG_TEMPLATE_BUTTON` | 🔴 사용자가 실행한다(에이전트 정지점) PASS=11 · 고아 0 |
| 22 · 23 · 25 | 각 파일 첫 줄 ~ 마지막 `GRANT` | 22 = 05_03 → 21 → 22 → 23 순서 · 23(35_) 은 22 다음 |
| 24 | `tmp/o249/agent_deploy.py`(환경변수 `AG` 로 1종씩) | 27 이 같은 일을 09_2 로 다시 하므로 **27 을 실행하면 24 는 건너뛰어도 된다** |
| 26 | `36_O250_ML예측_7축확장.sql` 문장 단위(뷰 2 → SV 2 → GRANT 12) · 끝의 스모크 2개로 판정 · 🆕 [O250-E] 아직 안 돌린 환경은 같은 정의의 정본 = `21_` [O250] 절 → `05_29` → `05_30` | 뷰 생성 수 초 · 스모크 = 회원수 = `ML_MEMBER_RISK_V` · 배분 합 = 예측 합(차이는 부동소수 수천 원) |
| 27 | 09_2 = [0] 부재 0행 → [0-B] COPY FILES → [0-C] 크기 대조 OK → [1] 롤백 기준 기록 → [2] → [3] | 이전 계정 = MEMBER $5 · EXECUTIVE $5 · MARKETING $6 · 실행기 예 = `tmp/o250/deploy_agents.py pre` → `deploy` |
| 28 | 09_1 [5] 의 `ALTER AGENT … SET COMMENT … PROFILE` 3문장만 | Agent 설명 = 수치 없는 카테고리 문안 |

- 🔴 [O250] `cortex ws` 마운트에서 **생성기 입력 csv 를 쓴 직후 읽으면 꼬리 행이 빠진다**(실측 = `env_capture` 직후 `b_struct_build` 가 SV 44 중 42 만 읽음) ⇒ 캡처와 생성기 사이에 수십 초 두거나, 생성 후 행 수를 캡처 csv 와 대조한다.
- 🔴 `SNOWFLAKE.ACCOUNT_USAGE.OBJECT_DEPENDENCIES` 는 새 뷰가 수 시간 늦게 들어온다 ⇒ 계보(D06) 의 view dependency 는 배포 다음 날 다시 만든다.
- 확인 = SV 질의 4문항(`tmp/o250/ca_check.py` · Cortex Analyst 생성 SQL ↔ 직접 SQL 값 대조 · GN_DW_ANALYST 로 실행 = 권한 확인 겸).

---

## 4. 알려진 예외 (재실행 시 이미 반영 또는 처리 규칙)

| 위치 | 증상 | 처리 |
|---|---|---|
| `08_mornitoring/07_OPS_알림수신자관리_및_파이프라인_이메일알림_표준.sql` §1-1 (`GRANT OWNERSHIP ON TABLE/PROCEDURE GN_DW.OPS.ALERT_RECIPIENT_CONFIG` 외 3건, 56~59행) | 신규 환경에는 객체가 없어 `does not exist` 실패 | 파일 주석대로 **신규 환경이면 이 4문장을 SKIP**. 기존 환경(객체 존재)이면 실행. `skips.json` 에 문장 번호로 등록(개발계 실측 번호 = 9,10,11,12) |
| `04_silver_design/09_SILVER_AD_CREATIVE_CAMPAIGN_MAP_적재.sql` | CSV 15열 코드가 `SILVER.CRM_CAMPAIGN` 과 어긋나 dbt 테스트 `assert_fap_ad_ctgr_consistency` FAIL 14 → `GOLD.WIDE_AD_*` 5개 SKIP | **2026-10-16 파일 수정 완료**(이름으로 CRM 코드 조회 우선). 적재 후 기대 = 258행 · MKTG 53 · CTGR 112 · NONE 93 |
| `15_MSTR 이관 PoC/…/06_MSTR_적재_실행.sql` [2] | 주석은 「2026-01 ~」, 코드는 `BETWEEN '202401' AND 현재월` (34개월) | 코드대로 실행. 결과 문자열에 `ERROR` 가 없어야 한다. 기간 축소 여부는 사용자 결정 |
| `02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql` 47행 | 사용자명 `TRIALADMIN` 하드코딩 | §0-3 |
| 🆕 `10_dbt_pipeline` build — 새 열을 추가한 모델(예: O241 `SILVER.BIGQUERY_SESSION.SESSION_END_TS`) | `003001 Insufficient privileges … must have MODIFY … GN_DW_DBT` — 테이블 소유자는 GN_DW_ADMIN 이고 dbt 역할은 `append_new_columns` 의 `ALTER TABLE ADD COLUMN` 을 못 한다(실측 2026-10-16 이전 계정) | 신규 구축 = DDL 정본(`08_SILVER_테이블DDL` · `06_DDL`)에 열이 이미 들어 있어 발생하지 않는다. **기존 환경 갱신** = 배포순서 파일의 `[D1-a]` ALTER(소유자 역할)를 **dbt build 전에** 실행한다. 실패했으면 그 ALTER 를 실행한 뒤 build 만 재실행(이미 성공한 모델은 다시 돌아도 멱등) |
| 🆕 `/workspace` 로그 파일 | 실행기가 쓰는 중인 로그를 `tail` 하면 `read error: No such file or directory`(스테이지 마운트 · 실측) | 진행 판정은 **상태 파일(`STATE`)** 과 §6.1 `QUERY_HISTORY` 로 한다. 로그는 프로세스 종료 후 읽는다 |
| 🆕 [O245] `shutil.copy2` 로 `/workspace` 에 백업 | `FileNotFoundError`(마운트가 xattr 를 지원하지 않는다 · 실측) — 빈 파일이 남을 수 있다 | `shutil.copyfile` 을 쓴다. 백업 후 원본을 쓰기 전에 백업 크기를 확인한다 |
| 🆕 [O245] 예산(`FACT_BUDGET`·`FACT_BUDGET_YEARLY`) 차수 | 추경(추가경정) 편성 데이터가 없는 연도가 있다(2026 = 편성 0) | 규칙 = 편성액이 있는 차수 중 최신(사용자 결정 · 현행 유지). 추경 목표(공153·155)는 데이터가 없다 — 「산출 불가」로 답한다 |

### 4.1 에러 처리 원칙
- 에러가 나면 **원인을 확인한 뒤** 고친다. 테스트 severity 를 낮추거나 테스트를 지우는 방식으로 넘기지 않는다.
- 소스 파일을 고치면 **파일·행·이유를 기록**하고 최종 보고에 포함한다. 파일 안에 `-- 🆕 [날짜] 사유` 주석을 남긴다(기존 관례).
- 순서표의 `SKIP` 은 파일 주석이 명시적으로 허용한 경우에만 한다.
- 운영계에서 원천 쓰기가 필요해 보이면 **실행하지 말고 멈춘다.**

---

## 5. 워크스페이스 마운트가 없을 때

샌드박스 재시작 후 `/workspace` 가 비어 보일 수 있다(실측). SQL 로 내려받아 `WS_BASE=/tmp/ws/` 로 실행한다.
```python
base = 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/'
# 문서실행순서.md 의 각 상대경로 rel 에 대해:
cur.execute(f"GET '{base}{rel}' 'file:///tmp/ws/{os.path.dirname(rel)}/'")
```
- 워크스페이스 경로를 직접 읽는 문장(`COPY FILES … FROM 'snow://workspace/…'`, dbt deploy 의 `FROM 'snow://workspace/…'`)은 서버측이라 마운트와 무관하게 동작한다.
- 워크스페이스명(`USER$.PUBLIC."snowflake_files"`)이 대상 계정에서 다르면 해당 문장을 수정해야 한다 — 사용자 확인.

---

## 6. 확인 쿼리

### 6.1 실행 중 쿼리 (재실행·재개 전 필수)
```sql
SELECT query_id, LEFT(query_text,120) q, execution_status, start_time
FROM TABLE(GN_DW.INFORMATION_SCHEMA.QUERY_HISTORY(RESULT_LIMIT=>2000))
WHERE execution_status IN ('RUNNING','QUEUED','BLOCKED') AND query_text NOT ILIKE '%QUERY_HISTORY%';
```

### 6.2 dbt build 결과
```sql
-- 실패 시 에러 메시지의 query_id 사용
SELECT l.value::string FROM TABLE(SPLIT_TO_TABLE(SYSTEM$GET_DBT_LOG('<query_id>', 1000000), '\n')) l
WHERE l.value ILIKE '%[error]%' OR l.value ILIKE '%Done. PASS%' OR (l.value ILIKE '%SKIP %' AND l.value ILIKE '%[info ]%');
```
기대(개발계): `ERROR=0` (WARN 21 은 기존 관측용 warn 테스트).

### 6.3 MSTR 적재 진행·결과
```sql
-- 진행: 처리한 월 수 / 대상 월 수
SELECT (SELECT COUNT(*) FROM GN_DW.MSTR.BCHLOG WHERE LOGPROC='USP_D_STRD_CAL_CD' AND LOGTIME > '<시작시각>') AS done_cnt,
       (SELECT COUNT(DISTINCT LEFT(OCCRRNC_DE,6)) FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT
         WHERE LEFT(OCCRRNC_DE,6) BETWEEN '202401' AND TO_CHAR(CURRENT_DATE(),'YYYYMM')) AS total;
-- 결과: 블록 query_id 의 반환 문자열에 ERROR 없음
SELECT * FROM TABLE(RESULT_SCAN('<block_query_id>'));
```

---

## 7. 최종 보고 형식

1. 환경 · 계정 · 시작/종료 시각
2. 파일별 결과(OK / SKIP 문장 / 수정 후 OK)
3. 수정한 파일·행·이유
4. dbt build 요약(PASS/WARN/ERROR/SKIP) · MSTR 월별 결과
5. 부작용(계정·사용자 설정 변경, 중복 실행 여부, 출처 불명 쿼리)
6. 롤백 참고: `GN_DW` `DATA_RETENTION_TIME_IN_DAYS = 1` → Time Travel 은 **1일 이내**만 가능
