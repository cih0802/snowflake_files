# Snowflake Streamlit CoCo용 MSTR_DW·MSTR_ODS 통합 참조 문서

- 작성 기준일: 2026-08-20
- 대상 시스템: MS SQL Server `MSTR_DW` / `MSTR_ODS` → Snowflake Native Streamlit
- 문서 목적: 기존 MSTR 리포트의 데이터 의미·계산식·의존 오브젝트를 Snowflake CoCo가 임의 추정하지 않고 재현하도록 하는 기준 자료
- 현재 상세 검증 대상:
  1. `01.부서별 회원개발`
  2. `5. 회비예측 > 01. 회비예측(월마감) > 3. 후원사업별 감액회원 신규기존구분`

---

## 1. CoCo가 반드시 지켜야 할 원칙

1. 이 문서에 없는 테이블·컬럼·코드 의미를 임의로 만들지 않는다.
2. Snowflake의 실제 Database/Schema/Object 이름은 배포 환경의 매핑표를 먼저 확인한다.
3. 기존 MSTR의 월마감 팩트와 현재 ODS 원천을 구분한다.
   - `MSTR_DW.MART`의 월 팩트는 당시 상태가 고정된 스냅샷이다.
   - `MSTR_ODS` 원천으로 과거월을 다시 계산하면 월마감 후 변경된 부서·후원·회원 상태가 반영될 수 있다.
4. `STRD_MT`는 `YYYYMM`, 일자는 대부분 `YYYYMMDD` 문자열이다. Snowflake에서는 내부 계산 시 `DATE`로 변환하고 결과 키는 원래 형식으로 반환한다.
5. `SPNSR_AMT_CNT`는 일반적인 행 수가 아니다. 기본적으로 `SPNSR_AMT / 10000.0`으로 계산되는 금액 환산 건수다.
6. MSTR에서 사용하는 `FULL OUTER JOIN`과 NULL 키의 결합 방식을 임의로 `INNER JOIN`으로 바꾸지 않는다.
7. `COUNT(DISTINCT MBER_NO)`의 집계 범위를 바꾸지 않는다. 특히 누계회원은 월별 회원 수 합계가 아니라 대상 기간 전체의 고유 회원 수다.
8. Streamlit 화면에는 주민번호, 성명, 연락처, 주소, 이메일 등 회원 개인정보를 노출하지 않는다. `MBER_NO`도 상세 조회 권한이 없으면 집계 전에 제거한다.
9. 검증 기준값과 차이가 발생하면 UI를 먼저 완성하지 말고 데이터 변환 단계별 행 수·금액·키 차이를 확인한다.

---

## 2. 전체 데이터 흐름

```text
MSTR_ODS 원천 테이블
  → MSTR_DW 함수(FN_*)가 월별 업무 규칙 적용
  → MSTR_DW 프로시저(USP_*)가 차원·팩트 스냅샷 적재
  → MART 팩트/차원 기반 MSTR SQL 실행
  → MSTR 분석엔진이 뷰필터·동적집계·부분합·크로스탭 수행

Snowflake 목표 구조
  → RAW/ODS 계층: MSTR_ODS 원천을 가급적 원형 유지
  → CORE 계층: 공통코드·부서·후원사업 차원 정규화
  → MART 계층: 개발/활동 월 팩트 또는 검증된 Semantic View
  → APP 계층: Streamlit 전용 집계 View
  → Native Streamlit: 필터·표·차트·다운로드 제공
```

권장 논리 스키마 예시는 다음과 같다. 실제 이름이 다르면 CoCo는 매핑만 교체해야 한다.

| 계층 | 예시 | 역할 |
|---|---|---|
| 원천 | `<DB>.RAW_MSTR_ODS` | CRM/ODS 원천 데이터 보존 |
| 코어 | `<DB>.CORE` | 부서·코드·후원사업 차원 |
| 마트 | `<DB>.MART` | MSTR 계산식이 반영된 월 팩트 |
| 앱 | `<DB>.APP` | Streamlit이 직접 조회할 집계 View |

---

## 3. 공통 업무키와 데이터 규칙

| 항목 | 의미/규칙 |
|---|---|
| `STRD_MT` | 기준년월, `YYYYMM` |
| `OCCRRNC_DE` | 개발·변경 발생일, `YYYYMMDD` |
| `MBER_NO` | 회원번호 |
| `SPNSR_NO` | 후원번호 |
| `SPNSR_BSNS_NO` | 후원번호 내부 후원사업 식별번호 |
| `SPNSR_BSNS_ID` | 후원사업 코드 |
| 개발 원천 업무키 | `SPNSR_NO + SPNSR_BSNS_NO + OCCRRNC_DE + SER_NO` |
| 후원사업 마스터 키 | `SPNSR_NO + SPNSR_BSNS_NO` |
| 회원 키 | `MBER_NO` |
| 부서 키 | `DEPT_ID` 또는 `ACMSLT_DEPT_CD` |
| 법인 `CPR_DIV_CD` | DW에서는 주로 `I`=사단, `S`=사복. 일부 ODS에서는 `1`/`2`이므로 `1→I`, `2→S` 변환 적용 |
| 미분류 대체값 | 문자코드는 보통 `Z~`, `99`, `999`, `0` 중 기존 오브젝트와 같은 값을 사용 |
| 금액건수 | `SPNSR_AMT_CNT = SPNSR_AMT / 10000.0` |
| 당해연도 누계 | 기준월과 같은 연도의 1월부터 기준월까지 |

### 3.1 공통코드 그룹

| 차원 | `CD_ID` | 주요 코드 |
|---|---:|---|
| 법인 | `CM019` | `I` 사단, `S` 사복 |
| 후원사업약칭 | `CM003` | 후원사업약칭 코드/명칭 |
| 개발구분 | `MM015` | `1` 신규, `2` 증액, `3` 감액, `4` 재후원, `5` 중단 |
| 신규기존구분 | `DMMM07` | `1` 신규, `2` 기존 |

주의: `DTL_CD_ID='1'`만으로 의미를 판단하면 안 된다. 동일 상세코드가 여러 `CD_ID`에서 반복되므로 반드시 `CD_ID + DTL_CD_ID`로 조회한다.

---

## 4. MSTR_ODS 핵심 원천 테이블

### 4.1 두 리포트에 직접 사용되는 테이블

