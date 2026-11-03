<!-- LLM-METADATA
doc_role: 폴더 안내 — 10_dbt_pipeline/snapshots/
created: 2026-11-02
created_by: O276-B (README 일괄 작성)
related: 00_FOLDER_INDEX.md · 10_dbt_pipeline/README.md
END-METADATA -->

# snapshots — dbt SCD2 스냅샷 정의

> 목적 = CRM 마스터 및 기준정보 원천 테이블의 변경 이력을 추적하여 `GN_DW.SNAPSHOT` 스키마에 SCD Type 2 형태로 적재하는 스냅샷 정의들을 보관한다.
> 파일 목록 = 같은 폴더 `00_FOLDER_INDEX.md`(자동 생성 · 손으로 고치지 않는다).

## 구성

| 하위 폴더·파일 묶음 | 내용 |
|---|---|
| `snp_crm_tc_cmmn_*.sql` | 공통코드 및 세부코드 변경 이력 추적 스냅샷 |
| `snp_crm_tm_cm_*.sql` | 캠페인, 브랜드, 부서, 개발목표, 후원사업 등 CRM 핵심 마스터 이력 스냅샷 |
| `snp_crm_tm_ms_*.sql`, `snp_crm_tm_rm_*.sql` | 회원 이벤트, 템플릿, 사업장 관리 마스터 스냅샷 |

## 참고

- 각 스냅샷은 `updated_at` 타임스탬프 전략을 사용하여 `DBT_VALID_FROM`, `DBT_VALID_TO` 구간을 자동 관리한다.
- 이 폴더는 `GN_DW.OPS.DW_PIPELINE` 배포 소스다 — `.md` 는 dbt 실행에 영향 없음 · SQL/YAML 은 손대지 않는다.
