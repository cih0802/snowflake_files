# Snowflake CoCo용 MSTR→CRM 전환 사례·자연어 의미 계층 참조

> v3 사용 상태: `LEGACY_CONVERSION_EXAMPLE`. 이 문서의 옛 REPORT_ID는 `../06_REFERENCE_MANIFEST.yaml`의 `legacy_report_aliases`로 변환한다. 최신 실행 원천·검증 상태·파일 라우팅은 v3 Manifest를 우선한다.

- 문서 버전: 1.0
- 작성 기준일: 2026-08-24
- 대상: Snowflake CoCo로 MSTR 리포트를 CRM 원천 기반 Streamlit으로 이관하는 개발자·운영자
- 선행 문서:
  - `snowflake_coco_mstr_dw_reference.md`
  - `snowflake_coco_mstr_virtual_structure_reference.md`
- 기계 판독용 동반 파일: `snowflake_coco_report_manifest.yaml`
- CoCo 자동 지침용 동반 파일: `SNOWFLAKE.md`

---

## 1. 결론

### 1.1 기존 두 reference와 MSTR 최종 SQL만으로 충분한가

**아니다. 신규 리포트를 한 번 분석해 보는 데는 사용할 수 있지만, 안정적인 자동 변환이나 비개발자 자연어 서비스에 충분하지 않다.**

기존 두 문서는 다음을 잘 설명한다.

- MSTR_DW 오브젝트가 Snowflake에 존재하지 않는다는 전제
- CRM 원천 테이블, 주요 컬럼, 가상 MSTR_DW 구조
- 확인된 함수·프로시저·팩트·차원의 업무 의미
- 현재 두 리포트의 지표 정의와 검증값
- 월마감 스냅샷과 현재 CRM 재계산의 구조적 차이

그러나 MSTR 최종 SQL은 이미 가공된 `MART.F_*`, `MART.D_*`만 조회한다. 최종 SQL 자체에는 다음 정보가 충분히 남아 있지 않다.

1. 팩트 한 행을 만드는 CRM 원천 이벤트의 정확한 선택 규칙
2. MSTR 함수 내부의 분기, 윈도 함수 `PARTITION BY`와 `ORDER BY`
3. 프로시저가 함수 결과에 부서·법인·후원사업 차원을 부여한 방식
4. 월마감 당시 상태와 현재 CRM 상태 중 어느 시점을 기준으로 할지
5. 동일 회원·월의 증액·감액을 상계하거나 대표행에 귀속하는 방식
6. `SPNSR_AMT_CNT`가 행 수가 아니라 `SPNSR_AMT / 10000.0`이라는 계산
7. MSTR 분석엔진에서 SQL 실행 후 수행한 동적 집계·부분합·크로스탭 규칙
8. 변환 결과가 정답인지 판단할 원본 기준값과 허용 오차

따라서 CoCo가 매번 이 정보를 추론하게 하면 쿼리는 실행되더라도 업무 수치가 달라질 위험이 높고, 스키마 탐색과 재추론 때문에 토큰·크레딧도 더 사용한다.

### 1.2 사용 목적별 충분성

| 사용 목적 | 두 reference만 | 두 reference + MSTR 최종 SQL | 전환 사례 + manifest + 검증 SQL까지 | 판정 |
|---|---|---|---|---|
| CoCo가 기존 두 리포트의 구조를 설명 | 가능 | 충분 | 충분 | 사용 가능 |
| CoCo가 새로운 MSTR SQL을 CRM SQL로 1차 변환 | 부족 | 부분 가능 | 권장 | 사람 검증 필수 |
| CoCo가 검증된 Streamlit APP View 생성 | 부족 | 부족 | 가능 | 실제 FQN 확인 필요 |
| 비개발자가 자연어로 수치 조회 | 부적합 | 부적합 | Semantic View/VQR 구성 후 가능 | 별도 런타임 계층 필요 |
| 과거 MSTR 월마감 수치 완전 재현 | 불가 | 불가 | 스냅샷 원천이 있을 때만 가능 | 현재 CRM만으로 한계 |

---

## 2. CoCo 개발과 비개발자 자연어 질의는 분리한다

### 2.1 CoCo의 역할

CoCo는 다음 개발 작업에 사용한다.

- Snowflake 실제 스키마 탐색
- MSTR SQL과 전환 사례 분석
- CRM 기반 CORE/MART/APP View 작성
- Snowflake Streamlit 코드 작성·수정
- 검증 SQL 실행과 차이 진단
- 배포 파일, 테스트, 문서 관리

### 2.2 Streamlit 사용자 질의의 역할

비개발자가 Streamlit에서 자연어로 묻는 경우, 매 질문마다 CoCo가 전체 MSTR 문서를 읽고 임의 SQL을 새로 만드는 구조로 운영하지 않는다.

권장 구조는 다음과 같다.

