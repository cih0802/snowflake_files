# S-1 엔티티 설계서 ① `CRM_MEMBER_MASTER`

> SILVER 정제 레이어 `GN_DW.SILVER.CRM_MEMBER_MASTER` 설계서.
> 입력: `BRONZE_CRM 테이블 정보.MD` / 상위: `SILVER_설계_작업 계획.md` §1-1(#1), §0 원칙 4·5·10·11, R3·R4.
> GOLD 수요처: `DIM_MEMBER`, `DIM_MEMBER_IDENTITY`(CRM측).

---

## 1. grain / PK

- **grain**: 1행 / 회원 1명 (정기회원 + 일시후원회원 **UNION ALL**).
- **자연키**: 정기 `MBER_NO`, 일시 `ONCE_MBER_NO`는 **서로 다른 번호 체계**(별도 채번). 두 체계 간 값 중복 여부는 **미검증** — 충돌 가능성을 배제할 수 없으므로 타입 접두 키로 방어한다(중복 실재 여부와 무관하게 안전).
- **PK (해소책, R3)**: `MEMBER_KEY` = `MEMBER_TYPE || '-' || SOURCE_MEMBER_NO`
  - `MEMBER_TYPE` ∈ {`FDRM`(정기), `ONCE`(일시)}
  - `SOURCE_MEMBER_NO` = 원천 회원번호(정기 `MBER_NO` / 일시 `ONCE_MBER_NO`)
  - PK 유일성 검증: `MEMBER_KEY` 중복 0건(§6-5).
- **중복 제거 규칙**: 각 원천은 1행/회원 전제이나 미검증 → 정제 시 `SOURCE_MEMBER_NO` 기준 중복 점검. 중복 발견 시 (a) `FRST_REGIST_DT` 최신 1행 채택 또는 (b) 적재 중단·경고 중 택일은 **OPEN-4**(원천 중복 실측 후 결정). 임의 dedup 금지.

---

## 2. 원천 매핑

| 원천 | 컬럼수 | 역할 | 비고 |
|---|---|---|---|
| `TM_MM_FDRM_MBER_INFO` | 41 | 정기회원 마스터 | `MEMBER_TYPE='FDRM'` |
| `TM_MM_ONCE_MBER_INFO` | 32 | 일시후원회원 마스터 | `MEMBER_TYPE='ONCE'` |
| `TM_MM_FDRM_MBER_IRSD` | 15 | 증감액(보류) | ⚠️ 작업계획 통합트리는 "+증감액"으로 master 입력에 포함하나, (1) 컬럼 2~15 정의 부재 + (2) 증감액이 발생일(`OCCRRNC_DE`)·감액여부(`RDCAMT_YN`) 기반 **이벤트 grain**으로 보여 "1행/회원" master와 충돌 소지 → §6 OPEN-1 |

> 구성: `FDRM 정제 SELECT` **UNION ALL** `ONCE 정제 SELECT`. 행 수 = 정기수 + 일시수(원칙 4, 행 축소 없음).
> IRSD(증감액)는 grain·컬럼 미확정으로 본 UNION에서 **제외**(OPEN-1). 작업계획의 "+증감액"은 정의 확보 후 재평가 — master 속성(1:1)이면 JOIN, 이벤트면 별도 엔티티(FMM 증감액 measure는 R7 약정 트랙에서 별도 처리).

---

## 3. UNION ALL 스키마 정합 규칙 (R3 해소)

두 원천의 컬럼을 **통합 표준 컬럼**으로 정렬한다. 한쪽에만 있으면 다른 쪽은 `NULL`.

### 3-1. 양쪽 공통 (직접 매핑)
`MBER_DIV_CD·CPR_DIV_CD·RRN_FSTDGT·RRN_LSTDGT_ENC·BRTHDY·SEX·MBER_KORNM·MBER_ENGNM·MBTLNUM·TSTM_DIV_CD·ETC_CTTPC·ETC_TSTM_DIV_CD·ZIP·ADDR·DTL_ADDR·EMAIL·FAXNO·HMPG_ID·CHRCTR_RECPTN_YN·SPECL_MNG_CD1·SPECL_MNG_CD2·TNI_CU_BL_NO·CTI_SYNCHRN_DIV_CD·FRST_REGIST_DT·REGIST_DEPT_CD·FRST_RGSTR_ID`

### 3-2. 의미는 같으나 형식이 다름 → 표준화 필요
| 표준 컬럼 | 정기(FDRM) | 일시(ONCE) | 규칙 |
|---|---|---|---|
| `POST_RECV_YN` | `PSTMTR_RECPTN_CD` (코드 MS027) | `PSTMTR_RECPTN_YN` (Y/N) | 코드→Y/N 매핑(OPEN-2). 원본코드는 `POST_RECV_CD`에 병행 보존 |
| `EMAIL_RECV_YN` | `EMAIL_RECPTN_CD` (코드 MS028) | `EMAIL_RECPTN_YN` (Y/N) | 동일(OPEN-2). 원본 `EMAIL_RECV_CD` 보존 |

### 3-3. 한쪽 전용 (없는 쪽은 NULL)
| 표준 컬럼 | 원천 | 보유 |
|---|---|---|
| `MEMBER_STAT_CD` (회원상태 MM010) | `MBER_STAT_CD` | FDRM만 (ONCE는 상태개념 없음 → NULL) |
| `RELATNSP_DIV_CD` (결연구분 MM019) | `RELATNSP_DIV_CD` | FDRM만 |
| `CMPGN_CD` (캠페인) | `CMPGN_CD` | FDRM만 |
| `ACT_DEPT_CD`·`JOIN_PATH_CD`·`STDR_DE`·`SLRCLD_LRR_CD`·`MOBLPHON_STAT_CD`·`EMAIL_STAT_CD`·`ETC_CTTPC_REL_CD`·`ETC_CTTPC_STAT_CD`·`BL_ENTRPS_NO` | 동명 | FDRM만 |
| `REL_CD` (관계 CM009)·`ENTRPS_NM`(업체명)·`FDRM_MBER_TRNSFER_FG`(정기이관) | 동명 | ONCE만 |

---

## 4. 컬럼 명세 (타입 · 정제규칙)

> 정제 표준은 §0 원칙 11 적용(NULL 표준화·TRIM·캐스팅). 코드 컬럼은 `*_CD` 원본 + `*_NM` 라벨 병행(원칙 5, OPEN-3).
> ⚠️ **타입 캐스팅은 잠정(provisional)**: `BRONZE_CRM 테이블 정보.MD`는 컬럼 인벤토리라 **원천 물리 데이터타입을 제공하지 않음**. 아래 SILVER 타입(DATE·NUMBER·TIMESTAMP)은 "원천이 문자열"이라는 추정에 기반 — S-2 DDL 확정 전 BRONZE 실제 타입(`DESCRIBE`/`INFORMATION_SCHEMA`) 확인 필요(OPEN-5).

| # | SILVER 컬럼 | 타입 | 원천 | 정제 규칙 |
|--:|---|---|---|---|
| 1 | `MEMBER_KEY` (PK) | VARCHAR | 파생 | `MEMBER_TYPE||'-'||SOURCE_MEMBER_NO` |
| 2 | `MEMBER_TYPE` | VARCHAR | 파생 | 'FDRM'/'ONCE' 리터럴 |
| 3 | `SOURCE_MEMBER_NO` | NUMBER | `MBER_NO`/`ONCE_MBER_NO` | 정수 캐스팅 |
| 4 | `MEMBER_DIV_CD` | VARCHAR | `MBER_DIV_CD` | 코드(MM018) TRIM |
| 5 | `CORP_DIV_CD` | VARCHAR | `CPR_DIV_CD` | 코드(CM019) |
| 6 | `RRN_FIRST` | VARCHAR | `RRN_FSTDGT` | 앞 6자리, 무효→NULL |
| 7 | `RRN_LAST_ENC` | VARCHAR | `RRN_LSTDGT_ENC` | 암호화 원본 보존(복호화 금지) |
| 8 | `BIRTH_DE` | DATE | `BRTHDY` | YYYYMMDD→DATE, 무효('00000000' 등)→NULL |
| 9 | `SEX_RAW` | VARCHAR | `SEX` | ⚠️ 성별 단독 신뢰 불가(6/7/8=단체/기업/기타). 원본만 보존, GENDER 파생 금지 |
| 10 | `MEMBER_KOR_NM` | VARCHAR | `MBER_KORNM` | TRIM |
| 11 | `MEMBER_ENG_NM` | VARCHAR | `MBER_ENGNM` | TRIM |
| 12 | `MOBILE_NO` | VARCHAR | `MBTLNUM` | 숫자/하이픈 정규화, 공백→NULL |
| 13 | `EMAIL` | VARCHAR | `EMAIL` | LOWER·TRIM, 빈값→NULL |
| 14 | `ZIP` | VARCHAR | `ZIP` | TRIM |
| 15 | `ADDR` | VARCHAR | `ADDR` | TRIM |
| 16 | `ADDR_DTL` | VARCHAR | `DTL_ADDR` | TRIM |
| 17 | `FAX_NO` | VARCHAR | `FAXNO` | 정규화 |
| 18 | `HOMEPAGE_ID` | VARCHAR | `HMPG_ID` | TRIM — **신원매핑 후보(R4/S-7)** |
| 19 | `POST_RECV_YN` | VARCHAR(1) | §3-2 | Y/N 표준화 |
| 20 | `POST_RECV_CD` | VARCHAR | `PSTMTR_RECPTN_CD` | FDRM 원본코드(ONCE는 NULL) |
| 21 | `EMAIL_RECV_YN` | VARCHAR(1) | §3-2 | Y/N 표준화 |
| 22 | `EMAIL_RECV_CD` | VARCHAR | `EMAIL_RECPTN_CD` | FDRM 원본코드 |
| 23 | `SMS_RECV_YN` | VARCHAR(1) | `CHRCTR_RECPTN_YN` | Y/N, 빈값·NULL→NULL |
| 24 | `MEMBER_STAT_CD` | VARCHAR | `MBER_STAT_CD` | MM010, ONCE→NULL |
| 25 | `RELATION_DIV_CD` | VARCHAR | `RELATNSP_DIV_CD` | MM019, ONCE→NULL |
| 26 | `CAMPAIGN_CD` | VARCHAR | `CMPGN_CD` | ONCE→NULL (DIM_CAMPAIGN FK) |
| 27 | `JOIN_PATH_CD` | VARCHAR | `JOIN_PATH_CD` | MM014, ONCE→NULL |
| 28 | `FIRST_REGIST_DT` | TIMESTAMP_NTZ | `FRST_REGIST_DT` | 캐스팅 |
| 29 | `REGIST_DEPT_CD` | VARCHAR | `REGIST_DEPT_CD` | 부서참조 |
| 30 | `FIRST_RGSTR_ID` | VARCHAR | `FRST_RGSTR_ID` | TRIM |

> 위는 GOLD `DIM_MEMBER`/`DIM_MEMBER_IDENTITY`가 요구하는 **핵심 컬럼**. 잔여 전용컬럼(SLRCLD_LRR_CD·각종 상태코드·REL_CD·ENTRPS_NM·FDRM_MBER_TRNSFER_FG 등)은 S-3 매핑표에서 1:1 포함하되, GOLD 비참조 시 보존 선택.

### 4-1. 표준 감사/메타 컬럼 (원칙 10, 전 테이블 공통)
`_SOURCE_SYSTEM`='CRM' · `_SOURCE_TABLE`(원천 테이블명) · `_LOADED_AT` TIMESTAMP_NTZ · `_BATCH_ID`

---

## 5. GOLD 정합

- `DIM_MEMBER` ← 회원 속성(상태·성별*·지역·신규기존). SCD2 가능 속성은 **MEMBER_STAT만**(원칙 6, R6) — 상태이력은 `CRM_MEMBER_STATUS_HIST`(별도 엔티티)에서.
- `DIM_MEMBER_IDENTITY`(CRM측) ← `SOURCE_MEMBER_NO`(MEMBER_NO 역할) + `HOMEPAGE_ID`. `MEMNUM`은 회원번호(=member id)와 동일 지표이므로 회원번호로 충족. GA측(GA_MEMBER_ID)은 S-7에서 결합.

---

## 6. OPEN 이슈 (S-1 → 다음 단계 차단/확인)

| ID | 이슈 | 영향 | 조치 |
|---|---|---|---|
| **OPEN-1** | `TM_MM_FDRM_MBER_IRSD`(15) 컬럼 2~15 정의 부재 + 증감액 grain 미확정. 작업계획 통합트리는 master "+증감액" 입력으로 표기 | master 결합 방식 미정(1:1 속성 JOIN vs 별도 이벤트 엔티티) | 입고팀/정의서 보강 요청. 확보 전 IRSD 제외하고 2원천(FDRM+ONCE)만으로 master 구성. 정의 확보 후 grain 판정 → 이벤트면 FMM(R7 약정 트랙)으로 이관 |
| **OPEN-2** | 수신동의 코드(MS027/MS028) → Y/N 매핑값 미정 | `POST_RECV_YN`/`EMAIL_RECV_YN` 표준화 차단 | `TM_CM_CODE`(MM/MS 코드마스터)에서 코드값 의미 확인 |
| **OPEN-3** | 코드→라벨(`*_NM`) 병행 보존(원칙 5)의 코드마스터 조인 | 라벨 컬럼 생성 | `CRM_CODE_MASTER`(#14) 엔티티와 조인 규칙 — 해당 엔티티 설계 후 일괄 |
| **OPEN-4** | 원천 1행/회원 전제 미검증 (중복 가능성) | dedup 규칙 확정 차단 | BRONZE에서 `SOURCE_MEMBER_NO` 중복 실측 → §1 dedup (a)/(b) 결정 |
| **OPEN-5** | BRONZE 원천 물리 데이터타입 미제공 | SILVER 타입·캐스팅 잠정 | S-2 전 `INFORMATION_SCHEMA.COLUMNS`로 실제 타입 확인 후 확정 |
| **OPEN-6 (PII)** | 민감정보 컬럼 — 주민번호(`RRN_FIRST`/`RRN_LAST_ENC`)·휴대폰·이메일·주소 | 거버넌스/마스킹 정책 필요 | SILVER는 **원본 보존(복호화·평문화 금지)**, 마스킹/접근제어는 GOLD·SERVING 노출 시점에 적용. `data-governance` 트랙과 마스킹 정책 연계 검토 |
| ~~**R4(상위)**~~ | ✅ **해소** — `MEMNUM`(#111)은 `member id`와 동일한 `회원번호`(문자, URL 용어), 별도 컬럼 아님 | — | DIM_MEMBER_IDENTITY는 회원번호로 충족 |
| **R3(해소)** | UNION ALL 스키마 불일치 | — | 본 문서 §3으로 **해소(MEMBER_KEY + NULL 정렬 + 수신동의 표준화)** |

---

## 7. 다음

- **S-2**: 본 명세 → `CREATE TABLE GN_DW.SILVER.CRM_MEMBER_MASTER` DDL (Snowflake 컴파일 검증).
- **S-3**: BRONZE 41+32 컬럼 → SILVER 컬럼 1:1 매핑표(전 컬럼).
- 선행 권장: OPEN-1(IRSD)·OPEN-2(수신코드) 입고팀 질의 / OPEN-4(중복)·OPEN-5(타입) BRONZE 실측 / OPEN-6(PII) 거버넌스 연계. (R4 memnum은 해소 — member id=회원번호)
