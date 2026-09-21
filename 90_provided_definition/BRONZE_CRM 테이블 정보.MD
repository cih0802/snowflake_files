# BRONZE CRM 원천 테이블 인벤토리 (데이터 딕셔너리)
> 입고팀이 회신한 CRM 원천 테이블/컬럼 정의서. SILVER 정제·GOLD 매핑의 소스 of truth.
> 원본은 탭 구분(TSV) 평면 표였으며, LLM 파싱이 쉽도록 테이블별 구조화 표로 재구성함. **데이터 무손실**: 45개 테이블 / 929개 컬럼 (테이블 인덱스·상세 헤더 합계 기준. 2026-06 현업 +1테이블·+13컬럼 반영).
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

### 2026-07-14 컬럼정의서 CSV 기반 전면 갱신
- **정본**: `컬럼정의서 20260714.csv` (45개 테이블 / 929개 컬럼).
- **변경**: 데이터타입·NULL허용 컬럼 추가, 코드그룹ID 갱신, 한글설명·비고 최신화.
- **이전 LLM생성 태그**: CSV에 설명이 있는 컬럼은 CSV 값으로 대체(LLM생성 태그 제거됨). CSV에 설명이 없는 컬럼은 공란.

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

---

### TD_MS_EMAIL_LQY_SNDNG  (24 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `SNDNG_KEY` | NUMBER | YES | N |  | 발신KEY |  |
| 2 | `MSG_ID` | TEXT | YES | N |  | 메시지ID |  |
| 3 | `MKT_TRGET_CTNT` | TEXT | YES | N |  | 마케팅대상내용 |  |
| 4 | `SNDNG_CNT` | NUMBER | YES | N |  | 발신건수 |  |
| 5 | `SUCCES_CNT` | NUMBER | YES | N |  | 성공건수 |  |
| 6 | `FAILR_CNT` | FLOAT | YES | N |  | 실패건수 |  |
| 7 | `RECPTN_CNT` | FLOAT | YES | N |  | 수신건수 |  |
| 8 | `SNDNG_STRT_DT` | TIMESTAMP_NTZ | YES | N |  | 발신시작일시 |  |
| 9 | `SNDNG_END_DT` | TIMESTAMP_NTZ | YES | N |  | 발신종료일시 |  |
| 10 | `INFLOW_PATH_CTNT` | TEXT | YES | N |  | 유입경로내용 |  |
| 11 | `SNDNG_YEAR_CTNT` | TEXT | YES | N |  | 발신년도내용 |  |
| 12 | `SNDNG_MT_CTNT` | TEXT | YES | N |  | 발신월내용 |  |
| 13 | `SNDNG_TEAM_CTNT` | TEXT | YES | N |  | 발신팀내용 |  |
| 14 | `SUCCES_FAILR_CNT_CTNT` | TEXT | YES | N |  | 성공실패건수내용 |  |
| 15 | `URL_OTHBC_CNT_CTNT` | TEXT | YES | N |  | URL공개건수내용 |  |
| 16 | `URL_OTHBC_RT_CTNT` | TEXT | YES | N |  | URL공개율내용 |  |
| 17 | `SESION_VU_CTNT` | TEXT | YES | N |  | 세션값내용 |  |
| 18 | `SESION_PGE_CNT_CTNT` | TEXT | YES | N |  | 세션페이지건수내용 |  |
| 19 | `DVLP_ACMSLT_CNT_CTNT` | TEXT | YES | N |  | 개발실적건수내용 |  |
| 20 | `CLOS_YN` | TEXT | YES | Y |  | 마감여부 | 중요도 낮음. 현재까지 5개의 row만 데이터가 있음 |
| 21 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자ID |  |
| 22 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일시 |  |
| 23 | `LAST_UPDUSR_ID` | TEXT | YES | N |  | 최종수정자ID |  |
| 24 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES | N |  | 최종수정일시 |  |

### TD_MS_EMAIL_SNDNG_DTLS  (12 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `SNDNG_KEY` | NUMBER | YES | N |  | 발신KEY |  |
| 2 | `SNDNG_DTL_KEY` | NUMBER | YES | N |  | 발신상세KEY |  |
| 3 | `SNDNG_DE` | TIMESTAMP_NTZ | YES | N |  | 발신일 |  |
| 4 | `MBER_NO` | TEXT | YES | N |  | 회원번호 |  |
| 5 | `EMAIL` | TEXT | YES | N |  | 이메일 |  |
| 6 | `CHN_PARM_CTNT` | TEXT | YES | N |  | 치환파라미터내용 |  |
| 7 | `SNDNG_RST_CD` | TEXT | YES | Y | 하드코딩됨 | 발신결과코드 | 0=실패;1=성공;4=계정없음;5=도메인오류;그외=미처리 |
| 8 | `ATCHFL_ID` | TEXT | YES | N |  | 첨부파일ID |  |
| 9 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자ID |  |
| 10 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일시 |  |
| 11 | `LAST_UPDUSR_ID` | TEXT | YES | N |  | 최종수정자ID |  |
| 12 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES | N |  | 최종수정일시 |  |

### TD_MS_MSG_AT_LQY_SNDNG  (18 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `SNDNG_KEY` | NUMBER | YES | N |  | 발신KEY |  |
| 2 | `DIVS_DTL_KEY` | NUMBER | YES | N |  | 분할상세KEY |  |
| 3 | `SNDNG_CNT` | NUMBER | YES | N |  | 발신건수 |  |
| 4 | `SUCCES_CNT` | NUMBER | YES | N |  | 성공건수 |  |
| 5 | `AT_ALTRTV_SNDNG_CNT` | NUMBER | YES | N |  | 알림톡대체발송건수 |  |
| 6 | `AT_FAILR_CNT` | NUMBER | YES | N |  | 알림톡실패건수 |  |
| 7 | `RESVE_SNDNG_DE` | TEXT | YES | N |  | 예약발신일 |  |
| 8 | `RESVE_HM` | TEXT | YES | N |  | 예약시분 |  |
| 9 | `TOT_CLICK_CNT_CTNT` | TEXT | YES | N |  | 총클릭건수내용 |  |
| 10 | `CLICK_CNT_CTNT1` | TEXT | YES | N |  | 클릭건수내용1 |  |
| 11 | `CLICK_CNT_CTNT2` | TEXT | YES | N |  | 클릭건수내용2 |  |
| 12 | `CLICK_CNT_CTNT3` | TEXT | YES | N |  | 클릭건수내용3 |  |
| 13 | `CLICK_CNT_CTNT4` | TEXT | YES | N |  | 클릭건수내용4 |  |
| 14 | `RM_VU_CTNT` | TEXT | YES | N |  | 비고값내용 |  |
| 15 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자ID |  |
| 16 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일시 |  |
| 17 | `LAST_UPDUSR_ID` | TEXT | YES | N |  | 최종수정자ID |  |
| 18 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES | N |  | 최종수정일시 |  |

### TD_MS_MSG_AT_SNDNG_DTLS  (17 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `SNDNG_KEY` | NUMBER | YES | N |  | 발신KEY |  |
| 2 | `SNDNG_DTL_KEY` | NUMBER | YES | N |  | 발신상세KEY |  |
| 3 | `SNDNG_DT` | TIMESTAMP_NTZ | YES | N |  | 발신일시 |  |
| 4 | `MBER_NO` | TEXT | YES | N |  | 회원번호 |  |
| 5 | `MBER_KORNM` | TEXT | YES | N |  | 회원명 |  |
| 6 | `MBTLNUM` | TEXT | YES | N |  | 휴대폰번호 |  |
| 7 | `SNDNG_NO` | NUMBER | YES | N |  | 발신번호 |  |
| 8 | `TRNSMS_STAT_CD` | TEXT | YES | Y | MS282 | 전송상태코드 |  |
| 9 | `TRNSMS_FAILR_CD_ID` | TEXT | YES | N |  | 전송실패코드ID |  |
| 10 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 대체메시지발신여부 |  |
| 11 | `ALTRTV_MSG_SNDNG_YN` | TEXT | YES | Y |  | 대체문자 발송 여부 | Y= '대체문자 발송' / N = '대체문자 발송X' |
| 12 | `MSG_AT_CTNT` | TEXT | YES | N |  | 대체메시지내용 |  |
| 13 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록자ID |  |
| 14 | `LAST_UPDUSR_ID` | TEXT | YES | N |  | 최초등록일시 |  |
| 15 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES | N |  | 최종수정자ID |  |
| 16 | `ALTRTV_MSG_CTNT` | TEXT | YES | N |  | 최종수정일시 |  |
| 17 | `ATTACHED_FILE` | TEXT | YES | N |  | 첨부파일 |  |

### TD_MS_PSTMTR_LQY_SNDNG  (9 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `SNDNG_KEY` | NUMBER | YES | N |  | 발신KEY |  |
| 2 | `SNDNG_CNT` | NUMBER | YES | N |  | 발신건수 |  |
| 3 | `SNDNG_SQNC` | NUMBER | YES | N |  | 발신차수 |  |
| 4 | `SNDNG_TIT` | TEXT | YES | N |  | 발신제목 |  |
| 5 | `SNDNG_MEMO_CTNT` | TEXT | YES | N |  | 발신메모내용 |  |
| 6 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자ID |  |
| 7 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일시 |  |
| 8 | `LAST_UPDUSR_ID` | TEXT | YES | N |  | 최종수정자ID |  |
| 9 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES | N |  | 최종수정일시 |  |

### TD_MS_PSTMTR_SNDNG_DTL  (15 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `SNDNG_KEY` | NUMBER | YES | N |  | 발신KEY |  |
| 2 | `SNDNG_DTL_KEY` | NUMBER | YES | N |  | 발신상세KEY |  |
| 3 | `SNDNG_DE` | TIMESTAMP_NTZ | YES | N |  | 발신일 |  |
| 4 | `MBER_NO` | TEXT | YES | N |  | 회원번호 |  |
| 5 | `ZIP` | TEXT | YES | N |  | 우편번호 |  |
| 6 | `ADDR` | TEXT | YES | N |  | 주소 |  |
| 7 | `DTL_ADDR` | TEXT | YES | N |  | 상세주소 |  |
| 8 | `RELATNSP_KEY` | TEXT | YES | N |  | 결연KEY |  |
| 9 | `MNG_NO` | TEXT | YES | N |  | 관리번호 |  |
| 10 | `DTL_KEY` | TEXT | YES | N |  | 상세KEY |  |
| 11 | `BIZN_REQUST_KEY` | TEXT | YES | N |  | 업무요청KEY |  |
| 12 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자ID |  |
| 13 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일시 |  |
| 14 | `LAST_UPDUSR_ID` | TEXT | YES | N |  | 최종수정자ID |  |
| 15 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES | N |  | 최종수정일시 |  |

### TM_CM_BRND_MNG  (9 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `BRND_ID` | TEXT | YES | N |  | 브랜드ID |  |
| 2 | `BRND_NM` | TEXT | YES | N |  | 브랜드명 |  |
| 3 | `USE_DEPT_CD` | TEXT | YES | Y |  | 사용부서코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 4 | `USE_YN` | TEXT | YES | Y |  | 사용여부 | Y/N |
| 5 | `PR_MTH_LIST` | TEXT | YES | N |  | 홍보방법리스트 |  |
| 6 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자ID |  |
| 7 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일시 |  |
| 8 | `LAST_UPDUSR_ID` | TEXT | YES | N |  | 최종수정자ID |  |
| 9 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES | N |  | 최종수정일시 |  |

