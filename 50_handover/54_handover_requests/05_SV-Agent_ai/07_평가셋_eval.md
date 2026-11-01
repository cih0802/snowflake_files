<!-- LLM-METADATA
doc_id: SV_EVAL_SET
doc_role: 4단계 — Cortex Analyst 평가셋(ground-truth Q&A) · SV 정확도 회귀 기준 (Agent eval 입력)
project: GN_DW (굿네이버스)
created: 2026-07-22
depends_on: 05_1~05_9_SV_DDL_*.sql(배포), 06_검증쿼리_VQR.md(VQR·custom instruction 후보)
scope: Phase-1 배포 5 SV
ground_truth_asof: **2026-08-10 (O57 전량 재실행)** — 종전 2026-07-22 스냅샷을 교체했다. 재실행 25문항 = 일치 14 · 불일치 11.
  불일치는 두 원인으로 전량 규명됐다: ㉠ O24 `DEV_CNT` 정본 교정 미반영 **7건**(폐기값 고정 = P156 재발) ㉡ 예산 3개년 적재·집행 갱신 **4건**(3계층 정확 일치 = 결함 아님).
  경위·근거 정본 = `20_issue/00_INDEX_이슈원장.md` §O57.
END-METADATA -->

# 4단계 — 평가셋 (eval set)

> 배포된 5 SV에 대해 **NL 질문 ↔ 기대 SQL ↔ 기대값(ground truth)** 세트를 정의한다. 5단계 Agent 구성·회귀에서 이 셋으로 Cortex Analyst 정확도를 측정한다.
> 🔴 **[2026-08-10 O57] 기대값 전량 재실행·교체 완료.** 종전 값은 **2026-07-22 스냅샷**이었고 그 사이 ① O24 가 `DEV_CNT` 정본을 교정했고 ② 예산이 3개년으로 증량 적재됐다. 교체 전 값은 각 행의 `종전` 표기로 이력 보존한다.

## 0. 평가 방법 & 판정 기준

- **채점 축**: ① 올바른 SV 선택(라우팅) ② 올바른 metric/dimension 선택 ③ 값 정확도(수치 허용오차 0 — 정수/원, 비율은 소수 2자리) ④ 가드레일 준수(비활성 지표는 산출 대신 Phase-2 안내).
- **PASS**: 기대 metric·dimension이 일치하고 값이 ground truth와 동일(비율 ±0.01%p). **FAIL**: SV/metric 오선택·값 불일치·비활성 지표를 임의 산출·fan-out 증폭.
- **실행 주체**: 5단계에서 Agent(`DATA_AGENT_RUN`)로 질문 → 생성 SQL·답변을 아래 gold SQL/값과 대조. 지금은 gold SQL을 직접 실행해 기대값을 고정.
- **표기**: 값은 **2026-08-10 O57 실측** 기준. ⓖ=가드레일(비활성/기간스코프) 평가. `종전`=교체된 폐기 기대값(이력).
- 🔴 **기대값을 교체할 때는 실행해서 채운다**(P33·P156). 문서만 고치면 「폐기값을 정답으로 고정」이 재발한다 — 실제로 O56-C·O57 에서 두 번 적발됐다.

---

## 1. SV_MEMBER_MONTHLY (회원 월별 실적)

