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
> | **결론** | CRM 공백 없음 | 노출 18 · 하드코딩 9 · SILVER까지 356 · 미노출 664 |
>
> **두 점검은 대체 관계가 아니다.** 본 문서가 "공백 없음"이라 한 것은 *설계된 지표를 채울 수 있다*는 뜻이며,
> *BRONZE에 있는 데이터를 다 노출한다*는 뜻이 아니다. 후자는 순방향 감사(06)의 관심사이고,
> 그 결과 **미노출 664컬럼 · 하드코딩 9컬럼**이 별도로 드러났다.
> 즉 **역방향 충족 ≠ 순방향 노출** — P13(커버리지≠정확도)의 또 다른 사례다.

> ✅ **[2026-07-20 배포·적재로 확증]** GOLD 24테이블 + SILVER 32테이블 적재 완료로 본 점검 결론("BRONZE에 GOLD 필요 데이터 공백 없음")이 실측 확인됨. `FACT_TARGET_BIZ`만 0행(=`CRM_BIZ_TARGET` 데이터 입고 대기).

**기준**: `09_bronze_crm_ddl.sql`(확정 BRONZE)이 GOLD 설계(215 지표 / 24테이블)가 필요로 하는 데이터를 **모두 담고 있는지**만 본다. 컬럼정의서 CSV는 작성중(WIP)이라 비교 기준으로 쓰지 않는다.

## 결론
**확정 BRONZE에 GOLD 필요 데이터가 모두 존재 — 누락 없음.** BRONZE에 적재 안 된 컬럼은 전부 GOLD가 쓰지 않는 PII·메시지 본문이다. 단, 회원 인구통계 속성의 **출처 테이블**만 lineage에서 유의(아래 1번).

> ⚠️ **이 결론의 유효 범위**: "GOLD 설계가 요구하는 CRM 데이터"에 한정된다.
> AGENCY 3원천의 이질속성 미노출(감사 결과 57컬럼) 및 GOLD 하드코딩 9건은 본 점검 범위 밖이며,
> `06_BRONZE노출감사.md` 와 `03_테이블 설계.md §3-A` 에서 다룬다.

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
| 테이블 | GOLD 사용 안 하는 이유 |
|---|---|
| `TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT` (결연 단위 개발) | 회원 개발은 `TM_MM_FDRM_MBER_DVLP_AMT`로 충족, 215 지표에 결연단위 개발지표 없음 |
| `TM_MM_FDRM_MBER_SPNSR` (회원-후원 매핑) | FACT가 `SPNSR_NO`·`SPNSR_BSNS_ID` 직접 보유 → 매핑 불요 |

> 향후 결연(아동결연) 단위 분석이 범위에 추가될 때만 재검토.

## 정리
- GOLD 설계 진행에 **BRONZE 데이터 공백 없음** — 별도 입고 요청 불필요.
- 유일한 후속 작업: SILVER lineage에서 **지역·연령은 `DVLP_AMT`/`IRSD` 시점 스냅샷에서 가져오도록** 매핑(`08_silver의존.md`).