### TM_CM_CMPGN_MNG  (32 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `CMPGN_CD` | TEXT | YES | N |  | 캠페인코드 |  |
| 2 | `CMPGN_NM` | TEXT | YES | N |  | 캠페인명 |  |
| 3 | `UPPER_CMPGN_CD` | TEXT | YES | N |  | 상위캠페인코드 |  |
| 4 | `UPPER_CMPGN_YN` | TEXT | YES | Y |  | 상위캠페인여부 | Y/N |
| 5 | `SPNSR_DIV_CD` | TEXT | YES | Y | CM035 | 후원구분코드 | 1=정기후원; 2=일시후원 |
| 6 | `CPR_DIV_CD` | TEXT | YES | Y | CM019 | 법인구분코드 |  |
| 7 | `CMPGN_TRGET_CD` | TEXT | YES | Y | CM002 | 캠페인대상코드 |  |
| 8 | `USE_DEPT_CD` | TEXT | YES | Y |  | 사용부서코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 9 | `USE_SCOPE` | TEXT | YES | N |  | 사용범위 |  |
| 10 | `SPNSR_ENTRPRS_ID` | TEXT | YES | N |  | 후원기업ID |  |
| 11 | `BRND_ID` | TEXT | YES | N |  | 브랜드ID |  |
| 12 | `PR_MTH_CD` | TEXT | YES | Y | CM008 | 홍보방법코드 |  |
| 13 | `CMPGN_STRT_DE` | TEXT | YES | N |  | 캠페인시작일 |  |
| 14 | `MBRFEE_BNKB_LIST` | TEXT | YES | N |  | 회비통장리스트 |  |
| 15 | `INICIS_ACNT_NO` | TEXT | YES | N |  | 이니시스계정번호 |  |
| 16 | `USE_YN` | TEXT | YES | Y |  | 사용여부 | Y/N |
| 17 | `REFER_URL` | TEXT | YES | N |  | 참고URL |  |
| 18 | `SPNSR_BSNS_ID` | TEXT | YES | N |  | 후원사업ID |  |
| 19 | `CMPGN_DC` | TEXT | YES | N |  | 캠페인설명 |  |
| 20 | `EMRGNCY_AID_BPLC_CD` | TEXT | YES | Y |  | 긴급구호사업장코드 | TM_CM_EMRGNCY_AID_BPLC - EMRGNCY_AID_BPLC_CD - EMRGNCY_AID_NM |
| 21 | `CMPGN_PRPT_YN` | TEXT | YES | Y |  | 캠페인특성여부 | Y/N |
| 22 | `ATCHFL_ID` | TEXT | YES | N |  | 첨부파일ID |  |
| 23 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자ID |  |
| 24 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일시 |  |
| 25 | `LAST_UPDUSR_ID` | TEXT | YES | N |  | 최종수정자ID |  |
| 26 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES | N |  | 최종수정일시 |  |
| 27 | `RM` | TEXT | YES | N |  | 비고 |  |
| 28 | `MBER_INFLOW_PATH_CD` | NUMBER | YES | Y | MM293 | 개발인입경로 |  |
| 29 | `CMPGN_CTGR_CD` | NUMBER | YES | Y | MM294 | 캠페인 카테고리 |  |
| 30 | `CMPGN_TYPE1_BSN` | NUMBER | YES | Y | MM295 | 캠페인유형(국내/해외) |  |
| 31 | `CMPGN_TYPE2_BSN` | NUMBER | YES | Y | MM296 | 캠페인유형(사업/사례) |  |
| 32 | `MKTG_CMPGN_NM` | NUMBER | YES | Y | TM_CM_MKTNG_CMPGN_MNG | 마케팅갬페인명 | TM_CM_MKTNG_CMPGN_MNG 테이블의 MK_CMPGN_CD에 연결되며, MK_CMPGN_NM을 사용하면 됨 |

### TM_CM_DEPT_INFO  (12 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `DEPT_ID` | TEXT | YES | N |  | 부서ID |  |
| 2 | `DEPT_NM` | TEXT | YES | N |  | 부서명 |  |
| 3 | `UPPER_DEPT_ID` | TEXT | YES | N |  | 상위부서ID |  |
| 4 | `SORT_ORDR` | TEXT | YES | N |  | 정렬순서 |  |
| 5 | `USE_YN` | TEXT | YES | Y |  | 사용여부 | Y/N |
| 6 | `ACMSLT_DEPT_YN` | TEXT | YES | Y |  | 실적부서여부 | Y/N |
| 7 | `STATS_DEPT_LVL` | TEXT | YES | N |  | 통계부서레벨 |  |
| 8 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자ID |  |
| 9 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일시 |  |
| 10 | `LAST_UPDUSR_ID` | TEXT | YES | N |  | 최종수정자ID |  |
| 11 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES | N |  | 최종수정일시 |  |
| 12 | `ACMSLT_UPPER_DEPT_ID` | TEXT | YES | N |  | 실적상위부서ID |  |

### TM_MM_FDRM_MBER_DVLP_AMT  (20 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `SPNSR_NO` | TEXT | YES | N |  | 후원번호 |  |
| 2 | `SPNSR_BSNS_NO` | NUMBER | YES | N |  | 후원사업번호 |  |
| 3 | `OCCRRNC_DE` | TEXT | YES | N |  | 발생일 |  |
| 4 | `SER_NO` | NUMBER | YES | N |  | 일련번호 |  |
| 5 | `MBER_NO` | TEXT | YES | N |  | 회원번호 |  |
| 6 | `ACT_DEPT_CD` | TEXT | YES | Y |  | 활동부서코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 7 | `ACMSLT_DEPT_CD` | TEXT | YES | Y |  | 실적부서코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 8 | `CMPGN_CD` | TEXT | YES | Y |  | 캠페인코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 10 | `MBER_DIV_CD` | TEXT | YES | Y | MM018 | 회원구분코드 |  |
| 11 | `SEX` | TEXT | YES | N | CM013 | 성별 | 특이사항, 6=단체, 7=기업, 8=기타 값을 보면. 컬럼설명은 성별이나 성별만으로는 사용하지는 않음 |
| 12 | `AREA_CD` | TEXT | YES | Y | CM018 | 지역코드 |  |
| 13 | `AGE` | NUMBER | YES | N |  | 연령 |  |
| 14 | `SPNSR_TIME_CO` | NUMBER | YES | N |  | 후원시간수 |  |
| 15 | `SPNSR_AMT_CD` | TEXT | YES | Y | CM012 | 후원금액코드 |  |
| 16 | `SPNSR_BSNS_ID` | TEXT | YES | N |  | 후원사업ID |  |
| 17 | `CANCL_RDCAMT_RSN_CD` | TEXT | YES | Y | MM002 | 취소감액사유코드 |  |
| 18 | `SPNSR_AMT` | NUMBER | YES | N |  | 후원금액 |  |
| 19 | `DVLP_DIV_CD` | TEXT | YES | Y | MM015 | 개발구분코드 |  |
| 20 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자ID |  |
| 21 | `FRST_RGSTR_NM` | TEXT | YES | N |  | 최초등록자명 |  |

### TM_MM_FDRM_MBER_INFO  (41 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `MBER_NO` | TEXT | YES | N |  | 회원번호 |  |
| 2 | `MBER_DIV_CD` | TEXT | YES | Y | MM018 | 회원구분코드 | 1=개인;2=기업;3=단체 |
| 3 | `CPR_DIV_CD` | TEXT | YES | Y | CM019 | 법인구분코드 | I=사단, S=사복, A=통합 |
| 4 | `RRN_FSTDGT` | TEXT | YES | N |  | 주민등록번호앞자리 |  |
| 5 | `RRN_LSTDGT_ENC` | TEXT | YES | N |  | 주민등록번호뒷자리암호화 |  |
| 6 | `BRTHDY` | TEXT | YES | N |  | 생년월일 |  |
| 7 | `SLRCLD_LRR_CD` | TEXT | YES | Y | CM029 | 양력음력코드 |  |
| 8 | `MBER_KORNM` | TEXT | YES | N |  | 회원한글명 |  |
| 9 | `MBER_ENGNM` | TEXT | YES | N |  | 회원영문명 |  |
| 10 | `MBTLNUM` | TEXT | YES | N |  | 휴대폰번호 |  |
| 11 | `MOBLPHON_STAT_CD` | TEXT | YES | Y | MM008 | 휴대폰상태코드 |  |
| 12 | `TSTM_DIV_CD` | FLOAT | YES | Y | MS026 | TSTM구분코드 |  |
| 13 | `ETC_CTTPC` | TEXT | YES | N |  | 기타연락처 |  |
| 14 | `ETC_TSTM_DIV_CD` | FLOAT | YES | Y | MS026 | 기타TSTM구분코드 |  |
| 15 | `ETC_CTTPC_REL_CD` | TEXT | YES | Y | MM008 | 기타연락처관계코드 |  |
| 16 | `ETC_CTTPC_STAT_CD` | TEXT | YES | Y | MM008 | 기타연락처상태코드 |  |
| 17 | `FAXNO` | TEXT | YES | N |  | 팩스번호 |  |
| 18 | `ZIP` | TEXT | YES | N |  | 우편번호 |  |
| 19 | `ADDR` | TEXT | YES | N |  | 주소 |  |
| 20 | `DTL_ADDR` | TEXT | YES | N |  | 상세주소 |  |
| 21 | `EMAIL` | TEXT | YES | N |  | 이메일 |  |
| 22 | `EMAIL_STAT_CD` | TEXT | YES | Y | MM009 | 이메일상태코드 |  |
| 23 | `PSTMTR_RECPTN_CD` | TEXT | YES | Y | MS027 | 우편물수신코드 |  |
| 24 | `EMAIL_RECPTN_CD` | TEXT | YES | Y | MS028 | 이메일수신코드 |  |
| 25 | `CHRCTR_RECPTN_YN` | TEXT | YES | Y |  | 문자수신여부 | Y/N (빈값 및 Null 존재) |
| 26 | `BL_ENTRPS_NO` | FLOAT | YES | N |  | 소속업체번호 |  |
| 27 | `SPECL_MNG_CD1` | TEXT | YES | N |  | 특별관리코드1 |  |
| 28 | `SPECL_MNG_CD2` | TEXT | YES | N |  | 특별관리코드2 |  |
| 29 | `TNI_CU_BL_NO` | TEXT | YES | N |  | 더네이버스클럽소속번호 |  |
| 30 | `CMPGN_CD` | TEXT | YES | Y |  | 캠페인코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 31 | `MBER_STAT_CD` | TEXT | YES | Y | MM010 | 회원상태코드 |  |
| 32 | `RELATNSP_DIV_CD` | TEXT | YES | Y | MM019 | 결연구분코드 | 1=신규;2=결연회원;3=비결연회원;4=혼합회원;5=후원중단 (빈값 및 NULL 존재) |
| 33 | `ACT_DEPT_CD` | TEXT | YES | Y |  | 활동부서코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 34 | `HMPG_ID` | TEXT | YES | N |  | 홈페이지ID |  |
| 35 | `JOIN_PATH_CD` | TEXT | YES | Y | MM014 | 가입경로코드 |  |
| 36 | `CTI_SYNCHRN_DIV_CD` | TEXT | YES | Y |  | CTI동기화구분코드 | 사용하지 않음 |
| 37 | `STDR_DE` | TEXT | YES | N |  | 기준일 |  |
| 38 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일시 |  |
| 39 | `REGIST_DEPT_CD` | TEXT | YES | Y | TM_CM_DEPT_INFO | 등록부서코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 40 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자ID |  |
| 41 | `SEX` | TEXT | YES | N | CM013 | 성별 | 특이사항, 6=단체, 7=기업, 8=기타 값을 보면. 컬럼설명은 성별이나 성별만으로는 사용하지는 않음 |

### TM_MM_ONCE_MBER_INFO  (32 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `ONCE_MBER_NO` | TEXT | YES | N |  | 일시후원회원번호 |  |
| 2 | `MBER_DIV_CD` | TEXT | YES | Y | MM018 | 회원구분코드 | 1=개인, 2=기업, 3=단체 |
| 3 | `CPR_DIV_CD` | TEXT | YES | Y | CM019 | 법인구분코드 | I=사단, S=사복, A=통합 |
| 4 | `RRN_FSTDGT` | TEXT | YES | N |  | 주민등록번호앞자리 |  |
| 5 | `RRN_LSTDGT_ENC` | TEXT | YES | N |  | 주민등록번호뒷자리암호화 |  |
| 6 | `SEX` | TEXT | YES | N | CM013 | 성별 | 특이사항, 6=단체, 7=기업, 8=기타 값을 보면. 컬럼설명은 성별이나 성별만으로는 사용하지는 않음 |
| 7 | `MBER_KORNM` | TEXT | YES | N |  | 회원한글명 |  |
| 8 | `MBER_ENGNM` | TEXT | YES | N |  | 회원영문명 |  |
| 9 | `BRTHDY` | TEXT | YES | N |  | 생년월일 |  |
| 10 | `MBTLNUM` | TEXT | YES | N |  | 휴대폰번호 |  |
| 11 | `TSTM_DIV_CD` | NUMBER | YES | Y | MS026 | TSTM구분코드 | 1=TM거절, 2=TS거절, 3=TMTS거절 |
| 12 | `ETC_CTTPC` | TEXT | YES | N |  | 기타연락처 |  |
| 13 | `ETC_TSTM_DIV_CD` | NUMBER | YES | Y | MS026 | 기타TSTM구분코드 | 1=TM거절, 2=TS거절, 3=TMTS거절 |
| 14 | `REL_CD` | TEXT | YES | Y | CM009 | 관계코드 |  |
| 15 | `ZIP` | TEXT | YES | N |  | 우편번호 |  |
| 16 | `ADDR` | TEXT | YES | N |  | 주소 |  |
| 17 | `DTL_ADDR` | TEXT | YES | N |  | 상세주소 |  |
| 18 | `EMAIL` | TEXT | YES | N |  | 이메일 |  |
| 19 | `FAXNO` | TEXT | YES | N |  | 팩스번호 |  |
| 20 | `ENTRPS_NM` | TEXT | YES | N |  | 업체명 |  |
| 21 | `HMPG_ID` | TEXT | YES | N |  | 홈페이지ID |  |
| 22 | `PSTMTR_RECPTN_YN` | TEXT | YES | Y |  | 우편물수신여부 | Y/N(NULL 존재) |
| 23 | `EMAIL_RECPTN_YN` | TEXT | YES | Y |  | 이메일수신여부 | Y/N(NULL 존재) |
| 24 | `CHRCTR_RECPTN_YN` | TEXT | YES | Y |  | 문자수신여부 | Y/N(NULL 존재) |
| 25 | `FDRM_MBER_TRNSFER_FG` | TEXT | YES | N |  | 정기회원이관유무 |  |
| 26 | `SPECL_MNG_CD1` | TEXT | YES | N |  | 특별관리코드1 |  |
| 27 | `SPECL_MNG_CD2` | TEXT | YES | N |  | 특별관리코드2 |  |
| 28 | `TNI_CU_BL_NO` | TEXT | YES | N |  | 더네이버스클럽소속번호 |  |
| 29 | `CTI_SYNCHRN_DIV_CD` | TEXT | YES |  |  | CTI동기화구분코드 | 사용하지 않음 |
| 30 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일시 |  |
| 31 | `REGIST_DEPT_CD` | TEXT | YES | Y | TM_CM_DEPT_INFO | 등록부서코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 32 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자ID |  |

