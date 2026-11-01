# Snowflake CoCo — MSTR_DW 명세 / MSTR_ODS 실행 원칙

- Reference Pack Version: `3.0`
- 실행 원천: `GN_DW.BRONZE_CRM`
- Legacy 명세: `MSTR_DW`

## 핵심 구분

| 구분 | 용도 | 실행 여부 |
|---|---|---|
| MSTR_DW SQL·MART·함수·프로시저 | 기존 보고서의 계산 방식과 Snapshot 구조를 이해하는 명세 | Snowflake에서 실행 금지 |
| MSTR_ODS/CRM | 실제 데이터 원천 | `GN_DW.BRONZE_CRM`에서 실행 |
| CORE/MART/APP/Semantic | 검증된 ODS 변환 결과 | 검증 후 생성·조회 |

MSTR_DW에 대한 이해 없이 최종 SQL의 MART 이름만 ODS 테이블로 바꾸지 않는다. 반대로 MSTR_DW 오브젝트가 Snowflake에 존재한다고 가정하지 않는다.

## 항상 먼저 할 일

1. `references/06_REFERENCE_MANIFEST.yaml`에서 REPORT_ID 또는 한글 Alias를 찾는다.
2. Manifest가 지정한 ODS 물리 모델, 리포트 조건, Source of Truth, Validation Gate만 읽는다.
3. 신규 리포트이면 `references/legacy_dw/`에서 관련 DW 정의를 추가로 읽는다.
4. 실제 테이블과 컬럼을 `INFORMATION_SCHEMA`에서 확인한다.

## 금지

- MSTR_DW 오브젝트 직접 SELECT/CALL
- 최종 MSTR SQL의 단순 Snowflake 문법 치환
- 비슷한 한글 리포트의 조건 재사용
- 미확인 코드·컬럼·조인키 추정
- 수치를 맞추기 위한 임의 `DISTINCT`, `drop_duplicates()`, 제외, 비율 보정
- REPORT_ID 전용 수동보정을 다른 화면·월·Fact로 전파
- 검증되지 않은 결과를 `VERIFIED`로 선언

## 완료 흐름

```text
REPORT_ID 식별
→ DW 계산 명세 해석
→ 실제 ODS 원천 확인
→ ODS 기반 재구성
→ Validation Gate
→ Snapshot 차이 판정
→ APP/Streamlit 적용
```

검증 실패 시 UI 작업을 중단하고 최초 차이 단계와 필요한 자료를 반환한다.