| 원천 테이블 | 예상 Grain/키 | 주요 컬럼 | 사용 목적 |
|---|---|---|---|
| `dbo.TM_MM_FDRM_MBER_DVLP_AMT` | 개발 이벤트 1행. 키: `SPNSR_NO, SPNSR_BSNS_NO, OCCRRNC_DE, SER_NO` | `MBER_NO`, `ACMSLT_DEPT_CD`, `SPNSR_BSNS_ID`, `SPNSR_AMT`, `DVLP_DIV_CD`, `CANCL_RDCAMT_RSN_CD` | 신규·증액·감액·재후원·중단의 원천 |
| `dbo.TM_MM_FDRM_MBER_INFO` | 회원 1행, 키 `MBER_NO` | `CPR_DIV_CD`, `MBER_STAT_CD`, `STDR_DE`, `FRST_REGIST_DT`, `ACT_DEPT_CD`; 그 외 개인정보 다수 | 회원 가입일, 상태, 법인 및 활동여부 기준 |
| `dbo.TM_MM_FDRM_MBER_SPNSR` | 후원번호 1행, 키 `SPNSR_NO` | `MBER_NO`, `ACMSLT_DEPT_CD`, `FRST_REGIST_DT`, `CMPGN_CD`, `JOIN_PATH_CD` | 회원-후원 연결, 후원 최초등록일, 실적부서 |
| `dbo.TM_MM_FDRM_MBER_SPNSR_BSNS` | 후원사업 연결 1행, 키 `SPNSR_NO, SPNSR_BSNS_NO` | `SPNSR_BSNS_ID`, `SPNSR_AMT`, `SPNSR_DSCNTC_DE`, `SPNSR_DSCNTC_YN` | 후원사업, 현재금액, 중단일 |
| `dbo.TM_MM_FDRM_MBER_SPNSR_DSCNTC` | 회원 후원중단 이력 | `MBER_NO`, `SPNSR_DSCNTC_DE` | 월말 활동회원 판정 |
| `dbo.TM_MM_FDRM_MBER_RE_SPNSR` | 회원 재후원 이력 | `MBER_NO`, `RE_SPNSR_DE` | 월말 활동기간 보정 |
| `dbo.TM_CM_DEPT_INFO` | 부서 1행, 키 `DEPT_ID` | `DEPT_NM`, `UPPER_DEPT_ID`, `ACMSLT_UPPER_DEPT_ID`, `SORT_ORDR`, `USE_YN`, `ACMSLT_DEPT_YN` | 부서 5단계 계층 재현 |
| `dbo.TM_CM_SPNSR_BSNS_INFO` | 후원사업 1행, 키 `SPNSR_BSNS_ID` | `SPNSR_BSNS_NM`, `SPNSR_BSNS_ABRV_CD`, `SORT_ORDR`, `CPR_DIV_CD`, `USE_YN` | 후원사업명·약칭·법인 |
| `dbo.TC_CMMN_CD` | 공통코드 그룹 1행, 키 `CD_ID` | `CD_NM`, `USE_YN`, `SORT_ORDR` | 공통코드 그룹 |
| `dbo.TC_CMMN_DTL_CD` | 상세코드 1행, 키 `CD_ID, DTL_CD_ID` | `DTL_CD_NM`, `SORT_ORDR`, `USE_YN`, `CD_ATRB1~3` | 법인·개발구분·약칭 등 |

### 4.2 회비예측/활동회원 계산에 사용되는 테이블

| 원천 테이블/뷰 | 역할 | 주의사항 |
|---|---|---|
| `dbo.TM_PM_SETLE_INFO` | 현재 결제정보 | 회원+법인별 최신 `SETLE_KEY` 선택 |
| `dbo.TH_PM_SETLE_INFO_HIST` | 결제정보 이력 | 현재 테이블과 `UNION ALL` 후 시점 필터 적용 |
| `dbo.VM_PM_SETLE_INFO` | 현재+이력 결제정보 뷰 | Snowflake에서는 직접 View로 재현하거나 APP 쿼리에서 최신 1건 선택 |
| `dbo.TH_MM_FDRM_MBER_STNG_DTLS` | 회원상태 변경 이력 | 기준월 내 `FRST_REGIST_DT DESC` 최신 1건 사용 |
| `dbo.TM_PM_MBRFEE_ACMSLT` | 회비 납입 실적 | 성공·사용중·정기회비·비환급 조건 적용 |
| `dbo.TM_PM_MBRFEE_UNSLCTED` | 미청구 회비 | `FN_PM_SETLE_BASE*`의 미청구 분기 |

### 4.3 캠페인·결연·서비스 확장 오브젝트의 원천

현재 두 리포트의 화면 계산에는 직접 필요하지 않지만, 공유된 함수·프로시저 정의에서 확인된 원천이다.

| 원천 | 용도 |
|---|---|
| `dbo.TM_CM_CMPGN_MNG` | 캠페인 마스터 |
| `dbo.ExplCampList` | 특별캠페인 분류 |
| `dbo.TM_CM_ZIPCODE`, `dbo.TM_CM_OLD_ZIPCODE` | 지역/우편번호 변환 |
| `dbo.TM_MM_FDRM_MBER_DT_DTLS` | 회원 상세 이력 |
| `dbo.TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT` | 결연 개발/변경 금액 |
| `dbo.TM_RM_RELATNSP_MSTR_INFO` | 결연 마스터 |
| `dbo.TM_RM_RELATNSP_CHG_INFO` | 결연 변경 이력 |
| `dbo.TM_RM_CHILD_SCREENING` | 아동 스크리닝/학교 정보 |

---

## 5. MSTR_DW/MART 핵심 팩트·차원

### 5.1 팩트

| 오브젝트 | 유형/Grain | 생성 주체 | 주요 사용처 |
|---|---|---|---|
| `mart.F_MM_SPNSR_DVLP` | 개발 이벤트 기반 월 팩트 | `USP_F_MM_SPNSR_DVLP` | 후원개발의 기초 팩트 |
| `mart.F_MM_SPNSR_DVLP_SUM` | `FN_MM_SPNSR_DVLP` 결과에 차원을 부여한 월 팩트 | `USP_F_MM_SPNSR_DVLP_SUM` | `01.부서별 회원개발` |
| `mart.F_MM_SPNSR_ACT` | 기준월 활동/중단/증액/감액 상태 팩트 | `FN_MM_SPNSR_ACT` + `USP_F_MM_SPNSR_ACT` | 회비예측 감액·활동회원 리포트 |
| `mart.F_PM_MBRFEE` | 월 회비 청구·출금·미출금·환급 팩트 | 회비 월 배치 | `FN_PM_SETLE_BASE*` |
| `mart.F_MM_DEPT_ACMSLT` | 월 부서실적 팩트 | `USP_F_MM_DEPT_ACMSLT` | 부서별 월 실적 확장 |
| `mart.F_MM_JOIN_MBER` | 월 가입회원 팩트 | `USP_F_MM_JOIN_MBER` | 신규가입 분석 확장 |
| `mart.F_MM_MBER_SURV` | 월 회원 생존/유지 팩트 | `USP_F_MM_MBER_SURV` | 회원 유지 분석 확장 |
| `mart.F_MM_MBER_IG_ANAL` | 회원 분석 팩트 | 관련 `USP_F_MM_MBER_IG_ANAL*` | 회원 분석 확장 |

