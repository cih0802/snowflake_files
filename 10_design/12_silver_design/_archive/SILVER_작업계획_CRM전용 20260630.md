<!-- LLM-METADATA
doc_id: SILVER_CRM_WORKPLAN
doc_role: silver_work_plan (CRM-only subset / 실행 단위)
project: GN_DW (굿네이버스)
created: 2026-06-29
scope: CRM 단독 — BRONZE_CRM 41테이블만 입고된 현 상황에서 즉시 완성 가능한 SILVER 객체
master_plan: 04_silver_design/SILVER_작업계획_BRONZE-GOLD연결_20260629.md  # 전체(33객체·트랙 A~D·S-1~S-7)의 정본
relation: 본 문서 = master_plan §1-1 CRM 21 + 트랙 A + 단계 S-1~S-5 의 분리 실행본
on_completion: 본 문서의 CRM 21객체(S-1~S-5) 완료 후, GA4/ERP/AGENCY BRONZE 입고 시 → master_plan 으로 복귀하여 트랙 B(GA4)·C(ERP)·D(AGENCY) 및 S-6·S-7(신원브리지) 이어서 진행.
out_of_scope: GA4 5 · ERP 3 · AGENCY 3 · 신원브리지(IDENTITY_MEMBER_XREF) 1 · DIM_DATE(생성) · FSE/FEP의 ADMIN 보강분
inputs(bronze): 99_provided_definition/09_bronze_crm_ddl.sql(타입 정본) · BRONZE_CRM 테이블 정보.MD · 컬럼/테이블정의 CSV(20260629)
inputs(gold): 03_top-down_gold/03_설계.md(24테이블 정본) · 02_지표분류.md
END-METADATA -->

# SILVER 작업계획 — CRM 전용 (실행 단위)

> ⚠️ **본 문서는 마스터 플랜의 CRM 분리 실행본**이다. 전체 SILVER 설계(33객체·4원천·트랙 A~D·S-1~S-7)는
> **`SILVER_작업계획_BRONZE-GOLD연결_20260629.md`(master_plan)** 가 정본.
>
> **▶ 진행 규칙 (LLM 지침)**
> 1. 현 상황 = BRONZE_CRM 41테이블만 입고. 본 문서의 **CRM 21개 SILVER 객체(S-1~S-5)** 만 수행한다.
> 2. 본 문서 완료 후 **GA4·ERP·AGENCY BRONZE가 입고되면 → master_plan 으로 복귀**하여 트랙 B/C/D 와 S-6·S-7(신원 브리지)을 이어서 진행한다.
> 3. 객체 명칭·그레인 원칙·정제 규칙은 master_plan 과 동일(불일치 시 master_plan 우선).

---

## 0. 범위

- **만들 것**: `GN_DW.SILVER` 의 **CRM 21개 객체** (BRONZE_CRM 41 중 사용 38 → 정제·통합 21).
- **이로써 빌드되는 GOLD**: 15테이블 (DATE 생성 포함). 잔여 9는 타 원천 입고 후(master_plan).
- **단계**: S-1 → S-5. (S-6 GA4/ERP/AGENCY, S-7 신원브리지는 **범위 외** → master_plan)
- **범위 외(이번엔 미생성)**: GA4 5 · ERP 3 · AGENCY 3 · `IDENTITY_MEMBER_XREF` 1 · `DIM_DATE`(생성) · FSE/FEP의 ADMIN 보강.

---

## 1. 생성할 CRM 21개 객체

> BRONZE 41 → 사용 38(아래) + 미포함 3(`TM_RM_BPLC_MNG`·`TM_RM_CHILD_MSTR_INFO`·`TM_RM_RELATNSP_CHG_INFO`, GOLD 미참조).
> 그레인 원칙: 채널분리(이메일/문자/우편)·정기/일시는 구조적 UNION으로 통합, 상이한 비즈니스 사건은 분리.

