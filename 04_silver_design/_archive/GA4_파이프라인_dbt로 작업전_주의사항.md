# GA4 파이프라인 작업 전 주의사항 (dbt 버전)

> 작성일: 2026-07-02 · 대상: Bronze_GA4 → Silver GA4 dbt 파이프라인 개발자
> 짝 문서: `GA4_파이프라인_SP로 작업전_주의사항.md` (Stored Procedure 버전)
> 방식: **C-2 — dbt + 프로젝트 내장 커스텀 매크로 (외부 패키지 無)**

---

## 0. 이 방식을 택한 이유 (trial 제약)

| 항목 | 사실 | 근거 |
|------|------|------|
| dbt 자체 | ✅ trial 사용 가능 | `dbt compile/run/docs`는 EAI 불필요 |
| `dbt deps` (dbt_utils 등) | ❌ trial 불가 | **EXTERNAL ACCESS INTEGRATION이 trial 미지원**(2026-07-02 실측 확인) |
| 결론 | **외부 패키지 없이 커스텀 매크로로 자립** | `run_query`로 `dbt_utils.get_relations_by_pattern` 대체 |

> ⚠️ `packages.yml`에 `dbt_utils`를 넣고 `dbt deps`를 돌리면 **trial에서 실패**한다. 서비스 계정 이전 시 동일 코드가 그대로 동작하도록 **처음부터 외부 의존 없이** 개발한다.

---

## 1. Bronze 구조 — date-shard 고정 (dbt로 처리)

- `BRONZE_GA4.EVENTS_YYYYMMDD` 날짜별 테이블 (개발환경 제약, 유지)
- date-shard여도 dbt로 처리 가능 — **커스텀 매크로가 `INFORMATION_SCHEMA` 동적 조회 후 UNION 조립**
- 테이블 목록 하드코딩 금지

```sql
-- macros/ga4_union_shards.sql  (dbt_utils.get_relations_by_pattern 대체)
{% macro ga4_union_shards(start_date, end_date) %}
  {% set q %}
    SELECT table_name FROM {{ target.database }}.INFORMATION_SCHEMA.TABLES
    WHERE table_schema = 'BRONZE_GA4' AND table_name LIKE 'EVENTS_%'
      AND REPLACE(table_name,'EVENTS_','') BETWEEN '{{ start_date }}' AND '{{ end_date }}'
    ORDER BY table_name
  {% endset %}
  {% if execute %}
    {% set tabs = run_query(q).columns[0].values() %}
    {% for t in tabs %}
      SELECT * FROM {{ target.database }}.BRONZE_GA4.{{ t }}
      {% if not loop.last %}UNION ALL{% endif %}
    {% endfor %}
  {% endif %}
{% endmacro %}
```

> `{% if execute %}` 가드 필수 — parse 단계에서 `run_query` 실행 방지.

---

## 2. 증분 전략 — incremental + GA4 72시간 보정 필수

GA4는 이벤트 발생 후 **최대 72시간(D+3)** 소급 수정된다.
dbt `incremental`이라도 "신규 날짜만"이 아니라 **D-3까지 재처리**해야 오래된 값이 안 남는다.

```sql
-- models/silver/ga4/ga4_event.sql
{{ config(
    materialized='incremental',
    unique_key=['USER_PSEUDO_ID','EVENT_TIMESTAMP','EVENT_NAME','BATCH_ORDERING_ID'],
    incremental_strategy='merge'
) }}

WITH src AS (
  {% if is_incremental() %}
    {{ ga4_union_shards(
        (modules.datetime.date.today() - modules.datetime.timedelta(days=3)).strftime('%Y%m%d'),
        (modules.datetime.date.today() - modules.datetime.timedelta(days=1)).strftime('%Y%m%d')
    ) }}
  {% else %}
    {{ ga4_union_shards('20000101', '99991231') }}   -- 최초 전체 적재
  {% endif %}
)
SELECT ... FROM src e, LATERAL FLATTEN(input => e.event_params) p
GROUP BY ...
```

| 실행 | 범위 | 동작 |
|------|------|------|
| 최초 (full) | 전체 날짜 | 모든 shard UNION |
| 증분 (is_incremental) | D-3 ~ D-1 | 최근 shard만 + `merge`로 기존 보정 |

