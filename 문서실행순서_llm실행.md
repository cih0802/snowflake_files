# 문서실행순서 — LLM 실행 지침

> 대상: 이 문서를 읽고 `문서실행순서.md` 의 SQL 을 실행하는 LLM 에이전트.
> 정본 순서 = `문서실행순서.md`. 이 문서는 **실행 방법·병렬화·예외 처리·금지 사항**만 정한다.
> 근거 = 2026-10-16 개발계(ua91864) 실측.

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
| 22 ~ 55 (SV·ML·Agent) | 약 3분 | — |

### 2.2 병렬 실행 (총 소요를 줄이는 핵심)

**MSTR 적재(21)는 dbt 와 무관하다** — 파일 주석: 「dbt 모델·dbt build 와 무관 · 선행 = BRONZE_CRM 적재 + 00~04 배포」.
`05_SV-Agent_ai/*` 는 `GN_DW.MSTR.*` 를 참조하지 않는다(grep 확인).

```
[직렬] 1 → … → 16(05_MSTR_SV_DDL) → 17(deploy dbt)
          ├─ 레인 A: 18 → 19(dbt build) → 20
          └─ 레인 B: 21(MSTR 적재)            ← 16 완료 직후 별도 세션으로 시작
[합류] 레인 A 완료 후 22 ~ 55 진행 (레인 B 는 22~55 에 불필요 — 55 완료 후 레인 B 종료만 확인)
```
(운영계 번호로는 21 → 17, 19 → 15, 18 → 14, 20 → 16, 22~55 → 18~51.)

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

---

## 4. 알려진 예외 (재실행 시 이미 반영 또는 처리 규칙)

| 위치 | 증상 | 처리 |
|---|---|---|
| `08_mornitoring/07_OPS_알림수신자관리_및_파이프라인_이메일알림_표준.sql` §1-1 (`GRANT OWNERSHIP ON TABLE/PROCEDURE GN_DW.OPS.ALERT_RECIPIENT_CONFIG` 외 3건, 56~59행) | 신규 환경에는 객체가 없어 `does not exist` 실패 | 파일 주석대로 **신규 환경이면 이 4문장을 SKIP**. 기존 환경(객체 존재)이면 실행. `skips.json` 에 문장 번호로 등록(개발계 실측 번호 = 9,10,11,12) |
| `04_silver_design/09_SILVER_AD_CREATIVE_CAMPAIGN_MAP_적재.sql` | CSV 15열 코드가 `SILVER.CRM_CAMPAIGN` 과 어긋나 dbt 테스트 `assert_fap_ad_ctgr_consistency` FAIL 14 → `GOLD.WIDE_AD_*` 5개 SKIP | **2026-10-16 파일 수정 완료**(이름으로 CRM 코드 조회 우선). 적재 후 기대 = 258행 · MKTG 53 · CTGR 112 · NONE 93 |
| `15_MSTR 이관 PoC/…/06_MSTR_적재_실행.sql` [2] | 주석은 「2026-01 ~」, 코드는 `BETWEEN '202401' AND 현재월` (34개월) | 코드대로 실행. 결과 문자열에 `ERROR` 가 없어야 한다. 기간 축소 여부는 사용자 결정 |
| `02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql` 47행 | 사용자명 `TRIALADMIN` 하드코딩 | §0-3 |

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
