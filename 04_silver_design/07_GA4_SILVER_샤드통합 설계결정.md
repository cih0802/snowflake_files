# GA4 일별 샤드 → SILVER 통합 설계 결정서

**대상 독자**: SILVER GA4 모델 개발·운영자, GOLD FACT_GA_BEHAVIOR 담당자
**작성일**: 2026-07-03
**짝 문서**:
- 구현 가이드 → `07_GA4_파이프라인_dbt로 작업전_주의사항.md` (dbt 매크로·증분·ERD)
- GOLD 의존성 → `03_top-down_gold/08_silver의존.md` §2·§3·§5

> **[2026-07-10 실적재 검증 반영]**
> - **샤드 현황**: `BRONZE_BIGQUERY.events_20260501` 1일 샤드만 적재(287,025행). **전체 기간 아님** — 다일 샤드 UNION 실증은 미완, 나머지 샤드 입고 후 §2 매크로로 재검증 필요.
> - **컬럼 안정성**: 실적재 30컬럼이 §2 매크로 나열과 정합(단 `app_info`·`event_dimensions`·`publisher`는 실적재상 NUMBER/NULL 계열 — VARIANT FLATTEN 대상 아님, model 매핑 시 주의).
> - 🟥 **`user_id` 채움률 = 4.2%**(12,120/287,025·식별회원 1,290명·익명 95.8%·`user_pseudo_id` distinct 27,840). **`GA4_IDENTITY`/`DIM_MEMBER_IDENTITY` 조인키(G-1)는 유효하나 커버리지가 낮음** → 회원단위 GA 지표(#81·신#32·#33)는 로그인 세션만 커버. §5 체크리스트에 커버리지 측정 항목 추가(아래).

---

> ## 🔴🔴 [2026-08-18 O86] 본 문서의 §1·§2·§4·§5 는 **폐기·대체**됐다 — 먼저 읽어라
>
> **G-5 가 해소됐고, 그 결과 「일별 샤드를 SILVER 에서 UNION 한다」는 전제 자체가 사라졌다.**
>
> ### 무엇이 바뀌었나
> BRONZE 가 **일별 911테이블이 아니라 통합 1테이블**로 적재됐다.
> `GN_DW.BRONZE_BIGQUERY.EVENTS` = **285,676,588행 / 911일**(`events_20240101`~`events_20260719` · 결번 0)
> · 6,517파일 · 통제총계 대조 **911건 전수 일치 · 불일치 0**. 정본 = `50_handoff/07_동적적재_GA4_EVENTS.sql`(2판).
>
> ⇒ **`ga4_union_shards` 매크로는 폐기한다.** SILVER 는 샤드를 열거하지 않고
> `EVENTS` 를 `WHERE EVENT_DT BETWEEN ...` 으로 읽는다. §2 의 매크로 코드는 **역사 기록**이다.
>
> ### 왜 BRONZE 에서 통합했나 (§1 의 A/B 논쟁이 무의미해진 이유)
> §1 은 *"Google 이 컬럼 순서를 보장하지 않는다"* 를 전제로 위치기반(A) 을 위험하다고 판정했다.
> **전제가 실측으로 반증됐다** — 원천 스키마 변화는 **전부 꼬리 추가(additive prefix)** 였다:
> **25 ⊂ 28 ⊂ 29 ⊂ 30 ⊂ 31 컬럼** · 앞쪽 컬럼의 순서·이름이 바뀐 적이 **한 번도 없다**
> (폴더별 CSV 헤더 DISTINCT = 1 · 혼재 0건). 그래서 31컬럼 상위집합 **1테이블**로 전 기간을
> 위치 기반 적재할 수 있었다(초과 위치 참조 = 오류가 아니라 NULL).
> 🟢 **사후 확증** — `session_traffic_source_last_click` 최초 비-NULL 이 **`events_20250426`** 으로,
> 15번 DDL 에서 독립 도출한 VARIANT 구간 시작일과 **정확히 일치**했다. 컬럼이 한 칸이라도
> 밀렸다면 이 경계가 어긋난다 ⇒ 911폴더 전체의 위치 정렬 확증.
> ⚠️ 단 **방어선은 유지해야 한다** — 파일 포맷 옵션은 컬럼수 드리프트를 막지 못한다(실측).
> 유일한 방어선 = 07번 §8 헤더 접두 검사(`STARTSWITH`). 신규 폴더 추가 시 반드시 1회 실행.
>
> ### 새 BRONZE 계약 (SILVER 가 읽어야 하는 것)
> | 컬럼 | 용도 |
> |---|---|
> | 1~31 | 원천 31컬럼 상위집합. 컬럼명·순서·타입 = `events_20260719` 와 동일 |
> | `SRC_TABLE` | 원본 일별 테이블명(`events_YYYYMMDD`). 원천 대조 키 |
> | `EVENT_DT` | DATE. **모든 SILVER 조회는 이 컬럼으로 범위 제한할 것**(프루닝 키) |
> | `SRC_FILE_NAME` | 파일 단위 계보. 중복 적재 검출용 |
> | `LOAD_TS` | 적재 배치 식별(업무일자 `EVENT_DT` 와 구분) |
>
> 🟢 프루닝 실측 = 3,006 파티션 중 **19개(0.632%)** → BRONZE 측 `CLUSTER BY` 불필요 확정.
> 🔴 그러나 **SILVER 조회가 `EVENT_DT` 제한을 빼면 2.86억행 × VARIANT 11개를 전량 스캔**한다.
> 비용이 즉시 문제가 되므로 모델·테스트·DQ 전부에 범위 제한을 강제할 것.
>
> ### 🔴 SILVER 착수를 막는 신규 하드블로커 2건 (G-5 는 자동 해소가 아니었다)
> | ID | 내용 | 실측 |
> |---|---|---|
> | **GA4-PK-1** | §7-B 의 `GA4_EVENT` 복합 PK 4번째 키 `BATCH_ORDERING_ID`(NOT NULL)가 **2024 상반기를 배제**한다. 그 컬럼은 원천 `events_20240719` 부터 생겼다 | **2024-01-01~07-18 · 199일 · 48,862,926행 = 전체 17.10% 적재 불가**. 3키로 낮춰도 2024-06 기준 **3.679% 중복(238,454행)** 잔존 |
> | **GA4-LEN-1** | `GA4_EVENT.USER_ID VARCHAR(10)` 초과 + **CRM 조인 불가 ID 체계 혼재** | `user_id` **6종** — 7자리 CRM 399,773id · `S`+8자리 16,907id(§7-B Q1 `ONCE_MBER_NO`) · `app-`+32hex 233id · `app-`+uuid 8id · 이메일 1 · 문자열 `'null'` 1 ⇒ **12,690행 길이 초과 실패** |
>
> 조치 후보·상세 = `20_issue/90_해소완료_로그.md` §1-A. **결정 전에는 전기간 SILVER 적재 불가.**
>
> ### 🟠 예정 — SILVER 평탄화 통합 테이블
> 사용자 고지(2026-08-18): *"미래에 silver 에 이 bronze_bigquery 데이터를 평탄화한 통합 테이블이
> 생성될 예정"*. ⇒ 아래 §4 의 5모델 구조는 **그 통합 테이블로 재편될 수 있다.**
> 설계 시 전제 = ① 소스는 `EVENTS` 단일 ② `EVENT_DT` 파티션 키 유지 ③ `SRC_TABLE`·`SRC_FILE_NAME`
> 계보 컬럼을 SILVER 까지 승계(그러면 GA4-PK-1 의 tiebreaker 를 계보로 대체할 수 있다).
>
> ### 🟢 성능은 병목이 아니다 (실측)
> `GA4_EVENT` 2025-06 1개월 = `GN_DW_ETL_WH`(**Small**) **68초** ·
> bronze 9,028,480행 → SILVER **8,161,106행**(PK `GROUP BY` dedup **9.6%**).
> 전 기간 285,676,588행 환산 ≈ **36분**. ⇒ 막는 것은 성능이 아니라 위 2건이다.

---

## 1. 설계 결정 배경

`BRONZE_BIGQUERY.EVENTS_YYYYMMDD`는 날짜마다 새 테이블이 생기고 Google이 컬럼 순서를 보장하지 않는 구조다. SILVER에서 이를 단일 모델로 통합할 때 두 가지 방식이 있다.

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
    WHERE table_schema = 'BRONZE_BIGQUERY'
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
      FROM {{ target.database }}.BRONZE_BIGQUERY.{{ t }}
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
BRONZE_BIGQUERY.EVENTS_YYYYMMDD (N개, 날짜별 샤드)
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
- [ ] `GA4_IDENTITY` 모델은 행매칭(CRM MEMBER_DK↔GA user_id) 실증 완료 전까지 비활성(08_silver의존.md §3 cross-source 조인 전제) — **[2026-07-10] G-1 조인키 유효 확인. 단 `user_id` 채움률 4.2% 실측 → 활성화 시 커버리지(식별/전체) 지표를 DQ로 노출하고, 회원단위 GA 지표에 "로그인 세션 한정" 주석 필수. 전체 샤드 입고 후 채움률 재측정.**
- [ ] 컬럼 추가 시 매크로 + SILVER DDL + 필요 시 GOLD DDL 동시 변경 (GOLD 의존 고려)

---

## 5-A. USER_ID 세션 채움(session-fill) — 커버리지(D) 대응 설계

> 배경: `user_id` 채움률 **4.22%**(로그인 세션만). **같은 세션에 로그인 이벤트가 하나라도 있으면 그 세션 전체 행에 `user_id`를 전파**해 회원 귀속 커버리지를 올린다. (33 §B `SF` 항목의 구체화)

### 위치·원칙
- **SILVER에서 1회 계산**(GOLD 아님). 원본 `user_id`는 **불변 보존**(lineage), 채움 결과는 **파생 컬럼 신설**(원본 덮어쓰기 금지).
- **세션 키**: GA4 `ga_session_id`는 **`user_pseudo_id` 내에서만 유일** → 반드시 **복합키 `(user_pseudo_id, ga_session_id)`**. `ga_session_id` 단독 채움은 **다른 사용자 세션 오병합** → 금지.
- 산출 모델: `GA4_IDENTITY`(또는 신설 `GA4_SESSION_IDENTITY`), `GA4_EVENT`가 참조.

### 신설 컬럼 (깔끔한 DA 위한 최소 세트)
| 컬럼 | 내용 |
|---|---|
| `GA_SESSION_KEY` | `user_pseudo_id ∥ '-' ∥ ga_session_id` (세션 자연키) |
| `USER_ID` | 원본 보존 (불변) |
| `USER_ID_FILLED` | 세션 전파 결과 (회원 귀속·IDENTITY 조인용) |
| `ID_RESOLUTION` | enum: `DIRECT`(원본 有) / `SESSION_FILL`(전파) / `UNRESOLVED`(익명) / `CONFLICT`(세션 내 상이 user_id ≥2) |

### 채움 규칙 (결정성·오귀속 방지)
> 🔴 **구현 주의(SQL 오류 방지)**: Snowflake는 **`COUNT(DISTINCT x) OVER(...)` 윈도우 미지원**. `MAX(user_id) OVER(파티션)` 단독으로 채우면 **CONFLICT 세션이 조용히 오귀속**된다. **반드시 2단계**로 구현: ① 세션 집계 CTE `... GROUP BY GA_SESSION_KEY`에서 `COUNT(DISTINCT user_id) AS n_id`·`MAX(user_id) AS sess_uid` 산출 → ② 이벤트에 `GA_SESSION_KEY`로 LEFT JOIN.
- `n_id = 1` → `ID_RESOLUTION='SESSION_FILL'`, `USER_ID_FILLED = COALESCE(USER_ID, sess_uid)`
- `n_id = 0` → `UNRESOLVED`(익명) · 원본 有 = `DIRECT`
- `n_id ≥ 2`(공유기기/재로그인) → **`CONFLICT` = 미채움**(원본만 유지). tie-break은 옵션(아래 4).
- ⚠️ `ga_session_id`는 `event_params`(VARIANT) 추출값(`GA4_EVENT` FLATTEN 후) → **세션 키 계산은 param 추출 이후**. `ga_session_id`가 없는 이벤트는 세션 불명 → `UNRESOLVED` 고정.
- **신뢰도 등급**: `SESSION_FILL`은 **추론값**(공유기기·단일로그인 세션도 오귀속 가능) → `DIRECT`보다 낮은 신뢰. 소비자는 필요 시 `DIRECT`만 사용하도록 `ID_RESOLUTION` 노출.

### ⚠️ 추가로 갖춰야 깔끔한 아키텍처 (보수적)
1. **materialization = `table`(전체 재계산)**: 세션-채움은 **세션 전체 이벤트**를 봐야 정확. `incremental`(72h 창)이면 세션이 창 경계로 잘려 CONFLICT/부분채움 오류 발생. → **세션→신원 매핑을 별도 `table` 모델**(`GA4_SESSION_IDENTITY`, 소량)로 분리해 full rebuild하고, `GA4_EVENT`(incremental 본체)가 `GA_SESSION_KEY`로 조인. (본체를 incremental로 두되 신원매핑만 table)
2. **DQ 지표**: 채움 전/후 채움률(4.22%→X%)·`CONFLICT`율·`UNRESOLVED`율을 DMF/테스트로 노출. **커버리지 개선일 뿐 완전 해결 아님**(미로그인 pseudo_id 세션은 여전히 UNRESOLVED) → 회원단위 GA 지표에 커버리지 경고 유지.
3. **하류 전파**: `FACT_GA_BEHAVIOR.IDENTITY_SK`는 `USER_ID_FILLED` 기반 `DIM_MEMBER_IDENTITY` 조인 + **`ID_RESOLUTION` 보존** → #81·신#32·33 파생지표가 신뢰도/커버리지로 필터 가능.
4. **CONFLICT tie-break(옵션)**: 필요 시 CONFLICT 세션만 마지막 로그인 우선(`event_timestamp DESC, batch_ordering_id DESC`로 결정적 정렬) 채움 가능. 채택 시 `ID_RESOLUTION='SESSION_FILL_TIEBREAK'`로 구분(기본은 미채움).
5. **PII/거버넌스**: `USER_ID_FILLED`도 회원번호(PII) → SILVER 마스킹 정책(`MASK_MEMBER_ID`) 적용 대상. 원본 `USER_ID`와 동일 등급.
6. **세션 스코프 한정**(교차세션·device 전파 금지) — stale identity 위험 회피(보수적 기본).

---

## 6. 관련 문서 맵

| 문서 | 역할 |
|---|---|
| `GA4_파이프라인_dbt로 작업전_주의사항.md` | dbt 구현 가이드 (매크로 코드, 증분 전략, ERD, trial 제약) |
| **본 문서** | 설계 결정 근거 + GOLD 의존성 영향 검증 |
| `03_top-down_gold/08_silver의존.md` | GOLD 컬럼 → SILVER 전체 lineage 정본 |
| `08_SILVER_테이블DDL_20260714.sql` | SILVER 물리 스키마 정본(38테이블 · GA4 5는 STEP 5) |

---

## 7. DDL 설계근거 (08 DDL 에서 이관 · 2026-07-29)

> `08_SILVER_테이블DDL_20260714.sql` 은 구조 계약(타입·PK·COMMENT)만 담도록 정리했다.
> GA4 관련 설계근거·실측수치는 아래로 이관했다. **08 STEP 5 는 본 절을 참조한다.**

### 7-A. 착수 게이트 · 적재 규칙 (종전 08 STEP 6 헤더)

- **게이트**: 현재 BRONZE 는 1일 샤드 `events_20260501`(**287,025행**)만 입고된 PoC 상태다(**G-5** 하드블로커). 전기간 샤드 입고 후 동일 DDL·적재로 **멱등 재적재**만 하면 되며 구조 변경은 불요.
  - 🟢 **[2026-08-18 O86 정정] G-5 해소.** BRONZE = `EVENTS` 통합 1테이블 **285,676,588행 / 911일**.
    ⚠️ **"구조 변경 불요" 는 틀렸다** — 실제로는 2건의 구조 변경이 필요하다(위 머리말 §신규 하드블로커):
    `GA4_EVENT` PK 재정의(**GA4-PK-1**) · `USER_ID` 길이 확장 + ID 체계 분류축(**GA4-LEN-1**).
    ⇒ 종전 게이트 문구는 **1일 샤드가 전 기간의 축소판이라고 가정**했고, 그 가정이 반증됐다.
    원천 스키마가 5종으로 변했고 PoC 샤드(30컬럼)에는 없던 결손이 2024 상반기(25컬럼)에 있다.
- **규칙**: 명시 30컬럼 선택(`SELECT *` 금지) · `session_traffic_source_last_click` 사용(GA4 UI 일치) · 비가산 지표는 raw 적재(율·평균은 GOLD/SV) · 공통감사 메타 5컬럼 · 멱등 `INSERT OVERWRITE`(09).
  - 🟢 **[2026-08-18 O86] 소스 변경** — 샤드 열거가 아니라 `EVENTS` 를 `WHERE EVENT_DT` 로 읽는다.
    명시 컬럼 수는 **30 → 31**(`event_original_occurrence_timestamp` 추가. 단 전 구간 NULL).
    ⚠️ 멱등 `INSERT OVERWRITE` 는 **월 단위 분할 적재와 상충**한다 — 월별로 돌리면 앞 달이 지워진다.
    O86 실측에서는 1개월만 `OVERWRITE`, 이후는 `INSERT` 로 append 했다. 전기간 적재 시
    ① 한 번에 전량 `OVERWRITE` 또는 ② `DELETE WHERE EVENT_DT` + `INSERT` 로 멱등성을 재설계할 것.
- ⚠️ all-NULL 잡컬럼(`app_info`·`event_dimensions`·`publisher`)은 원천 타입이 NUMBER — **매핑 제외**.
  - 🟢 **[2026-08-18 O86] 전 기간 285,676,588행 전수 재확인 — 3컬럼 모두 여전히 전건 NULL.**
    **`event_original_occurrence_timestamp` 도 같은 부류로 확정**(전건 NULL). 2026-07 원천 CSV 헤더가
    31컬럼이고 31번째가 이 컬럼임을 확인했으므로 **컬럼 누락이 아니라 원천 언로드 값이 NULL** 이다.
    ⇒ **매핑 제외 대상 = 4컬럼**(종전 3 + 1).
- DDL 초안 이관원 = `_archive/09_SILVER_DDL_20260702.sql`.

### 7-B. 테이블별 grain·리스크 (종전 08 GA4 1~5 블록 주석)

| 테이블 | grain | 근거·리스크 |
|---|---|---|
| `GA4_TRAFFIC_SOURCE` | `session_traffic_source_last_click` **한정** DISTINCT (PK 없음) | first-touch(`traffic_source`)·collected(`collected_traffic_source`)는 어트리뷰션 모델·grain 이 달라 **본 차원에서 제외**. 혼재 시 그레인 팽창 + `DIM_GA_SOURCE` fan-out. 필요 시 별도 유저/이벤트 grain 차원으로 GOLD 에서 신설.(GA4-검토 2026-07-14) |
| `GA4_EVENT_DIM` | `event_name × category × label × action` DISTINCT (키 NULL 가능 → PK 없음) | **GA-2 카디널리티 리스크**: `event_label` 이 혼합타입(문자+숫자) 고카디널리티라 전기간 확장 시 차원이 사실상 팩트화된다(1일 실측 `event_name` 49개 대비 **3,633행**). → GOLD `DIM_GA_EVENT` 는 `event_name`(+안정 category/action)으로 conform 하고, 변동성 높은 `label` 은 팩트측(`GA4_EVENT.EVENT_LABEL`)에 유지 권고. |
| `GA4_DEVICE` | `device_type × platform × category` DISTINCT (PK 없음) | 실측 76행. **코드값 실측 = `DEVICE_TYPE` PC/M 2종 · `PLATFORM` WEB 단일** — APP/ANDROID/IOS 는 미입고(O2 APP 휴면). 08 COMMENT 에 실측값으로 명시(**P19**).<br>🟢 **[2026-08-18 O86 전 기간 285,676,588행 재실측] `PLATFORM = WEB 단독` 유지 확인** — ANDROID/IOS **0건**. O2 APP 휴면 판정이 전 기간에서도 유효하다.<br>⚠️ 단 `device:category` 는 **4종**이다 — `mobile` 202,329,180 · `desktop` 79,892,714 · `tablet` 3,454,195 · **`smart tv` 499**(2024-01-10~2026-06-01). 종전 실측에는 `smart tv` 가 없었다.<br>🔴 09 적재쿼리의 `DEVICE_TYPE` CASE 는 `mobile`/`tablet` → `M`, **else → `PC`** 이므로 **`smart tv` 가 `PC` 로 분류**된다. 499행이라 영향은 미미하나 **라벨이 사실과 다르다** — `DEVICE_TYPE` 에 `TV` 를 신설하거나 08 COMMENT 에 "smart tv 는 PC 로 집계됨" 을 명시할 것(라벨 창작 금지 DEC-17-B 와 별개로, **오분류는 표기 대상**). |
| `GA4_EVENT` | 복합 PK(`USER_PSEUDO_ID`,`EVENT_TIMESTAMP`,`EVENT_NAME`,`BATCH_ORDERING_ID`) | **GA-1**: 원천 샤드에 복합키 중복군 존재(1일 실측 16,187군) → 적재에서 PK `GROUP BY` dedup. 287,025행 → SILVER **265,312행**. 비가산(`ENGAGEMENT_TIME_MSEC` 등)은 raw 보존(**O1**).<br>🔴 **[2026-08-18 O86] 이 PK 는 전 기간에 쓸 수 없다 — `GA4-PK-1`.** 4번째 키 `BATCH_ORDERING_ID` 는 원천 `events_20240719` 부터 생긴 컬럼이므로 **2024-01-01~07-18 · 199일 · 48,862,926행(17.10%)** 이 `NOT NULL` 위반으로 적재 불가다.<br>🟢 dedup 율은 전 기간에서도 유사 확인 — 2025-06 bronze 9,028,480 → SILVER **8,161,106**(**9.6%** dedup · 1일 실측 7.6% 와 같은 자리수).<br>조치 후보 ① `ROW_NUMBER()` surrogate tiebreaker(손실 0 · 권장 · 위 §예정 의 `SRC_FILE_NAME` 계보로 결정성 확보 가능) ② 3키 `GROUP BY` dedup(2024-06 기준 **3.679% 추가 손실**) ③ 2024-07-18 이전 제외(17.1% 포기). |
| `GA4_IDENTITY` | 1행/`USER_PSEUDO_ID` | **Q1** 접두사 분기 `S%`→`ONCE_MBER_NO` / else→`MBER_NO`. §5-A session-fill 반영(원본 `USER_ID` 불변 보존 + 파생 `USER_ID_FILLED`/`ID_RESOLUTION` 신설). 실측 1,348행.<br>🔴 **[2026-08-18 O86] Q1 의 2분기(`S%` / else)로는 부족하다 — `GA4-LEN-1`.** 전 기간 `user_id` 실측 **6종**:<br>· 7자리 숫자 = CRM `MBER_NO` — 9,104,851행 / **399,773 id** (정상)<br>· `S`+8자리 = `ONCE_MBER_NO` — 194,763행 / **16,907 id** (Q1 이 이미 상정)<br>· `app-`+32hex(36자) — 11,836행 / **233 id** 🔴 신규<br>· `app-`+uuid(40자) — 844행 / **8 id** 🔴 신규<br>· 이메일(`GN03440@gni.kr` 14자) — 10행 / 1 id 🔴 신규<br>· 문자열 `'null'`(4자) — 20행 / 1 id 🔴 **원천 오류값**(NULL 이 아니라 문자 "null")<br>⚠️ `USER_ID VARCHAR(10)` 이라 뒤 3종(14/36/40자) **12,690행이 적재 실패**한다.<br>🔴 **길이 확장만으로 닫지 마라** — `app-`·이메일·`'null'` 은 **CRM 회원번호가 아니다.** 확장만 하면 `IDENTITY_MEMBER_XREF` 매칭 분모에 비회원 ID 가 섞여 **채움률이 조용히 왜곡**된다. `ID_SCHEME` 분류축(`MBER_NO`/`ONCE_MBER_NO`/`APP`/`EMAIL`/`INVALID`)을 신설해 함께 노출할 것. `'null'` 은 `INVALID` 로 격리(라벨 창작 금지 DEC-17-B — 원천 문자열을 그대로 보존하고 분류만 부여). |

- 센티넬: `UTM_SOURCE`/`UTM_MEDIUM` 은 `(not set)`/`(none)`/`(direct)` 를 `NULLIF` 처리. 단 `DEFAULT_CHANNEL_GROUP` 은 **정규화 금지**(정상 라벨).
- 혼합타입 컬럼(`SESSION_ENGAGED`·`EVENT_LABEL`)은 적재 시 `COALESCE(string_value, int_value)`.

*Co-authored with CoCo*