| # | NL 질문 | 기대 metric / dim | 기대값 (2026-08-10 O57 실측) | 판정 |
|---|---|---|---|---|
| M1 | 전체 **총수납액**(회비+기부금)은? | TOTAL_PAID_ALL | 895,178,309,108 | ✅ 일치 |
| M2 | 전체 청구금액 총액은? | TOTAL_BILLED_AMT | 891,959,790,888 | ✅ 일치 |
| M3 | 2024년 납부율은? | **PAYMENT_RATE_FEE** / month.CAL_YEAR=2024 | **85.77%**(85.767153) | ✅ 일치 |
| M4 | 연도별 납부율 추이(2023~2025) | **PAYMENT_RATE_FEE** / month.CAL_YEAR | **2023 86.05 · 2024 85.77 · 2025 85.65 (%)** | ✅ 일치 |
| M5 | 회원구분별 **총수납액** | TOTAL_PAID_ALL / member.MEMBER_TYPE_NAME | 개인=756,640,436,694 · 기업=132,140,772,778 · 단체=6,356,891,665 · (NULL)=40,207,971 | ✅ 일치(4구분 전건) |
| M6 | 성별 개발 건수 | TOTAL_DEV_CNT / **member.GENDER_NAME**(라벨) | 여자=1,273,549 · 남자=878,124 · 기타=72,982 · 기업=53,431 · 단체=13,522 · (NULL)=270 **합 2,291,878** | 🔴 **교체**(원인 ㉠+차원명) |
| M7 | 회원상태별 개발 건수(상위) | TOTAL_DEV_CNT / **member.MBER_STAT_CD**(raw) | 12=1,229,621 · 1=994,231 · 7=23,702 (전 13구분 합 2,291,878) | 🔴 **교체**(원인 ㉠+차원명) |
| M8 | 2024년 개발/중단 건수 | TOTAL_DEV_CNT·TOTAL_STOP_CNT / CAL_YEAR=2024 | 개발 **176,400** · 중단 123,180 | 🔴 **개발 교체**(원인 ㉠) · 중단 ✅ |
| M9 | 전체 개발/중단 총건 | TOTAL_DEV_CNT·TOTAL_STOP_CNT | 개발 **2,291,878** / 중단 1,038,262 | 🔴 **개발 교체**(원인 ㉠) · 중단 ✅ |
| M10ⓖ | 캠페인별 납부율 알려줘 | (비활성) | "캠페인 FK 미적재 → Phase-2" 안내(산출 금지) | ⬜ NL 필요 |
| M11ⓖ | 활동회원수(월말 활동회원)는? | (비활성) | "ACTIVE_CNT 미적재 → Phase-2" 안내 | ⬜ NL 필요 |

**교체 이력**
- M1 🔴[2026-08-10 O56-C] metric 개명(`TOTAL_PAID_FEE`→`TOTAL_PAID_ALL`) · **질문 문구도 교정**: 이 값은 「납입회비」가 아니라 기부금 포함 총수납액이다(회비만은 `TOTAL_PAID_FEE_BILLABLE` **768,800,286,349** — O57 재실측 일치).
- M3 🔴[2026-08-10 O56-C EXPO-2] `PAYMENT_RATE` 제거로 metric·기대값 동시 교체. 종전 93.86% 는 **폐기식(모집단 불일치) 값**이었다.
- M4 🔴[동일] 종전 93.66·93.86·93.98 은 폐기식 값이다.
- M6 🔴🔴[2026-08-10 O57] **두 가지가 동시에 틀려 있었다.** ① 차원 `member.GENDER` 는 **SV 에 존재하지 않는다**(실측 차원 = `SEX`(raw 코드 9종)·`SEX_NM`·`GENDER_NAME`(CM017 라벨 6종)) ② 종전 값 `F=2,002,899 · M=1,362,101 · U=229,573 · (공백)=270`(합 **3,594,843**)은 **O24 이전 `DEV_CNT` 전건=1 하드코딩 시절 값**이다. 코드축으로 답하려면 `member.SEX` = 2:1,270,993 · 1:876,391 · 8:62,842 · 7:53,431 · 6:13,522 · 5:10,140 · 4:2,556 · 3:1,733 · (NULL):270.
- M7 🔴🔴[2026-08-10 O57] 차원 `member.MEMBER_STATUS` 도 **존재하지 않는다**(실측 = `MBER_STAT_CD`·`MEMBER_STATUS_NAME`). 종전 값 `12=2,317,052 · 1=1,194,376 · 7=29,794` 도 O24 이전 폐기값이다.
- M8 🔴[2026-08-10 O57] 종전 개발 319,881 → **176,400**. 중단 123,180 은 불변(원천이 다르다).
- M9 🔴[2026-08-10 O57] 종전 개발 3,594,843 → **2,291,878**. 3,594,843 은 **개발원천 행수**(= `BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT` 전건)이고 **개발 건수가 아니다** — O24 가 정본 공#121(개발 = 신규1·증액2·재후원4)에 맞춰 감액(3)·후원중단(5)을 제외했다. 제외분 **1,302,965행(36.24%)** 이 정확히 차이와 일치한다.

