# BRONZE CRM 원천 테이블 인벤토리 (데이터 딕셔너리)
> 입고팀이 회신한 CRM 원천 테이블/컬럼 정의서. SILVER 정제·GOLD 매핑의 소스 of truth.
> 원본은 탭 구분(TSV) 평면 표였으며, LLM 파싱이 쉽도록 테이블별 구조화 표로 재구성함. **데이터 무손실**: 41개 테이블 / 876개 컬럼 (테이블 인덱스·상세 헤더 합계 기준. 2026-06 현업 +1테이블·+13컬럼 반영).
> **물리 데이터타입 정본 = `09_bronze_crm_ddl.sql`** (2026-06-29 DDL 수령). 본 MD는 한글 설명·코드그룹 중심, 타입은 DDL 참조.

---

## 작업 로그 / 미완 항목 (TODO)

### 2026-06-29 BRONZE_CRM 물리 DDL 수령 (SnowSQL `create or replace`)
- **BRONZE 스키마 확정**: `BRONZE_CRM` (`with managed access`, COMMENT='원천 데이터 적재 - CRM'). **BRONZE 테이블명 = 원천 테이블명 그대로 미러링** 확인.
- **적재 메타 컬럼 전 테이블 공통**: `_LOAD_DT TIMESTAMP_NTZ(9)` · `_BATCH_ID VARCHAR(50)` (본 인벤토리 컬럼수에는 미포함 — 적재 메타).
- **물리 데이터타입 확보(OPEN-5 해소)**: 전 컬럼 타입은 **`09_bronze_crm_ddl.sql`(타입 정본)** 에 보관. 본 MD는 3개 차단 테이블만 타입 인라인, **나머지 38테이블 타입은 백필하지 않고 DDL 파일을 참조**(중복·전사오류 방지).
- **⛔ 차단 3건 해소**:
  - `TH_MM_FDRM_MBER_STNG_DTLS` COL2~6 → `MBER_NO·SER_NO·BF_STAT_CD·CHN_STAT_CD·FRST_RGSTR_ID·FRST_REGIST_DT` (변경 전/후 회원상태 + 시점). **FMM 시점지표 #49·50·52·53 산출 가능.**
  - `TM_CM_SPNSR_BSNS_INFO` → `SPNSR_BSNS_NM`(후원사업명)·`SPNSR_BSNS_ABRV_CD`(약칭) 등 13컬럼 확정. **DIM_SPONSORSHIP 가능.**
  - `TM_MM_FDRM_MBER_IRSD` → 증감 15컬럼 + `RDCAMT_YN`(감액여부) 확정.
- **잔여**: `EHGT`(VARCHAR(30)) 의미 여전히 미상 · BF/CHN_STAT_CD 코드그룹(MM010) 현업 확인 · 나머지 38테이블 타입 백필은 선택.

### 2026-06-29 컬럼정의서/테이블정의 정본 2종 CSV 수령 (`../컬럼정의서_20260629.csv`·`../테이블정의_20260629.csv`)
- **컬럼정의서(907행)**: 전 테이블 컬럼×(타입·NULL·코드여부·**코드그룹ID**·한글설명·비고) 갱신 정본. DDL(`09_bronze_crm_ddl.sql`)의 타입과 함께 **코드그룹·설명의 정본**.
- **테이블정의(41행)**: **증분적재 업데이트 컬럼**·우선순위(상/중)·테이블설명·컬럼수/코드컬럼수. → 기존 "증분 메타 미반영"(하단 ※) **해소** — SILVER 적재 설계 입력.
- **C-6 해소**: `TM_CM_CMPGN_MNG` **32컬럼 버전** 확정 — `CMPGN_CTGR_CD`(29, MM294, 캠페인 카테고리)=#17 캠페인유형, `CMPGN_TYPE1_BSN`(30,MM295)=국내해외#15, `CMPGN_TYPE2_BSN`(31,MM296)=사업사례#16. 코드그룹 추가: SPNSR_DIV_CD=CM035·CPR_DIV_CD=CM019·CMPGN_TRGET_CD=CM002·PR_MTH_CD=CM008.
- ⚠️ **DDL ↔ 컬럼정의서 불일치(검수 필요, 정본 우선순위 결정)**:
  - **컬럼 집합 차이**: 예 `TD_MS_EMAIL_SNDNG_DTLS` — 컬럼정의서엔 `EMAIL`·`CHN_PARM_CTNT` 존재, DDL엔 없음(BRONZE 미적재? PII 제외?). DDL엔 `_LOAD_DT`/`_BATCH_ID` 적재메타 존재, 컬럼정의서엔 없음.
  - **타입 차이**: 예 `TD_MS_EMAIL_LQY_SNDNG.FAILR_CNT`·`RECPTN_CNT` = 컬럼정의서 `FLOAT` vs DDL `NUMBER(10,0)`.
  - **원칙(잠정)**: 물리타입·실제 적재 컬럼 = **DDL 정본**, 코드그룹·한글설명·소스 컬럼 완전성 = **컬럼정의서 정본**. 컬럼 집합 불일치(EMAIL 등)는 입고팀 확인 후 확정.

### 2026-06-26 현업 CRM 개발서버 추가분 반영 ((공통)브랜드 및 상위캠페인_26.02활동기준 > 'CRM코드정리' 시트)
- **`TM_CM_CMPGN_MNG` 컬럼 5개 추가 (27→32)**: `MBER_INFLOW_PATH_CD`(개발인입경로)·`CMPGN_CTGR_CD`(캠페인 카테고리)·`CMPGN_TYPE1_BSN`(캠페인유형 국내/해외)·`CMPGN_TYPE2_BSN`(캠페인유형 사업/사례)·`MKTG_CMPGN_NM`(마케팅캠페인명). 모두 코드 값(숫자)으로 적재.
  - 앞 4개는 공통코드 `TC_CMMN_DTL_CD`에 코드값 정의 — `CD_ID`는 순서대로 **MM293 / MM294 / MM295 / MM296**. 다른 코드와 동일하게 `CD_ID`+`DTL_CD_ID` 조건으로 조인.
  - `MKTG_CMPGN_NM`은 신규 테이블 `TM_CM_MKTNG_CMPGN_MNG`(코드 `MK_CMPGN_CD`, 코드명 `MK_CMPGN_NM`) 참조. `MK_CMPGN_CD` 조건으로 조인.
