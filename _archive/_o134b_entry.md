> #### 🟢 [2026-09-02 O134-B] 산출물 6종 + ERD 전수 재생성 및 test_generators 골든 갱신 (사용자 전건 승인 집행)
>
> - **배경 및 목적**: 사용자 지시에 따른 O134 작업 비판적 검토 및 개선: (1) `scripts/` 폴더 내 산출물 생성기(gen_*.py) 신선도 및 정합성 전수 조사, (2) 현행 스키마(DEC-46 SILVER 개명, DEC-44 예산 편성 차수, SV_AD 초수 노출, GA4→BIGQUERY) 및 라이브 `census.json` 기반 `30_output_share/` 산출물 전수 재생성, (3) `test_generators.py` 신선도 가드 통과 및 골든 갱신.
> - **수행 내역**:
>   1. **라이브 `census.json` 생성**:
>      - `scripts/census_columns.py` 로 Snowflake 라이브 80개 테이블의 컬럼별 `nonnull`, `nonzero`, `approx_count_distinct` 를 전수 실측하여 `/tmp/census.json` 에 적재.
>   2. **`30_output_share/` 산출물 6종 및 ERD 카탈로그 전수 재생성**:
>      - `gen_column_mapping.py`: `04_컬럼계보매핑.{md,csv,xlsx}` 재생성 (563개 컬럼 계보 최신화).
>      - `gen_metric_gold_mapping.py`: `05_지표GOLD매핑.{md,csv,xlsx}` 재생성 (지표 215개, 마케팅 97.3%, 회원 99.3%).
>      - `run_bronze_audit_host.py`: `06_BRONZE노출감사.{md,csv,xlsx}` 재생성 (BRONZE 1,153개 컬럼 노출 실측).
>      - `gen_silver_gold_retention.py`: `08_SILVER→GOLD_보존율.{md,csv}` 재생성 (보존율 67.7%, 754개 관계선).
>      - `gen_section_assembly.py`: `09_보고서필드_조립가능성.{md,csv}` 재생성 (507개 필드 조립가능도 및 29개 섹션 배너, 열수 결손 5건 해소).
>      - `gen_unresolved_issue_summary.py`: `11_미해결이슈_요약.md` 재생성 (현업 45, dbt 18, 착수표 12).
>      - `gen_pipeline_erd.py`: `30_output_share/erd/` (52개 HTML) 재생성.
>      - `gen_gold_erd.py`: `30_output_share/GOLD_ERD_테이블별.html` 재생성.
>   3. **`test_generators.py` 골든 갱신**:
>      - 현행 스키마 지문 `06d10374589df3aa` 와 live census 결과를 반영하여 골든 갱신 완료 (`--reason` 기록).
>      - `python3 scripts/test_generators.py` 실행 결과 21/21 PASS 달성.
> - **산출물 및 변경 파일**:
>   - `30_output_share/04_컬럼계보매핑.{md,csv,xlsx}`
>   - `30_output_share/05_지표GOLD매핑.{md,csv,xlsx}`
>   - `30_output_share/06_BRONZE노출감사.{md,csv,xlsx}`
>   - `30_output_share/08_SILVER→GOLD_보존율.{md,csv}`
>   - `30_output_share/09_보고서필드_조립가능성.{md,csv}`
>   - `30_output_share/11_미해결이슈_요약.md`
>   - `30_output_share/erd/` (52개 HTML) 및 `30_output_share/GOLD_ERD_테이블별.html`
>   - `scripts/golden/outputs.json`: 골든 기준선 갱신