```sql
-- gold (M3/M4): 연도별 납부율
SELECT CAL_YEAR, PAYMENT_RATE_FEE
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY DIMENSIONS month.CAL_YEAR METRICS PAYMENT_RATE_FEE)
WHERE CAL_YEAR BETWEEN 2023 AND 2025 ORDER BY CAL_YEAR;
-- gold (M5): 회원구분별 총수납액
SELECT MEMBER_TYPE_NAME, TOTAL_PAID_ALL
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY DIMENSIONS member.MEMBER_TYPE_NAME METRICS TOTAL_PAID_ALL);
-- gold (M6): 성별 개발 건수 — ⚠️ 차원명은 GENDER 가 아니다
SELECT GENDER_NAME, TOTAL_DEV_CNT
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY DIMENSIONS member.GENDER_NAME METRICS TOTAL_DEV_CNT)
ORDER BY TOTAL_DEV_CNT DESC NULLS LAST;
-- gold (M7): 회원상태별 개발 건수 — ⚠️ 차원명은 MEMBER_STATUS 가 아니다
SELECT MBER_STAT_CD, TOTAL_DEV_CNT
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY DIMENSIONS member.MBER_STAT_CD METRICS TOTAL_DEV_CNT)
ORDER BY TOTAL_DEV_CNT DESC NULLS LAST;
```

> ⓖ 주의(06 §4-1): 납부율은 **기간(연/월) 스코프**로 답해야 PASS — 무필터 전기간 집계는 재청구·이월로 왜곡된다.
> 🔴 **[2026-08-10 O57 자기정정]** 이 자리에 있던 「무필터 전기간 100.36%」는 **제거된 `PAYMENT_RATE`**(분자 기부금 혼입)의 값이다.
> 정본 `PAYMENT_RATE_FEE` 기준 무필터 전기간은 **86.19%** 다 — 폐기값을 경계 근거로 인용하면 Agent 가 **존재하지 않는 값**을 경계한다(P155).

---

## 2. SV_MEMBER_EVENT (회원 상태전이)

| # | NL 질문 | 기대 metric / dim | 기대값 (2026-08-10 O57 실측) | 판정 |
|---|---|---|---|---|
| E1 | 전체 개발/중단 건수 | TOTAL_DEV_CNT·TOTAL_STOP_CNT | 개발 **2,291,878** / 중단 1,038,262 | 🔴 **개발 교체**(원인 ㉠) · 중단 ✅ |
| E2 | 개발한 고유 회원수는? | DEV_MEMBER_COUNT | **1,585,923** | 🔴 **교체**(원인 ㉠ · −26) |
| E3 | 중단한 고유 회원수는? | STOP_MEMBER_COUNT | 903,064 | ✅ 일치 |
| E4 | 전이유형별 건수·회원수 | */ fme.EVENT_TYPE | DEV: 개발 **2,291,878**·회원 **1,585,923** / STOP: 중단 1,038,262·회원 903,064 | 🔴 **개발 2건 교체** · 중단 2건 ✅ |
| E5ⓖ | 평균 유지기간(가입~중단)은? | (비활성) | "LAST_STOP_DATE 미적재·페어링 불가 → Agent/Phase-2" 안내(산출 금지) | ⬜ NL 필요 |
| E6ⓖ | 중단 사유별 중단 건수 | (비활성) | "REASON_SK 미적재 → Phase-2" 안내 | ⬜ NL 필요 |

**교체 이력**
- E1/E4 🔴[2026-08-10 O57] M9 와 동일 원인(O24). 종전 3,594,843 은 개발원천 행수다.
- E2 🔴[2026-08-10 O57] 종전 **1,585,949 → 1,585,923**(−26). 1,585,949 는 **개발원천 distinct 회원수**이고 metric 은
  `COUNT(DISTINCT CASE WHEN DEV_CNT>0 THEN MEMBER_DK END)` = **개발(1·2·4) 회원**이다.
  차이 **26명은 개발 사건이 감액(3)·후원중단(5)뿐인 회원**으로 실측 확정했다(1,585,949 = 1,585,923 + 26 · 오차 0).
  ⇒ 두 값은 모두 참이고 **정의가 다르다**. 「개발한 회원」의 정본은 1,585,923 이다.

