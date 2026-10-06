# Snowflake CoCo Reference — 회원통계보고서 2-1 활동회원 현황

## 0. 문서 목적

이 문서는 Snowflake Native Streamlit의 **회원통계보고서 > 2. 회원활동 > 2-1. 활동회원 현황(회원구분별)** 을 생성·수정할 때 CoCo가 최우선으로 참조해야 하는 업무 규칙이다.

- REPORT_ID: `ACT_2_1_MEMBER_TYPE`
- LEGACY_ALIAS: `MEMBER_ACTIVITY_2_1`
- REFERENCE_PRIORITY: `P0 / SOURCE_OF_TRUTH`
- 원천 계층: `GN_DW.BRONZE_CRM`
- MSTR_DW의 `MART.F_MM_SPNSR_ACT`, `FN_MM_SPNSR_ACT`, `FN_MM_ACT_DATE`를 직접 참조하지 않는다.
- Snowflake에서는 MSTR_ODS 원천 테이블로 해당 로직을 재현한다.
- 현재 Streamlit의 **2안(`load_active_v2`)이 기준 구현**이다.
- 기존 1안의 `load_active_agg`, `load_active_members`는 **참조 금지/폐기 대상 로직**으로 취급한다.

---

## 1. 왜 기존 1안이 틀렸는가

### 1.1 가장 중요한 오류 — 마지막 이벤트 금액을 활동(건)으로 사용

기존 1안은 아래와 같은 방식이다.

```sql
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO
    ORDER BY A.OCCRRNC_DE DESC, A.SER_NO DESC
) = 1
```

그리고 선택된 마지막 행의:

```sql
A.SPNSR_AMT
```

를 사용해:

```sql
SUM(AF.SPNSR_AMT / 10000.0)
```

로 활동(건)을 계산했다.

이 방식은 MSTR `F_MM_SPNSR_ACT`의 의미와 다르다.

### 올바른 방식

후원번호 + 후원사업번호 단위로 **기준월까지의 모든 금액 변동을 누적**해야 한다.

```sql
SUM(A.SPNSR_AMT) OVER (
    PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO
) AS SUM_AMT
```

동시에 최종 속성 행은:

```sql
ROW_NUMBER() OVER (
    PARTITION BY A.SPNSR_NO, A.SPNSR_BSNS_NO
    ORDER BY A.OCCRRNC_DE DESC, A.SER_NO DESC
) AS RNUM
```

으로 선택한다.

최종 활동 후원은:

```sql
RNUM = 1
AND SUM_AMT > 0
```

이어야 한다.

활동(건):

```text
SPNSR_AMT_CNT = SUM_AMT / 10000.0
```

### 예시

후원 금액 변경이 다음과 같다고 가정한다.

```text
신규     +30,000
증액     +10,000
감액     -10,000
```

기준월 현재 후원잔액은:

```text
30,000
```

이다.

그러나 마지막 이벤트 행만 사용하면:

```text
-10,000
```

이 되어 활동(건)이 `-1`로 계산될 수 있다.

MSTR 방식은 누적잔액 `30,000 / 10,000 = 3건`이다.

---

## 2. 활동회원 판정은 단순 미중단 후원 필터가 아니다

기존 1안은 다음 조건을 활동회원 판정의 핵심으로 사용했다.

```text
후원사업 중단일 > 기준월말
+
마지막 DVLP_DIV_CD IN ('1','2','3','4')
```

이것만으로 활동회원을 판정하면 안 된다.

MSTR `FN_MM_ACT_DATE` 상당의 아래 흐름을 반드시 유지한다.

```text
LAST_DSCNTC
    ↓
LAST_RE_SPNSR
    ↓
LAST_ACTIVITY_DATE
    ↓
HAS_LIVE_SPONSOR
    ↓
ACTIVE_MEMBER
```

### 필수 의미

1. 회원별 기준월까지 가장 최근 중단일을 찾는다.
2. 회원별 기준월까지 가장 최근 재후원일을 찾는다.
3. 중단일과 재후원일의 순서를 비교해 실제 활동 종료일 `ACTUAL_DT`를 계산한다.
4. 기준월 말에 유효한 후원을 하나 이상 가진 회원만 후보가 된다.
5. 기준월 실제 말일이 다음 범위에 있어야 한다.

```text
회원 최초등록일 <= 기준월말 <= ACTUAL_DT
```

즉, `SPNSR_DSCNTC_DE` 하나만 보고 활동 여부를 결정하지 않는다.

---

## 3. DVLP_DIV_CD는 활동회원 여부 자체가 아니다

금지:

```sql
AND A.DVLP_DIV_CD IN ('1','2','3','4')
```

를 활동회원 판정의 핵심 조건으로 사용하는 것.

`DVLP_DIV_CD`는 개발 이벤트의 종류이다.

활동회원 여부는 다음 두 조건으로 결정한다.

```text
1. ACTIVE_MEMBER에 포함되는 회원
2. SPNSR_NO + SPNSR_BSNS_NO의 기준월 누적 SUM_AMT > 0
```

마지막 이벤트 코드 자체를 활동여부로 사용하지 않는다.

---

## 4. 법인(CPR_DIV_CD) 귀속 규칙

기존 1안은 주로:

```text
TM_CM_SPNSR_BSNS_INFO.CPR_DIV_CD
```

를 이용해 사단법인 `I`를 판정했다.

그러나 활동 Fact의 법인 귀속은 결제정보 기준을 유지해야 한다.

### 필수 로직

현재 결제정보:

```text
TM_PM_SETLE_INFO
```

결제 이력:

```text
TH_PM_SETLE_INFO_HIST
```

을 `UNION ALL` 한다.

기준시점까지:

```text
MBER_NO + CPR_DIV_CD
```

별 `SETLE_KEY DESC` 최신 1건을 선택한다.

활동 Fact:

```sql
LEFT JOIN SETLE_MONTH ST
  ON A.MBER_NO = ST.MBER_NO
 AND BUSINESS_DIM.CPR_DIV_CD = ST.CPR_DIV_CD
```

법인:

```sql
COALESCE(ST.CPR_DIV_CD, 'I')
```

현재 Snowflake ODS의 법인 코드가 이미 `I/S`라면 불필요한 코드 변환을 추가하지 않는다.

---

## 5. 부서(DEPT4) 귀속 규칙

기존 1안은 마지막 개발 이벤트:

```text
TM_MM_FDRM_MBER_DVLP_AMT.ACMSLT_DEPT_CD
```

를 직접 DEPT4로 변환했다.

활동 Fact의 기준 구현은 후원 기본정보:

```text
TM_MM_FDRM_MBER_SPNSR.ACMSLT_DEPT_CD
```

를 사용한다.

필수 JOIN:

```sql
JOIN TM_MM_FDRM_MBER_SPNSR S
  ON A.MBER_NO = S.MBER_NO
 AND A.SPNSR_NO = S.SPNSR_NO
```

그 다음:

```sql
LEFT JOIN DEPT_MAP MAP
  ON COALESCE(S.ACMSLT_DEPT_CD, 'Z~') = MAP.SRC_DEPT_ID
```

로 `DEPT4_ID`를 만든다.

MSTR `D_DEPT_CD` 재현 시 중간 레벨의 부서까지 임의로 DEPT4에 연결하지 않는다.
검증된 계층 Grain을 유지한다.

---

## 6. 신규/기존 구분

신규회원은 단순히 회원이 기준연도에 등록됐다고 판단하지 않는다.

아래 두 조건이 모두 참이어야 신규다.

```text
회원 최초등록연도 = 기준연도
AND
후원 최초등록연도 = 기준연도
```

SQL 예시:

```sql
CASE
    WHEN TO_CHAR(M.FRST_REGIST_DT, 'YYYY') = LEFT(STRD_MT, 4)
     AND TO_CHAR(S.FRST_REGIST_DT, 'YYYY') = LEFT(STRD_MT, 4)
    THEN '1'
    ELSE '2'
END
```

- `1` = 신규
- `2` = 기존

### 금지

아래 값을 신규/기존 판단 기준으로 사용하지 않는다.

```text
STDR_DE
최초 개발 이벤트 날짜만
DVLP_DIV_CD만
현재 회원상태만
```

현재 Streamlit에 남아 있는 `load_active_members()`의:

```python
CASE WHEN YEAR(MI.STDR_DE) = year THEN '신규회원'
```

형태는 2-1 활동회원 로직의 기준으로 사용하지 않는다.

---

## 7. 회원 월상태 및 NPY_YN

MSTR의 기준월 회원상태를 재현하기 위해 다음 원천을 사용한다.

```text
TM_MM_FDRM_MBER_INFO
TH_MM_FDRM_MBER_STNG_DTLS
TM_PM_SETLE_INFO
```

해당 기준월의 최신 상태이력과 청구제외 예외를 반영한 뒤:

```text
MBER_STAT_CD BETWEEN 2 AND 11 → NPY_YN='Y'
그 외 → NPY_YN='N'
```

로 계산한다.

정상회원 납입금액:

```sql
SUM(
    CASE
        WHEN NPY_YN = 'N'
        THEN PAY_AMT
    END
)
```

---

## 8. 납입금액

원천:

```text
TM_PM_MBRFEE_ACMSLT
```

필수 조건:

```text
USE_YN = 'Y'
PRCS_STAT_CD = 'S'
PAY_STAT_CD = 'S'
MBRFEE_DIV_CD = 'E'
RETUN_MBRFEE_KEY IS NULL
PAY_DE <= 기준월 실제 말일
```

후원번호 + 후원사업번호별로 당월 납입금액을 집계한다.

---

## 9. 기준월 날짜 처리

두 종류의 날짜를 구분한다.

### MONTH_31

MSTR 원 함수 호환용 문자열 상한:

```text
YYYYMM31
```

예:

```text
20260231
20260431
```

실제 날짜가 아니라 `YYYYMMDD` 문자열 비교 상한으로 사용한다.

### MONTH_END

실제 달력 말일:

```text
2024-02-29
2026-02-28
2026-04-30
```

실제 날짜 비교에는 `LAST_DAY()` 또는 동등한 달력 계산을 사용한다.

### 금지

```python
"28" if month == 2 else ...
```

와 같이 2월을 항상 28일로 고정하지 않는다.

윤년 조회에서 데이터가 누락될 수 있다.

---

## 10. 최종 활동 Fact의 최소 Grain

활동 Fact의 기준 Grain:

```text
STRD_MT
+ SPNSR_NO
+ SPNSR_BSNS_NO
+ MBER_NO
+ SPNSR_BSNS_ID
+ CPR_DIV_CD
+ DEPT4_ID
+ NEW_OLD_DIV_CD
```

필수 값:

```text
SUM_AMT
SPNSR_AMT_CNT
NPY_YN
PAY_AMT
```

필수 조건:

```text
ACTIVE_MEMBER 회원
RNUM = 1
SUM_AMT > 0
```

---

## 11. 2-1 MSTR 메트릭

### WJXBFS1 — 활동(명)

```sql
COUNT(DISTINCT MBER_NO)
```

### WJXBFS2 — 활동(건)

```sql
SUM(SPNSR_AMT_CNT)
```

여기서:

```text
SPNSR_AMT_CNT = SUM_AMT / 10000.0
```

### WJXBFS3 — 정상회원 납입금액

```sql
SUM(
    CASE
        WHEN NPY_YN = 'N'
        THEN PAY_AMT
    END
)
```

### WJXBFS4 — 중단(건)

```sql
SUM(ABS(중단 SPNSR_AMT_CNT))
```

---

## 12. 중단 Fact

중단은 활동 Fact와 별도의 Branch로 만든다.

원천:

```text
TM_MM_FDRM_MBER_DVLP_AMT
TM_MM_FDRM_MBER_SPNSR_DSCNTC
```

필수 조건:

```text
DVLP_DIV_CD = '5'
OCCRRNC_DE = SPNSR_DSCNTC_DE
기준월과 동일 월
```

Grain:

```text
MBER_NO
+ SPNSR_NO
+ SPNSR_BSNS_NO
+ STRD_MT
```

`SER_NO DESC` 최종 1건의 월합 `MAMT`를 사용한다.

---

## 13. 최종 집계

MSTR 원본과 동일하게 활동과 중단을 별도로 집계한 뒤 결합한다.

```text
ACTIVE_AGG
DSCNTC_AGG
```

결합:

```sql
FULL OUTER JOIN
```

Key:

```text
CPR_DIV_CD
DEPT4_ID
NEW_OLD_DIV_CD
STRD_MT
```

### 금지

```text
INNER JOIN으로 변경
LEFT JOIN으로 임의 단순화
활동/중단을 하나의 이벤트 필터로 합침
```

---

## 14. Python/Streamlit 집계 주의

SQL에서 이미:

```sql
COUNT(DISTINCT MBER_NO)
```

를 특정 DEPT4 Grain으로 계산했다면,
더 상위 레벨의 전체 활동회원 수를 만들 때 단순 `SUM()`을 사용하면
한 회원이 여러 부서에 존재하는 경우 중복될 수 있다.

새로운 합계/부분합/후원사업별 화면을 만들 때는 가능하면
**해당 목표 Grain의 raw ACTIVE_FACT에서 COUNT(DISTINCT MBER_NO)를 다시 계산**한다.

현재 2안의 표시값이 MSTR과 검증되어 있다면 기존 화면은 유지하되,
새로운 차원을 추가할 때 이 규칙을 반드시 적용한다.

활동(건)은 금액기반 지표이므로 동일 Grain 내에서 합산 가능하다.

---

## 15. 현재 Streamlit 구현 우선순위

### P0 — 사용 가능 / 기준 구현

```text
load_active_v2()
```

그리고 해당 함수와 동일한 업무 흐름:

```text
MEMBER_MONTH
SETLE_MONTH
LAST_DSCNTC
LAST_RE_SPNSR
LAST_ACTIVITY_DATE
HAS_LIVE_SPONSOR
ACTIVE_MEMBER
ACTIVE_HISTORY
ACTIVE_FACT
DSCNTC_SOURCE
DSCNTC_FACT
ACTIVE_AGG
DSCNTC_AGG
```

### P1 — 후원사업별 확장 시 참고 가능

```text
load_activity_member_by_business()
```

단, 후원사업 표시용 분류 로직과 활동회원 계산 Base Logic을 구분한다.

### DEPRECATED — 사용 금지

```text
load_active_agg()
load_active_members()
```

이 함수의 활동회원 계산 로직을 복사하거나 신규 화면에 재사용하지 않는다.

특히 다음 패턴은 금지한다.

```sql
마지막 이벤트 1건의 SPNSR_AMT만 사용
DVLP_DIV_CD IN ('1','2','3','4')로 활동 여부 판단
후원사업 마스터 CPR_DIV_CD만으로 법인 판단
개발이벤트 ACMSLT_DEPT_CD를 활동부서로 사용
STDR_DE로 신규/기존 판단
2월 말일을 항상 28일로 처리
```

---

## 16. 회귀검증 기준 — 202606 / CPR_DIV_CD='I'

MSTR_DW 검증값:

```text
활동 Fact 행수       708,866
활동 회원수          631,207
활동(건)             1,350,547.9944002
정상회원 납입금액    12,559,666,635

중단 Fact 행수       9,262
중단 회원수          8,323
중단(건)             17,728.91
```

수정 후 반드시 위 값을 먼저 비교한다.

값이 다르면 UI에서 보정하지 않는다.

다음 단계별로 차이를 찾는다.

```text
1. MEMBER_MONTH
2. SETLE_MONTH
3. ACTIVE_MEMBER
4. ACTIVE_HISTORY
5. ACTIVE_FACT
6. ACTIVE_AGG
7. DSCNTC_SOURCE
8. DSCNTC_FACT
9. DSCNTC_AGG
```

각 단계에서 필요 시:

```text
ROW COUNT
COUNT(DISTINCT MBER_NO)
SUM(SUM_AMT)
SUM(SPNSR_AMT_CNT)
SUM(PAY_AMT)
```

을 비교한다.

---

## 17. CoCo 작업 규칙

`ACT_2_1_MEMBER_TYPE` 또는 Legacy Alias `MEMBER_ACTIVITY_2_1` 관련 요청을 받으면:

1. 이 문서를 최우선으로 읽는다.
2. 기존 Streamlit의 `load_active_v2()` 또는 검증된 활동회원 SQL을 Source of Truth로 사용한다.
3. `load_active_agg()` / `load_active_members()`는 기존 화면 호환 확인 외에는 참조하지 않는다.
4. UI 요구가 변경되어도 활동회원 업무 규칙은 변경하지 않는다.
5. 수치를 맞추기 위한 하드코딩, 비율 보정, 임의 DISTINCT, `drop_duplicates()`를 금지한다.
6. 데이터 차이가 발생하면 CTE 단계별 진단을 먼저 수행한다.
7. 다른 리포트의 정상 SQL/함수/화면은 수정하지 않는다.
8. 동일 Base Logic이 반복될 경우 장기적으로 APP View/Dynamic Table로 공통화하되, 검증 전에는 로직을 축약하지 않는다.

---

## 18. CoCo 요청 시 권장 헤더

```text
MODE=CHANGE_UI
REPORT_ID=ACT_2_1_MEMBER_TYPE
REFERENCE_PRIORITY=P0
SOURCE_OF_TRUTH=Snowflake CoCo Reference — 회원통계보고서 2-1 활동회원 현황

현재 요청은 2-1 활동회원 화면만 수정한다.
활동회원 계산은 본 Reference와 검증된 load_active_v2 로직을 변경하지 않는다.
기존 load_active_agg/load_active_members의 단순화 로직은 사용하지 않는다.
202606/I 회귀검증 기준을 통과한 뒤 UI를 적용한다.
```

---

## 19. 한 줄 핵심

> **활동회원은 "마지막 개발 이벤트"가 아니라 "기준월 말 활동 가능한 회원의 후원별 누적잔액(SUM_AMT > 0)"이다.**