```text
CoCo: 일회성 개발·변경·검증
  CRM 원천
    → 검증된 CORE/MART/APP View
    → Snowflake Semantic View
    → Verified Queries + Custom Instructions
    → Cortex Analyst 또는 Cortex Agent
    → Streamlit 자연어 화면

비개발자: 운영 질의
  자연어 질문
    → 등록된 REPORT_ID/업무용어로 질문 해석
    → Semantic View의 허용 지표·차원만 사용
    → 검증된 SQL 또는 검증된 View 조회
    → 표·차트·설명 반환
```

이 분리는 다음 이유로 중요하다.

- reference 문서는 개발 명세이지 자연어→SQL 의미 모델 자체가 아니다.
- 사용자 질문의 `개발건수`, `개발회원`, `누계`, `신규` 같은 용어를 논리 지표에 고정해야 한다.
- 존재하지 않는 MSTR_DW 테이블을 런타임에서 조회하는 실수를 방지한다.
- 개인정보 테이블 접근을 APP 집계 View로 제한할 수 있다.
- 반복 질문마다 긴 문서를 다시 전달하지 않아도 된다.

구현 선택:

- 현재 두 리포트처럼 구조화 데이터의 단일 보고서 질의가 중심이면 Streamlit에서 Cortex Analyst와 해당 Semantic View를 직접 사용하는 구성이 단순하다.
- 여러 Semantic View, 검색, 사용자 정의 도구를 함께 오케스트레이션해야 할 때만 Cortex Agent를 고려한다.
- Cortex Agent API를 Streamlit in Snowflake에서 호출하려면 warehouse runtime의 제약을 먼저 확인한다. 현재 Snowflake 문서상 Agent API는 SiS warehouse runtime에서 지원되지 않으므로 이 방식은 container runtime을 사용해야 한다.

---

## 3. 권장 전달 패키지

### 3.1 최초 프로젝트 생성 시 CoCo에 전달

| 순번 | 파일 | 역할 | 필수 여부 |
|---:|---|---|---|
| 1 | `SNOWFLAKE.md` | 자동 로드되는 프로젝트 원칙과 파일 라우팅 | 필수 |
| 2 | `snowflake_coco_report_manifest.yaml` | 보고서·지표·동의어·검증상태의 기계 판독용 목록 | 필수 |
| 3 | `snowflake_coco_mstr_dw_reference.md` | 업무 규칙, 함수·프로시저, 지표, 검증 | 필수 |
| 4 | `snowflake_coco_mstr_virtual_structure_reference.md` | CRM 물리 구조와 MSTR 가상 구조 | 필수 |
| 5 | 이 문서 | 충분성 판단, 실제 전환 사례, 자연어/프롬프트 운영 | 필수 |
| 6 | `mstr_dept_member_development_to_crm_final_202606.sql` | 검증 완료된 실제 MSTR→CRM 전환 예시 1 | 필수 |
| 7 | `ods_fee_forecast_decrease_new_old_202601.sql` | 실제 MSTR→CRM 전환 예시 2 | 필수 |
| 8 | `diagnose_remaining_dw_ods_difference_202601.sql` | 스냅샷 차이 진단 예시 | 권장 |
| 9 | `diagnose_decrease_gap_and_snapshot_limits_202601.sql` | NULL 안전 비교·부서 이동 진단 예시 | 권장 |

`SNOWFLAKE.md` 자동 발견은 CoCo Desktop 프로젝트 instruction 파일 기준이다. CoCo in Snowsight를 사용하면 같은 내용을 해당 Workspace의 personal skill로 등록하거나 작업 시작 시 명시적으로 컨텍스트에 포함한다.

### 3.2 새 리포트 추가 때만 전달

- 원본 MSTR 최종 SQL 전체
- MSTR 분석엔진 단계 또는 리포트 그리드/필터 정보
- 원본 결과 기준값: 대표월, 법인, 행 수, 회원 수, 금액건수, 금액
- 새로 등장하는 `F_*`, `D_*`, `FN_*`, `USP_*`, View의 DDL 또는 정의
- 위 오브젝트가 참조하는 CRM 테이블의 컬럼 구조와 논리 키
- 과거 시점 정확도 요구: `월마감 그대로` 또는 `현재 CRM 재계산 허용`

기존 두 보고서의 UI만 바꾸는 요청에는 이 자료를 다시 전달하지 않는다.

---

## 4. 실제 전환 사례 1 — 부서별 회원개발

### 4.1 사례 식별자

- `REPORT_ID`: `DEPT_MEMBER_DEVELOPMENT`
- MSTR 명칭: `01.부서별 회원개발`
- 기준 사례: `STRD_MT=202606`, 전체 법인 및 법인 `I`
- 입력: 사용자가 제공한 MSTR 최종 SQL
- 실제 CRM 변환 정답 예시: `mstr_dept_member_development_to_crm_final_202606.sql`
- 검증 상태: 선택월 지표와 법인 I 상세 Grain 검증 완료

### 4.2 MSTR 최종 SQL이 보여 주는 것

```text
mart.F_MM_SPNSR_DVLP_SUM
  → 선택월 집계 WJXBFS1~3

mart.F_MM_SPNSR_DVLP_SUM + mart.D_STRD_ADD_MT_CD
  → 같은 해 1월~기준월 누계 WJXBFS4~5

두 집계 FULL OUTER JOIN
  → 개발구분·기준월·법인·부서·후원사업 기준 통합

mart.D_* LEFT JOIN
  → 명칭과 정렬순서 부여
```

