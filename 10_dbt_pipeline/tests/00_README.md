<!-- LLM-METADATA
doc_role: 폴더 안내 — 10_dbt_pipeline/tests/
created: 2026-11-02
created_by: O276-B (README 일괄 작성)
related: 00_FOLDER_INDEX.md · 10_dbt_pipeline/README.md
END-METADATA -->

# tests — dbt 단일 테스트(Singular Tests)

> 목적 = 파이프라인 무결성을 보장하기 위한 dbt SQL 단일 테스트 쿼리들(PK 유일성, 불변식 assertion, 매핑 커버리지 warn 등)을 관리한다.
> 파일 목록 = 같은 폴더 `00_FOLDER_INDEX.md`(자동 생성 · 손으로 고치지 않는다).

## 구성

| 하위 폴더·파일 묶음 | 내용 |
|---|---|
| `assert_*.sql` | 위반 시 즉시 빌드를 중단시키는 불변식 검증 테스트 (PK 유일성, 금액/건수 보존, 입도 무결성 등) |
| `warn_*.sql` | 빌드를 중단하지 않고 경고로 데이터 드리프트를 감지하는 테스트 (매핑 누락률, NULL 비율, 예산 입도 검증 등) |

## 참고

- 각 테스트 SQL은 반환되는 행이 0건이면 통과(PASS)로 판정된다.
- 이 폴더는 `GN_DW.OPS.DW_PIPELINE` 배포 소스다 — `.md` 는 dbt 실행에 영향 없음 · SQL/YAML 은 손대지 않는다.