- **신규 테이블 `TM_CM_MKTNG_CMPGN_MNG`(8) 추가** — 마케팅캠페인명 마스터. → 인벤토리 40→41개 테이블.
- **영향**: 본 추가분은 SILVER ⑥ `CRM_CAMPAIGN_MASTER` 설계서의 **OPEN-26**(DIM_CAMPAIGN 캠페인유형#17·국내해외구분#15·사업사례구분#16 원천 미상)을 해소. 국내해외#15←`CMPGN_TYPE1_BSN`, 사업사례#16←`CMPGN_TYPE2_BSN` 확정. 캠페인유형#17 원천은 현업 최종확인 대기(후보 `CMPGN_CTGR_CD`).
- **검수 요청**: MM293~296 / `MK_CMPGN_CD` 코드값 상세 정의서 별도 수령 필요(현재 컬럼 정의만 반영, 코드값 라벨 미반영).

### 이번 작업에서 한 것
- **설명-한글명 공란 컬럼 보강 (LLM 생성)**: 입고팀 정의서에 설명이 비어 있던 8개 테이블 **약 261개 컬럼**에 한글 설명을 채움.
  - 대상 테이블: `SND_MEMBER_LIST`(96) · `SND_REQ_MST`(56) · `TM_MS_CRMN`(31) · `TD_MS_CRMN_PRTCPNT`(19) · `TM_RM_RELATNSP_GFTMNEY_INFO`(19) · `TD_MS_EVENT_PRTCPNT_DTL`(15) · `TM_RM_RELATNSP_LETTER_INFO`(14) · `TM_MS_EVENT`(11).
  - **생성 규칙**: ① 다른 테이블에 동일 컬럼명이 정의돼 있으면 그 설명을 그대로 복사(예 `MBER_NO`→회원번호, `RELATNSP_KEY`→결연KEY). ② 없으면 영어 컬럼명 형태소 + 소속 테이블 의미로 생성(`_CD`→코드, `_NM`→명, `_DE`→일, `_DT`→일시, `_YN`→여부, `_CO`→수, `_AMT`→금액 등).
  - **표시**: 이 작업으로 채운 모든 설명 옆에 `(LLM생성)` 태그를 붙임. 태그 없는 설명은 입고팀 원본.

### 마무리(검수)에 필요한 것 — 입고팀/현업 확인 요청
1. **`(LLM생성)` 설명 검수·확정**: 추정 기반이므로 업무 용어와 일치하는지 검토 후 태그 제거(확정) 필요. 특히 유사명을 복사한 항목(`CHILD_KOR_NM`≈`CHILD_KORNM`, `SPNSR_AMOUNT`≈`SPNSR_AMT`, `FAX`≈`FAXNO`)은 의미 동일 여부 확인.
2. ~~**생성 불가로 비워둔 컬럼 정의**~~: ✅ **부분 해소 (2026-06-29 DDL)**
   - ~~`TH_MM_FDRM_MBER_STNG_DTLS`의 `COL2`~`COL6`~~ → DDL로 확정(BF_STAT_CD·CHN_STAT_CD 등). **시점지표 차단 해소.**
   - `TM_RM_RELATNSP_GFTMNEY_INFO`의 `EHGT` (해독 불가 약어) — **여전히 미상**(타입 VARCHAR(30)만 확인).
3. ~~**물리 데이터타입 미제공(OPEN-5)**~~: ✅ **DDL로 수령** — 타입 정본 `09_bronze_crm_ddl.sql`. 3개 차단 테이블만 본 MD 인라인, 나머지 38테이블은 **DDL 파일 참조**(백필 안 함).
4. **컬럼 결번 검증(OPEN-17)**: 일부 테이블의 `#` 결번(예 MBRFEE #20~23·35, DNTN #4·7·8·12)이 삭제 컬럼인지 누락인지 전수 확인.
5. ~~**`memnum` 원천 미확인(R4)**~~: ✅ **해소** — `memnum`은 별도 컬럼이 아니라 `member id`와 동일한 `회원번호`(문자) 지표이며 URL 등에서 쓰는 용어(예 `?memnum=1831636`). `DIM_MEMBER_IDENTITY.MEMNUM`은 회원번호 컬럼을 그대로 사용 → 신원매핑 차단 아님.

> ※ 별도 수령한 **증분적재 메타(테이블별 PK 후보·업데이트 컬럼·갱신패턴(append-only/update)·우선순위)** 는 본 인벤토리에 미반영 — SILVER 적재 설계 시 작업계획(`04_silver_design/SILVER_설계_작업계획.md`)에 반영 예정.

---

## 범례 (Legend)
- **원본 컬럼**: `TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION, 코드여부, 코드그룹ID, 컬럼설명(한글), 비고`
- **#** = ORDINAL_POSITION (원본 물리 컬럼 순서). 번호 결번은 원본 그대로(삭제 컬럼 등).
- **코드여부**: `Y` = 공통코드 컬럼(코드그룹ID의 코드값 사용) / `N` = 비코드 / 공란 = 정의서 미기재.
- **코드그룹/참조**: 원본 `코드그룹ID`. 공통코드 그룹ID(예 `MM015`)는 `TC_CMMN_DTL_CD.CD_ID`에 코드값 정의. 일부는 참조 테이블명(예 `TM_CM_DEPT_INFO`) 또는 `하드코딩됨` 표기.
- **비고**: 원문 그대로. 포함 유형 — 값 매핑(예 `1=정기후원;2=일시후원`), FK 조인 힌트(형식 `참조테이블 - 키컬럼 - 명컬럼`), `PK`, 데이터 특이사항.
- **공통코드 마스터**: `TC_CMMN_CD`(코드 그룹) / `TC_CMMN_DTL_CD`(그룹별 상세 코드값).

## 테이블 인덱스 (41개)
| # | 테이블 | 컬럼수 | 접두사 |
|---|--------|:--:|:--:|
| 1 | `SND_MEMBER_LIST` | 96 | SND_ |
| 2 | `SND_REQ_MST` | 56 | SND_ |
| 3 | `TC_CMMN_CD` | 10 | TC_ |
| 4 | `TC_CMMN_DTL_CD` | 15 | TC_ |
| 5 | `TD_MS_CRMN_PRTCPNT` | 19 | TD_MS_ |
| 6 | `TD_MS_EMAIL_LQY_SNDNG` | 24 | TD_MS_ |
| 7 | `TD_MS_EMAIL_SNDNG_DTLS` | 12 | TD_MS_ |
| 8 | `TD_MS_EVENT_PRTCPNT_DTL` | 15 | TD_MS_ |
| 9 | `TD_MS_MSG_AT_LQY_SNDNG` | 18 | TD_MS_ |
| 10 | `TD_MS_MSG_AT_SNDNG_DTLS` | 17 | TD_MS_ |
| 11 | `TD_MS_PSTMTR_LQY_SNDNG` | 9 | TD_MS_ |
| 12 | `TD_MS_PSTMTR_SNDNG_DTL` | 15 | TD_MS_ |
| 13 | `TH_MM_FDRM_MBER_STNG_DTLS` | 6 | TH_ |
| 14 | `TH_PM_SETLE_INFO_HIST` | 53 | TH_ |
| 15 | `TM_CM_BRND_MNG` | 9 | TM_CM_ |
| 16 | `TM_CM_CMPGN_MNG` | 32 | TM_CM_ |
| 17 | `TM_CM_DEPT_INFO` | 12 | TM_CM_ |
| 18 | `TM_CM_MBER_DVLP_GOAL` | 9 | TM_CM_ |
| 19 | `TM_CM_SPNSR_BSNS_INFO` | 13 | TM_CM_ |
| 20 | `TM_MM_FDRM_MBER_DVLP_AMT` | 20 | TM_MM_ |
| 21 | `TM_MM_FDRM_MBER_INFO` | 41 | TM_MM_ |
| 22 | `TM_MM_FDRM_MBER_IRSD` | 15 | TM_MM_ |
| 23 | `TM_MM_FDRM_MBER_RE_SPNSR` | 5 | TM_MM_ |
| 24 | `TM_MM_FDRM_MBER_SPNSR_BSNS` | 7 | TM_MM_ |
| 25 | `TM_MM_FDRM_MBER_SPNSR_DSCNTC` | 7 | TM_MM_ |
| 26 | `TM_MM_ONCE_MBER_INFO` | 32 | TM_MM_ |
| 27 | `TM_MS_CRMN` | 31 | TM_MS_ |
| 28 | `TM_MS_EMAIL_SNDNG` | 15 | TM_MS_ |
| 29 | `TM_MS_EVENT` | 11 | TM_MS_ |
| 30 | `TM_MS_MSG_AT_SNDNG` | 21 | TM_MS_ |
| 31 | `TM_MS_PSTMTR_SNDNG` | 14 | TM_MS_ |
| 32 | `TM_PM_DNTN_DTLS` | 25 | TM_PM_ |
| 33 | `TM_PM_MBRFEE_ACMSLT` | 51 | TM_PM_ |
| 34 | `TM_PM_SETLE_INFO` | 48 | TM_PM_ |
| 35 | `TM_RM_BPLC_MNG` | 18 | TM_RM_ |
| 36 | `TM_RM_CHILD_MSTR_INFO` | 16 | TM_RM_ |
| 37 | `TM_RM_RELATNSP_CHG_INFO` | 7 | TM_RM_ |
| 38 | `TM_RM_RELATNSP_GFTMNEY_INFO` | 19 | TM_RM_ |
| 39 | `TM_RM_RELATNSP_LETTER_INFO` | 14 | TM_RM_ |
| 40 | `TM_RM_RELATNSP_MSTR_INFO` | 11 | TM_RM_ |
| 41 | `TM_CM_MKTNG_CMPGN_MNG` | 8 | TM_CM_ |

## 테이블 상세

### SND_MEMBER_LIST  (96 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `REQ_SEQ_NO` |  |  | 요청일련번호(LLM생성) |  |
| 2 | `R_NUM` |  |  | 행번호(LLM생성) |  |
| 3 | `MBER_NO` |  |  | 회원번호(LLM생성) |  |
| 4 | `MBER_KORNM` |  |  | 회원한글명(LLM생성) |  |
| 5 | `MBTLNUM` |  |  | 휴대폰번호(LLM생성) |  |
| 6 | `EMAIL` |  |  | 이메일(LLM생성) |  |
| 7 | `SPNSR_CD` |  |  | 후원코드(LLM생성) |  |
| 8 | `SPNSR_NM` |  |  | 후원명(LLM생성) |  |
| 9 | `CMPGN_CD` |  |  | 캠페인코드(LLM생성) |  |
| 10 | `CMPGN_NM` |  |  | 캠페인명(LLM생성) |  |
| 11 | `GENDER` |  |  | 성별(LLM생성) |  |
| 12 | `AGE` |  |  | 연령(LLM생성) |  |
| 13 | `SETLE_CD` |  |  | 결제코드(LLM생성) |  |
| 14 | `SETLE_NM` |  |  | 결제명(LLM생성) |  |
| 15 | `DSCNTC_PATH` |  |  | 후원중단경로(LLM생성) |  |
| 16 | `DSCNTC_RSN_CD` |  |  | 후원중단사유코드(LLM생성) |  |
| 17 | `DSCNTC_RSN_NM` |  |  | 후원중단사유명(LLM생성) |  |
| 18 | `CHILD_NO` |  |  | 아동번호(LLM생성) |  |
| 19 | `CHILD_KOR_NM` |  |  | 아동한글명(LLM생성) |  |
| 20 | `LST_BRND_CD` |  |  | 최종브랜드코드(LLM생성) |  |
| 21 | `LST_BRND_NM` |  |  | 최종브랜드명(LLM생성) |  |
| 22 | `FRST_REGIST_DT` |  |  | 최초등록일시(LLM생성) |  |
| 23 | `MNG_NO` |  |  | 관리번호(LLM생성) |  |
| 24 | `LETTER_DIV_CD` |  |  | 서신구분코드(LLM생성) |  |
| 25 | `CHILD_DTL_CD` |  |  | 아동상세코드(LLM생성) |  |
| 26 | `CHILD_DTL_NM` |  |  | 아동상세명(LLM생성) |  |
| 27 | `RELATNSP_DSCNTC_YN` |  |  | 결연중단여부(LLM생성) |  |
| 28 | `FRST_SPNSR` |  |  | 최초후원(LLM생성) |  |
| 29 | `FRST_BRND_CD` |  |  | 최초브랜드코드(LLM생성) |  |
| 30 | `FRST_BRND_NM` |  |  | 최초브랜드명(LLM생성) |  |
| 31 | `RELATNSP_KEY` |  |  | 결연KEY(LLM생성) |  |
| 32 | `LST_REGIST_DT` |  |  | 최종등록일시(LLM생성) |  |
| 33 | `FAX` |  |  | 팩스번호(LLM생성) |  |
| 34 | `PRIV_SUSP_YN` |  |  | 개인정보정지여부(LLM생성) |  |
| 35 | `SND_YN` |  |  | 발송여부(LLM생성) |  |
| 36 | `SND_MSG` |  |  | 발송메시지(LLM생성) |  |
| 37 | `REG_DATE` |  |  | 등록일자(LLM생성) |  |
| 38 | `SND_DT` |  |  | 발송일시(LLM생성) |  |
| 39 | `SND_HOUR` |  |  | 발송시(LLM생성) |  |
| 40 | `SND_MIN` |  |  | 발송분(LLM생성) |  |
| 41 | `email_recptn_cd` |  |  | 이메일수신코드(LLM생성) |  |
| 42 | `email_recptn_nm` |  |  | 이메일수신명(LLM생성) |  |
| 43 | `CHILD_PIC` |  |  | 아동사진(LLM생성) |  |
| 44 | `NATION_CD` |  |  | 국가코드(LLM생성) |  |
| 45 | `NATION_NM` |  |  | 국가명(LLM생성) |  |
| 46 | `BPLC_CD` |  |  | 사업장코드(LLM생성) |  |
| 47 | `BPLC_KOR_NM` |  |  | 사업장한글명(LLM생성) |  |
| 48 | `CHILD_BIRTHDAY` |  |  | 아동생년월일(LLM생성) |  |
| 49 | `ACL_CNTNT` |  |  | ACL내용(LLM생성) |  |
| 50 | `DISCHARGE_REPORT_KOR` |  |  | 종결보고서한글(LLM생성) |  |
| 51 | `PAST_NATION_NM` |  |  | 과거국가명(LLM생성) |  |
| 52 | `PAST_BPLC_NM` |  |  | 과거사업장명(LLM생성) |  |
| 53 | `PAST_CHILD_NM` |  |  | 과거아동명(LLM생성) |  |
| 54 | `PAST_CHILD_NO` |  |  | 과거아동번호(LLM생성) |  |
| 55 | `FAMILY_DTL` |  |  | 가족상세(LLM생성) |  |
| 56 | `FINAL_ACL_SCAN_CP` |  |  | 최종ACL스캔본(LLM생성) |  |
| 57 | `FINAL_ACL_CHILD_PIC` |  |  | 최종ACL아동사진(LLM생성) |  |
| 58 | `FINAL_ACL_TRANSLATED_CNTNT` |  |  | 최종ACL번역내용(LLM생성) |  |
| 59 | `FINAL_CHILD_SPNSR_START_DT` |  |  | 최종아동후원시작일시(LLM생성) |  |
| 60 | `NEW_CHILD_NO` |  |  | 신규아동번호(LLM생성) |  |
| 61 | `NEW_CHILD_NM` |  |  | 신규아동명(LLM생성) |  |
| 62 | `NEW_CHILD_ENGLISH_NAME` |  |  | 신규아동영문명(LLM생성) |  |
| 63 | `NEW_CHILD_PROJECT_COUNTRY` |  |  | 신규아동프로젝트국가(LLM생성) |  |
| 64 | `NEW_CHILD_WORKPLACE_NM` |  |  | 신규아동사업장명(LLM생성) |  |
| 65 | `NEW_CHILD_BIRTH_DT` |  |  | 신규아동생년월일(LLM생성) |  |
| 66 | `NEW_CHILD_PIC` |  |  | 신규아동사진(LLM생성) |  |
| 67 | `NEW_CHILD_GENDER` |  |  | 신규아동성별(LLM생성) |  |
| 68 | `RELATN_CHILD_PIC` |  |  | 결연아동사진(LLM생성) |  |
| 69 | `SPNSR_AMOUNT` |  |  | 후원금액(LLM생성) |  |
| 70 | `SPNSR_STRT_DT` |  |  | 후원시작일시(LLM생성) |  |
| 71 | `SPNSR_DSCNTC_DT` |  |  | 후원중단일시(LLM생성) |  |
| 72 | `RELATNSP_DT` |  |  | 결연일시(LLM생성) |  |
| 73 | `MBER_BIRTHDAY` |  |  | 회원생년월일(LLM생성) |  |
| 74 | `SPNSR_TYPE` |  |  | 후원유형(LLM생성) |  |
| 75 | `CPR_DIV_CD` |  |  | 법인구분코드(LLM생성) |  |
| 76 | `DEPT_CD` |  |  | 부서코드(LLM생성) |  |
| 77 | `CURRENT_BRND` |  |  | 현재브랜드(LLM생성) |  |
| 78 | `CURRENT_UPPER_CMPGN` |  |  | 현재상위캠페인(LLM생성) |  |
| 79 | `CURRENT_CMPGN` |  |  | 현재캠페인(LLM생성) |  |
| 80 | `FIRST_UPPER_CMPGN` |  |  | 최초상위캠페인(LLM생성) |  |
| 81 | `FIRST_CMPGN` |  |  | 최초캠페인(LLM생성) |  |
| 82 | `LAST_TOP_CMPGN` |  |  | 최종최상위캠페인(LLM생성) |  |
| 83 | `LAST_CMPGN` |  |  | 최종캠페인(LLM생성) |  |
| 84 | `SMS_TALK_CONT` |  |  | SMS내용(LLM생성) |  |
| 85 | `MAIL_CONT` |  |  | 메일내용(LLM생성) |  |
| 86 | `ALIM_TALK_CONT` |  |  | 알림톡내용(LLM생성) |  |
| 87 | `BTN_LIST` |  |  | 버튼리스트(LLM생성) |  |
| 88 | `EXTRA` |  |  | 기타(LLM생성) |  |
| 89 | `MSG_KEY` |  |  | 메시지KEY(LLM생성) |  |
| 90 | `CINFO` |  |  | 고객정보(LLM생성) |  |
| 91 | `RESPONSED_YN` |  |  | 응답여부(LLM생성) |  |
| 92 | `RESPONSED_DT` |  |  | 응답일시(LLM생성) |  |
| 93 | `SYNCED_AT` |  |  | 동기화일시(LLM생성) |  |
| 94 | `CALL_STATUS` |  |  | 통화상태(LLM생성) |  |
| 95 | `REAL_SEND_DT` |  |  | 실제발송일시(LLM생성) |  |
| 96 | `LAST_UPPER_CMPGN` |  |  | 최종상위캠페인(LLM생성) |  |

### SND_REQ_MST  (56 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `SEQ_NO` |  |  | 일련번호(LLM생성) |  |
| 2 | `SEND_GBN_TOP` |  |  | 발송구분대분류(LLM생성) |  |
| 3 | `SEND_GBN_MID` |  |  | 발송구분중분류(LLM생성) |  |
| 4 | `SEND_GBN_BOT` |  |  | 발송구분소분류(LLM생성) |  |
| 5 | `SEND_TITLE` |  |  | 발송제목(LLM생성) |  |
| 6 | `MSG_TYPE` |  |  | 메시지유형(LLM생성) |  |
| 7 | `MAIL_CONT` |  |  | 메일내용(LLM생성) |  |
| 8 | `TMPL_CODE` |  |  | 템플릿코드(LLM생성) |  |
| 9 | `AUTHOR` |  |  | 작성자(LLM생성) |  |
| 10 | `CREATE_DATE` |  |  | 생성일자(LLM생성) |  |
| 11 | `CONDITION_TITLE` |  |  | 조건제목(LLM생성) |  |
| 12 | `CALL_NUMBER` |  |  | 발신번호(LLM생성) |  |
| 13 | `ALT_SMS_YN` |  |  | 대체SMS여부(LLM생성) |  |
| 14 | `ALIM_TALK_CONT` |  |  | 알림톡내용(LLM생성) |  |
| 15 | `SMS_TALK_CONT` |  |  | SMS내용(LLM생성) |  |
| 16 | `REGULARLY` |  |  | 정기여부(LLM생성) |  |
| 17 | `PERIODIC` |  |  | 주기여부(LLM생성) |  |
| 18 | `PERIODIC_WEEK` |  |  | 주기주(LLM생성) |  |
| 19 | `PERIODIC_DAY` |  |  | 주기일(LLM생성) |  |
| 20 | `SEND_DATE` |  |  | 발송일자(LLM생성) |  |
| 21 | `SEND_TIME` |  |  | 발송시(LLM생성) |  |
| 22 | `SEND_MIN` |  |  | 발송분(LLM생성) |  |
| 23 | `SEND_SPLIT_TYPE` |  |  | 발송분할유형(LLM생성) |  |
| 24 | `DIVIDE` |  |  | 분할(LLM생성) |  |
| 25 | `DIVIDE_UNIT` |  |  | 분할단위(LLM생성) |  |
| 26 | `CORP_TYPE` |  |  | 법인유형(LLM생성) |  |
| 27 | `AUTO_TYPE` |  |  | 자동유형(LLM생성) |  |
| 28 | `USE_YN` |  |  | 사용여부(LLM생성) |  |
| 29 | `REG_ID` |  |  | 등록자ID(LLM생성) |  |
| 30 | `MOD_DATE` |  |  | 수정일자(LLM생성) |  |
| 31 | `INIT_REG_DATE` |  |  | 최초등록일자(LLM생성) |  |
| 32 | `LAST_SEND_DATE` |  |  | 최종발송일자(LLM생성) |  |
| 33 | `APPR_STATUS` |  |  | 승인상태(LLM생성) |  |
| 34 | `CREATE_DEPT` |  |  | 생성부서(LLM생성) |  |
| 35 | `SENDER_EMAIL` |  |  | 발신자이메일(LLM생성) |  |
| 36 | `RCPT_LIST` |  |  | 수신자리스트(LLM생성) |  |
| 37 | `SEND_STATUS` |  |  | 발송상태(LLM생성) |  |
| 38 | `SEND_CNT` |  |  | 발송건수(LLM생성) |  |
| 39 | `FAIL_CNT` |  |  | 실패건수(LLM생성) |  |
| 40 | `LAST_ERR` |  |  | 최종오류(LLM생성) |  |
| 41 | `END_DATE` |  |  | 종료일자(LLM생성) |  |
| 42 | `PAPER_YEAR` |  |  | 우편년도(LLM생성) |  |
| 43 | `MENU_CODE` |  |  | 메뉴코드(LLM생성) |  |
| 44 | `SEND_GBN_TOP_NM` |  |  | 발송구분대분류명(LLM생성) |  |
| 45 | `SEND_GBN_MID_NM` |  |  | 발송구분중분류명(LLM생성) |  |
| 46 | `SEND_GBN_BOT_NM` |  |  | 발송구분소분류명(LLM생성) |  |
| 47 | `TARGET_CNT` |  |  | 대상건수(LLM생성) |  |
| 48 | `SEND_ROUND` |  |  | 발송차수(LLM생성) |  |
| 49 | `BTN_LIST` |  |  | 버튼리스트(LLM생성) |  |
| 50 | `EXTRA` |  |  | 기타(LLM생성) |  |
| 51 | `ASSIGN_TARGET_CNT` |  |  | 할당대상건수(LLM생성) |  |
| 52 | `FIRST_SEQ_NO` |  |  | 최초일련번호(LLM생성) |  |
| 53 | `JOB_ID` |  |  | 작업ID(LLM생성) |  |
| 54 | `SYNCED_AT` |  |  | 동기화일시(LLM생성) |  |
| 55 | `REG_NM` |  |  | 등록자명(LLM생성) |  |
| 56 | `SERVICE_MENU_CODE` |  |  | 서비스메뉴코드(LLM생성) |  |

### TC_CMMN_CD  (10 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `CD_ID` | N |  | 코드ID |  |
| 2 | `CD_NM` | N |  | 코드명 |  |
| 3 | `CD_DC` | N |  | 코드설명 |  |
| 4 | `SORT_ORDR` | N |  | 정렬순서 |  |
| 5 | `RM` | N |  | 비고 |  |
| 6 | `USE_YN` | Y |  | 사용여부 | Y/N |
| 7 | `FRST_RGSTR_ID` | N |  | 최초등록자ID |  |
| 8 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 9 | `LAST_UPDUSR_ID` | N |  | 최종수정자ID |  |
| 10 | `LAST_UPDT_DT` | N |  | 최종수정일시 |  |

### TC_CMMN_DTL_CD  (15 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `CD_ID` | N |  | 코드ID |  |
| 2 | `DTL_CD_ID` | N |  | 상세코드ID |  |
| 3 | `DTL_CD_NM` | N |  | 상세코드명 |  |
| 4 | `DTL_CD_DC` | N |  | 상세코드설명 |  |
| 5 | `SORT_ORDR` | N |  | 정렬순서 |  |
| 6 | `RM` | N |  | 비고 |  |
| 7 | `USE_YN` | Y |  | 사용여부 | Y/N |
| 8 | `CD_ATRB1` | N |  | 코드속성1 |  |
| 9 | `CD_ATRB2` | N |  | 코드속성2 |  |
| 10 | `CD_ATRB3` | N |  | 코드속성3 |  |
| 11 | `FRST_RGSTR_ID` | N |  | 최초등록자ID |  |
| 12 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 13 | `LAST_UPDUSR_ID` | N |  | 최종수정자ID |  |
| 14 | `LAST_UPDT_DT` | N |  | 최종수정일시 |  |
| 15 | `UPPER_CD_ID` | N |  | 상위코드ID |  |

### TD_MS_CRMN_PRTCPNT  (19 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `CRMN_CD` |  |  | 캠페인코드(LLM생성) |  |
| 2 | `PRTCPNT_KEY` |  |  | 참여자KEY(LLM생성) |  |
| 3 | `MBER_NO` |  |  | 회원번호(LLM생성) |  |
| 4 | `RQST_PATH_CD` |  |  | 신청경로코드(LLM생성) |  |
| 5 | `PARTCPT_TIME_CO` |  |  | 참여시간수(LLM생성) |  |
| 6 | `PARTCPT_STAT_CD` |  |  | 참여상태코드(LLM생성) |  |
| 7 | `SELF_PARTCPT_CD` |  |  | 본인참여코드(LLM생성) |  |
| 8 | `RCPMNY_STAT_CD` |  |  | 수납상태코드(LLM생성) |  |
| 9 | `RCPMNY_DATE` |  |  | 수납일자(LLM생성) |  |
| 10 | `REFND_DATE` |  |  | 환불일자(LLM생성) |  |
| 11 | `RQST_DATE` |  |  | 신청일자(LLM생성) |  |
| 12 | `PARTCPT_DATE` |  |  | 참여일자(LLM생성) |  |
| 13 | `RCPMNY_AMT` |  |  | 수납금액(LLM생성) |  |
| 14 | `ACMPNY_PARTCPT_CO` |  |  | 동반참여수(LLM생성) |  |
| 15 | `RM` |  |  | 비고(LLM생성) |  |
| 16 | `FRST_RGSTR_ID` |  |  | 최초등록자ID(LLM생성) |  |
| 17 | `FRST_REGIST_DT` |  |  | 최초등록일시(LLM생성) |  |
| 18 | `LAST_UPDUSR_ID` |  |  | 최종수정자ID(LLM생성) |  |
| 19 | `LAST_UPDT_DT` |  |  | 최종수정일시(LLM생성) |  |

### TD_MS_EMAIL_LQY_SNDNG  (24 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `SNDNG_KEY` | N |  | 발신KEY |  |
| 2 | `MSG_ID` | N |  | 메시지ID |  |
| 3 | `MKT_TRGET_CTNT` | N |  | 마케팅대상내용 |  |
| 4 | `SNDNG_CNT` | N |  | 발신건수 |  |
| 5 | `SUCCES_CNT` | N |  | 성공건수 |  |
| 6 | `FAILR_CNT` | N |  | 실패건수 |  |
| 7 | `RECPTN_CNT` | N |  | 수신건수 |  |
| 8 | `SNDNG_STRT_DT` | N |  | 발신시작일시 |  |
| 9 | `SNDNG_END_DT` | N |  | 발신종료일시 |  |
| 10 | `INFLOW_PATH_CTNT` | N |  | 유입경로내용 |  |
| 11 | `SNDNG_YEAR_CTNT` | N |  | 발신년도내용 |  |
| 12 | `SNDNG_MT_CTNT` | N |  | 발신월내용 |  |
| 13 | `SNDNG_TEAM_CTNT` | N |  | 발신팀내용 |  |
| 14 | `SUCCES_FAILR_CNT_CTNT` | N |  | 성공실패건수내용 |  |
| 15 | `URL_OTHBC_CNT_CTNT` | N |  | URL공개건수내용 |  |
| 16 | `URL_OTHBC_RT_CTNT` | N |  | URL공개율내용 |  |
| 17 | `SESION_VU_CTNT` | N |  | 세션값내용 |  |
| 18 | `SESION_PGE_CNT_CTNT` | N |  | 세션페이지건수내용 |  |
| 19 | `DVLP_ACMSLT_CNT_CTNT` | N |  | 개발실적건수내용 |  |
| 20 | `CLOS_YN` | Y |  | 마감여부 | 중요도 낮음. 현재까지 5개의 row만 데이터가 있음 |
| 21 | `FRST_RGSTR_ID` | N |  | 최초등록자ID |  |
| 22 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 23 | `LAST_UPDUSR_ID` | N |  | 최종수정자ID |  |
| 24 | `LAST_UPDT_DT` | N |  | 최종수정일시 |  |

### TD_MS_EMAIL_SNDNG_DTLS  (12 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `SNDNG_KEY` | N |  | 발신KEY |  |
| 2 | `SNDNG_DTL_KEY` | N |  | 발신상세KEY |  |
| 3 | `SNDNG_DE` | N |  | 발신일 |  |
| 4 | `MBER_NO` | N |  | 회원번호 |  |
| 5 | `EMAIL` | N |  | 이메일 |  |
| 6 | `CHN_PARM_CTNT` | N |  | 치환파라미터내용 |  |
| 7 | `SNDNG_RST_CD` | Y | 하드코딩됨 | 발신결과코드 | 0=실패;1=성공;4=계정없음;5=도메인오류;그외=미처리 |
| 8 | `ATCHFL_ID` | N |  | 첨부파일ID |  |
| 9 | `FRST_RGSTR_ID` | N |  | 최초등록자ID |  |
| 10 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 11 | `LAST_UPDUSR_ID` | N |  | 최종수정자ID |  |
| 12 | `LAST_UPDT_DT` | N |  | 최종수정일시 |  |

### TD_MS_EVENT_PRTCPNT_DTL  (15 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `EVENT_CD` |  |  | 이벤트코드(LLM생성) |  |
| 2 | `MBER_NO` |  |  | 회원번호(LLM생성) |  |
| 3 | `PARTCPT_SEQ` |  |  | 참여일련번호(LLM생성) |  |
| 4 | `EVENT_PARTCPT_DIV_CD` |  |  | 이벤트참여구분코드(LLM생성) |  |
| 5 | `PRZWIN_CD` |  |  | 당첨코드(LLM생성) |  |
| 6 | `PARTCPT_CHNNL_CD` |  |  | 참여채널코드(LLM생성) |  |
| 7 | `PARTCPT_PATH_CD` |  |  | 참여경로코드(LLM생성) |  |
| 8 | `PARTCPT_STAT_CD` |  |  | 참여상태코드(LLM생성) |  |
| 9 | `PARTCPT_DT` |  |  | 참여일시(LLM생성) |  |
| 10 | `RM` |  |  | 비고(LLM생성) |  |
| 11 | `RM2` |  |  | 비고2(LLM생성) |  |
| 12 | `FRST_RGSTR_ID` |  |  | 최초등록자ID(LLM생성) |  |
| 13 | `FRST_REGIST_DT` |  |  | 최초등록일시(LLM생성) |  |
| 14 | `LAST_UPDUSR_ID` |  |  | 최종수정자ID(LLM생성) |  |
| 15 | `LAST_UPDT_DT` |  |  | 최종수정일시(LLM생성) |  |

### TD_MS_MSG_AT_LQY_SNDNG  (18 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `SNDNG_KEY` | N |  | 발신KEY |  |
| 2 | `DIVS_DTL_KEY` | N |  | 분할상세KEY |  |
| 3 | `SNDNG_CNT` | N |  | 발신건수 |  |
| 4 | `SUCCES_CNT` | N |  | 성공건수 |  |
| 5 | `AT_ALTRTV_SNDNG_CNT` | N |  | 알림톡대체발송건수 |  |
| 6 | `AT_FAILR_CNT` | N |  | 알림톡실패건수 |  |
| 7 | `RESVE_SNDNG_DE` | N |  | 예약발신일 |  |
| 8 | `RESVE_HM` | N |  | 예약시분 |  |
| 9 | `TOT_CLICK_CNT_CTNT` | N |  | 총클릭건수내용 |  |
| 10 | `CLICK_CNT_CTNT1` | N |  | 클릭건수내용1 |  |
| 11 | `CLICK_CNT_CTNT2` | N |  | 클릭건수내용2 |  |
| 12 | `CLICK_CNT_CTNT3` | N |  | 클릭건수내용3 |  |
| 13 | `CLICK_CNT_CTNT4` | N |  | 클릭건수내용4 |  |
| 14 | `RM_VU_CTNT` | N |  | 비고값내용 |  |
| 15 | `FRST_RGSTR_ID` | N |  | 최초등록자ID |  |
| 16 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 17 | `LAST_UPDUSR_ID` | N |  | 최종수정자ID |  |
| 18 | `LAST_UPDT_DT` | N |  | 최종수정일시 |  |

### TD_MS_MSG_AT_SNDNG_DTLS  (17 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `SNDNG_KEY` | N |  | 발신KEY |  |
| 2 | `SNDNG_DTL_KEY` | N |  | 발신상세KEY |  |
| 3 | `SNDNG_DT` | N |  | 발신일시 |  |
| 4 | `MBER_NO` | N |  | 회원번호 |  |
| 5 | `MBER_KORNM` | N |  | 회원명 |  |
| 6 | `MBTLNUM` | N |  | 휴대폰번호 |  |
| 7 | `SNDNG_NO` | N |  | 발신번호 |  |
| 8 | `TRNSMS_STAT_CD` | Y | MS282 | 전송상태코드 |  |
| 9 | `TRNSMS_FAILR_CD_ID` | N |  | 전송실패코드ID |  |
| 10 | `FRST_RGSTR_ID` | N |  | 대체메시지발신여부 |  |
| 11 | `ALTRTV_MSG_SNDNG_YN` | Y |  | 대체문자 발송 여부 | Y= '대체문자 발송' / N = '대체문자 발송X' |
| 12 | `MSG_AT_CTNT` | N |  | 대체메시지내용 |  |
| 13 | `FRST_REGIST_DT` | N |  | 최초등록자ID |  |
| 14 | `LAST_UPDUSR_ID` | N |  | 최초등록일시 |  |
| 15 | `LAST_UPDT_DT` | N |  | 최종수정자ID |  |
| 16 | `ALTRTV_MSG_CTNT` | N |  | 최종수정일시 |  |
| 17 | `ATTACHED_FILE` | N |  | 첨부파일 |  |

### TD_MS_PSTMTR_LQY_SNDNG  (9 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `SNDNG_KEY` | N |  | 발신KEY |  |
| 2 | `SNDNG_CNT` | N |  | 발신건수 |  |
| 3 | `SNDNG_SQNC` | N |  | 발신차수 |  |
| 4 | `SNDNG_TIT` | N |  | 발신제목 |  |
| 5 | `SNDNG_MEMO_CTNT` | N |  | 발신메모내용 |  |
| 6 | `FRST_RGSTR_ID` | N |  | 최초등록자ID |  |
| 7 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 8 | `LAST_UPDUSR_ID` | N |  | 최종수정자ID |  |
| 9 | `LAST_UPDT_DT` | N |  | 최종수정일시 |  |

### TD_MS_PSTMTR_SNDNG_DTL  (15 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `SNDNG_KEY` | N |  | 발신KEY |  |
| 2 | `SNDNG_DTL_KEY` | N |  | 발신상세KEY |  |
| 3 | `SNDNG_DE` | N |  | 발신일 |  |
| 4 | `MBER_NO` | N |  | 회원번호 |  |
| 5 | `ZIP` | N |  | 우편번호 |  |
| 6 | `ADDR` | N |  | 주소 |  |
| 7 | `DTL_ADDR` | N |  | 상세주소 |  |
| 8 | `RELATNSP_KEY` | N |  | 결연KEY |  |
| 9 | `MNG_NO` | N |  | 관리번호 |  |
| 10 | `DTL_KEY` | N |  | 상세KEY |  |
| 11 | `BIZN_REQUST_KEY` | N |  | 업무요청KEY |  |
| 12 | `FRST_RGSTR_ID` | N |  | 최초등록자ID |  |
| 13 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 14 | `LAST_UPDUSR_ID` | N |  | 최종수정자ID |  |
| 15 | `LAST_UPDT_DT` | N |  | 최종수정일시 |  |

### TH_MM_FDRM_MBER_STNG_DTLS  (6 cols)

> ✅ **DDL 확정 (2026-06-29 BRONZE_CRM DDL 수령)** — 플레이스홀더 COL2~6 해소. 정기회원 **상태변경내역**(SCD2 소스). BF/CHN = 변경 전/후 회원상태. **FMM 시점지표 #49·50·52·53 산출 가능**.

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고(물리타입) |
|--:|------|:--:|------|------|------|
| 1 | `MBER_NO` | N |  | 회원번호 | VARCHAR(10) |
| 2 | `SER_NO` | N |  | 일련번호(변경순번) | NUMBER(10,0) |
| 3 | `BF_STAT_CD` | Y | MM010(추정) | 변경전 회원상태코드 | VARCHAR(3) |
| 4 | `CHN_STAT_CD` | Y | MM010(추정) | 변경후 회원상태코드 | VARCHAR(3) |
| 5 | `FRST_RGSTR_ID` | N |  | 최초등록자ID | VARCHAR(30) |
| 6 | `FRST_REGIST_DT` | N |  | 최초등록일시(상태변경 시점) | TIMESTAMP_NTZ(9) |

### TH_PM_SETLE_INFO_HIST  (53 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `UPDT_DT` |  |  | 수정일시 |  |
| 2-53 |  |  |  |  | (원본 정의서 상세 미기재) |

### TM_CM_BRND_MNG  (9 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `BRND_ID` | N |  | 브랜드ID |  |
| 2 | `BRND_NM` | N |  | 브랜드명 |  |
| 3 | `USE_DEPT_CD` | Y |  | 사용부서코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 4 | `USE_YN` | Y |  | 사용여부 | Y/N |
| 5 | `PR_MTH_LIST` | N |  | 홍보방법리스트 |  |
| 6 | `FRST_RGSTR_ID` | N |  | 최초등록자ID |  |
| 7 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 8 | `LAST_UPDUSR_ID` | N |  | 최종수정자ID |  |
| 9 | `LAST_UPDT_DT` | N |  | 최종수정일시 |  |

### TM_CM_CMPGN_MNG  (32 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `CMPGN_CD` | N |  | 캠페인코드 |  |
| 2 | `CMPGN_NM` | N |  | 캠페인명 |  |
| 3 | `UPPER_CMPGN_CD` | N |  | 상위캠페인코드 |  |
| 4 | `UPPER_CMPGN_YN` | Y |  | 상위캠페인여부 | Y/N |
| 5 | `SPNSR_DIV_CD` | Y | CM035 | 후원구분코드 | 1=정기후원; 2=일시후원 |
| 6 | `CPR_DIV_CD` | Y | CM019 | 법인구분코드 |  |
| 7 | `CMPGN_TRGET_CD` | Y | CM002 | 캠페인대상코드 |  |
| 8 | `USE_DEPT_CD` | Y |  | 사용부서코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 9 | `USE_SCOPE` | N |  | 사용범위 |  |
| 10 | `SPNSR_ENTRPRS_ID` | N |  | 후원기업ID |  |
| 11 | `BRND_ID` | N |  | 브랜드ID |  |
| 12 | `PR_MTH_CD` | Y | CM008 | 홍보방법코드 |  |
| 13 | `CMPGN_STRT_DE` | N |  | 캠페인시작일 |  |
| 14 | `MBRFEE_BNKB_LIST` | N |  | 회비통장리스트 |  |
| 15 | `INICIS_ACNT_NO` | N |  | 이니시스계정번호 |  |
| 16 | `USE_YN` | Y |  | 사용여부 | Y/N |
| 17 | `REFER_URL` | N |  | 참고URL |  |
| 18 | `SPNSR_BSNS_ID` | N |  | 후원사업ID |  |
| 19 | `CMPGN_DC` | N |  | 캠페인설명 |  |
| 20 | `EMRGNCY_AID_BPLC_CD` | Y |  | 긴급구호사업장코드 | TM_CM_EMRGNCY_AID_BPLC - EMRGNCY_AID_BPLC_CD - EMRGNCY_AID_NM |
| 21 | `CMPGN_PRPT_YN` | Y |  | 캠페인특성여부 | Y/N |
| 22 | `ATCHFL_ID` | N |  | 첨부파일ID |  |
| 23 | `FRST_RGSTR_ID` | N |  | 최초등록자ID |  |
| 24 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 25 | `LAST_UPDUSR_ID` | N |  | 최종수정자ID |  |
| 26 | `LAST_UPDT_DT` | N |  | 최종수정일시 |  |
| 27 | `RM` | N |  | 비고 |  |
| 28 | `MBER_INFLOW_PATH_CD` | Y | MM293 | 개발인입경로 | 2026-06 현업 추가. 코드값(숫자). CD_ID=MM293 + DTL_CD_ID 조인 |
| 29 | `CMPGN_CTGR_CD` | Y | MM294 | 캠페인카테고리 | 2026-06 현업 추가. 코드값(숫자). CD_ID=MM294 + DTL_CD_ID 조인. (GOLD 캠페인유형#17 후보 — 현업 최종확인 대기) |
| 30 | `CMPGN_TYPE1_BSN` | Y | MM295 | 캠페인유형(국내/해외) | 2026-06 현업 추가. 코드값(숫자). CD_ID=MM295 + DTL_CD_ID 조인. GOLD 국내해외구분#15 원천 |
| 31 | `CMPGN_TYPE2_BSN` | Y | MM296 | 캠페인유형(사업/사례) | 2026-06 현업 추가. 코드값(숫자). CD_ID=MM296 + DTL_CD_ID 조인. GOLD 사업사례구분#16 원천 |
| 32 | `MKTG_CMPGN_NM` | Y | TM_CM_MKTNG_CMPGN_MNG | 마케팅캠페인명 | 2026-06 현업 추가. 코드값(숫자). TM_CM_MKTNG_CMPGN_MNG - MK_CMPGN_CD - MK_CMPGN_NM |

### TM_CM_MKTNG_CMPGN_MNG  (8 cols)

> 2026-06-26 현업 신규 추가. 마케팅캠페인명 마스터. `TM_CM_CMPGN_MNG.MKTG_CMPGN_NM`(코드값)이 `MK_CMPGN_CD`로 본 테이블 참조.

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `MK_CMPGN_CD` | N |  | 마케팅캠페인코드 | PK. TM_CM_CMPGN_MNG.MKTG_CMPGN_NM 조인키 |
| 2 | `MK_CMPGN_NM` | N |  | 마케팅캠페인명 |  |
| 3 | `USE_YN` | Y |  | 사용여부 | Y/N |
| 4 | `RM` | N |  | 비고 |  |
| 5 | `FRST_RGSTR_ID` | N |  | 최초등록자ID |  |
| 6 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 7 | `LAST_UPDUSR_ID` | N |  | 최종수정자ID |  |
| 8 | `LAST_UPDT_DT` | N |  | 최종수정일시 |  |

### TM_CM_DEPT_INFO  (12 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `DEPT_ID` | N |  | 부서ID |  |
| 2 | `DEPT_NM` | N |  | 부서명 |  |
| 3 | `UPPER_DEPT_ID` | N |  | 상위부서ID |  |
| 4 | `SORT_ORDR` | N |  | 정렬순서 |  |
| 5 | `USE_YN` | Y |  | 사용여부 | Y/N |
| 6 | `ACMSLT_DEPT_YN` | Y |  | 실적부서여부 | Y/N |
| 7 | `STATS_DEPT_LVL` | N |  | 통계부서레벨 |  |
| 8 | `FRST_RGSTR_ID` | N |  | 최초등록자ID |  |
| 9 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 10 | `LAST_UPDUSR_ID` | N |  | 최종수정자ID |  |
| 11 | `LAST_UPDT_DT` | N |  | 최종수정일시 |  |
| 12 | `ACMSLT_UPPER_DEPT_ID` | N |  | 실적상위부서ID |  |

### TM_CM_MBER_DVLP_GOAL  (9 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `STDYY` | N |  | 기준연 |  |
| 2 | `STDR_MT` | N |  | 기준월 |  |
| 3 | `MBER_DVLP_DIV_CD` | Y | MM015 | 개발구분 |  |
| 4 | `DEPT_ID` | N |  | 부서 |  |
| 5 | `GOAL_CNT` | N |  | 개발목표수 |  |
| 6 | `FRST_RGSTR_ID` | N |  | 최초등록자 |  |
| 7 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 8 | `LAST_UPDUSR_ID` | N |  | 최종등록자ID |  |
| 9 | `LAST_UPDT_DT` | N |  | 최종등록일시 |  |

### TM_CM_SPNSR_BSNS_INFO  (13 cols)

> ✅ **DDL 확정 (2026-06-29)** — 후원사업 마스터. `SPNSR_BSNS_NM`(후원사업명)·`SPNSR_BSNS_ABRV_CD`(약칭) 확인 → **DIM_SPONSORSHIP 구성 가능**.

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고(물리타입) |
|--:|------|:--:|------|------|------|
| 1 | `SPNSR_BSNS_ID` | N |  | 후원사업ID | VARCHAR(20) |
| 2 | `SPNSR_DIV_CD` | Y | CM035 | 후원구분코드 | VARCHAR(3) 1=정기;2=일시 |
| 3 | `SPNSR_BSNS_NM` | N |  | 후원사업명 | VARCHAR(50) |
| 4 | `SPNSR_BSNS_ABRV_CD` | N |  | 후원사업약칭 | VARCHAR(3) |
| 5 | `DNTN_TY_CD` | Y |  | 기부유형코드 | VARCHAR(3) |
| 6 | `SORT_ORDR` | N |  | 정렬순서 | NUMBER(10,0) |
| 7 | `CPR_DIV_CD` | Y |  | 법인구분코드 | VARCHAR(3) |
| 8 | `RM` | N |  | 비고 | VARCHAR(1000) |
| 9 | `USE_YN` | Y |  | 사용여부 | VARCHAR(1) Y/N |
| 10 | `FRST_RGSTR_ID` | N |  | 최초등록자ID | VARCHAR(30) |
| 11 | `FRST_REGIST_DT` | N |  | 최초등록일시 | TIMESTAMP_NTZ(9) |
| 12 | `LAST_UPDUSR_ID` | N |  | 최종수정자ID | VARCHAR(30) |
| 13 | `LAST_UPDT_DT` | N |  | 최종수정일시 | TIMESTAMP_NTZ(9) |

### TM_MM_FDRM_MBER_DVLP_AMT  (20 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `SPNSR_NO` | N |  | 후원번호 |  |
| 2 | `SPNSR_BSNS_NO` | N |  | 후원사업번호 |  |
| 3 | `OCCRRNC_DE` | N |  | 발생일 |  |
| 4 | `SER_NO` | N |  | 일련번호 |  |
| 5 | `MBER_NO` | N |  | 회원번호 |  |
| 6 | `ACT_DEPT_CD` | Y |  | 활동부서코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 7 | `ACMSLT_DEPT_CD` | Y |  | 실적부서코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 8 | `CMPGN_CD` | Y |  | 캠페인코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 10 | `MBER_DIV_CD` | Y | MM018 | 회원구분코드 |  |
| 11 | `SEX` | N | CM013 | 성별 | 특이사항, 6=단체, 7=기업, 8=기타 값을 보면. 컬럼설명은 성별이나 성별만으로는 사용하지는 않음 |
| 12 | `AREA_CD` | Y | CM018 | 지역코드 |  |
| 13 | `AGE` | N |  | 연령 |  |
| 14 | `SPNSR_TIME_CO` | N |  | 후원시간수 |  |
| 15 | `SPNSR_AMT_CD` | Y | CM012 | 후원금액코드 |  |
| 16 | `SPNSR_BSNS_ID` | N |  | 후원사업ID |  |
| 17 | `CANCL_RDCAMT_RSN_CD` | Y | MM002 | 취소감액사유코드 |  |
| 18 | `SPNSR_AMT` | N |  | 후원금액 |  |
| 19 | `DVLP_DIV_CD` | Y | MM015 | 개발구분코드 |  |
| 20 | `FRST_RGSTR_ID` | N |  | 최초등록자ID |  |
| 21 | `FRST_RGSTR_NM` | N |  | 최초등록자명 |  |

### TM_MM_FDRM_MBER_INFO  (41 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `MBER_NO` | N |  | 회원번호 |  |
| 2 | `MBER_DIV_CD` | Y | MM018 | 회원구분코드 | 1=개인;2=기업;3=단체 |
| 3 | `CPR_DIV_CD` | Y | CM019 | 법인구분코드 | I=사단, S=사복, A=통합 |
| 4 | `RRN_FSTDGT` | N |  | 주민등록번호앞자리 |  |
| 5 | `RRN_LSTDGT_ENC` | N |  | 주민등록번호뒷자리암호화 |  |
| 6 | `BRTHDY` | N |  | 생년월일 |  |
| 7 | `SLRCLD_LRR_CD` | Y | CM029 | 양력음력코드 |  |
| 8 | `MBER_KORNM` | N |  | 회원한글명 |  |
| 9 | `MBER_ENGNM` | N |  | 회원영문명 |  |
| 10 | `MBTLNUM` | N |  | 휴대폰번호 |  |
| 11 | `MOBLPHON_STAT_CD` | Y | MM008 | 휴대폰상태코드 |  |
| 12 | `TSTM_DIV_CD` | Y | MS026 | TSTM구분코드 |  |
| 13 | `ETC_CTTPC` | N |  | 기타연락처 |  |
| 14 | `ETC_TSTM_DIV_CD` | Y | MS026 | 기타TSTM구분코드 |  |
| 15 | `ETC_CTTPC_REL_CD` | Y | MM008 | 기타연락처관계코드 |  |
| 16 | `ETC_CTTPC_STAT_CD` | Y | MM008 | 기타연락처상태코드 |  |
| 17 | `FAXNO` | N |  | 팩스번호 |  |
| 18 | `ZIP` | N |  | 우편번호 |  |
| 19 | `ADDR` | N |  | 주소 |  |
| 20 | `DTL_ADDR` | N |  | 상세주소 |  |
| 21 | `EMAIL` | N |  | 이메일 |  |
| 22 | `EMAIL_STAT_CD` | Y | MM009 | 이메일상태코드 |  |
| 23 | `PSTMTR_RECPTN_CD` | Y | MS027 | 우편물수신코드 |  |
| 24 | `EMAIL_RECPTN_CD` | Y | MS028 | 이메일수신코드 |  |
| 25 | `CHRCTR_RECPTN_YN` | Y |  | 문자수신여부 | Y/N (빈값 및 Null 존재) |
| 26 | `BL_ENTRPS_NO` | N |  | 소속업체번호 |  |
| 27 | `SPECL_MNG_CD1` | N |  | 특별관리코드1 |  |
| 28 | `SPECL_MNG_CD2` | N |  | 특별관리코드2 |  |
| 29 | `TNI_CU_BL_NO` | N |  | 더네이버스클럽소속번호 |  |
| 30 | `CMPGN_CD` | Y |  | 캠페인코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 31 | `MBER_STAT_CD` | Y | MM010 | 회원상태코드 |  |
| 32 | `RELATNSP_DIV_CD` | Y | MM019 | 결연구분코드 | 1=신규;2=결연회원;3=비결연회원;4=혼합회원;5=후원중단 (빈값 및 NULL 존재) |
| 33 | `ACT_DEPT_CD` | Y |  | 활동부서코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 34 | `HMPG_ID` | N |  | 홈페이지ID |  |
| 35 | `JOIN_PATH_CD` | Y | MM014 | 가입경로코드 |  |
| 36 | `CTI_SYNCHRN_DIV_CD` | Y |  | CTI동기화구분코드 | 사용하지 않음<br>1= '동기' , NULL ='비동기' , 2='비동기' |
| 37 | `STDR_DE` | N |  | 기준일 |  |
| 38 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 39 | `REGIST_DEPT_CD` | Y | TM_CM_DEPT_INFO | 등록부서코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 40 | `FRST_RGSTR_ID` | N |  | 최초등록자ID |  |
| 41 | `SEX` | N | CM013 | 성별 | 특이사항, 6=단체, 7=기업, 8=기타 값을 보면. 컬럼설명은 성별이나 성별만으로는 사용하지는 않음 |

### TM_MM_FDRM_MBER_IRSD  (15 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고(물리타입) |
|--:|------|:--:|------|------|------|
| 1 | `OCCRRNC_DE` | N |  | 발생일 | VARCHAR(8). UPDATE 시 RDCAMT_YN이 Y로 바뀌나, 안 바뀌는 경우도 있어 날짜로 구분 불가 |
| 2 | `SER_NO` | N |  | 일련번호 | NUMBER(10,0) |
| 3 | `ACMSLT_DEPT_CD` | Y |  | 실적부서코드 | VARCHAR(10) |
| 4 | `CMPGN_CD` | Y |  | 캠페인코드 | VARCHAR(20) |
| 5 | `MBER_NO` | N |  | 회원번호 | VARCHAR(10) |
| 6 | `SPNSR_AMT` | N |  | 후원금액(증감액) | NUMBER(19,0) |
| 7 | `SETLE_CD` | Y |  | 결제코드 | VARCHAR(3) |
| 8 | `MBER_DIV_CD` | Y | MM018 | 회원구분코드 | VARCHAR(3) |
| 9 | `SEX` | N | CM013 | 성별 | VARCHAR(2) |
| 10 | `AREA_CD` | Y | CM018 | 지역코드 | VARCHAR(3) |
| 11 | `AGE` | N |  | 연령 | NUMBER(10,0) |
| 12 | `SPNSR_TIME_CO` | N |  | 후원시간수 | NUMBER(10,0) |
| 13 | `SPNSR_AMT_CD` | Y | CM012 | 후원금액코드 | VARCHAR(3) |
| 14 | `RDCAMT_YN` | Y |  | 감액여부 | VARCHAR(1) Y/N |
| 15 | `FRST_RGSTR_ID` | N |  | 최초등록자ID | VARCHAR(30) |

### TM_MM_FDRM_MBER_RE_SPNSR  (5 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `RE_SPNSR_DE` |  |  | 재후원일 | UPDATE 없이 계속 ROW가 쌓이는 구조 |
| 2-5 |  |  |  |  | (원본 정의서 상세 미기재) |

### TM_MM_FDRM_MBER_SPNSR_BSNS  (7 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `SPNSR_NO` | N |  | 후원번호 | UPDATE 없이 계속 ROW가 쌓이는 구조 |
| 2 | `SPNSR_BSNS_NO` | N |  | 후원사업번호 |  |
| 3 | `SPNSR_BSNS_ID` | N |  | 후원사업코드 |  |
| 4 | `SPNSR_AMT` | N |  | 후원금액 |  |
| 5 | `SPNSR_DSCNTC_DE` | N |  | 후원중단일 |  |
| 6 | `SPNSR_DSCNTC_YN` | Y |  | 후원중단여부 | Y/N Y=중단완료 / N=후원중 |
| 7 | `SPNSR_DSCNTC_RSN_CD` | Y | MM002 | 후원사업취소사유 |  |

### TM_MM_FDRM_MBER_SPNSR_DSCNTC  (7 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `MBER_NO` | N |  | 회원번호 | UPDATE 없이 계속 ROW가 쌓이는 구조 |
| 2 | `SPNSR_DSCNTC_DE` | N |  | 후원중단일 |  |
| 3 | `SER_NO` | N |  | 일련번호 |  |
| 4 | `DSCNTC_RSN_CD` | Y | MM005 | 후원중단사유 |  |
| 5 | `DSCNTC_PATH` | Y | MM287 | 후원중단경로 |  |
| 6 | `REGIST_DEPT_CD` | Y |  | 등록부서코드 | TM_CM_DEPT_INFO - DEPT_ID - DEPT_NM |
| 7 | `FRST_RGSTR_ID` | N |  | 최초등록자 |  |

### TM_MM_ONCE_MBER_INFO  (32 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `ONCE_MBER_NO` | N |  | 일시후원회원번호 |  |
| 2 | `MBER_DIV_CD` | Y | MM018 | 회원구분코드 | 1=개인, 2=기업, 3=단체 |
| 3 | `CPR_DIV_CD` | Y | CM019 | 법인구분코드 | I=사단, S=사복, A=통합 |
| 4 | `RRN_FSTDGT` | N |  | 주민등록번호앞자리 |  |
| 5 | `RRN_LSTDGT_ENC` | N |  | 주민등록번호뒷자리암호화 |  |
| 6 | `SEX` | N | CM013 | 성별 | 특이사항, 6=단체, 7=기업, 8=기타 값을 보면. 컬럼설명은 성별이나 성별만으로는 사용하지는 않음 |
| 7 | `MBER_KORNM` | N |  | 회원한글명 |  |
| 8 | `MBER_ENGNM` | N |  | 회원영문명 |  |
| 9 | `BRTHDY` | N |  | 생년월일 |  |
| 10 | `MBTLNUM` | N |  | 휴대폰번호 |  |
| 11 | `TSTM_DIV_CD` | Y | MS026 | TSTM구분코드 | 1=TM거절, 2=TS거절, 3=TMTS거절 |
| 12 | `ETC_CTTPC` | N |  | 기타연락처 |  |
| 13 | `ETC_TSTM_DIV_CD` | Y | MS026 | 기타TSTM구분코드 | 1=TM거절, 2=TS거절, 3=TMTS거절 |
| 14 | `REL_CD` | Y | CM009 | 관계코드 |  |
| 15 | `ZIP` | N |  | 우편번호 |  |
| 16 | `ADDR` | N |  | 주소 |  |
| 17 | `DTL_ADDR` | N |  | 상세주소 |  |
| 18 | `EMAIL` | N |  | 이메일 |  |
| 19 | `FAXNO` | N |  | 팩스번호 |  |
| 20 | `ENTRPS_NM` | N |  | 업체명 |  |
| 21 | `HMPG_ID` | N |  | 홈페이지ID |  |
| 22 | `PSTMTR_RECPTN_YN` | Y |  | 우편물수신여부 | Y/N(NULL 존재) |
| 23 | `EMAIL_RECPTN_YN` | Y |  | 이메일수신여부 | Y/N(NULL 존재) |
| 24 | `CHRCTR_RECPTN_YN` | Y |  | 문자수신여부 | Y/N(NULL 존재) |
| 25 | `FDRM_MBER_TRNSFER_FG` | N |  | 정기회원이관유무 |  |
| 26 | `SPECL_MNG_CD1` | N |  | 특별관리코드1 |  |
| 27 | `SPECL_MNG_CD2` | N |  | 특별관리코드2 |  |
| 28 | `TNI_CU_BL_NO` | N |  | 더네이버스클럽소속번호 |  |
| 29 | `CTI_SYNCHRN_DIV_CD` |  |  | CTI동기화구분코드 | 사용하지 않음<br>1='동기' , 2 ='비동기' |
| 30 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 31 | `REGIST_DEPT_CD` | Y | TM_CM_DEPT_INFO | 등록부서코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 32 | `FRST_RGSTR_ID` | N |  | 최초등록자ID |  |

### TM_MS_CRMN  (31 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `CRMN_CD` |  |  | 캠페인코드(LLM생성) |  |
| 2 | `CRMN_DIV_CD` |  |  | 캠페인구분코드(LLM생성) |  |
| 3 | `CRMN_TIT` |  |  | 캠페인제목(LLM생성) |  |
| 4 | `CRMN_PLACE_NM` |  |  | 캠페인장소명(LLM생성) |  |
| 5 | `BRNCH_DEPT_ID` |  |  | 지부부서ID(LLM생성) |  |
| 6 | `ATCHFL_ID` |  |  | 첨부파일ID(LLM생성) |  |
| 7 | `SITE_URL` |  |  | 사이트URL(LLM생성) |  |
| 8 | `CRMN_STRT_DE` |  |  | 캠페인시작일(LLM생성) |  |
| 9 | `CRMN_END_DE` |  |  | 캠페인종료일(LLM생성) |  |
| 10 | `CRMN_PART_STRT_DE` |  |  | 캠페인참여시작일(LLM생성) |  |
| 11 | `CRMN_PART_END_DE` |  |  | 캠페인참여종료일(LLM생성) |  |
| 12 | `TAT` |  |  | 처리소요시간(TAT)(LLM생성) |  |
| 13 | `RCRIT_PSNNL_CO` |  |  | 모집인원수(LLM생성) |  |
| 14 | `RESRCE_SRVC_FG` |  |  | 자원봉사여부(LLM생성) |  |
| 15 | `CPR_DIV_CD` |  |  | 법인구분코드(LLM생성) |  |
| 16 | `ENTRPS_CD` |  |  | 업체코드(LLM생성) |  |
| 17 | `RM` |  |  | 비고(LLM생성) |  |
| 18 | `CRMN_CTNT` |  |  | 캠페인내용(LLM생성) |  |
| 19 | `USE_YN` |  |  | 사용여부(LLM생성) |  |
| 20 | `PART_USE_YN` |  |  | 참여사용여부(LLM생성) |  |
| 21 | `TMPLAT_ID` |  |  | 템플릿ID(LLM생성) |  |
| 22 | `TMPLAT_TIT` |  |  | 템플릿제목(LLM생성) |  |
| 23 | `TMPLAT_PART_ID` |  |  | 템플릿참여ID(LLM생성) |  |
| 24 | `TMPLAT_PART_TIT` |  |  | 템플릿참여제목(LLM생성) |  |
| 25 | `FRST_RGSTR_ID` |  |  | 최초등록자ID(LLM생성) |  |
| 26 | `FRST_REGIST_DT` |  |  | 최초등록일시(LLM생성) |  |
| 27 | `LAST_UPDUSR_ID` |  |  | 최종수정자ID(LLM생성) |  |
| 28 | `LAST_UPDT_DT` |  |  | 최종수정일시(LLM생성) |  |
| 29 | `SRVY` |  |  | 설문조사(LLM생성) |  |
| 30 | `RM2` |  |  | 비고2(LLM생성) |  |
| 31 | `PROMO_CODE` |  |  | 프로모션코드(LLM생성) |  |

### TM_MS_EMAIL_SNDNG  (15 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `SNDNG_KEY` | N |  | 발신KEY |  |
| 2 | `SNDNG_CD_ID` | N |  | 발신코드ID |  |
| 3 | `SNDNG_DTL_CD_ID` | N |  | 발신상세코드ID |  |
| 4 | `SNDNG_STDR_DE` | N |  | 발신기준일 |  |
| 5 | `SNDNG_TY_CD` | Y | MS281 | 발신유형코드 | 0=대량;1=개별;2=비즈아이 // 코드 테이블에는 2번 비즈아이는 없음 하드코딩해서 쓰는 경우 |
| 6 | `TIT` | N |  | 제목 |  |
| 7 | `EMAIL_CTNT` | N |  | 이메일내용 |  |
| 8 | `EMAIL_RM` | N |  | 이메일비고 |  |
| 9 | `PRCS_DE` | N |  | 처리일 |  |
| 10 | `PCPSN_ID` | N |  | 처리자ID |  |
| 11 | `PRCS_YN` | Y |  | 처리여부 | Y=처리;N=처리안됨(1 존재) |
| 12 | `FRST_RGSTR_ID` | N |  | 최초등록자ID |  |
| 13 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 14 | `LAST_UPDUSR_ID` | N |  | 최종수정자ID |  |
| 15 | `LAST_UPDT_DT` | N |  | 최종수정일시 |  |

### TM_MS_EVENT  (11 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `EVENT_CD` |  |  | 이벤트코드(LLM생성) |  |
| 2 | `EVENT_DIV_CD` |  |  | 이벤트구분코드(LLM생성) |  |
| 3 | `EVENT_NM` |  |  | 이벤트명(LLM생성) |  |
| 4 | `STRT_DATE` |  |  | 시작일자(LLM생성) |  |
| 5 | `END_DATE` |  |  | 종료일자(LLM생성) |  |
| 6 | `PRZWIN_PSNNL_CO` |  |  | 당첨인원수(LLM생성) |  |
| 7 | `PRZWIN_GFT_SNDNG_DE` |  |  | 당첨선물발송일(LLM생성) |  |
| 8 | `FRST_RGSTR_ID` |  |  | 최초등록자ID(LLM생성) |  |
| 9 | `FRST_REGIST_DT` |  |  | 최초등록일시(LLM생성) |  |
| 10 | `LAST_UPDUSR_ID` |  |  | 최종수정자ID(LLM생성) |  |
| 11 | `LAST_UPDT_DT` |  |  | 최종수정일시(LLM생성) |  |

### TM_MS_MSG_AT_SNDNG  (21 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `SNDNG_KEY` | N |  | 발신KEY |  |
| 2 | `SNDNG_CD_ID` | N |  | 발신코드ID |  |
| 3 | `SNDNG_DTL_CD_ID` | N |  | 발신상세코드ID |  |
| 4 | `SNDNG_STDR_DE` | N |  | 발신기준일 |  |
| 5 | `SNDNG_TY_CD` | Y | MS281 | 발신유형코드 |  |
| 6 | `SNDNG_TIME_DIV_CD` | Y | MS267 | 발신시간구분코드 | 1=즉시발송;2=분할발송;3=예약발송(NULL 존재) |
| 7 | `MSG_DIV_CD` | Y | MS010 | 메시지구분코드 |  |
| 8 | `TIT` | N |  | 제목 |  |
| 9 | `MSG_AT_CTNT` | N |  | 메시지알림톡내용 |  |
| 10 | `MSG_AT_RM` | N |  | 메시지알림톡비고 |  |
| 11 | `PRCS_DE` | N |  | 처리일 |  |
| 12 | `PCPSN_ID` | N |  | 처리자ID |  |
| 13 | `ATCHFL_ID` | N |  | 첨부파일ID |  |
| 14 | `TMPLAT_ID` | N |  | 템플릿ID |  |
| 15 | `ALTRTV_MSG_SNDNG_YN` | Y |  | 대체메시지발신여부 | Y/N(빈값 및 NULL 존재) |
| 16 | `ALTRTV_MSG_CTNT` | N |  | 대체메시지내용 |  |
| 17 | `ALTRTV_MSG_ATCHFL_ID` | N |  | 대체메시지첨부파일ID |  |
| 18 | `FRST_RGSTR_ID` | N |  | 최초등록자ID |  |
| 19 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 20 | `LAST_UPDUSR_ID` | N |  | 최종수정자ID |  |
| 21 | `LAST_UPDT_DT` | N |  | 최종수정일시 |  |

### TM_MS_PSTMTR_SNDNG  (14 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `SNDNG_KEY` | N |  | 발신KEY |  |
| 2 | `SNDNG_CD_ID` | N |  | 발신코드ID |  |
| 3 | `SNDNG_DTL_CD_ID` | N |  | 발신상세코드ID |  |
| 4 | `SNDNG_STDR_DE` | N |  | 발신기준일 |  |
| 5 | `SNDNG_TY_CD` | Y | CM015 | 발신유형코드 |  |
| 6 | `PRCS_DE` | N |  | 처리일 |  |
| 7 | `PCPSN_ID` | N |  | 처리자ID |  |
| 8 | `PRCS_STAT_CD` | Y | MS061 | 처리상태코드 |  |
| 9 | `LQY_YN` | Y |  | 대량여부 | Y/N |
| 10 | `RE_SNDNG_YN` | Y |  | 재발신여부 | Y/N |
| 11 | `FRST_RGSTR_ID` | N |  | 최초등록자ID |  |
| 12 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 13 | `LAST_UPDUSR_ID` | N |  | 최종수정자ID |  |
| 14 | `LAST_UPDT_DT` | N |  | 최종수정일시 |  |

### TM_PM_DNTN_DTLS  (25 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `DNTN_KEY` | N |  | 기부금KEY |  |
| 2 | `ONCE_MBER_NO` | N |  | 일시후원회원번호 |  |
| 3 | `CPR_DIV_CD` | Y | CM019 | 법인구분코드 |  |
| 5 | `ONCE_CMPGN_CD` | Y |  | 일시후원캠페인코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 6 | `ELCTR_SETLE_KEY` | N |  | 전자결제KEY |  |
| 9 | `MBRFEE_BNKB_KEY` | N |  | 회비통장KEY |  |
| 10 | `ACNUT_SER_NO` | N |  | 계좌일련번호 |  |
| 11 | `FNLT_CD` | Y |  | 금융기관코드 | TM_PM_FNLT - FNLT_CD - FNLT_NM |
| 13 | `PAYER_NM` | N |  | 결제자명 |  |
| 14 | `PAY_AMT` | N |  | 납입금액 |  |
| 15 | `PAY_DE` | N |  | 납입일 |  |
| 16 | `PAY_STAT_CD` | Y |  | 납입상태코드 | S=성공;F=실패 |
| 17 | `PRCS_STAT_CD` | Y |  | 처리상태코드 | S= '완료' , F= '미완' (현시점 운영 DB 상에는 S만 존재) |
| 18 | `USE_YN` | Y |  | 사용여부 | Y/N |
| 19 | `TRNSFER_MBRFEE_KEY` | N |  | 이관회비KEY |  |
| 20 | `TRNSFER_RSN_CD` | Y |  | 이관사유코드 | NULL |
| 21 | `RETUN_DNTN_KEY` | N |  | 환급기부금KEY |  |
| 22 | `RETUN_RSN_CD` | Y | PM042 | 환급사유코드 |  |
| 23 | `RETUN_KEY` | N |  | 환급KEY |  |
| 24 | `RM` | N |  | 비고 |  |
| 25 | `ACMSLT_DEPT_CD` | Y | TM_CM_DEPT_INFO | 실적부서코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 26 | `REGIST_DE` | N |  | 등록일 |  |
| 27 | `RGSTR_ID` | N |  | 등록자ID |  |
| 28 | `RGSTR_NM` | N |  | 등록자명 |  |
| 29 | `SPNSR_BSNS_ID` | N |  | 후원사업ID |  |

### TM_PM_MBRFEE_ACMSLT  (51 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `MBRFEE_KEY` | N |  | 회비KEY |  |
| 2 | `MBER_DIV_CD` | Y | MM018 | 회원구분코드 |  |
| 3 | `MBER_NO` | N |  | 회원번호 |  |
| 4 | `CPR_DIV_CD` | Y | CM019 | 법인구분코드 |  |
| 5 | `SPNSR_NO` | N |  | 후원번호 |  |
| 6 | `SPNSR_BSNS_NO` | N |  | 후원사업번호 |  |
| 7 | `SPNSR_BSNS_ID` | N |  | 후원사업ID |  |
| 8 | `RELATNSP_KEY` | N |  | 결연KEY |  |
| 9 | `OVSEA_AID_KEY` | N |  | 해외구호KEY |  |
| 10 | `MBRFEE_MT` | N |  | 회비월 |  |
| 11 | `MBRFEE_SQNC` | N |  | 회비차수 |  |
| 12 | `RQEST_MT` | N |  | 청구월 |  |
| 13 | `RQEST_SQNC` | N |  | 청구차수 |  |
| 14 | `MBRFEE_DIV_CD` | Y | PM010 | 회비구분코드 |  |
| 15 | `GFT_DIV_CD` | Y | RM070 | 선물구분코드 |  |
| 16 | `GFTMNEY_CHILD_CD` | Y |  | 선물금아동코드 | TM_RM_CHILD_MSTR_INFO - CHILD_CD |
| 17 | `ONCE_CMPGN_CD` | Y |  | 일시후원캠페인코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 18 | `TOGETH_WTDRW_REQUST_KEY` | N |  | 함께출금요청KEY |  |
| 19 | `TOGETH_WTDRW_YN` | Y |  | 함께출금여부 | Y/N |
| 24 | `PAYER_NM` | N |  | 결제자명 |  |
| 25 | `RQEST_DIV_CD` | Y | PM024 | 청구구분코드 |  |
| 26 | `RQEST_AMT` | N |  | 청구금액 |  |
| 27 | `RQEST_DE` | N |  | 청구일 |  |
| 28 | `PAY_AMT` | N |  | 납입금액 |  |
| 29 | `PAY_DE` | N |  | 납입일 |  |
| 30 | `PAY_STAT_CD` | Y | PM012 | 납입상태코드 | S=성공;F=실패(NULL 존재) |
| 31 | `PRCS_STAT_CD` | Y | PM013 | 처리상태코드 |  |
| 32 | `RQST_KEY` | N |  | 신청KEY |  |
| 33 | `RST_KEY` | N |  | 결과KEY |  |
| 34 | `ELCTR_SETLE_KEY` | N |  | 전자결제KEY |  |
| 36 | `MBRFEE_BNKB_KEY` | N |  | 회비통장KEY |  |
| 37 | `ACNUT_SER_NO` | N |  | 계좌일련번호 |  |
| 38 | `FNLT_CD` | Y |  | 금융기관코드 | TM_PM_FNLT - FNLT_CD - FNLT_NM |
| 39 | `BILLKEY` | N |  | 빌키 |  |
| 40 | `RQEST_RST_CD` | Y | PM021 | 청구결과코드 |  |
| 41 | `PRCS_RST_CD` | Y |  | 처리결과코드 | S='납입 성공', '', 0, 00 |
| 42 | `TRNSFER_REQUST_KEY` | N |  | 이관요청KEY |  |
| 43 | `TRNSFER_MBRFEE_KEY` | N |  | 이관회비KEY |  |
| 44 | `TRNSFER_DNTN_KEY` | N |  | 이관기부금KEY |  |
| 45 | `TRNSFER_RSN_CD` | Y |  | 이관사유코드 | 1=이관;NULL |
| 46 | `RETUN_REQUST_KEY` | N |  | 환급요청KEY |  |
| 47 | `RETUN_MBRFEE_KEY` | N |  | 환급회비KEY |  |
| 48 | `RETUN_RSN_CD` | Y | PM042 | 환급사유코드 |  |
| 49 | `RM` | N |  | 비고 |  |
| 50 | `USE_YN` | Y |  | 사용여부 | Y/N |
| 51 | `OPERTOR_ID` | N |  | 작업자ID |  |
| 52 | `OPERTOR_NM` | N |  | 작업자명 |  |
| 53 | `OPERT_DE` | N |  | 작업일 |  |
| 54 | `OPERT_DIV_CD` | Y | MM014 | 작업구분코드 | 1=홈페이지, 2=CRM, 3=모바일웹, 4=희망TV, 5=외주콜센터, 6=모바일앱 |
| 55 | `OPER_KEY` | N |  | 운영KEY |  |
| 56 | `OPER_RST_KEY` | N |  | 운영결과KEY |  |

### TM_PM_SETLE_INFO  (48 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 2 | `MBER_NO` | N |  | 회원번호 |  |
| 3 | `CPR_DIV_CD` | Y | CM019 | 법인구분코드 |  |
| 5 | `WTDRW_STRT_DE` | N |  | 출금시작일 |  |
| 6 | `WTDRW_ASMT_SQNC` | N |  | 출금지정차수 |  |
| 7 | `WTDRW_ASMT_SQNC_UPDT_DE` | N |  | 출금지정차수수정일 |  |
| 8 | `FNLT_DIV_CD` | Y | PM050 | 금융기관구분코드 |  |
| 9 | `FNLT_CD` | Y |  | 금융기관코드 | TM_PM_FNLT - FNLT_CD - FNLT_NM |
| 12 | `CARD_TRMVT` | N |  | 카드유효기간 |  |
| 13 | `ACNUT_SER_NO` | N |  | 계좌일련번호 |  |
| 14 | `PAYER_NM` | N |  | 결제자명 |  |
| 15 | `CARD_DIV_CD` | Y | PM052 | 카드구분코드 | 0=개인;1=법인,2=개인,NULL=개인 |
| 16 | `PAYER_RRN_BIZRNO_ENC` | N |  | 결제자주민등록번호사업자등록번호암호화 |  |
| 17 | `MBTLNUM` | N |  | 휴대폰번호 |  |
| 18 | `ETC_CTTPC` | N |  | 기타연락처 |  |
| 19 | `ETC_CTTPC_REL_CD` | Y |  | 기타연락처관계코드 | CM009 |
| 20 | `PAYER_MBER_REL_CD` | Y |  | 결제자회원관계코드 | CM009 |
| 21 | `CRTFC_MTH_CD` | Y | MM014 | 인증방법코드 |  |
| 22 | `CRTFC_FILE_NM` | N |  | 인증파일명 |  |
| 23 | `CRTFC_DATA_CTNT` | N |  | 인증데이터내용 |  |
| 24 | `CRTFC_DE` | N |  | 인증일 |  |
| 25 | `FILE_SIZE` | N |  | 파일크기 |  |
| 26 | `BILLKEY` | N |  | 빌키 |  |
| 28 | `RQST_DIV_CD` | Y | PM004 | 신청구분코드 |  |
| 29 | `RCEPT_DIV_CD` | Y | PM003 | 접수구분코드 |  |
| 30 | `APRV_YN` | Y |  | 승인여부 | Y/N (NULL 존재) |
| 31 | `APRV_REQUST_KEY` | N |  | 승인요청KEY |  |
| 32 | `APRV_RST_KEY` | N |  | 승인결과KEY |  |
| 33 | `FRST_BEGIN_DE` | N |  | 최초개시일 |  |
| 34 | `RQEST_EXCL_YN` | Y |  | 청구제외여부 | Y/N |
| 35 | `RQEST_EXCL_STRT_DE` | N |  | 청구제외시작일 |  |
| 36 | `RQEST_EXCL_END_DE` | N |  | 청구제외종료일 |  |
| 37 | `APPLCNT_NM` | N |  | 신청자명 |  |
| 38 | `APPLCNT_RRN_ENC` | N |  | 신청자주민등록번호암호화 |  |
| 39 | `APPLCNT_MBTLNUM` | N |  | 신청자휴대폰번호 |  |
| 40 | `APPLCNT_ETC_CTTPC` | N |  | 신청자기타연락처 |  |
| 41 | `APPLCNT_ETC_CTTPC_REL_CD` | Y |  | 신청자기타연락처관계코드 | CM009 |
| 42 | `APPLCNT_MBER_REL_CD` | Y | CM009 | 신청자회원관계코드 |  |
| 43 | `BF_SETLE_KEY` | N |  | 이전결제KEY |  |
| 44 | `OPERT_DIV_CD` | Y |  | 작업구분코드 | 1='홈페이지', 2='CRM', 3='글로벌에듀' |
| 45 | `CARD_PWDNO_ENC` | N |  | 카드비밀번호암호화 |  |
| 46 | `CRTFC_TY_CD` | Y |  | 인증유형코드 | 0=계좌, 2=휴대폰, 3=카드, 계좌=NULL |
| 47 | `USE_YN` | Y |  | 사용여부 | Y/N |
| 48 | `FRST_RGSTR_ID` | N |  | 최초등록자ID |  |
| 49 | `FRST_RGSTR_NM` | N |  | 최초등록자명 |  |
| 50 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 51 | `LAST_UPDUSR_ID` | N |  | 최종수정자ID |  |
| 52 | `LAST_UPDUSR_NM` | N |  | 최종수정자명 |  |
| 53 | `LAST_UPDT_DT` | N |  | 최종수정일시 |  |

### TM_RM_BPLC_MNG  (18 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `BPLC_CD` | Y |  | 사업장코드 | TM_RM_BPLC_MNG - BPLC_CD - BPLC_KORNM |
| 2 | `NATION_CD` | Y |  | 국가코드 | TM_RM_NATION_MNG - NATION_CD - NATION_KORNM |
| 3 | `BPLC_KORNM` | N |  | 사업장한글명 |  |
| 4 | `BPLC_ENGNM` | N |  | 사업장영문명 |  |
| 5 | `BSNS_STRT_DE` | N |  | 사업시작일 |  |
| 6 | `BSNS_END_DE` | N |  | 사업종료일 |  |
| 7 | `RELATNSP_BSNS_YN` | Y |  | 결연사업여부 | Y/N |
| 8 | `RELATNSP_BSNS_DSCNTC_DE` | N |  | 결연사업중단일 |  |
| 9 | `GFTMNEY_PSBL_YN` | Y |  | 선물금가능여부 | Y/N |
| 10 | `LETTER_PSBL_YN` | Y |  | 서신가능여부 | Y/N |
| 11 | `BPLC_DC` | N |  | 사업장설명 |  |
| 12 | `WTWK_FROM_DSTNC` | N |  | 수도부터거리 |  |
| 13 | `CNCSN_RSN` | N |  | 종결사유 |  |
| 14 | `BPLC_MTCHG_MNG_YN` | Y |  | 사업장매칭관리여부 | Y/N |
| 15 | `FRST_RGSTR_ID` | N |  | 최초등록자ID |  |
| 16 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 17 | `LAST_UPDUSR_ID` | N |  | 최종수정자ID |  |
| 18 | `LAST_UPDT_DT` | N |  | 최종수정일시 |  |

### TM_RM_CHILD_MSTR_INFO  (16 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `CHILD_CD` | Y |  | 아동코드 | PK |
| 2 | `CHILD_NO` | N |  | 아동번호 |  |
| 3 | `BPLC_CD` | Y |  | 사업장코드 | TM_RM_BPLC_MNG - BPLC_CD - BPLC_KORNM |
| 4 | `CHILD_KORNM` | N |  | 아동한글명 |  |
| 5 | `CHILD_ENGNM` | N |  | 아동영문명 |  |
| 6 | `SEX` | N |  | 성별 | m='남자', M='남자', f='여자', F='여자' |
| 7 | `CHILD_BRTHDY` | N |  | 아동생년월일 |  |
| 8 | `RELATNSP_STAT_CD` | Y | RM076 | 결연상태코드 |  |
| 9 | `CHILD_STAT_CD` | Y | RM077 | 아동상태코드 |  |
| 10 | `CHILD_DTL_STAT_CD` | Y | RM078 | 아동상세상태코드 |  |
| 11 | `REGIST_DIV_CD` | Y |  | 등록구분코드 | 사용안함 |
| 12 | `FRST_REGIST_DT` | N |  | 최초등록일시 |  |
| 13 | `LAST_REGIST_DT` | N |  | 최종등록일시 |  |
| 14 | `RE_UPDT_DT` | N |  | 재수정일시 |  |
| 15 | `MNYRS_NATION_CD` | Y | RM023 | 모금국가코드 |  |
| 16 | `CMS_CHILD_NO` | N |  | CMS아동번호 |  |

### TM_RM_RELATNSP_CHG_INFO  (7 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `RELATNSP_KEY` | N |  | 결연KEY |  |
| 2 | `CHG_YN` | Y | RM079 | 교체여부 |  |
| 3 | `CHG_RSN_CD` | Y | RM066 | 교체사유코드 |  |
| 4 | `CHG_RST_CD` | Y |  | 교체결과코드 | NULL |
| 5 | `CHG_PERSON_ID` | N |  | 교체자ID |  |
| 6 | `CHG_DE` | N |  | 교체일 |  |
| 7 | `CHG_RELATNSP_KEY` | N |  | 교체결연KEY |  |

### TM_RM_RELATNSP_GFTMNEY_INFO  (19 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `RELATNSP_KEY` |  |  | 결연KEY(LLM생성) |  |
| 2 | `MNG_NO` |  |  | 관리번호(LLM생성) |  |
| 3 | `MBRFEE_KEY` |  |  | 회비KEY(LLM생성) |  |
| 4 | `SETLE_DE` |  |  | 결제일(LLM생성) |  |
| 5 | `SETLE_CD` |  |  | 결제코드(LLM생성) |  |
| 6 | `SETLE_BANK_CD` |  |  | 결제은행코드(LLM생성) |  |
| 7 | `SETLE_NO_ENC` |  |  | 결제번호암호화(LLM생성) |  |
| 8 | `GFTMNEY` |  |  | 선물금(LLM생성) |  |
| 9 | `GFT_DIV_CD` |  |  | 선물구분코드(LLM생성) |  |
| 10 | `KOREAN_RM_CTNT` |  |  | 한글비고내용(LLM생성) |  |
| 11 | `ENGL_RM_CTNT` |  |  | 영문비고내용(LLM생성) |  |
| 12 | `SNDNG_DE` |  |  | 발신일(LLM생성) |  |
| 13 | `EHGT` |  |  |  |  |
| 14 | `GFTMNEY_DOLLAR_AMT` |  |  | 선물금달러금액(LLM생성) |  |
| 15 | `APRV_DE` |  |  | 승인일(LLM생성) |  |
| 16 | `UNREPLY_RSN_CD` |  |  | 미회신사유코드(LLM생성) |  |
| 17 | `TRNSFER_KEY` |  |  | 이관KEY(LLM생성) |  |
| 18 | `TRNSFER_YN` |  |  | 이관여부(LLM생성) |  |
| 19 | `TRNSFER_AFTER_RELATNSP_KEY` |  |  | 이관후결연KEY(LLM생성) |  |

### TM_RM_RELATNSP_LETTER_INFO  (14 cols)

| # | 컬럼 | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|:--:|------|------|------|
| 1 | `RELATNSP_KEY` |  |  | 결연KEY(LLM생성) |  |
| 2 | `MNG_NO` |  |  | 관리번호(LLM생성) |  |
| 3 | `LETTER_DIV_CD` |  |  | 서신구분코드(LLM생성) |  |
| 4 | `CTNT` |  |  | 내용(LLM생성) |  |
| 5 | `RCEPT_DE` |  |  | 접수일(LLM생성) |  |
| 6 | `SNDNG_DE` |  |  | 발신일(LLM생성) |  |
| 7 | `ONLINE_POST_WRITNG_YN` |  |  | 온라인게시글작성여부(LLM생성) |  |
| 8 | `FRST_RGSTR_ID` |  |  | 최초등록자ID(LLM생성) |  |
| 9 | `FRST_REGIST_DE` |  |  | 최초등록일(LLM생성) |  |
| 10 | `EXCEL_SER_NO` |  |  | 엑셀일련번호(LLM생성) |  |
| 11 | `UNREPLY_RSN_CD` |  |  | 미회신사유코드(LLM생성) |  |
| 12 | `LANG_CD` |  |  | 언어코드(LLM생성) |  |
| 13 | `ONLINE_INFLOW_CD` |  |  | 온라인유입코드(LLM생성) |  |
| 14 | `LETTER_STAT_CD` |  |  | 서신상태코드(LLM생성) |  |

### TM_RM_RELATNSP_MSTR_INFO  (