### TM_MS_EMAIL_SNDNG  (15 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `SNDNG_KEY` | NUMBER | YES | N |  | 발신KEY |  |
| 2 | `SNDNG_CD_ID` | TEXT | YES | N |  | 발신코드ID |  |
| 3 | `SNDNG_DTL_CD_ID` | TEXT | YES | N |  | 발신상세코드ID |  |
| 4 | `SNDNG_STDR_DE` | TIMESTAMP_NTZ | YES | N |  | 발신기준일 |  |
| 5 | `SNDNG_TY_CD` | TEXT | YES | Y | MS281 | 발신유형코드 | 0=대량;1=개별;2=비즈아이 // 코드 테이블에는 2번 비즈아이는 없음 하드코딩해서 쓰는 경우 |
| 6 | `TIT` | TEXT | YES | N |  | 제목 |  |
| 7 | `EMAIL_CTNT` | TEXT | YES | N |  | 이메일내용 |  |
| 8 | `EMAIL_RM` | TEXT | YES | N |  | 이메일비고 |  |
| 9 | `PRCS_DE` | TIMESTAMP_NTZ | YES | N |  | 처리일 |  |
| 10 | `PCPSN_ID` | TEXT | YES | N |  | 처리자ID |  |
| 11 | `PRCS_YN` | TEXT | YES | Y |  | 처리여부 | Y=처리;N=처리안됨(1 존재) |
| 12 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자ID |  |
| 13 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일시 |  |
| 14 | `LAST_UPDUSR_ID` | TEXT | YES | N |  | 최종수정자ID |  |
| 15 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES | N |  | 최종수정일시 |  |

### TM_MS_MSG_AT_SNDNG  (21 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `SNDNG_KEY` | NUMBER | YES | N |  | 발신KEY |  |
| 2 | `SNDNG_CD_ID` | TEXT | YES | N |  | 발신코드ID |  |
| 3 | `SNDNG_DTL_CD_ID` | TEXT | YES | N |  | 발신상세코드ID |  |
| 4 | `SNDNG_STDR_DE` | TIMESTAMP_NTZ | YES | N |  | 발신기준일 |  |
| 5 | `SNDNG_TY_CD` | TEXT | YES | Y | MS281 | 발신유형코드 |  |
| 6 | `SNDNG_TIME_DIV_CD` | TEXT | YES | Y | MS267 | 발신시간구분코드 | 1=즉시발송;2=분할발송;3=예약발송(NULL 존재) |
| 7 | `MSG_DIV_CD` | TEXT | YES | Y | MS010 | 메시지구분코드 |  |
| 8 | `TIT` | TEXT | YES | N |  | 제목 |  |
| 9 | `MSG_AT_CTNT` | TEXT | YES | N |  | 메시지알림톡내용 |  |
| 10 | `MSG_AT_RM` | TEXT | YES | N |  | 메시지알림톡비고 |  |
| 11 | `PRCS_DE` | TIMESTAMP_NTZ | YES | N |  | 처리일 |  |
| 12 | `PCPSN_ID` | TEXT | YES | N |  | 처리자ID |  |
| 13 | `ATCHFL_ID` | TEXT | YES | N |  | 첨부파일ID |  |
| 14 | `TMPLAT_ID` | TEXT | YES | N |  | 템플릿ID |  |
| 15 | `ALTRTV_MSG_SNDNG_YN` | TEXT | YES | Y |  | 대체메시지발신여부 | Y/N(빈값 및 NULL 존재) |
| 16 | `ALTRTV_MSG_CTNT` | TEXT | YES | N |  | 대체메시지내용 |  |
| 17 | `ALTRTV_MSG_ATCHFL_ID` | TEXT | YES | N |  | 대체메시지첨부파일ID |  |
| 18 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자ID |  |
| 19 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일시 |  |
| 20 | `LAST_UPDUSR_ID` | TEXT | YES | N |  | 최종수정자ID |  |
| 21 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES | N |  | 최종수정일시 |  |

### TM_MS_PSTMTR_SNDNG  (14 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `SNDNG_KEY` | NUMBER | YES | N |  | 발신KEY |  |
| 2 | `SNDNG_CD_ID` | TEXT | YES | N |  | 발신코드ID |  |
| 3 | `SNDNG_DTL_CD_ID` | TEXT | YES | N |  | 발신상세코드ID |  |
| 4 | `SNDNG_STDR_DE` | TEXT | YES | N |  | 발신기준일 |  |
| 5 | `SNDNG_TY_CD` | TEXT | YES | Y | CM015 | 발신유형코드 |  |
| 6 | `PRCS_DE` | TEXT | YES | N |  | 처리일 |  |
| 7 | `PCPSN_ID` | TEXT | YES | N |  | 처리자ID |  |
| 8 | `PRCS_STAT_CD` | TEXT | YES | Y | MS061 | 처리상태코드 |  |
| 9 | `LQY_YN` | TEXT | YES | Y |  | 대량여부 | Y/N |
| 10 | `RE_SNDNG_YN` | TEXT | YES | Y |  | 재발신여부 | Y/N |
| 11 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자ID |  |
| 12 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일시 |  |
| 13 | `LAST_UPDUSR_ID` | TEXT | YES | N |  | 최종수정자ID |  |
| 14 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES | N |  | 최종수정일시 |  |

### TM_PM_DNTN_DTLS  (25 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `DNTN_KEY` | NUMBER | YES | N |  | 기부금KEY |  |
| 2 | `ONCE_MBER_NO` | TEXT | YES | N |  | 일시후원회원번호 |  |
| 3 | `CPR_DIV_CD` | TEXT | YES | Y | CM019 | 법인구분코드 |  |
| 5 | `ONCE_CMPGN_CD` | TEXT | YES | Y |  | 일시후원캠페인코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 6 | `ELCTR_SETLE_KEY` | FLOAT | YES | N |  | 전자결제KEY |  |
| 9 | `MBRFEE_BNKB_KEY` | FLOAT | YES | N |  | 회비통장KEY |  |
| 10 | `ACNUT_SER_NO` | FLOAT | YES | N |  | 계좌일련번호 |  |
| 11 | `FNLT_CD` | TEXT | YES | Y |  | 금융기관코드 | TM_PM_FNLT - FNLT_CD - FNLT_NM |
| 13 | `PAYER_NM` | TEXT | YES | N |  | 결제자명 |  |
| 14 | `PAY_AMT` | NUMBER | YES | N |  | 납입금액 |  |
| 15 | `PAY_DE` | TEXT | YES | N |  | 납입일 |  |
| 16 | `PAY_STAT_CD` | TEXT | YES | Y |  | 납입상태코드 | S=성공;F=실패 |
| 17 | `PRCS_STAT_CD` | TEXT | YES | Y |  | 처리상태코드 | S= '완료' , F= '미완' (현시점 운영 DB 상에는 S만 존재) |
| 18 | `USE_YN` | TEXT | YES | Y |  | 사용여부 | Y/N |
| 19 | `TRNSFER_MBRFEE_KEY` | FLOAT | YES | N |  | 이관회비KEY |  |
| 20 | `TRNSFER_RSN_CD` | TEXT | YES | Y |  | 이관사유코드 | NULL |
| 21 | `RETUN_DNTN_KEY` | TEXT | YES | N |  | 환급기부금KEY |  |
| 22 | `RETUN_RSN_CD` | TEXT | YES | Y | PM042 | 환급사유코드 |  |
| 23 | `RETUN_KEY` | TEXT | YES | N |  | 환급KEY |  |
| 24 | `RM` | TEXT | YES | N |  | 비고 |  |
| 25 | `ACMSLT_DEPT_CD` | TEXT | YES | Y | TM_CM_DEPT_INFO | 실적부서코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 26 | `REGIST_DE` | TEXT | YES | N |  | 등록일 |  |
| 27 | `RGSTR_ID` | TEXT | YES | N |  | 등록자ID |  |
| 28 | `RGSTR_NM` | TEXT | YES | N |  | 등록자명 |  |
| 29 | `SPNSR_BSNS_ID` | TEXT | YES | N |  | 후원사업ID |  |