| # | 도메인 | SILVER 객체 | BRONZE 원천 | 그레인(예상·S-1 확정) | 충족 GOLD |
|---|---|---|---|---|---|
| 1 | 회원 | `CRM_MEMBER` | `TM_MM_FDRM_MBER_INFO` ∪ `TM_MM_ONCE_MBER_INFO` | 1 회원(MEMBER_DK), 정기/일시 MEMBER_TYPE | DIM_MEMBER, DIM_MEMBER_IDENTITY(CRM) |
| 2 | 회원 | `CRM_MEMBER_STATUS_HIST` | `TH_MM_FDRM_MBER_STNG_DTLS` | 상태변경 1건 (SCD2, EFFECTIVE_FROM/TO·IS_CURRENT) | DIM_MEMBER, FMM 시점지표, FME |
| 3 | 약정/사건 | `CRM_MEMBER_DEV` | `TM_MM_FDRM_MBER_DVLP_AMT` | 회원×개발(약정) 실적 | FMM, FME |
| 4 | 약정/사건 | `CRM_MEMBER_AMT_CHANGE` | `TM_MM_FDRM_MBER_IRSD` | 증액/감액 사건 | FMM, FME |
| 5 | 약정/사건 | `CRM_MEMBER_DISCONTINUE` | `TM_MM_FDRM_MBER_SPNSR_DSCNTC` | 중단 사건 | FMM, FME |
| 6 | 약정/사건 | `CRM_MEMBER_RESPONSOR` | `TM_MM_FDRM_MBER_RE_SPNSR` | 재후원 사건 | FME |
| 7 | 약정/사건 | `CRM_MEMBER_SPONSOR_BIZ` | `TM_MM_FDRM_MBER_SPNSR_BSNS` | 회원×후원사업 | FMM/FME 후원사업 귀속 |
| 8 | 약정/사건 | `CRM_SPONSOR_RELATION` | `TM_RM_RELATNSP_MSTR_INFO` | 결연(회원×아동) | DIM_MEMBER_IDENTITY 아동 |
| 9 | 납입결제 | `CRM_PAYMENT_BILLING` | `TM_PM_MBRFEE_ACMSLT` ∪ `TM_PM_DNTN_DTLS` | 납입+청구(회비+기부금) | FMM 납입/청구 |
| 10 | 납입결제 | `CRM_PAYMENT_METHOD` | `TM_PM_SETLE_INFO` ∪ `TH_PM_SETLE_INFO_HIST` | 결제수단 | DIM_PAYMENT |
| 11 | 마스터 | `CRM_CAMPAIGN` | `TM_CM_CMPGN_MNG` ∪ `TM_CM_BRND_MNG` ∪ `TM_CM_MKTNG_CMPGN_MNG` | 1 캠페인 | DIM_CAMPAIGN |
| 12 | 마스터 | `CRM_SPONSORSHIP` | `TM_CM_SPNSR_BSNS_INFO` | 1 후원사업 | DIM_SPONSORSHIP |
| 13 | 마스터 | `CRM_ORG` | `TM_CM_DEPT_INFO` | 1 조직노드 (SCD2) | DIM_ORG |
| 14 | 마스터 | `CRM_DEV_TARGET` | `TM_CM_MBER_DVLP_GOAL` | 월×조직×개발구분 | FTG-D |
| 15 | 발송 | `CRM_SEND_REQUEST` | `SND_REQ_MST` ∪ `TM_MS_EMAIL_SNDNG` ∪ `TM_MS_MSG_AT_SNDNG` ∪ `TM_MS_PSTMTR_SNDNG` | 발송요청(채널통합) | DIM_SERVICE, FSE |
| 16 | 발송 | `CRM_SEND_MEMBER` | `SND_MEMBER_LIST` ∪ `TD_MS_EMAIL_SNDNG_DTLS` ∪ `TD_MS_MSG_AT_SNDNG_DTLS` ∪ `TD_MS_PSTMTR_SNDNG_DTL` | 발송×회원 | FSE |
| 17 | 발송 | `CRM_SEND_RESULT` | `TD_MS_EMAIL_LQY_SNDNG` ∪ `TD_MS_MSG_AT_LQY_SNDNG` ∪ `TD_MS_PSTMTR_LQY_SNDNG` | 발송×채널 성과 | FSE |
| 18 | 행사 | `CRM_EVENT` | `TM_MS_EVENT` ∪ `TM_MS_CRMN` | 1 행사 | DIM_EVENT |
| 19 | 행사 | `CRM_EVENT_PARTICIPATION` | `TD_MS_EVENT_PRTCPNT_DTL` ∪ `TD_MS_CRMN_PRTCPNT` | 행사×참여자 | FEP |
| 20 | 결연활동 | `CRM_RELATION_ACTIVITY` | `TM_RM_RELATNSP_LETTER_INFO` ∪ `TM_RM_RELATNSP_GFTMNEY_INFO` | 서신·선물금 | FSE(서신/선물금참여) |
| 21 | 코드 | `CRM_CODE` | `TC_CMMN_CD` ∪ `TC_CMMN_DTL_CD` | 코드그룹×코드 | DIM_REASON + 전 객체 라벨 |

