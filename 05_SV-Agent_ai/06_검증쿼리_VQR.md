<!-- LLM-METADATA
doc_id: SV_VQR_VERIFICATION
doc_role: 4단계 — SV 검증쿼리(DoD 회귀) + Verified Query(VQR) 후보 + custom instruction 후보
project: GN_DW (굿네이버스)
created: 2026-07-22
depends_on: 05_1~05_9_SV_DDL_*.sql (배포 완료 2026-07-22), 04_SV_설계.md(정정본), 03_SV_metric_배속.md(정정본)
scope: Phase-1 배포 5 SV (SV_MEMBER_MONTHLY·SV_MEMBER_EVENT·SV_SERVICE·SV_EVENT_PARTICIPATION·SV_BUDGET)
verify_env: GN_DW.SERVING (live) — **2026-08-10 O57 전량 재실측**(종전 2026-07-22 스냅샷 교체)
END-METADATA -->

# 4단계 — 검증쿼리 & Verified Query (VQR)

> 배포된 5 SV를 **실데이터로 검증**(SV 집계 = 단일 FACT 직접집계 일치)하고, Cortex Analyst 스티어링용 **VQR 후보**·**custom instruction 후보**를 확정한다.
> 🔴 **[2026-08-10 O57] 절대값 전량 재실측 + 판정 방식 교정.** 경위 정본 = `20_issue/00_INDEX_이슈원장.md` **§O57**.
> 🔴🔴 **판정 원칙 (`04_SV_설계.md` §6.9-(8) 적용)** — 이 문서의 판정은 **불변식**(`SV값 == FACT값`)으로 한다.
> **절대값은 참고치**다. 절대값을 판정 기준으로 박으면 적재량이 바뀌는 순간 정상 파이프라인이 전건 오탐이 된다
> (§6.9-(8) 이 이미 이 사고를 기록했고, O57 에서 이 문서가 그 규약을 어기고 있음이 적발됐다).

---

## 0. 검증 요약

- ✅ **fan-out/가산성 DoD 통과**: 5 SV 전부 SEMANTIC_VIEW 집계 = FACT 직접집계 **완전 일치**(§1 불변식).
- 🔧 **결함 1건 수정·재배포 완료(2026-07-22)**: `SV_MEMBER_EVENT.AVG_RETENTION_MONTHS` 가 전건 **NULL** → 제거.
  🔴 **[2026-08-10 O57] 제거 근거의 절반이 무효화됐다** — 당시 근거는 ㉮ FME 행별 `DATEDIFF` 가 NULL(개발행에 `JOIN_DATE`·중단행에 `STOP_DATE` 가 **서로 다른 행**에 있다)
  ＋ ㉯ *"`DIM_MEMBER_CURRENT.LAST_STOP_DATE` 도 미적재(실측 0)"* 였다. **㉮는 지금도 참이고 ㉯는 거짓이 됐다**(실측 = 채움 **898,425**).
  실제로 `DIM_MEMBER_CURRENT` 경로로 **유지기간이 산출된다**: 페어링 898,425 · 유효 898,424(역순 1행) · 평균 **42.39개월**.
  ⚠️ 단 **「산출 가능」과 「노출해야 한다」는 다르다**(P97). 분모가 **중단 이력 보유 회원 898,425 / 1,763,065(50.96%)** 이므로
  진행 중 회원이 빠진 **생존 편향(right-censoring)** 값이다 ⇒ 노출 여부·정의(중단자 한정인지 전체인지)는 **결정 사안**으로 남긴다(§4-7).
- ⚠ **custom instruction 후보**(§4): 납부율 기간 스코프 · 미납회원 감소율 월 그룹 전제 · 행사/서비스 미매핑 고지 · **개발 건수 정의(O24)**.

---

## 1. 검증 결과 매트릭스 — **판정 = 불변식** (참고 실측 2026-08-10 O57)