### TM_PM_MBRFEE_ACMSLT  (51 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `MBRFEE_KEY` | NUMBER | YES | N |  | 회비KEY |  |
| 2 | `MBER_DIV_CD` | TEXT | YES | Y | MM018 | 회원구분코드 |  |
| 3 | `MBER_NO` | TEXT | YES | N |  | 회원번호 |  |
| 4 | `CPR_DIV_CD` | TEXT | YES | Y | CM019 | 법인구분코드 |  |
| 5 | `SPNSR_NO` | TEXT | YES | N |  | 후원번호 |  |
| 6 | `SPNSR_BSNS_NO` | NUMBER | YES | N |  | 후원사업번호 |  |
| 7 | `SPNSR_BSNS_ID` | TEXT | YES | N |  | 후원사업ID |  |
| 8 | `RELATNSP_KEY` | TEXT | YES | N |  | 결연KEY |  |
| 9 | `OVSEA_AID_KEY` | TEXT | YES | N |  | 해외구호KEY |  |
| 10 | `MBRFEE_MT` | TEXT | YES | N |  | 회비월 |  |
| 11 | `MBRFEE_SQNC` | NUMBER | YES | N |  | 회비차수 |  |
| 12 | `RQEST_MT` | TEXT | YES | N |  | 청구월 |  |
| 13 | `RQEST_SQNC` | NUMBER | YES | N |  | 청구차수 |  |
| 14 | `MBRFEE_DIV_CD` | TEXT | YES | Y | PM010 | 회비구분코드 |  |
| 15 | `GFT_DIV_CD` | TEXT | YES | Y | RM070 | 선물구분코드 |  |
| 16 | `GFTMNEY_CHILD_CD` | TEXT | YES | Y |  | 선물금아동코드 | TM_RM_CHILD_MSTR_INFO - CHILD_CD |
| 17 | `ONCE_CMPGN_CD` | TEXT | YES | Y |  | 일시후원캠페인코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 18 | `TOGETH_WTDRW_REQUST_KEY` | TEXT | YES | N |  | 함께출금요청KEY |  |
| 19 | `TOGETH_WTDRW_YN` | TEXT | YES | Y |  | 함께출금여부 | Y/N |
| 24 | `PAYER_NM` | TEXT | YES | N |  | 결제자명 |  |
| 25 | `RQEST_DIV_CD` | TEXT | YES | Y | PM024 | 청구구분코드 |  |
| 26 | `RQEST_AMT` | NUMBER | YES | N |  | 청구금액 |  |
| 27 | `RQEST_DE` | TEXT | YES | N |  | 청구일 |  |
| 28 | `PAY_AMT` | NUMBER | YES | N |  | 납입금액 |  |
| 29 | `PAY_DE` | TEXT | YES | N |  | 납입일 |  |
| 30 | `PAY_STAT_CD` | TEXT | YES | Y | PM012 | 납입상태코드 | S=성공;F=실패(NULL 존재) |
| 31 | `PRCS_STAT_CD` | TEXT | YES | Y | PM013 | 처리상태코드 |  |
| 32 | `RQST_KEY` | NUMBER | YES | N |  | 신청KEY |  |
| 33 | `RST_KEY` | TEXT | YES | N |  | 결과KEY |  |
| 34 | `ELCTR_SETLE_KEY` | TEXT | YES | N |  | 전자결제KEY |  |
| 36 | `MBRFEE_BNKB_KEY` | TEXT | YES | N |  | 회비통장KEY |  |
| 37 | `ACNUT_SER_NO` | TEXT | YES | N |  | 계좌일련번호 |  |
| 38 | `FNLT_CD` | TEXT | YES | Y |  | 금융기관코드 | TM_PM_FNLT - FNLT_CD - FNLT_NM |
| 39 | `BILLKEY` | TEXT | YES | N |  | 빌키 |  |
| 40 | `RQEST_RST_CD` | TEXT | YES | Y | PM021 | 청구결과코드 |  |
| 41 | `PRCS_RST_CD` | TEXT | YES | Y |  | 처리결과코드 | S='납입 성공', '', 0, 00 |
| 42 | `TRNSFER_REQUST_KEY` | TEXT | YES | N |  | 이관요청KEY |  |
| 43 | `TRNSFER_MBRFEE_KEY` | TEXT | YES | N |  | 이관회비KEY |  |
| 44 | `TRNSFER_DNTN_KEY` | TEXT | YES | N |  | 이관기부금KEY |  |
| 45 | `TRNSFER_RSN_CD` | TEXT | YES | Y |  | 이관사유코드 | 1=이관;NULL |
| 46 | `RETUN_REQUST_KEY` | TEXT | YES | N |  | 환급요청KEY |  |
| 47 | `RETUN_MBRFEE_KEY` | TEXT | YES | N |  | 환급회비KEY |  |
| 48 | `RETUN_RSN_CD` | TEXT | YES | Y | PM042 | 환급사유코드 |  |
| 49 | `RM` | TEXT | YES | N |  | 비고 |  |
| 50 | `USE_YN` | TEXT | YES | Y |  | 사용여부 | Y/N |
| 51 | `OPERTOR_ID` | TEXT | YES | N |  | 작업자ID |  |
| 52 | `OPERTOR_NM` | TEXT | YES | N |  | 작업자명 |  |
| 53 | `OPERT_DE` | TEXT | YES | N |  | 작업일 |  |
| 54 | `OPERT_DIV_CD` | TEXT | YES | Y | MM014 | 작업구분코드 | 1=홈페이지, 2=CRM, 3=모바일웹, 4=희망TV, 5=외주콜센터, 6=모바일앱 |
| 55 | `OPER_KEY` | NUMBER | YES | N |  | 운영KEY |  |
| 56 | `OPER_RST_KEY` | NUMBER | YES | N |  | 운영결과KEY |  |

### TM_PM_SETLE_INFO  (48 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 2 | `MBER_NO` | TEXT | YES | N |  | 회원번호 |  |
| 3 | `CPR_DIV_CD` | TEXT | YES | Y | CM019 | 법인구분코드 |  |
| 5 | `WTDRW_STRT_DE` | TEXT | YES | N |  | 출금시작일 |  |
| 6 | `WTDRW_ASMT_SQNC` | NUMBER | YES | N |  | 출금지정차수 |  |
| 7 | `WTDRW_ASMT_SQNC_UPDT_DE` | TEXT | YES | N |  | 출금지정차수수정일 |  |
| 8 | `FNLT_DIV_CD` | TEXT | YES | Y | PM050 | 금융기관구분코드 |  |
| 9 | `FNLT_CD` | TEXT | YES | Y |  | 금융기관코드 | TM_PM_FNLT - FNLT_CD - FNLT_NM |
| 12 | `CARD_TRMVT` | TEXT | YES | N |  | 카드유효기간 |  |
| 13 | `ACNUT_SER_NO` | TEXT | YES | N |  | 계좌일련번호 |  |
| 14 | `PAYER_NM` | TEXT | YES | N |  | 결제자명 |  |
| 15 | `CARD_DIV_CD` | TEXT | YES | Y | PM052 | 카드구분코드 | 0=개인;1=법인,2=개인,NULL=개인 |
| 16 | `PAYER_RRN_BIZRNO_ENC` | TEXT | YES | N |  | 결제자주민등록번호사업자등록번호암호화 |  |
| 17 | `MBTLNUM` | TEXT | YES | N |  | 휴대폰번호 |  |
| 18 | `ETC_CTTPC` | TEXT | YES | N |  | 기타연락처 |  |
| 19 | `ETC_CTTPC_REL_CD` | TEXT | YES | Y |  | 기타연락처관계코드 | CM009 |
| 20 | `PAYER_MBER_REL_CD` | TEXT | YES | Y |  | 결제자회원관계코드 | CM009 |
| 21 | `CRTFC_MTH_CD` | TEXT | YES | Y | MM014 | 인증방법코드 |  |
| 22 | `CRTFC_FILE_NM` | TEXT | YES | N |  | 인증파일명 |  |
| 23 | `CRTFC_DATA_CTNT` | TEXT | YES | N |  | 인증데이터내용 |  |
| 24 | `CRTFC_DE` | TEXT | YES | N |  | 인증일 |  |
| 25 | `FILE_SIZE` | FLOAT | YES | N |  | 파일크기 |  |
| 26 | `BILLKEY` | TEXT | YES | N |  | 빌키 |  |
| 28 | `RQST_DIV_CD` | TEXT | YES | Y | PM004 | 신청구분코드 |  |
| 29 | `RCEPT_DIV_CD` | TEXT | YES | Y | PM003 | 접수구분코드 |  |
| 30 | `APRV_YN` | TEXT | YES | Y |  | 승인여부 | Y/N (NULL 존재) |
| 31 | `APRV_REQUST_KEY` | FLOAT | YES | N |  | 승인요청KEY |  |
| 32 | `APRV_RST_KEY` | FLOAT | YES | N |  | 승인결과KEY |  |
| 33 | `FRST_BEGIN_DE` | TEXT | YES | N |  | 최초개시일 |  |
| 34 | `RQEST_EXCL_YN` | TEXT | YES | Y |  | 청구제외여부 | Y/N |
| 35 | `RQEST_EXCL_STRT_DE` | TEXT | YES | N |  | 청구제외시작일 |  |
| 36 | `RQEST_EXCL_END_DE` | TEXT | YES | N |  | 청구제외종료일 |  |
| 37 | `APPLCNT_NM` | TEXT | YES | N |  | 신청자명 |  |
| 38 | `APPLCNT_RRN_ENC` | TEXT | YES | N |  | 신청자주민등록번호암호화 |  |
| 39 | `APPLCNT_MBTLNUM` | TEXT | YES | N |  | 신청자휴대폰번호 |  |
| 40 | `APPLCNT_ETC_CTTPC` | TEXT | YES | N |  | 신청자기타연락처 |  |
| 41 | `APPLCNT_ETC_CTTPC_REL_CD` | TEXT | YES | Y |  | 신청자기타연락처관계코드 | CM009 |
| 42 | `APPLCNT_MBER_REL_CD` | TEXT | YES | Y | CM009 | 신청자회원관계코드 |  |
| 43 | `BF_SETLE_KEY` | FLOAT | YES | N |  | 이전결제KEY |  |
| 44 | `OPERT_DIV_CD` | TEXT | YES | Y |  | 작업구분코드 | 1='홈페이지', 2='CRM', 3='글로벌에듀' |
| 45 | `CARD_PWDNO_ENC` | TEXT | YES | N |  | 카드비밀번호암호화 |  |
| 46 | `CRTFC_TY_CD` | TEXT | YES | Y |  | 인증유형코드 | 0=계좌, 2=휴대폰, 3=카드, 계좌=NULL |
| 47 | `USE_YN` | TEXT | YES | Y |  | 사용여부 | Y/N |
| 48 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자ID |  |
| 49 | `FRST_RGSTR_NM` | TEXT | YES | N |  | 최초등록자명 |  |
| 50 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일시 |  |
| 51 | `LAST_UPDUSR_ID` | TEXT | YES | N |  | 최종수정자ID |  |
| 52 | `LAST_UPDUSR_NM` | TEXT | YES | N |  | 최종수정자명 |  |
| 53 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES | N |  | 최종수정일시 |  |

### TM_RM_BPLC_MNG  (18 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `BPLC_CD` | TEXT | YES | Y |  | 사업장코드 | TM_RM_BPLC_MNG - BPLC_CD - BPLC_KORNM |
| 2 | `NATION_CD` | TEXT | YES | Y |  | 국가코드 | TM_RM_NATION_MNG - NATION_CD - NATION_KORNM |
| 3 | `BPLC_KORNM` | TEXT | YES | N |  | 사업장한글명 |  |
| 4 | `BPLC_ENGNM` | TEXT | YES | N |  | 사업장영문명 |  |
| 5 | `BSNS_STRT_DE` | TEXT | YES | N |  | 사업시작일 |  |
| 6 | `BSNS_END_DE` | TEXT | YES | N |  | 사업종료일 |  |
| 7 | `RELATNSP_BSNS_YN` | TEXT | YES | Y |  | 결연사업여부 | Y/N |
| 8 | `RELATNSP_BSNS_DSCNTC_DE` | TEXT | YES | N |  | 결연사업중단일 |  |
| 9 | `GFTMNEY_PSBL_YN` | TEXT | YES | Y |  | 선물금가능여부 | Y/N |
| 10 | `LETTER_PSBL_YN` | TEXT | YES | Y |  | 서신가능여부 | Y/N |
| 11 | `BPLC_DC` | TEXT | YES | N |  | 사업장설명 |  |
| 12 | `WTWK_FROM_DSTNC` | NUMBER | YES | N |  | 수도부터거리 |  |
| 13 | `CNCSN_RSN` | TEXT | YES | N |  | 종결사유 |  |
| 14 | `BPLC_MTCHG_MNG_YN` | TEXT | YES | Y |  | 사업장매칭관리여부 | Y/N |
| 15 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자ID |  |
| 16 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일시 |  |
| 17 | `LAST_UPDUSR_ID` | TEXT | YES | N |  | 최종수정자ID |  |
| 18 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES | N |  | 최종수정일시 |  |

