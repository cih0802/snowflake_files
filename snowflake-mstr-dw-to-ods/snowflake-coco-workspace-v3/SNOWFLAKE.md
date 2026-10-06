# CoCo Workspace Instructions — MSTR_DW 명세를 MSTR_ODS로 재구성

- Reference Pack Version: `3.0`
- 실행 원천: `GN_DW.BRONZE_CRM`
- Legacy 명세: `MSTR_DW`
- 최종 대상: 검증된 Snowflake APP/Semantic View 및 Native Streamlit

## 절대 원칙

1. Snowflake에서 `MSTR_DW.MART.*`, `MSTR_DW.dbo.FN_*`, `MSTR_DW.MART.USP_*`를 조회하거나 호출하지 않는다.
2. MSTR_DW SQL·함수·프로시저·View는 **업무 계산 명세**로만 해석한다.
3. 실행 SQL은 실제 `GN_DW.BRONZE_CRM` 오브젝트와 확인된 파생 View만 사용한다.
4. 테이블·컬럼·코드·조인키·계산식을 추정하지 않는다. `INFORMATION_SCHEMA`와 Reference에서 확인한다.
5. REPORT_ID별 조건을 섞지 않는다. 한글명이 입력되면 `references/06_REFERENCE_MANIFEST.yaml`에서 식별한다.
6. UI는 관련 Validation Gate를 통과한 뒤 변경한다.
7. 과거 DW 월마감 Snapshot과 현재 ODS 재계산 결과의 차이를 오류로 단정하거나 임의 보정하지 않는다.
8. 개인정보와 무제한 회원 상세를 APP/Streamlit에 노출하지 않는다.

## 최초 로딩

모든 작업에서 다음 두 파일만 먼저 읽는다.

1. `references/common/00_COCO_READ_FIRST_ODS_ONLY.md`
2. `references/06_REFERENCE_MANIFEST.yaml`

Manifest가 지정한 파일만 추가로 읽는다. 전체 Reference를 매번 다시 읽지 않는다.

## 작업 모드

### `ANALYZE_LEGACY`

새 MSTR_DW SQL의 파라미터, 원천, 조인, Grain, 필터 순서, Window, 지표, MSTR 후처리를 분석한다. 실행 SQL을 만들지 않아도 된다.

추가 참조:

- `references/legacy_dw/`의 관련 문서
- 사용자가 제공한 MSTR 최종 SQL
- 새로 등장한 함수·프로시저·View 정의

### `ONBOARD_REPORT`

새 MSTR 리포트를 ODS 기반으로 변환한다. `ANALYZE_LEGACY → 실제 ODS 매핑 → 변환 SQL → 검증 → Manifest 등록` 순서로 수행한다.

필수 입력:

- 한글 리포트명과 화면 경로
- MSTR 최종 SQL 전체
- 조회조건과 화면 지표
- 대표 기준 결과
- 새로운 `F_*`, `D_*`, `FN_*`, `USP_*`, View 정의
- `월마감 그대로` 또는 `현재 ODS 재계산 허용` 정책

### `VALIDATE_DATA`

Manifest의 Gate와 Snapshot 정책을 읽고 `조회조건 → 대상범위 → 조인 → 분류 → 중복 → 집계 → 화면표시` 순서로 최초 차이를 찾는다.

### `BUILD_APP`

검증된 APP View 또는 검증된 Base Fact를 사용한다. Streamlit Python에서 핵심 업무 계산을 새로 만들지 않는다.

### `CHANGE_UI`

관련 REPORT_ID의 검증된 계산을 변경하지 않고 표시·필터·차트·다운로드만 수정한다. 계산 변경이 필요하면 `VALIDATE_DATA`로 전환한다.

### `FULL`

`ANALYZE_LEGACY → ONBOARD_REPORT → VALIDATE_DATA → BUILD_APP`을 순서대로 수행한다. 검증 실패 시 다음 단계로 진행하지 않는다.

## 공통 계산 규칙

- `STRD_MT`: `YYYYMM`
- 이벤트일: 주로 `YYYYMMDD`
- 실제 월말: `LAST_DAY()` 등 달력 계산
- 당해연도 누계: 기준연도 1월부터 기준월까지
- `SPNSR_AMT_CNT`: 기본적으로 `SPNSR_AMT / 10000.0`; 물리 행 수가 아님
- 금액 환산 건수: `NUMBER(38,7)` 등 명시적 Decimal 사용
- 전체 고유회원: 하위 그룹의 회원 수를 더하지 않고 목표 Grain에서 `COUNT(DISTINCT MBER_NO)` 재계산
- 공통코드: `CD_ID + DTL_CD_ID`로 해석
- JOIN 종류, NULL 처리, Window 파티션·정렬, 필터 순서를 근거 없이 변경하지 않음

## 응답 규칙

기본 응답은 다음만 반환한다.

1. `판정`: 완료 / 검증 필요 / 자료 필요 / 적용 중단
2. 변경 파일 또는 오브젝트
3. 검증 조건·기준값·변환값·차이
4. 미해결 항목 또는 사용자 결정 사항 최대 3개

긴 Reference와 변경되지 않은 코드는 반복하지 않는다.
