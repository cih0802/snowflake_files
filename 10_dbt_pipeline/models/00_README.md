<!-- LLM-METADATA
doc_role: 폴더 안내 — 10_dbt_pipeline/models/
created: 2026-11-02
created_by: O276-B (README 일괄 작성)
related: 00_FOLDER_INDEX.md · 10_dbt_pipeline/README.md
END-METADATA -->

# models — dbt 모델 소스 모음

> 목적 = SILVER 계층 정제 모델과 GOLD 계층 분석 모델(차원 DIM, 팩트 FACT, 와이드 뷰 WIDE)의 SQL 및 스키마 명세를 담는다.
> 파일 목록 = 같은 폴더 `00_FOLDER_INDEX.md`(자동 생성 · 손으로 고치지 않는다).

## 구성

| 하위 폴더·파일 묶음 | 내용 |
|---|---|
| `silver/` | 원천 데이터(CRM, ERP, GA4, BigQuery, 대행사 등) 정제 및 표준화 모델 |
| `gold/dim/` | 비즈니스 엔티티 기준 분석용 차원 테이블 모델 (DIM_MEMBER, DIM_CAMPAIGN 등) |
| `gold/fact/` | 트랜잭션 및 집계 분석용 팩트 테이블 모델 (FACT_PAYMENT, FACT_AD_PERFORMANCE 등) |
| `gold/wide/` | BI 및 대시보드 쿼리 가속용 통합 와이드 뷰 모델 |
| `gold/*.yml`, `silver/*.yml` | 컬럼 정의, 테스트 및 메타데이터 정의 YAML 파일 |

## 참고

- 상위 파이프라인 프로젝트인 `10_dbt_pipeline/README.md`에 정의된 실행 순서와 종속성에 따라 빌드된다.
- 이 폴더는 `GN_DW.OPS.DW_PIPELINE` 배포 소스다 — `.md` 는 dbt 실행에 영향 없음 · SQL/YAML 은 손대지 않는다.
