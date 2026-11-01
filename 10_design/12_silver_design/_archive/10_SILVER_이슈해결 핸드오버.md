<!-- LLM-METADATA
doc_id: SILVER_ISSUE_HANDOVER
doc_role: 이슈·해결 핸드오버 노트 (CRM SILVER 설계 선결 Q)
project: GN_DW (굿네이버스)
created: 2026-06-29
purpose: 인수인계자가 유사 이슈 발생 시 읽고 대응. Q번호는 master_plan §5와 동일.
status: Q4·Q7·Q13·Q14·Q15 ✅ / Q5·Q6 ✅해소·적재완료(2026-07-14) / Q2·Q3 ◐(현업 라벨 대기). CRM 21/21 SILVER 적재 완료.
refs: 02_SILVER_작업계획_BRONZE-GOLD연결 20260714.md(master 매핑 인덱스) · 03_SILVER_작업계획_CRM전용 20260714.md · 09_bronze_crm_ddl.sql · BRONZE_CRM 테이블 정보.MD · 06_지표용어사전 20260624.md
END-METADATA -->

# SILVER 설계 이슈·해결 핸드오버 노트 (CRM)

> 목적: CRM BRONZE→SILVER 정제 설계 중 발생한 데이터 이슈와 그 해결을 기록한다.
> **인수인계자는 유사 증상 발생 시 §1 진단 패턴 → §2 해당 Q 이슈카드 순으로 본다.**
> Q번호 = `master_plan §5` 와 동일(원장). 본 노트는 "왜·어떻게 풀었나"의 보존용.

---

## 1. 재사용 가능한 진단 패턴 (먼저 읽기)

| # | 증상/상황 | 진단 레시피 | 결론 도출 |
|---|---|---|---|
| **P1 코드→라벨** | 코드 컬럼의 코드그룹이 "추정"·라벨 미상 | distinct 코드값을 `TC_CMMN_DTL_CD`에 `DTL_CD_ID`로 매칭, `CD_ID`별 등장 확인 | `DTL_CD_ID`는 **전역 비유일** → 반드시 **(CD_ID,DTL_CD_ID) 복합** 조인. 전 값이 한 CD_ID로 매칭되면 그룹 확정 |
| **P2 유사키 함정** | `_NO`/`_ID`/`_KEY` 등 비슷한 키가 "같은 것"인지 불확실 | 각 키의 `COUNT(DISTINCT)` 비교 + `id_equals_no`(값 일치율) 체크 | distinct 수가 자릿수 다르면 **grain 다름**(별칭 아님). 값 일치=0이면 단순 변환도 아님 |
| **P3 병합 fan-out** | 여러 테이블 JOIN 시 행 폭발 우려 | ① 조인키당 중복행 `GROUP BY key HAVING COUNT(*)>1` ② 조인 후 행수 vs base 행수 | 중복키=0 & 조인후≈base → N:1 안전. 미매칭분은 **LEFT JOIN**으로 스파인 보존 |
| **P4 SUM 중복** | PK 있어도 금액 합계가 부풀 우려 | 동일 실물키(예 납입일+금액)로 GROUP BY 후 행수>1 그룹 비율 측정 | 동일 실물이 복수 행(차수/적상)에 중복되면 **measure별 grain 분리**(납입 dedup, 청구 행 기준) |
| **P5 미검증 스키마** | 컬럼 설명에 "(LLM생성)" 표기 | 원본 정의서 확보 여부 확인 | 정의서 전까지 **키·관계 단정 금지**(SND_* 계열) |
| **P6 실측 핸드오프** | 실데이터가 타 어카운트 | 판정기준 명시 쿼리팩 + 결과 회수 템플릿 분리 | 실행자는 숫자만 회수, 해석은 설계자가 |

---

## 2. Q별 이슈 카드