### TM_RM_CHILD_MSTR_INFO  (16 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `CHILD_CD` | NUMBER | YES | Y |  | 아동코드 | PK |
| 2 | `CHILD_NO` | TEXT | YES | N |  | 아동번호 |  |
| 3 | `BPLC_CD` | TEXT | YES | Y |  | 사업장코드 | TM_RM_BPLC_MNG - BPLC_CD - BPLC_KORNM |
| 4 | `CHILD_KORNM` | TEXT | YES | N |  | 아동한글명 |  |
| 5 | `CHILD_ENGNM` | TEXT | YES | N |  | 아동영문명 |  |
| 6 | `SEX` | TEXT | YES | N |  | 성별 | m='남자', M='남자', f='여자', F='여자' |
| 7 | `CHILD_BRTHDY` | TEXT | YES | N |  | 아동생년월일 |  |
| 8 | `RELATNSP_STAT_CD` | TEXT | YES | Y | RM076 | 결연상태코드 |  |
| 9 | `CHILD_STAT_CD` | TEXT | YES | Y | RM077 | 아동상태코드 |  |
| 10 | `CHILD_DTL_STAT_CD` | TEXT | YES | Y | RM078 | 아동상세상태코드 |  |
| 11 | `REGIST_DIV_CD` | TEXT | YES | Y |  | 등록구분코드 | 사용안함 |
| 12 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일시 |  |
| 13 | `LAST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최종등록일시 |  |
| 14 | `RE_UPDT_DT` | TEXT | YES | N |  | 재수정일시 |  |
| 15 | `MNYRS_NATION_CD` | TEXT | YES | Y | RM023 | 모금국가코드 |  |
| 16 | `CMS_CHILD_NO` | TEXT | YES | N |  | CMS아동번호 |  |

### TM_RM_RELATNSP_CHG_INFO  (7 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `RELATNSP_KEY` | NUMBER | YES | N |  | 결연KEY |  |
| 2 | `CHG_YN` | TEXT | YES | Y | RM079 | 교체여부 |  |
| 3 | `CHG_RSN_CD` | NUMBER | YES | Y | RM066 | 교체사유코드 |  |
| 4 | `CHG_RST_CD` | TEXT | YES | Y |  | 교체결과코드 | NULL |
| 5 | `CHG_PERSON_ID` | TEXT | YES | N |  | 교체자ID |  |
| 6 | `CHG_DE` | TEXT | YES | N |  | 교체일 |  |
| 7 | `CHG_RELATNSP_KEY` | NUMBER | YES | N |  | 교체결연KEY |  |

### TM_RM_RELATNSP_MSTR_INFO  (11 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `RELATNSP_KEY` | NUMBER | YES | N |  | 결연KEY |  |
| 2 | `SPNSR_NO` | TEXT | YES | N |  | 후원번호 |  |
| 3 | `SPNSR_BSNS_NO` | NUMBER | YES | N |  | 후원사업번호 |  |
| 4 | `CHILD_CD` | NUMBER | YES | Y |  | 아동코드 | TM_RM_CHILD_MSTR_INFO - CHILD_CD |
| 5 | `RELATNSP_STRT_DE` | TEXT | YES | N |  | 결연시작일 |  |
| 6 | `RELATNSP_DSCNTC_DE` | TEXT | YES | N |  | 결연중단일 |  |
| 7 | `RELATNSP_DSCNTC_YN` | TEXT | YES | Y |  | 결연중단여부 | 0=후원중;1=후원중단 |
| 8 | `RELATNSP_DSCNTC_RSN_CD` | NUMBER | YES | Y | MM002 | 결연중단사유코드 |  |
| 9 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자ID |  |
| 10 | `FRST_REGIST_DE` | TEXT | YES | N |  | 최초등록일 |  |
| 11 | `MBER_NO` | TEXT | YES | N |  | 회원번호 |  |

### TC_CMMN_CD  (10 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `CD_ID` | TEXT | YES | N |  | 코드ID |  |
| 2 | `CD_NM` | TEXT | YES | N |  | 코드명 |  |
| 3 | `CD_DC` | TEXT | YES | N |  | 코드설명 |  |
| 4 | `SORT_ORDR` | NUMBER | YES | N |  | 정렬순서 |  |
| 5 | `RM` | TEXT | YES | N |  | 비고 |  |
| 6 | `USE_YN` | TEXT | YES | Y |  | 사용여부 | Y/N |
| 7 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자ID |  |
| 8 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일시 |  |
| 9 | `LAST_UPDUSR_ID` | TEXT | YES | N |  | 최종수정자ID |  |
| 10 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES | N |  | 최종수정일시 |  |

### TC_CMMN_DTL_CD  (15 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `CD_ID` | TEXT | YES | N |  | 코드ID |  |
| 2 | `DTL_CD_ID` | TEXT | YES | N |  | 상세코드ID |  |
| 3 | `DTL_CD_NM` | TEXT | YES | N |  | 상세코드명 |  |
| 4 | `DTL_CD_DC` | TEXT | YES | N |  | 상세코드설명 |  |
| 5 | `SORT_ORDR` | NUMBER | YES | N |  | 정렬순서 |  |
| 6 | `RM` | TEXT | YES | N |  | 비고 |  |
| 7 | `USE_YN` | TEXT | YES | Y |  | 사용여부 | Y/N |
| 8 | `CD_ATRB1` | TEXT | YES | N |  | 코드속성1 |  |
| 9 | `CD_ATRB2` | TEXT | YES | N |  | 코드속성2 |  |
| 10 | `CD_ATRB3` | TEXT | YES | N |  | 코드속성3 |  |
| 11 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자ID |  |
| 12 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일시 |  |
| 13 | `LAST_UPDUSR_ID` | TEXT | YES | N |  | 최종수정자ID |  |
| 14 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES | N |  | 최종수정일시 |  |
| 15 | `UPPER_CD_ID` | TEXT | YES | N |  | 상위코드ID |  |

### TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT  (11 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `OCCRRNC_DE` | TEXT | YES | N |  | 발생일자 |  |
| 2 | `SER_NO` | NUMBER | YES | N |  |  | Sequence number |
| 3 | `SPNSR_NO` | NUMBER | YES | N |  | 후원번호 |  |
| 4 | `SPNSR_BSNS_NO` | NUMBER | YES | N |  | 후원사업번호 |  |
| 5 | `MBER_NO` | TEXT | YES | N |  | 회원번호 |  |
| 6 | `SPNSR_AMT` | NUMBER | YES | N |  | 후원금액 |  |
| 7 | `BF_STAT_CD` | TEXT | YES | Y |  | 이전상태코드 | TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT_TBL - BF_STAT_CD - BF_STAT_NM |
| 8 | `AF_STAT_CD` | TEXT | YES | Y |  |  | TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT_TBL - AF_STAT_CD - AF_STAT_NM |
| 9 | `RELATNSP_DVLP_DIV_CD` | TEXT | YES | Y |  |  | TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT_TBL - DVLP_DIV_CD - DVLP_DIV_NM |
| 10 | `ACCNUT_STATS_CD` | TEXT | YES | Y |  |  | TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT_TBL - MBER_STATS_CD - MBER_STATS_NM |
| 11 | `CHILD_STATS_CD` | TEXT | YES | Y |  |  | TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT_TBL - CHILD_STATS_CD - CHILD_STATS_NM |

### TM_MM_FDRM_MBER_SPNSR  (7 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `SPNSR_NO` | TEXT | YES | N |  | 후원번호 |  |
| 2 | `MBER_NO` | TEXT | YES | N |  | 회원번호 |  |
| 3 | `CMPGN_CD` | TEXT | YES | Y |  | 캠페인코드 | TM_CM_CMPGN_MNG - CMPGN_CD - CMPGN_NM |
| 4 | `ACMSLT_DEPT_CD` | TEXT | YES | Y | TM_CM_DEPT_INFO | 실적부서코드 | TM_CM_DEPT_INFO - DEPT_ID - DEPT_NM |
| 5 | `JOIN_PATH_CD` | TEXT | YES | Y | MM014 | 가입경로코드 |  |
| 6 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자 |  |
| 7 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일 |  |

### TM_MM_FDRM_MBER_SPNSR_BSNS  (14 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `SPNSR_NO` | TEXT | YES | N |  | 후원번호 |  |
| 1 | `SPNSR_NO` | TEXT | NO | Y | TM_MM_FDRM_MBER_DVLP_AMT | 후원번호 |  |
| 2 | `SPNSR_BSNS_NO` | NUMBER | YES | N |  | 후원사업번호 |  |
| 2 | `SPNSR_BSNS_NO` | NUMBER | NO | Y | TM_MM_FDRM_MBER_DVLP_AMT | 후원사업번호 |  |
| 3 | `SPNSR_BSNS_ID` | TEXT | YES | N |  | 후원사업코드 |  |
| 3 | `SPNSR_BSNS_ID` | TEXT | YES |  |  | 후원사업ID |  |
| 4 | `SPNSR_AMT` | NUMBER | YES | N |  | 후원금액 |  |
| 4 | `SPNSR_AMT` | NUMBER | YES |  |  | 후원금액 |  |
| 5 | `SPNSR_DSCNTC_DE` | TEXT | YES | N |  | 후원중단일 |  |
| 5 | `SPNSR_DSCNTC_DE` | TEXT | YES |  |  | 후원중단일 |  |
| 6 | `SPNSR_DSCNTC_YN` | TEXT | YES | Y |  | 후원중단여부 | Y/N Y=중단완료 / N=후원중 |
| 6 | `SPNSR_DSCNTC_YN` | TEXT | YES |  |  | 후원중단여부 |  |
| 7 | `SPNSR_DSCNTC_RSN_CD` | TEXT | YES | Y | MM002 | 후원사업취소사유 |  |
| 7 | `SPNSR_DSCNTC_RSN_CD` | TEXT | YES | Y | MM005 | 후원중단사유코드 |  |

### TM_MM_FDRM_MBER_SPNSR_DSCNTC  (14 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `MBER_NO` | TEXT | YES | N |  | 회원번호 |  |
| 1 | `MBER_NO` | TEXT | NO |  |  | 회원번호 |  |
| 2 | `SPNSR_DSCNTC_DE` | TEXT | YES | N |  | 후원중단일 |  |
| 2 | `SPNSR_DSCNTC_DE` | TEXT | NO |  |  | 후원중단일 |  |
| 3 | `SER_NO` | NUMBER | YES | N |  |  | Sequence number |
| 3 | `SER_NO` | NUMBER | NO |  |  | 일련번호 |  |
| 4 | `DSCNTC_RSN_CD` | TEXT | YES | Y | MM005 | 후원중단사유 |  |
| 4 | `DSCNTC_RSN_CD` | TEXT | YES | Y | MM005 | 중단사유코드 |  |
| 5 | `DSCNTC_PATH` | TEXT | YES | Y | MM287 | 후원중단경로 |  |
| 5 | `DSCNTC_PATH` | TEXT | YES | Y | MM287 | 중단경로 |  |
| 6 | `REGIST_DEPT_CD` | TEXT | YES | Y |  | 등록부서코드 | TM_CM_DEPT_INFO - DEPT_ID - DEPT_NM |
| 6 | `REGIST_DEPT_CD` | TEXT | YES | Y | TM_CM_DEPT_INFO | 등록부서코드 |  |
| 7 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자 |  |
| 7 | `FRST_RGSTR_ID` | TEXT | YES |  |  | 최초등록자ID |  |

### TM_CM_MBER_DVLP_GOAL  (9 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `STDYY` | TEXT | NO | N |  | 기준연 |  |
| 2 | `STDR_MT` | TEXT | NO | N |  | 기준월 |  |
| 3 | `MBER_DVLP_DIV_CD` | NUMBER | NO | Y | MM015 | 개발구분 |  |
| 4 | `DEPT_ID` | TEXT | NO | N |  | 부서 |  |
| 5 | `GOAL_CNT` | NUMBER | YES | N |  | 개발목표수 |  |
| 6 | `FRST_RGSTR_ID` | TEXT | YES | N |  | 최초등록자 |  |
| 7 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES | N |  | 최초등록일시 |  |
| 8 | `LAST_UPDUSR_ID` | TEXT | YES | N |  | 최종등록자ID |  |
| 9 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES | N |  | 최종등록일시 |  |

### SND_REQ_MST  (56 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `SEQ_NO` | NUMBER | NO |  |  | 순번 |  |
| 2 | `SEND_GBN_TOP` | TEXT | YES |  |  | 발송 카테고리 (대) |  |
| 3 | `SEND_GBN_MID` | TEXT | YES |  |  | 발송 카테고리 (중) |  |
| 4 | `SEND_GBN_BOT` | TEXT | YES |  |  | 발송 카테고리 (소) |  |
| 5 | `SEND_TITLE` | TEXT | YES |  |  | 발송 제목 |  |
| 6 | `MSG_TYPE` | TEXT | YES |  |  | 메시지 유형 |  |
| 7 | `MAIL_CONT` | TEXT | YES |  |  | 메시지 내용 |  |
| 8 | `TMPL_CODE` | TEXT | YES |  |  | 템플릿 코드 |  |
| 9 | `AUTHOR` | TEXT | YES |  |  | 작성자 |  |
| 10 | `CREATE_DATE` | TIMESTAMP_NTZ | YES |  |  | 작성일 |  |
| 11 | `CONDITION_TITLE` | TEXT | YES |  |  | 발송 조건 제목 |  |
| 12 | `CALL_NUMBER` | TEXT | YES |  |  | 발신 번호 |  |
| 13 | `ALT_SMS_YN` | TEXT | YES |  |  | 대체 문자 발송 여부 |  |
| 14 | `ALIM_TALK_CONT` | TEXT | YES |  |  | 알림톡 내용 |  |
| 15 | `SMS_TALK_CONT` | TEXT | YES |  |  | 대체 문자 내용 |  |
| 16 | `REGULARLY` | TEXT | YES |  |  | 발송 유형 (정기/비정기) |  |
| 17 | `PERIODIC` | TEXT | YES |  |  | 발송 주기 |  |
| 18 | `PERIODIC_WEEK` | TEXT | YES |  |  | 요일별 발송 요일 |  |
| 19 | `PERIODIC_DAY` | NUMBER | YES |  |  | 매월 발송 일자 |  |
| 20 | `SEND_DATE` | TIMESTAMP_NTZ | YES |  |  | 발송 시작 날짜 |  |
| 21 | `SEND_TIME` | TEXT | YES |  |  | 발송 시작 시간 |  |
| 22 | `SEND_MIN` | TEXT | YES |  |  |  |  |
| 23 | `SEND_SPLIT_TYPE` | TEXT | YES |  |  | 발송 분할 방식 |  |
| 24 | `DIVIDE` | NUMBER | YES |  |  | 분할 건수 |  |
| 25 | `DIVIDE_UNIT` | NUMBER | YES |  |  | 분할 단위 (분) |  |
| 26 | `CORP_TYPE` | TEXT | YES |  |  | 법인 구분 |  |
| 27 | `AUTO_TYPE` | TEXT | YES |  |  | 자동/수동 구분 |  |
| 28 | `USE_YN` | TEXT | YES |  |  | 사용 여부 |  |
| 29 | `REG_ID` | TEXT | YES |  |  | 등록자 |  |
| 30 | `MOD_DATE` | TIMESTAMP_NTZ | YES |  |  | 수정일 |  |
| 31 | `INIT_REG_DATE` | TIMESTAMP_NTZ | YES |  |  | 최초 등록일 |  |
| 32 | `LAST_SEND_DATE` | TIMESTAMP_NTZ | YES |  |  | 최근 발송일 |  |
| 33 | `APPR_STATUS` | TEXT | YES |  |  | 승인 상태 |  |
| 34 | `CREATE_DEPT` | TEXT | YES |  |  | 작성 부서 |  |
| 35 | `SENDER_EMAIL` | TEXT | YES |  |  | 발신 메일주소 |  |
| 36 | `RCPT_LIST` | TEXT | YES |  |  | 수신자 목록 |  |
| 37 | `SEND_STATUS` | TEXT | YES |  |  | 발송 상태 |  |
| 38 | `SEND_CNT` | NUMBER | YES |  |  | 발송 건수 |  |
| 39 | `FAIL_CNT` | NUMBER | YES |  |  | 실패 건수 |  |
| 40 | `LAST_ERR` | TEXT | YES |  |  | 최근 오류 |  |
| 41 | `END_DATE` | TIMESTAMP_NTZ | YES |  |  | 발송종료일 |  |
| 42 | `PAPER_YEAR` | TEXT | YES |  |  | ACPI 년도 |  |
| 43 | `MENU_CODE` | TEXT | YES |  |  | 메뉴코드 |  |
| 44 | `SEND_GBN_TOP_NM` | TEXT | YES |  |  | 발송 카테고리 (대) |  |
| 45 | `SEND_GBN_MID_NM` | TEXT | YES |  |  | 발송 카테고리 (중) |  |
| 46 | `SEND_GBN_BOT_NM` | TEXT | YES |  |  | 발송 카테고리 (소) |  |
| 47 | `TARGET_CNT` | NUMBER | YES |  |  | 발송대상카운트 |  |
| 48 | `SEND_ROUND` | TIMESTAMP_NTZ | YES |  |  | 발송차수 |  |
| 49 | `BTN_LIST` | TEXT | YES |  |  | 버턴 |  |
| 50 | `EXTRA` | TEXT | YES |  |  | EXTRA |  |
| 51 | `ASSIGN_TARGET_CNT` | NUMBER | YES |  |  | 배정대상카운트 |  |
| 52 | `FIRST_SEQ_NO` | NUMBER | YES |  |  | 첫번째SEQ_NO |  |
| 53 | `JOB_ID` | TEXT | YES |  |  | 배치잡ID |  |
| 54 | `SYNCED_AT` | TEXT | YES |  |  | 동기화 타임스탬프 |  |
| 55 | `REG_NM` | TEXT | YES |  |  |  |  |
| 56 | `SERVICE_MENU_CODE` | TEXT | YES |  |  |  |  |

### SND_MEMBER_LIST  (96 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `REQ_SEQ_NO` | NUMBER | NO |  |  | REQ_SEQ_NO |  |
| 2 | `R_NUM` | NUMBER | NO |  |  | 순번 |  |
| 3 | `MBER_NO` | TEXT | YES |  |  | 회원번호 |  |
| 4 | `MBER_KORNM` | TEXT | YES |  |  | 회원명 |  |
| 5 | `MBTLNUM` | TEXT | YES |  |  | 연락처 |  |
| 6 | `EMAIL` | TEXT | YES |  |  | 이메일 |  |
| 7 | `SPNSR_CD` | TEXT | YES |  |  | 후원사업(코드) |  |
| 8 | `SPNSR_NM` | TEXT | YES |  |  | 후원사업(이름) |  |
| 9 | `CMPGN_CD` | TEXT | YES |  |  | 캠페인(코드) |  |
| 10 | `CMPGN_NM` | TEXT | YES |  |  | 캠페인(이름) |  |
| 11 | `GENDER` | TEXT | YES |  |  | 성별(회원) |  |
| 12 | `AGE` | TEXT | YES |  |  | 연령대 |  |
| 13 | `SETLE_CD` | TEXT | YES |  |  | 납입방식(코드) |  |
| 14 | `SETLE_NM` | TEXT | YES |  |  | 납입방식(이름) |  |
| 15 | `DSCNTC_PATH` | TEXT | YES |  |  | 중단채널 |  |
| 16 | `DSCNTC_RSN_CD` | TEXT | YES |  |  | 중단사유(코드) |  |
| 17 | `DSCNTC_RSN_NM` | TEXT | YES |  |  | 중단사유(이름) |  |
| 18 | `CHILD_NO` | TEXT | YES |  |  | 아동번호 |  |
| 19 | `CHILD_KOR_NM` | TEXT | YES |  |  | 아동이름 |  |
| 20 | `LST_BRND_CD` | TEXT | YES |  |  | 최종브랜드(코드) |  |
| 21 | `LST_BRND_NM` | TEXT | YES |  |  | 최종브랜드(이름) |  |
| 22 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES |  |  | 가입일 |  |
| 23 | `MNG_NO` | TEXT | YES |  |  | 관리번호 |  |
| 24 | `LETTER_DIV_CD` | TEXT | YES |  |  | 서비스구분 |  |
| 25 | `CHILD_DTL_CD` | TEXT | YES |  |  | 아동세부상태(코드) |  |
| 26 | `CHILD_DTL_NM` | TEXT | YES |  |  | 아동세부상태(이름) |  |
| 27 | `RELATNSP_DSCNTC_YN` | TEXT | YES |  |  | 결연중단유무 |  |
| 28 | `FRST_SPNSR` | TEXT | YES |  |  | 최초후원사업(회원) |  |
| 29 | `FRST_BRND_CD` | TEXT | YES |  |  | 최초 브랜드(코드) |  |
| 30 | `FRST_BRND_NM` | TEXT | YES |  |  | 최초 브랜드(이름) |  |
| 31 | `RELATNSP_KEY` | NUMBER | YES |  |  | 결연번호 |  |
| 32 | `LST_REGIST_DT` | TIMESTAMP_NTZ | YES |  |  | 최종가입일 |  |
| 33 | `FAX` | TEXT | YES |  |  | 팩스 |  |
| 34 | `PRIV_SUSP_YN` | TEXT | YES |  |  | 개인 정보 이용 중단 |  |
| 35 | `SND_YN` | TEXT | YES |  |  | 발송 성공 여부 |  |
| 36 | `SND_MSG` | TEXT | YES |  |  | 발송 메시지 |  |
| 37 | `REG_DATE` | TIMESTAMP_NTZ | YES |  |  | 등록일시 |  |
| 38 | `SND_DT` | TIMESTAMP_NTZ | YES |  |  | 발송일 |  |
| 39 | `SND_HOUR` | TEXT | YES |  |  | 발송시 |  |
| 40 | `SND_MIN` | TEXT | YES |  |  | 발송분 |  |
| 41 | `email_recptn_cd` | TEXT | YES |  |  | 이메일 수신 상태(코드) |  |
| 42 | `email_recptn_nm` | TEXT | YES |  |  | 이메일 수신 상태(이름) |  |
| 43 | `CHILD_PIC` | TEXT | YES |  |  | 아동사진 |  |
| 44 | `NATION_CD` | TEXT | YES |  |  | 국가코드 |  |
| 45 | `NATION_NM` | TEXT | YES |  |  | 국가명 |  |
| 46 | `BPLC_CD` | TEXT | YES |  |  | 사업장코드 |  |
| 47 | `BPLC_KOR_NM` | TEXT | YES |  |  | 사업장명 |  |
| 48 | `CHILD_BIRTHDAY` | TIMESTAMP_NTZ | YES |  |  | 생년월일 |  |
| 49 | `ACL_CNTNT` | TEXT | YES |  |  | ACL내용 |  |
| 50 | `DISCHARGE_REPORT_KOR` | TEXT | YES |  |  | 퇴소보고서(한글) |  |
| 51 | `PAST_NATION_NM` | TEXT | YES |  |  | 과거국가명 |  |
| 52 | `PAST_BPLC_NM` | TEXT | YES |  |  | 과거사업장명 |  |
| 53 | `PAST_CHILD_NM` | TEXT | YES |  |  | 과거아동이름 |  |
| 54 | `PAST_CHILD_NO` | TEXT | YES |  |  | 과거아동번호 |  |
| 55 | `FAMILY_DTL` | TEXT | YES |  |  | 가족사항 |  |
| 56 | `FINAL_ACL_SCAN_CP` | TEXT | YES |  |  | 종결ACL스캔본 |  |
| 57 | `FINAL_ACL_CHILD_PIC` | TEXT | YES |  |  | 종결ACL아동사진 |  |
| 58 | `FINAL_ACL_TRANSLATED_CNTNT` | TEXT | YES |  |  | 종결ACL번역내용 |  |
| 59 | `FINAL_CHILD_SPNSR_START_DT` | TIMESTAMP_NTZ | YES |  |  | 종결아동결연시작일 |  |
| 60 | `NEW_CHILD_NO` | TEXT | YES |  |  | 신규아동번호 |  |
| 61 | `NEW_CHILD_NM` | TEXT | YES |  |  | 신규아동이름 |  |
| 62 | `NEW_CHILD_ENGLISH_NAME` | TEXT | YES |  |  | 신규아동영문이름 |  |
| 63 | `NEW_CHILD_PROJECT_COUNTRY` | TEXT | YES |  |  | 신규아동사업국 |  |
| 64 | `NEW_CHILD_WORKPLACE_NM` | TEXT | YES |  |  | 신규아동사업장명 |  |
| 65 | `NEW_CHILD_BIRTH_DT` | TIMESTAMP_NTZ | YES |  |  | 신규아동생년월일 |  |
| 66 | `NEW_CHILD_PIC` | TEXT | YES |  |  | 신규아동사진 |  |
| 67 | `NEW_CHILD_GENDER` | TEXT | YES |  |  | 신규아동성별 |  |
| 68 | `RELATN_CHILD_PIC` | TEXT | YES |  |  | 결연아동사진 |  |
| 69 | `SPNSR_AMOUNT` | NUMBER | YES |  |  | 후원금액(월납부액) |  |
| 70 | `SPNSR_STRT_DT` | TIMESTAMP_NTZ | YES |  |  | 후원시작일(최초가입일) |  |
| 71 | `SPNSR_DSCNTC_DT` | TIMESTAMP_NTZ | YES |  |  | 후원중단일(가장최근중단일) |  |
| 72 | `RELATNSP_DT` | TIMESTAMP_NTZ | YES |  |  | 결연매칭일(결연일) |  |
| 73 | `MBER_BIRTHDAY` | TIMESTAMP_NTZ | YES |  |  | 생년월일(회원) |  |
| 74 | `SPNSR_TYPE` | TEXT | YES |  |  | 후원구분 |  |
| 75 | `CPR_DIV_CD` | TEXT | YES |  |  | 법인구분 |  |
| 76 | `DEPT_CD` | TEXT | YES |  |  | 사용부서 |  |
| 77 | `CURRENT_BRND` | TEXT | YES |  |  | 최종브랜드(현재) |  |
| 78 | `CURRENT_UPPER_CMPGN` | TEXT | YES |  |  | 최종상위캠페인(현재) |  |
| 79 | `CURRENT_CMPGN` | TEXT | YES |  |  | 최종캠페인(현재) |  |
| 80 | `FIRST_UPPER_CMPGN` | TEXT | YES |  |  | 최초상위캠페인 |  |
| 81 | `FIRST_CMPGN` | TEXT | YES |  |  | 최초캠페인 |  |
| 82 | `LAST_TOP_CMPGN` | TEXT | YES |  |  | 최종상위캠페인 |  |
| 83 | `LAST_CMPGN` | TEXT | YES |  |  | 최종캠페인 |  |
| 84 | `SMS_TALK_CONT` | TEXT | YES |  |  | SMS컨텐츠 |  |
| 85 | `MAIL_CONT` | TEXT | YES |  |  | 메일컨텐츠 |  |
| 86 | `ALIM_TALK_CONT` | TEXT | YES |  |  | 알림톡 컨텐츠 |  |
| 87 | `BTN_LIST` | TEXT | YES |  |  | 버턴정보 |  |
| 88 | `EXTRA` | TEXT | YES |  |  | EXTRA |  |
| 89 | `MSG_KEY` | TEXT | YES |  |  | 메세지키 |  |
| 90 | `CINFO` | TEXT | YES |  |  | 알림톡구분 |  |
| 91 | `RESPONSED_YN` | TEXT | YES |  |  | 발송확인여부 |  |
| 92 | `RESPONSED_DT` | TIMESTAMP_NTZ | YES |  |  | 확인일시 |  |
| 93 | `SYNCED_AT` | TIMESTAMP_NTZ | YES |  |  |  |  |
| 94 | `CALL_STATUS` | TEXT | YES |  |  | 수신 결과 상태 (비즈뿌리오) |  |
| 95 | `REAL_SEND_DT` | TIMESTAMP_NTZ | YES |  |  |  |  |
| 96 | `LAST_UPPER_CMPGN` | TEXT | YES |  |  |  |  |

### TM_RM_RELATNSP_GFTMNEY_INFO  (19 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `RELATNSP_KEY` | NUMBER | NO |  |  | 결연KEY |  |
| 2 | `MNG_NO` | TEXT | NO |  |  | 관리번호 |  |
| 3 | `MBRFEE_KEY` | NUMBER | NO |  |  | 회비KEY |  |
| 4 | `SETLE_DE` | TIMESTAMP_NTZ | YES |  |  | 결제일 |  |
| 5 | `SETLE_CD` | TEXT | YES |  |  | 결제코드 |  |
| 6 | `SETLE_BANK_CD` | TEXT | YES |  |  | 결제은행코드 |  |
| 7 | `SETLE_NO_ENC` | TEXT | YES |  |  | 결제번호암호화 |  |
| 8 | `GFTMNEY` | NUMBER | YES |  |  | 선물금 |  |
| 9 | `GFT_DIV_CD` | TEXT | YES |  |  | 선물구분코드 |  |
| 10 | `KOREAN_RM_CTNT` | TEXT | YES |  |  | 한글비고내용 |  |
| 11 | `ENGL_RM_CTNT` | TEXT | YES |  |  | 영어비고내용 |  |
| 12 | `SNDNG_DE` | TIMESTAMP_NTZ | YES |  |  | 발신일 |  |
| 13 | `EHGT` | TEXT | YES |  |  | 환율 |  |
| 14 | `GFTMNEY_DOLLAR_AMT` | TEXT | YES |  |  | 선물금미화금액 |  |
| 15 | `APRV_DE` | TIMESTAMP_NTZ | YES |  |  | 승인일 |  |
| 16 | `UNREPLY_RSN_CD` | NUMBER | YES |  |  | 미답신사유코드 |  |
| 17 | `TRNSFER_KEY` | NUMBER | YES |  |  | 이관KEY |  |
| 18 | `TRNSFER_YN` | TEXT | YES |  |  | 이관여부 |  |
| 19 | `TRNSFER_AFTER_RELATNSP_KEY` | NUMBER | YES |  |  | 이관후결연KEY |  |

### TM_RM_RELATNSP_LETTER_INFO  (14 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `RELATNSP_KEY` | NUMBER | NO |  |  | 결연KEY |  |
| 2 | `MNG_NO` | TEXT | NO |  |  | 관리번호 |  |
| 3 | `LETTER_DIV_CD` | NUMBER | YES |  |  | 서신구분코드 |  |
| 4 | `CTNT` | TEXT | YES |  |  | 내용 |  |
| 5 | `RCEPT_DE` | TIMESTAMP_NTZ | YES |  |  | 접수일 |  |
| 6 | `SNDNG_DE` | TIMESTAMP_NTZ | YES |  |  | 발신일 |  |
| 7 | `ONLINE_POST_WRITNG_YN` | TEXT | YES |  |  | 온라인우편작성여부 |  |
| 8 | `FRST_RGSTR_ID` | TEXT | YES |  |  | 최초등록자ID |  |
| 9 | `FRST_REGIST_DE` | TIMESTAMP_NTZ | YES |  |  | 최초등록일 |  |
| 10 | `EXCEL_SER_NO` | NUMBER | YES |  |  | 엑셀일련번호 |  |
| 11 | `UNREPLY_RSN_CD` | NUMBER | YES |  |  | 미답신사유코드 |  |
| 12 | `LANG_CD` | TEXT | YES |  |  | 언어코드 |  |
| 13 | `ONLINE_INFLOW_CD` | NUMBER | YES |  |  |  |  |
| 14 | `LETTER_STAT_CD` | NUMBER | YES |  |  | 편지상태코드 |  |

### TM_MS_CRMN  (31 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `CRMN_CD` | NUMBER | NO |  |  | 행사코드 |  |
| 2 | `CRMN_DIV_CD` | TEXT | YES |  |  | 행사구분코드 |  |
| 3 | `CRMN_TIT` | TEXT | YES |  |  | 행사제목 |  |
| 4 | `CRMN_PLACE_NM` | TEXT | YES |  |  | 행사장소명 |  |
| 5 | `BRNCH_DEPT_ID` | TEXT | YES |  |  | 지부부서ID |  |
| 6 | `ATCHFL_ID` | TEXT | YES |  |  | 첨부파일ID |  |
| 7 | `SITE_URL` | TEXT | YES |  |  | 사이트URL |  |
| 8 | `CRMN_STRT_DE` | TEXT | YES |  |  | 행사시작일 |  |
| 9 | `CRMN_END_DE` | TEXT | YES |  |  | 행사종료일 |  |
| 10 | `CRMN_PART_STRT_DE` | TEXT | YES |  |  |  |  |
| 11 | `CRMN_PART_END_DE` | TEXT | YES |  |  |  |  |
| 12 | `TAT` | NUMBER | YES |  |  | 소요시간 |  |
| 13 | `RCRIT_PSNNL_CO` | NUMBER | YES |  |  | 모집인원수 |  |
| 14 | `RESRCE_SRVC_FG` | NUMBER | YES |  |  | 자원봉사유무 |  |
| 15 | `CPR_DIV_CD` | TEXT | YES |  |  | 법인구분코드 |  |
| 16 | `ENTRPS_CD` | NUMBER | YES |  |  | 업체코드 |  |
| 17 | `RM` | TEXT | YES |  |  | 비고 |  |
| 18 | `CRMN_CTNT` | TEXT | YES |  |  | 행사내용 |  |
| 19 | `USE_YN` | TEXT | YES |  |  | 사용여부 |  |
| 20 | `PART_USE_YN` | TEXT | YES |  |  |  |  |
| 21 | `TMPLAT_ID` | TEXT | YES |  |  |  |  |
| 22 | `TMPLAT_TIT` | TEXT | YES |  |  |  |  |
| 23 | `TMPLAT_PART_ID` | TEXT | YES |  |  |  |  |
| 24 | `TMPLAT_PART_TIT` | TEXT | YES |  |  |  |  |
| 25 | `FRST_RGSTR_ID` | TEXT | YES |  |  | 최초등록자ID |  |
| 26 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES |  |  | 최초등록일시 |  |
| 27 | `LAST_UPDUSR_ID` | TEXT | YES |  |  | 최종수정자ID |  |
| 28 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES |  |  | 최종수정일시 |  |
| 29 | `SRVY` | TEXT | YES |  |  | 설문조사 링크 |  |
| 30 | `RM2` | TEXT | YES |  |  |  |  |
| 31 | `PROMO_CODE` | TEXT | YES |  |  |  |  |

### TD_MS_CRMN_PRTCPNT  (19 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `CRMN_CD` | NUMBER | NO |  |  | 행사코드 |  |
| 2 | `PRTCPNT_KEY` | NUMBER | NO |  |  | 참여자KEY |  |
| 3 | `MBER_NO` | TEXT | YES |  |  | 회원번호 |  |
| 4 | `RQST_PATH_CD` | TEXT | YES |  |  | 신청경로코드 |  |
| 5 | `PARTCPT_TIME_CO` | NUMBER | YES |  |  | 참여시간수 |  |
| 6 | `PARTCPT_STAT_CD` | TEXT | YES |  |  | 참여상태코드 |  |
| 7 | `SELF_PARTCPT_CD` | TEXT | YES |  |  | 자기참여코드 |  |
| 8 | `RCPMNY_STAT_CD` | TEXT | YES |  |  | 입금상태코드 |  |
| 9 | `RCPMNY_DATE` | TEXT | YES |  |  | 입금일자 |  |
| 10 | `REFND_DATE` | TEXT | YES |  |  | 환불일자 |  |
| 11 | `RQST_DATE` | TEXT | YES |  |  | 신청일자 |  |
| 12 | `PARTCPT_DATE` | TEXT | YES |  |  | 참여일자 |  |
| 13 | `RCPMNY_AMT` | NUMBER | YES |  |  | 입금금액 |  |
| 14 | `ACMPNY_PARTCPT_CO` | NUMBER | YES |  |  | 동반참여수 |  |
| 15 | `RM` | TEXT | YES |  |  | 비고 |  |
| 16 | `FRST_RGSTR_ID` | TEXT | YES |  |  | 최초등록자ID |  |
| 17 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES |  |  | 최초등록일시 |  |
| 18 | `LAST_UPDUSR_ID` | TEXT | YES |  |  | 최종수정자ID |  |
| 19 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES |  |  | 최종수정일시 |  |

### TM_MS_EVENT  (11 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `EVENT_CD` | NUMBER | NO |  |  | 이벤트코드 |  |
| 2 | `EVENT_DIV_CD` | TEXT | YES |  |  | 이벤트구분코드 |  |
| 3 | `EVENT_NM` | TEXT | YES |  |  | 이벤트명 |  |
| 4 | `STRT_DATE` | TEXT | YES |  |  | 시작일자 |  |
| 5 | `END_DATE` | TEXT | YES |  |  | 종료일자 |  |
| 6 | `PRZWIN_PSNNL_CO` | NUMBER | YES |  |  | 당첨인원수 |  |
| 7 | `PRZWIN_GFT_SNDNG_DE` | TEXT | YES |  |  | 당첨선물발송일 |  |
| 8 | `FRST_RGSTR_ID` | TEXT | YES |  |  | 최초등록자ID |  |
| 9 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES |  |  | 최초등록일시 |  |
| 10 | `LAST_UPDUSR_ID` | TEXT | YES |  |  | 최종수정자ID |  |
| 11 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES |  |  | 최종수정일시 |  |

### TD_MS_EVENT_PRTCPNT_DTL  (15 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `EVENT_CD` | NUMBER | NO |  |  | 이벤트코드 |  |
| 2 | `MBER_NO` | TEXT | NO |  |  | 회원번호 |  |
| 3 | `PARTCPT_SEQ` | NUMBER | NO |  |  | 참여순번 |  |
| 4 | `EVENT_PARTCPT_DIV_CD` | TEXT | YES |  |  | 이벤트참여구분코드 |  |
| 5 | `PRZWIN_CD` | NUMBER | YES |  |  | 당첨코드 |  |
| 6 | `PARTCPT_CHNNL_CD` | TEXT | YES |  |  | 참여채널코드 |  |
| 7 | `PARTCPT_PATH_CD` | TEXT | YES |  |  | 참여경로코드 |  |
| 8 | `PARTCPT_STAT_CD` | TEXT | YES |  |  | 참여상태코드 |  |
| 9 | `PARTCPT_DT` | TIMESTAMP_NTZ | YES |  |  | 참여일시 |  |
| 10 | `RM` | TEXT | YES |  |  | 비고 |  |
| 11 | `RM2` | TEXT | YES |  |  | 비고2 |  |
| 12 | `FRST_RGSTR_ID` | TEXT | YES |  |  | 최초등록자ID |  |
| 13 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES |  |  | 최초등록일시 |  |
| 14 | `LAST_UPDUSR_ID` | TEXT | YES |  |  | 최종수정자ID |  |
| 15 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES |  |  | 최종수정일시 |  |

### TM_MM_FDRM_MBER_RE_SPNSR  (5 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `MBER_NO` | TEXT | NO |  |  | 회원번호 |  |
| 2 | `SER_NO` | NUMBER | NO |  |  | 일련번호 |  |
| 3 | `RE_SPNSR_DE` | TEXT | NO |  |  | 재후원일 |  |
| 4 | `REGIST_DEPT_CD` | TEXT | YES | Y | TM_CM_DEPT_INFO | 등록부서코드 |  |
| 5 | `FRST_RGSTR_ID` | TEXT | YES |  |  | 최초등록자ID |  |

### TM_MM_FDRM_MBER_IRSD  (15 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `OCCRRNC_DE` | TEXT | NO |  |  | 발생일 |  |
| 2 | `SER_NO` | NUMBER | NO |  |  | 일련번호 |  |
| 3 | `ACMSLT_DEPT_CD` | TEXT | YES | Y | TM_CM_DEPT_INFO | 실적부서코드 |  |
| 4 | `CMPGN_CD` | TEXT | YES | Y | TM_CM_CMPGN_MNG | 캠페인코드 |  |
| 5 | `MBER_NO` | TEXT | YES |  |  | 회원번호 |  |
| 6 | `SPNSR_AMT` | NUMBER | YES |  |  | 후원금액 |  |
| 7 | `SETLE_CD` | TEXT | YES | Y | PM040 | 결제코드 |  |
| 8 | `MBER_DIV_CD` | TEXT | YES | Y | MM018 | 회원구분코드 |  |
| 9 | `SEX` | TEXT | YES | Y | CM013 | 성별 |  |
| 10 | `AREA_CD` | TEXT | YES | Y | CM011 | 지역코드 |  |
| 11 | `AGE` | NUMBER | YES | Y | CM014 | 연령 |  |
| 12 | `SPNSR_TIME_CO` | NUMBER | YES |  |  | 후원시간수 |  |
| 13 | `SPNSR_AMT_CD` | TEXT | YES | Y | CM012 | 후원금액코드 |  |
| 14 | `RDCAMT_YN` | TEXT | YES |  |  | 감액여부 |  |
| 15 | `FRST_RGSTR_ID` | TEXT | YES |  |  | 최초등록자ID |  |

### TH_PM_SETLE_INFO_HIST  (48 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `SETLE_KEY` | NUMBER | NO |  |  | 결제KEY |  |
| 2 | `UPDT_DT` | TIMESTAMP_NTZ | YES |  |  | 수정일시 |  |
| 3 | `UPDUSR_ID` | TEXT | YES |  |  | 수정자ID |  |
| 4 | `UPDUSR_NM` | TEXT | YES |  |  | 수정자명 |  |
| 5 | `MBER_NO` | TEXT | NO |  |  | 회원번호 |  |
| 6 | `CPR_DIV_CD` | TEXT | NO |  |  | 법인구분코드 |  |
| 7 | `SETLE_CD` | TEXT | NO | Y | PM040 | 결제코드 |  |
| 8 | `WTDRW_STRT_DE` | TIMESTAMP_NTZ | YES |  |  | 출금시작일 |  |
| 9 | `WTDRW_ASMT_SQNC` | NUMBER | YES |  |  | 출금지정차수 |  |
| 10 | `FNLT_DIV_CD` | TEXT | YES |  |  | 금융기관구분코드 |  |
| 11 | `FNLT_CD` | TEXT | YES |  |  | 금융기관코드 |  |
| 12 | `SETLE_ENTRPS_CD` | TEXT | YES |  |  | 결제업체코드 |  |
| 14 | `CARD_TRMVT` | TEXT | YES |  |  | 결제번호암호화 |  |
| 15 | `ACNUT_SER_NO` | NUMBER | YES |  |  | 카드유효기간 |  |
| 16 | `PAYER_NM` | TEXT | YES |  |  | 결제자명 |  |
| 17 | `CARD_DIV_CD` | TEXT | YES | Y | PM044 | 카드구분코드 |  |
| 19 | `MBTLNUM` | TEXT | YES |  |  | 휴대폰번호 |  |
| 20 | `ETC_CTTPC` | TEXT | YES |  |  | 기타연락처 |  |
| 21 | `ETC_CTTPC_REL_CD` | TEXT | YES |  |  | 기타연락처관계코드 |  |
| 22 | `PAYER_MBER_REL_CD` | TEXT | YES |  |  | 결제자회원관계코드 |  |
| 23 | `CRTFC_MTH_CD` | TEXT | YES |  |  | 인증방법코드 |  |
| 24 | `CRTFC_FILE_NM` | TEXT | YES |  |  | 인증파일명 |  |
| 25 | `CRTFC_DATA_CTNT` | TEXT | YES |  |  | 인증데이터내용 |  |
| 26 | `CRTFC_DE` | TIMESTAMP_NTZ | YES |  |  | 인증일 |  |
| 27 | `FILE_SIZE` | NUMBER | YES |  |  | 파일크기 |  |
| 29 | `SETLE_STAT_CD` | TEXT | YES | Y | PM001 | 결제상태코드 |  |
| 30 | `BF_SETLE_STAT_CD` | TEXT | YES |  |  | 이전결제상태코드 |  |
| 31 | `RQST_DIV_CD` | TEXT | YES |  |  | 신청구분코드 |  |
| 32 | `RCEPT_DIV_CD` | TEXT | YES |  |  | 접수구분코드 |  |
| 33 | `APRV_YN` | TEXT | YES |  |  | 승인여부 |  |
| 34 | `APRV_REQUST_KEY` | NUMBER | YES |  |  | 승인요청KEY |  |
| 35 | `APRV_RST_KEY` | NUMBER | YES |  |  | 승인결과KEY |  |
| 36 | `FRST_BEGIN_DE` | TIMESTAMP_NTZ | YES |  |  | 최초개시일 |  |
| 37 | `RQEST_EXCL_YN` | TEXT | YES |  |  | 청구제외여부 |  |
| 38 | `RQEST_EXCL_STRT_DE` | TIMESTAMP_NTZ | YES |  |  | 청구제외시작일 |  |
| 39 | `RQEST_EXCL_END_DE` | TIMESTAMP_NTZ | YES |  |  | 청구제외종료일 |  |
| 40 | `APPLCNT_NM` | TEXT | YES |  |  | 신청자명 |  |
| 42 | `APPLCNT_MBTLNUM` | TEXT | YES |  |  | 신청자휴대폰번호 |  |
| 43 | `APPLCNT_ETC_CTTPC` | TEXT | YES |  |  | 신청자기타연락처 |  |
| 44 | `APPLCNT_ETC_CTTPC_REL_CD` | TEXT | YES |  |  | 신청자기타연락처관계코드 |  |
| 45 | `APPLCNT_MBER_REL_CD` | TEXT | YES |  |  | 신청자회원관계코드 |  |
| 46 | `BF_SETLE_KEY` | NUMBER | YES |  |  | 이전결제KEY |  |
| 47 | `OPERT_DIV_CD` | TEXT | YES |  |  | 작업구분코드 |  |
| 49 | `CRTFC_TY_CD` | TEXT | YES |  |  | 인증유형코드 |  |
| 50 | `USE_YN` | TEXT | YES |  |  | 사용여부 |  |
| 51 | `RGSTR_ID` | TEXT | YES |  |  | 등록자ID |  |
| 52 | `RGSTR_NM` | TEXT | YES |  |  | 등록자명 |  |
| 53 | `REGIST_DT` | TIMESTAMP_NTZ | YES |  |  | 등록일시 |  |

### TM_CM_SPNSR_BSNS_INFO  (13 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `SPNSR_BSNS_ID` | TEXT | NO |  |  | 후원사업ID |  |
| 2 | `SPNSR_DIV_CD` | TEXT | YES |  |  | 후원구분코드 |  |
| 3 | `SPNSR_BSNS_NM` | TEXT | YES |  |  | 후원사업명 |  |
| 4 | `SPNSR_BSNS_ABRV_CD` | TEXT | YES |  |  | 후원사업약칭코드 |  |
| 5 | `DNTN_TY_CD` | TEXT | YES | Y | PM041 | 기부금유형코드 |  |
| 6 | `SORT_ORDR` | NUMBER | YES |  |  | 정렬순서 |  |
| 7 | `CPR_DIV_CD` | TEXT | YES | Y | CM019 | 법인구분코드 |  |
| 8 | `RM` | TEXT | YES |  |  | 비고 |  |
| 9 | `USE_YN` | TEXT | YES |  |  | 사용여부 |  |
| 10 | `FRST_RGSTR_ID` | TEXT | YES |  |  | 최초등록자ID |  |
| 11 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES |  |  | 최초등록일시 |  |
| 12 | `LAST_UPDUSR_ID` | TEXT | YES |  |  | 최종수정자ID |  |
| 13 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES |  |  | 최종수정일시 |  |

### TH_MM_FDRM_MBER_STNG_DTLS  (6 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `MBER_NO` | TEXT | NO |  |  | 회원번호 |  |
| 2 | `SER_NO` | NUMBER | NO |  |  | 일련번호 |  |
| 3 | `BF_STAT_CD` | TEXT | YES | Y | MM010 | 이전상태코드 |  |
| 4 | `CHN_STAT_CD` | TEXT | YES | Y | MM010 | 변경상태코드 |  |
| 5 | `FRST_RGSTR_ID` | TEXT | YES |  |  | 최초등록자ID |  |
| 6 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES |  |  | 최초등록일시 |  |

### TM_CM_MKTNG_CMPGN_MNG  (8 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `MK_CMPGN_CD` | TEXT | NO |  |  |  |  |
| 2 | `MK_CMPGN_NM` | TEXT | YES |  |  |  |  |
| 3 | `USE_YN` | TEXT | YES |  |  |  |  |
| 4 | `RM` | TEXT | YES |  |  |  |  |
| 5 | `FRST_RGSTR_ID` | TEXT | YES |  |  |  |  |
| 6 | `FRST_REGIST_DT` | TIMESTAMP_NTZ | YES |  |  |  |  |
| 7 | `LAST_UPDUSR_ID` | TEXT | YES |  |  |  |  |
| 8 | `LAST_UPDT_DT` | TIMESTAMP_NTZ | YES |  |  |  |  |

### TD_MS_AT_TMPLAT_BTN_LIST  (12 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `TMPLAT_ID` | varchar | NO |  |  | 템플릿ID |  |
| 2 | `BTN_SEQ` | int | NO |  |  | 버튼순번 |  |
| 3 | `BTN_TY_CD` | varchar | YES |  |  | 버튼유형코드 |  |
| 4 | `BTN_NM` | nvarchar | YES |  |  | 버튼명 |  |
| 5 | `Android_URL` | varchar | YES |  |  | 안드로이드URL |  |
| 6 | `IOS_URL` | varchar | YES |  |  | IOSURL |  |
| 7 | `MOBILE_URL` | varchar | YES |  |  | 모바일URL |  |
| 8 | `PC_URL` | varchar | YES |  |  | PCURL |  |
| 9 | `FRST_RGSTR_ID` | varchar | YES |  |  | 최초등록자ID |  |
| 10 | `FRST_REGIST_DT` | datetime | YES |  |  | 최초등록일시 |  |
| 11 | `LAST_UPDUSR_ID` | varchar | YES |  |  | 최종수정자ID |  |
| 12 | `LAST_UPDT_DT` | datetime | YES |  |  | 최종수정일시 |  |

### TM_MS_EMAIL_TMPLAT_MNG  (14 cols)

| # | 컬럼 | 데이터타입 | NULL | 코드 | 코드그룹/참조 | 설명 | 비고 |
|--:|------|------|:--:|:--:|------|------|------|
| 1 | `TMPLAT_KEY` | int | NO |  |  | 템플릿KEY |  |
| 2 | `CPR_DIV_CD` | varchar | YES |  |  | 법인구분코드 |  |
| 3 | `SNDNG_CD_ID` | varchar | YES | Y |  | 발신코드ID |  |
| 4 | `SNDNG_DTL_CD_ID` | varchar | YES | Y |  | 발신상세코드ID |  |
| 5 | `ATMC_YN` | char | YES |  |  | 자동여부 |  |
| 6 | `TIT` | varchar | YES |  |  | 제목 |  |
| 7 | `EMAIL_CTNT` | nvarchar | YES |  |  | 이메일내용 |  |
| 8 | `WRITNG_DEPT_ID` | varchar | YES |  |  | 작성부서ID |  |
| 9 | `WRITNG_DEPT_NM` | varchar | YES |  |  | 작성부서명 |  |
| 10 | `CHRG_DEPT_ID` | varchar | YES |  |  | 담당부서ID |  |
| 11 | `FRST_RGSTR_ID` | varchar | YES |  |  | 최초등록자ID |  |
| 12 | `FRST_REGIST_DT` | datetime | YES |  |  | 최초등록일시 |  |
| 13 | `LAST_UPDUSR_ID` | varchar | YES |  |  | 최종수정자ID |  |
| 14 | `LAST_UPDT_DT` | datetime | YES |  |  | 최종수정일시 |  |
