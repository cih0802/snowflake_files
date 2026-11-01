---
name: snowflake-mstr-dw-to-ods
description: MSTR 리포트의 MSTR_DW SQL을 업무 명세로 해석하고, 실제 Snowflake의 MSTR_ODS/CRM 원천 오브젝트를 확인하여 동등한 Snowflake SQL·APP View·Streamlit 데이터 로직으로 변환하고 검증한다. 기획자가 영문 컬럼명, 코드값, SQL을 모르더라도 한글 리포트명·조회조건·기준값과 복사한 기존 SQL만 제공해 요청하는 경우에 사용한다. 단순 SQL 문법 변환, 신규 리포트 온보딩, DW 함수·프로시저·MART 의존성 제거, DW/ODS 수치 차이 진단에도 적용한다.
---

# MSTR_DW SQL → Snowflake MSTR_ODS 변환

## 목표

MSTR_DW SQL을 실행 대상으로 보지 말고 **업무 계산 명세**로 해석한다. Snowflake에 실제 존재하는 MSTR_ODS/CRM 원천으로 같은 업무 의미를 재구성하고, 검증을 통과한 결과만 APP View 또는 Streamlit에 연결한다.

## 시작할 때

1. Workspace에 `../../SNOWFLAKE.md`와 `../../references/06_REFERENCE_MANIFEST.yaml`이 있으면 먼저 읽고 해당 라우팅을 따른다.
2. 사용자의 한글 리포트명, 화면 경로, 조회조건, 기준값, 기존 MSTR_DW SQL을 입력으로 받는다.
3. `MODE`가 없으면 요청을 보고 다음 중 하나로 정한다.
   - `ANALYZE_LEGACY`: 기존 SQL의 업무 로직과 필요한 자료만 정리
   - `ONBOARD_REPORT`: MSTR_ODS 기반 Snowflake SQL 생성 및 리포트 등록
   - `VALIDATE_DATA`: 기존 결과와 변환 결과의 차이 진단
   - `BUILD_APP`: 검증된 SQL을 APP View/Streamlit에 신규 적용
   - `CHANGE_UI`: 검증된 계산을 유지하고 화면만 변경
   - `FULL`: 분석→변환→검증→적용을 순서대로 수행
4. 신규 변환이면 [conversion-rules.md](references/conversion-rules.md)와 Manifest의 `legacy_dw_references`를 읽는다.
5. 기획자 요청 작성에는 `../../references/05_COCO_TASK_TEMPLATE.md`를 우선 사용하고, Workspace 외 단독 설치 시 [planner-request-template.md](references/planner-request-template.md)를 사용한다.
6. 검증에는 Manifest의 Gate와 [validation-checklist.md](references/validation-checklist.md)를 사용한다.

## 입력이 부족할 때

영문 오브젝트명이나 코드값을 사용자에게 요구하지 않는다. 먼저 제공된 SQL, 프로젝트 참조 문서, 리포트 매니페스트, `INFORMATION_SCHEMA`에서 찾는다.

결과를 바꿀 수 있는 항목만 질문한다: 실제 조회조건, 한글 지표의 뜻/기준 결과, SQL 밖의 MSTR 뷰 필터·부분합·동적 집계, 참조 문서에도 없는 함수·프로시저·뷰 정의.

한 번에 최대 3개를 쉬운 한국어로 질문한다. 확인되지 않은 테이블·컬럼·코드·조인키·계산식은 만들지 않는다. 질문 없이 안전하게 수행 가능한 단계는 먼저 수행한다.

## 변환 절차

### 1. 레거시 로직 해석

기존 SQL에서 아래를 추출한다.

- 입력 파라미터와 실제 기간 경계
- 원천 테이블·뷰·함수·프로시저와 임시 테이블/CTE
- 조인 유형, 조인키, NULL 처리, 필터 적용 순서
- 결과 Grain, 그룹 기준, DISTINCT 범위, Window의 `PARTITION BY`와 `ORDER BY`
- 지표 계산식, 코드 분류, 소계/전체합계, MSTR 엔진의 후처리 가능성

`WJXBFS1` 같은 기계 Alias만 보고 업무 의미를 추정하지 않는다. 수식, 화면 한글명, 리포트 정의를 함께 확인한다.

### 2. 실제 Snowflake 원천 매핑

모든 의존성을 다음 상태로 관리한다.