### Q4 ✅ 회원상태 코드그룹 미확정 (패턴 P1)
- **이슈**: `TH_MM_FDRM_MBER_STNG_DTLS.BF_STAT_CD`/`CHN_STAT_CD` 코드그룹이 `MM010(추정)`, 라벨 미상 → SCD2 상태·FMM 시점지표(#49·50·52·53) 모델링 불가.
- **진단**: 12개 distinct 값을 `TC_CMMN_DTL_CD`(CD_ID='MM010')에 조인 → 12/12 매칭.
- **해결**: **MM010 확정**. 1=활동회원·2~6=신규미납1~5·7~11=장기미납1~5·12=후원중단. 라벨 조인은 **(CD_ID,DTL_CD_ID) 복합** 필수(DTL_CD_ID가 다른 그룹에도 중복 등장).
- **재발 시**: 다른 코드 컬럼도 동일 — 사전의 "(추정)" 코드그룹은 P1로 실측 확정. 절대 DTL_CD_ID 단독 조인 금지.

### Q13 ✅ 약정 3중 grain 병합 폭발 우려 (패턴 P3)
- **이슈**: 개발(`DVLP_AMT`)·사업(`SPNSR_BSNS`)·결연(`RELATNSP_MSTR_INFO`) 병합 시 카디널리티 폭발 우려 → FMM measure 정합 위험.
- **진단**: ① `SPNSR_BSNS`의 (SPNSR_NO,SPNSR_BSNS_NO)당 중복행=0 ② `DVLP_AMT`(3,561,635) ⋈ `SPNSR_BSNS` = 3,561,561(미매칭 74).
- **해결**: **폭발 없음**. `DVLP_AMT` 자연키(SPNSR_NO+SPNSR_BSNS_NO+OCCRRNC_DE+SER_NO)=PK 스파인, `SPNSR_BSNS` **N:1 LEFT JOIN**(미매칭 74행 보존), **결연은 별도 엔티티**(`CRM_SPONSOR_RELATION`).
- **재발 시**: 다른 다원천 병합도 P3로 검증 후 스파인+LEFT JOIN. INNER JOIN으로 실적 누락 주의.

### Q14 ✅ 납입+청구 SUM 중복 (패턴 P4)
- **이슈**: `TM_PM_MBRFEE_ACMSLT`(회비=납입+청구 동일행)에서 차수(`MBRFEE_SQNC`/`RQEST_SQNC`)로 행 증식 → `SUM(PAY_AMT)` 중복 위험.
- **진단**: `MBRFEE_KEY`=PK(45.4M=행수). 동일 납입(PAY_DE+PAY_AMT)이 복수 적상행 중복 = pay_group **5.4%(199만)**. 회비차수 자체 증식은 극소(2,823).
- **해결**: **납입 measure = 납입건 dedup 후 집계 / 청구 measure = 행 기준**. 기부금(`DNTN_DTLS`, `DNTN_KEY`=PK)=납입만(청구 컬럼 없음) → `CRM_PAYMENT_BILLING` UNION 시 PAYMENT_TYPE 구분·기부금 청구 NULL.
- **재발 시**: PK 있어도 measure 합계 전 P4로 실물 중복 확인. 청구/납입처럼 의미 다른 금액은 grain 분리.

### Q15 ✅ 후원사업 키 NO vs ID — "1:1 별칭" 오해 (패턴 P2)
- **이슈**: 마스터=`SPNSR_BSNS_ID`(VARCHAR), 결연=`SPNSR_BSNS_NO`(NUMBER) → "두 키가 같은 후원사업의 1:1 별칭"으로 가정.
- **진단**: distinct 비교 → ID **29개**(→ 06-30 마스터 실측 **50**, AC-2 재확인), NO **약 215만개**, `id_equals_no=0`. → **전제 반증**.
- **해결**: `SPNSR_BSNS_ID`=후원사업(=DIM_SPONSORSHIP 키), `SPNSR_BSNS_NO`=약정/관계 단위 번호(차원키 아님). 관계=**NO→ID 다대일**. 회원·납입 테이블은 ID 직보유(귀속 직접). **결연만 NO 단독** → `DVLP_AMT`/`SPNSR_BSNS`/`MBRFEE_ACMSLT`에서 NO→ID 크로스워크(커버리지·마스터무결 100%). ⚠️NO 20건 ID 2개 모호 → 우선순위/충돌표시 클렌징.
- **재발 시**: 키 이름 유사성에 속지 말 것. P2(distinct 비교)부터. NO/ID가 grain이 다르면 크로스워크 필요.
- **[실측 2026-06-30 재확인]**: NO≈215만 일치(2,152,476)·NO→ID 모호 **16건(약정테이블 기준; L54 결연 20건과 모집단 상이)**. 단 **마스터 `SPNSR_BSNS_ID` distinct=50**(기존 카드의 29와 차이) → **AC-2 결정: DIM_SPONSORSHIP=전체 마스터 적재(50)**; 50↔29 원인은 S13 대조. 모호 클렌징.

### Q7 ✅ 조직 역할(활동/실적/등록) 반영
- **이슈**: FMM/FME에 조직 역할 3종 분리 필요한데 원천 존재 불확실.
- **해결**: `ACT_DEPT_CD`·`ACMSLT_DEPT_CD`·`REGIST_DEPT_CD` DDL 존재 확인(회원 테이블). = GOLD O10. **원천 확정**, 잔여는 FACT FK 설계 반영(차단 아님).

### Q2 / Q3 ◐ 캠페인 코드 (부분)
- **상태**: 컬럼↔코드그룹 확정(`CMPGN_CTGR_CD`=MM294·`CMPGN_TYPE1_BSN`=MM295·`CMPGN_TYPE2_BSN`=MM296), #15·#16 원천 확정. **잔여**: 코드값↔라벨 정의서 미수령(Q2), #17 현업 최종확인(Q3) → CRM 현업 의존.

---

## 3. Q5·Q6 — 해소 완료 (2026-07-14 적재)

> 최초 미해결(P5 미검증·설계결정) → **정의서 업데이트 + 실측 프로파일링으로 해소, CRM_SEND_*·CRM_MEMBER 적재 완료.**
> 적재 SQL 정본 = `09_SILVER_적재쿼리_20260714.sql` STEP 3 배치 4 (구조 DDL은 `08_SILVER_테이블DDL_20260714.sql`).

### Q5 ✅ 발송키 이원화 (패턴 P5) — 해소
- **이슈**: `SND_*.SEQ_NO` vs `TM_MS_*/TD_MS_*.SNDNG_KEY` 관계 불명(병렬/구신/마이그레이션?).
- **막혔던 이유**: `SND_*` 컬럼 설명이 "(LLM생성)" 미검증 → 키 단정 불가.
- **[실측 2026-06-30]**: `SND_REQ_MST.SEQ_NO`·`TM_MS_EMAIL_SNDNG.SNDNG_KEY` 각 전건 유일 → 별개 계열 추정(별칭 아님). SND_* 컬럼 미검증으로 최종 PK 보류.
- **[해소 2026-07-14]** — `BRONZE_CRM 테이블 정보.MD` 정의서 업데이트로 SND_* 컬럼 확정 + 실측:
  - `SND_REQ_MST` 1,707행 = 1,707 distinct SEQ_NO → **SEQ_NO = PK**(요청 마스터).
  - `SND_MEMBER_LIST` 8.3M행, REQ_SEQ_NO 1,646종, **orphan 0** → REQ_SEQ_NO → SEQ_NO **유효 FK**.
  - **키 도메인 완전 분리**: `SEQ_NO ∩ EMAIL.SNDNG_KEY = 0`, `EMAIL ∩ MSG_AT SNDNG_KEY = 0`(레거시 3채널도 서로 분리).
  - **결론**: 두 개의 독립 발송 시스템 —
    · **SND_\*** (비즈뿌리오): `SND_REQ_MST`(요청) → `SND_MEMBER_LIST`(수신자)
    · **TM_MS_\*/TD_MS_\*** (레거시 CRM): EMAIL·MSG_AT·PSTMTR 각 SNDNG_KEY
    → `CRM_SEND_*`는 **4채널(EMAIL/MSG_AT/PSTMTR/SND) 구조적 UNION**, **`SEND_CHANNEL`을 PK에 포함**(채널·시스템 충돌 방지; REQUEST/MEMBER PK 보정, RESULT는 기존부터 포함).
  - **적재 완료**: `CRM_SEND_REQUEST` 1,614,397 · `CRM_SEND_RESULT` 1,611,758(채널×SNDNG_KEY 집계) · `CRM_SEND_MEMBER` 38,471,525(EMAIL 7.81M+MSG_AT 20.56M+PSTMTR 1.80M+SND 8.30M).
  - **실측 타입 주의**: `TM_MS_PSTMTR_SNDNG.SNDNG_STDR_DE`·`SND_REQ_MST.SEND_DATE`는 문서상 TEXT였으나 **실측 DATE형** → `::TIMESTAMP_NTZ` 캐스팅(TRY_TO_TIMESTAMP는 DATE 입력 거부).

### Q6 ✅ 정기/일시 회원 UNION 정렬 — 해소
- **이슈**: `TM_MM_FDRM_MBER_INFO`(정기)·`TM_MM_ONCE_MBER_INFO`(일시) 컬럼셋·동일의미 표현 상이(수신동의: 정기 코드 vs 일시 Y/N). 성격 = **설계 결정**.
- **[실측 2026-06-30]**: 정기 1,575,046(숫자·38% leading-zero)·일시 175,061(비숫자)·**번호 충돌 0** → `MEMBER_DK`=**VARCHAR(10)** 확정(접두 불요). GOLD `MEMBER_DK` NUMBER→VARCHAR(10) 반영(AC-1).
- **[해소 2026-07-14]** — 값 분포 프로파일링으로 표준화 규칙 확정 + `CRM_MEMBER` 적재:
  - **SEX**: 코드그룹 **CM013 확정**(1=국내남·2=국내여·3=외국인남·4=외국인여·5=외국인기타·6=단체·7=기업·8=기타 — 순수 성별 아님). 규칙 = `'1','3'→'M'` · `'2','4'→'F'` · `'5'~'8'→'U'` · 공백/NULL→NULL. (상세 아래 "코드그룹 라벨" 참조)
  - **수신동의(EMAIL_RECPTN/PSTMTR_RECPTN)**: 정기=콤마 멀티값(`'2,5,6'` 304k·`'2,5'` 181k·`'2, 3, 4, 5'`·`'2,6,5'` 등 **순서/공백 제각각**), 일시=Y/N. 규칙 = **정규화**(공백제거→분리→DISTINCT→오름차순→재결합; `ARRAY_SORT/DISTINCT/REMOVE`) → `'2,6,5'`·`'2, 3, 4, 5'`가 `'2,5,6'`·`'2,3,4,5'`로 통일. 일시 Y/N은 통과. (코드셋 정보 보존; BOOLEAN 축약은 GOLD/SV에서.)
  - **UNION**: 정기(FDRM)∪일시(ONCE), MEMBER_TYPE 구분, MBER_NO 기준 dedup(QUALIFY). MBER_STAT_NM는 MM010 라벨 조인.
  - **적재 완료**: `CRM_MEMBER` 1,763,065(정기 1,587,343 + 일시 175,722, 충돌·손실 0).

### Q16 ✅ 캠페인↔마케팅캠페인 조인키 (패턴 P2) — 해소(무효화)
- **이슈**: `TM_CM_CMPGN_MNG.MKTG_CMPGN_NM`(NUMBER) vs `TM_CM_MKTNG_CMPGN_MNG.MK_CMPGN_CD`(VARCHAR) 타입 상이.
- **[해소 2026-07-14]**: 적재 후 실측 — `CRM_CAMPAIGN.MKTG_CMPGN_NM` **36,143행 전건 NULL**(원천 미채움). ⇒ **데이터상 연결 자체가 없음**(타입 불일치는 무의미). `MK_CMPGN_NM`=NULL 유지. 마케팅캠페인 마스터(287행)는 존재하나 캠페인이 이를 참조하지 않음. → 연결 필요 시 **현업에 조인키/매핑 요청** 필요.

### 코드그룹 라벨 ✅ 확정·채움 (2026-07-14, 정의서 `코드그룹` 열 + CRM_CODE 조인)
- **SEX = CM013**(혼합 필드): 1=국내남·2=국내여·3=외국인남·4=외국인여·5=외국인기타·6=단체·7=기업·8=기타. → 정의서 주석대로 **순수 성별 아님**. 표준화 `1,3→M · 2,4→F · 5~8→U`(비개인·외국기타; 개인/기업/단체 구분은 `MBER_DIV_CD`가 담당). 실측 채움: F 947,500·M 699,786·U 115,358·NULL 421.
- **MBER_DIV_CD = MM018**: 1=개인·2=기업·3=단체 → `CRM_MEMBER.MBER_DIV_NM` **100% 채움**(당초 미상 해소).
- **SETLE_CD = PM040**: 1=자동이체·2=신용카드·3=신용카드즉시·4=회비통장·5=휴대폰·…·12=네이버페이·13=가상계좌즉시 → `CRM_PAYMENT_METHOD.SETLE_NM` **100% 채움**.

### Q12 ◐ 컬럼정의서 CSV ↔ DDL 컬럼집합 — CRM 적재 범위 내 해소
- **[해소 2026-07-14]**: SILVER CRM 21테이블 정제 적재가 **매핑 컬럼 전부 성공**(결번·미존재 소스컬럼 0) → 적재에 필요한 컬럼집합은 검증됨. 실측 BRONZE_CRM=43테이블/927컬럼(원천정의 41/876 + 템플릿 2테이블 `TD_MS_AT_TMPLAT_BTN_LIST`·`TM_MS_EMAIL_TMPLAT_MNG`). **잔여**: 정제 미사용 컬럼의 전수 CSV↔DDL 대조는 입고팀 확인(저영향).
- **실측 타입 교훈**: `SNDNG_STDR_DE`·`SEND_DATE`가 문서 TEXT였으나 실측 DATE → UNION 전 타입 확인 필수(§4).

---

## 4. 교훈 요약 (한 줄)
- 사전의 "추정"·"(LLM생성)"은 **실측 전 사실 아님**.
- `_NO`/`_ID` 유사 키는 **grain부터 의심**(distinct 비교).
- PK 있어도 **measure는 실물 중복 별도 확인**.
- 실데이터 타 어카운트 → **쿼리팩+회수 템플릿**으로 분리 실행(P6).
- 미수령/미검증 원천 의존 항목은 **잠정 처리 후 입고/정의서 시 확정**.
- **정의서 타입 ≠ 실측 타입**: UNION/캐스팅 전 `INFORMATION_SCHEMA.COLUMNS`로 실제 타입 확인(예 `SNDNG_STDR_DE`·`SEND_DATE`가 문서 TEXT였으나 실측 DATE → `TRY_TO_TIMESTAMP` 거부, `::TIMESTAMP_NTZ` 사용).
- **다계열 UNION 키는 판별자를 PK에 포함**: 키 도메인이 오늘 분리(overlap 0)여도 미래 충돌 방지 위해 `SEND_CHANNEL` 등 discriminator를 논리 PK에 포함.