> 🔴 **판정 열은 `SV값 == FACT값` 불변식이다.** 「참고 실측」 열의 절대값은 **그 날짜의 적재량**이며 재적재 시 변한다 —
> 값이 달라진 것은 결함이 아니고, **양측이 어긋난 것**만 결함이다.

| SV | metric | 불변식 (판정) | 참고 실측 (2026-08-10) | 판정 |
|---|---|---|---:|:--:|
| SV_MEMBER_MONTHLY | TOTAL_PAID_ALL | = `SUM(FMM.PAID_FEE)` | 895,178,309,108 | ✅ |
| SV_MEMBER_MONTHLY | TOTAL_PAID_FEE_BILLABLE | = `SUM(FMM.PAID_FEE_BILLABLE)` | 768,800,286,349 | ✅ |
| SV_MEMBER_MONTHLY | TOTAL_BILLED_AMT | = `SUM(FMM.BILLED_AMT)` | 891,959,790,888 | ✅ |
| SV_MEMBER_MONTHLY | **PAYMENT_RATE_FEE**(공64 정본) | 회비납입 ÷ 회비청구 ×100 | **86.192258%** | ✅ |
| SV_MEMBER_MONTHLY | TOTAL_UNPAID_AMT(DEC-3 정본) | = `SUM(FMM.UNPAID_BILLED_AMT)` | 122,621,758,323 | ✅ |
| SV_MEMBER_MONTHLY | UNPAID_RATIO(DEC-3 정본) | 미납청구 ÷ 회비청구 ×100 | **13.747454%** | ✅ |
| SV_MEMBER_MONTHLY | **TOTAL_DEV_CNT** | = `SUM(FMM.DEV_CNT)` | **2,291,878** | ✅ 🔴 **[O57 교체]** 종전 3,594,843 은 **개발원천 행수**이고 개발 건수가 아니다(O24) |
| SV_MEMBER_MONTHLY | TOTAL_STOP_CNT | = `SUM(FMM.STOP_CNT)` | 1,038,262 | ✅ |
| SV_MEMBER_MONTHLY | UNPAID_MEMBERS_BOM | = `COUNT(DISTINCT … UNPAID_FLAG_BOM)` | 526,654 | ✅ |
| SV_MEMBER_MONTHLY | UNPAID_MEMBERS_EOM | = `COUNT(DISTINCT … UNPAID_FLAG_EOM)` | 547,651 | ✅ |
| SV_MEMBER_MONTHLY | UNPAID_REDUCTION_RATE(공80) | (BOM−EOM)÷BOM | **−3.9869%** | ✅(전기간·주의 §4-2) |
| SV_MEMBER_EVENT | **TOTAL_DEV_CNT** | = `SUM(FME.DEV_CNT)` | **2,291,878** | ✅ 🔴 **[O57 교체]**(위와 동일 원인) |
| SV_MEMBER_EVENT | TOTAL_STOP_CNT | = `SUM(FME.STOP_CNT)` | 1,038,262 | ✅ |
| SV_MEMBER_EVENT | **DEV_MEMBER_COUNT** | = `COUNT(DISTINCT … DEV_CNT>0)` | **1,585,923** | ✅ 🔴 **[O57 교체]** 종전 1,585,949 는 **개발원천 distinct 회원수**다(차이 26명 = 개발사건이 코드 3·5 뿐인 회원) |
| SV_MEMBER_EVENT | STOP_MEMBER_COUNT | = `COUNT(DISTINCT … STOP_CNT>0)` | 903,064 | ✅ |
| SV_MEMBER_EVENT | ~~AVG_RETENTION_MONTHS~~ | — | — | 🔧제거(2026-07-22) · ⚠️ **근거 절반 무효화 · §0 참조** |
| SV_SERVICE | TOTAL_SEND_MEMBERS | = `SUM(FSE.SEND_MEMBERS)` | 38,470,780 | ✅ |
| SV_SERVICE | DISTINCT_SEND_MEMBERS | = `COUNT(DISTINCT FSE.MEMBER_DK)` | 1,031,971 | ✅ |
| SV_EVENT_PARTICIPATION | TOTAL_PARTICIPANTS | = `SUM(FEP.PARTICIPANT_CNT)` | 1,134,126 | ✅ |
| SV_EVENT_PARTICIPATION | DISTINCT_PARTICIPANTS | = `COUNT(DISTINCT FEP.MEMBER_DK)` | 407,223 | ✅ |
| SV_BUDGET | TOTAL_PLAN_BUDGET | = `SUM(FBD.PLAN_BUDGET_MONTH)` | **547,614,848,306** | ✅ 🔴 **[O57 교체]** 종전 503,070,876,000 은 **2026년 단독 적재 시점** 값 |
| SV_BUDGET | TOTAL_EXEC_BUDGET | = `SUM(FBD.EXEC_BUDGET_ERP)` | **297,045,080,903** | ✅ 🔴 **[O57 교체]** |
| SV_BUDGET | EXEC_RATE | 집행 ÷ 편성 ×100 | **54.243431%** | ✅ 🔴 **[O57 교체]** 종전 39.61% |