### 5.2 차원/스냅샷

| 오브젝트 | 역할 | Snowflake 구현 권장 |
|---|---|---|
| `mart.D_CM_DEPT_INFO` | DW 부서 마스터 | ODS 부서에서 CORE 차원 생성 |
| `mart.D_DEPT_CD` | 상세부서→DEPT2/3/4/5 계층 | View 또는 Dynamic Table |
| `mart.D_DEPT2_CD`~`D_DEPT5_CD` | 레벨별 부서 차원 | 레벨별 View |
| `mart.D_CMMN_DTL_CD` | 통합 상세 공통코드 | ODS 코드 + DW 하드코드 보정 |
| `mart.D_CPR_DIV_CD` | 법인 차원, `CM019` | CORE View |
| `mart.D_DVLP_DIV_CD` | 개발구분 차원, `MM015` | CORE View |
| `mart.D_NEW_OLD_DIV_CD` | 신규/기존 차원, `DMMM07` | CORE View |
| `mart.D_SPNSR_BSNS_ABRV_CD` | 후원사업약칭 차원, `CM003` | CORE View |
| `mart.D_SPNSR_BSNS_INFO` | 후원사업 차원 | ODS 마스터 기반 CORE View |
| `mart.D_SPNSR_BSNS_V` | 후원번호+후원사업의 시작/종료 상태 | ODS 후원사업 연결로 재현하되 정확한 원본 정의 확인 권장 |
| `mart.D_STRD_CAL_CD` | 일/월/연 달력 | Snowflake Date Dimension |
| `mart.D_STRD_MT_CD` | 기준년월명·전월·전년동월 | Date Dimension View |
| `mart.D_STRD_ADD_MT_CD` | 동일 연도 1월~기준월 누계 매핑 | Date Dimension 기반 View |
| `mart.D_MM_MBER_STRD_MT_INFO` | 월마감 회원상태 스냅샷 | 과거 정확성 필요 시 월별 물리 스냅샷 |
| `mart.D_MM_MBER_SETLE_STRD_MT_INFO` | 월마감 결제정보 스냅샷 | 회원+법인별 최신 결제정보 월 스냅샷 |
| `mart.D_PM_MBER_SPNSR_PAY_INFO` | 후원별 최초/최종 납입월·납입개월·누적액 | 월 Dynamic Table 또는 Task 적재 |
| `mart.D_CMPGN_CD`, `mart.D_CMPGN_EXPL_CD` | 캠페인/특별캠페인 차원 | ODS 캠페인 + `ExplCampList` |
| `mart.D_FDRM_MBER_INFO_CD` | 정기회원 기본 차원 | 회원 원천 기반 CORE 차원 |

---

## 6. 핵심 View 정의 규칙

### 6.1 부서 계층

`TM_CM_DEPT_INFO`를 `ACMSLT_UPPER_DEPT_ID`로 self join한다.

```text
A(최상위) → B(DEPT4) → C(DEPT3) → D(DEPT2) → E(상세 DEPT)
```

핵심 조건:

- 최상위: `A.UPPER_DEPT_ID = 'ZV000000'`
- `D_DEPT_CD`, `D_DEPT3_CD`에서 `C.DEPT_ID <> 'ZC000029'`
- `D_DEPT3_CD`, `D_DEPT4_CD`는 `A.USE_YN = 'Y'`
- 미분류 행: 각 레벨 키 `Z~`, 명칭 `없음`, 정렬 `999`

`D_DEPT_CD` 출력의 핵심 매핑:

| 결과 컬럼 | 원천 Alias |
|---|---|
| `DEPT_ID` | E |
| `DEPT2_ID` | D |
| `DEPT3_ID` | C |
| `DEPT4_ID` | B |
| `DEPT5_ID` | A |

### 6.2 기준년월 View

- `D_STRD_MT_CD`: `YMD`에서 `STRD_MT=LEFT(YMD,6)`, `STRD_NM=YYYY-MM`, 전월·전년동월 파생
- `D_STRD_ADD_MT_CD`: 동일 연도 안에서 `기준월 >= 누계월`인 모든 조합
- Snowflake에서는 Date Dimension의 `YEAR`, `MONTH`를 이용해 생성한다.

### 6.3 후원사업 View

`D_SPNSR_BSNS_INFO`는 `TM_CM_SPNSR_BSNS_INFO`에서 생성하며 법인코드를 다음처럼 정규화한다.

```sql
CASE CPR_DIV_CD WHEN '1' THEN 'I' WHEN '2' THEN 'S' ELSE CPR_DIV_CD END
```

`D_SPNSR_BSNS_V`는 최소한 다음 컬럼이 필요하다.

- `MBER_NO`
- `SPNSR_NO`
- `SPNSR_BSNS_NO`
- `SPNSR_BSNS_ID`
- `FST_DE`
- `DSC_DE`

202606 회원개발 재현에서는 `DSC_DE`를 `TM_MM_FDRM_MBER_SPNSR_BSNS.SPNSR_DSCNTC_DE`로 대체해 총계와 상세가 일치했다. 다월 운영 전 원본 View가 NULL/공백/종료일을 추가 가공하는지 확인한다.

---

## 7. 함수 정의와 Snowflake 변환 지침

### 7.1 `dbo.FN_MM_SPNSR_DVLP(@STRD_MT)` — 후원개발 변환

입력: 기준년월 `YYYYMM`

#### 개발구분 1 신규 / 4 재후원

1. 원천 `TM_MM_FDRM_MBER_DVLP_AMT`에서 `DVLP_DIV_CD IN ('1','4')`.
2. `SPNSR_NO + SPNSR_BSNS_NO + 발생월`별 금액합계 `MAMT` 계산.
3. `MAMT > 0`만 유지.
4. 후원사업 종료일 `DSC_DE > 발생월+'31'`인 행만 유지.
5. 출력금액은 원천 `SPNSR_AMT`.

#### 개발구분 2 증액

원천 개발구분 `2,3,5`를 함께 사용한다.