### 4.3 최종 SQL만으로 알 수 없고 전환 사례가 보완하는 것

| MSTR 논리 오브젝트/처리 | CRM 기반 실제 재현 |
|---|---|
| `F_MM_SPNSR_DVLP_SUM` | `TM_MM_FDRM_MBER_DVLP_AMT`를 중심으로 개발 이벤트 재계산 |
| `FN_MM_SPNSR_DVLP` 코드 1/4 | 후원번호+후원사업번호+월 금액합이 양수이고 월말 이후 유지되는 신규/재후원 |
| `FN_MM_SPNSR_DVLP` 코드 2 | 원천 코드 2/3/5를 회원+월로 순액화하고 양수인 회원만 선택한 뒤 원본 RAMT 배분식 적용 |
| `SPNSR_AMT_CNT` | `SPNSR_AMT / 10000.0`, 일반 행 수가 아님 |
| 부서 차원 | `TM_CM_DEPT_INFO`를 `ACMSLT_UPPER_DEPT_ID`로 5단계 self join |
| 법인 차원 | `TM_CM_SPNSR_BSNS_INFO.CPR_DIV_CD`의 `1→I`, `2→S` 변환 |
| 개발구분명 | `TC_CMMN_DTL_CD`, `CD_ID='MM015'` |
| 후원사업약칭명 | `TC_CMMN_DTL_CD`, `CD_ID='CM003'` |
| YTD 매핑 | 별도 DW 테이블 대신 기준연도 1월~기준월 범위 생성 |
| 선택월/누계 결합 | 원본과 같은 Grain에서 FULL OUTER JOIN 또는 키 집합 합성 |

### 4.4 변환 파이프라인

CoCo는 원본 SQL의 임시테이블 이름을 단순 번역하지 말고 다음 논리 단계로 변환한다.

```text
PARAMS
  → DEPT_DIM / DEPT3_DIM / DEPT4_DIM
  → CPR_DIM / ABRV_DIM / DVLP_DIM / BUSINESS_DIM
  → NEW_REJOIN_BASE
  → INCREASE_NET_BASE
  → DVLP_SOURCE
  → DVLP_FACT
  → MONTH_AGG
  → YTD_AGG
  → RESULT_KEYS
  → FINAL_RESULT
```

Snowflake에서는 임시테이블을 CTE, Transient Table, Dynamic Table 중 하나로 바꿀 수 있다. 다만 아래 업무 의미는 변경하면 안 된다.

- 윈도 함수의 파티션과 정렬
- 동일 회원·월 증감 상계 범위
- 배분금액이 귀속되는 대표행
- `COUNT(DISTINCT MBER_NO)`의 집계 기간
- 선택월과 YTD 집계의 결합 키
- 문자 코드의 미분류 값과 법인 변환

### 4.5 지표 매핑

| MSTR 지표 | 자연어 명칭 | 계산 |
|---|---|---|
| `WJXBFS1` | 선택월 개발건수 | `SUM(SPNSR_AMT_CNT)` |
| `WJXBFS2` | 선택월 개발회원 수 | `COUNT(DISTINCT MBER_NO)` |
| `WJXBFS3` | 선택월 개발금액 | `SUM(SPNSR_AMT)` |
| `WJXBFS4` | 당해연도 누계 개발건수 | 1월~기준월 `SUM(SPNSR_AMT_CNT)` |
| `WJXBFS5` | 당해연도 누계 개발회원 수 | 1월~기준월 전체 `COUNT(DISTINCT MBER_NO)` |

### 4.6 검증 정답

202606 전체 법인 기준:

| `DVLP_DIV_CD` | 팩트 행 | 회원 수 | 금액건수 | 금액 |
|---:|---:|---:|---:|---:|
| 1 | 12,832 | 11,969 | 25,713.8900000 | 257,138,900 |
| 2 | 2,318 | 2,014 | 4,999.9501000 | 49,999,501 |
| 4 | 1,605 | 1,465 | 3,350.7500000 | 33,507,500 |

검증 완료:

- 3개 개발구분 × 4개 집계 항목 = 12개 차이값 0
- 법인 `I`의 선택월 상세 301개 키 일치
- 누락 키 0, 추가 키 0
- `WJXBFS1~3` 차이 키 0

미완료:

- `WJXBFS4~5`는 로직을 재현했지만 원본 MSTR의 동일 조건 YTD 결과와 독립 대사 필요

### 4.7 Snowflake 목표 오브젝트

권장 명칭:

```text
CORE.DIM_DEPARTMENT_HIERARCHY
CORE.DIM_SPONSOR_BUSINESS
CORE.DIM_COMMON_CODE
MART.FACT_MONTHLY_SPONSOR_DEVELOPMENT
APP.APP_RPT_DEPT_MBER_DVLP
SEMANTIC.SV_DEPT_MEMBER_DEVELOPMENT
```