> 🔴 **[2026-08-10 O57] 종전 이 자리의 fan-out 각주가 M6 평가셋 오류의 발원지였다.**
> 종전 문안: *"성별별 개발건 합(F 2,002,899 + M 1,362,101 + U 229,573 + 공백 270 = 3,594,843)"*.
> ⇒ ① 합계가 **O24 이전 폐기값**이고 ② 차원명 `GENDER` 와 라벨 `F/M/U` 는 **현 SV·현 GOLD 어디에도 없다**.
> **교체된 fan-out 무증폭 확인(2026-08-10 실측)**: `member.GENDER_NAME` 별 `TOTAL_DEV_CNT` 합
> (여자 1,273,549 + 남자 878,124 + 기타 72,982 + 기업 53,431 + 단체 13,522 + (NULL) 270) = **2,291,878**
> = `SUM(FMM.DEV_CNT)` ⇒ `DIM_MEMBER_CURRENT` 조인 증폭 **0**. **V7 실행 = PASS**(2026-08-10).
> ⚠️ **판정은 「합 = 무차원 총계」 불변식으로 한다** — 구간별 절대값은 참고치다.

---

## 2. 검증쿼리 (DoD 회귀검증 — GOLD 재적재/SV 재배포 후 재실행)

> R6(GOLD 변경 → SV stale) 방어. 각 쿼리는 **SV 집계 = FACT 직접**을 단언한다. 배포 후·재적재 후 재실행하여 일치 확인.
> 🔴 **절대값을 기대값으로 적지 않는다**(§6.9-(8)). V6 가 종전에 `기대: 3,594,843` 을 박고 있었고 그것이 O24 교정 후 **거짓 기대값**이 됐다.

