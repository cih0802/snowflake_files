# SILVER 작업계획 비판적 검토 결과

> ✅ **종료(RESOLVED) — 2026-06-23**: 본 검토의 정정 2건은 `SILVER_설계_작업 계획.md`에 모두 반영 완료.
> - 발견 1(레거시 View EXT_* 의존) → §3-1 **R8 신설**(서빙 계층 검증)
> - 발견 2·3(DIM_MEMBER_IDENTITY 커버리지 과장) → §1-1·§6·§7 **"DIM 7 완전 + IDENTITY 부분(CRM측만), 잔여 DIM 5"**로 정정 + **S-7(신원 브리지)** 단계 신설.
> 이 문서는 더 이상 작업 대상(worklist)이 아니며, **검토 이력(audit record)으로 보존·아카이브**됨. 이하 본문은 정정 이전 시점 기록.

---

> 대상 문서: `04_silver_design/SILVER_설계_작업 계획.md` (GOLD 요구 + BRONZE 구성 가능성 2축으로 재작성한 버전)
> 검토 질문: "EXT_* 제외 + 소스 4분류 재작성이 GOLD_SILVER 의존·BRONZE 정의와 정합하며, 과장·미검증 단정이 없는가?"
> 참조: `03_top-down_gold/GOLD_SILVER 의존.md`, `03_top-down_gold/GOLD_ddl 초안.sql`, `02_GN_DW_building/02_DB_BRONZE_SILVER.md`, `02_GN_DW_building/03_GOLD_SERVING.md`
> 결론: **구조 결정(EXT_* 제외·PoC 섹션 삭제)은 지시·소스와 부합. 단, 서빙 계층 영향을 미검증 단정했고, DIM_MEMBER_IDENTITY 커버리지를 과장하는 내부 모순이 있다. 정정 2건 필요.**

---

## 발견 요약

| # | 발견 | 심각도 | 위치 |
|---|---|---|---|
| 1 | 레거시 View의 EXT_* 소스를 "BRONZE 직참조로 유지"라 미검증 단정 | 🔴 치명 | §1-5 |
| 2 | DIM_MEMBER_IDENTITY를 "CRM 즉시 충족 DIM 8"에 포함(cross-source 무시) | 🟠 중 | §6-1, §7 |
| 3 | 발견 2의 연쇄 — "잔여 DIM 4" 산술 오류 | 🟠 중 | §7 |

---

## 🔴 발견 1: 레거시 View 소스 단정 (§1-5)

**현상**
- §1-5는 외부 집계 테이블 제외를 설명하며 "PoC View가 공급받던 외부 집계 테이블은 SILVER 정제 없이 **BRONZE 직참조로 유지한다**"라고 기재.

**문제**
- `02_GN_DW_building/03_GOLD_SERVING.md` §3.5-L: 레거시 GOLD View 35개는 **SV·Agent·Streamlit이 현재 참조 중**이라 병존(폐기 불가).
- 기존 작업계획에서 `EXT_*`는 **SILVER 레이어 테이블**이었고, PoC GOLD View가 이 `SILVER EXT_*`를 참조하는 구조였음.
- 그런데 EXT_*를 SILVER에서 삭제하면서 "View는 BRONZE를 직접 참조하면 된다"고 **근거 없이 단정**. 실제 View가 `SILVER EXT_*`를 참조 중이라면 EXT_* 삭제는 **서빙 계층을 끊는 변경**.

**결론**
- "BRONZE 직참조로 유지"는 검증되지 않은 주장. 정직한 서술은 "EXT_*는 GOLD star schema 비참조가 확실하나, **레거시 View의 EXT_* 의존 여부는 확인 필요(검증 항목)**".

---

## 🟠 발견 2: DIM_MEMBER_IDENTITY 커버리지 과장 (§6-1, §7)

**현상**
- §6-1·§7 두 곳에서 "CRM_* 14가 **DIM 8** 즉시 충족"이라 기재. 이 8개에 `DIM_MEMBER_IDENTITY` 포함.

**문제 — `DIM_MEMBER_IDENTITY`는 cross-source 차원** (GOLD_SILVER 의존 §1)
- `GA_MEMBER_ID`(#112) ← `SILVER_GA4.사용자` (입고 후)
- `SPONSORED_CHILD_CODE`(#122) ← `SILVER_GA4.트래픽소스/페이지` (입고 후)
- `MEMNUM`(#111) ← **원천 미확인(R4 미해소)**
- → CRM만으로 **완성 불가**.

**내부 모순**
- 작업계획 §1-1은 `CRM_MEMBER_MASTER`와 `GA4_USER` 둘 다 `DIM_MEMBER_IDENTITY` 수요처로 명시해 놓고도, §7 집계에서는 8개 전부 즉시 충족으로 계산.

**결론**
- 정확한 표현: "**7개 완전 충족 + DIM_MEMBER_IDENTITY는 CRM측(MEMBER_NO)만, GA측·MEMNUM 미충족**".

---

## 🟠 발견 3: 잔여 DIM 산술 오류 (§7)

**현상**
- §7: "잔여 DIM 4(DATE는 ETL 생성, GA_SOURCE·GA_EVENT·AD_CREATIVE는 입고 후)".

**문제**
- 발견 2로 인해 완전 충족은 7개. 12 − 7 = 5이며, 여기에 `DIM_MEMBER_IDENTITY`의 GA측 완성분이 포함돼야 함. "잔여 4"는 IDENTITY를 즉시 충족으로 오계산한 결과.

---

## ✅ 검증 결과 문제 없는 부분

- **EXT_* 제외 핵심 논거**: GOLD FGA(세션·이벤트 raw grain)·FAD(매체 raw grain)가 집계본을 참조하는 컬럼 0건 — GOLD_SILVER 의존 §2(line 82~89)와 일치. **타당**.
- **CRM_* 14 ↔ BRONZE**: 사용 37 + 미포함 3 = 40. **정확**.
- **FMM·FTG-D·FSE의 CRM 소스 충족**: 발송·참여·약정·납입·상태이력·개발목표 모두 CRM 매핑. **정확**.
- **D10/R6(DIM_MEMBER SCD2 = STATUS만), R7(약정 3중 grain)** 추가: 직전 검토 발견과 일치. **타당**.
- **테이블 수 24** (CRM 14 + GA4 5 + ERP 2 + AGENCY 3): **정확**.

---

## 종합 판정

- **구조 결정(EXT_* 제외·PoC 전환 섹션 삭제)**: 지시("BRONZE 잔여 SILVER 정의 무시") 및 GOLD 소스와 ✅ 부합.
- **결함**: ① 서빙 계층(레거시 View) 영향을 검증 없이 "해결됨"으로 단정(발견 1), ② DIM_MEMBER_IDENTITY cross-source 성격 무시한 커버리지 과장 + 내부 모순(발견 2·3).
- 두 결함 모두 "지나치게 깔끔하게 마무리하려다" 생긴 오류 유형.

## 반영 예정 (정정 2건)

| 발견 | 반영 위치 | 조치 |
|---|---|---|
| 1 | §1-5, §3-1 리스크 | "BRONZE 직참조로 유지" → "레거시 View의 EXT_* 의존 여부 확인 필요" + **R8 신설**(서빙 계층 검증) |
| 2·3 | §6-1, §7 | "DIM 8" → "DIM 7 완전 + IDENTITY 부분(CRM측만, GA·MEMNUM 미충족)"으로 정정, 잔여 차원 산술 수정 |