실제 Database/Schema 명칭은 `INFORMATION_SCHEMA` 확인 후 매핑한다. 위 이름을 존재한다고 가정하지 않는다.

---

## 5. 실제 전환 사례 2 — 회비예측 감액회원 신규/기존

### 5.1 사례 식별자

- `REPORT_ID`: `FEE_FORECAST_DECREASE_NEW_OLD`
- MSTR 명칭: `5. 회비예측 > 01. 회비예측(월마감) > 3. 후원사업별 감액회원 신규기존구분`
- 기준 사례: `STRD_MT=202601`, `CPR_DIV_CD=I`
- 실제 CRM 변환 예시: `ods_fee_forecast_decrease_new_old_202601.sql`
- 차이 진단 예시:
  - `diagnose_remaining_dw_ods_difference_202601.sql`
  - `diagnose_decrease_gap_and_snapshot_limits_202601.sql`

### 5.2 전환 시 필요한 추가 의미

| MSTR 논리 처리 | CRM 기반 실제 재현 |
|---|---|
| `F_MM_SPNSR_ACT` | 활동회원, 감액 이벤트, 결제·부서·후원사업 정보를 기준월 시점으로 결합 |
| `FN_MM_ACT_DATE` | 후원중단/재후원 이력으로 기준월 활동 여부 산정 |
| 결제정보 월 스냅샷 | 현재+이력 `UNION ALL` 후 회원+법인별 가장 큰 `SETLE_KEY` 1건 |
| 신규/기존 | 회원 최초등록연도와 후원 최초등록연도가 모두 기준연도면 신규, 아니면 기존 |
| 감액 건수 | 행 수가 아니라 `SUM(ABS(SPNSR_AMT / 10000.0))` |
| 대표행 | 원본 함수와 같은 `SPNSR_NO DESC` 규칙 유지; 동률은 결정적이지 않을 수 있음 |
| 부서 | 현재 CRM 계층으로 재구성하므로 과거 월마감과 달라질 수 있음 |

### 5.3 변환 파이프라인

```text
PARAMS
  → DEPT_MAP / DEPT4_DIM
  → CPR_DIM / BUSINESS_DIM
  → MEMBER_MONTH
  → SETLE_MONTH
  → ACTIVE_MEMBER
  → DECREASE_FACT
  → ACTIVE_FACT
  → MONTH_DECREASE
  → YTD_DECREASE
  → MONTH_ACTIVE
  → RESULT_KEYS
  → FINAL_RESULT
```

### 5.4 지표 매핑

| MSTR 지표 | 자연어 명칭 | 계산 |
|---|---|---|
| `WJXBFS1` | 당월 감액회원 수 | `COUNT(DISTINCT MBER_NO)` |
| `WJXBFS2` | 당월 감액건수 | `SUM(ABS(SPNSR_AMT_CNT))` |
| `WJXBFS3` | 당해연도 누계 감액회원 수 | YTD `COUNT(DISTINCT MBER_NO)` |
| `WJXBFS4` | 당해연도 누계 감액건수 | YTD `SUM(ABS(SPNSR_AMT_CNT))` |
| `WJXBFS5` | 기준월 활동회원 수 | `COUNT(DISTINCT MBER_NO)` |
| `WJXBFS6` | 기준월 활동 후원건수 | `SUM(SPNSR_AMT_CNT)` |

### 5.5 검증 결과와 허용 범위

202601, 법인 `I` 기준:

| 항목 | DW 월마감 | 현재 CRM 재계산 | 판단 |
|---|---:|---:|---|
| 활동 팩트 행 | 689,677 | 689,678 | CRM +1 |
| 활동회원 수 | 616,418 | 616,418 | 일치 |
| 활동 금액건수 | 실질 동일 | 실질 동일 | decimal 정규화 후 일치 |
| 감액 팩트 행 | 1,316 | 1,316 | 일치 |
| 감액회원 수 | 1,316 | 1,316 | 일치 |
| 감액 금액건수 | 2,923.3702 | 2,924.8702 | CRM +1.5000 |

확인된 상세 차이:

- `DIMENSION_DIFF`: 745
- `AMOUNT_DIFF`: 1
- `ODS_ONLY`: 1
- 대표 부서 이동: `ZB000007 → ZB000002`, 745개 키, 금액건수 1,545.0

이 차이는 단순 SQL 오류로 확정하면 안 된다. DW 월마감 팩트는 당시 부서·원천 상태를 보존하지만 현재 CRM에는 그 과거 상태를 완전히 복원할 이력이 없을 수 있다.

정확한 과거 수치가 필수이면 다음 중 하나가 필요하다.

1. MSTR_DW 월 팩트/차원 스냅샷을 Snowflake로 이관
2. CRM CDC/이력으로 기준월 시점 데이터를 재구성
3. 검증 완료 월별 결과를 별도 스냅샷 테이블에 적재

---

## 6. 신규 리포트 전환 계약

새 리포트마다 다음 항목을 한 묶음으로 관리한다. 한 항목이라도 없으면 CoCo는 불확실성을 명시하고 검증 전 배포하지 않는다.