```sql
-- gold (E4)
SELECT EVENT_TYPE, TOTAL_DEV_CNT, TOTAL_STOP_CNT, DEV_MEMBER_COUNT, STOP_MEMBER_COUNT
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_EVENT DIMENSIONS fme.EVENT_TYPE
     METRICS TOTAL_DEV_CNT, TOTAL_STOP_CNT, DEV_MEMBER_COUNT, STOP_MEMBER_COUNT);
-- 26명 갭 재현(원인 확정용)
WITH d AS (SELECT MEMBER_DK, MAX(IFF(DVLP_DIV_CD IN ('1','2','4'),1,0)) AS HAS_DEV
           FROM GN_DW.GOLD.FACT_MEMBER_EVENT WHERE EVENT_TYPE='DEV' GROUP BY 1)
SELECT COUNT(*) AS DEV_SRC_MEMBERS, SUM(HAS_DEV) AS WITH_CODE124, COUNT(*)-SUM(HAS_DEV) AS ONLY_CODE35 FROM d;
-- → 1,585,949 / 1,585,923 / 26
```

---

## 3. SV_SERVICE (서비스 발송)

| # | NL 질문 | 기대 metric / dim | 기대값 (2026-08-10 O57 실측) | 판정 |
|---|---|---|---|---|
| S1 | 전체 발송수는? | TOTAL_SEND_MEMBERS | 38,470,780 | ✅ 일치 |
| S2 | 발송 대상 고유 회원수는? | DISTINCT_SEND_MEMBERS | 1,031,971 | ✅ 일치 |
| S3 | 채널별 발송수 | TOTAL_SEND_MEMBERS / service.CHANNEL | MSG_AT 20,557,626 · SND 8,300,272 · EMAIL 7,811,121 · PSTMTR 1,790,448 · (미매핑) 11,313 | ✅ 일치(5구분 전건) |
| S4 | 2024년 발송수는? | TOTAL_SEND_MEMBERS / date.CAL_YEAR=2024 | 16,563,437 | ✅ 일치 |
| S5ⓖ | 발송 성공률(수신율)은? | (비활성) | "SUCCESS/FAIL 미적재 → Phase-2" 안내(산출 금지) | ⬜ NL 필요 |

```sql
-- gold (S3)
SELECT CHANNEL, TOTAL_SEND_MEMBERS
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_SERVICE DIMENSIONS service.CHANNEL METRICS TOTAL_SEND_MEMBERS)
ORDER BY TOTAL_SEND_MEMBERS DESC;
```

---

## 4-SV. SV_EVENT_PARTICIPATION (행사 참여)

| # | NL 질문 | 기대 metric / dim | 기대값 (2026-08-10 O57 실측) | 판정 |
|---|---|---|---|---|
| P1 | 전체 행사 참여자수는? | TOTAL_PARTICIPANTS | 1,134,126 | ✅ 일치 |
| P2 | 고유 참여 회원수는? | DISTINCT_PARTICIPANTS | 407,223 | ✅ 일치 |
| P3 | 행사종류별 참여자수 | TOTAL_PARTICIPANTS / event.EVENT_KIND | EVENT 718,438 · (NULL) 263,611 · CRMN 152,077 | ✅ 일치 |
| P4 | 2024년 참여자수는? | TOTAL_PARTICIPANTS / date.CAL_YEAR=2024 | 246,628 | ✅ 일치 |
| P5ⓖ | 캠페인별 참여자수 | (비활성) | "CAMPAIGN_SK 미적재 → Phase-2" 안내 | ⬜ NL 필요 |

> ⓖ 주의(06 §4-3): 행사 미매핑(EVENT_SK=0) 참여 263,611(약 23%). 행사명/종류별은 부분 커버 → 커버리지 고지해야 PASS.
> ⚠️[2026-08-10 O57] P3 의 미매핑 구분은 문서에 `(Unknown)` 으로 적혀 있었으나 실측 반환값은 **NULL** 이다(라벨 문자열이 아니다).

---

## 5. SV_BUDGET (예산)

