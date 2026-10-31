# MS-SQL vs Snowflake 쿼리 차이 분석
# Co-authored with CoCo

## 분석 일자: 2026-08-26
## 대상: `load_dscntc_12_cumulative` (1-2 연 누계 3개년 비교)

---

## 1. 원본 MS-SQL 구조

### 사용되는 SQL 조각 2개

| SQL ID | 용도 | 호출 위치 |
|---|---|---|
| `DscntcMberListWith` | 중단회원조회 (메인) | `selectDscntcMberList`, `selectDscntcMberListCnt` |
| `SpnsrBsnsDscntcMberListWith` | 후원사업별 중단회원 건수 조회 | 별도 화면 |

### DscntcMberListWith 핵심 로직

```sql
-- CTE_TBL1: 기간 내 중단회원 (회원당 최신 1건)
WITH CTE_TBL1 AS (
    SELECT MBER_NO, SPNSR_DSCNTC_DE, DSCNTC_RSN_CD, DSCNTC_PATH
    FROM (
        SELECT A.MBER_NO, A.SPNSR_DSCNTC_DE, A.DSCNTC_RSN_CD, A.DSCNTC_PATH,
               ROW_NUMBER() OVER(PARTITION BY A.MBER_NO ORDER BY A.SPNSR_DSCNTC_DE DESC) AS RNUM
        FROM TM_MM_FDRM_MBER_SPNSR_DSCNTC A
        LEFT OUTER JOIN TM_MM_FDRM_MBER_INFO B ON A.MBER_NO = B.MBER_NO
        WHERE A.SPNSR_DSCNTC_DE BETWEEN #{DSCNTC_FROM_DE} AND #{DSCNTC_TO_DE}
          AND B.MBER_STAT_CD = 12
          -- ★ 조건부: chkYearNDt='Y'일 때만 아래 적용
          AND (YEAR(B.FRST_REGIST_DT) <> YEAR(A.SPNSR_DSCNTC_DE)
               OR MONTH(B.FRST_REGIST_DT) <> MONTH(A.SPNSR_DSCNTC_DE))
    ) A WHERE A.RNUM = 1
    -- ★ 조건부: DSCNTC_RSN_CD 값이 있으면 추가 필터
)
-- CTE_TBL2: 후원금액 합산 (MBER_NO + SPNSR_DSCNTC_DE 단위)
, CTE_TBL2 AS (
    SELECT MBER_NO, SPNSR_DSCNTC_DE, SUM(SPNSR_AMT) AS SPNSR_AMT
    FROM (
        SELECT A.*, B.MBER_NO, ...
        FROM TM_MM_FDRM_MBER_SPNSR_BSNS A
        LEFT OUTER JOIN TM_MM_FDRM_MBER_SPNSR B ON A.SPNSR_NO = B.SPNSR_NO
        WHERE A.SPNSR_DSCNTC_YN = 'Y'
          AND A.SPNSR_DSCNTC_DE BETWEEN #{DSCNTC_FROM_DE} AND #{DSCNTC_TO_DE}
          AND A.SPNSR_DSCNTC_RSN_CD = '7'
    ) A
    GROUP BY MBER_NO, SPNSR_DSCNTC_DE  -- ★ SPNSR_BSNS_ID 없음!
)
```

### SpnsrBsnsDscntcMberListWith 차이점
- CTE_TBL1: `chkYearNDt` 조건 **없음** (동일 월 제외 미적용)
- CTE_TBL2: `GROUP BY MBER_NO, SPNSR_DSCNTC_DE, SPNSR_BSNS_ID` (후원사업별 분리)
- ACMSLT_DEPT_CD 파라미터 있으면 부서 컬럼도 GROUP BY에 포함

---

## 2. 확정된 차이점 (수정된 분석)

| 우선순위 | 차이 항목 | MS-SQL (DscntcMberListWith) | 현재 Snowflake | 영향 | 판정 |
|:---:|---|---|---|---|---|
| **1** | 동일 월 제외 조건 | `chkYearNDt='Y'`일 때만 적용 (조건부) | **무조건 적용** | chkYearNDt≠'Y'면 SF가 더 적음 | **chkYearNDt 값 확인 필요** |
| **2** | CTE_TBL1 JOIN 유형 | `LEFT OUTER JOIN` | `INNER JOIN` | INFO에 없는 회원 SF에서 탈락 | 확정: 차이 |
| **3** | CTE_TBL2 집계 단위 | `MBER_NO, SPNSR_DSCNTC_DE` | `MBER_NO, SPNSR_DSCNTC_DE` | **동일** | 일치 |
| **4** | DSCNTC_RSN_CD 필터 | CTE_TBL1 RNUM=1 이후 조건부 적용 | 없음 | 파라미터 사용 시 차이 | 값 확인 필요 |
| **5** | MBER_STAT_CD 비교 | `= 12` (정수) | `= '12'` (문자열) | 자료형 암묵적 변환 | 검증 필요 |
| **6** | ROW_NUMBER 동률 | `ORDER BY SPNSR_DSCNTC_DE DESC` | 동일 | 비결정적 선택 | 검증 필요 |
| **7** | 신규/기존 판정 | 원본에 없음 (목록 조회 전용) | FRST_REGIST_DT 연도 = base_year | SF 추가 로직 | 확정 |
| **8** | 컬럼명 오해 | - | `DSCNTC_CNT`가 실제로는 만원 환산 금액 | 혼동 가능 | DSCNTC_AMT_10K로 변경 권장 |