### 6.1 입력 계약

```yaml
report_id: 영문_고정_ID
mstr_report_name: MSTR 화면명
mstr_final_sql: 원본 파일 경로
analysis_engine_steps: 동적집계/뷰필터/부분합/크로스탭 정보
default_filters:
  strd_mt: YYYYMM 또는 latest_closed_month
  cpr_div_cd: I/S/ALL
output_grain:
  - 결과를 유일하게 만드는 차원 키
metrics:
  - mstr_metric_id
  - business_name
  - exact_formula
legacy_dependencies:
  facts: []
  dimensions: []
  functions: []
  procedures: []
  views: []
crm_dependencies:
  tables: []
validation:
  sample_period: YYYYMM
  reference_totals: []
  allowed_tolerance: 0 또는 명시값
snapshot_policy: EXACT_MONTH_END | CURRENT_RECALCULATION | BOTH
```

### 6.2 출력 계약

CoCo는 새 리포트 전환 결과로 최소 다음을 만든다.

1. MSTR 오브젝트→CRM 오브젝트 매핑표
2. CRM 기반 Snowflake 변환 SQL
3. 단계별 행 수·고유키·금액 검증 SQL
4. MSTR 기준값 대사 결과
5. 차이가 있으면 차이 유형과 재현 한계
6. APP View 또는 Dynamic Table DDL
7. Semantic View용 지표·차원·관계 정의
8. 자연어 질문↔정답 SQL Verified Query 후보
9. Streamlit 화면과 개인정보/RBAC 점검 결과

---

## 7. 비개발자 자연어용 보고서 의미 사전

### 7.1 `DEPT_MEMBER_DEVELOPMENT`

| 구분 | 허용 값/용어 |
|---|---|
| 보고서 동의어 | 부서별 회원개발, 회원개발, 개발현황, 부서 개발실적 |
| 기준월 동의어 | 기준월, 조회월, 해당월, 월마감월 |
| 법인 동의어 | 사단, 사단법인=`I`; 사복, 사회복지법인=`S`; 전체법인 |
| 개발구분 | 신규=`1`, 증액=`2`, 재후원=`4`; 감액=`3`, 중단=`5`는 이 보고서 기본 범위 아님 |
| 차원 | 본부/지부, 사업부/시도권역, 부서, 후원사업약칭, 후원사업, 개발구분, 기준월, 법인 |
| 기본 필터 | 기준월=최근 검증된 마감월, 법인=`I`, 개발구분=`1,2,4` |
| 지표 | 개발건수, 개발회원 수, 개발금액, 누계개발건수, 누계개발회원 수 |

업무 용어 규칙:

- `개발건수`는 팩트 행 수가 아니라 `SUM(SPNSR_AMT_CNT)`다.
- `개발회원`은 `COUNT(DISTINCT MBER_NO)`다.
- `누계`는 기준연도 1월부터 기준월까지다.
- `누계개발회원`은 월별 회원 수 합계가 아니라 전체 기간의 고유 회원 수다.
- 사용자가 `개발`만 요청하면 기본 지표는 개발건수와 개발회원 수를 함께 표시한다.
- 사용자가 법인을 생략하면 기본 `I`를 적용하되 화면에 적용 필터를 표시한다.
- 사용자가 연도만 말하면 월을 임의 선택하지 말고 월을 확인한다.

### 7.2 `FEE_FORECAST_DECREASE_NEW_OLD`

| 구분 | 허용 값/용어 |
|---|---|
| 보고서 동의어 | 회비예측 감액, 감액회원 신규기존, 후원사업별 감액회원, 감액현황 |
| 신규/기존 | 신규=`1`, 기존=`2` |
| 차원 | 기준월, 법인, 본부/지부, 후원사업, 신규/기존 |
| 기본 필터 | 기준월=최근 마감월, 법인=`I` |
| 지표 | 당월 감액회원, 당월 감액건수, 누계 감액회원, 누계 감액건수, 활동회원, 활동 후원건수 |

업무 용어 규칙:

- `감액건수`는 감액 이벤트 행 수가 아니라 감액금액 절대값의 만원 환산 합이다.
- `활동회원`은 기준월 시점의 활동 판정 결과다.
- 과거월 질문에는 `월마감 스냅샷`인지 `현재 CRM 재계산`인지 결과 출처를 표시한다.
- 두 출처의 차이가 있는 월에는 경고 배지를 표시한다.

### 7.3 모호한 질문 처리

| 사용자 표현 | 처리 |
|---|---|
| “개발 수” | 개발건수와 개발회원 수를 함께 제공하거나 두 지표 중 선택 요청 |
| “누계” | 기준연도 1월~기준월 YTD로 해석하고 적용 기간 표시 |
| “전체” | 전체 법인인지 전체 부서인지 모호하면 한 번만 확인 |
| “신규” | 현재 보고서 맥락에 따라 개발구분 신규 또는 신규/기존 구분 신규로 해석; 보고서가 불명확하면 확인 |
| 월 없음 | 최근 검증된 마감월을 사용하고 화면에 명시 |
| 지원하지 않는 개인정보 상세 | 집계 결과만 제공하고 회원명·연락처·주소 요청은 거절 또는 권한 절차 안내 |