| 계산값 | 정의 |
|---|---|
| `SAMT` | `SPNSR_NO + SPNSR_BSNS_NO + 월`별 원천 2/3 금액합계 |
| `MAMT` | `MBER_NO + 월`별 원천 2/3/5 전체 금액합계 |
| `DAMT` | 회원+월별 감액(코드 3) 금액합계 |
| `AAMT` | 회원+월별 `SAMT` 누적합. 순서 `OCCRRNC_DE, SER_NO` |
| `RAMT` | 최종 증액 배분금액 |

필터 순서가 중요하다.

1. `MAMT > 0`.
2. `(SAMT > 0 AND 코드=2) OR (SAMT < 0 AND 코드=3)`.
3. 위 결과에서 `DAMT`를 계산한 뒤 코드 2만 유지.
4. `AAMT - ABS(DAMT) > 0`.
5. `RAMT`:

```sql
CASE
  WHEN MAMT <= SAMT AND AAMT + DAMT <= MAMT THEN AAMT + DAMT
  WHEN MAMT >  SAMT AND AAMT + DAMT <= SAMT THEN AAMT + DAMT
  WHEN MAMT <= SAMT THEN MAMT
  ELSE SAMT
END
```

6. `월 + SPNSR_NO + SPNSR_BSNS_NO`별 `SER_NO ASC` 첫 행(`RNUM=1`)만 출력.
7. 출력금액은 `RAMT`.

#### 개발구분 3 감액

1. 원천 코드 2/3을 `MBER_NO + 월`로 합산한 `MAMT` 계산.
2. `MAMT < 0`인 회원만 감액.
3. `MBER_NO + 월`별 `SPNSR_NO DESC` 첫 행에 전체 `MAMT` 귀속.
4. 원본 정렬이 `SPNSR_NO DESC`뿐이라 동률 시 차원 귀속이 비결정적일 수 있다. MSTR 완전 재현 모드에서는 추가 정렬을 넣지 않는다.

#### 개발구분 5 중단

1. 원천 코드 5.
2. 회원 중단이력과 `MBER_NO + OCCRRNC_DE=SPNSR_DSCNTC_DE`로 연결.
3. `회원 + 후원번호 + 후원사업번호 + 월`별 `SER_NO DESC` 첫 행.
4. 출력금액은 해당 그룹 `MAMT`.

Snowflake 권장: 이 함수를 호출형 UDTF로 그대로 옮기기보다, `STRD_MT`를 가진 `MART_SPNSR_DVLP_TRANSFORMED` Dynamic Table/View로 물리화한다. Streamlit 실행 때마다 전체 Window 함수를 재계산하지 않는다.

### 7.2 `dbo.FN_MM_ACT_DATE(@STRD_MT)` — 월말 활동회원

1. 월말 이전 가입 회원.
2. 기준월 말까지 유효한 후원사업 보유.
3. 회원별 기준월까지 가장 최근 중단일과 재후원일을 조회.
4. 중단/재후원 관계로 실제 활동종료일 `ACTUAL_DT` 계산.
5. 기준월 말일이 `FRST_REGIST_DT ~ ACTUAL_DT` 사이인 회원만 출력.

### 7.3 `dbo.FN_MM_SPNSR_ACT(@STRD_MT)` — 활동/변동 상태 변환

- 활동 분기: 후원번호+후원사업별 최종 이벤트(`OCCRRNC_DE DESC, SER_NO DESC`)를 선택하고 누적금액 `SUM_AMT > 0`, 활동회원 함수 결과와 결합.
- 상태 코드 변환:
  - 활동: `ACT_DSCNTC_DIV_CD='1'`
  - 원천 중단 5 → 활동상태 2
  - 원천 증액 2 → 활동상태 3
  - 원천 감액 3 → 활동상태 4
- 후원금액 구간, 활동개월/연수, 최초후원일, 최근증액일 등의 파생컬럼을 생성.

### 7.4 `FN_PM_SETLE_BASE`, `FN_PM_SETLE_BASE_NEW`

월 회비 팩트에서 출금·미출금·미청구·환급·함께출금을 통합해 납입방식별 회원 수와 금액을 만든다.

- 기본 출력: `STRD_MT, CPR_DIV_CD, SETLE_CD, RQEST_SQNC, MBRFEE_SQNC, SETLE_ENTRPS_CD, TOGETH_WTDRW_DIV_CD, NEW_OLD_DIV_CD, PAY_TYP_CD, PAY_CNT, PAY_AMT`
- 대표 분류: 출금 22, 미출금 33, 미청구 44, 환급 55, 함께출금 92/93
- 이관·환급 중복 제외 조건을 유지한다.
- `NEW` 버전은 성공 출금의 `PAY_DE`를 해당 기준월 범위로 제한하는 차이가 확인됐다. 실제 Snowflake 대상 리포트가 이 함수를 사용하면 두 버전 중 기준 버전을 먼저 확정한다.

### 7.5 결연 함수

| 함수 | 역할 | 현재 문서 상태 |
|---|---|---|
| `FN_RM_RELATNSP_MSTR_INFO` | 결연 시작/중단, 아동·회원 취소유형, 신규/기존, 결연기간 계산 | 정의 확보, 현재 두 리포트에는 미사용 |
| `FN_RM_SPSNR_ACT` | 결연 후원 활동 상태 계산 | 정의 확보, 현재 두 리포트에는 미사용 |

---

## 8. 프로시저 정의와 배치 의존성

### 8.1 리포트 핵심 프로시저

| 프로시저 | 주기 | 핵심 처리 |
|---|---|---|
| `mart.USP_F_MM_SPNSR_DVLP` | 일 | 기준월 `F_MM_SPNSR_DVLP` 삭제 후 ODS 개발이벤트 적재, 부서·캠페인·회원·사업 차원 부여 및 개발 플래그 보정 |
| `mart.USP_F_MM_SPNSR_DVLP_SUM` | 일 | `FN_MM_SPNSR_DVLP` 결과를 기준월에 적재하고 부서/캠페인/회원/사업 차원, `SPNSR_AMT_CNT`, 신규기존 등을 부여 |
| `mart.USP_F_MM_SPNSR_ACT` | 월 | 기준월 `F_MM_SPNSR_ACT`를 재생성하고 `FN_MM_SPNSR_ACT` 결과에 월 스냅샷 차원 부여 |
| `mart.USP_F_MM_SPNSR_ACT_UP` | 월 후처리 | 활동 팩트의 증액금액·최근증액일 등 보정. `F_MM_SPNSR_DVLP_SUM` 선행 필요 |
| `mart.USP_D_MM_MBER_STRD_MT_INFO` | 월 | 회원상태 월 스냅샷 생성. 상태이력 최신 1건과 납부제외 정보를 반영 |
| `mart.USP_D_MM_MBER_SETLE_STRD_MT_INFO` | 월 | 결제정보 월 스냅샷 생성 |
| `mart.USP_D_PM_MBER_SPNSR_PAY_INFO` | 월 | 후원별 최초/최종 납입월, 납입개월 수, 누적/당월 납입액 생성 |
| `mart.USP_D_SPNSR_BSNS_INFO` | 일 | ODS 후원사업 마스터 적재, 법인 `1→I`, `2→S`, 미분류행 추가 |
| `mart.USP_D_CM_DEPT_INFO` | 일 | ODS 부서 마스터를 DW 부서 차원으로 적재 |
| `mart.USP_D_CMMN_DTL_CD` | 일 | ODS 공통코드와 DW 전용 하드코드 차원 적재, 코드별 미분류행 생성 |
| `mart.USP_D_STRD_CAL_CD` | 일/초기 | 기준 달력 생성 |
| `mart.USP_D_CMPGN_CD` | 일 | 캠페인 마스터 적재 후 `ExplCampList`로 특별캠페인 표시 |
| `mart.USP_D_CMPGN_EXPL_CD` | 일 | 특별캠페인 코드 적재 |

