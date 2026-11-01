# S-1 엔티티 설계서 ⑥ `CRM_CAMPAIGN_MASTER`

> SILVER 정제 레이어 `GN_DW.SILVER.CRM_CAMPAIGN_MASTER` 설계서.
> 입력: `BRONZE_CRM 테이블 정보.MD` / 상위: `SILVER_설계_작업 계획.md` §1-1(#6), §0 원칙 4·5·10·11.
> GOLD 수요처: `DIM_CAMPAIGN`(SCD1, GOLD_차원 설계 §4). 간접: `FMM`·`FSE`가 `CAMPAIGN_SK` 보유, 실적 조직귀속이 캠페인 경유(결정 G).
> 원천: `TM_CM_CMPGN_MNG`(32, 캠페인 본체 — 2026-06 현업 +5컬럼) + `TM_CM_BRND_MNG`(9, 브랜드 속성 N:1 JOIN) + `TM_CM_MKTNG_CMPGN_MNG`(8, 마케팅캠페인명 N:1 JOIN).

---

## 1. 핵심 — 깔끔한 SCD1 차원 (차단 없음) + 속성 갭

본 엔티티는 **1행/캠페인** 마스터로, 이력 테이블·차단 원천이 없어 **즉시 완전 설계 가능**(⑤와 달리 HIST 없음). 두 가지만 유의:

1. **브랜드는 속성 JOIN(N:1, LEFT)** — `TM_CM_BRND_MNG`(9)는 다수 캠페인이 공유하는 브랜드. `BRND_ID`(CMPGN #11) → 브랜드 row를 캠페인에 denormalize(원칙 4, 행 불변). **반드시 LEFT JOIN** — `BRND_ID`가 NULL/미등록인 캠페인도 보존(INNER 시 캠페인 누락, 원칙 4 위배). grain 1/캠페인 유지.
2. **DIM_CAMPAIGN 속성 3개 원천 확보 (OPEN-26 ✅해소, 2026-06 현업)** — GOLD가 요구하던 `국내해외구분(#15)·사업사례구분(#16)·캠페인유형(#17)`이 `TM_CM_CMPGN_MNG`에 명시 컬럼으로 추가됨: `CMPGN_TYPE1_BSN`(국내/해외, MM295)→#15, `CMPGN_TYPE2_BSN`(사업/사례, MM296)→#16. #17(캠페인유형)은 `CMPGN_CTGR_CD`(캠페인카테고리, MM294) 후보로 현업 최종확인 대기. 추가로 `MBER_INFLOW_PATH_CD`(개발인입경로, MM293)·`MKTG_CMPGN_NM`(마케팅캠페인명, →`TM_CM_MKTNG_CMPGN_MNG`) 신규 확보.

> ⚠️ 캠페인↔후원사업 관계 불확실(결정 C) → GOLD는 `DIM_CAMPAIGN`/`DIM_SPONSORSHIP` 분리, 팩트가 양 SK 보유. SILVER는 `SPNSR_BSNS_ID`(#18)를 **속성(링크)으로만 보존**, 병합 금지.

---

## 2. grain / PK

- **grain**: 1행 / 캠페인(`CMPGN_CD`).
- **PK**: `CAMPAIGN_KEY` = `CMPGN_CD`(#1) — 캠페인 코드 자연키. GOLD `DIM_CAMPAIGN.CAMPAIGN_BK`(#120)와 동일. 회원 접두 없음(전역 코드).
  - PK 유일성·#120 BK 동일성 BRONZE 실측(OPEN-29).
- **계층(자기참조)**: `UPPER_CMPGN_CD`(#3) → 동일 테이블 `CMPGN_CD` 상위 캠페인. `UPPER_CMPGN_YN`(#4)로 상위 여부. GOLD 계층(공통브랜드>공통상위>공통캠페인>캠페인)은 분리설계라 순서 오답에도 무손상(OPEN-28).
- **브랜드 FK**: `BRND_ID`(#11) → `TM_CM_BRND_MNG`. N:1 속성 JOIN(OPEN-27).
- **조직 경로(결정 G)**: `USE_DEPT_CD`(#8) → `CRM_ORG_MASTER`(엔티티⑧, DEPT_ID). GOLD `DIM_CAMPAIGN.ORG_SK`(#114~116) 해소 경로.
- **소프트삭제**: `USE_YN`(#16) 보존, 필터 금지(원칙 4).

---

## 3. 컬럼 명세 (`TM_CM_CMPGN_MNG` 본체 + `BRND_MNG` JOIN)

> 정제 표준 §0 원칙 11. 코드 `*_CD`+라벨 `*_NM` 병행(원칙 5, OPEN-3). 타입 캐스팅 잠정(OPEN-5).

| # | SILVER 컬럼 | 타입 | 원천 | 정제 규칙 |
|--:|---|---|---|---|
| 1 | `CAMPAIGN_KEY` (PK) | VARCHAR | `CMPGN_CD`(#1) | 캠페인코드. TRIM |
| 2 | `CAMPAIGN_NM` | VARCHAR | `CMPGN_NM`(#2) | 캠페인명 TRIM |
| 3 | `UPPER_CAMPAIGN_CD` | VARCHAR | `UPPER_CMPGN_CD`(#3) | 상위캠페인코드(자기참조) |
| 4 | `IS_UPPER_CAMPAIGN` | BOOLEAN | `UPPER_CMPGN_YN`(#4) | Y→TRUE/N→FALSE |
| 5 | `SPONSOR_DIV_CD` | VARCHAR | `SPNSR_DIV_CD`(#5, CM035) | 후원구분 1=정기/2=일시 |
| 6 | `CORP_DIV_CD` | VARCHAR | `CPR_DIV_CD`(#6, CM019) | 법인구분 |
| 7 | `CAMPAIGN_TARGET_CD` | VARCHAR | `CMPGN_TRGET_CD`(#7, CM002) | 캠페인대상 |
| 8 | `PR_METHOD_CD` | VARCHAR | `PR_MTH_CD`(#12, CM008) | 홍보방법 |
| 9 | `CAMPAIGN_OPEN_DE` | DATE | `CMPGN_STRT_DE`(#13) | 캠페인시작/오픈일 YYYYMMDD→DATE (GOLD 캠페인오픈일자 #19) |
| 10 | `USE_DEPT_CD` | VARCHAR | `USE_DEPT_CD`(#8) | 사용(운영)부서 → ORG_SK 경로(#114~116) |
| 11 | `SPNSR_BSNS_ID` | VARCHAR | `SPNSR_BSNS_ID`(#18) | 후원사업ID(DIM_SPONSORSHIP 링크, 병합 금지) |
| 12 | `SPNSR_ENTRPRS_ID` | VARCHAR | `SPNSR_ENTRPRS_ID`(#10) | 후원기업ID |
| 13 | `EMRGNCY_AID_BPLC_CD` | VARCHAR | `EMRGNCY_AID_BPLC_CD`(#20) | 긴급구호사업장(→`TM_CM_EMRGNCY_AID_BPLC`, 국내해외 후보 OPEN-26) |
| 14 | `CAMPAIGN_PROPERTY_YN` | VARCHAR(1) | `CMPGN_PRPT_YN`(#21) | 캠페인특성여부 |
| 15 | `USE_YN` | VARCHAR(1) | `USE_YN`(#16) | 사용여부(소프트삭제, 필터 금지) |
| 16 | `USE_SCOPE` | VARCHAR | `USE_SCOPE`(#9) | 사용범위 |
| 17 | `REFER_URL` | VARCHAR | `REFER_URL`(#17) | 참고URL |
| 18 | `CAMPAIGN_DC` | VARCHAR | `CMPGN_DC`(#19) | 캠페인설명 |
| — | *(2026-06 현업 추가 5컬럼 — 모두 코드값, CD_ID+DTL_CD_ID 라벨조인)* | | | |
| 19 | `DOMESTIC_OVERSEA_CD` | VARCHAR | `CMPGN_TYPE1_BSN`(#30, MM295) | 국내/해외구분. GOLD 국내해외구분#15 ✅ |
| 20 | `BSNS_CASE_CD` | VARCHAR | `CMPGN_TYPE2_BSN`(#31, MM296) | 사업/사례구분. GOLD 사업사례구분#16 ✅ |
| 21 | `CAMPAIGN_CTGR_CD` | VARCHAR | `CMPGN_CTGR_CD`(#29, MM294) | 캠페인카테고리. GOLD 캠페인유형#17 후보(현업 확인) |
| 22 | `MBER_INFLOW_PATH_CD` | VARCHAR | `MBER_INFLOW_PATH_CD`(#28, MM293) | 개발인입경로 |
| 23 | `MKTG_CAMPAIGN_CD` | VARCHAR | `MKTG_CMPGN_NM`(#32) | 마케팅캠페인코드(→`TM_CM_MKTNG_CMPGN_MNG` JOIN키) |
| 24 | `MKTG_CAMPAIGN_NM` | VARCHAR | `MKTNG.MK_CMPGN_NM`(#2) | 마케팅캠페인명(N:1 LEFT JOIN, `MK_CMPGN_CD` 기준) |
| — | *(BRND_MNG N:1 JOIN, BRND_ID 기준)* | | | |
| 25 | `BRND_ID` | VARCHAR | `BRND_ID`(#11) | 브랜드ID(조인키) |
| 26 | `BRND_NM` | VARCHAR | `BRND_MNG.BRND_NM`(#2) | 브랜드명(GOLD 공통브랜드 #117) |
| 27 | `BRND_PR_MTH_LIST` | VARCHAR | `BRND_MNG.PR_MTH_LIST`(#5) | 브랜드 홍보방법리스트(보존 선택) |
| — | *(감사)* | | | |
| 28 | `FIRST_RGSTR_ID` | VARCHAR | `FRST_RGSTR_ID`(#23) | TRIM |
| 29 | `FIRST_REGIST_DT` | TIMESTAMP_NTZ | `FRST_REGIST_DT`(#24) | 최초등록일시 |
| 30 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | `LAST_UPDT_DT`(#26) | 최종수정일시 |

> **SILVER 제외(운영·비분석)**: `MBRFEE_BNKB_LIST`(#14 회비통장리스트)·`INICIS_ACNT_NO`(#15 이니시스계정)·`ATCHFL_ID`(#22 첨부파일)·`RM`(#27 비고). GOLD 비참조. INICIS 계정은 결제 운영정보(보존 시 거버넌스 검토).

### 3-1. 표준 감사/메타 컬럼 (원칙 10)
`_SOURCE_SYSTEM`='CRM' · `_SOURCE_TABLE`('TM_CM_CMPGN_MNG'/'TM_CM_BRND_MNG'/'TM_CM_MKTNG_CMPGN_MNG' 행별 JOIN 출처) · `_LOADED_AT` · `_BATCH_ID`

---

## 4. GOLD 정합 (`DIM_CAMPAIGN`, SCD1)

| GOLD DIM_CAMPAIGN 컬럼 | 소스# | 본 엔티티 매핑 |
|---|---|---|
| CAMPAIGN_BK | #120 | `CAMPAIGN_KEY`(=CMPGN_CD) ✅ |
| 캠페인명 | #18 | `CAMPAIGN_NM` ✅ |
| 캠페인오픈일자 | #19 | `CAMPAIGN_OPEN_DE` ✅ |
| 공통상위캠페인 | #119 | `UPPER_CAMPAIGN_CD` ✅ |
| 공통브랜드 | #117 | `BRND_NM`(JOIN) ✅ |
| 홍보방법 | #118 | `PR_METHOD_CD`(+라벨) ✅ |
| ORG_SK | #114~116 | `USE_DEPT_CD` → ⑧ ORG ✅(경로) |
| **캠페인유형** | #17 | 🔶 `CAMPAIGN_CTGR_CD`(`CMPGN_CTGR_CD`, MM294) 후보 — 현업 최종확인 대기(OPEN-26 잔여) |
| **국내해외구분** | #15 | ✅ `DOMESTIC_OVERSEA_CD`(`CMPGN_TYPE1_BSN`, MM295) — 2026-06 현업 확보 |
| **사업사례구분** | #16 | ✅ `BSNS_CASE_CD`(`CMPGN_TYPE2_BSN`, MM296) — 2026-06 현업 확보 |
| 공통캠페인 | #147 | ⚠️ #119(상위)와 구분 기준 현업 — 자기참조 레벨. OPEN-28 |

- **세션캠페인(GA #102)**: GA4 입고 후 본 DIM에 매핑(정합 스테이징) — CRM 범위 밖.
- **#126 캠페인별 납입방식**: GOLD 미지정(현업) — DIM_PAYMENT(⑤) 연계, 본 엔티티 비차단.
- 캠페인↔후원사업 카디널리티: 분리차원+양 SK로 방어(결정 C). `SPNSR_BSNS_ID` 속성 보존.

---

## 5. OPEN 이슈 (S-1 → 다음 단계 확인)

| ID | 이슈 | 영향 | 조치 |
|---|---|---|---|
| **OPEN-26 ✅대부분 해소(2026-06 현업)** | 국내해외구분#15←`CMPGN_TYPE1_BSN`(MM295)·사업사례구분#16←`CMPGN_TYPE2_BSN`(MM296) 확정. 잔여: 캠페인유형#17 원천(후보 `CMPGN_CTGR_CD`/MM294) | DIM 속성 충족 | #17 후보 현업 최종확인 + MM293~296·`MK_CMPGN_CD` 코드값 라벨 정의서 수령 |
| **OPEN-27** | `BRND_MNG` JOIN — `BRND_ID` N:1, `BRND_NM` 1:1 유일성 | 브랜드 denormalize 정합 | BRONZE 실측(BRND_ID당 1 BRND_NM) |
| **OPEN-28** | 캠페인 계층 — `UPPER_CMPGN_CD` 자기참조 깊이·루트(NULL/자기) + 공통캠페인(#147) vs 공통상위(#119) 구분 | 계층 컬럼 정확도 | 현업 계층 정의(분리설계라 비차단) |
| **OPEN-29** | `CMPGN_CD` PK 유일성 · #120 BK 동일성 | PK·조인 | BRONZE 실측 |
| **OPEN-5(공통)** | BRONZE 물리타입 미제공 | 캐스팅 잠정 | S-2 전 실제 타입 확인 |
| **OPEN-3(공통)** | 코드→라벨(CM035·CM019·CM002·CM008) + `TM_CM_EMRGNCY_AID_BPLC`(긴급구호사업장) | 라벨 컬럼 | `CRM_CODE_MASTER`(#14) 후 일괄 |

---

## 6. 다음

- **즉시 완전 설계 가능** — 차단 원천 없음(⑤와 달리 HIST 없음). 현 시점 DDL·매핑 작성 가능.
- **선결(품질, S-2 전)**: OPEN-29(PK 유일성)·OPEN-27(브랜드 1:1)·OPEN-26 잔여(캠페인유형#17 후보 확인 — 비차단).
- **S-2**: `CREATE TABLE GN_DW.SILVER.CRM_CAMPAIGN_MASTER` DDL(CMPGN_MNG 본체 + BRND_MNG + MKTNG_CMPGN_MNG JOIN).
- **S-3**: `TM_CM_CMPGN_MNG`(32)+`TM_CM_BRND_MNG`(9)+`TM_CM_MKTNG_CMPGN_MNG`(8) → SILVER 1:1 매핑표(제외 4컬럼 표기).
