<!-- LLM-METADATA
doc_id: SILVER_ISSUE_HANDOVER
doc_role: 이슈·해결 핸드오버 노트 (CRM SILVER 설계 선결 Q)
project: GN_DW (굿네이버스)
created: 2026-06-29
purpose: 인수인계자가 유사 이슈 발생 시 읽고 대응. Q번호는 master_plan §5와 동일.
refs: SILVER_작업계획_BRONZE-GOLD연결_20260629.md(master §5 Q표) · SILVER_작업계획_CRM전용_20260629.md(§4) · 09_bronze_crm_ddl.sql · BRONZE_CRM 테이블 정보.MD · 06_지표용어사전 20260624.md
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

## 3. 미해결 — 인수인계 대응 가이드

### Q5 ⚠️ 발송키 이원화 (패턴 P5)
- **이슈**: `SND_*.SEQ_NO` vs `TM_MS_*/TD_MS_*.SNDNG_KEY` 관계 불명(병렬/구신/마이그레이션?).
- **막힌 이유**: `SND_*` 컬럼 설명이 **"(LLM생성)" 미검증** → 키 단정 불가.
- **대응**: ① `SND_*` 원본 정의서 확보(필수) ② 확보 전 임시 진단 = 두 키 값집합 overlap·날짜/회원 기준 행 매칭률 프로파일링(P3 응용) → 미러/병렬 추정. 결론 전까지 `CRM_SEND_*` 키 설계 잠정.
- **[실측 2026-06-30]**: `SND_REQ_MST.SEQ_NO` 1,566 전건 유일·`TM_MS_EMAIL_SNDNG.SNDNG_KEY` 483,629 전건 유일 → **각 마스터에서 PK 유효**. 두 키 grain 상이(요청 1,566 vs 이메일발송 483,629)로 **별개 계열 확정**(별칭 아님). 단 SND_* 컬럼은 여전히 미검증 → 최종 PK는 정의서 확인 후.

### Q6 ⚠️ 정기/일시 회원 UNION 정렬
- **이슈**: `TM_MM_FDRM_MBER_INFO`(정기)·`TM_MM_ONCE_MBER_INFO`(일시) 컬럼셋·동일의미 표현 상이(수신동의: 정기 코드 vs 일시 Y/N).
- **성격**: 데이터 이슈보다 **설계 결정**. 실측으로 "해결"되지 않음.
- **대응**: S-1 `CRM_MEMBER` 설계 시 — 공통 교집합 + NULL 패딩 + `MEMBER_TYPE` 구분 + 수신동의 등 표준화 매핑 정의. 값 분포는 distinct 프로파일링으로 보조.
- **[실측 2026-06-30]**: 정기 1,575,046(전건 숫자·38% leading-zero·len≤7)·일시 175,061(**전건 비숫자**·len≤9)·**번호 충돌 0**. ⇒ `MEMBER_DK`=**VARCHAR(10)** 확정(일시 비숫자·정기 0시작으로 NUMBER 불가), 충돌0이라 **접두 불요**. **GOLD `MEMBER_DK` NUMBER(38,0)→VARCHAR(10) ✅ 반영 완료(AC-1, GOLD CSV·05_필드인벤토리)**(TYPE-MDK). 수신값: 정기 `EMAIL_RECPTN_CD`가 **콤마 멀티값**(`'2,5,6'`·`'2, 3, 4, 5'`·순서/공백 제각각·`'Y'`·공백 혼재)·일시 Y/N → 단일코드 아님, **집합 정규화 규칙 필요**. SEX도 1·2 외 3·4·5·6·7·8·공백 존재 → 보정 매핑 보강.

---

## 4. 교훈 요약 (한 줄)
- 사전의 "추정"·"(LLM생성)"은 **실측 전 사실 아님**.
- `_NO`/`_ID` 유사 키는 **grain부터 의심**(distinct 비교).
- PK 있어도 **measure는 실물 중복 별도 확인**.
- 실데이터 타 어카운트 → **쿼리팩+회수 템플릿**으로 분리 실행(P6).
- 미수령/미검증 원천 의존 항목은 **잠정 처리 후 입고/정의서 시 확정**.
