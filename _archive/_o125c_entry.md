> #### 🟢 [2026-08-31 O125-C] 착수표 ㉜ 수행 — dbt yml 미등재 7모델 등재로 테스트 커버리지 0 → 전건
>
> **지시** = 「dbt 에 의존하지 않는 문제들과 잔여 문제 진행: ㉜ yml 미등재 7모델 · 이력 §O125 등재」.
> 🟢 **이력 §O125·§O125-B 는 직전 작업 단위에서 이미 등재됐다** — 재작업하지 않고 실재를 grep 으로 단정했다
> (`01_세션이력_조각/01_세션이력-054.md:159` · `:213`). 🔴 「등재하라」는 지시를 받았을 때
> **먼저 등재 여부를 확인**한다(이중 등재는 좌표를 갈라 놓는다).
>
> ### 1. 무엇을 했나 — 기존 yml 2파일에 7모델 추가(신설 파일 0)
>
> | 파일 | 추가 모델 |
> |---|---|
> | `models/silver/crm/_crm_schema.yml` | `CRM_MARKETING_CAMPAIGN` · `CRM_MEMBER_SPONSOR_SPAN` · `CRM_RELATION_ACTIVITY` |
> | `models/gold/_gold_ready_schema.yml` | `DIM_MARKETING_CAMPAIGN` · `FACT_MEMBER_FEE` · `FACT_MEMBER_SPONSOR_BIZ` · `FACT_TARGET_BIZ` |
>
> 🔴 **GOLD 4모델에는 컬럼 description 을 쓰지 않았다** — 컬럼 COMMENT 정본이 `03_top-down_gold/06_DDL.sql`
> 이라는 사용자 결정(2026-08-10)이 있고, 같은 사실을 두 곳에 두면 갈라진다(`P85`). ⇒ **구조 테스트만** 넣었다.
>
> ### 2. 🔴🔴 최대 발견 — 모델 주석이 **존재하지 않는 안전망**을 근거로 dedup 을 생략했다
>
> `CRM_MEMBER_SPONSOR_SPAN.sql` 47~49행:
> *"fan-out 0 … dedup 을 걸지 않는 이유 = 유일성이 성립하므로 QUALIFY 가 무의미하고, 걸면 유일성 붕괴를
> 조용히 감추게 된다. 유일성은 `_crm_schema.yml` 의 unique 테스트가 지킨다."*
>
> 🔴 그 unique 테스트가 **그 파일에 없었다.** ⇒ 「감추지 않기 위해 dedup 을 뺐다」는 설계 판단이
> **아무 가드도 없는 상태**로 서 있었다. 🟢 (MBER_NO, SPNSR_BSNS_NO) 유일 가드를 만들어 **주석을 참으로** 만들었다.
> 🔴 판정식 = **코드 주석이 인용한 안전망은 그 자리에서 실재를 확인하라** — 주석은 계약이 아니다.
>
> ### 3. 선언 전 라이브 실측 (테스트는 검증된 불변식만 선언한다 · `R2-4`)
>
> | 대상 | 실측(2026-08-31 조회 시점) |
> |---|---|
> | `CRM_MARKETING_CAMPAIGN.MK_CMPGN_CD` | 394행 = distinct 394 · NULL 0 |
> | `CRM_RELATION_ACTIVITY.ACTIVITY_KEY` | 388,153 = distinct 388,153 · NULL 0 |
> | `CRM_MEMBER_SPONSOR_SPAN` (MBER_NO, SPNSR_BSNS_NO) | 2,170,572 = distinct 2,170,572 · NULL 0 |
> | `DIM_MARKETING_CAMPAIGN.MKTG_CAMPAIGN_SK` | 395 = distinct 395 · NULL 0 |
> | `FACT_MEMBER_FEE` 7컬럼 grain | 40,262,076 = distinct 40,262,076 · 키 NULL 0 |
> | `FACT_MEMBER_SPONSOR_BIZ` (MEMBER_DK, SPNSR_BSNS_NO) | 2,170,572 = distinct 2,170,572 · NULL 0 |
> | `FACT_TARGET_BIZ` | **0행**(원천 미입고 `E-6`) |
>
> 🔴 **`FACT_TARGET_BIZ` 의 테스트는 지금 공허하게 통과한다** — 입고 후에 처음 의미를 갖는다.
> 「통과했다」를 「검증됐다」로 읽지 마라(그 위험을 yml description 에 명시했다).
> 🔴 `MEMBER_DK`·`MBER_NO` 관계는 **severity warn** 으로 맞췄다 — 회원 마스터 고아는 기존 축과 **같은 축**이며
> (문서50 §O116 ㉠) 새 축이 아니다 ⇒ **WARN 건수를 두 번 세지 마라.**
> ⚠️ **비용** = FMF grain 가드는 4,000만 행 문자열 GROUP BY 다. 느려지면 `severity: warn` 강등이 아니라
> **tag 분리 후 주기 축소**로 대응한다 — 이 팩트에서 grain 은 구조 불변식이다.
>
> ### 4. 검증 · 잔여
>
> - `dbt_schema_lint` **rc=0**(2,893 → **3,003 단정**) · `o125_layer_census` **yml 미등재 7 → 0** ·
>   `line_len` PASS · 착수표 ㉜ 취소선 확인(브리핑 재생성 후 그 행이 열린 목록에서 사라졌다).
> - 🔴 **`dbt parse`·`build` 는 실행하지 않았다**(`R4-1` 정지점) ⇒ 이 테스트들은 현재
>   **「선언됐고 아직 돌지 않았다」**. 사용자 실행 후 WARN/ERROR 분류가 확정된다.
> - 🔴 `FACT_BUDGET_YEARLY`(O114-B)와 **같은 유형의 재발**이었다 ⇒ 근본 처방은 **분모 게이트**다:
>   `o125_layer_census.py` 가 이제 yml 등재 커버리지를 매 실행 판정하므로 다음 미등재는 즉시 드러난다.