### 8.2 배치 오케스트레이션

| 프로시저 | 역할 |
|---|---|
| `USP_RUN_D_MART` | 일 배치. 공통코드·차원·일 팩트 호출 |
| `USP_RUN_M_MART` | 월 배치. 회원/회비/결연/서비스 영역별 월 프로시저 호출 |
| `USP_RUN_INIT_MART` | 초기 적재 |
| `USP_INIT_RUN_MART` | 초기 달력·개발 팩트 준비 |
| `USP_RUN_M_MART_TEST` | 월 배치 테스트 호출 집합 |
| `USP_BCHLOG`, `USP_BCHERR` | 배치 로그·오류 처리 |

Snowflake에서는 MS SQL 프로시저 호출 체인을 그대로 복제하기보다 `TASK`와 선후행 DAG로 분리한다.

```text
공통코드/부서/사업 차원
  → 개발 팩트
  → 개발 SUM 팩트
  → 회원/결제 월 스냅샷
  → 활동 팩트
  → 활동 팩트 후처리
  → Streamlit APP 집계 View
```

### 8.3 정의가 공유된 확장 프로시저 목록

다음 오브젝트는 정의 또는 이름이 공유됐지만 현재 두 리포트에 직접 사용하지 않는다. CoCo는 이름만 보고 구현하지 말고 해당 리포트가 추가될 때 원본 정의를 함께 사용한다.

- 회원/후원: `USP_D_FDRM_MBER_INFO_CD`, `USP_F_MM_JOIN_MBER`, `USP_F_MM_MBER_SURV`, `USP_F_MM_MBER_IG_ANAL`, `USP_F_MM_MBER_IG_ANAL_UP`, `USP_F_MM_MBER_IG_ANAL_UP_01`, `USP_F_MM_MBER_IG_ANAL_UP_02`, `USP_F_MM_DEPT_ACMSLT`
- 개발 초기/보정: `USP_F_MM_SPNSR_DVLP_INIT`, `USP_F_MM_SPNSR_DVLP_INIT_UP`, `USP_F_MM_SPNSR_DVLP_INIT_UP01`, `USP_F_MM_SPNSR_DVLP_INIT_UP02`, `USP_F_MM_SPNSR_DVLP_SUM_INIT`, `USP_TEMP_F_MM_SPNSR_ACT_UP`
- 버전 보관: `USP_D_MM_MBER_STRD_MT_INFO_202004`, `USP_F_MM_SPNSR_ACT_202004`
- 서비스: `USP_F_MS_CRMN_SUM`, `USP_F_MS_CRMN_EVENT_SUM`, `USP_F_MS_EVENT_SUM`, `USP_F_MS_EMAIL`, `USP_F_MS_MSG_SUM`, `USP_F_MS_PSTMTR_SNDNG`, `USP_F_MSG`
- 결연: `USP_F_RM_CHILD`, `USP_F_RM_RELATNSP`, `USP_F_RM_EXPL_ACMSLT_DEPT`

---

## 9. 리포트 1 — 01.부서별 회원개발

### 9.1 필터와 Grain

- 필수 입력: `STRD_MT`
- 기본 법인 필터: `CPR_DIV_CD='I'`
- 개발구분: `1,2,4`
- 최종 Grain:

```text
STRD_MT
+ DEPT4_ID
+ DEPT3_ID
+ DEPT_ID
+ CPR_DIV_CD
+ SPNSR_BSNS_ABRV_CD
+ SPNSR_BSNS_ID
+ DVLP_DIV_CD
```

### 9.2 지표

| MSTR Metric | 정의 |
|---|---|
| `WJXBFS1` | 선택월 `SUM(SPNSR_AMT_CNT)` |
| `WJXBFS2` | 선택월 `COUNT(DISTINCT MBER_NO)` |
| `WJXBFS3` | 선택월 `SUM(SPNSR_AMT)` |
| `WJXBFS4` | 당해연도 1월~기준월 `SUM(SPNSR_AMT_CNT)` |
| `WJXBFS5` | 당해연도 1월~기준월 `COUNT(DISTINCT MBER_NO)` |

### 9.3 계산 순서

1. `FN_MM_SPNSR_DVLP` 중 코드 1/2/4를 재현한다.
2. 부서 계층, 후원사업 약칭/법인, 개발구분 명칭을 연결한다.
3. 선택월 집계와 YTD 집계를 별도로 만든다.
4. 두 집계를 원본과 같은 전체 키로 `FULL OUTER JOIN`한다.
5. 차원 명칭을 연결하고 법인 필터를 적용한다.
6. Streamlit에서 MSTR의 동적집계/크로스탭을 재현한다.

### 9.4 검증 기준값 — 202606 전체법인

| 개발구분 | FACT 행 | 회원 수 | 금액건수 | 금액 |
|---:|---:|---:|---:|---:|
| 1 | 12,832 | 11,969 | 25,713.8900000 | 257,138,900 |
| 2 | 2,318 | 2,014 | 4,999.9501000 | 49,999,501 |
| 4 | 1,605 | 1,465 | 3,350.7500000 | 33,507,500 |

검증 완료 범위:

- 위 3개 개발구분 × 4개 지표 = 12개 비교항목 차이 0.
- 법인 `I` 선택월 상세 301개 키가 모두 일치.
- 누락/추가 키 0, `WJXBFS1~3` 차이 키 0.
- `WJXBFS4~5`는 로직을 재현했으나 원본 MSTR의 동일 조건 누계 결과와 별도 독립 대사가 필요하다.

---

