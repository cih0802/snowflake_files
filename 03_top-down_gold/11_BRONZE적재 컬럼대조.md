<!-- LLM-METADATA
doc_id: BRONZE_GOLD_COVERAGE_CHECK
doc_role: gold_need_coverage_check (내부 점검) — CRM 전용·역방향
project: GN_DW (굿네이버스)
기준: 09_bronze_crm_ddl.sql (확정 BRONZE 정본) — GOLD 설계가 필요한 데이터를 충족하는지 점검
scope: BRONZE_CRM only. 방향 = GOLD 필요 → BRONZE 충족 여부 (역방향)
related: 30_output_share/06_BRONZE노출감사.md (전 원천·순방향, 상호 보완)
note: 컬럼정의서_20260629.csv는 WIP(작성중)이라 비교 기준 아님. "정의서에 있는데 DDL에 없다"는 판단 대상에서 제외.
END-METADATA -->

# BRONZE(확정 DDL) ↔ GOLD 필요 데이터 충족 점검

> ⚠️ **본 문서의 범위·방향 (2026-07-28 명시)**
>
> | 구분 | 본 문서 (11) | `06_BRONZE노출감사.md` |
> |---|---|---|
> | **범위** | **BRONZE_CRM 전용** | **전 원천** (CRM·AGENCY·ERP·GA4 1,121컬럼) |
> | **방향** | **역방향** — GOLD 필요 데이터가 BRONZE에 있는지 | **순방향** — BRONZE 컬럼이 GOLD에 노출되는지 |
> | **질문** | "설계에 필요한 게 없나?" (공백 탐지) | "있는 걸 다 보여주나?" (미노출 탐지) |
> | **기준** | 215 지표가 요구하는 컬럼 | BRONZE 물리 컬럼 전량 |
> | **결론** | CRM 공백 없음 | 노출됨(GOLD) 70 · 대체노출(파생) 14 · 설계O·값미주입 1 · SILVER까지만 359 · 판정보류 14 · 미노출 612 · 제외 51 = 1,121 |
>
> ⚠️ **[2026-08-03 수치 정정]** 종전 본 행은 감사 결과를 "노출 18 · 하드코딩 9 · SILVER까지 356 · 미노출 664"로
> 인용했으나 **감사 정본(`06_BRONZE노출감사.md` §1, 감사일 2026-07-28)의 실제 값과 불일치**했다. 위 수치로 교체한다.
> 인용 시 감사 정본 §1 요약표를 직접 확인할 것(문서 간 drift 재발 방지).
>
> **두 점검은 대체 관계가 아니다.** 본 문서가 "공백 없음"이라 한 것은 *설계된 지표를 채울 수 있다*는 뜻이며,
> *BRONZE에 있는 데이터를 다 노출한다*는 뜻이 아니다. 후자는 순방향 감사(06)의 관심사이고,
> 그 결과 **미노출 612컬럼 · 설계O·값미주입 1컬럼**이 별도로 드러났다.
> 즉 **역방향 충족 ≠ 순방향 노출** — P13(커버리지≠정확도)의 또 다른 사례다.

> ✅ **[2026-07-20 배포·적재로 확증]** GOLD 24테이블 + SILVER 32테이블 적재 완료로 본 점검 결론("BRONZE에 GOLD 필요 데이터 공백 없음")이 실측 확인됨. `FACT_TARGET_BIZ`만 0행(=`CRM_BIZ_TARGET` 데이터 입고 대기).

**기준**: `09_bronze_crm_ddl.sql`(확정 BRONZE)이 GOLD 설계(215 지표 / 24테이블)가 필요로 하는 데이터를 **모두 담고 있는지**만 본다. 컬럼정의서 CSV는 작성중(WIP)이라 비교 기준으로 쓰지 않는다.

## 결론
**확정 BRONZE에 GOLD 필요 데이터가 모두 존재 — 누락 없음.** BRONZE에 적재 안 된 컬럼은 전부 GOLD가 쓰지 않는 PII·메시지 본문이다. 단, 회원 인구통계 속성의 **출처 테이블**만 lineage에서 유의(아래 1번).

> ⚠️ **이 결론의 유효 범위**: "GOLD 설계가 요구하는 CRM 데이터"에 한정된다.
> AGENCY 3원천의 이질속성 미승격 및 GOLD 값미주입은 본 점검 범위 밖이며,
> `06_BRONZE노출감사.md` 와 `03_테이블 설계.md §3-A` 에서 다룬다.
>
> ⚠️ **[2026-08-03 수치 정정]** 종전 "AGENCY … 57컬럼 및 GOLD 하드코딩 9건" 인용은 감사 정본과 불일치한다.
> 감사 정본 §1 원천별 교차표 실측: **AGENCY 102컬럼 = 노출됨 63 · 대체노출 13 · 설계O·값미주입 1 · SILVER까지만 18 · 판정보류 7 · 미노출 0**
> (즉 AGENCY 미노출은 0건이다). "57"의 근거는 재현 불가 — 대조하면 ERP `SILVER까지만`=57 과 수치가 일치하므로
> **원천 오귀속 가능성**이 있으나 확정할 수 없어 추정하지 않고 삭제한다.

## 1. GOLD 회원 속성 — 출처 유의 (충족됨)
DIM_MEMBER가 쓰는 인구통계 속성이 `TM_MM_FDRM_MBER_INFO`엔 일부 없지만 **개발/증감 거래 테이블에 시점 스냅샷으로 존재** → GOLD 충족. SILVER lineage에서 출처만 맞추면 됨.