```sql
-- V1. SV_MEMBER_MONTHLY: 회비/개발/중단/미납 총량 = FMM 직접 (fan-out·가산성)
SELECT sv.*, f.*
FROM (SELECT * FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY
        METRICS TOTAL_PAID_ALL, TOTAL_BILLED_AMT, TOTAL_DEV_CNT, TOTAL_STOP_CNT,
                UNPAID_MEMBERS_BOM, UNPAID_MEMBERS_EOM)) sv,
     (SELECT SUM(PAID_FEE) f_paid, SUM(BILLED_AMT) f_billed, SUM(DEV_CNT) f_dev, SUM(STOP_CNT) f_stop,
             COUNT(DISTINCT CASE WHEN UNPAID_FLAG_BOM THEN MEMBER_DK END) f_bom,
             COUNT(DISTINCT CASE WHEN UNPAID_FLAG_EOM THEN MEMBER_DK END) f_eom
      FROM GN_DW.GOLD.FACT_MEMBER_MONTHLY) f;
-- 기대: TOTAL_PAID_ALL=f_paid ... UNPAID_MEMBERS_EOM=f_eom (전열 일치 · 절대값 무관)

-- V2. SV_MEMBER_EVENT: 개발/중단 건·고유회원수 = FME 직접
SELECT 'SV' src, TOTAL_DEV_CNT, TOTAL_STOP_CNT, DEV_MEMBER_COUNT, STOP_MEMBER_COUNT
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_EVENT
       METRICS TOTAL_DEV_CNT, TOTAL_STOP_CNT, DEV_MEMBER_COUNT, STOP_MEMBER_COUNT)
UNION ALL
SELECT 'FACT', SUM(DEV_CNT), SUM(STOP_CNT),
       COUNT(DISTINCT CASE WHEN DEV_CNT>0 THEN MEMBER_DK END),
       COUNT(DISTINCT CASE WHEN STOP_CNT>0 THEN MEMBER_DK END)
FROM GN_DW.GOLD.FACT_MEMBER_EVENT;   -- 기대: 두 행 동일

-- V3. SV_SERVICE: 발송수·고유회원수 = FSE 직접
SELECT (SELECT TOTAL_SEND_MEMBERS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_SERVICE METRICS TOTAL_SEND_MEMBERS)) sv_send,
       (SELECT SUM(SEND_MEMBERS) FROM GN_DW.GOLD.FACT_SERVICE_EVENT) f_send,
       (SELECT DISTINCT_SEND_MEMBERS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_SERVICE METRICS DISTINCT_SEND_MEMBERS)) sv_dist,
       (SELECT COUNT(DISTINCT MEMBER_DK) FROM GN_DW.GOLD.FACT_SERVICE_EVENT) f_dist;

-- V4. SV_EVENT_PARTICIPATION: 참여자수·고유회원수 = FEP 직접
SELECT (SELECT TOTAL_PARTICIPANTS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_EVENT_PARTICIPATION METRICS TOTAL_PARTICIPANTS)) sv_part,
       (SELECT SUM(PARTICIPANT_CNT) FROM GN_DW.GOLD.FACT_EVENT_PARTICIPATION) f_part,
       (SELECT DISTINCT_PARTICIPANTS FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_EVENT_PARTICIPATION METRICS DISTINCT_PARTICIPANTS)) sv_dist,
       (SELECT COUNT(DISTINCT MEMBER_DK) FROM GN_DW.GOLD.FACT_EVENT_PARTICIPATION) f_dist;

-- V5. SV_BUDGET: 편성/집행 = FBD 직접
SELECT (SELECT TOTAL_PLAN_BUDGET FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_BUDGET METRICS TOTAL_PLAN_BUDGET)) sv_plan,
       (SELECT SUM(PLAN_BUDGET_MONTH) FROM GN_DW.GOLD.FACT_BUDGET) f_plan,
       (SELECT TOTAL_EXEC_BUDGET FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_BUDGET METRICS TOTAL_EXEC_BUDGET)) sv_exec,
       (SELECT SUM(EXEC_BUDGET_ERP) FROM GN_DW.GOLD.FACT_BUDGET) f_exec;

-- V6. 시간 가산성(월 그룹 SUM = 전체) — 🔴 [O57] 절대값 기대값 제거, 불변식으로 교정
SELECT g.yr_sum, t.total, IFF(g.yr_sum = t.total, 'PASS', 'FAIL') AS verdict
FROM (SELECT SUM(TOTAL_DEV_CNT) yr_sum
      FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY DIMENSIONS month.CAL_YEAR METRICS TOTAL_DEV_CNT)) g,
     (SELECT TOTAL_DEV_CNT total
      FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY METRICS TOTAL_DEV_CNT)) t;
-- 기대: verdict='PASS' (연도 분해 후 재합 = 총량 · fan-out·중복 0). 절대값은 적지 않는다.

-- V7. 🆕 [O57] 차원 조인 fan-out 무증폭 — 종전 §1 각주(폐기값 산술)를 실행 가능한 불변식으로 대체
SELECT d.dim_sum, t.total, IFF(d.dim_sum = t.total, 'PASS', 'FAIL') AS verdict
FROM (SELECT SUM(TOTAL_DEV_CNT) dim_sum
      FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY DIMENSIONS member.GENDER_NAME METRICS TOTAL_DEV_CNT)) d,
     (SELECT TOTAL_DEV_CNT total
      FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY METRICS TOTAL_DEV_CNT)) t;

-- V8. 🆕 [O57] 개발 건수 정의 회귀 — O24 교정(코드 1·2·4 한정)이 유지되는지 판정
SELECT SUM(DEV_CNT)                                            AS dev_cnt,
       COUNT_IF(EVENT_TYPE='DEV')                              AS dev_src_rows,
       SUM(IFF(DVLP_DIV_CD IN ('1','2','4'), 1, 0))            AS code124_rows,
       IFF(SUM(DEV_CNT) = SUM(IFF(DVLP_DIV_CD IN ('1','2','4'),1,0)), 'PASS','FAIL') AS verdict
FROM GN_DW.GOLD.FACT_MEMBER_EVENT;
-- 기대: verdict='PASS' 이고 dev_cnt < dev_src_rows (원천 행수를 개발건수로 쓰면 안 된다 · O24)
```

