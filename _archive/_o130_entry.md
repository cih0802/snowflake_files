> #### 🟢 [2026-09-01 O130] `DEC-48` SILVER GA4 명명 반전(`GA4_*`→`BIGQUERY_*`) + 착수표 ㊷ 집행 · ㊶ 부분 · ㊲ 확인

🔒 **라벨** = `id_collision_gate --next O` → **O130**(정의 최대 129 ⇒ O130).

**착수 지시** = 사용자 「SILVER 테이블 명칭은 원천을 따라가기로 했다. `BIGQUERY_EVENT` 가 거짓이
되면 새로 테이블을 만들고 파이프라인을 수정한다」 + 「이번 세션 열린 작업 23건 비판적 검토 후
승인 필요분 전건 승인」.

#### 무엇을 결정했나 — `DEC-48`

`DEC-38`(2026-08-19 O87 확정, 문서30 §25)은 「SILVER 는 `GA4_*` 유지, 기반 테이블 1종만
`BIGQUERY_` 접두」를 결정했다. 그 근거 4개 중 근거 2(*"이름은 덜 자주 변하는 축에 건다"*)는
지금도 유효하지만, 실제 운영에서 현업이 SILVER 계층에서 GA4 명칭을 계속 보게 되는 혼란이
`DEC-38` 자신이 인지한 트레이드오프보다 크게 확인되어 사용자가 반전을 결정했다. 사용자는
그 위험(원천 전환 시 `BIGQUERY_EVENT` 가 거짓이 될 수 있음)을 명시적으로 인지하고 수용했다 —
그때 재작명·파이프라인 수정 비용을 지불하는 쪽을 택했다. `DEC-38` 근거 1·3·4는 이번 결정으로
무효화된다(SILVER 를 원천 기준으로 통일하는 것이 목적 자체이므로). 정본 = 문서30 §34.

#### 무엇을 실행했나

1. **실측 선행** — SILVER GA4 6모델(`GA4_EVENT`·`_EVENT_DIM`·`_IDENTITY`·`_BASIC`·`_DEVICE`·
   `_TRAFFIC_SOURCE`) 라이브 전건 **0행**(`INFORMATION_SCHEMA.TABLES`) 확인 ⇒ 데이터 손실
   없이 개명 가능함을 먼저 확인했다(단, `BIGQUERY_REFINED_DATA` 는 310,182,678행 실재 — 이름
   불변 대상이므로 무관).
2. **라이브 개명 6건** — `ALTER TABLE … RENAME TO` 로 GA4_* → BIGQUERY_* (`CREATE OR REPLACE
   TABLE` 미사용 · 데이터 없음이라 안전).
3. **`BIGQUERY_REFINED_DATA` COMMENT 갱신** — "BigQuery 평탄화 테이블을 정제하였다" 문구로
   명확화(`ALTER TABLE … SET COMMENT`).
4. **코드 동기화** — `04_silver_design/08_SILVER_테이블DDL_20260714.sql` ·
   `09_SILVER_적재쿼리_20260714.sql` · `10_dbt_pipeline/models/silver/ga4/*.sql` 6개
   파일 리네임(`BIGQUERY_*.sql`) · `_ga4_schema.yml`→`_bigquery_schema.yml` · bridge
   (`IDENTITY_MEMBER_XREF.sql`) · `_sources.yml` · GOLD `ref()` 3파일(`DIM_GA_EVENT`·
   `DIM_GA_SOURCE`·`FACT_GA_BEHAVIOR`) · 매크로 4종(`ga4_range_predicate`·`ga4_range_purge`·
   `silver_purge.RANGED_MODELS`·`gn_no_structural_alter`) · 테스트 3종 · `dbt_project.yml` ·
   `README.md`. 리터럴 치환은 1회용 스크립트 `scripts/_o130_ga4_rename.py`(순서: 긴 토큰
   먼저 → `GA4_EVENT` 마지막, 부분문자열 충돌 방지)로 일괄 처리 후 잔존 0건 grep 확인.
   GOLD `DIM_GA_EVENT`·`DIM_GA_SOURCE`·`FACT_GA_BEHAVIOR`·`WIDE_GA_BEHAVIOR`(도메인명 유지)·
   `IDENTITY_MEMBER_XREF`(교차소스)는 이름 불변 — `ref()` 인자만 갱신.
