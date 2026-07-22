<!-- LLM-METADATA
doc_id: SV_EVAL_SET
doc_role: 4단계 — Cortex Analyst 평가셋(ground-truth Q&A) · SV 정확도 회귀 기준 (Agent eval 입력)
project: GN_DW (굿네이버스)
created: 2026-07-22
depends_on: 05_SV_DDL.sql(배포), 06_검증쿼리_VQR.md(VQR·custom instruction 후보)
scope: Phase-1 배포 5 SV
ground_truth_asof: 2026-07-22 (GOLD 재적재 시 기대값 재생성 필요 — §4)
END-METADATA -->

# 4단계 — 평가셋 (eval set)

> 배포된 5 SV에 대해 **NL 질문 ↔ 기대 SQL ↔ 기대값(ground truth)** 세트를 정의한다. 5단계 Agent 구성·회귀에서 이 셋으로 Cortex Analyst 정확도를 측정한다. 기대값은 **2026-07-22 라이브 실측**(GOLD 재적재 시 재생성, §4).

## 0. 평가 방법 & 판정 기준

- **채점 축**: ① 올바른 SV 선택(라우팅) ② 올바른 metric/dimension 선택 ③ 값 정확도(수치 허용오차 0 — 정수/원, 비율은 소수 2자리) ④ 가드레일 준수(비활성 지표는 산출 대신 Phase-2 안내).
- **PASS**: 기대 metric·dimension이 일치하고 값이 ground truth와 동일(비율 ±0.01%p). **FAIL**: SV/metric 오선택·값 불일치·비활성 지표를 임의 산출·fan-out 증폭.
- **실행 주체**: 5단계에서 Agent(`DATA_AGENT_RUN`)로 질문 → 생성 SQL·답변을 아래 gold SQL/값과 대조. 지금은 gold SQL을 직접 실행해 기대값을 고정.
- **표기**: 값은 2026-07-22 기준. ⓖ=가드레일(비활성/기간스코프) 평가.

---

## 1. SV_MEMBER_MONTHLY (회원 월별 실적)

| # | NL 질문 | 기대 metric / dim | 기대값 (2026-07-22) |
|---|---|---|---|
| M1 | 전체 납입회비 총액은? | TOTAL_PAID_FEE | 895,178,309,108 |
| M2 | 전체 청구금액 총액은? | TOTAL_BILLED_AMT | 891,959,790,888 |
| M3 | 2024년 납부율은? | PAYMENT_RATE / month.CAL_YEAR=2024 | 93.86% |
| M4 | 연도별 납부율 추이(2023~2025) | PAYMENT_RATE / month.CAL_YEAR | 2023 93.66 · 2024 93.86 · 2025 93.98 (%) |
| M5 | 회원구분별 납입회비 총액 | TOTAL_PAID_FEE / member.MEMBER_TYPE | 1=756,640,436,694 · 2=132,140,772,778 · 3=6,356,891,665 · (NULL)=40,207,971 |
| M6 | 성별 개발 건수 | TOTAL_DEV_CNT / member.GENDER | F=2,002,899 · M=1,362,101 · U=229,573 · (공백)=270 |
| M7 | 회원상태별 개발 건수(상위) | TOTAL_DEV_CNT / member.MEMBER_STATUS | 12=2,317,052 · 1=1,194,376 · 7=29,794 |
| M8 | 2024년 개발/중단 건수 | TOTAL_DEV_CNT·TOTAL_STOP_CNT / CAL_YEAR=2024 | 개발 319,881 · 중단 123,180 |
| M9 | 전체 개발/중단 총건 | TOTAL_DEV_CNT·TOTAL_STOP_CNT | 3,594,843 / 1,038,262 |
| M10ⓖ | 캠페인별 납부율 알려줘 | (비활성) | "캠페인 FK 미적재 → Phase-2" 안내(산출 금지) |
| M11ⓖ | 활동회원수(월말 활동회원)는? | (비활성) | "ACTIVE_CNT 미적재 → Phase-2" 안내 |