---

## 8. Semantic View와 Verified Query 구성 권장

### 8.1 Semantic View에 넣을 항목

- 논리 테이블과 실제 APP/MART View 연결
- 각 차원의 업무 설명과 내부 용어 동의어
- 지표의 고정 계산식
- 테이블 관계와 키
- 기본 필터와 모호한 질문 처리 규칙
- 월마감/현재 재계산 출처 컬럼
- 지원하지 않는 질문 분류 규칙

동의어는 일반 단어를 과도하게 나열하지 않는다. 내부 약어, MSTR 지표명, 조직 고유 명칭처럼 모델이 알기 어려운 용어에 한정한다.

### 8.2 첫 Verified Query 후보

#### VQ-DMD-01

질문:

```text
2026년 6월 전체 법인의 개발구분별 개발건수, 개발회원 수, 개발금액을 보여줘.
```

정답 조건:

- `REPORT_ID=DEPT_MEMBER_DEVELOPMENT`
- `STRD_MT='202606'`
- `DVLP_DIV_CD IN ('1','2','4')`
- 전체 법인
- 위 4.6 검증값과 일치

#### VQ-DMD-02

질문:

```text
2026년 6월 사단법인의 본부/지부별 신규·증액·재후원 개발실적을 비교해줘.
```

정답 조건:

- `CPR_DIV_CD='I'`
- `DEPT4` 단위
- 개발건수와 개발회원 수 표시
- 명칭 정렬은 부서 `SORT_ORDR`

#### VQ-DMD-03

질문:

```text
2026년 6월까지 사단법인의 누계 개발건수와 누계 개발회원 수를 부서별로 보여줘.
```

정답 조건:

- 기간 `202601~202606`
- 누계회원은 기간 전체 distinct
- YTD 독립 대사 완료 후 `VERIFIED`로 승격

#### VQ-FFD-01

질문:

```text
2026년 1월 사단법인의 신규/기존별 감액회원 수와 감액건수를 보여줘.
```

정답 조건:

- `REPORT_ID=FEE_FORECAST_DECREASE_NEW_OLD`
- 감액건수는 절대 금액의 만원 환산 합
- 데이터 출처가 현재 CRM 재계산임을 표시

검증되지 않은 질문·SQL 쌍을 Verified Query로 등록하지 않는다.

---

## 9. 실제 Snowflake 구조에서 추가로 필요한 자료

### 9.1 반드시 확보

1. **실제 오브젝트 매핑표**
   - 논리 CRM 테이블
   - Snowflake 실제 `DATABASE.SCHEMA.OBJECT`
   - 컬럼명과 타입
   - 행 수와 최신 적재시각
2. **PK/UK와 관계 정보**
   - Snowflake 제약이 선언되지 않았더라도 논리 유일키를 별도 기록
3. **적재 정책**
   - 전체/증분 적재
   - CDC 제공 여부
   - 삭제 처리 방식
   - 타임존
4. **월마감 정책**
   - 마감월 캘린더
   - 재마감 가능 여부
   - 과거월 재계산 허용 여부
5. **권한 정책**
   - CoCo 개발 Role
   - Streamlit 실행 Role
   - APP View 조회 Role

### 9.2 현재 미확정이라 우선순위가 높은 항목

| 우선순위 | 필요 자료 | 이유 |
|---:|---|---|
| 1 | Snowflake 실제 FQN 매핑표 | 현재 문서의 `<DB>.<SCHEMA>`를 실행 가능한 SQL로 치환 |
| 2 | `D_SPNSR_BSNS_V` 원본 정의 | 후원사업 종료시점 일반화 |
| 3 | `DEPT_MEMBER_DEVELOPMENT`의 원본 YTD 결과 | `WJXBFS4~5` 독립 검증 |
| 4 | 과거 월별 부서·회원·후원 스냅샷 또는 CDC | 회비예측의 과거 월마감 완전 재현 |
| 5 | 신규 리포트가 사용하는 함수·프로시저·View DDL | 최종 MSTR SQL에서 소실된 계산 규칙 복원 |

### 9.3 실제 FQN 자동 수집 결과 형식

CoCo가 `INFORMATION_SCHEMA.COLUMNS`와 테이블 메타데이터를 조회해 다음 형태로 저장한다.

```csv
LOGICAL_OBJECT,SNOWFLAKE_FQN,OBJECT_TYPE,ROW_COUNT,LAST_LOADED_AT,KEY_COLUMNS,STATUS
dbo.TM_CM_DEPT_INFO,MYDB.RAW.TM_CM_DEPT_INFO,TABLE,...,...,DEPT_ID,CONFIRMED
dbo.TM_MM_FDRM_MBER_DVLP_AMT,MYDB.RAW.TM_MM_FDRM_MBER_DVLP_AMT,TABLE,...,...,"SPNSR_NO,SPNSR_BSNS_NO,OCCRRNC_DE,SER_NO",CONFIRMED
```

