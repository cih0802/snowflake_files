# 변환 규칙

## 1. 참조 자료 우선순위

다음 자료가 제공되면 필요한 범위만 읽는다.

1. 프로젝트 지침: `../../../SNOWFLAKE.md`
2. 리포트 목록·지표·동의어·기준값: `../../../references/06_REFERENCE_MANIFEST.yaml`
3. 최신 ODS 물리 구조: `../../../references/common/01_ODS_PHYSICAL_MODEL.yaml`
4. DW 업무 로직: `../../../references/legacy_dw/snowflake_coco_mstr_dw_reference.md`
5. DW 가상 구조: `../../../references/legacy_dw/snowflake_coco_mstr_virtual_structure_reference.md`
6. 변환 사례와 의미 계층: `../../../references/legacy_dw/snowflake_coco_conversion_examples_semantic_reference.md`
7. 검증된 변환 SQL과 차이 진단 SQL
8. 사용자가 복사한 MSTR 최종 SQL, 화면 캡처, 결과 엑셀

참조 파일명이나 경로가 다르면 의미가 같은 자료를 찾는다. 관련 없는 전체 자료를 매번 읽지 않는다.

## 2. MSTR SQL 분석표

변환 전에 내부적으로 아래 표를 완성한다.

| 항목 | 확인 내용 |
|---|---|
| 리포트 | 한글명, 화면 경로, REPORT_ID |
| 파라미터 | 기준월/기간, 법인, 조직, 상태, 화면 기본값 |
| 결과 Grain | 결과 1행을 구분하는 업무 키 |
| 지표 | 한글명, Alias, 수식, 집계 범위, 단위 |
| 차원 | 코드/명칭, 계층, 미분류 처리, 정렬 |
| 원천 | DW 팩트/차원, 함수/프로시저, 임시 테이블 |
| 결합 | JOIN 종류, 키, NULL, 1:N 가능성 |
| 순서 | 필터 전후, Window 전후, 집계 전후 |
| 후처리 | MSTR 뷰 필터, 동적 집계, 소계, 크로스탭 |

SQL 일부가 잘렸거나 함수 정의가 없으면 해당 부분은 `미확인`으로 남긴다.

## 3. 레거시 구조별 변환

| MSTR_DW 요소 | Snowflake 변환 원칙 |
|---|---|
| MART 팩트 | ODS 이벤트/상태 이력으로 같은 Grain의 CORE/MART 결과 재생성 |
| MART 차원 | ODS 마스터·공통코드로 CORE 차원 또는 View 생성 |
| `FN_*` | 정의의 필터·Window·배분 순서를 CTE/View/Dynamic Table로 구현 |
| `USP_*` | 적재 대상 Grain과 스냅샷 시점을 확인하여 Task/Dynamic Table/물리 테이블로 설계 |
| `#temp`, `##temp` | 1회성 단계는 CTE, 반복 사용·대용량은 임시/중간 테이블 검토 |
| MSSQL 날짜 함수 | Snowflake 날짜 함수로 치환하되 기간 경계와 문자열 키 유지 |
| `ISNULL`, `CONVERT` 등 | `COALESCE`, `TRY_TO_*`, 명시적 CAST 사용 |
| MSTR Metric Alias | 화면 한글명과 수식으로 매핑; Alias명만으로 추정 금지 |
| 소계·전체합계 | 원래 Grain에서 별도 집계; 하위 항목 합산 금지 |

## 4. 프로젝트 고정 원칙

- Snowflake의 실제 원천은 `GN_DW.BRONZE_CRM`의 MSTR_ODS/CRM 계열이다. 배포 전 테이블·컬럼 존재 여부는 `INFORMATION_SCHEMA`로 다시 확인한다.
- `MSTR_DW.MART.F_*`, `MSTR_DW.MART.D_*`, `MSTR_DW.dbo.FN_*`, `MSTR_DW.MART.USP_*`는 레거시 명세이며 Snowflake에서 직접 조회·호출하지 않는다.
- `STRD_MT`는 `YYYYMM`, 일자는 주로 `YYYYMMDD` 문자열이다.
- `SPNSR_AMT_CNT = SPNSR_AMT / 10000.0`을 기본으로 하며 `NUMBER(38,7)` 등 명시적 소수 타입을 사용한다.
- 법인 값은 소스에 따라 `1/2` 또는 `I/S`일 수 있다. 참조 자료에서 확인된 경우에만 `1→I`, `2→S`를 적용한다.
- 공통코드는 `CD_ID + DTL_CD_ID` 조합으로 해석한다.
- 과거 MSTR_DW 월 팩트는 당시 상태를 고정한 스냅샷일 수 있다. 현재 ODS로 과거월을 재계산한 값과 달라도 자동 보정하지 않는다.

## 5. 반드시 점검할 함정

1. `FULL OUTER JOIN`을 `INNER/LEFT JOIN`으로 바꾸어 한쪽 데이터가 사라짐
2. 조인 전후 Grain이 달라져 금액·회원이 증폭됨
3. Window의 정렬 또는 동률 처리 변경으로 귀속 대상이 바뀜
4. 집계 전에 적용해야 할 필터를 집계 후 적용함
5. 월별 고유회원 수를 더해 누계 고유회원으로 잘못 표시함
6. `SELECT DISTINCT`로 중복 원인을 숨김
7. ODS의 현재 마스터 상태를 과거 스냅샷으로 잘못 설명함
8. SQL 밖에서 적용된 MSTR 뷰 필터·부분합을 누락함
9. `WJXBFS*` Alias에 의미를 임의 부여함
10. 화면마다 KPI·표·차트·다운로드 쿼리를 따로 만들어 수치가 달라짐

## 6. 구현 계층

| 계층 | 역할 |
|---|---|
| RAW/ODS | CRM/MSTR_ODS 원천 보존 |
| CORE | 코드·부서·후원사업·날짜 등 공통 차원과 표준화 |
| MART | 레거시 함수/프로시저의 검증된 업무 계산과 필요 시 월 스냅샷 |
| APP | 리포트 필터와 화면 Grain에 맞춘 안전한 집계 View |
| Streamlit | 조회조건, 표시, 차트, 다운로드; 업무 계산 재구현 금지 |

APP View는 적용한 기준월, 법인, 주요 분류, 스냅샷/현재재계산 구분을 화면에서 설명할 수 있게 설계한다.