---

## 3. Verified Query (VQR) 후보 — Cortex Analyst 스티어링

> 각 항목: **NL 질문(한글)** → 검증된 `SEMANTIC_VIEW` SQL. Phase-1 **활성 metric/dimension만** 사용.
> 🔴 **[O57] VQR 로 등록하기 전에 반드시 실행해 본다** — 종전 이 절에 **존재하지 않는 차원**(`member.GENDER`)이 있어
> 그대로 등록하면 컴파일 실패한다. 예시 수치는 **참고치**이며 등록 대상은 SQL 이다.

### SV_MEMBER_MONTHLY
```sql
-- Q. "연도별 납부율 추이" (공64)  ※기간 스코프 필수(§4-1)
SELECT CAL_YEAR, PAYMENT_RATE_FEE   -- 🔴[O56-C] PAYMENT_RATE 는 제거됐다
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY DIMENSIONS month.CAL_YEAR METRICS PAYMENT_RATE_FEE)
ORDER BY CAL_YEAR;
-- 참고(2026-08-10): 2023=86.05 · 2024=85.77 · 2025=85.65 (%)  🔴[O57] 종전 93.66/93.86/93.98 은 폐기식 값이었다

-- Q. "회원구분별 총수납액"
SELECT MEMBER_TYPE_NAME, TOTAL_PAID_ALL   -- 🔴[O56-C] TOTAL_PAID_FEE → TOTAL_PAID_ALL 개명
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY DIMENSIONS member.MEMBER_TYPE_NAME METRICS TOTAL_PAID_ALL)
ORDER BY TOTAL_PAID_ALL DESC NULLS LAST;
-- 참고(2026-08-10): 개인 756,640,436,694 · 기업 132,140,772,778 · 단체 6,356,891,665 · (NULL) 40,207,971

-- Q. "2024년 월별 미납회원 감소율" (공80)  ※월 그룹 전제(§4-2)
SELECT CAL_MONTH, UNPAID_REDUCTION_RATE
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY DIMENSIONS month.CAL_YEAR, month.CAL_MONTH
                   METRICS UNPAID_REDUCTION_RATE)
WHERE CAL_YEAR = 2024 ORDER BY CAL_MONTH;

-- Q. "성별 개발/중단 건수"
-- 🔴🔴 [O57] 종전 이 쿼리는 `member.GENDER` 를 썼고 **그 차원은 존재하지 않는다** → 등록 시 컴파일 실패.
--   실측 차원 = member.SEX(raw 코드) · member.SEX_NM · member.GENDER_NAME(라벨). 라벨축을 권장한다.
SELECT GENDER_NAME, TOTAL_DEV_CNT, TOTAL_STOP_CNT
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY DIMENSIONS member.GENDER_NAME
                   METRICS TOTAL_DEV_CNT, TOTAL_STOP_CNT)
ORDER BY TOTAL_DEV_CNT DESC NULLS LAST;
-- 참고(2026-08-10): 여자 1,273,549 · 남자 878,124 · 기타 72,982 · 기업 53,431 · 단체 13,522 · (NULL) 270

-- Q. "회원상태별 개발 건수"
-- 🔴 [O57] 차원명은 `MEMBER_STATUS` 가 아니다 → member.MBER_STAT_CD(raw) 또는 member.MEMBER_STATUS_NAME(라벨).
SELECT MBER_STAT_CD, TOTAL_DEV_CNT
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY DIMENSIONS member.MBER_STAT_CD METRICS TOTAL_DEV_CNT)
ORDER BY TOTAL_DEV_CNT DESC NULLS LAST;
-- 참고(2026-08-10): 12=1,229,621 · 1=994,231 · 7=23,702 (전 13구분 합 = 2,291,878)
```