| # | NL 질문 | 기대 metric / dim | 기대값 (2026-08-10 O57 실측) | 판정 |
|---|---|---|---|---|
| B1 | 전체 편성예산은? | TOTAL_PLAN_BUDGET | **547,614,848,306** | 🔴 **교체**(원인 ㉡) |
| B2 | 전체 집행예산(ERP)은? | TOTAL_EXEC_BUDGET | **297,045,080,903** | 🔴 **교체**(원인 ㉡) |
| B3 | 전체 집행율은? | EXEC_RATE | **54.24%**(54.243431) | 🔴 **교체**(원인 ㉡) |
| B4 | 예산구분별 편성·집행·집행율 | */ item.BUDGET_CATEGORY | 지출 **298,601,794,306 / 151,182,445,172 / 50.63%** · 수입 **249,013,054,000 / 145,862,635,731 / 58.58%** | 🔴 **교체**(원인 ㉡) |
| B5ⓖ | 캠페인별 ROI(개발단가) 알려줘 | (비활성) | "CAMPAIGN_SK·비용·FMM 연계 미적재 → Phase-2(신9~11)" 안내 | ⬜ NL 필요 |

**교체 이력 — 🟢 결함이 아니다(적재 증량)**
- 🔴[2026-08-10 O57] 종전 값(편성 503,070,876,000 · 집행 199,287,107,812 · 39.61% · 지출 254,057,822,000/80,492,821,242/31.68% · 수입 249,013,054,000/118,794,286,570/47.71%)은 **2026년 단독 적재 시점 스냅샷**이었다. 실측 분해:
  · 연도별 편성 = 2024 **18,313,586,000** + 2025 **26,230,386,306** + 2026 **503,070,876,000** = 547,614,848,306
  · **2026 단독값이 종전 B1 과 정확히 일치**한다 ⇒ 증분은 2024·2025 **추가 적재분**(+44,543,972,306)이다.
  · B4 의 종전 편성값도 **2026 단독**이 정확 일치(지출 254,057,822,000 · 수입 249,013,054,000).
  · 집행(ERP) 차이 = **+97,757,973,091**. 이 중 **2024·2025 추가분 46,029,387,156 은 실측 확정**이고,
    잔여 **51,728,585,935**(2026 집행이 종전 기대값 199,287,107,812 → 현재 251,015,693,747)는 🟠 **원인 미확증**이다 —
    2026 진행연도의 집행 누적으로 **추정**되나 **과거 스냅샷이 없어 검증 불가**하다. 단정하지 않는다(R2-1).
    🟢 다만 현 시점 3계층 정합은 아래처럼 오차 0 이므로 **파이프라인 결함이 아님은 확정**이다.
- 🟢 **3계층 정확 일치 검증(R2-3)** — `BRONZE_ERP.BDGT_ACMSLT_LEDGER`(`INCOME_EXPS_DIV_NM<>'TOTAL'` 제외 후 **월별 컬럼을 컬럼별로 SUM**) = `SILVER.ERP_BUDGET` = `GOLD.FACT_BUDGET` 이 **3개년 전건 오차 0**. 행수도 6,333×12 = **75,996 전 계층 동일**. ⇒ 파이프라인 결함 없음.
- 🔴 **내가 처음에 낸 BRONZE 대조값이 틀렸다** — 행 단위로 `EXEC_AMT_1+…+_12` 를 더하니 **월 하나라도 NULL 인 행이 통째로 탈락**해 2024 가 20,280,050,664(실제 21,032,819,608)로 나왔다.
  ⇒ 🆕 **P160: wide 테이블을 행 단위 산술합으로 대조하지 않는다.** `a+b+…` 는 NULL 전파로 행을 삭제한다 — `SUM(a)+SUM(b)+…` 또는 언피벗 후 `SUM` 으로 대조한다. 안 그러면 정상 파이프라인을 결함으로 오진한다.
- ⚠️ 2026 은 진행연도라 집행액이 계속 늘어난다 ⇒ **B2·B3·B4 집행 계열은 재적재마다 재실행 대상**이다(§7).