---

## 2. 빌드되는 GOLD 15테이블

- **CRM 단독 완결 (후속 원천 보강 없음, 9)**: DIM_MEMBER · DIM_CAMPAIGN · DIM_SPONSORSHIP · DIM_ORG · DIM_PAYMENT · DIM_REASON / FMM · FME · FTG-D
- **CRM으로 생성·적재 + 후속 보강 있음 (5)**: DIM_SERVICE(+ADMIN 앱푸시 채널) · DIM_EVENT(+ADMIN 온라인행사) · FSE(+ADMIN 앱푸시 발송) · FEP(+ADMIN 조회수) · DIM_MEMBER_IDENTITY(+GA 신원 매핑) — **CRM분으로 구조·적재 완료, 보강은 입고 시 행/컬럼 추가(차단 아님)**
- **생성(원천 무관, 1)**: DIM_DATE — GOLD/util에서 생성(SILVER 객체 아님)

> 잔여 GOLD 9테이블(DIM_AD_CREATIVE·DIM_GA_SOURCE·DIM_GA_EVENT·DIM_DEVICE·DIM_BUDGET_ITEM·FTG-B·FGA·FAD·FBD)은 GA4·ERP·AGENCY 입고 후 → master_plan 트랙 B/C/D.

---

## 3. 단계별 작업 (S-1 ~ S-5)

| 단계 | 산출물 | 내용 |
|---|---|---|
| **S-1** | 엔티티 설계서 21개 (`S1_CRM_entity_design/`) | 객체별 grain·PK·컬럼선별·타입·정제규칙·증분키 확정 |
| **S-2** | DDL 초안 | `CREATE TABLE GN_DW.SILVER.CRM_*` 21개 (Snowflake 컴파일 검증) |
| **S-3** | 정제 매핑표 | BRONZE 컬럼 → SILVER 컬럼 1:1 (타입캐스팅·코드→라벨·NULL표준화·메타 4컬럼) |
| **S-4** | 정제 프로시저 | `SP_REFINE_CRM_*` (`CREATE OR REPLACE TABLE` 멱등) |
| **S-5** | GOLD 역산 검증 | §2 의 15 GOLD 테이블 컬럼 대비 누락·불일치 점검 |

---

## 4. S-1 착수 전 선결 (CRM 내부) — 실측으로 4 해소(Q4·Q13·Q14·Q15 ✅), **잔존 Q5·Q6**

