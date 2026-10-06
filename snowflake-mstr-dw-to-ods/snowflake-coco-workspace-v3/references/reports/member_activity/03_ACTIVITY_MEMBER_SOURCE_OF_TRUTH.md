# ACT_2_1 / ACT_2_2 활동회원 ODS Source of Truth

## 적용 범위
- `ACT_2_1_MEMBER_TYPE`
- `ACT_2_2_BUSINESS`

실행 원천은 오직 `GN_DW.BRONZE_CRM`. MSTR_DW는 조회하지 않는다.

## 기준 파라미터
- `STRD_MT=YYYYMM`
- `CPR_DIV_CD` 기본 I
- `MONTH_31=STRD_MT || '31'` : 문자열 상한
- `MONTH_END=실제 달력 말일`
- `SETLE_CUTOFF=검증된 기존 로직의 기준시점`

## 처리 순서
```text
PARAMS
→ DEPT_MAP / DEPT4_DIM / BUSINESS_DIM
→ STATUS_HISTORY → MEMBER_MONTH
→ SETLE_SOURCE → SETLE_MONTH
→ PAYMENT_MONTH
→ LAST_DSCNTC + LAST_RE_SPNSR
→ LAST_ACTIVITY_DATE
→ HAS_LIVE_SPONSOR
→ ACTIVE_MEMBER
→ ACTIVE_HISTORY
→ ACTIVE_FACT
→ ACTIVE_AGG
```

중단 지표:
```text
DSCNTC_SOURCE → DSCNTC_FACT → DSCNTC_AGG
```

## MEMBER_MONTH
`TH_MM_FDRM_MBER_STNG_DTLS`에서 기준월 회원별 `FRST_REGIST_DT DESC` 최신 1건을 사용한다.
`TM_PM_SETLE_INFO.RQEST_EXCL_END_DE IS NOT NULL` 청구제외 예외를 반영한다.
재구성된 상태코드 2~11이면 `NPY_YN='Y'`, 그 외 `N`.

## SETLE_MONTH
`TM_PM_SETLE_INFO` + `TH_PM_SETLE_INFO_HIST`를 `UNION ALL`.
기준시점까지 회원+법인별 `SETLE_KEY DESC` 최신 1건.

202606 활동회원 진단에서 ODS `CPR_DIV_CD`는 이미 I/S로 확인됨. 활동 Base에 1→I, 2→S 변환을 자동 추가하지 않는다.

## ACTIVE_MEMBER
최근 중단일과 최근 재후원일로 실제 활동종료일을 계산한다.

1. 재후원 없음 → 최근 중단일 - 1일
2. 중단일 > 재후원일 → 최근 중단일 - 1일
3. 재후원일 < 기준월 실제 말일 → 기준월 실제 말일
4. 그 외 → 재후원일

회원은 기준월 말에 유효한 후원사업을 하나 이상 가지고 있어야 한다.
기준월 실제 말일이 `회원 FRST_REGIST_DT ~ ACTUAL_DT` 범위에 있어야 한다.

202606 진단:
- 후보 732,745행
- DISTINCT 회원 732,745

## ACTIVE_HISTORY — 핵심
원천 `TM_MM_FDRM_MBER_DVLP_AMT`.

후원관계 Grain:
`SPNSR_NO + SPNSR_BSNS_NO`.

기준월까지:
```sql
SUM(SPNSR_AMT) OVER (
  PARTITION BY SPNSR_NO, SPNSR_BSNS_NO
) AS SUM_AMT
```

최종 속성행:
```sql
ROW_NUMBER() OVER (
  PARTITION BY SPNSR_NO, SPNSR_BSNS_NO
  ORDER BY OCCRRNC_DE DESC, SER_NO DESC
) AS RNUM
```

활동 후원:
```text
RNUM=1
AND SUM_AMT>0
AND 회원이 ACTIVE_MEMBER에 포함
```

금지:
- 마지막 이벤트 행의 `SPNSR_AMT`만 현재 잔액으로 사용
- `DVLP_DIV_CD IN (1,2,3,4)`만으로 활동 여부 판단

## 신규/기존
```text
회원 TM_MM_FDRM_MBER_INFO.FRST_REGIST_DT 연도 = 기준연도
AND
후원 TM_MM_FDRM_MBER_SPNSR.FRST_REGIST_DT 연도 = 기준연도
→ 1 신규
그 외 → 2 기존
```
DEV_1_3/1_4의 최초 신규개발일 기준과 혼용 금지.

## 활동 부서
`TM_MM_FDRM_MBER_SPNSR.ACMSLT_DEPT_CD`를 `TM_CM_DEPT_INFO.ACMSLT_UPPER_DEPT_ID` 계층으로 DEPT4에 매핑.
개발이벤트의 `ACMSLT_DEPT_CD`로 대체하지 않는다.
- Root `ZV000000`
- 검증된 중간 제외 `C.DEPT_ID <> 'ZC000029'`
- 미분류 `Z~`

## 활동 법인
후원사업 마스터 법인만으로 최종 활동 Fact 법인을 정하지 않는다.
`SETLE_MONTH` 회원+법인 최신 결제정보를 연결한다.
법인 I 리포트는 최종 Fact `CPR_DIV_CD='I'`.

## 활동건
```text
SPNSR_AMT = SUM_AMT
SPNSR_AMT_CNT = SUM_AMT / 10000.0
```
물리 후원 개수/이벤트 행 개수가 아니다.

## PAYMENT_MONTH
`TM_PM_MBRFEE_ACMSLT`:
- USE_YN='Y'
- PRCS_STAT_CD='S'
- PAY_STAT_CD='S'
- MBRFEE_DIV_CD='E'
- RETUN_MBRFEE_KEY IS NULL
- PAY_DE <= MONTH_END

후원번호+후원사업번호별 당월 PAY_AMT.

## ACT_2_1 집계
Grain:
`STRD_MT + NEW_OLD_DIV_CD + DEPT4_ID + CPR_DIV_CD`.

- WJXBFS1 = COUNT(DISTINCT MBER_NO)
- WJXBFS2 = SUM(SPNSR_AMT_CNT)
- WJXBFS3 = SUM(CASE WHEN NPY_YN='N' THEN PAY_AMT END)

새 상위 합계가 필요하면 raw ACTIVE_FACT에서 그 Grain으로 DISTINCT를 다시 계산한다.

## ACT_2_2 집계
별도 활동판정 SQL을 만들지 않는다.
ACT_2_1과 **동일 ACTIVE_FACT**에 `SPNSR_BSNS_ID/SPNSR_BSNS_NM` 차원만 추가한다.

- 사업별 회원수 = COUNT(DISTINCT MBER_NO)
- 사업별 활동건 = SUM(SPNSR_AMT_CNT)
- Grand 회원수 = raw ACTIVE_FACT 전체 DISTINCT
- 사업별 회원수 SUM을 Grand로 사용 금지
- 사업명 contains는 임시 호환. 정식은 ID Mapping.
- 미매핑 ID는 버리지 말고 목록/회원수/활동건을 표시해 분류 결정을 받는다.

## 중단 Branch
`TM_MM_FDRM_MBER_DVLP_AMT`:
- DVLP_DIV_CD='5'
- OCCRRNC_DE가 회원 중단일과 일치
- 기준월 동일월
- 회원+후원+후원사업+월별 MAMT
- SER_NO DESC 최종 행
- 중단건 = SUM(ABS(MAMT/10000.0))

이 Branch는 STOP_3_1 화면과 자동 동일시하지 않는다.

## 202606 / I 회귀검증
- 활동 Fact 행수: 708,866
- 활동 회원수: 631,207
- 활동(건): 1,350,547.9944002
- 정상회원 납입금액: 12,559,666,635
- 중단 Fact 행수: 9,262
- 중단 회원수(참고): 8,323
- 중단(건): 17,728.91

부서별 기준:
| NEW_OLD | DEPT4_ID | ACT_ROWS | ACT_MBER | ACT_AMT_CNT | NORMAL_PAY | STOP_ROWS | STOP_AMT_CNT |
|---|---|---:|---:|---:|---:|---:|---:|
| 1 | ZB000001 | 46807 | 43934 | 90538.7100 | 751336000 | 875 | 1688.3000 |
| 1 | ZB000002 | 3528 | 3379 | 7298.9600 | 56047800 | 143 | 267.9000 |
| 1 | ZB000006 | 8602 | 8337 | 19039.5900 | 139007900 | 371 | 686.5500 |
| 2 | ZB000001 | 433569 | 369936 | 784924.3652 | 7366693643 | 5535 | 9930.4952 |
| 2 | ZB000002 | 67596 | 66339 | 130847.3533 | 1237518233 | 754 | 1631.0649 |
| 2 | ZB000003 | 6105 | 6070 | 10658.2779 | 103116779 | 27 | 46.0000 |
| 2 | ZB000004 | 28 | 28 | 28.0000 | 270000 | 0 | 0 |
| 2 | ZB000005 | 148 | 146 | 206.5000 | 1965000 | 0 | 0 |
| 2 | ZB000006 | 136811 | 133044 | 299193.2300 | 2827924300 | 1523 | 3429.5999 |
| 2 | ZB000007 | 5671 | 5574 | 7812.9080 | 75785980 | 34 | 49.0000 |
| 2 | ZB000008 | 1 | 1 | 0.1000 | 1000 | 0 | 0 |

## 오류 진단 순서
1. MEMBER_MONTH
2. SETLE_MONTH
3. ACTIVE_MEMBER
4. ACTIVE_HISTORY
5. ACTIVE_FACT
6. ACTIVE_AGG
7. DSCNTC_SOURCE
8. DSCNTC_FACT
9. DSCNTC_AGG

각 단계에서 ROW COUNT, COUNT(DISTINCT MBER_NO), SUM_AMT, SPNSR_AMT_CNT, PAY_AMT를 대사한다.