## 10. 리포트 2 — 후원사업별 감액회원 신규기존구분

### 10.1 필터와 Grain

- 기준월 예시: `202601`
- 기본 법인: `I`
- Grain:

```text
STRD_MT
+ CPR_DIV_CD
+ SPNSR_BSNS_ID
+ NEW_OLD_DIV_CD
+ DEPT4_ID
```

### 10.2 지표

| MSTR Metric | 정의 |
|---|---|
| `WJXBFS1` | 당월 감액회원 수: `COUNT(DISTINCT MBER_NO)` |
| `WJXBFS2` | 당월 감액 건수: `SUM(ABS(SPNSR_AMT_CNT))` |
| `WJXBFS3` | 당해연도 누계 감액회원 수 |
| `WJXBFS4` | 당해연도 누계 감액 건수 |
| `WJXBFS5` | 기준월 활동회원 수 |
| `WJXBFS6` | 기준월 활동 후원 건수: `SUM(SPNSR_AMT_CNT)` |

### 10.3 신규/기존

회원 최초등록일과 후원 최초등록일의 연도가 모두 기준연도와 같은 경우만 신규다.

```sql
CASE
  WHEN YEAR(MBER.FRST_REGIST_DT) = 기준연도
   AND YEAR(SPNSR.FRST_REGIST_DT) = 기준연도
  THEN '1'
  ELSE '2'
END
```

### 10.4 감액

- 원천 코드 2/3을 회원+월로 합산.
- 합계가 음수인 회원.
- 회원+월별 `SPNSR_NO DESC` 첫 행에 전체 감액 귀속.
- 감액 건수는 행 수가 아니라 `ABS(감액금액 / 10000.0)` 합계.

### 10.5 활동회원

- 기준월 말일에 활동 중인 회원만 포함.
- 후원번호+후원사업별 마지막 이벤트를 선택.
- 누적금액이 양수인 후원만 포함.
- 결제법인은 현재+이력 결제정보를 합친 뒤 회원+법인별 최신 `SETLE_KEY` 1건 사용.

### 10.6 202601 DW 월마감 기준과 ODS 재계산 결과

| 검증 항목 | DW 월마감 | 현재 ODS 재계산 | 차이/상태 |
|---|---:|---:|---|
| 활동 팩트 행 | 689,677 | 689,678 | +1 |
| 활동회원 수 | 616,418 | 616,418 | 일치 |
| 활동 금액건수 | 1,316,513.49050015 | 자료형 정규화 후 사실상 동일 | 표시 정밀도 주의 |
| 감액 팩트 행 | 1,316 | 1,316 | 일치 |
| 감액회원 수 | 1,316 | 1,316 | 일치 |
| 감액 금액건수 | 2,923.3702 | 2,924.8702 | +1.5000 |

차이 원인으로 확인된 사항:

- 상세 차이: `DIMENSION_DIFF 745`, `AMOUNT_DIFF 1`, `ODS_ONLY 1`.
- 대표적인 부서 이동: `ZB000007 → ZB000002`, 745개 키, 금액건수 1,545.0.
- DW는 월마감 당시 부서/팩트를 저장하지만 ODS 재계산은 현재 마스터를 사용한다.
- 감액 대표행의 원본 정렬이 완전한 동률해소 조건을 갖지 않아 차원 귀속이 달라질 수 있다.
- 과거 ODS 수정 전 상태를 복원할 이력/수정일이 충분하지 않으면 완전 일치는 불가능하다.

Snowflake에서 이 리포트의 과거값을 MSTR과 완전히 같게 유지하려면 `MSTR_DW.MART.F_MM_SPNSR_ACT` 월 스냅샷을 Snowflake에 이관하거나, Snowflake 적재 시작 시점부터 월마감 스냅샷을 별도 보존해야 한다.

---

## 11. MS SQL → Snowflake 변환 규칙

| MS SQL | Snowflake 권장 |
|---|---|
| `ISNULL(a,b)` | `COALESCE(a,b)` |
| `LEFT(x,n)` | `LEFT(x,n)` 또는 `SUBSTR(x,1,n)` |
| `CONVERT(CHAR(8), date,112)` | `TO_CHAR(date,'YYYYMMDD')` |
| `CONVERT(DATE, yyyymmdd)` | `TO_DATE(yyyymmdd,'YYYYMMDD')` |
| `DATEADD(DD,-1,...)` | `DATEADD(DAY,-1,...)` |
| `GETDATE()` | `CURRENT_TIMESTAMP()` / `CURRENT_DATE()` |
| `SELECT ... INTO #TEMP` | `CREATE TEMP TABLE ... AS SELECT` 또는 CTE |
| `##GLOBAL_TEMP` | 사용하지 않음. CTE/TEMP/APP View로 변경 |
| `NOLOCK`, `READ UNCOMMITTED` | 제거. Snowflake MVCC 사용 |
| `WITH(TABLOCK)` | 제거 |
| `GO`, `USE DB` | 제거하고 Fully Qualified Name 사용 |
| `THROW` | Streamlit 입력검증 또는 Snowflake Scripting 예외 |
| 인라인 TVF | View/Dynamic Table/SQL UDTF 중 선택 |
| 배치 프로시저 | Task + Stored Procedure/Dynamic Table |

추가 원칙:

- `DECIMAL(38,7)` 등 금액 정밀도를 명시해 부동소수점 차이를 방지한다.
- Window 함수의 `PARTITION BY`와 `ORDER BY`는 원본과 동일하게 유지한다.
- 문자열 날짜의 잘못된 값이 있을 수 있으므로 `TRY_TO_DATE` 사용 여부를 데이터 품질 검증 후 결정한다.
- 대용량 원천은 `OCCRRNC_DE` 또는 파생 `STRD_MT` 필터를 가장 먼저 적용한다.
- 반복 사용되는 개발/활동 변환은 앱 쿼리 내부 CTE가 아니라 MART 계층에 사전 계산한다.

---

## 12. Streamlit 구현 기준

### 12.1 공통 필터

- 기준년월: 필수, 기본값은 데이터의 최신 마감월
- 법인: 기본 `I`, 권한에 따라 `S` 또는 전체 허용
- 본부/지부(`DEPT4`), 사업부/권역(`DEPT3`), 부서(`DEPT`)
- 후원사업약칭, 후원사업
- 개발구분 1/2/4
- 신규/기존(회비예측 리포트)

### 12.2 화면

1. 상단 KPI 카드
2. MSTR과 같은 계층형 표/피벗
3. 선택한 차원의 동적 집계
4. 부분합/합계
5. CSV/XLSX 다운로드
6. 데이터 기준월, 마지막 갱신시각, 적용 필터 표시