| GOLD 속성 | 확정 BRONZE 출처 | 비고 |
|---|---|---|
| 성별 | `TM_MM_FDRM_MBER_INFO.SEX` (+DVLP_AMT/IRSD) | OK |
| 회원상태·신규기존·가입경로 | `TM_MM_FDRM_MBER_INFO` (MBER_STAT_CD·RELATNSP_DIV_CD·JOIN_PATH_CD) | OK |
| **지역(AREA_CD)** | `TM_MM_FDRM_MBER_DVLP_AMT`·`IRSD` | MBER_INFO엔 **없음** → 개발시점 스냅샷 사용 |
| **연령(AGE)** | `TM_MM_FDRM_MBER_DVLP_AMT`·`IRSD` | 〃. 생일(BRTHDY) raw는 미적재지만 AGE 코드화로 충족 |

## 2. BRONZE 미적재 컬럼 — 전부 GOLD 불요
컬럼정의서엔 있으나 확정 BRONZE엔 없는 컬럼(약 71개)은 **이름·연락처·주소·생일·주민/카드·메시지 본문** 등 개인정보·콘텐츠뿐이다. **GOLD 24테이블 어디에도 쓰지 않는다** → 조치 불요.

| 유형 | 예시 컬럼 | GOLD 사용 |
|---|---|---|
| 식별 PII | MBER_KORNM/ENGNM, MBTLNUM, EMAIL, FAXNO, ADDR/DTL_ADDR/ZIP, RRN_*_ENC, CARD_PWDNO_ENC | ✖ |
| 아동 PII | CHILD_KORNM/ENGNM, CHILD_BRTHDY, CHILD_PIC | ✖ (결연아동코드#122는 GA4 URL 파싱으로 별도 확보) |
| 메시지 본문 | MAIL_CONT, SMS_TALK_CONT, ALIM_TALK_CONT, MSG_AT_CTNT, EMAIL_CTNT, BTN_LIST | ✖ |

## 3. 컬럼정의서에만 있는 테이블 2개 — GOLD 불요

🔴🔴 **[2026-08-13 O72-C] 이 절의 전제가 무효화됐다 — 두 테이블은 이제 BRONZE 에 물리 실재한다.**
실측 = `TM_MM_FDRM_MBER_SPNSR` **2,228,064행 / 9컬럼** · `TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT` **1,134,848행 / 13컬럼**
(BRONZE_CRM 45테이블 ↔ 감사 기준선 43 차집합 · `50_handoff/02_데이터마이그 A_PRODUCER.sql:87` 이 *"누락되어 있던 2개"* 로 명시).
⇒ 제목의 **「컬럼정의서에만 있는」은 더 이상 사실이 아니다**(제목은 골든 좌표라 유지하고 여기서 시점을 적는다).

🟢 **아래 표의 두 판정도 재검토 조건이 발동했다**(이 절 말미가 예고한 그 조건이다):

| 테이블 | 종전 「GOLD 불요」 판정 | 🔴 O72-C 실측 재판정 |
|---|---|---|
| `TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT` (결연 단위 개발) | 회원 개발은 `TM_MM_FDRM_MBER_DVLP_AMT`로 충족, 215 지표에 결연단위 개발지표 없음 | **215 지표 기준은 여전히 유효**하나, `07_추가_지표사전_20260813` **20건이 추가**되며 **177 평균 약정금액(원)**·175·176(후원사업금액 기반 활동건)이 후원/약정 단위를 요구한다. 이 테이블은 **`BF_STAT_CD`→`AF_STAT_CD` 상태전이 + 33년 금액 이력**(1993-01-13~2026-08-06 · `SPNSR_AMT` NULL 0 · 음수 = 감액/해지)을 보유한다 ⇒ **재검토 대상으로 승격** |
| `TM_MM_FDRM_MBER_SPNSR` (회원-후원 매핑) | FACT가 `SPNSR_NO`·`SPNSR_BSNS_ID` 직접 보유 → 매핑 불요 | 🔴 **그 판정은 개발 사건 grain 에서만 참이다.** `TM_MM_FDRM_MBER_SPNSR_BSNS`(후원×사업 **완전 유일** 상태 테이블 · 약정금액·중단일 보유)에는 **회원번호가 없어** 회원 단위 집계가 불가능했고, 이 매핑이 그것을 연결한다(**고아 0 · 팬아웃 0**). 또 **`FRST_REGIST_DT`(후원 시작일)** 가 `DEC-22` 의 「시작일 부재」를 메운다 ⇒ **불요 판정 철회** |

> 🔴 **판정 정본 = 이슈원장 `00_INDEX_이슈원장.md` §1 의 O72-C 행.** 이 문서는 좌표만 갱신한다.
> ⚠️ 다만 **아직 배선하지 않았다** — SILVER/GOLD 모델은 두 테이블을 참조하지 않는다(`_sources.yml` 미등재).
> 향후 결연(아동결연) 단위 분석이 범위에 추가될 때만 재검토.

## 정리
- GOLD 설계 진행에 **BRONZE 데이터 공백 없음** — 별도 입고 요청 불필요.
- 유일한 후속 작업: SILVER lineage에서 **지역·연령은 `DVLP_AMT`/`IRSD` 시점 스냅샷에서 가져오도록** 매핑(`08_silver의존.md`).
