# S-1 엔티티 설계서 ④ `CRM_PAYMENT_BILLING`

> SILVER 정제 레이어 `GN_DW.SILVER.CRM_PAYMENT_BILLING` 설계서.
> 입력: `BRONZE_CRM 테이블 정보.MD` / 상위: `SILVER_설계_작업 계획.md` §1-1(#4), §0 원칙 4·5·10·11, **D3(납입+청구 단일 테이블)**, R3(UNION ALL 패턴, 회원마스터 정합).
> GOLD 수요처: `FMM`(납입 #69·70 / 청구 #71 / 회비유형 #66·67·68 measure), `DIM_PAYMENT`(회비유형 FEE_TYPE).

---

## 1. 핵심 — 이질적 2원천 UNION ALL (회비 + 기부금)

작업계획 §1-1(#4)·§2 통합트리·D3는 본 엔티티를 "`MBRFEE_ACMSLT` + `DNTN_DTLS` → 납입+청구 동일행"으로 표기하나, 두 원천은 **키·회원체계·컬럼셋이 모두 다른 별개 과금 스트림**이다. 회원마스터(엔티티①)와 동일한 **UNION ALL + 타입 구분** 패턴으로 통합한다(JOIN 아님).

| 원천 | 컬럼 | 자연키 | 회원참조 | 청구(RQEST) | 납입(PAY) | 성격 |
|---|---|---|---|---|---|---|
| `TM_PM_MBRFEE_ACMSLT` | 51 | `MBRFEE_KEY` | `MBER_NO`(정기) | ✅ 보유 | ✅ 보유 | 정기회비 적산(청구→납입 동일행) |
| `TM_PM_DNTN_DTLS` | 25 | `DNTN_KEY` | `ONCE_MBER_NO`(일시) | ❌ **없음** | ✅ 보유 | 일시기부금(청구 없이 즉시 납입) |

### 1-1. 두 가지 핵심 사실
1. **D3의 "납입+청구 동일행 보존"은 `MBRFEE_ACMSLT`에만 해당.** 이 원천은 한 행에 `RQEST_AMT`(청구)·`PAY_AMT`(납입)가 공존하므로 **행 분리 금지**(컬럼으로 분리 보존). GOLD에서 RQEST→청구 measure(#71), PAY→납입 measure(#69·70)로 추출.
2. **`DNTN_DTLS`(일시기부금)는 청구 개념이 없다.** `RQEST_*` 컬럼 자체가 원천에 부재 → UNION ALL 시 기부금 행의 청구 컬럼은 전부 `NULL` 패딩. 일시기부는 "청구→납입" 사이클이 아니라 캠페인 단발 납입이기 때문(원천 비고: `PRCS_STAT_CD` "현시점 S만 존재").

> ⚠️ 작업계획 §1-1(#4)·D3는 UNION ALL 구조와 "기부금 청구 부재"를 명시하지 않음 → §6 OPEN-13 + 작업계획 정합 정정(신규 R9).

---

## 2. grain / PK

- **grain**: 1행 / 과금건. `MBRFEE_ACMSLT`는 1행/회비건(회비월×차수), `DNTN_DTLS`는 1행/기부건. 두 스트림 UNION ALL → 행 수 = 회비건수 + 기부건수(원칙 4, 행 축소 없음).
- **자연키**: `MBRFEE_KEY`(회비)·`DNTN_KEY`(기부)는 **별도 채번 체계** → 값 충돌 가능성 배제 불가. 회원마스터(R3)와 동일하게 타입 접두 키로 방어.
- **PK (해소책)**: `PAY_KEY` = `PAYMENT_TYPE || '-' || SOURCE_PAY_KEY`
  - `PAYMENT_TYPE` ∈ {`MBRFEE`(회비/정기), `DNTN`(기부금/일시)}
  - `SOURCE_PAY_KEY` = 원천 키(`MBRFEE_KEY` / `DNTN_KEY`)
  - PK 유일성: `PAY_KEY` 중복 0건(§6, OPEN-14에서 실측).
- **회원 FK**: `MEMBER_KEY` — 엔티티① `CRM_MEMBER_MASTER`와 정합.
  - 회비: `'FDRM-' || MBER_NO` (⚠️ `MBRFEE_ACMSLT.MBER_NO`가 전부 정기마스터(`TM_MM_FDRM_MBER_INFO`)에 존재한다는 가정 — 고아 회원키 여부 OPEN-14에서 실측)
  - 기부: `'ONCE-' || ONCE_MBER_NO`
- **중복/소프트삭제**: 두 원천 모두 `USE_YN`(Y/N) 보유. SILVER는 **원본 보존**(필터 금지). GOLD 적재 시 `USE_YN='Y'` 필터는 적재 트랙 결정(§5 GOLD 정합).

---

## 3. UNION ALL 스키마 정합 규칙

두 원천을 통합 표준 컬럼으로 정렬. 한쪽에만 있으면 다른 쪽은 `NULL`.

### 3-1. 양쪽 공통 (직접 매핑)
`CPR_DIV_CD`(법인구분 CM019) · `ELCTR_SETLE_KEY`(전자결제KEY) · `MBRFEE_BNKB_KEY`(회비통장KEY) · `ACNUT_SER_NO`(계좌일련번호) · `FNLT_CD`(금융기관) · `PAYER_NM`(결제자명) · `PAY_AMT`(납입금액) · `PAY_DE`(납입일) · `PAY_STAT_CD`(납입상태) · `PRCS_STAT_CD`(처리상태) · `USE_YN` · `TRNSFER_MBRFEE_KEY`(이관회비KEY) · `TRNSFER_RSN_CD`(이관사유) · `RETUN_RSN_CD`(환급사유 PM042) · `ACMSLT_DEPT_CD`(실적부서) · `SPNSR_BSNS_ID`(후원사업ID)

### 3-2. 회비(MBRFEE) 전용 — 기부금은 NULL
| 표준 컬럼 | 원천 컬럼 | 의미 |
|---|---|---|
| `SPNSR_NO`·`SPNSR_BSNS_NO`·`RELATNSP_KEY` | 동명 | 후원/사업/결연 연계(약정 엔티티③ 정합) |
| `MBRFEE_MT`·`MBRFEE_SQNC` | 동명 | 회비월·차수 |
| `RQEST_MT`·`RQEST_SQNC` | 동명 | **청구**월·차수 |
| `RQEST_DIV_CD`(PM024)·`RQEST_AMT`·`RQEST_DE`·`RQEST_RST_CD`(PM021) | 동명 | **청구**구분·금액·일·결과 |
| `MBRFEE_DIV_CD`(PM010) | 동명 | 회비구분(정기/일시성 분기, #66~68 핵심) |
| `GFT_DIV_CD`(RM070)·`GFTMNEY_CHILD_CD` | 동명 | 선물구분·선물금아동코드 |
| `BILLKEY`·`PRCS_RST_CD`·`RQST_KEY`·`RST_KEY` | 동명 | 빌키·처리결과·신청/결과KEY |
| `OPERT_DIV_CD`(MM014)·`OPERTOR_ID`·`OPERT_DE` | 동명 | 작업구분/작업자/작업일 |

### 3-3. 기부금(DNTN) 전용 — 회비는 NULL
| 표준 컬럼 | 원천 컬럼 | 의미 |
|---|---|---|
| `ONCE_CMPGN_CD` | `ONCE_CMPGN_CD` | 일시후원캠페인코드(DIM_CAMPAIGN FK) |
| `RETUN_DNTN_KEY`·`RETUN_KEY` | 동명 | 환급기부금/환급KEY |
| `REGIST_DE`·`RGSTR_ID`·`RGSTR_NM`·`RM` | 동명 | 등록일/등록자/비고 |

> `ONCE_CMPGN_CD`는 `MBRFEE_ACMSLT`에도 존재(#17) → 캠페인 연계는 양쪽 보유. 표준 컬럼 `CAMPAIGN_CD`로 통합(회비=`ONCE_CMPGN_CD`#17, 기부=`ONCE_CMPGN_CD`#5).

---

## 4. 컬럼 명세 (타입 · 정제규칙)

> 정제 표준은 §0 원칙 11 적용(NULL 표준화·TRIM·캐스팅). 코드 컬럼은 `*_CD` 원본 + `*_NM` 라벨 병행(원칙 5, OPEN-3).
> ⚠️ **타입 캐스팅 잠정(OPEN-5 공통)**: BRONZE 정의서는 컬럼 인벤토리라 물리 데이터타입 미제공. 아래 타입은 추정 — S-2 전 `INFORMATION_SCHEMA.COLUMNS` 확인.
> ⚠️ 금액은 **원 단위 NUMBER 보존**(/10000 환산은 GOLD measure 단계, 원칙 11).

| # | SILVER 컬럼 | 타입 | 원천 | 정제 규칙 |
|--:|---|---|---|---|
| 1 | `PAY_KEY` (PK) | VARCHAR | 파생 | `PAYMENT_TYPE||'-'||SOURCE_PAY_KEY` |
| 2 | `PAYMENT_TYPE` | VARCHAR | 파생 | 'MBRFEE'/'DNTN' 리터럴 |
| 3 | `SOURCE_PAY_KEY` | NUMBER | `MBRFEE_KEY`/`DNTN_KEY` | 원천 키 정수 |
| 4 | `MEMBER_KEY` (FK) | VARCHAR | 파생 | 회비 `'FDRM-'||MBER_NO` / 기부 `'ONCE-'||ONCE_MBER_NO` |
| 5 | `MEMBER_DIV_CD` | VARCHAR | `MBER_DIV_CD`(MM018) | 회비만, 기부→NULL |
| 6 | `CORP_DIV_CD` | VARCHAR | `CPR_DIV_CD`(CM019) | 양쪽 |
| 7 | `CAMPAIGN_CD` | VARCHAR | `ONCE_CMPGN_CD` | 양쪽(§3-3) DIM_CAMPAIGN FK |
| 8 | `SPNSR_NO` | NUMBER | `SPNSR_NO` | 회비만 |
| 9 | `SPNSR_BSNS_NO` | NUMBER | `SPNSR_BSNS_NO` | 회비만 |
| 10 | `SPNSR_BSNS_ID` | VARCHAR | `SPNSR_BSNS_ID` | 양쪽 |
| 11 | `RELATNSP_KEY` | NUMBER | `RELATNSP_KEY` | 회비만(결연 연계) |
| 12 | `MBRFEE_MT` | VARCHAR | `MBRFEE_MT` | 회비월 YYYYMM, 기부→NULL |
| 13 | `MBRFEE_SQNC` | NUMBER | `MBRFEE_SQNC` | 회비차수 |
| 14 | `MBRFEE_DIV_CD` | VARCHAR | `MBRFEE_DIV_CD`(PM010) | 회비구분(#66~68 분기) |
| 15 | `GFT_DIV_CD` | VARCHAR | `GFT_DIV_CD`(RM070) | 선물구분 |
| 16 | `GFTMNEY_CHILD_CD` | VARCHAR | `GFTMNEY_CHILD_CD` | 선물금아동코드 |
| — | *(청구 RQEST — 회비만, 기부→NULL)* | | | |
| 17 | `RQEST_MT` | VARCHAR | `RQEST_MT` | 청구월 YYYYMM |
| 18 | `RQEST_SQNC` | NUMBER | `RQEST_SQNC` | 청구차수 |
| 19 | `RQEST_DIV_CD` | VARCHAR | `RQEST_DIV_CD`(PM024) | 청구구분 |
| 20 | `RQEST_AMT` | NUMBER | `RQEST_AMT` | **청구금액**(원, GOLD #71) |
| 21 | `RQEST_DE` | DATE | `RQEST_DE` | 청구일 YYYYMMDD→DATE, 무효→NULL |
| 22 | `RQEST_RST_CD` | VARCHAR | `RQEST_RST_CD`(PM021) | 청구결과 |
| — | *(납입 PAY — 양쪽)* | | | |
| 23 | `PAY_AMT` | NUMBER | `PAY_AMT` | **납입금액**(원, GOLD #69·70) |
| 24 | `PAY_DE` | DATE | `PAY_DE` | 납입일 YYYYMMDD→DATE, 무효→NULL |
| 25 | `PAY_STAT_CD` | VARCHAR | `PAY_STAT_CD`(PM012) | 납입상태 S=성공/F=실패(NULL 존재) |
| 26 | `PRCS_STAT_CD` | VARCHAR | `PRCS_STAT_CD`(PM013) | 처리상태 S=완료/F=미완 |
| 27 | `PRCS_RST_CD` | VARCHAR | `PRCS_RST_CD` | 처리결과(회비만) |
| — | *(결제수단 연계키 — 양쪽)* | | | |
| 28 | `ELCTR_SETLE_KEY` | NUMBER | `ELCTR_SETLE_KEY` | 전자결제KEY → `CRM_PAYMENT_METHOD`(#5) 조인 |
| 29 | `MBRFEE_BNKB_KEY` | NUMBER | `MBRFEE_BNKB_KEY` | 회비통장KEY |
| 30 | `ACNUT_SER_NO` | NUMBER | `ACNUT_SER_NO` | 계좌일련번호 |
| 31 | `FNLT_CD` | VARCHAR | `FNLT_CD` | 금융기관(→TM_PM_FNLT 라벨) |
| 32 | `BILLKEY` | VARCHAR | `BILLKEY` | 빌키(회비만) |
| 33 | `PAYER_NM` | VARCHAR | `PAYER_NM` | 결제자명 TRIM (⚠️PII) |
| — | *(이관/환급 — 추적)* | | | |
| 34 | `TRNSFER_MBRFEE_KEY` | NUMBER | `TRNSFER_MBRFEE_KEY` | 이관회비KEY |
| 35 | `TRNSFER_RSN_CD` | VARCHAR | `TRNSFER_RSN_CD` | 이관사유 |
| 36 | `RETUN_RSN_CD` | VARCHAR | `RETUN_RSN_CD`(PM042) | 환급사유 |
| — | *(귀속/감사)* | | | |
| 37 | `ACMSLT_DEPT_CD` | VARCHAR | `ACMSLT_DEPT_CD` | 실적부서(→CRM_ORG_MASTER) |
| 38 | `OPERT_DIV_CD` | VARCHAR | `OPERT_DIV_CD`(MM014) | 작업구분(회비만) |
| 39 | `USE_YN` | VARCHAR(1) | `USE_YN` | 사용여부 Y/N(소프트삭제, 필터 금지) |
| 40 | `REGIST_DE` | DATE | `REGIST_DE` | 등록일(기부만) |
| 41 | `RGSTR_ID` | VARCHAR | `RGSTR_ID` | 등록자ID(기부만) |

> 잔여 전용컬럼(`RQST_KEY`·`RST_KEY`·`OVSEA_AID_KEY`·`TOGETH_WTDRW_*`·`RETUN_*_KEY`·`OPER_KEY` 등)은 S-3 매핑표에서 1:1 포함하되 GOLD 비참조 시 보존 선택.

### 4-1. 표준 감사/메타 컬럼 (원칙 10, 전 테이블 공통)
`_SOURCE_SYSTEM`='CRM' · `_SOURCE_TABLE`('TM_PM_MBRFEE_ACMSLT'/'TM_PM_DNTN_DTLS', 행별 출처) · `_LOADED_AT` TIMESTAMP_NTZ · `_BATCH_ID`

---

## 5. GOLD 정합

- **FMM 납입 #69 `PAID_FEE`·#70 `PAID_AMT`** ← `SUM(PAY_AMT)` (월별 집계, GOLD). #70은 #69 중복 의심(GOLD DDL 주석) — **SILVER는 `PAY_AMT` 단일 보존**, 중복 단일화는 GOLD measure 정의 책임(GOLD 적재 트랙).
- **FMM 청구 #71 `BILLED_AMT`** ← `SUM(RQEST_AMT)` (회비 행만 비NULL; 기부 행은 청구 0/NULL).
- **FMM 회비유형 #66~68**(정기회비/정기회원 일시회비/일시회원 일시회비) ← GOLD에서 `PAYMENT_TYPE` + `MBRFEE_DIV_CD`(PM010) 조합으로 분기 집계. SILVER는 두 코드를 보존만.
  - #66 정기회비 = `PAYMENT_TYPE='MBRFEE'` + 정기 구분
  - #68 일시회원 일시회비 = `PAYMENT_TYPE='DNTN'`
  - #67 정기회원 일시회비 = `PAYMENT_TYPE='MBRFEE'` + 일시성 `MBRFEE_DIV_CD` (분기값 확정 OPEN-15)
- **납입 measure 필터**: GOLD 납입 measure는 `PAY_STAT_CD='S'`(성공)만 집계해야 정확(실패·NULL 제외). SILVER는 미필터 보존, 필터는 GOLD 적재 트랙.
- **DIM_PAYMENT**: `PAYMENT_METHOD`(#125)의 직접 소스는 `CRM_PAYMENT_METHOD`(엔티티⑤, `TM_PM_SETLE_INFO`)다 — **본 엔티티 아님**. 본 엔티티는 `ELCTR_SETLE_KEY`로 결제수단에 연결하고, `PAYMENT_TYPE`→`DIM_PAYMENT.FEE_TYPE`(회비유형 보류 컬럼)에 기여. FMM의 `PAYMENT_SK` 해소는 회원의 결제수단(SETLE_INFO) 경유(GOLD 적재 트랙).
- **MONTH_KEY**: FMM 조회년월(YYYYMM)은 `MBRFEE_MT`(청구/회비월) 또는 `PAY_DE` 기준 — 월 귀속 기준 확정은 GOLD 적재 트랙(OPEN-16).

---

## 6. OPEN 이슈 (S-1 → 다음 단계 차단/확인)

| ID | 이슈 | 영향 | 조치 |
|---|---|---|---|
| **OPEN-13** | 작업계획 §1-1(#4)·D3가 UNION ALL 구조·"기부금 청구 부재"를 명시 안 함 | 작업계획-설계 표현 불일치 | 본 §1로 해소. 작업계획 §1-1·D3 정정 + 신규 **R9** 등재(아래 정합 점검) |
| **OPEN-14** | `PAY_KEY` 유일성(`MBRFEE_KEY`/`DNTN_KEY` 단독 중복 + 타입 접두 후 충돌) 미검증 | PK 무결성 | BRONZE 실측(키 중복 카운트) |
| **OPEN-15** | `MBRFEE_DIV_CD`(PM010) 값별 의미 — #67 정기회원 일시회비 분기값 미확정 | FMM #66~68 분기 차단 | 코드마스터(PM010) 확인 → `CRM_CODE_MASTER`(#14) 후 |
| **OPEN-16** | 월 귀속 기준(`MBRFEE_MT` vs `RQEST_MT` vs `PAY_DE`) | FMM MONTH_KEY 산출 | GOLD 적재 트랙 결정(현업 합의) |
| **OPEN-19** | **청구↔납입 카디널리티** — `MBRFEE_SQNC`(회비차수)·`RQEST_SQNC`(청구차수) 존재 → 동일 회비건이 재청구·부분납입 시 다행으로 증식 가능. 단순 `SUM(PAY_AMT)`·`SUM(RQEST_AMT)` 시 **중복 합산** 위험 | FMM 납입(#69·70)·청구(#71) 금액 정합 | BRONZE 실측(`MBRFEE_KEY`당 행수·`SQNC` 분포). 증식 시 GOLD 집계에 최신차수/성공건 dedup 규칙 적용(적재 트랙) |
| **OPEN-17** | 인벤토리 컬럼 # 결번(MBRFEE #20~23·35 등, DNTN #4·7·8·12 등) — 51/25 컬럼과 표시 행수 불일치 | 전 컬럼 매핑 누락 위험 | S-3 전 BRONZE 전수 컬럼 확보(DESCRIBE) |
| **OPEN-18 (PII)** | `PAYER_NM`(결제자명)·계좌/빌키(`BILLKEY`·`ACNUT_SER_NO`)·금융기관 = 결제 민감정보 | 거버넌스/마스킹 | SILVER 원본 보존, 마스킹은 GOLD·SERVING 노출 시점. `data-governance` 연계 |
| **OPEN-5(공통)** | BRONZE 물리타입 미제공 | 캐스팅 잠정 | S-2 전 실제 타입 확인 |
| **OPEN-3(공통)** | 코드→라벨 병행(PM010·PM012·PM013·PM021·PM024·PM042·CM019·RM070·MM018·MM014) | 라벨 컬럼 | `CRM_CODE_MASTER`(#14)·`TM_PM_FNLT`(금융기관) 후 일괄 |

---

## 7. 다음

- **즉시 설계 가능**(두 원천 컬럼 정의 확보 — 회원/상태이력과 달리 차단 적음). 청구·납입 컬럼 모두 명시됨.
- **선결**: OPEN-13(작업계획 정정)·OPEN-14(키 유일성 실측)이 S-2 전 확인 대상. OPEN-15/16은 GOLD 적재 트랙 의존(SILVER DDL 비차단).
- **S-2**: 본 명세 → `CREATE TABLE GN_DW.SILVER.CRM_PAYMENT_BILLING` DDL(Snowflake 컴파일 검증, UNION ALL 컬럼셋 기준).
- **S-3**: `MBRFEE_ACMSLT`(51)·`DNTN_DTLS`(25) → SILVER 컬럼 1:1 매핑표(NULL 패딩 규칙 명시).
