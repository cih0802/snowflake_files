# MSTR 일일 적재 — dbt 연동 준비안 (🟢 O207-C 확정 · 2026-10-07)

작성: 2026-10-06 · O203 · 계정 JU93656(개발계) 실측 기준

> 🟢 **[O207-C 확정 · 사용자 결정 「MSTR 일일적재 확정」]** 방식 = **C안(Task · dbt 일 배치 Task 의 `AFTER`)** ·
> 정본 DDL = `snowflake 적용 ddl/07_MSTR_일일적재_TASK.sql`.
> · 질문 「dbt 스케줄 6:01 · 약 1시간 → Task 07:00 고정?」 답 = 고정 07:00 보다 **dbt Task 완료 직후(AFTER)** 가 낫다
>   (dbt 지연·조기 종료에 자동 대응 · dbt 실패 시 MSTR 도 멈춰 두 기준의 기준일이 같다). 고정 시각이 불가피하면 **07:30 KST**.
> · 🔴 프로시저는 BRONZE_CRM 을 직접 읽는다(dbt 산출물 의존 없음) — dbt 뒤에 두는 이유는 같은 BRONZE 시점 정렬이다.
> · 🔴 일 배치 경로의 마트 DELETE 는 기준월 한정(`WHERE STRD_MT = :I_YM` · 라이브 GET_DDL 2026-10-07) ⇒ 전월·당월 2회 호출 안전.
> · 실측 = 1개 월 ≈ 23초(BCHLOG 2026-10-06 21:51:45 → 21:52:08) ⇒ 2개 월 ≈ 1분.
> · 남은 사람 작업 = 운영계에서 dbt Task FQN 확인 → [1] 실행 → `RESUME`(이 개발계 계정에는 dbt Task 가 없어 여기서 만들지 않았다).
>
> ~~🔴 **지금은 아무것도 적용하지 않는다.** 착수 조건 = 현업이 「MSTR 데이터를 쓰겠다」고 회신.~~ ➔ 🟢 [O207-C] 회신 = 확정.
> 회신이 오면 이 문서 §5 순서대로 진행한다. dbt 명령(`build`·`parse`)은 사람이 실행한다(`R4-1`).
> 함께 볼 것: MSTR 결과를 다른 Agent 에 붙일지(B안 전환)는 `MSTR_1차이관_Snowflake전환_작업계획.md` §9 에서 따로 묻는다.

## 1. 목표

- 매일 dbt 일 배치가 끝난 뒤 MSTR 집계를 **전월 + 당월 2개 월만** 다시 만든다.
- 마감된 과거 월(202401~전전월)은 매일 다시 돌리지 않는다 — 결과가 바뀌지 않는다.
- 근거: 프로시저 1회 = 1개 월 · 개발계 실측 월당 약 30초(Small) ⇒ 2개 월 ≈ 1분. 202401 부터 전체를 매일 돌리면 33개월 × 30초 ≈ 16~17분.

## 2. 현재 상태 (2026-10-06 실측)

| 항목 | 값 |
|---|---|
| 프로시저 | `GN_DW.MSTR.USP_RUN_MSTR_1ST(VARCHAR 월, VARCHAR 실행구분, BOOLEAN 이력)` → VARCHAR |
| 프로시저 소유 역할 | GN_DW_ADMIN · `EXECUTE AS OWNER`(확인 완료) |
| dbt 실행 역할 | GN_DW_DBT — 🔴 **MSTR 스키마 권한 0건**(SHOW GRANTS TO ROLE GN_DW_DBT) |
| 원천 | BRONZE_CRM(`TM_MM_FDRM_MBER_DVLP_AMT` 등) — dbt 가 BRONZE 를 만들지 않는다(BRONZE 적재는 dbt 앞단) |
| 1회 적재 범위 | `06_MSTR_적재_실행.sql` [2] — 🔴 워크스페이스 파일은 시작월 `'202601'` · 운영계는 `'202401'` 로 변경됨(사용자 확인) ⇒ 착수 시 파일도 맞춘다 |
| 개발계 Task | 없음(SHOW TASKS IN DATABASE GN_DW = 0건) — 운영계 dbt 일 배치 Task 이름·시각은 이 계정에서 보이지 않는다 |

## 3. 방식 비교

| 안 | 방법 | 장점 | 주의 |
|---|---|---|---|
| **A. dbt `on-run-end` hook** | `dbt_project.yml` 의 `on-run-end` 에서 매크로가 프로시저를 2번 CALL | 한 작업으로 끝난다 · dbt 로그에 같이 남는다 | 🔴 `--select` 부분 실행·`dbt test` 에서도 돈다(조건 필요) · 프로시저가 실패하면 dbt 실행 전체가 실패로 표시된다 · dbt 역할에 MSTR 권한 부여 필요 |
| **B. dbt `run-operation`** | 매크로만 두고 일 배치 Task 에서 `build` 다음에 `run-operation mstr_daily_refresh` 를 한 번 더 실행 | build 와 실패가 분리된다 · 부분 실행에 안 걸린다 | dbt 실행이 2번(EXECUTE DBT PROJECT 2회) · 권한은 A 와 같다 |
| **C. Snowflake Task (AFTER dbt Task)** | 일 배치 dbt Task 뒤에 `AFTER` 로 MSTR Task 를 잇는다 | dbt 프로젝트를 건드리지 않는다 · 역할 그대로(GN_DW_ADMIN) · 실패가 독립 | dbt 밖이라 「dbt build 에 포함」은 아니다 |