### 12.3 쿼리 실행

- Native Streamlit의 활성 Snowpark Session 사용.
- 사용자 입력은 문자열 조합이 아닌 바인딩 또는 검증된 선택값으로 전달.
- `st.cache_data`를 사용하되 기준월·법인·차원 필터를 캐시 키에 포함.
- 사용자에게 원천 회원 상세를 내려주지 않고 APP 집계 View를 조회.
- 한 화면에서 동일 대형 CTE를 여러 번 실행하지 않는다.

### 12.4 MSTR 분석엔진 기능 대응

| MSTR 기능 | Streamlit 대응 |
|---|---|
| 뷰필터 | SQL WHERE + UI 필터 |
| 동적집계 | 선택된 차원 목록으로 안전한 GROUP BY 구성 |
| 부분합 | Snowflake `GROUPING SETS` 또는 Pandas/Polars subtotal |
| 크로스탭 | `st.dataframe`용 Pivot DataFrame |
| 정렬 | 차원 `SORT_ORDR` 우선, 명칭은 보조 |
| 파생요소 | CORE/MART View의 명시적 CASE 컬럼 |

---

## 13. 성능·보안 설계

### 13.1 성능

- `TM_MM_FDRM_MBER_DVLP_AMT` 적재본은 `STRD_MT=LEFT(OCCRRNC_DE,6)` 파생컬럼을 저장한다.
- 큰 Window 변환은 기준월 파티션 단위로 증분 처리한다.
- 앱은 `APP_RPT_DEPT_MBER_DVLP`와 `APP_RPT_FEE_FORECAST_DECREASE` 같은 집계 View만 조회한다.
- Snowflake Search Optimization/Cluster Key는 실제 Query Profile 확인 후 `STRD_MT`, `CPR_DIV_CD` 중심으로 판단한다.
- Dimension join 전에 Fact를 기준월로 줄인다.

### 13.2 보안

- Streamlit Role은 APP View에만 SELECT.
- 원천의 `RRN_*`, `MBER_KORNM`, 전화, 이메일, 주소 컬럼은 앱 Role에서 차단.
- 필요 시 `MBER_NO` Masking Policy 적용.
- 다운로드도 집계 결과만 허용.
- 쿼리 로그에 개인정보 필터값을 남기지 않는다.

---

## 14. 검증 절차

1. 원천 월별 행 수와 금액합계.
2. 함수 변환 후 개발구분/활동구분별 행·회원·금액.
3. 부서/사업/법인 차원 연결 전후 행 수.
4. 최종 Grain별 `FULL OUTER JOIN` 비교.
5. 비교 항목:
   - 누락 키
   - 추가 키
   - 행 수 차이
   - 회원 수 차이
   - 금액건수 차이
   - 금액 차이
   - 차원 귀속 차이
6. `DECIMAL`로 자료형을 통일한 후 비교.
7. 월마감 스냅샷과 현재 ODS 재계산의 구조적 차이는 결함과 분리해 기록.

검증 SQL은 결과에 다음 컬럼을 포함하도록 한다.

```text
DIFF_TYPE
BUSINESS_KEY...
SNOWFLAKE_ROW_CNT / MSTR_ROW_CNT / ROW_DIFF
SNOWFLAKE_MBER_CNT / MSTR_MBER_CNT / MBER_DIFF
SNOWFLAKE_AMT_CNT / MSTR_AMT_CNT / AMT_CNT_DIFF
SNOWFLAKE_AMT / MSTR_AMT / AMT_DIFF
```

---

## 15. 아직 확인하거나 제공해야 할 자료

| 우선순위 | 자료 | 필요한 이유 |
|---:|---|---|
| 1 | Snowflake 실제 DB/Schema/Object 매핑표 | 문서의 논리명을 실행 가능한 이름으로 변환 |
| 1 | `MART.D_SPNSR_BSNS_V` 정확한 정의 | 다월 종료일/활동 상태 일반화 |
| 1 | `01.부서별 회원개발`의 원본 MSTR `WJXBFS4~5` 결과 | 누계 독립 검증 |
| 1 | 과거 MSTR 월 팩트의 Snowflake 이관 여부 | 월마감 스냅샷 정확성 결정 |
| 2 | Snowflake 적재 주기·지연시간·마감 기준 | 앱에 최신월/마감월 표시 |
| 2 | Snowflake 테이블의 PK 대체키·중복 현황 | Window/Join 중복 방지 |
| 2 | Streamlit 사용자 Role과 법인별 접근권한 | Row Access Policy 설계 |
| 3 | 추가 MSTR 리포트 SQL과 최종 결과 표본 | 확장 오브젝트의 실제 사용 범위 확정 |

---

## 16. CoCo에 전달할 구현 요청문

아래 문장을 이 문서와 함께 CoCo에 전달한다.

> 첨부된 `Snowflake Streamlit CoCo용 MSTR_DW·MSTR_ODS 통합 참조 문서`를 데이터 정의의 기준으로 사용해 주세요. 먼저 Snowflake의 실제 테이블과 문서의 논리 오브젝트를 매핑하고, 매핑되지 않은 테이블이나 컬럼을 임의로 생성하지 마세요. `01.부서별 회원개발`과 `후원사업별 감액회원 신규기존구분`을 각각 MART/APP View와 Native Streamlit 화면으로 구현해 주세요. 계산식, Window 함수의 파티션/정렬, FULL OUTER JOIN, DISTINCT 회원 집계, 당해연도 누계 범위는 문서와 동일하게 유지하세요. MS SQL 전용 문법은 Snowflake 문법으로 변환하되 업무 의미는 변경하지 마세요. 먼저 단계별 검증 SQL과 기준값 대사 결과를 제시하고, 검증 통과 후 UI를 완성하세요. 개인정보 컬럼은 사용하지 말고 앱 Role은 집계 View만 조회하도록 구성하세요. 불명확한 항목은 추정하지 말고 질문 목록으로 반환하세요.

CoCo의 산출물은 다음 순서로 요청한다.

1. 오브젝트 매핑표
2. 미확인 항목 목록
3. CORE/MART/APP DDL
4. 증분 적재 또는 Dynamic Table/Task 설계
5. 기준값 대사용 SQL
6. Streamlit 소스
7. 배포·권한 부여 SQL
8. 운영 점검 체크리스트

---

## 17. 공유된 전체 오브젝트 체크리스트

### 17.1 함수