> **`merge` 전략 + `unique_key`** 로 D-3 이내 갱신분이 덮어써짐 (delete+insert 불필요).

---

## 3. dbt 주의사항

| 항목 | 내용 |
|------|------|
| **외부 패키지 금지** | `dbt_utils`·`packages.yml` 사용 금지 (trial EAI 불가). 커스텀 매크로만 |
| **`{% if execute %}`** | `run_query` 매크로는 반드시 execute 가드로 감쌀 것 |
| **incremental 로직 수정 시** | 로직 변경 후 반드시 `--full-refresh` 재실행 (기존 잘못된 데이터 잔존) |
| **VARCHAR 필수** | `USER_ID`(회원번호) 선행0·S접두 보존 — **NUMBER 캐스팅 절대 금지** |
| **컬럼 불일치** | 날짜별 스키마 차이 시 UNION ALL 실패 가능 → VARIANT는 흡수, 스칼라 추가 시 Bronze `ALTER TABLE ADD COLUMN` 선행 |
| **UNION 범위** | 최초 full-refresh 외 증분은 D-3~D-1(3일)만 — 성능 보호 |

---

## 4. 처리 대상 Silver 모델 (5개 · materialized 전략)

```
① ga4_traffic_source  materialized=table        ← session_traffic_source_last_click DISTINCT
② ga4_event_dim       materialized=table        ← event_params FLATTEN → cat/label/action DISTINCT
③ ga4_device          materialized=table        ← device + platform → PC/M/APP DISTINCT
④ ga4_event           materialized=incremental  ← 전체 FLATTEN (메인·72h merge)
⑤ ga4_identity        materialized=table        ← user_id 접두사 분기 (Q1 행매칭 실증 후 활성화)
```

> ①②③⑤ 는 DISTINCT 소량이라 `table` 전체 재생성이 단순·안전. ④만 `incremental`.

---

## 5. ERD 이점 (dbt 방식 고유)

- `dbt docs generate` → `manifest.json` + `catalog.json` 생성 (trial 가능, EAI 불필요)
- 로컬에서 `dbterd`로 CRM 21 + GA4 5 + Gold 24 = **전체 50개 모델 ERD** 생성
- ⚠️ **FK 화살표**는 `schema.yml`에 `relationships` 테스트를 정의해야 나옴 (컬럼 인벤토리 CSV 기반으로 이관)

```yaml
# models/silver/schema.yml (관계선용)
models:
  - name: ga4_event
    columns:
      - name: UTM_SOURCE
        tests:
          - relationships: { to: ref('ga4_traffic_source'), field: UTM_SOURCE }
```

---

## 6. 착수 전 선결 확인

- [ ] Bronze 전체 기간 날짜별 CSV 적재 완료 여부
- [ ] `BRONZE_GA4.GA4_CSV_FMT` 파일 포맷 존재 확인
- [ ] Silver 테이블 26개 DDL 생성 완료 (`SILVER_DDL_20260702.sql`) — 또는 dbt `materialized`로 대체 생성
- [ ] **`packages.yml` 없이** 프로젝트 구성 (trial EAI 불가 재확인)
- [ ] `profiles.yml` — account·user 빈 문자열, `env_var()` 금지, password 계열 금지
- [ ] 대상 스키마(`GN_DW.SILVER`) 사전 생성
- [ ] GA4_IDENTITY는 Q1 행매칭 실증 전까지 실행 대상에서 **제외**
- [ ] incremental 로직 수정 시 `--full-refresh` 재실행 원칙 숙지

---

## 부록: SP 버전과의 선택 기준

| | SP 버전 (C-1) | dbt 버전 (C-2, 본 문서) |
|--|--|--|
| 진입 장벽 | 낮음 (SQL만) | dbt 프로젝트 구성 필요 |
| 리니지·ERD | 수동 | **manifest.json → dbterd 자동** |
| 테스트 | 직접 구현 | **dbt test 내장** |
| 외부 의존 | 없음 | 없음 (커스텀 매크로) |
| trial 동작 | ✅ | ✅ |
| 추천 상황 | 빠른 구축 | 리니지·문서화·장기 유지보수 |