---

## 10. 검증 Gate

### Gate 0 — 오브젝트 확인

- 모든 CRM 원천의 실제 FQN 확인
- 필수 컬럼 존재 확인
- 논리 키 중복률 확인

### Gate 1 — 원천 정합성

- 기준월 원천 행 수
- 날짜 형식 오류 수
- NULL 키 수
- 코드 미매핑 수

### Gate 2 — 중간 변환 정합성

- 개발구분/활동구분별 행 수
- 윈도 함수 대표행 수
- 회원+월 순액 분포
- 단계별 금액 합계

### Gate 3 — MSTR 기준값 대사

- 팩트 행 수 차이
- distinct 회원 수 차이
- 금액건수 차이
- 금액 차이
- 차원별 누락/추가 키

### Gate 4 — APP/Semantic 정합성

- APP View와 MART 집계 비교
- Verified Query 결과 비교
- 모호한 자연어 질문 처리 테스트
- 허용되지 않은 개인정보 질의 차단

### Gate 5 — Streamlit

- 필터 기본값 표시
- 출처와 마감/재계산 상태 표시
- 빈 결과·대용량 결과 처리
- 다운로드 컬럼의 개인정보 점검
- 실행 Role이 APP View에만 접근 가능한지 확인

---

## 11. 크레딧을 줄이는 운영 방식

### 11.1 한 번만 수행

- 프로젝트 루트에 `SNOWFLAKE.md` 배치
- 실제 FQN 매핑 파일 생성
- CORE/MART/APP View 생성
- Semantic View와 Verified Query 등록
- 두 보고서의 기준값 회귀 테스트 저장

### 11.2 매 요청에서 반복하지 않음

- 두 긴 reference 전문 재첨부
- 이미 검증된 함수 로직 재분석
- 전체 데이터베이스 재탐색
- UI 수정 때 데이터 모델 재생성
- 동일 기준값의 장황한 재출력

### 11.3 작업 유형을 먼저 한 줄로 지정

| `MODE` | CoCo가 읽을 범위 | 예시 |
|---|---|---|
| `BUILD_FOUNDATION` | 전체 reference + manifest | 최초 CORE/MART/APP 구성 |
| `ONBOARD_REPORT` | 전체 reference + 새 MSTR SQL/DDL | 새 리포트 추가 |
| `BUILD_APP` | manifest + 해당 REPORT_ID + APP View | Streamlit 신규 화면 |
| `CHANGE_UI` | Streamlit 파일 + 해당 REPORT_ID | 차트/필터/레이아웃 수정 |
| `VALIDATE_DATA` | 해당 변환 SQL + 기준값 + 진단 SQL | 수치 차이 진단 |
| `ASK_DATA` | Semantic View만 | 비개발자 자연어 조회 |

### 11.4 출력도 제한

CoCo 프롬프트 끝에 다음을 붙인다.

```text
응답은 1) 변경 파일, 2) 검증 결과, 3) 미확정 항목만 간단히 작성하세요.
변경하지 않은 코드 전문과 이미 확인된 reference 설명은 반복하지 마세요.
```

### 11.5 Snowflake compute credit도 줄이는 방법

- Streamlit 사용자 요청마다 CRM 원천에서 전체 함수 로직을 다시 계산하지 않는다.
- 월 적재 후 한 번 갱신하는 MART Dynamic Table/Task와 집계 APP View를 사용한다.
- APP View는 필요한 열만 노출하고 기준월·법인 조건이 먼저 적용되도록 설계한다.
- 저변동 차원과 동일 조건 결과는 Streamlit 캐시 및 Snowflake 결과 캐시를 활용한다.
- Warehouse는 예상 동시 사용자 수에 맞추고 auto-suspend/auto-resume을 적용한다.
- 구조화된 한 개 Semantic View 질의에는 Cortex Analyst를 우선하고, 여러 도구 오케스트레이션이 필요할 때만 Cortex Agent를 사용한다.

---

## 12. 권장 프롬프트 구조

### 12.1 공통 구조

```text
MODE: [BUILD_FOUNDATION | ONBOARD_REPORT | BUILD_APP | CHANGE_UI | VALIDATE_DATA]
REPORT_ID: [manifest의 고정 ID]
PARAMS: [기준월, 법인, 기타 필터]
REQUEST: [원하는 결과 한 문단]
ACCEPTANCE: [통과 기준]
OUTPUT: [필요 파일/화면/검증 결과]
```

프로젝트 루트에 `SNOWFLAKE.md`가 있으면 긴 배경과 금지사항은 다시 쓰지 않는다.

### 12.2 최초 기반 구축용

```text
MODE: BUILD_FOUNDATION
REPORT_ID: DEPT_MEMBER_DEVELOPMENT
REQUEST: reference와 manifest를 기준으로 Snowflake 실제 CRM FQN을 먼저 확인하고,
CORE/MART/APP View 및 Streamlit 기본 화면을 구성하세요.
ACCEPTANCE: 202606 전체법인 개발구분 1/2/4의 12개 비교값 차이 0.
OUTPUT: 생성/변경 파일, 실행 순서, 검증 결과, 아직 확인할 항목.
```