```sql
-- gold (M3/M4): 연도별 납부율
SELECT CAL_YEAR, PAYMENT_RATE
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY DIMENSIONS month.CAL_YEAR METRICS PAYMENT_RATE)
WHERE CAL_YEAR BETWEEN 2023 AND 2025 ORDER BY CAL_YEAR;
-- gold (M5): 회원구분별 납입회비
SELECT MEMBER_TYPE, TOTAL_PAID_FEE
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY DIMENSIONS member.MEMBER_TYPE METRICS TOTAL_PAID_FEE);
```

> ⓖ 주의(06 §4-1): 납부율 무필터 전기간은 100.36%(재청구·이월 왜곡) → 기간(연/월) 스코프로 답해야 PASS.

---

## 2. SV_MEMBER_EVENT (회원 상태전이)

| # | NL 질문 | 기대 metric / dim | 기대값 |
|---|---|---|---|
| E1 | 전체 개발/중단 건수 | TOTAL_DEV_CNT·TOTAL_STOP_CNT | 3,594,843 / 1,038,262 |
| E2 | 개발한 고유 회원수는? | DEV_MEMBER_COUNT | 1,585,949 |
| E3 | 중단한 고유 회원수는? | STOP_MEMBER_COUNT | 903,064 |
| E4 | 전이유형별 건수·회원수 | */ fme.EVENT_TYPE | DEV: 개발 3,594,843·회원 1,585,949 / STOP: 중단 1,038,262·회원 903,064 |
| E5ⓖ | 평균 유지기간(가입~중단)은? | (비활성) | "LAST_STOP_DATE 미적재·페어링 불가 → Agent/Phase-2" 안내(산출 금지) |
| E6ⓖ | 중단 사유별 중단 건수 | (비활성) | "REASON_SK 미적재 → Phase-2" 안내 |

```sql
-- gold (E4)
SELECT EVENT_TYPE, TOTAL_DEV_CNT, TOTAL_STOP_CNT, DEV_MEMBER_COUNT, STOP_MEMBER_COUNT
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_EVENT DIMENSIONS fme.EVENT_TYPE
     METRICS TOTAL_DEV_CNT, TOTAL_STOP_CNT, DEV_MEMBER_COUNT, STOP_MEMBER_COUNT);
```

---

## 3. SV_SERVICE (서비스 발송)

| # | NL 질문 | 기대 metric / dim | 기대값 |
|---|---|---|---|
| S1 | 전체 발송수는? | TOTAL_SEND_MEMBERS | 38,470,780 |
| S2 | 발송 대상 고유 회원수는? | DISTINCT_SEND_MEMBERS | 1,031,971 |
| S3 | 채널별 발송수 | TOTAL_SEND_MEMBERS / service.CHANNEL | MSG_AT 20,557,626 · SND 8,300,272 · EMAIL 7,811,121 · PSTMTR 1,790,448 · (미매핑) 11,313 |
| S4 | 2024년 발송수는? | TOTAL_SEND_MEMBERS / CAL_YEAR=2024 | 16,563,437 |
| S5ⓖ | 발송 성공률(수신율)은? | (비활성) | "SUCCESS/FAIL 미적재 → Phase-2" 안내(산출 금지) |

```sql
-- gold (S3)
SELECT CHANNEL, TOTAL_SEND_MEMBERS
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_SERVICE DIMENSIONS service.CHANNEL METRICS TOTAL_SEND_MEMBERS)
ORDER BY TOTAL_SEND_MEMBERS DESC;
```

---

## 4-SV. SV_EVENT_PARTICIPATION (행사 참여)