---

## 3. 이전 분석에서 수정된 사항

| 이전 (잘못됨) | 수정됨 |
|---|---|
| "동일 월 제외 조건이 MS-SQL에 없다" | DscntcMberListWith에 **있음** (chkYearNDt='Y' 조건부) |
| "CTE_TBL2가 SPNSR_BSNS_ID별로 집계된다" | DscntcMberListWith는 **MBER_NO+SPNSR_DSCNTC_DE만** (SpnsrBsnsDscntcMberListWith만 SPNSR_BSNS_ID 포함) |
| "두 SQL 조각이 동일한지 불명" | **완전히 다른 화면용** — 화면별로 다른 CTE 호출 |

---

## 4. 미확인 파라미터 (다음 세션에서 확인 필요)

| 파라미터 | 필요한 이유 | 예상 형식 |
|---|---|---|
| `chkYearNDt` | 'Y'면 동일 월 제외 적용 → SF와 일치. 아니면 불일치 | 'Y' 또는 빈값 |
| `DSCNTC_FROM_DE` | 검증 SQL 실행용 | YYYYMMDD |
| `DSCNTC_TO_DE` | 검증 SQL 실행용 | YYYYMMDD |
| `DSCNTC_RSN_CD` | 중단사유 필터 사용 여부 | 빈값 또는 코드값 |
| `CPR_DIV_CD` | 법인구분 확인 | 'I' |
| MS-SQL 실제 결과값 | 비교 대상 수치 | 건수, 회원수, 금액 |

---

## 5. 다음 단계 (TODO)

1. [ ] chkYearNDt 파라미터 값 확인
2. [ ] 실제 실행 파라미터(기간, 법인구분) 확정
3. [ ] 검증 SQL 실행 (단계별 건수 비교)
4. [ ] CTE_TBL1 JOIN 유형을 LEFT JOIN으로 수정
5. [ ] PARITY_MODE 쿼리 작성 및 MS-SQL 결과와 비교
6. [ ] KPI_MODE 쿼리 확정
7. [ ] Streamlit 함수 최종 수정

---

## 6. 검증 SQL (실행 대기 — 파라미터 확정 후)

```sql
-- 파라미터 설정 후 실행
SET DSCNTC_FROM_DE = 'YYYYMMDD';  -- 실제 값으로 변경
SET DSCNTC_TO_DE   = 'YYYYMMDD';  -- 실제 값으로 변경

-- JOIN 유형 차이 확인 (LEFT vs INNER)
SELECT
    'LEFT_JOIN' AS JOIN_TYPE,
    COUNT(*) AS ROW_COUNT,
    COUNT(DISTINCT A.MBER_NO) AS DISTINCT_MBER
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC A
LEFT JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO B ON A.MBER_NO = B.MBER_NO
WHERE A.SPNSR_DSCNTC_DE BETWEEN $DSCNTC_FROM_DE AND $DSCNTC_TO_DE
  AND B.MBER_STAT_CD = '12'

UNION ALL

SELECT
    'INNER_JOIN' AS JOIN_TYPE,
    COUNT(*) AS ROW_COUNT,
    COUNT(DISTINCT A.MBER_NO) AS DISTINCT_MBER
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC A
JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO B ON A.MBER_NO = B.MBER_NO
WHERE A.SPNSR_DSCNTC_DE BETWEEN $DSCNTC_FROM_DE AND $DSCNTC_TO_DE
  AND B.MBER_STAT_CD = '12';

-- 동일 월 제외 영향 확인
SELECT
    'WITH_EXCLUDE' AS FILTER_TYPE,
    COUNT(*) AS ROW_COUNT,
    COUNT(DISTINCT A.MBER_NO) AS DISTINCT_MBER
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC A
LEFT JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO B ON A.MBER_NO = B.MBER_NO
WHERE A.SPNSR_DSCNTC_DE BETWEEN $DSCNTC_FROM_DE AND $DSCNTC_TO_DE
  AND B.MBER_STAT_CD = '12'
  AND (YEAR(B.FRST_REGIST_DT) <> YEAR(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD'))
       OR MONTH(B.FRST_REGIST_DT) <> MONTH(TO_DATE(A.SPNSR_DSCNTC_DE, 'YYYYMMDD')))

UNION ALL

SELECT
    'WITHOUT_EXCLUDE' AS FILTER_TYPE,
    COUNT(*) AS ROW_COUNT,
    COUNT(DISTINCT A.MBER_NO) AS DISTINCT_MBER
FROM GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC A
LEFT JOIN GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO B ON A.MBER_NO = B.MBER_NO
WHERE A.SPNSR_DSCNTC_DE BETWEEN $DSCNTC_FROM_DE AND $DSCNTC_TO_DE
  AND B.MBER_STAT_CD = '12';
```

---

## 7. 수정 예정 Streamlit 함수 구조

```python
def load_dscntc_12_cumulative(sel_year, cum_from, cum_to, mode='KPI', chk_year_n_dt='Y'):
    """
    mode='PARITY': MS-SQL DscntcMberListWith 재현
      - LEFT JOIN 사용
      - chk_year_n_dt에 따라 동일 월 제외 조건 적용/미적용
      
    mode='KPI': 순수 업무 지표
      - LEFT JOIN 사용
      - 동일 월 제외 조건 적용 (chk_year_n_dt='Y' 가정)
    """
    pass  # 파라미터 확정 후 구현
```
