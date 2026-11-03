<!-- LLM-METADATA
doc_role: 폴더 안내 — 10_dbt_pipeline/macros/
created: 2026-11-02
created_by: O276-B (README 일괄 작성)
related: 00_FOLDER_INDEX.md · 10_dbt_pipeline/README.md
END-METADATA -->

# macros — dbt 공통 매크로 모음

> 목적 = dbt 파이프라인에서 공통으로 재사용되는 Jinja/SQL 매크로(대리키 생성, 감사메타, 파티션 purge, 샤드 유니온 등)를 정의한다.
> 파일 목록 = 같은 폴더 `00_FOLDER_INDEX.md`(자동 생성 · 손으로 고치지 않는다).

## 구성

| 하위 폴더·파일 묶음 | 내용 |
|---|---|
| `gold_helpers.sql`, `silver_helpers.sql` | GOLD/SILVER 대리키(`gold_sk`), 감사 메타(`gold_meta`), 날짜키 생성 매크로 |
| `bigquery_range_*.sql`, `silver_purge.sql`, `gold_fact_purge.sql` | 증분 적재 및 기간별 데이터 퍼지/필터 매크로 |
| `ga4_union_shards.sql`, `generate_schema_name.sql`, `gn_*.sql` | GA4 일별 샤드 결합, 스키마 네이밍 오버라이드, 비즈니스 공통 코드 매크로 |

## 참고

- 상위 파이프라인 프로젝트인 `10_dbt_pipeline/README.md`의 설정에 따라 빌드 시 자동 로드된다.
- 이 폴더는 `GN_DW.OPS.DW_PIPELINE` 배포 소스다 — `.md` 는 dbt 실행에 영향 없음 · SQL/YAML 은 손대지 않는다.