- `dbo.FN_MM_ACT_DATE`
- `dbo.FN_MM_SPNSR_ACT`
- `dbo.FN_MM_SPNSR_DVLP`
- `dbo.FN_PM_SETLE_BASE`
- `dbo.FN_PM_SETLE_BASE_NEW`
- `dbo.FN_RM_RELATNSP_MSTR_INFO`
- `dbo.FN_RM_SPSNR_ACT`

### 17.2 View

- `mart.D_CPR_DIV_CD`
- `mart.D_DEPT_CD`, `D_DEPT2_CD`, `D_DEPT3_CD`, `D_DEPT4_CD`, `D_DEPT5_CD`
- `mart.D_DVLP_DIV_CD`
- `mart.D_NEW_OLD_DIV_CD`
- `mart.D_SPNSR_BSNS_ABRV_CD`
- `mart.D_STRD_MT_CD`, `D_STRD_ADD_MT_CD`
- `mart.D_MS_MBER_INFO_CD`
- `mart.F_MS_CRMN`, `mart.F_MS_EVENT`, `mart.F_MS_MSG`
- `dbo.VM_PM_SETLE_INFO`

### 17.3 테이블/팩트/차원

- `mart.F_MM_SPNSR_DVLP`, `mart.F_MM_SPNSR_DVLP_SUM`, `mart.F_MM_SPNSR_ACT`
- `mart.F_PM_MBRFEE`
- `mart.F_MM_DEPT_ACMSLT`, `mart.F_MM_JOIN_MBER`, `mart.F_MM_MBER_SURV`, `mart.F_MM_MBER_IG_ANAL`
- `mart.D_CM_DEPT_INFO`, `mart.D_CMMN_DTL_CD`, `mart.D_SPNSR_BSNS_INFO`, `mart.D_SPNSR_BSNS_V`
- `mart.D_MM_MBER_STRD_MT_INFO`, `mart.D_MM_MBER_SETLE_STRD_MT_INFO`
- `mart.D_PM_MBER_SPNSR_PAY_INFO`, `mart.D_FDRM_MBER_INFO_CD`
- `mart.D_CMPGN_CD`, `mart.D_CMPGN_EXPL_CD`, `mart.D_STRD_CAL_CD`

### 17.4 프로시저

- 핵심: `USP_F_MM_SPNSR_DVLP`, `USP_F_MM_SPNSR_DVLP_SUM`, `USP_F_MM_SPNSR_ACT`, `USP_F_MM_SPNSR_ACT_UP`
- 차원: `USP_D_CM_DEPT_INFO`, `USP_D_FDRM_MBER_INFO_CD`, `USP_D_MM_MBER_STRD_MT_INFO`, `USP_D_MM_MBER_SETLE_STRD_MT_INFO`, `USP_D_PM_MBER_SPNSR_PAY_INFO`, `USP_D_SPNSR_BSNS_INFO`, `USP_D_CMPGN_CD`, `USP_D_CMPGN_EXPL_CD`, `USP_D_CMMN_DTL_CD`, `USP_D_STRD_CAL_CD`
- 버전 보관: `USP_D_MM_MBER_STRD_MT_INFO_202004`, `USP_F_MM_SPNSR_ACT_202004`
- 회원/부서: `USP_F_MM_DEPT_ACMSLT`, `USP_F_MM_JOIN_MBER`, `USP_F_MM_MBER_SURV`, `USP_F_MM_MBER_IG_ANAL`, `USP_F_MM_MBER_IG_ANAL_UP`, `USP_F_MM_MBER_IG_ANAL_UP_01`, `USP_F_MM_MBER_IG_ANAL_UP_02`
- 개발 초기/보정: `USP_F_MM_SPNSR_DVLP_INIT`, `USP_F_MM_SPNSR_DVLP_INIT_UP`, `USP_F_MM_SPNSR_DVLP_INIT_UP01`, `USP_F_MM_SPNSR_DVLP_INIT_UP02`, `USP_F_MM_SPNSR_DVLP_SUM_INIT`, `USP_TEMP_F_MM_SPNSR_ACT_UP`
- 서비스: `USP_F_MS_CRMN_SUM`, `USP_F_MS_CRMN_EVENT_SUM`, `USP_F_MS_EVENT_SUM`, `USP_F_MS_EMAIL`, `USP_F_MS_MSG_SUM`, `USP_F_MS_PSTMTR_SNDNG`, `USP_F_MSG`
- 결연: `USP_F_RM_CHILD`, `USP_F_RM_RELATNSP`, `USP_F_RM_EXPL_ACMSLT_DEPT`
- 실행제어: `USP_INIT_RUN_MART`, `USP_RUN_D_MART`, `USP_RUN_INIT_MART`, `USP_RUN_M_MART`, `USP_RUN_M_MART_TEST`, `USP_BCHLOG`, `USP_BCHERR`

### 17.5 정의 내부에서 이름만 확인된 보조 오브젝트

아래 오브젝트는 공유된 함수·프로시저의 의존성에서 이름은 확인됐지만 이 문서 작성 시 전체 정의를 독립 검증하지 않았다. 추가 리포트 구현 시 원본 DDL을 먼저 확보한다.

- 차원/코드: `D_AREA_CD`, `D_CRMN_CD`, `D_MBER_DVLP_GOAL_CD`, `D_MM_MBER_SPNSR_INFO`, `D_ONCE_MBER_INFO_CD`, `D_SIGUN_AREA_CD`, `D_SIGUN_AREA_CD_V`
- 서비스 팩트: `F_CNSL`, `F_CRMN`, `F_EVENT`, `F_MSG`, `F_MS_CRMN_EVENT_SUM`, `F_MS_CRMN_SUM`, `F_MS_EMAIL`, `F_MS_EVENT_SUM`, `F_MS_MSG_SUM`, `F_MS_PSTMTR_SNDNG`
- 결연 팩트: `F_RM_CHILD`, `F_RM_EXPL_ACMSLT_DEPT`, `F_RM_RELATNSP`
- 실행 참조: `USP_RUN_F_MM_MBER_IG_ANAL`

---

## 18. 최종 판단

- `01.부서별 회원개발`의 선택월 `WJXBFS1~3`은 MSTR과 상세 Grain까지 검증됐다.
- 회비예측 감액/활동 리포트의 업무 계산식은 재현됐지만, 과거 월마감 스냅샷과 현재 ODS 재계산의 구조적 차이가 존재한다.
- Snowflake에서는 화면 쿼리로 모든 함수를 즉시 재계산하기보다 검증된 MART/Dynamic Table을 먼저 만들고 Streamlit은 집계 View만 조회하는 구성이 안전하다.
- CoCo가 구현을 시작하기 전에 실제 Snowflake 오브젝트 매핑과 과거 DW 스냅샷 이관 정책을 확정해야 한다.
