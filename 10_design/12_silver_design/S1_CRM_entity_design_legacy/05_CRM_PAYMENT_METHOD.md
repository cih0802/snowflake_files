# S-1 엔티티 설계서 ⑤ `CRM_PAYMENT_METHOD`

> SILVER 정제 레이어 `GN_DW.SILVER.CRM_PAYMENT_METHOD` 설계서.
> 입력: `BRONZE_CRM 테이블 정보.MD` + **`컬럼정의서 20260622.csv`(권위 원천)** / 상위: `SILVER_설계_작업 계획.md` §1-1(#5), §0 원칙 4·5·10·11.
> GOLD 수요처: `DIM_PAYMENT`(납입방식 #125). 간접: `FMM`(PAYMENT_SK 해소 = 회원 결제수단 경유, ④ §5).
> 원천: `TM_PM_SETLE_INFO`(51, 현재값) + `TH_PM_SETLE_INFO_HIST`(49, 변경이력) — **전 컬럼 정의됨 ✅ (OPEN-20/21 해소)**.

---

## 1. 핵심 — grain 불일치 + 키/이력 해소

본 엔티티는 **회원별 결제수단 인스턴스**이고 GOLD `DIM_PAYMENT`는 **납입방식 lookup**(SCD1) — grain 상이. SILVER는 회원별 raw 보존, GOLD가 `DISTINCT 납입방식`으로 축약(원칙 4).

- **OPEN-20 해소**: PK = **`SETLE_KEY`**(정의서 확정). 결번이던 `SETLE_CD`(결제코드)·`SETLE_ENTRPS_CD`(결제업체)·`SETLE_STAT_CD`(결제상태) 확보.
- **OPEN-21 해소**: `TH_PM_SETLE_INFO_HIST`(49) 완전 정의 — `SETLE_KEY`+`UPDT_DT`+ SETLE_INFO 스냅샷 + `BF_SETLE_STAT_CD`(이전 상태). 변경이력 설계 가능. **단 DIM_PAYMENT SCD1이라 현재 GOLD 비요구**(우선순위 낮음, §4).
- **DIM_PAYMENT.납입방식(#125) 직접 소스**: 본 엔티티 파생 분류값. 회비유형(#66~68)은 ④(납입이력).

---

## 2. grain / PK

- **grain**: 1행 / 결제수단(회원별 settlement). 회원 복수 결제수단·재등록 시 다행(OPEN-25 실측).
- **PK**: `SETTLE_KEY` = `SETLE_KEY`(정의서 확정 PK).
  - ⚠️ ④ `CRM_PAYMENT_BILLING`의 조인 컬럼명(`ELCTR_SETLE_KEY`)이 본 `SETLE_KEY`와 동일 키인지 확인(OPEN-20b).
- **회원 FK**: `MEMBER_KEY` = `'FDRM-' || MBER_NO` → ①. 회원범위(FDRM/ONCE) OPEN-24.
- **변경 추적**: `BF_SETLE_KEY`(이전결제KEY) 보유. 이력은 §4(HIST).

---

## 3. 컬럼 명세 — 현재값 (`TM_PM_SETLE_INFO` 51)

> 정제 표준 §0 원칙 11. ⚠️ **PII 정책 OPEN-23**(일부 제외/마스킹).

| # | SILVER 컬럼 | 타입 | 원천 | 정제 규칙 |
|--:|---|---|---|---|
| 1 | `SETTLE_KEY` (PK) | VARCHAR | `SETLE_KEY` | 결제키 |
| 2 | `MEMBER_KEY` (FK) | VARCHAR | 파생 | `'FDRM-'||MBER_NO`. OPEN-24 |
| 3 | `SOURCE_MEMBER_NO` | VARCHAR | `MBER_NO` | 회원번호 |
| 4 | `CORP_DIV_CD` | VARCHAR | `CPR_DIV_CD`(CM019) | 법인구분 |
| 5 | `PAYMENT_METHOD_CD` (파생) | VARCHAR | `SETLE_CD`+`CRTFC_TY_CD`+`CARD_DIV_CD`+`FNLT_DIV_CD` | **납입방식 분류** → DIM_PAYMENT #125. 규칙 OPEN-22 |
| 6 | `SETTLE_CD` | VARCHAR | `SETLE_CD` | 결제코드(납입방식 후보) |
| 7 | `SETTLE_STATUS_CD` | VARCHAR | `SETLE_STAT_CD` | 결제수단 상태 |
| 8 | `SETTLE_ENTRPS_CD` | VARCHAR | `SETLE_ENTRPS_CD` | 결제업체 |
| 9 | `SETTLE_TYPE_CD` | VARCHAR | `CRTFC_TY_CD` | 인증유형(0계좌/2휴대폰/3카드) |
| 10 | `CARD_DIV_CD` | VARCHAR | `CARD_DIV_CD`(PM052) | 카드구분 |
| 11 | `FNLT_DIV_CD` | VARCHAR | `FNLT_DIV_CD`(PM050) | 금융기관구분 |
| 12 | `FNLT_CD` | VARCHAR | `FNLT_CD` | 금융기관(→`TM_PM_FNLT` 라벨) |
| 13 | `CRTFC_MTH_CD` | VARCHAR | `CRTFC_MTH_CD`(MM014) | 인증방법 |
| 14 | `WTDRW_STRT_DE` | DATE | `WTDRW_STRT_DE` | 출금시작일 |
| 15 | `WTDRW_ASMT_SQNC` | NUMBER | `WTDRW_ASMT_SQNC` | 출금지정차수 |
| 16 | `FIRST_BEGIN_DE` | DATE | `FRST_BEGIN_DE` | 최초개시일 |
| 17 | `RQST_DIV_CD` | VARCHAR | `RQST_DIV_CD`(PM004) | 신청구분 |
| 18 | `RCEPT_DIV_CD` | VARCHAR | `RCEPT_DIV_CD`(PM003) | 접수구분 |
| 19 | `APRV_YN` | VARCHAR(1) | `APRV_YN` | 승인여부 |
| 20 | `RQEST_EXCL_YN` | VARCHAR(1) | `RQEST_EXCL_YN` | 청구제외여부 |
| 21 | `RQEST_EXCL_STRT_DE` | DATE | `RQEST_EXCL_STRT_DE` | 청구제외시작 |
| 22 | `RQEST_EXCL_END_DE` | DATE | `RQEST_EXCL_END_DE` | 청구제외종료 |
| 23 | `OPER_DIV_CD` | VARCHAR | `OPERT_DIV_CD` | 작업구분(홈페이지/CRM/글로벌에듀) |
| 24 | `BF_SETTLE_KEY` | NUMBER | `BF_SETLE_KEY`(FLOAT) | 이전결제KEY |
| 25 | `BILLKEY` | VARCHAR | `BILLKEY` | 빌키 ⚠️PII |
| 26 | `USE_YN` | VARCHAR(1) | `USE_YN` | 사용여부(필터 금지) |
| 27 | `FIRST_REGIST_DT` | TIMESTAMP_NTZ | `FRST_REGIST_DT` | 최초등록일시 |
| 28 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | `LAST_UPDT_DT` | 최종수정일시 |

### 3-1. 표준 감사/메타 컬럼 (원칙 10)
`_SOURCE_SYSTEM`='CRM' · `_SOURCE_TABLE`('TM_PM_SETLE_INFO') · `_LOADED_AT` · `_BATCH_ID`

> **SILVER 미적재(고민감/비분석, OPEN-23)**: `CRTFC_DATA_CTNT`·`CRTFC_FILE_NM`·`FILE_SIZE`(인증파일) · `PAYER_NM`·`APPLCNT_*`(신청자 PII) · `ACNUT_SER_NO`(계좌)·`CARD_TRMVT`(카드유효기간)·`MBTLNUM`/`ETC_CTTPC`(연락처). **주민/카드비밀번호류는 정의서에도 미적재**(BRONZE 단계 제외 추정 — 정의서에 RRN/PWD 컬럼 없음). 거버넌스 합의.

---

## 4. 변경이력 (`TH_PM_SETLE_INFO_HIST` 49) — 정의됨, GOLD 비요구

`TH_PM_SETLE_INFO_HIST`(49) = `SETLE_KEY`+`UPDT_DT`+`UPDUSR_ID/NM`+ SETLE_INFO 스냅샷 + **`BF_SETLE_STAT_CD`(이전 결제상태)**. 결제수단 변경(계좌→카드, 상태전이) 타임라인 제공.

- **grain**: 1행 / `SETLE_KEY` × `UPDT_DT`(변경 이벤트). 별도 테이블 `CRM_PAYMENT_METHOD_HIST` 또는 본 엔티티 SCD2 확장으로 적재 가능.
- **그러나 DIM_PAYMENT SCD1**(현재값) → 변경 타임라인 요구 GOLD 소비자 없음 → **현 시점 적재 보류(비차단)**. 향후 결제수단 변경 분석 요구 시 활성화.

---

## 5. GOLD 정합

- **DIM_PAYMENT.납입방식(#125)** ← `SELECT DISTINCT PAYMENT_METHOD_CD/_NM`(§3-#5). SILVER 회원별 raw → GOLD lookup 축약. 분류 규칙 OPEN-22(`SETLE_CD`/`CRTFC_TY_CD`/카드·금융구분).
- **회비유형(#66~68)**: ④에서. DIM_PAYMENT = ⑤(납입방식)+④(회비유형) 공동 기여.
- **FMM PAYMENT_SK 경로**: ④ `ELCTR_SETLE_KEY` → ⑤ `SETTLE_KEY` → `PAYMENT_METHOD_CD` → `DIM_PAYMENT.PAYMENT_SK`. 키 동일성 OPEN-20b.

---

## 6. OPEN 이슈

| ID | 이슈 | 영향 | 조치 |
|---|---|---|---|
| ~~OPEN-20~~ | ~~결제키·결번 컬럼~~ | — | **✅ 해소 — `SETLE_KEY`(PK)·`SETLE_CD`·`SETLE_ENTRPS_CD`·`SETLE_STAT_CD`** |
| ~~OPEN-21~~ | ~~HIST 컬럼 미정의~~ | — | **✅ 해소 — HIST 49컬럼(BF_SETLE_STAT_CD 포함). 단 GOLD 비요구(§4)** |
| **OPEN-20b** | ④ `ELCTR_SETLE_KEY` ↔ 본 `SETLE_KEY` 동일 키 여부 | FMM 조인 | BRONZE 실측(두 컬럼 매핑) |
| **OPEN-22** | 납입방식 분류 — `SETLE_CD`/`CRTFC_TY_CD`/`CARD_DIV_CD`/`FNLT_DIV_CD` → CMS/카드/지로 매핑 | DIM_PAYMENT #125 직접 차단 | 코드값 의미 + 현업 분류 합의 |
| **OPEN-23 (PII)** | 빌키·계좌·연락처·신청자 PII | 거버넌스 | 위 미적재 정책 확정. `data-governance` 연계 |
| **OPEN-24** | 회원범위(FDRM/ONCE) → MEMBER_KEY 접두 | FK 정합 | BRONZE 실측 |
| **OPEN-25** | grain — 회원당 다결제수단/재등록 누적 | PK·dedup | BRONZE 실측 |
| **OPEN-3(공통)** | 라벨(CM019·PM050·PM052·PM004·PM003·MM014) | 라벨 | ⑭ 후 |

---

## 7. 다음

- **현재값(§3) 즉시 완전 설계** — OPEN-20/21 해소. 변경이력(§4)은 GOLD 요구 시 활성화.
- **선결**: OPEN-22(납입방식 분류 — DIM_PAYMENT 직접) · OPEN-20b(④ 조인키) · OPEN-25(dedup).
- **S-2**: `CREATE TABLE CRM_PAYMENT_METHOD` DDL(현재값). HIST는 별도/보류.
- **S-3**: `TM_PM_SETLE_INFO`(51) → SILVER 매핑(PII 제외 표기).