### SV_MEMBER_EVENT
```sql
-- Q. "전이유형별 개발/중단 건수와 고유 회원수"
SELECT EVENT_TYPE, TOTAL_DEV_CNT, TOTAL_STOP_CNT, DEV_MEMBER_COUNT, STOP_MEMBER_COUNT
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_EVENT DIMENSIONS fme.EVENT_TYPE
                   METRICS TOTAL_DEV_CNT, TOTAL_STOP_CNT, DEV_MEMBER_COUNT, STOP_MEMBER_COUNT);
-- 참고(2026-08-10): DEV 2,291,878/1,585,923 · STOP 1,038,262/903,064
-- 🔴[O57] 종전 3,594,843/1,585,949 는 개발원천 행수·원천 distinct 회원수였다(O24 이전 정의)

-- Q. "연도·주차별 중단 건수 추이"  ※주차는 CAL_YEAR 동반 필수(O56-B)
SELECT CAL_YEAR, WEEK_OF_YEAR, TOTAL_STOP_CNT
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_EVENT DIMENSIONS date.CAL_YEAR, date.WEEK_OF_YEAR
                   METRICS TOTAL_STOP_CNT)
WHERE CAL_YEAR = 2025 ORDER BY WEEK_OF_YEAR;
```

### SV_SERVICE
```sql
-- Q. "채널별 발송수"
SELECT CHANNEL, TOTAL_SEND_MEMBERS
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_SERVICE DIMENSIONS service.CHANNEL METRICS TOTAL_SEND_MEMBERS)
ORDER BY TOTAL_SEND_MEMBERS DESC;
-- 참고(2026-08-10): MSG_AT 20,557,626 · SND 8,300,272 · EMAIL 7,811,121 · PSTMTR 1,790,448 · (미매핑) 11,313

-- Q. "서비스유형별 발송 고유회원수"
SELECT SUBTYPE, DISTINCT_SEND_MEMBERS
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_SERVICE DIMENSIONS service.SUBTYPE METRICS DISTINCT_SEND_MEMBERS)
ORDER BY DISTINCT_SEND_MEMBERS DESC NULLS LAST;
```