```sql
-- gold (B4)
SELECT BUDGET_CATEGORY, TOTAL_PLAN_BUDGET, TOTAL_EXEC_BUDGET, EXEC_RATE
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_BUDGET DIMENSIONS item.BUDGET_CATEGORY
     METRICS TOTAL_PLAN_BUDGET, TOTAL_EXEC_BUDGET, EXEC_RATE) ORDER BY TOTAL_PLAN_BUDGET DESC;
-- 3계층 대조 게이트(O57) — 컬럼별 SUM 으로 대조할 것(P160)
SELECT YEAR,
       SUM(EXEC_AMT_1)+SUM(EXEC_AMT_2)+SUM(EXEC_AMT_3)+SUM(EXEC_AMT_4)+SUM(EXEC_AMT_5)+SUM(EXEC_AMT_6)
      +SUM(EXEC_AMT_7)+SUM(EXEC_AMT_8)+SUM(EXEC_AMT_9)+SUM(EXEC_AMT_10)+SUM(EXEC_AMT_11)+SUM(EXEC_AMT_12) AS EXEC_NULLSAFE
FROM GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER WHERE INCOME_EXPS_DIV_NM <> 'TOTAL' GROUP BY 1 ORDER BY 1;
```

---

## 6. 가드레일 평가(ⓖ) 요약 — custom instruction 검증

| 케이스 | 기대 Agent 행동 |
|---|---|
| M10·E6·S5·P5·B5 (비활성 지표) | 임의 산출 금지 → "데이터 적재 후(Phase-2)" 안내(R8) |
| M11 (활동회원수) | ACTIVE_CNT 미적재 안내 |
| E5 (유지기간) | 페어링 불가 → Agent/Phase-2 안내 |
| 납부율 무필터 | 기간 스코프로 재해석 — 🔴 **[O57]** 경계 근거는 **폐기값 100.36% 가 아니라** 정본 `PAYMENT_RATE_FEE` 전기간 **86.19%** 다 |
| 행사/서비스 Unknown | 커버리지(23% 미매핑) 고지 |

> ⛔ ⓖ 8문항은 **NL 응답 행동 평가**이므로 SQL 로 채울 수 없다. 트라이얼 계정에서 `DATA_AGENT_RUN` 이 차단돼 있어
> **사용자가 CoWork UI 에서 질의**해야 판정된다(`10_SI연결_검증.md` §3.3).

---

## 7. 운영 주의 & 다음

- **기대값 재생성**: 값은 **2026-08-10 O57 실측** 스냅샷. Bronze→GOLD 재적재·A/B계열 추가 적재 시 **본 평가셋 기대값 재실행·갱신**(§1~5 gold SQL 재실행).
  🔴 **O57 이 이 경고가 실제로 발생함을 확인했다** — 예산 4문항이 정확히 이 사유(2024·2025 추가 적재)로 어긋났다. 특히 **2026 진행연도 집행액**은 계속 변한다.
- 🔴 **정본 산식이 바뀌면 평가셋을 같은 커밋에서 재실행한다**(P149 계열) — O24 가 `DEV_CNT` 를 교정했는데 평가셋은 **7일간 폐기값을 정답으로 유지**했다. 산식 교정 PR 에 평가셋 재실행을 포함시킨다.
- 🔴 **평가셋의 차원명도 검증 대상이다** — M6 `GENDER`·M7 `MEMBER_STATUS` 는 SV 에 **존재하지 않는 차원**이었다.
  실명 확인은 `GN_DW.INFORMATION_SCHEMA.SEMANTIC_DIMENSIONS`·`SEMANTIC_METRICS`(P158).
- **활성 확장 시 평가 추가**: Phase-2에서 캠페인/조직/성공률/유지율 등 활성화되면 해당 ⓖ 케이스를 정상 산출 케이스로 승격하고 기대값 추가.
- **다음**: `08_AGENT_spec.md` — 최종 3 Agent(회원·마케팅·overall) 중 **Phase-1 배포 2개**(회원·overall, 마케팅은 bronze 미완으로 Phase-2) 스펙(도구=SV 5개·Cortex Search·orchestration 라우팅·custom instruction §6) → `10_SI연결_검증.md`(CoWork ADD AGENT).

---
_Co-authored with CoCo_