### 12.3 새 MSTR 리포트 추가용

```text
MODE: ONBOARD_REPORT
REPORT_ID: <NEW_REPORT_ID>
INPUT: <MSTR 최종 SQL 파일>, <분석엔진 단계>, <기준값 파일>
REQUEST: 기존 두 전환 사례의 절차를 따라 MSTR 오브젝트 의존성을 추출하고
CRM 원천 변환 SQL, APP View, manifest 항목, 검증 SQL을 추가하세요.
ACCEPTANCE: 제공 기준월의 행 수·회원 수·금액건수·금액이 허용 오차 내 일치.
OUTPUT: 오브젝트 매핑, 변경 파일, 대사 결과, 추가로 필요한 DDL 목록.
```

### 12.4 UI만 수정할 때

```text
MODE: CHANGE_UI
REPORT_ID: DEPT_MEMBER_DEVELOPMENT
REQUEST: 부서별 개발건수를 막대차트로 추가하고 표 다운로드를 유지하세요.
CONSTRAINT: APP View와 계산식은 변경하지 마세요.
ACCEPTANCE: 기존 데이터 회귀 테스트 통과, 개인정보 컬럼 없음.
OUTPUT: 변경 파일과 화면 변경점만.
```

### 12.5 수치 차이 진단용

```text
MODE: VALIDATE_DATA
REPORT_ID: FEE_FORECAST_DECREASE_NEW_OLD
PARAMS: STRD_MT=202601, CPR_DIV_CD=I
OBSERVED: 감액 금액건수 CRM-DW=+1.5000
REQUEST: 기존 진단 SQL 패턴으로 원천/금액/차원/스냅샷 차이를 분리하세요.
CONSTRAINT: 과거 스냅샷 차이를 계산 오류로 단정하지 마세요.
OUTPUT: 차이 유형별 건수·금액, 대표 키, 수정 필요 여부.
```

### 12.6 비개발자 Streamlit 요청용 최소 프롬프트

```text
REPORT_ID: DEPT_MEMBER_DEVELOPMENT
질문: 2026년 6월 사단법인의 본부/지부별 신규·증액·재후원 개발실적을 비교해줘.
표시: 개발건수와 개발회원 수, 막대차트와 표.
```

사용자는 내부 테이블명이나 `WJXBFS`를 알 필요가 없다. Streamlit은 보고서 ID를 숨겨도 되지만, 내부 요청에는 고정 `REPORT_ID`를 함께 전달해 의미 모델 선택 오류를 줄인다.

### 12.7 가장 짧은 CoCo 개발 요청

```text
MODE=BUILD_APP; REPORT_ID=DEPT_MEMBER_DEVELOPMENT;
기준월·법인·개발구분 필터와 부서별 표/차트를 만드세요.
manifest의 APP View만 사용하고 검증된 계산식은 변경하지 마세요.
```

---

## 13. 배포 전 최종 판단 기준

다음 조건이 모두 충족되면 비개발자에게 자연어 화면을 제공할 수 있다.

- 실제 Snowflake FQN 매핑 완료
- APP View가 개인정보 없이 필요한 집계만 제공
- Semantic View에 지표·차원·관계·기본 필터 정의
- 최소 대표 질문별 Verified Query 등록
- 검증값 회귀 테스트 통과
- 월마감 스냅샷과 현재 재계산 구분 표시
- 지원하지 않는 질문과 모호한 질문 처리 규칙 정의
- Streamlit 실행 Role 권한 점검

이 조건 전에는 reference만으로 자유로운 자연어 질의를 허용하지 않는다. 보고서별 고정 필터 UI와 검증된 APP View 조회부터 운영하고, Verified Query 범위를 늘린 뒤 자연어 범위를 확장한다.

---

## 14. 공식 Snowflake 설계 근거

- CoCo는 Snowflake 환경의 스키마와 코드를 탐색하고 SQL·Streamlit 개발을 수행하는 개발 에이전트다: https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code
- CoCo Desktop은 `SNOWFLAKE.md`, `AGENTS.md` 등 instruction 파일을 자동 발견한다: https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/instruction-files
- Cortex Analyst는 Semantic View/Model을 사용해 자연어 질문을 SQL로 변환한다: https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst
- Verified Query는 자연어 질문과 올바른 SQL을 짝지어 유사 질문의 정확도를 높인다: https://docs.snowflake.com/en/user-guide/views-semantic/verified-query-repository
- Semantic View Editor는 Verified Query, 내부 용어 동의어, 기본 동작과 모호성 처리를 위한 custom instructions를 지원한다: https://docs.snowflake.com/en/user-guide/views-semantic/editor
- Semantic View 관계는 명시해야 하며 내부 고유 용어가 아닌 일반 동의어의 과도한 사용은 토큰만 늘릴 수 있다: https://docs.snowflake.com/en/user-guide/views-semantic/best-practices-modeling
- Cortex Agent API를 Streamlit in Snowflake에서 사용할 때의 runtime 제약: https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents
