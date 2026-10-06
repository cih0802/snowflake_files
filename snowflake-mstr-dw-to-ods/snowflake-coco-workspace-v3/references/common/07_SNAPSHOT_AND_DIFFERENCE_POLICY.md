# 과거월 Snapshot 및 수치차이 정책

## 왜 같은 계산식도 과거 값이 달라질 수 있는가
현재 Snowflake `GN_DW.BRONZE_CRM`은 현재 시점의 ODS/CRM 상태다. 과거 월마감 보고서는 당시 시점의 Snapshot 성격을 가질 수 있다.

월마감 이후 다음이 바뀌면 과거 재계산 결과가 달라질 수 있다.
- 회원상태
- 후원 중단/재후원 이력
- 금액 이벤트 정정/삭제
- 실적부서/부서계층
- 후원사업 명칭·법인·분류
- 결제정보 이력
- 지연 적재/사후 유입

Reference Pack은 계산식/조건 혼용 차이는 방지하지만 Snapshot 상태 차이까지 로직만으로 제거할 수는 없다.

## 차이 분류

### LOGIC_DIFF
계산식 차이. 예: 마지막 이벤트 금액 vs 누적잔액, Window Partition 오류, JOIN 방식 오류.
→ 코드 수정.

### GRAIN_DIFF
집계 Grain 차이. 예: 사업별 DISTINCT 회원수 합을 전체 회원수로 사용.
→ 집계 수정.

### FILTER_DIFF
기간/법인/사업/상태 조건 차이.
→ `02_REPORT_CONDITION_MATRIX.md` 확인.

### MAPPING_DIFF
부서/후원사업/캠페인 Mapping 차이.
→ ID Mapping 보완.

### ODS_SNAPSHOT_DIFF
현재 ODS로 과거월을 재계산한 결과와 당시 마감 Snapshot의 상태 차이.
→ 임의 보정 금지.

### DATA_QUALITY_DIFF
중복, NULL, 적재지연, 잘못된 코드.
→ 원천/적재 확인.

## 권장 마감 Snapshot 구조
앞으로 Snowflake가 공식 보고서 기준이 되면 마감월 Fact를 Snapshot으로 보존한다.

```text
GN_DW.BRONZE_CRM
→ 검증된 월 변환
→ MART/CORE 월 Fact
→ CLOSED_MONTH_SNAPSHOT
→ APP/SEMANTIC
→ Streamlit
```

활동회원 Snapshot 최소 논리 컬럼:
- STRD_MT
- CPR_DIV_CD
- NEW_OLD_DIV_CD
- DEPT4_ID
- SPNSR_BSNS_ID
- MBER_NO 또는 보안된 내부 Member Key
- SPNSR_AMT_CNT
- NPY_YN
- PAY_AMT
- ACT_DSCNTC_DIV_CD
- SNAPSHOT_TS
- SOURCE_LOAD_TS
- LOGIC_VERSION

개인정보는 저장하지 않는다.

## 마감 원칙
1. 월마감 전: ODS 재계산 가능.
2. 검증 완료 후 Snapshot 생성.
3. 마감월 기본 조회는 Snapshot 사용.
4. 재마감은 Version을 올리고 이전 Snapshot 보존.
5. UI에 `마감 Snapshot / 현재 ODS 재계산` 출처 표시.

## 과거월 요청 시 CoCo
1. 검증 Snapshot 존재 여부 확인.
2. 있으면 Snapshot 우선.
3. 없으면 ODS 재계산.
4. ODS 재계산이면 과거 Snapshot과 차이 가능성을 명시.
5. 기준값 차이를 특정 행 제외/비율보정으로 숨기지 않음.

## 숫자 차이를 없애기 위한 현실적 범위
Reference Pack으로 방지 가능:
- 잘못된 계산식
- 잘못된 보고서 조건 재사용
- 신규/기존 정의 혼용
- 부서/법인 귀속 오류
- 합계 Grain 오류
- 사업명 문자열 분류 누락
- Float 정밀도 문제
- 특정 보고서 수동보정의 타 보고서 전파

Snapshot 없이는 100% 보장 불가:
- 월마감 이후 과거 원천 자체가 수정된 경우의 완전 일치

따라서 장기 재발방지의 핵심은 **검증된 마감 Snapshot 보존**이다.