| # | NL 질문 | 기대 metric / dim | 기대값 |
|---|---|---|---|
| P1 | 전체 행사 참여자수는? | TOTAL_PARTICIPANTS | 1,134,126 |
| P2 | 고유 참여 회원수는? | DISTINCT_PARTICIPANTS | 407,223 |
| P3 | 행사종류별 참여자수 | TOTAL_PARTICIPANTS / event.EVENT_KIND | EVENT 718,438 · (Unknown) 263,611 · CRMN 152,077 |
| P4 | 2024년 참여자수는? | TOTAL_PARTICIPANTS / CAL_YEAR=2024 | 246,628 |
| P5ⓖ | 캠페인별 참여자수 | (비활성) | "CAMPAIGN_SK 미적재 → Phase-2" 안내 |

> ⓖ 주의(06 §4-3): 행사 미매핑(EVENT_SK=0) 참여 263,611(약 23%). 행사명/종류별은 부분 커버 → 커버리지 고지해야 PASS.

---

## 5. SV_BUDGET (예산)

| # | NL 질문 | 기대 metric / dim | 기대값 |
|---|---|---|---|
| B1 | 전체 편성예산은? | TOTAL_PLAN_BUDGET | 503,070,876,000 |
| B2 | 전체 집행예산(ERP)은? | TOTAL_EXEC_BUDGET | 199,287,107,812 |
| B3 | 전체 집행율은? | EXEC_RATE | 39.61% |
| B4 | 예산구분별 편성·집행·집행율 | */ item.BUDGET_CATEGORY | 지출 254,057,822,000/80,492,821,242/31.68% · 수입 249,013,054,000/118,794,286,570/47.71% |
| B5ⓖ | 캠페인별 ROI(개발단가) 알려줘 | (비활성) | "CAMPAIGN_SK·비용·FMM 연계 미적재 → Phase-2(신9~11)" 안내 |

```sql
-- gold (B4)
SELECT BUDGET_CATEGORY, TOTAL_PLAN_BUDGET, TOTAL_EXEC_BUDGET, EXEC_RATE
FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_BUDGET DIMENSIONS item.BUDGET_CATEGORY
     METRICS TOTAL_PLAN_BUDGET, TOTAL_EXEC_BUDGET, EXEC_RATE) ORDER BY TOTAL_PLAN_BUDGET DESC;
```

---

## 6. 가드레일 평가(ⓖ) 요약 — custom instruction 검증

| 케이스 | 기대 Agent 행동 |
|---|---|
| M10·E6·S5·P5·B5 (비활성 지표) | 임의 산출 금지 → "데이터 적재 후(Phase-2)" 안내(R8) |
| M11 (활동회원수) | ACTIVE_CNT 미적재 안내 |
| E5 (유지기간) | 페어링 불가 → Agent/Phase-2 안내 |
| 납부율 무필터 | 기간 스코프로 재해석(전기간 100.36% 단정 금지) |
| 행사/서비스 Unknown | 커버리지(23% 미매핑) 고지 |

---

## 7. 운영 주의 & 다음

- **기대값 재생성**: 값은 2026-07-22 GOLD 스냅샷. Bronze→GOLD 재적재·A/B계열 추가 적재 시 **본 평가셋 기대값 재실행·갱신**(§1~5 gold SQL 재실행). 특히 미래연도(2026~) 행은 데이터 유입 시 변동.
- **활성 확장 시 평가 추가**: Phase-2에서 캠페인/조직/성공률/유지율 등 활성화되면 해당 ⓖ 케이스를 정상 산출 케이스로 승격하고 기대값 추가.
- **다음**: `08_AGENT_spec.md` — 최종 3 Agent(회원·마케팅·overall) 중 **Phase-1 배포 2개**(회원·overall, 마케팅은 bronze 미완으로 Phase-2) 스펙(도구=SV 5개·Cortex Search·orchestration 라우팅·custom instruction §6) → `10_SI연결_검증.md`(CoWork ADD AGENT).

---
_Co-authored with CoCo_