5. **설계문서 배너** — `04_silver_design/00_README.md`·`02_SILVER_작업계획_BRONZE-GOLD연결`·
   `04_SILVER_작업계획_GA4전용`·`07_GA4_SILVER_샤드통합 설계결정`·`14_GA4_작업지시 프롬프트`·
   `15_dbt파이프라인_작업지시 프롬프트`·`22`·`23` 7종에 반전 배너 삽입. 🔴 **과거 세션 서술은
   원문 보존**했다 — 그 시점 사실을 기록한 이력이므로 되쓰지 않는다(이 워크스페이스의 역사
   기록 보존 철학과 일치).

#### 함께 처리한 브리핑 열린 작업(사용자 「전건 승인」에 따라 안전하게 집행 가능한 항목만)

- ✅ **㊷ 집행 완료** — `FACT_BUDGET.PLAN_BUDGET_YEAR`(`DEC42`)·`FACT_EVENT_PARTICIPATION.
  INCREASE_FLAG` 를 모델 SELECT → `WIDE_BUDGET`/`WIDE_EVENT_PARTICIPATION` SELECT·
  `_wide_schema.yml` → `06_DDL.sql` → 라이브 `ALTER TABLE … DROP COLUMN` 순서로 3축 동시
  정합(둘 다 0행 확인 후 집행 · WIDE 뷰는 이 계정에 아직 미생성이라 재생성 충돌 없음).
  편집 중 `_wide_schema.yml` 에서 `old_string`/`new_string` 치환 실수로 두 줄이 잘못된
  위치(`PLAN_BUDGET_MONTH` 설명 아래)에 남는 사고가 있었고 즉시 자력 발견·수정했다(행 키·
  열 수 불변 확인).
- 🟠 **㊶ 부분 완료** — 근거가 이미 확보된 8개 컬럼(`CONV_CALL_CNT` 4객체·
  `MEDIA_POTENTIAL_CUST_CNT` 3객체·`CRM_MARKETING_CAMPAIGN.RM`·`CRM_SEND_RESULT.
  TOT_CLICK_CNT`)만 라이브 `ALTER … COMMENT` 로 사유 전파(전부 「원천 컬럼 실재·값 전건
  공백 = 원천 미보고」 근거). 근거 미확보 5건(`FACT_MEMBER_EVENT.NEW_EXISTING_FLAG` ·
  `FACT_MEMBER_MONTHLY` 밴드 4종·`NEW_EXISTING_FLAG` · `FACT_SERVICE_EVENT` 3종)은
  `R2-7-1`(사유 창작 금지)에 따라 보류 유지 — 문서30 §7-C 등재표에 반영.
- ✅ **㊲ 확인·취소선** — 재실측 결과 `gold_erd_coverage_gate.py` 는 이미 `O128` 이
  `KEY_TABLE_PREFIXES`에 `DIM` 을 추가해 해소돼 있었다(재실행 = 분류 17 · 미분류 0).
  이 항목은 O128 이 먼저 닫았으나 착수표 취소선 처리가 빠져 있었다 — 처리만 수행.

#### 처리하지 않은 것 — 왜

- ②·④·⑦·⑪·⑫·⑭·⑰·㉞·㊱·㊳·㊴·㊵·㊸·㊹ — 현업 회신 대기·사람 실행 소관·설계 재작성
  대규모 작업·정책 결정 필요 항목이라 이번 폭에서 제외(브리핑 처분표로 사용자에게 먼저
  제시 후 확인받은 범위).
- `index_row_gate.py` 가 `00_INDEX_이슈원장.md` 행 유실 **99건**·`99_NEXT_SESSION.md`
  행 유실 **9건**을 보고했다 — 🔴 **재확인 결과 이번 세션이 만든 손실이 아니다**(예시로
  나열된 행 키 텍스트가 이번 세션 편집 대상과 무관 · 과거 여러 세션의 은퇴·재균형 이력에서
  누적된 골든 드리프트로 추정). 🔴 **`--update-golden` 으로 덮지 않았다** — 사고를
  기준선으로 만들 위험이 있어 원인 조사를 다음 세션 착수표로 넘긴다.

#### 게이트

`doc_census`·`clause_order_gate`·`doc_heading_gate`·`doc_coord_gate` 전건 통과.
`doc_type_gate` 🟡(여유 부족 경고 2건 — `30_설계_의사결정`·`99_NEXT_SESSION`, 둘 다
`--rebalance` 로 여유 회복 완료). `index_row_gate` 🔴 FAIL — 위 사유로 원인 미조사 상태
그대로 다음 세션에 인계(신규 손실 0 은 확인, 기존 드리프트 규모는 미확정).

정본 = 문서30 §34(`DEC-48`) · §7-C 등재표(㊶) · 착수표 ~~㊲~~·㊶·~~㊷~~ · 원장 §1 O130 행.