| 상태 | 의미 | 다음 행동 |
|---|---|---|
| 확인 | 실제 Snowflake FQN과 컬럼이 확인됨 | 변환에 사용 |
| 파생 | ODS 컬럼으로 계산 가능하고 규칙이 확인됨 | 계산식과 Grain 명시 |
| 미확인 | 오브젝트·컬럼·업무 규칙이 확인되지 않음 | 추정 금지, 질문 또는 참조 요청 |

실제 `DATABASE.SCHEMA.OBJECT`와 컬럼은 `INFORMATION_SCHEMA` 또는 프로젝트 매핑 자료로 확인한다. MSTR_DW MART·함수·프로시저는 Snowflake에서 직접 호출하지 않는다.

### 3. Snowflake SQL 재구성

- MSSQL 구문만 치환하지 말고, 레거시 함수/프로시저의 내부 계산을 ODS 원천 기반 CTE·View·Dynamic Table로 재구성한다.
- 날짜 문자열은 내부에서 안전하게 `DATE`로 변환하고, 결과의 업무 키 형식은 유지한다.
- 금액·환산 건수는 명시적 `NUMBER` 정밀도를 사용한다.
- 복잡한 공통 계산은 CORE/MART에, 화면용 집계는 APP View에 둔다.
- Streamlit은 검증된 APP View를 조회하며 Python에서 업무 계산을 다시 만들지 않는다.
- 파라미터는 바인딩하거나 허용값을 검증한다. SQL 문자열에 사용자 입력을 직접 붙이지 않는다.

### 4. 검증 게이트

UI 작업 전에 `조회조건 → 대상범위 → 조인 → 분류 → 중복 → 집계 → 화면표시` 순으로 최초 차이 지점을 찾는다.

대표 조건 1개와 변형 조건 1개 이상에서 기준 결과와 대사한다. 전체 고유회원과 전체합계는 하위 행을 단순 합산하지 말고 원래 Grain에서 다시 계산한다. 과거 월마감 DW 스냅샷과 현재 ODS 재계산의 차이는 오류와 구분하여 표시한다.

검증이 실패하면 APP/Streamlit 적용을 중단하고 차이 유형, 최초 차이 단계, 대표 키, 추가로 필요한 자료를 반환한다.

## 반드시 보존할 규칙

- `FULL OUTER JOIN`, NULL 키 결합, 조인 방향을 근거 없이 변경하지 않는다.
- `COUNT(DISTINCT MBER_NO)`의 대상 기간과 그룹 범위를 유지한다.
- Window의 파티션, 정렬, 동률 처리와 필터 순서를 유지한다.
- 당해연도 누계는 기준월과 같은 해의 1월부터 기준월까지다.
- `SPNSR_AMT_CNT`는 기본적으로 `SPNSR_AMT / 10000.0`인 금액 환산 건수이며 행 수가 아니다.
- 공통코드는 `CD_ID + DTL_CD_ID`로 해석하며 상세코드 하나만 보고 의미를 정하지 않는다.
- 기준값을 맞추기 위한 숫자 하드코딩, 임의 제외, 임의 보정, 중복 은폐용 `SELECT DISTINCT`를 사용하지 않는다.
- 성명, 주민번호, 연락처, 주소, 이메일 등 개인정보와 무제한 회원 상세를 노출하지 않는다.

## 응답 형식

기본 응답은 짧게 유지한다.

1. `판정`: 완료 / 검증 필요 / 자료 필요
2. `레거시 로직`: 한글 5줄 이내
3. `매핑`: 레거시 대상 | 한글 의미 | Snowflake 대상 | 상태
4. `결과`: 요청한 SQL·View·파일 또는 변경 내용
5. `검증`: 조건 | 기준값 | 변환값 | 차이 | 판정
6. `미해결`: 없으면 `없음`, 있으면 최대 3개

긴 SQL은 설명에서 반복하지 않고 파일 또는 코드 블록 한 번으로만 제공한다. 변경되지 않은 참조 규칙은 재인용하지 않는다.

## 완료 조건

- 모든 사용 오브젝트와 컬럼이 실제 Snowflake에서 확인됨
- 레거시 계산 규칙, Grain, 필터 순서, 조인 의미가 보존됨
- 대표 조건과 변형 조건의 검증 결과가 기록됨
- 스냅샷과 현재 ODS 재계산의 차이가 구분됨
- Streamlit이 하나의 검증된 결과를 KPI·표·차트·다운로드에 재사용함
- 개인정보 및 권한 기준을 충족함
