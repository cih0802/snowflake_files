<!-- LLM-METADATA
doc_role: 폴더 안내 — 10_dbt_pipeline/seeds/
created: 2026-11-02
created_by: O276-B (README 일괄 작성)
related: 00_FOLDER_INDEX.md · 10_dbt_pipeline/README.md
END-METADATA -->

# seeds — dbt 시드(정적 매핑 CSV) 데이터

> 목적 = 비즈니스 코드 매핑, 조직 개편 매핑, 예산 절차 등 하드코딩을 방지하기 위한 정적 참조 CSV 파일과 스키마 정의를 관리한다.
> 파일 목록 = 같은 폴더 `00_FOLDER_INDEX.md`(자동 생성 · 손으로 고치지 않는다).

## 구성

| 하위 폴더·파일 묶음 | 내용 |
|---|---|
| `MAP_*.csv` | GA 링크 매핑, 예산 절차, 사업 유형, 서비스 분류 등 정적 참조 매핑 테이블 |
| `ORG_SUCCESSION_MANUAL.csv` | 폐지/개편 부서의 현재 활성 부서 귀속 수기 매핑 |
| `_seeds.yml` | 각 시드 파일의 대상 스키마, 컬럼 데이터 타입 및 제약 조건 테스트 명세 |

## 참고

- 원천 라벨 변경 또는 신규 분류 발생 시 모델 코드 대신 이 폴더의 CSV에 행을 추가하여 반영한다.
- 이 폴더는 `GN_DW.OPS.DW_PIPELINE` 배포 소스다 — `.md` 는 dbt 실행에 영향 없음 · SQL/YAML 은 손대지 않는다.