| Q | 무엇 | 영향 객체 |
|---|---|---|
| Q4 ✅ | **MM010 확정** — 12상태(1=활동회원·2~6 신규미납·7~11 장기미납·12 후원중단). 라벨 조인 **(CD_ID,DTL_CD_ID) 복합** | `CRM_MEMBER_STATUS_HIST` (SCD2) |
| Q5 | 발송키 이원화(`SND_*.SEQ_NO` vs `TM_MS_*.SNDNG_KEY`) | `CRM_SEND_REQUEST`/`_MEMBER`/`_RESULT` |
| Q6 | 정기·일시 UNION 스키마 정렬 규칙 | `CRM_MEMBER` |
| Q13 ✅ | **폭발 없음** — `DVLP_AMT` 자연키 유일=스파인 + `SPNSR_BSNS` N:1 **LEFT JOIN**(multi_key=0, 미매칭 74행 보존), 결연 별도 | 약정/사건 5종 |
| Q14 ✅ | **납입 SUM 중복 확인** — `MBRFEE_KEY`=PK. 동일 납입 복수 적상행 5.4% → **납입은 납입건 dedup 집계·청구는 행 기준**. 기부금=납입만(`DNTN_KEY`=PK) | `CRM_PAYMENT_BILLING` |
| Q15 ✅ | **실측 완료** — `SPNSR_BSNS_ID`=후원사업(=DIM_SPONSORSHIP 키; 당시 29개 → **06-30 마스터 실측 50, AC-2 재확인**), `SPNSR_BSNS_NO`=약정/관계 번호(약 215만). NO→ID 다대일. 결연은 NO만 → 정제 시 `DVLP_AMT`/`SPNSR_BSNS`/`MBRFEE_ACMSLT`에서 NO→ID 크로스워크(커버리지 100%). ⚠️NO 20건 모호 클렌징(결연 기준; 약정 S9 실측=16, 모집단 상이) | `CRM_SPONSOR_RELATION` |

> **나머지 Q (master_plan §5)**:
> - **CRM 관련·빌드 중 해소(선결 아님)**: Q2·Q3(캠페인 코드↔라벨, `CRM_CAMPAIGN`) · **Q7 ✅원천 확정**(조직 역할 3종 `ACT_DEPT_CD`·`ACMSLT_DEPT_CD`·`REGIST_DEPT_CD` DDL 존재 — FMM/FME 설계 반영만) · Q8(EVENT_TYPE 코드체계, `CRM_MEMBER_*` 사건/FME) · Q11(`EHGT` 의미, `CRM_RELATION_ACTIVITY`) · Q12(컬럼집합 불일치 검증) — S-1~S-3 진행 중 데이터로 확정.
> - **타 원천 의존(범위 외)**: Q1(GA 신원) · Q9(GA/AGENCY 출처) · Q10(ERP 세세목) → 입고 후 master_plan.

---

## 5. 공통 정제 규칙 (전 객체 적용)

- **타입 정본** = `09_bronze_crm_ddl.sql`. 컬럼집합 불일치는 입고팀 확인.
- **코드 → 라벨 병행보존**: `CRM_CODE`(`TC_CMMN_DTL_CD`, CD_ID+DTL_CD_ID) 조인으로 `_NM` 생성. 하드코딩(예 `SNDNG_RST_CD` 0/1/4/5)은 CASE 매핑.
- **NULL/날짜/숫자/문자 표준화**: 빈문자·`'NULL'`·`'-'`→NULL · `YYYYMMDD`→DATE · 콤마/통화기호 제거 · TRIM·UTF-8 · 컬럼명 UPPER_SNAKE_CASE.
- **금액 원단위 보존** (`(건)=SUM(금액)/10000` 변환은 GOLD에서).
- **메타 4컬럼**: `_SOURCE_SYSTEM`(=CRM) · `_SOURCE_TABLE` · `_LOADED_AT` · `_BATCH_ID`.
- **SCD2는 상태만**(성별·지역·신규기존은 SCD1). 집계·교차소스 조인 금지(GOLD에서).

---

## 6. 완료 정의 & 다음

- **완료**: CRM 21객체 DDL 생성 + 정제 프로시저 적재 + 15 GOLD 테이블 역산 검증 통과(S-5).
- **다음(LLM)**: GA4/ERP/AGENCY BRONZE 입고 시 → **`SILVER_작업계획_BRONZE-GOLD연결_20260629.md`** 의 트랙 B/C/D 및 S-6·S-7(신원 브리지)로 복귀해 이어서 진행.