### SV_EVENT_PARTICIPATION
```sql
-- Q. "행사종류별 참여자수·고유참여회원수"  ※미매핑 23% 고지(§4-3)
SELECT EVENT_KIND, TOTAL_PARTICIPANTS, DISTINCT_PARTICIPANTS
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_EVENT_PARTICIPATION DIMENSIONS event.EVENT_KIND
                   METRICS TOTAL_PARTICIPANTS, DISTINCT_PARTICIPANTS)
ORDER BY TOTAL_PARTICIPANTS DESC NULLS LAST;
-- 참고(2026-08-10): EVENT 718,438 · (NULL) 263,611 · CRMN 152,077
-- ⚠️[O57] 미매핑 구분의 실제 반환값은 **NULL** 이다(문서가 `(Unknown)` 문자열로 적고 있었다)
```

### SV_BUDGET
```sql
-- Q. "예산구분별 편성·집행·집행율"
SELECT BUDGET_CATEGORY, TOTAL_PLAN_BUDGET, TOTAL_EXEC_BUDGET, EXEC_RATE
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_BUDGET DIMENSIONS item.BUDGET_CATEGORY
                   METRICS TOTAL_PLAN_BUDGET, TOTAL_EXEC_BUDGET, EXEC_RATE)
ORDER BY TOTAL_PLAN_BUDGET DESC NULLS LAST;
-- 참고(2026-08-10): 지출 298.60B/151.18B/50.63% · 수입 249.01B/145.86B/58.58%
-- 🔴[O57] 종전 참고치(지출 254.1B/31.7% · 수입 249.0B/47.7%)는 **2026년 단독 적재 시점** 값이다

-- Q. "월별 집행율 추이"
SELECT MONTH_KEY, EXEC_RATE
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_BUDGET DIMENSIONS month.MONTH_KEY METRICS EXEC_RATE)
ORDER BY MONTH_KEY;
-- ⚠️[O57] 적재 범위는 2024-01~2026-12(MONTH_KEY 202401~202612)다. 2026 은 진행연도로 집행액이 계속 변한다.
```

---

## 4. custom instruction 후보 (Agent/SV 지침 — 5단계 반영)

1. **납부율(공64)은 기간 스코프 필수.** 전기간 무필터 집계는 재청구·이월로 왜곡된다. 질문에 연/월 그룹 또는 필터가 없으면 최근 연·월 또는 명시 기간으로 한정하고, 무필터 총율은 참고치로만 제시.
   🔴 **[O57 정정] 종전 문안의 근거 수치가 폐기식이었다** — *"전기간 100.36% vs 연도별 ~94%"* 의 100.36% 는 **제거된 `PAYMENT_RATE`**(분자에 기부금 혼입)의 값이고, ~94% 도 폐기식 연도값이다. **정본 기준**: 전기간 `PAYMENT_RATE_FEE` = **86.19%** · 연도별 **~85.7%**. 왜곡의 방향·규모가 달라졌으므로 지침 근거를 이 값으로 교체한다.
2. **미납회원 감소율(공80)·미납회원수는 월 그룹/필터 전제.** `COUNT(DISTINCT MEMBER_DK)` 기반이라 다월 무그룹 집계는 회원 중복 제거로 월별 합과 다르다(전기간 단일값은 의미 약함). 반드시 `month` 차원과 함께 사용.
3. **행사·서비스 미매핑 고지.** 행사 `EVENT_KIND` 의 미매핑(EVENT_SK=0)과 서비스 채널 `(미매핑)` 은 부분 커버 → 확정치로 단정 금지, 커버리지 안내. ⚠️ 행사 미매핑의 반환값은 **NULL** 이다(라벨 문자열이 아니다).
4. **회원 속성 스코프.** 성별·회원상태·회원구분은 **현재 스냅샷 기준**(과거월 조회 시에도 현재값).
   🔴 **[O57 정정 · P61] 종전 *"지역·연령대·후원사업은 dim 공란으로 비활성"* 은 부분적으로 거짓이 됐다** — 실측(2026-08-10 `DIM_MEMBER_CURRENT` 1,763,065행):
   · **지역 `REGION` 채움 1,566,416 · 연령대 `AGE_BAND` 채움 1,575,863 · `FIRST_SPONSORSHIP` 1,585,913 = 활성**(O35/O45 배선분)
   · ⚠️ 분모 주의(P128): 이 값들은 **정기후원 회원(FDRM) 모집단** 기준이고 일시회원(ONCE)은 **구조적 부재**다 — 전체 1,763,065 를 분모로 쓰면 결손으로 오진한다
   · **후원사업 축(FMM 경유)은 여전히 비활성** — `FMM.SPONSORSHIP_SK`·`CAMPAIGN_SK`·`PAYMENT_SK` 는 **전건 0**(실측)
   · 🆕 **미납사유 축은 활성화됐다** — `FMM.REASON_SK` 비-0 **3,164,724**(종전 문서·`50_dbt` 표는 「전건 0」으로 기재) ⇒ `REASON.UNPAID_REASON` 분해 가능
   · 사건시점 축(`_AT_EVENT`)은 `SV_MEMBER_EVENT` 에 있고 현재 스냅샷과 **다른 값**이다 — 두 축을 혼용하지 않는다
