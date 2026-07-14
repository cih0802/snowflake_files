# GA4 일별 샤드 → SILVER 통합 설계 결정서

**대상 독자**: SILVER GA4 모델 개발·운영자, GOLD FACT_GA_BEHAVIOR 담당자
**작성일**: 2026-07-03
**짝 문서**:
- 구현 가이드 → `GA4_파이프라인_dbt로 작업전_주의사항.md` (dbt 매크로·증분·ERD)
- GOLD 의존성 → `03_top-down_gold/08_silver의존.md` §2·§3·§5

---

## 1. 설계 결정 배경

`BRONZE_GA4.EVENTS_YYYYMMDD`는 날짜마다 새 테이블이 생기고 Google이 컬럼 순서를 보장하지 않는 구조다. SILVER에서 이를 단일 모델로 통합할 때 두 가지 방식이 있다.

| 방식 | 설명 | 결과 |
|---|---|---|
| **A. 위치 기반** (`SELECT *`) | UNION ALL이 컬럼 순서로 정렬 | 날짜별 순서 차이 시 **데이터 오염** (잘못된 컬럼에 값 삽입, 에러 없이 조용히 발생) |
| **B. 이름 기반** (컬럼명 명시) | SELECT에서 컬럼명을 명시적으로 나열 | 순서 변동 무관, SILVER 출력 스키마 고정 |

**결정: 방식 B를 채택한다.**

---

## 2. 핵심 수정 — 기존 dbt 매크로의 `SELECT *` 제거

`GA4_파이프라인_dbt로 작업전_주의사항.md`의 `ga4_union_shards` 매크로는 현재 `SELECT *`를 사용한다. 이것은 위에서 설명한 위치 기반 문제를 내포한다. **컬럼명 명시 SELECT로 교체해야 한다.**

### 수정 후 매크로 패턴

```sql
-- macros/ga4_union_shards.sql
{% macro ga4_union_shards(start_date, end_date) %}
  {% set q %}
    SELECT table_name
    FROM {{ target.database }}.INFORMATION_SCHEMA.TABLES
    WHERE table_schema = 'BRONZE_GA4'
      AND table_name LIKE 'EVENTS_%'
      AND REPLACE(table_name,'EVENTS_','') BETWEEN '{{ start_date }}' AND '{{ end_date }}'
    ORDER BY table_name
  {% endset %}
  {% if execute %}
    {% set tabs = run_query(q).columns[0].values() %}
    {% for t in tabs %}
      SELECT
        event_date, event_timestamp, event_name,
        event_params,          -- VARIANT: LATERAL FLATTEN은 model에서
        event_previous_timestamp, event_value_in_usd,
        event_bundle_sequence_id, event_server_timestamp_offset,
        user_id, user_pseudo_id, user_first_touch_timestamp,
        privacy_info, user_properties, user_ltv,
        device, geo, app_info, traffic_source,
        stream_id, platform, is_active_user,
        event_dimensions, ecommerce, items,
        collected_traffic_source,
        session_traffic_source_last_click,
        publisher,
        batch_event_index, batch_page_id, batch_ordering_id
      FROM {{ target.database }}.BRONZE_GA4.{{ t }}
      {% if not loop.last %}UNION ALL{% endif %}
    {% endfor %}
  {% endif %}
{% endmacro %}
```

> **⚠️ 컬럼 추가 시**: Google이 BRONZE에 신규 컬럼을 추가해도 위 매크로는 무시한다. 필요 시 매크로와 SILVER DDL을 **동시에** 의도적으로 업데이트할 것 (자동 전파 차단 = 의도된 설계).

---

## 3. 이 결정이 GOLD 계약에 미치는 영향 (검증 완료)

`03_top-down_gold/08_silver의존.md`를 기준으로 GOLD→SILVER 의존성을 검토한 결과:

### 영향 없음 — 이유

dbt 샤드 통합은 **BRONZE→SILVER** 구간의 일이다. GOLD는 SILVER의 출력 스키마(테이블명·컬럼)에만 의존하며 BRONZE 샤드가 몇 개인지 알 필요가 없다.

