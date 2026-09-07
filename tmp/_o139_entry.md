> #### 🟢 [2026-09-04 O139] DEC-50 GA/GA4 명칭의 BIGQUERY 전면 전환 완결 + DDL·dbt 모델·산출물 전수 재발행
> * **개요**: 현업 정책 결정에 따라 `BRONZE_GA4` 원천 레이어를 제외한 모든 가공 레이어(SILVER, GOLD DIM/FACT/WIDE, SERVING, SV/Agent, 산출물)에서 기존 `GA`/`GA4` 명칭을 `BIGQUERY`로 전면 전환함 (`DEC-50`).
> * **주요 작업**:
>   - **이슈원장**: `DEC-50` 신설 등재 (`20_issue/30_설계_의사결정.md`).
>   - **SILVER DDL/dbt**: `models/silver/ga4/` → `models/silver/bigquery/` 디렉토리 이동 및 주석 표준화.
>   - **GOLD DDL/dbt**: `DIM_BIGQUERY_EVENT`(`BIGQUERY_EVENT_SK`), `DIM_BIGQUERY_SOURCE`(`BIGQUERY_SOURCE_SK`), `FACT_BIGQUERY_BEHAVIOR`, `WIDE_BIGQUERY_BEHAVIOR` DDL 및 dbt 모델 4종 전면 리팩터링.
>   - **Snowflake Live DB**: `GN_DW.GOLD` 내 신규 테이블/뷰 생성 및 구 `GA_*` 4개 객체 Drop 정리 완료.
>   - **산출물 전수 갱신**: `02_{SILVER,gold} 스키마 컬럼 인벤토리`, `04_컬럼계보매핑`, `05_지표GOLD매핑`, `08_보존율`, `09_조립가능성`, `11_미해결이슈_요약`, `03_GN_DW_개념도.html`, `GOLD_ERD_테이블별.html`, `erd/*.html` 38종 전량 재생성.
>   - **골든 회귀 검증**: `test_generators.py` 21개 테스트 전건 PASS (사유: `DEC-50 GA to BIGQUERY renaming`).
> * **판정**: 🟢 PASS — 전 계층 BIGQUERY 명칭 일관화 및 회귀 검증 통과.