- 🟢 **권고 = B(또는 C)**. 사용자 의도(「dbt 에 포함」)에 맞추면 **B**, 운영 단순성은 **C**.
- 🔴 A 는 비권고 — `on-run-end` 는 `dbt test`·`dbt run --select X` 처럼 일부만 돌릴 때도 실행돼 MSTR 이 의도치 않게 다시 적재된다. 꼭 A 로 하려면 §4-1 의 조건(`flags.WHICH == 'build'` + var 스위치)을 반드시 넣는다.

## 4. 준비물 (착수 시 그대로 쓰는 초안 · 지금은 파일로 만들지 않는다)

### 4-1. 매크로 초안 — `10_dbt_pipeline/macros/mstr_daily_refresh.sql`

```sql
{% macro mstr_daily_refresh() %}
  {#- O203 준비안: 전월·당월 2개 월만 MSTR 재적재. var mstr_daily=true 일 때만 동작 -#}
  {% if not var('mstr_daily', false) %}
    {{ log('mstr_daily_refresh: skip (var mstr_daily=false)', info=True) }}
    {% do return('') %}
  {% endif %}
  {% set months = run_query("SELECT TO_CHAR(DATEADD(MONTH,-1,CURRENT_DATE()),'YYYYMM') AS PREV_YM, TO_CHAR(CURRENT_DATE(),'YYYYMM') AS CUR_YM") %}
  {% for ym in [months.columns[0].values()[0], months.columns[1].values()[0]] %}
    {% set res = run_query("CALL GN_DW.MSTR.USP_RUN_MSTR_1ST('" ~ ym ~ "', 'TASK', FALSE)") %}
    {% set ret = res.columns[0].values()[0] %}
    {{ log('mstr_daily_refresh ' ~ ym ~ ' = ' ~ ret, info=True) }}
    {% if 'ERROR' in ret %}
      {{ exceptions.raise_compiler_error('MSTR 적재 실패 ' ~ ym ~ ' : ' ~ ret) }}
    {% endif %}
  {% endfor %}
{% endmacro %}
```

- B안 실행 = `run-operation mstr_daily_refresh --vars '{"mstr_daily": true}'`
- A안으로 바꿀 때만 `dbt_project.yml` 에 아래를 추가한다:
  ```yaml
  on-run-end:
    - "{% if flags.WHICH == 'build' %}{{ mstr_daily_refresh() }}{% endif %}"
  ```

### 4-2. 권한 (A·B 공통 · GN_DW_ADMIN 또는 SECURITYADMIN 실행)

```sql
GRANT USAGE ON SCHEMA GN_DW.MSTR TO ROLE GN_DW_DBT;
GRANT USAGE ON PROCEDURE GN_DW.MSTR.USP_RUN_MSTR_1ST(VARCHAR, VARCHAR, BOOLEAN) TO ROLE GN_DW_DBT;
```

- 🟢 확인 완료(2026-10-06 · DESCRIBE PROCEDURE): **`execute as = OWNER`** · 소유 GN_DW_ADMIN ⇒ 위 2개 GRANT 로 충분하다(MSTR 테이블 DML·BRONZE 조회는 소유자 권한으로 돈다).

### 4-3. C안 Task 초안 (운영계 · dbt Task 이름 확인 후)

```sql
CREATE TASK GN_DW.MSTR.TSK_RUN_MSTR_DAILY
  WAREHOUSE = GN_DW_ETL_WH
  AFTER <운영계 dbt 일 배치 Task FQN>
AS
BEGIN
  CALL GN_DW.MSTR.USP_RUN_MSTR_1ST(TO_CHAR(DATEADD(MONTH,-1,CURRENT_DATE()),'YYYYMM'), 'TASK', FALSE);
  CALL GN_DW.MSTR.USP_RUN_MSTR_1ST(TO_CHAR(CURRENT_DATE(),'YYYYMM'), 'TASK', FALSE);
END;
-- ALTER TASK GN_DW.MSTR.TSK_RUN_MSTR_DAILY RESUME;   -- 생성 후 별도 승인
```

## 5. 착수 순서 (현업 회신 후)

1. 방식 선택(B 또는 C · A 는 조건 필수) — 사용자 결정.
2. `06_MSTR_적재_실행.sql` [2] 시작월을 운영계와 같게 `'202401'` 로 맞춘다(재구축 시 범위 일치).
3. 권한 부여(B · §4-2) 또는 Task 생성(C · §4-3).
4. B 면 §4-1 매크로 파일 생성 → 👤 `dbt parse` → 👤 일 배치에 `run-operation` 추가.
5. 첫 실행 후 검증 = `06_MSTR_적재_실행.sql` [3] · `BCHLOG` 최근 2행 OK · `mstr_verify.py --ym <당월>`.
6. 이때 `MSTR_1차이관_Snowflake전환_작업계획.md` §9 대로 **B안(AGENT_MEMBER 에 MSTR 도구) 전환 여부를 함께 묻는다.**
7. 원장 §1 행 기록(라이브 변경 D6).

## 6. 확인 필요 (착수 시)

- 운영계 dbt 일 배치 Task 이름·실행 시각(이 계정에서 보이지 않음).
- 프로시저는 호출마다 차원 7종(공통코드·달력·부서·브랜드·캠페인·후원사업·개발목표)을 함께 다시 만든다 ⇒ 2개 월 호출 시 차원 재적재 2회(결과 동일 · 시간만 추가).
- 실행구분 인자(`I_OPER`)는 하위 프로시저로 전달된다 — 기존 사용값 `OPER`·`TASK` 만 쓴다(초안은 `TASK`).
- 월초(1일) 실행 시 「당월」은 데이터가 거의 없다 — 전월 마감 반영이 주목적임을 현업과 공유.