| GOLD 객체 | 의존 SILVER | 영향 |
|---|---|---|
| `FACT_GA_BEHAVIOR` | `GA4_EVENT` | 없음 — 샤드 UNION은 일별 행 stacking일 뿐, grain 유지 ✓ |
| `DIM_GA_SOURCE` | `GA4_TRAFFIC_SOURCE` | 없음 ✓ |
| `DIM_GA_EVENT` | `GA4_EVENT_DIM` | 없음 ✓ |
| `DIM_DEVICE` | `GA4_DEVICE` | 없음 ✓ |
| `DIM_MEMBER_IDENTITY` (IDENTITY_SK) | `GA4_IDENTITY` | 없음 ✓ |

### 단, 아래 전제가 지켜져야 함

**SILVER 5개 GA4 모델의 출력 컬럼 스키마가 `SILVER_DDL_20260702.sql`과 일치해야 한다.**

- `SELECT *` 매크로를 그대로 두면 날짜별 컬럼 순서 오염이 SILVER까지 전파 → GOLD가 잘못된 컬럼을 읽음.
- 위 §2의 명시적 컬럼 매크로로 교체하면 SILVER 출력이 스키마에 고정 → GOLD 계약 안정.
- VARIANT 평탄화 결과(`event_params` FLATTEN → GA4_EVENT의 세부 컬럼)도 SILVER DDL과 일치하도록 model에서 명시적으로 매핑할 것.

---

## 4. BRONZE→SILVER GA4 변환 레이어 구조 (요약)

```
BRONZE_GA4.EVENTS_YYYYMMDD (N개, 날짜별 샤드)
        │
        │ ga4_union_shards 매크로
        │ (컬럼명 명시 UNION ALL)
        ▼
  ┌────────────────────────────────────────────────────┐
  │  dbt 모델 (SILVER)                                  │
  │  ① GA4_TRAFFIC_SOURCE  materialized=table          │
  │  ② GA4_EVENT_DIM       materialized=table          │
  │  ③ GA4_DEVICE          materialized=table          │
  │  ④ GA4_EVENT           materialized=incremental    │  ← LATERAL FLATTEN 포함
  │  ⑤ GA4_IDENTITY        materialized=table (조건부) │
  └────────────────────────────────────────────────────┘
        │
        ▼ (08_silver의존.md §2 기준)
  GOLD: FACT_GA_BEHAVIOR, DIM_GA_SOURCE, DIM_GA_EVENT,
        DIM_DEVICE, DIM_MEMBER_IDENTITY
```

---

## 5. 체크리스트 (SILVER GA4 모델 개발 착수 전)

- [ ] `ga4_union_shards` 매크로에서 `SELECT *` 제거 → 컬럼명 명시 버전으로 교체
- [ ] 매크로 출력 컬럼 목록이 `SILVER_DDL_20260702.sql`의 GA4 테이블 정의와 일치하는지 대조
- [ ] VARIANT 평탄화(`event_params` FLATTEN) 결과가 GOLD `FACT_GA_BEHAVIOR`의 grain(DATE_SK×IDENTITY_SK×GA_EVENT_SK×GA_SOURCE_SK×DEVICE_SK×CAMPAIGN_SK×PAGE_PATH)에 필요한 컬럼을 모두 생성하는지 확인
- [ ] `GA4_IDENTITY` 모델은 행매칭(CRM MEMBER_DK↔GA user_id) 실증 완료 전까지 비활성(08_silver의존.md §3 cross-source 조인 전제)
- [ ] 컬럼 추가 시 매크로 + SILVER DDL + 필요 시 GOLD DDL 동시 변경 (GOLD 의존 고려)

---

## 6. 관련 문서 맵

| 문서 | 역할 |
|---|---|
| `GA4_파이프라인_dbt로 작업전_주의사항.md` | dbt 구현 가이드 (매크로 코드, 증분 전략, ERD, trial 제약) |
| **본 문서** | 설계 결정 근거 + GOLD 의존성 영향 검증 |
| `03_top-down_gold/08_silver의존.md` | GOLD 컬럼 → SILVER 전체 lineage 정본 |
| `SILVER_DDL_20260702.sql` | SILVER 물리 스키마 (GA4 5 + CRM 21) |

*Co-authored with CoCo*