5. **회비 지표는 `HAS_BILLING=TRUE` 전제 권장**(청구 원천 존재 행).
6. 🆕 **[O57] 개발 건수 정의 고지(O24).** 「개발」은 **신규(1)·증액(2)·재후원(4)** 이다 — 감액(3)·후원중단(5)은 제외한다.
   개발원천 행수(전건)를 개발 건수로 답하면 **감액·후원중단을 개발실적으로 계상**한 값이 된다.
   또 「개발 건수」와 「개발 회원수」는 다르고, **「개발한 회원수」의 정본은 `DEV_MEMBER_COUNT`**(코드 1·2·4 보유 회원)다 —
   개발원천 distinct 회원수와 26명 차이가 나며 그 26명은 개발 사건이 코드 3·5 뿐인 회원이다.
7. **비활성 지표 요청 시**: 캠페인/납입방식/조직/후원사업별 분해·성공/실패/오픈·D5 코호트·활동/누계 카운트·목표대비는 **데이터 적재 후(Phase-2)** 안내(추정 금지, R8).
   ⚠️ 🆕 **[O57] 「유지기간」은 이 목록에서 재검토 대상이다** — 제거 근거 중 `LAST_STOP_DATE` 미적재는 **해소됐고**(채움 898,425) 실제로 산출된다(평균 42.39개월).
   그러나 분모가 **중단 이력 보유 회원 50.96%** 이므로 생존 편향이 있다 ⇒ **노출 여부·정의는 결정 사안**이며, 결정 전까지는 현행(안내) 유지가 맞다(P97).

---

## 5. 재배포 이력 & 다음 단계

- ✅ **`SV_MEMBER_EVENT` 재배포 완료(2026-07-22)**: retention 제거 정정본으로 `CREATE OR REPLACE` 실행 → §2 V2 재검증 통과. **⚠ `CREATE OR REPLACE` 가 grant 를 삭제하므로 REFERENCES/SELECT(ANALYST·VIEWER·SERVICE) 재부여 완료**(SHOW GRANTS 7행 확인).
  🔴 **[현행 규약] 정의만 바꿀 때는 `CREATE OR ALTER SEMANTIC VIEW` 를 쓴다** — GRANT 가 보존됨을 실측했다(P125 · O54 `created_on` 불변). 위 `CREATE OR REPLACE` 는 **이력**이다.
- 🔴 **[O57] 이 문서는 절대값 판정 금지 규약(§6.9-(8))의 적용 대상이다.** 재적재 후에는 §2 V1~V8 을 돌려 **불변식으로** 판정하고, §1·§3 의 참고치는 그때 갱신한다.
- **다음**: `08_AGENT_spec.md` → `10_SI연결_검증.md`(CoWork ADD AGENT · NL 층 판정).

---
_Co-authored with CoCo_
