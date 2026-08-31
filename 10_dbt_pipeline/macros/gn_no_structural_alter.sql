-- dbt 의 자동 컬럼 타입 확장(ALTER)을 무효화한다 — 구조 정본은 DDL(GN_DW_ADMIN) 이다.
-- Co-authored with CoCo
{#
  gn_no_structural_alter — `snowflake__alter_column_type` 오버라이드 (2026-08-30 O121 신설)

  🔴🔴 무엇을 막는가
    dbt 의 incremental materialization 은 매 run 임시뷰를 만든 뒤
    **`adapter.expand_target_column_types()`** 를 호출한다. 이 호출은 임시뷰의 VARCHAR 폭이
    대상 테이블보다 넓으면 `ALTER TABLE … ALTER <col> SET DATA TYPE varchar(N)` 을 발행한다.
    ⚠️ 이 호출은 **`on_schema_change` 설정과 무관하다**(그 설정은 컬럼 추가/삭제 경로다)
       ⇒ `ignore` 로 바꿔도 막히지 않는다. 2026-08-30 실측으로 확인했다.

  🔴 왜 막아야 하는가
    ALTER 는 OWNERSHIP 을 요구하고 dbt 롤(GN_DW_ENGINEER)에는 없다 — 그게 **설계**다
    (구조·타입·COMMENT·FK 소유 = 04/06/08 DDL · `07_ENVIRONMENT_RBAC_setup.sql` §D.5).
    ⇒ 막지 않으면 SILVER/GOLD 11개 모델이 `003001 … must have MODIFY granted on TABLE` 로 죽는다
      (2026-08-30 실측: CRM 5 · ERP 1 · GA4 2 · GOLD 3).
    ⇒ 반대로 권한을 주면 dbt 가 DDL 이 정한 폭(예: `VARCHAR(50)`)을 원천 폭(`VARCHAR(16777216)`)으로
      **말없이 넓혀 간다** ⇒ 타입 정본이 DDL 에서 dbt 로 넘어간다. 그것도 받아들일 수 없다.

  🟢 왜 no-op 이 안전한가
    · 이 매크로는 **타입 변경 경로만** 무효화한다. 컬럼 **추가** 경로
      (`alter_relation_add_remove_columns` ← `on_schema_change: append_new_columns`)는 그대로 살아 있다
      ⇒ O95 가 넣은 「신규 컬럼 무증상 폐기」 방어(`P82`)는 **손상되지 않는다**.
    · 폭을 넓히지 않아도 INSERT 는 정상 동작한다 — 값이 DDL 폭에 실제로 안 맞을 때만 실패한다.
      즉 「폭이 다르다」는 이유로 죽는 것을 멈추고, 「값이 안 맞는다」는 진짜 결함만 남긴다.
      🟢 실측(2026-08-30) = `CRM_PAYMENT_BILLING` 이 RQEST_RST_CD ALTER 를 건너뛴 상태로 **47,521,872행 적재 성공**.
    · 무엇을 건너뛰었는지 `log(info=True)` 로 남긴다.
      🔴🔴 어디서 보이는지 주의하라(2026-08-30 실측으로 정정):
        · 보인다   = `EXECUTE DBT PROJECT` 가 반환하는 **STDOUT**(Snowsight 실행 결과 창).
                     예) `[gn_no_structural_alter] SKIPPED: alter table GN_DW.SILVER.CRM_PAYMENT_BILLING …`
        · 안 보인다 = **`SYSTEM$GET_DBT_LOG(<query_id>)`** — 이 함수가 돌려주는 스트림에는 이 줄이 **없다**
                     (실측: 같은 run 의 STDOUT 1,163행 vs GET_DBT_LOG 1,002행 · 매칭 0건).
        ⇒ 드리프트를 조사할 때 GET_DBT_LOG 만 보고 「없다」고 결론내지 말 것.
        ⚠️ 워크스페이스 실행(`EXECUTE DBT PROJECT FROM 'snow://workspace/…'`)은 GET_DBT_LOG 자체가
           `Operation not supported for WORKSPACE DBT runs` 로 막힌다 ⇒ STDOUT 이 유일한 경로다.

  🔴 그래서 드리프트를 어떻게 해소하는가 — 이 매크로는 **증상 차단이지 해소가 아니다.**
    로그에 SKIPPED 가 보이면 절차는 종전과 같다: ① DDL 수정 ② ALTER 실행(ADMIN) ③ INFORMATION_SCHEMA 확인.
    교차검증(차이 0 이 정상) = 모델 SELECT 를 임시뷰로 만들어 대상 테이블과 INFORMATION_SCHEMA 비교.

  ── 미해소 드리프트 재고(2026-08-30 실측 · 이 매크로가 억제하고 있는 것) ─────────────────
    아래 11개 모델이 각각 **최소 1개** 컬럼에서 DDL 보다 넓은 타입을 산출한다.
      SILVER.CRM_PAYMENT_BILLING     RQEST_RST_CD        → varchar(50)
      SILVER.CRM_SEND_REQUEST        TIT                 → varchar(255)
      SILVER.CRM_SEND_MEMBER         MBER_NO             → varchar(255)
      SILVER.CRM_EVENT               EVENT_DIV_GROUP     → varchar(16777216)
      SILVER.CRM_EVENT_PARTICIPATION PARTCPT_STAT_GROUP  → varchar(16777216)
      SILVER.ERP_BUDGET              MONTH_KEY           → varchar(16777216)
      SILVER.GA4_EVENT               USER_ID_FILLED      → varchar(16777216)
      SILVER.GA4_IDENTITY            GA_MEMBER_ID        → varchar(16777216)
      GOLD.DIM_MEMBER                PREV_MBER_STAT_CD   → varchar(16777216)
      GOLD.FACT_MEMBER_EVENT         AREA_CD_AT_EVENT    → varchar(16777216)
      GOLD.FACT_MEMBER_SPONSOR_BIZ   SPNSR_NO            → varchar(16777216)
    ⚠️ 위 목록은 **모델당 첫 번째** 컬럼만이다 — 종전 run 은 각 모델의 첫 ALTER 에서 죽어 그 뒤를 못 봤다.
       모델별 전체 목록을 보려면 `build --select <모델>` 을 돌려 STDOUT 의 SKIPPED 줄을 전부 읽어라.
       🔴 `--empty` 로 싸게 떠보려 하지 말 것 — SILVER pre-hook 이 TRUNCATE 라서 **적재 데이터가 날아간다.**
    🟢 해소 완료 사례 = `GA4_BASIC`(12컬럼 CAST 로 차이 0 달성 · 그 파일 헤더 참조). 나머지 11개도 같은 방식으로 처리한다.
    🟢 참고로 `CRM_BIZ_TARGET` 은 처음부터 `CAST(NULL AS …)` 로 DDL 타입을 맞춰 둔 모델이다 — 이 프로젝트의 기존 관례다.

  ⚠️ 이 파일을 지우면 11개 모델이 즉시 다시 죽는다. 지우려면 먼저 DDL 폭을 원천에 맞추거나
     dbt 롤에 구조 권한을 주는 결정을 해야 한다(둘 다 설계 변경이다).
#}
{% macro snowflake__alter_column_type(relation, column_name, new_column_type) -%}
  {%- do log(
        "[gn_no_structural_alter] SKIPPED: alter table " ~ relation ~ " alter \"" ~ column_name
        ~ "\" set data type " ~ new_column_type
        ~ "  — 구조 정본은 DDL(GN_DW_ADMIN). 필요하면 DDL 을 고치고 사람이 ALTER 하라.",
        info=True) -%}
{%- endmacro %}
