<!-- LLM-METADATA
doc_id: HANDOFF_O0213_F
doc_role: 인수인계 — 세션 `O213-F` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-08
created_by: O213-F
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0213-F -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O213-F 인수인계 (Y3-E 라이브 · Y3-F GA4/검색 신규 3계열 dbt 정지점)

### ▣ O213-F-0 🔴 먼저 알아라 (2026-10-08 · nj58180 · ㉡ 적용 · 승인 일괄 · 확정위반 1 = R1-7-2 병렬 edit(계획서 2건) · 유실 0 실측)

- 🟢 Y3-E 라이브 = build PASS=40 · 비NULL 확인 · SV_SERVICE 에 DIM_SEND_REQUEST 연결 · 60차원 · 스모크 14/14.
- 🟢 Y3-F 물리 반영(데이터는 build 후):
  · SILVER 신규 3 = `BIGQUERY_SESSION`(일×세션 · range 모델) · `GA4_USER_DEMOGRAPHIC` · `SEARCH_CONSOLE_DATA`
  · GOLD 신규 3 = `FACT_BIGQUERY_SESSION`(RANGED_FACTS) · `FACT_GA4_DEMOGRAPHIC` · `FACT_SEARCH_CONSOLE`
  · SV 신규 3 = `SV_GA_SESSION`(30차원·5지표) · `SV_SEARCH_CONSOLE`(7·4) · `SV_GA_DEMOGRAPHIC`(6·1) — 0행 상태 라이브 · Agent 미연결 · GRANT 3롤.
  · 6테이블 GN_DW_ADMIN 선생성(GN_DW_DBT 는 SILVER/GOLD CREATE TABLE 권한 없음) · BRONZE_GA4·GSC USAGE/SELECT(+FUTURE) → GN_DW_DBT 부여.
- 🔴🔴 **range 모델 2종은 첫 build 가 롤링 3일치만 채운다**(테이블 선생성 ⇒ is_incremental) ⇒ **전량 백필 필수**(아래 2단계).
- 🔴 SEARCH_CONSOLE_DATA2 는 DATA 의 중복 복사본(941,298행 INTERSECT 일치) — 미사용.

### ▣ O213-F-1 🟠 남은 작업 — ㉠ 7차 잔여

| # | 할 일 | 비고 |
|---|---|---|
| 1 | 👤 dbt build(아래 ①) → 👤 백필(아래 ②) → 행수(세션 ≈1,224,849)·비NULL·스모크 3종 3값 대조 → VQR 추가(실측) → `*_SESSION` 2테이블 COMMENT ALTER | ⏸ 정지점 |
| 2 | 남은 도메인 = K 조직/예산/목표 15 · G 광고 13 · J 결연 3 · I 행사 1(`OPS.O213_Y2_FINAL` L·P) | 다음 = K 또는 G |
| 3 | 라벨 해소 잔여(행사 그룹 3 · 이전상태 · 약칭 코드) · S3 잔여 판정 | |
| 4 | Y4 Agent 도구 배선(신규 SV 4종 = PAYMENT_BILLING_STATUS·GA_SESSION·SEARCH_CONSOLE·GA_DEMOGRAPHIC 포함) → ADD VERSION · Y5 · Y6 · OPS 임시 객체 DROP | 마지막 |

- ① `dbt build --select BIGQUERY_SESSION+ GA4_USER_DEMOGRAPHIC+ SEARCH_CONSOLE_DATA+ --project-dir 10_dbt_pipeline`
- ② `EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS = 'build --select BIGQUERY_SESSION+ --vars ''{"bigquery_dt_ranges": [["2024-01-01", "9999-12-31"]]}'''` (O202-B 선례 · 파일 슬롯은 잠근 채)

### ▣ O213-F-2 ⚪ 결정 완료(재론 금지)

- O213-A~E 결정 전건 유지 + 아래 추가:
- GA4 세션 속성은 세션 grain 신규 팩트로 분리한다(FACT_BIGQUERY_BEHAVIOR grain 보존 · O45).
- 세션 속성값 = 그 일자·세션의 첫 non-NULL 값 · 자정 경계 세션은 일자별 분할(range 재적재 전제).
- GTM 미치환 `{{…}}`·`(not set)` 은 원값 보존 + SV 규칙으로 「수집 오류」 표기(R2-7).
- GA4 인구통계 사용자수는 비가산이라 지표화하지 않는다(세션만).
- EP_GAD_SOURCE 는 라벨 없는 숫자 코드라 노출하지 않는다.

_Co-authored with CoCo_
