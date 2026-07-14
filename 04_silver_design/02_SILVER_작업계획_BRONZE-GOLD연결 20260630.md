<!-- LLM-METADATA
doc_id: SILVER_BRIDGE_PLAN
doc_role: silver_work_plan (bronze↔gold 연결)
project: GN_DW (굿네이버스)
created: 2026-06-29
inputs(gold): 03_top-down_gold/03_설계.md(24테이블 정본) · 02_지표분류.md(215지표) · GOLD_개발자_전달노트_20260629.md · gold 스키마 컬럼 인벤토리_20260629.csv
inputs(bronze): 99_provided_definition/BRONZE_CRM 테이블 정보.MD · 09_bronze_crm_ddl.sql(타입 정본) · 08_bronze_ga4_events_schema.md(GA4 구조 참조)
inputs(index): 99_provided_definition/01_원천보고서_인벤토리 인덱스.md
END-METADATA -->

# SILVER 작업계획 — BRONZE → SILVER → GOLD

> **목적**: BRONZE 원천을 GOLD star schema(**24테이블 = 15 DIM + 9 FACT**, 정본 `03_설계.md`)로 적재하기 위해
> **SILVER 정제 레이어에서 만들 객체와 작업**을 정의한다.

---

## 0. 입력·전제

- **GOLD 목표**: 24테이블(15 DIM + 9 FACT). 모든 GOLD 테이블이 SILVER로 빌드 가능해야 함(§1-1 검증).
- **원천 4개 + 현재 상태**:
  | 원천 | 상태 | 정본 |
  |---|---|---|
  | CRM | ✅ 수령 | `09_bronze_crm_ddl.sql`(41테이블, 타입 정본) + 컬럼/테이블정의 CSV |
  | GA4 | 🟡 스키마 스펙만 | `08_bronze_ga4_events_schema.md`(구조 참조) |
  | ERP | ⛔ 미수령 | — |
  | AGENCY (= AGENCY ∪ GADS ∪ ADMIN) | 🟢 3테이블 실적재(2026-07-10) | DGT 197,686 / REBRDC 2,064 / VIDEO 35,822행 |
- ⚠️ **[AGENCY 실적재 반영 2026-07-10]** 아래 트랙 D의 "⛔미수령"은 스키마 선정의 시점 표기이며, 실제로는 AGENCY 3테이블(디지털 DGT·재송출 REBRDC·영상 VIDEO)이 표본 적재됨. 적재 결과 발견:
  - **_SOURCE_SYSTEM 부재(결론5·A-2)**: 3테이블에 행 단위 출처 플래그 없음. `GA_`/`CRM_` 접두는 지표별 귀속시스템(GA집계 vs CRM집계)이지 광고 출처(대행사 vs Google Ads) 아님. 3테이블 분리도 광고**유형**(디지털/재송출/영상)이지 출처 아님 → SILVER→FAD 적재 시 명시 `_SOURCE_SYSTEM` 부여 필요.
  - **인입콜 타입 불일치(결론4)**: 재송출(REBRDC).INBOUND_CALL_CNT=**TEXT** vs 영상(VIDEO).INBOUND_CALL_CNT=**NUMBER** → 통합 전 `TRY_TO_NUMBER` 캐스팅 필수. 영상 `CONV_CALL_CNT`(전환콜)은 인입콜과 별개 measure.
  - **명/건·CVR(결론1·2)**: 전환수 `GA_CONV_MBER_CNT`(명, Σ122,551) > `CONV_VU_CNT`(Σ63,372.9, **소수=비건수**) → VU '건' 단정 금지. `CVR=전환명/클릭` 확정(오차1.7e-6, O5).
- GADS·ADMIN은 **AGENCY로 흡수**(별도 prefix 미생성).
- 미수령 원천: GOLD·SILVER 모두 **컬럼/스키마만 선정의**, 데이터 적재는 입고 후.

---

## 1. SILVER 위치·명명·범위

- **스키마**: `GN_DW.SILVER` 단일.
- **테이블명 = 소스 접두사 + 엔티티**: `CRM_*` · `GA4_*` · `ERP_*` · `AGENCY_*`.
- **계층 단방향**: `SERVING → GOLD → SILVER → BRONZE`. GOLD는 BRONZE 직접참조 금지.
- **SILVER가 하는 일 (정제만)**:
  1. 물리 타입 캐스팅 (`09_bronze_crm_ddl.sql` 정본 기준 — VARCHAR(255) 등 원천 과대타입 → 의미타입)
  2. NULL/빈값 표준화 (`'' → NULL`, Y/N·코드 빈값 규칙)
  3. **코드 → 라벨 병행보존** (코드 컬럼 + `_NM` 라벨 동시 보유, `TC_CMMN_DTL_CD` 조인)
  4. PK 기준 **중복제거**·증분 적재 키 정의
  5. **동일 소스 내 JOIN**(마스터 결합)까지만. **집계(GROUP BY)·교차소스 conform 조인은 GOLD에서.**
- **SILVER가 안 하는 일**: 비율·증감·LTV·ROI 등 derived(81개) 계산 → GOLD/SV. 월 롤업·cohort 집계 → GOLD FACT 적재 프로시저.

### 1-1. SILVER 생성 객체 목록

> **설계 기준**: _GOLD 24테이블을 전부 만들 수 있는가_. 입력 2축 — ① GOLD가 요구하는 컬럼(§2-1/§2-2 역산) ② BRONZE에서 정제로 구성 가능한 범위.
>
> **그레인 원칙**: SILVER 객체 = **원천 비즈니스 객체 1개**. 같은 소스의 채널분리(이메일/문자/우편)·정기/일시 분리는 구조적 UNION으로 통합하되, **서로 다른 비즈니스 사건(개발·증감·중단·재후원·발송·행사참여)은 분리 유지**(GOLD가 FACT별 다른 그레인으로 소비). 집계·교차소스 결합은 SILVER가 하지 않음.
> §2-1/§2-2는 GOLD 테이블별 관점, 본 §1-1·§2-3은 SILVER 객체 관점 — 객체 명칭은 양쪽 동일.

**객체 수 요약**

| 소스 | 개수 | 상태 | 생성 시점 |
|---|---|---|---|
| CRM | 21 | ✅원천 수령 | 즉시(트랙 A) |
| GA4 | 5 | 🟡스펙만 | 입고 후(트랙 B) |
| ERP | 3 | ⛔미수령 | 입고 후(트랙 C) |
| AGENCY(∪GADS∪ADMIN) | 3 | ⛔미수령 | 입고 후(트랙 D) |
| 신원 브리지(교차소스) | 1 | 🟡 | GA4 입고 후(S-7) |
| **합계** | **33** | | DATE 차원은 별도(생성) |

**GOLD 24 ← SILVER 충족 매트릭스 (완전성 검증)**

| GOLD | 충족 SILVER 객체 | 상태 |
|---|---|---|
| DIM_DATE | (생성 — 원천 없음, GOLD/util seed) | ✅ |
| DIM_MEMBER (SCD2) | CRM_MEMBER + CRM_MEMBER_STATUS_HIST | ✅ |
| DIM_MEMBER_IDENTITY | CRM_MEMBER(+CRM_SPONSOR_RELATION 아동) + GA4_IDENTITY → **IDENTITY_MEMBER_XREF** | ✅/🟡 |
| DIM_CAMPAIGN | CRM_CAMPAIGN | ✅ |
| DIM_SPONSORSHIP | CRM_SPONSORSHIP | ✅ |
| DIM_ORG (SCD2) | CRM_ORG | ✅ |
| DIM_AD_CREATIVE | AGENCY_AD_CREATIVE | ⛔ |
| DIM_GA_SOURCE | GA4_TRAFFIC_SOURCE | 🟡 |
| DIM_GA_EVENT | GA4_EVENT_DIM | 🟡 |
| DIM_SERVICE | CRM_SEND_REQUEST + CRM_CODE | ✅ |
| DIM_PAYMENT | CRM_PAYMENT_METHOD + CRM_CODE | ✅ |
| DIM_REASON | CRM_CODE | ✅ |
| DIM_DEVICE | GA4_DEVICE (또는 seed) | 🟡 |
| DIM_EVENT | CRM_EVENT (+ADMIN 온라인행사) | ✅ |
| DIM_BUDGET_ITEM | ERP_BUDGET_ITEM | ⛔ |
| FMM | CRM_MEMBER_DEV + CRM_MEMBER_AMT_CHANGE + CRM_MEMBER_DISCONTINUE + CRM_PAYMENT_BILLING + CRM_MEMBER_STATUS_HIST + CRM_MEMBER_SPONSOR_BIZ(후원사업 귀속) | ✅ |
| FME | CRM_MEMBER_DEV + CRM_MEMBER_AMT_CHANGE + CRM_MEMBER_DISCONTINUE + CRM_MEMBER_RESPONSOR + CRM_MEMBER_STATUS_HIST + CRM_MEMBER_SPONSOR_BIZ(후원사업 귀속) | ✅ |
| FTG-D | CRM_DEV_TARGET | ✅ |
| FTG-B | ERP_BIZ_TARGET | ⛔ |
| FSE | CRM_SEND_REQUEST + CRM_SEND_MEMBER + CRM_SEND_RESULT + CRM_RELATION_ACTIVITY(서신/선물금) [+ADMIN 앱푸시] | ✅ |
| FGA | GA4_EVENT | 🟡 |
| FAD | AGENCY_AD_PERFORMANCE + GA4_EVENT(전환) | ⛔/🟡 |
| FEP | CRM_EVENT_PARTICIPATION [+ADMIN 조회수] | ✅ |
| FBD | ERP_BUDGET + AGENCY_COST | ⛔ |

→ **24/24 빌드 가능**(미수령 원천 입고 전제). CRM 단독으로 GOLD 15테이블 착수 가능(`DIM_MEMBER_IDENTITY`·`FSE`·`FEP`는 CRM분 우선 — GA·ADMIN 보강은 입고 후), 잔여 9는 GA4·ERP·AGENCY 입고로 충족. 컬럼은 24테이블 모두 선생성.

**설계 주석**
- **DIM_DATE**: 원천 없는 conform 차원 → SILVER 정제 대상 아님. GOLD(또는 util) 생성 → SILVER 객체 수 제외.
- **IDENTITY_MEMBER_XREF**: SILVER 원칙(동일소스 only)의 **유일한 교차소스 예외**. GA↔CRM 신원해소는 매칭 로직이 무거워 전용 브리지로 격리(`MATCH_METHOD`/`MATCH_CONFIDENCE`). S-7에서 위치(SILVER vs GOLD) 확정.
- **ADMIN 피드**(앱푸시→FSE, 행사 조회수→FEP)는 AGENCY로 흡수 또는 CRM 서비스에 합류 — 목적지 미정.
- **명명 규칙**: `<SRC>_<SUBJECT>[_<QUALIFIER>]` (예 `CRM_MEMBER_STATUS_HIST`). 차원/팩트 구분 접미사(`_DIM`·`_MASTER`)는 SILVER에서 강제하지 않음.

---

## 2. BRONZE → SILVER → GOLD 연결 매트릭스 (핵심)

> 범례 — 원천상태: ✅수령(CRM) · 🟡스펙만(GA4) · ⛔미수령(ERP·AGENCY/GADS/ADMIN)

### 2-1. 차원 (15 DIM)

| GOLD DIM | SILVER 객체(§1-1) | BRONZE 원천 | 상태 | 핵심 작업 / 비고 |
|---|---|---|---|---|
| D1 `DIM_DATE` | (생성) | 없음 | ✅ | 달력 생성 테이블. 원천 없음 — SILVER 또는 GOLD에서 generate |
| D2 `DIM_MEMBER` (SCD2) | `CRM_MEMBER` + `CRM_MEMBER_STATUS_HIST` | `TM_MM_FDRM_MBER_INFO` ∪ `TM_MM_ONCE_MBER_INFO` + `TH_MM_FDRM_MBER_STNG_DTLS` | ✅ | 정기/일시 **UNION ALL 스키마 정렬**(§5 Q6). 상태이력으로 **SCD2 effective range** 구성. `SEX` 6/7/8(단체·기업·기타) 보정 |
| D3 `DIM_MEMBER_IDENTITY` | `CRM_MEMBER`(+`CRM_SPONSOR_RELATION` 아동) + `GA4_IDENTITY` → `IDENTITY_MEMBER_XREF` | CRM 회원번호(=memnum=member id) / GA4 `user_id` / 결연아동코드 | ✅/🟡 | CRM측 즉시. **GA↔CRM 식별자 매핑**은 GA4 입고 후(§5 Q1). 결연아동코드는 GA4 URL 파싱 |
| D4 `DIM_CAMPAIGN` | `CRM_CAMPAIGN` | `TM_CM_CMPGN_MNG` + `TM_CM_BRND_MNG` + `TM_CM_MKTNG_CMPGN_MNG` | ✅ | 캠페인유형·국내해외·사업사례 = `TM_CM_CMPGN_MNG` 의 `CMPGN_CTGR_CD`/`CMPGN_TYPE1_BSN`/`CMPGN_TYPE2_BSN`(NUMBER 코드, 코드그룹 MM293~296 추정). 코드↔라벨 정의서 대기(§5 Q2·Q3) |
| D5 `DIM_SPONSORSHIP` | `CRM_SPONSORSHIP` | `TM_CM_SPNSR_BSNS_INFO` | ✅ | 키 = `SPNSR_BSNS_ID`(**마스터 실측 50개**; 기존 기록 29와 차이 — 원인 미확정, AC-2/O13·S13 대조. DIM=전체 마스터 적재). `SPNSR_BSNS_NM`·`SPNSR_BSNS_ABRV_CD`. 결연은 `SPNSR_BSNS_NO`만 보유 → NO→ID 크로스워크 필요(§5 Q15) |
| D6 `DIM_ORG` (SCD2) | `CRM_ORG` | `TM_CM_DEPT_INFO` | ✅ | 부서 계층(`UPPER_DEPT_ID`). **TEAM=실적팀은 `ACMSLT_UPPER_DEPT_ID` 재귀·루트 'ZV000000'·LVL5**(현업쿼리 review/05; CRM_ORG에 USE_YN·SORT_ORDR 추가 필요). **조직 역할 3종**(회원 테이블): 활동(`ACT_DEPT_CD`)·실적(`ACMSLT_DEPT_CD`)·등록(`REGIST_DEPT_CD`) → FMM/FME 역할별 FK (O10) |
| D7 `DIM_AD_CREATIVE` | `AGENCY_AD_CREATIVE` | AGENCY 일별레포트 | ⛔ | 매체·플랫폼·소재·CM위치·초수·RT유형. **데이터 입고 후** |
| D8 `DIM_GA_SOURCE` | `GA4_TRAFFIC_SOURCE` | GA4 `session_traffic_source_last_click`(UI 일치) | 🟡 | utm source/medium/content/term. FLATTEN 후 추출 |
| D9 `DIM_GA_EVENT` | `GA4_EVENT_DIM` | GA4 `event_name`·`event_params` | 🟡 | event_category/label/action. `LATERAL FLATTEN(event_params)` |
| D10 `DIM_SERVICE` | `CRM_SEND_REQUEST` + `CRM_CODE` | `SND_REQ_MST`(발송구분 대/중/소) + `TM_MS_*_SNDNG` 채널 | ✅ | CRM_UMS 채널. **앱푸시(ADMIN) 채널은 AGENCY/ADMIN 입고 후 추가** |
| D11 `DIM_PAYMENT` | `CRM_PAYMENT_METHOD` | `TM_PM_*` + 코드그룹(납입방식·결제·회비유형) | ✅ | 납입방식×결제방식×회비유형 조합 차원 |
| D12 `DIM_REASON` | `CRM_CODE` | 코드그룹 MM005(중단)·MM002(취소/미납) via `TC_CMMN_DTL_CD` | ✅ | 중단사유#162·미납사유#82(⚠️합의). REASON_TYPE 구분 |
| D13 `DIM_DEVICE` 🆕 | `GA4_DEVICE` / (생성) | GA4 `device`/`platform` ∪ AGENCY 기기 | 🟡/⛔ | PC/M/APP. APP 정의(GA4 platform vs 앱SDK) **확인**(O2) |
| D14 `DIM_EVENT` 🆕 | `CRM_EVENT` | `TM_MS_EVENT` + `TM_MS_CRMN` | ✅ | 온라인/오프라인(문화) 행사·행사명·기간·신청경로. 온라인이벤트 ADMIN 수집분은 입고 후 |
| D15 `DIM_BUDGET_ITEM` 🆕 | `ERP_BUDGET_ITEM` | ERP 세세목 마스터 | ⛔ | 예산 세세목·예산구분. **ERP 미수령** |

### 2-2. 팩트 (9 FACT)

| GOLD FACT | grain | SILVER 객체(§1-1) | BRONZE 원천 | 상태 | 핵심 작업 |
|---|---|---|---|---|---|
| `FMM` MEMBER_MONTHLY | 월×MEMBER_DK | `CRM_MEMBER_DEV`·`CRM_MEMBER_AMT_CHANGE`·`CRM_MEMBER_DISCONTINUE`·`CRM_PAYMENT_BILLING`·`CRM_MEMBER_STATUS_HIST`·`CRM_MEMBER_SPONSOR_BIZ` | `TM_MM_FDRM_MBER_DVLP_AMT`·`TM_MM_FDRM_MBER_IRSD`·`TM_PM_MBRFEE_ACMSLT`·상태이력 | ✅ | 일 grain(FME) **월 롤업 스냅샷**. `(건)=SUM(금액)/10000` 원금액 보존. 시점지표#49·50·52·53는 상태이력 기반 |
| `FME` MEMBER_EVENT 🆕 | 일×MEMBER_DK×EVENT_TYPE | `CRM_MEMBER_DEV`·`CRM_MEMBER_AMT_CHANGE`·`CRM_MEMBER_DISCONTINUE`·`CRM_MEMBER_RESPONSOR`·`CRM_MEMBER_STATUS_HIST` | `TM_MM_FDRM_MBER_DVLP_AMT`(개발)·`TM_MM_FDRM_MBER_SPNSR_DSCNTC`(중단)·`TM_MM_FDRM_MBER_IRSD`(증감) | ✅ | **1행=1상태전이**. EVENT_TYPE 코드체계 정의(O6). 가입↔중단 간격=유지기간(LTV base) |
| `FTG-D` TARGET_DEV | 월×조직×개발구분 | `CRM_DEV_TARGET` | `TM_CM_MBER_DVLP_GOAL`(`GOAL_CNT`) | ✅ | 파생 #1~3 분모. DEV_TYPE(`MBER_DVLP_DIV_CD` MM015) conform |
| `FTG-B` TARGET_BIZ | 월×조직×후원사업[×캠페인] | `ERP_BIZ_TARGET` | ERP/사업계획 #152~155 | ⛔ | 연사업·추경 (누계)목표. **ERP 미수령·적재예약** |
| `FSE` SERVICE_EVENT | 일×MEMBER×SERVICE×CAMP | `CRM_SEND_REQUEST`·`CRM_SEND_MEMBER`·`CRM_SEND_RESULT`·`CRM_RELATION_ACTIVITY` | `SND_REQ_MST`·`SND_MEMBER_LIST`·`TM_MS_*_SNDNG`·`TD_MS_*_SNDNG_DTLS`·`TD_MS_EMAIL_*` | ✅ | 발송·성공·실패·오픈·서신/선물금참여·+5일차 매칭. **발송키 이원화**(`SEQ_NO` vs `SNDNG_KEY`) 정합(§5 Q5). 앱푸시(ADMIN)는 입고 후 |
| `FGA` GA_BEHAVIOR | 일×IDENTITY×EVENT×SOURCE×DEVICE×CAMP×페이지 | `GA4_EVENT` | GA4 `events_YYYYMMDD` | 🟡 | FLATTEN(event_params/items). #98 평균세션시간·#108 이탈율 = **비가산** 적재(O1). 결연아동코드 URL 파싱 |
| `FAD` AD_PERFORMANCE | 일×CAMP×소재×DEVICE | `AGENCY_AD_PERFORMANCE` | AGENCY·GADS 일별레포트 + GA4 전환 | 🟢실적재 | 광고비·노출·클릭·인입콜·전환수(명/건). ⚠️인입콜 REBRDC=TEXT/VIDEO=NUMBER→`TRY_TO_NUMBER`(결론4). ⚠️행단위 `_SOURCE_SYSTEM` 부재→SILVER 부여(결론5). 노출·클릭 **GA vs AGENCY 출처구분**(§5 Q9). CVR=전환명/클릭(결론2). 비용 base는 FBD 분리 |
| `FEP` EVENT_PARTICIPATION 🆕 | 일×MEMBER×EVENT | `CRM_EVENT_PARTICIPATION` | `TD_MS_EVENT_PRTCPNT_DTL`·`TD_MS_CRMN_PRTCPNT` + ADMIN 조회수 | ✅ | 모집/참여/대기/취소 인원·참여횟수. 참여정의 서비스별 상이→`PARTICIPATION_DEF` 메타(O4). 조회수(ADMIN)는 입고 후 |
| `FBD` BUDGET 🆕 | 월×조직×세세목[×캠페인] | `ERP_BUDGET`·`AGENCY_COST` | ERP 편성/집행예산 + AGENCY 모금성비용 | ⛔ | 개발단가·ROI(신#9·10·11) 비용 분모. **누계는 SV(P7)**. 세세목↔캠페인 매핑 미합의(O3) |

### 2-3. BRONZE CRM 41 → SILVER CRM 21 정제 매핑 (DDL 검증)

> §1-1 CRM 21개의 **원천→SILVER 매핑 상세**. 41개 원천 테이블명은 `09_bronze_crm_ddl.sql` 와 1:1 대조 확인(타입·컬럼 정본은 DDL). 그레인 원칙은 §1-1.

```
회원      TM_MM_FDRM_MBER_INFO ∪ TM_MM_ONCE_MBER_INFO              → CRM_MEMBER (정기+일시, MEMBER_TYPE 구분)
          TH_MM_FDRM_MBER_STNG_DTLS                                → CRM_MEMBER_STATUS_HIST (SCD2 상태이력)
약정/사건 TM_MM_FDRM_MBER_DVLP_AMT                                 → CRM_MEMBER_DEV (개발 약정 실적·월)
          TM_MM_FDRM_MBER_IRSD                                     → CRM_MEMBER_AMT_CHANGE (증액/감액)
          TM_MM_FDRM_MBER_SPNSR_DSCNTC                             → CRM_MEMBER_DISCONTINUE (중단)
          TM_MM_FDRM_MBER_RE_SPNSR                                 → CRM_MEMBER_RESPONSOR (재후원)
          TM_MM_FDRM_MBER_SPNSR_BSNS                               → CRM_MEMBER_SPONSOR_BIZ (회원×후원사업)
          TM_RM_RELATNSP_MSTR_INFO                                 → CRM_SPONSOR_RELATION (결연/아동; SPNSR_BSNS_NO만 → ID 크로스워크 §5 Q15) ★Q15
납입결제  TM_PM_MBRFEE_ACMSLT ∪ TM_PM_DNTN_DTLS                    → CRM_PAYMENT_BILLING (회비+기부금) ★Q14
          TM_PM_SETLE_INFO ∪ TH_PM_SETLE_INFO_HIST                 → CRM_PAYMENT_METHOD
마스터    TM_CM_CMPGN_MNG ∪ TM_CM_BRND_MNG ∪ TM_CM_MKTNG_CMPGN_MNG → CRM_CAMPAIGN
          TM_CM_SPNSR_BSNS_INFO                                    → CRM_SPONSORSHIP
          TM_CM_DEPT_INFO                                          → CRM_ORG
          TM_CM_MBER_DVLP_GOAL                                     → CRM_DEV_TARGET
발송      SND_REQ_MST ∪ TM_MS_EMAIL_SNDNG ∪ TM_MS_MSG_AT_SNDNG ∪ TM_MS_PSTMTR_SNDNG → CRM_SEND_REQUEST (발송요청·채널통합) ⚠️Q5
          SND_MEMBER_LIST ∪ TD_MS_EMAIL_SNDNG_DTLS ∪ TD_MS_MSG_AT_SNDNG_DTLS ∪ TD_MS_PSTMTR_SNDNG_DTL → CRM_SEND_MEMBER (발송×회원)
          TD_MS_EMAIL_LQY_SNDNG ∪ TD_MS_MSG_AT_LQY_SNDNG ∪ TD_MS_PSTMTR_LQY_SNDNG → CRM_SEND_RESULT (발송×채널 성과)
행사      TM_MS_EVENT ∪ TM_MS_CRMN                                 → CRM_EVENT (행사/캠페인행사 마스터)
          TD_MS_EVENT_PRTCPNT_DTL ∪ TD_MS_CRMN_PRTCPNT             → CRM_EVENT_PARTICIPATION (행사 참여)
결연활동  TM_RM_RELATNSP_LETTER_INFO ∪ TM_RM_RELATNSP_GFTMNEY_INFO  → CRM_RELATION_ACTIVITY (서신·선물금)
코드      TC_CMMN_CD ∪ TC_CMMN_DTL_CD                              → CRM_CODE (코드→라벨)
```
**미포함 3개**(GOLD 미참조): `TM_RM_BPLC_MNG`(사업장) · `TM_RM_CHILD_MSTR_INFO`(아동마스터, 향후 DIM 확장 여지) · `TM_RM_RELATNSP_CHG_INFO`(결연교체). → 사용 38 + 미포함 3 = 41.

> **행사·발송 분리 / 사건 분리 근거**: GOLD가 행사(DIM_EVENT·FEP)와 발송(DIM_SERVICE·FSE)을 별도 테이블·그레인으로 두고, FME를 일 grain 상태전이로 두므로 — SILVER도 ① 행사(`CRM_EVENT`/`CRM_EVENT_PARTICIPATION`)와 발송(`CRM_SEND_*`)을 분리, ② 약정 사건(개발/증감/중단/재후원)을 상태이력과 분리한다(GOLD 그레인이 요구하는 최소 분리).

---

## 3. 작업 우선순위 (원천 입고 상태 기반)

### 트랙 A — 즉시 착수 (CRM 단독, ✅수령)
GOLD **15테이블 착수 가능**: DIM_DATE(생성)·DIM_MEMBER·DIM_MEMBER_IDENTITY(CRM측)·DIM_CAMPAIGN·DIM_SPONSORSHIP·DIM_ORG·DIM_SERVICE·DIM_PAYMENT·DIM_REASON·DIM_EVENT + FMM·FME·FTG-D·FSE(CRM분)·FEP(CRM분).
- 산출물: `S1_CRM_entity_design/` 에 **CRM 21개 엔티티 설계서**(grain·PK·컬럼·정제규칙·증분키).

### 트랙 B — GA4 (🟢 적재됨, 실측 검토 후)
DIM_GA_SOURCE·DIM_GA_EVENT·DIM_DEVICE(GA분)·FGA + DIM_MEMBER_IDENTITY(GA측·식별자 매핑).
- 선결: **user_id 채움률 4.22%**(실측) → 회원단위 GA 지표 부분 커버리지·DQ 고지(§5 Q1). GA4 dbt 매크로는 `10_dbt_pipeline`의 대소문자 안전 수정본 기준. 전체기간 샤드는 입고 대기(현재 1일 287,025행).

### 트랙 C — ERP (🟢 적재됨 2,041행, ⚠️실측 검토 후)
DIM_BUDGET_ITEM·FTG-B·FBD.
> **[실측 2026-07-13 · S-6 착수 전 검토]** `BRONZE_ERP.BDGT_ACMSLT_LEDGER`(1테이블·62컬럼·2,041행) = 예산·집행 원장(예산과목 장/관/항/목/세목/세세목 + 예산단위명 + 재원 + 월별 편성/추경/조정/집행).
> - `DIM_BUDGET_ITEM`(세세목·예산구분) → ✅ 매핑 가능.
> - `FBD`(편성/집행) → ◐ 편성·집행 O, **모금성비용·광고비는 원장에 없음**(AGENCY로 보강 검토).
> - `FACT_TARGET_BIZ`(사업목표) → ❌ **원장은 사업목표가 아님 → FTG-B 원천 여전히 부재**(현업 별도 원천 필요).
> - 캠페인/조직 연결키 없음(조직=이름, 코드X) → 캠페인별 예산 ROI 불가(결론7/O3·E-1·E-4).

### 트랙 D — AGENCY (🟢 3테이블 적재됨, ⚠️실측 검토 후) / GADS·ADMIN
DIM_AD_CREATIVE·FAD + (ADMIN 앱푸시·이벤트조회수는 ❌제외 확정).
> **[실측 2026-07-13 · S-6 착수 전 검토]** AGENCY는 단일 테이블이 아니라 **광고유형별 3테이블이 스키마 상이**: `DGT_AD_CMPGN_DTLS`(디지털 197,686)·`REBRDC_AD_CMPGN_DTLS`(재송출 2,064)·`VIDEO_AD_CMPGN_DTLS`(영상 35,822).
> - measure 불균일: 노출·클릭=DGT만 / 인입콜=REBRDC(TEXT)·VIDEO(NUMBER)+CONV_CALL_CNT / GA전환=DGT만(GA_CONV_MBER_CNT·CONV_VU_CNT) / 광고비=DGT `GA_AD_COST`·REBRDC `BRDC_SCHDL_COST`(편성)·VIDEO `ACTL_PUR_AD_COST_KRW`(집행)로 **컬럼·의미 상이**.
> - `_SOURCE_SYSTEM` 부재 → SILVER에서 테이블 기반 부여(결론5). 인입콜 REBRDC=TEXT→`TRY_TO_NUMBER`(결론4).
> - **DGT에 파생 사전계산**(CPA·CTR·CVR·CPC·CPM·VTR·DEV_UNIT_PRICE) → P2(derived는 SV) 충돌: 원천값 신뢰 vs 재계산 결정 필요.
> - 캠페인=이름(CMPGN_NM/MKT_CMPGN_NM, 코드X) → DIM_CAMPAIGN 이름 매칭 크로스워크 필요. DIM_AD_CREATIVE 필드(매체·소재·CM위치·초수)는 원천별 산재/부분.
> **→ 트랙 C/D는 위 대조·결정(정규화 전략·이름매칭·파생처리·FTG-B 원천·FBD 갭)을 확정한 뒤 SILVER 신설.**

> 컬럼은 24테이블 모두 선생성, 미수령/미결정 원천은 입고·검토 후 적재. SILVER도 미검토 소스 테이블은 **스키마만 정의** 후 확정 시 적재.

### ▶ 우리끼리 선행 확정 (2026-07-13, 현업 위임 — "웬만한 건 알아서")
> 원칙: 현업 크리티컬 의견 없이 진행하되 **실측 검증된 것만 '확정', 나머지는 '잠정 기본값 + 검증 게이트'**로 표기한다. 후속 SILVER 빌드가 **미검증 가정 위에 서지 않도록**, 게이트 미통과 객체는 스키마-only 또는 잠정규칙+DQ 테스트로 방어한다. 정의성 기본값은 `가정(현업 추후 추인)`.

**A. 확정 (실측 검증 완료 — 즉시 반영 가능)**

| 항목 | 근거(실측 2026-07-13) |
|---|---|
| Q5 발송키 | `SND_REQ_MST.SEQ_NO` **1,707/1,707 유일 = PK 확정**. `TM_MS_*.SNDNG_KEY`(발송실행)와 별개 계열 → `CRM_SEND_REQUEST` PK=SEQ_NO |
| 상태코드 라벨 | `TC_CMMN_DTL_CD`(CD_ID='MM010', **적재됨**) **(CD_ID,DTL_CD_ID) 복합조인** → DIM_MEMBER 상태라벨(Q4) |
| Q6 표현차 | 정기 수신동의 `*_RECPTN_CD`(코드) vs 일시 `*_RECPTN_YN`(Y/N) **실재 확인** → UNION 시 정규화 필요(규칙은 B) |
| O10 원천 위치 | `ACMSLT_DEPT_CD`=**거래테이블**(`TM_MM_FDRM_MBER_DVLP_AMT`·`IRSD`·`TM_PM_DNTN_DTLS`), 회원마스터=`ACT_DEPT_CD`·`REGIST_DEPT_CD`만. DIM_ORG 계층=`TM_CM_DEPT_INFO`(`UPPER_DEPT_ID` 5레벨=실적팀, DEC-5) |
| DIM_EVENT 소스 | `TM_MS_EVENT.EVENT_DIV_CD` **5값** + `EVENT_NM` 실재 |
| AGENCY 이질성 | 3테이블 스키마 상이·measure 불균일·`_SOURCE_SYSTEM` 부재·인입콜 TEXT/NUMBER **실측 확인** |

**B. 잠정 기본값 + ⚠️검증 게이트 (SILVER 빌드 전 게이트 통과 필수 — 미통과 시 해당 객체 스키마-only)**

| 항목 | 잠정 기본값(가정) | ⚠️ 검증 게이트(후속 에러 방지) |
|---|---|---|
| Q6 UNION 정규화 | 코드→표준세트 + `MEMBER_TYPE` 구분 + 공통 교집합·NULL 패딩 | `EMAIL_RECPTN_CD` **콤마 멀티값 distinct 세트 프로파일** 후 매핑표 확정. 정기/일시 **UNION 컬럼셋 정합**(공통/전용) 사전 대조 |
| DIM_SERVICE | `SEND_GBN_TOP/MID/BOT`+`_NM` 코드·라벨 3계층 passthrough | **소스 범위 미확정**: SEND_GBN은 '발송'만 — 참여/채널(CRM_UMS/ADMIN) 포함 전체 DIM_SERVICE 소스 집합 확정 필요. 라벨 중복(MS046·MS051=결연) **코드 정규화 규칙** |
| DIM_EVENT 파생 | `EVENT_DIV_CD`(5)→EVENT_CATEGORY, `EVENT_NM` passthrough | 5개 코드 **라벨 매핑 확인**. `APPLY_CHANNEL`=`FEP.PART_CHANNEL`은 **컬럼 존재 미검증(추정)** → 확인 |
| DIM_PAYMENT FEE_TYPE | `MEMBER_TYPE`로 구분·회비성격 별도 컬럼(이중표현 회피) | 결제/회비(`TM_PM_*`) **미프로파일** → 값 확인 후 확정 |
| O10 조직귀속 | 사건 FACT(FME)=행 `ACMSLT_DEPT_CD`; 기본 역할=실적(ACMSLT), 활동/등록 보존 | ⚠️ 실적부서는 **사건 행별** → **FMM(월 롤업) 대표조직 집계 규칙 별도 정의** 필요(단순 '기본=실적'로 롤업 불가) |
| O8 FSE·FEP 귀속 | 직접 FK(grain 단순) | ⚠️ **회원 다중 후원사업 실재(Q15)** → 직접 FK 시 fan-out/오귀속 위험. **카디널리티 검증** 후 직접FK vs MEMBER 스냅샷 확정 |
| AGENCY 정규화 | 유형별 정제→UNION, `_SOURCE_SYSTEM`=테이블 부여, 인입콜 `TRY_TO_NUMBER` | 캠페인 **이름 매칭 크로스워크는 오류 취약** → 커버리지 측정+미매칭 플래그 필수. REBRDC/VIDEO는 **노출·클릭 부재 → CTR/CVR 재계산 불가**(DGT만 GOLD/SV 재계산, 타 유형은 원천값 의존 명시) |

**⛔ 우리끼리 불가 (데이터 부재 → 스키마-only, 입고/원천 확인 대기)**
- `FACT_TARGET_BIZ`(사업목표) — ERP 예산원장에 사업목표 없음
- `FACT_BUDGET`의 **모금성비용** 원천 불명 (광고비는 AGENCY로 보강 가능)

> **빌드 순서 가드**: 트랙 A는 **A(확정) 항목만으로 착수 가능한 객체부터**(예 상태라벨·발송요청) 빌드하고, B(게이트) 객체는 게이트 통과 후 편입. 모든 SILVER 테이블에 **PK 유일성·UNION 컬럼정합·조인 fan-out DQ 테스트**를 붙여 미검증 가정으로 인한 무결성 오류를 차단한다.

---

## 4. 공통 정제 규칙

1. **타입 정본 = `09_bronze_crm_ddl.sql`**. 코드그룹·한글설명·소스 완전성 = 컬럼정의서 CSV. 충돌 시 물리타입은 DDL 우선, 컬럼집합 불일치(예 `EMAIL`/`CHN_PARM_CTNT`)는 입고팀 확인.
2. **코드 변환**: 코드여부 `Y` 컬럼은 `TC_CMMN_DTL_CD`(CD_ID + DTL_CD_ID) 조인으로 `_NM` 라벨 생성, **코드·라벨 병행보존**. 하드코딩 코드(예 `SNDNG_RST_CD` 0/1/4/5)는 SILVER에서 CASE 매핑.
3. **증분 적재**: `테이블정의_20260629.csv` 의 PK 후보·업데이트 컬럼·갱신패턴 반영. 각 테이블 적재방식(누적형 vs `LAST_UPDT_DT` 머지)은 테이블정의서로 확정.
4. **적재 메타**: SILVER 표준 메타 — `_SOURCE_SYSTEM`(CRM/GA4/ERP/AGENCY), `_SOURCE_TABLE`(다중원천 UNION/JOIN 시 행별 출처), `_LOADED_AT`(DEFAULT CURRENT_TIMESTAMP), `_BATCH_ID`(멱등 재적재). GOLD 공통 4컬럼(`DW_SOURCE_SYSTEM`·`DW_LOAD_TS`·`DW_UPDATE_TS`·`DW_BATCH_ID`)의 시작점.
5. **GA4(스키마 스펙 §2 기준)**: 중첩(`event_params`/`items`/`user_properties`)은 `LATERAL FLATTEN`, leaf는 `::` 캐스팅. 트래픽소스는 `session_traffic_source_last_click`(UI 일치). float은 `double_value` 사용.
6. **금액 단위**: `(건) = SUM(금액)/10000` 다수 → SILVER는 **원금액 보존**, /10000 변환은 GOLD measure 계산에서.
7. **정제 컨벤션**: NULL 표준화(빈문자·`'NULL'`·`'-'`·공백→NULL) · 날짜(`YYYYMMDD`/`YYYY-MM-DD`→DATE/TIMESTAMP, 무효값→NULL) · 숫자(콤마·통화기호 제거, 금액 원단위 보존) · 문자(TRIM·전각→반각·UTF-8) · 컬럼명 UPPER_SNAKE_CASE.
8. **SCD2 한계**: 회원 SCD2 가능 속성은 **상태(STATUS)만** — 이력 소스(`TH_MM_FDRM_MBER_STNG_DTLS` `BF_STAT_CD`/`CHN_STAT_CD`)가 상태만 보유. **성별·지역·신규기존은 마스터 현재값=SCD1**(과거 시점 복원 불가). SCD2 엔티티(`CRM_MEMBER_STATUS_HIST`)는 `EFFECTIVE_FROM/TO`·`IS_CURRENT` 부가. `DIM_ORG` SCD2도 동일 한계 검토.

---

## 5. 미해결·확인 필요 (GOLD open 항목과 연동)

> 상태: **✅ 해소** · **◐ 부분 해소**(원천/구조 확정, 잔여 명시) · (무표시) 미해소. BRONZE_CRM DDL·데이터사전(`BRONZE_CRM 테이블 정보.MD`)·`06_지표용어사전` 검토 반영(2026-06-29).

| # | 항목 | 담당/선결 | GOLD 연계 |
|---|---|---|---|
| Q1 | **GA↔CRM 식별자 매핑** — GA4 `user_id`에 CRM 회원번호 심김 여부. 미설정 시 `user_pseudo_id`+`transaction_id` 간접연계. ⚠️**[결론9] 실측 user_id 채움률 4.2%**(전수 12,120/287,025·식별 1,290명·익명 95.8%) → 형식은 일치(조인 성립)하나 **회원단위 GA 지표는 부분 커버리지**, 전수 단정 금지·SV 커버리지 경고 | GA4 입고팀 | DIM_MEMBER_IDENTITY·FGA |
| Q2 | 캠페인 코드 **컬럼↔코드그룹 확정**(`CMPGN_CTGR_CD`=MM294·`CMPGN_TYPE1_BSN`=MM295·`CMPGN_TYPE2_BSN`=MM296). 잔여 = **코드값↔라벨 정의서 미수령**(별도 수령 필요) | CRM 현업 | DIM_CAMPAIGN |
| Q3 ◐ | **#15(`CMPGN_TYPE1_BSN`/MM295)·#16(`CMPGN_TYPE2_BSN`/MM296) 원천 확정**. #17(`CMPGN_CTGR_CD`/MM294)만 후보·현업 최종확인 잔존 | CRM 현업 | DIM_CAMPAIGN |
| Q4 ✅ | **실측 완료 — MM010 확정+라벨**. `BF/CHN_STAT_CD` 12값 전부 MM010 소속: 1=활동회원·2~6=신규미납1~5·7~11=장기미납1~5·12=후원중단. ⚠️`DTL_CD_ID` 전역 비유일 → 라벨 조인은 **(CD_ID,DTL_CD_ID) 복합** 필수 | CRM 실측(완료) | DIM_MEMBER SCD2·FMM 시점지표(#49·50·52·53) |
| Q5 | 발송키 이원화(`SND_*.SEQ_NO` vs `TM_MS_*.SNDNG_KEY`) — 병렬/구신 시스템 | CRM 입고팀 | FSE |
| Q6 | 정기·일시 회원 UNION 스키마 정렬 규칙 | 설계 | DIM_MEMBER |
| Q7 ✅ | **원천 확정(해소)** — 조직 역할 3종 컬럼(`ACT_DEPT_CD`·`ACMSLT_DEPT_CD`·`REGIST_DEPT_CD`) DDL 존재 확인(= GOLD O10 원천 확정). 잔여 = FMM/FME 역할별 FK **설계 반영만**(차단 아님) | 설계(S-1) | FMM/FME (O10) |
| Q8 | EVENT_TYPE 코드체계·'활동전환' CRM 캡처 가능성 | CRM 현업 | FME (O6) |
| Q9 ◐ | 노출·클릭 **GA vs AGENCY 출처구분** 규칙. ⚠️**[결론5 실적재]** AGENCY 3테이블에 행단위 `_SOURCE_SYSTEM` 부재·`GA_`/`CRM_` 접두는 귀속시스템(출처 아님)·3테이블은 광고유형(출처 아님) → 명시 출처 플래그 SILVER 부여 필요 | 설계+AGENCY | FAD |
| Q10 | 세세목↔캠페인 매핑(부서 grain까지만?) | ERP 현업 | FBD·ROI(신#11) (O3) |
| Q11 | `EHGT`(VARCHAR30) 의미 미상 — DDL 주석도 '미상' | CRM 현업 | (저영향) |
| Q12 | 컬럼정의서 CSV ↔ DDL **컬럼집합 불일치/결번** 삭제·누락 검증 | CRM 입고팀 | 적재 완전성 |
| Q13 ✅ | **실측 완료 — 폭발 없음**. `DVLP_AMT` 자연키(SPNSR_NO+SPNSR_BSNS_NO+OCCRRNC_DE+SER_NO) **유일=PK 스파인** · `SPNSR_BSNS`는 (SPNSR_NO,SPNSR_BSNS_NO)당 1행(multi_key=0) → **N:1 LEFT JOIN 안전**(3,561,635→3,561,561, 미매칭 74행 LEFT 보존). 결연(858,912행)은 별도 엔티티 | 설계(S-1) | FMM·FME |
| Q14 ✅ | **실측 완료 — 납입 SUM 중복 확인**. `MBRFEE_KEY`=PK(45.4M=행수). 청구=전행·납입=86%. 동일 납입(PAY_DE+PAY_AMT)이 복수 적상행 중복 = pay_group **약 5.4%(199만)** → **납입 measure는 납입건 dedup 후 집계, 청구는 행 기준**. 회비차수 행증식 극소(2,823). 기부금(`DNTN_KEY`=PK, 1.13M)=납입만 확인 | 설계(S-1) | FMM·`CRM_PAYMENT_BILLING` |
| Q15 ✅ | **실측 완료 — "1:1 alt-key" 전제 정정**. `SPNSR_BSNS_ID`=후원사업(=DIM_SPONSORSHIP 키; 당시 **29개** → **06-30 마스터 실측 50, AC-2/O13 재확인**) · `SPNSR_BSNS_NO`=후원사업'번호'(**약 215만**≈약정/관계 단위). 관계 = **NO→ID 다대일**(`id_equals_no=0`, 문자열 변환 아님). 결연(NO만)→후원사업 귀속은 크로스워크(`DVLP_AMT`/`SPNSR_BSNS`/`MBRFEE_ACMSLT`)로 **커버리지·마스터무결 100%**. ⚠️잔여=NO **20건 ID 2개 모호(결연 크로스워크; 약정테이블 S9 실측=16건은 모집단 상이)** → 클렌징 규칙 + NO 의미 현업 1줄 확인 | CRM 실측(완료) | DIM_SPONSORSHIP 결연 조인 |
| Q16 | **캠페인↔마케팅캠페인 조인키 불일치** — `TM_CM_CMPGN_MNG.MKTG_CMPGN_NM`(NUMBER) vs 마스터 `TM_CM_MKTNG_CMPGN_MNG.MK_CMPGN_CD`(VARCHAR) 타입 상이(Q15와 유사 패턴 P2). 인벤토리 작성 중 발견 | CRM 실측 | DIM_CAMPAIGN(`CRM_CAMPAIGN` 마케팅캠페인명 조인) |

> **확정 사항(현행)**:
> - **memnum = member id = 회원번호**(문자, URL 파라미터 용어 예 `?memnum=…`). `DIM_MEMBER_IDENTITY`의 회원번호는 별도 키가 아니라 `CRM_MEMBER` 회원번호 컬럼으로 충족 → CRM측 신원 차단 없음(잔여는 Q1 GA측 매핑만). 근거: 컬럼정의서·`지표용어통합` 모두 `회원번호`로 정의.
> - **발송 키·후원사업 마스터·회원상태 컬럼**: 컬럼정의서 + DDL로 물리 확정. 잔여 값/관계 실측 = **Q5만**(Q4·Q13·Q14·Q15 실측 해소).
> - **후원사업 키 체계(Q15 실측 확정)**: `SPNSR_BSNS_ID`(VARCHAR; 당시 **29개** → **06-30 마스터 실측 50**, AC-2/O13 재확인) = 후원사업 = **DIM_SPONSORSHIP 키**(DIM은 전체 마스터 적재). `SPNSR_BSNS_NO`(NUMBER, **약 215만**) = 약정/관계 단위 번호(≈행 유일) — 후원사업 차원키 **아님**(degenerate/관계 식별자). 회원·납입 테이블(`DVLP_AMT`/`SPNSR_BSNS`/`MBRFEE_ACMSLT`)은 ID 직보유 → 후원사업 귀속 직접 가능. **결연(`TM_RM_RELATNSP_MSTR_INFO`)만 NO 단독** → `CRM_SPONSOR_RELATION` 정제 시 위 테이블에서 NO→ID 크로스워크로 `SPNSR_BSNS_ID` 부여(모호 NO는 우선순위/충돌표시 클렌징).

### 5-1. SILVER Q ↔ 현행 GOLD O 매핑

> SILVER Q는 본 SILVER 설계에서 도출된 **독자 번호**다. 아래는 현행 GOLD open 항목(`03_top-down_gold/03_설계.md` §5 의 O1~O11)과 사안이 겹치는 것만 연결한 것. (GOLD 설계과정의 옛 Q1~Q9는 무관·아카이브)

| SILVER Q | 현행 GOLD O | 관계 |
|---|---|---|
| Q7 ✅ | **O10** | 동일 — 조직 역할 3종(활동/실적/등록). 양쪽 원천 확정 |
| Q8 | **O6** | 동일 — FME EVENT_TYPE·'활동전환' |
| Q9 | **O5** | 인접 — 전환수 단위(명/건)·GA CVR 분모 |
| Q10 | **O3** | 동일 — FBD 세세목↔캠페인 grain |
| Q13·Q15 | **O8** | 인접 — FSE/FEP 캠페인·후원사업 귀속 grain |
| Q1·Q2·Q3·Q4·Q5·Q6·Q11·Q12·Q14·Q16 | — | GOLD O 없음. SILVER 내부 설계 / CRM 현업·실측 / 입고요청(컨트랙트 G-1 등) |

**SILVER Q 없는 GOLD O (GOLD·SV에서 처리, SILVER 무관)**: O1(GA 율·평균 비가산) · O2(DEVICE APP 정의) · O4(FEP 참여 정의 메타) · O7(overview↔215 매핑) · O11('이벤트관리' 물리화 보류).

---

## 6. 정합성 기준 (완료 정의)

- **커버리지**: GOLD 24테이블 각 컬럼이 SILVER 객체로 역추적되거나 (생성/derived/미수령)으로 명시 분류.
- **물리화 대상 = measure 60 + dimension 74 = 134컬럼**. derived 81은 SILVER/GOLD 적재 제외(SV).
- **타입**: SILVER 컬럼타입 = DDL 정본과 일치 또는 의미타입으로 의도적 캐스팅(매핑표 기록).
- **키 무결성**: `MEMBER_DK` 불변, conform 차원 키(MONTH_KEY·DATE_SK·ORG·CAMPAIGN) 소스 간 일치.
- **단방향**: SILVER가 BRONZE만 참조, GOLD가 SILVER만 참조(직참조 0건).

---

## 7. 작업 단계 (S-1 ~ S-7)

| 단계 | 산출물 | 대상 | 설명 |
|---|---|---|---|
| **S-1** | 엔티티 설계서 | CRM 21 | grain·PK·컬럼선별·타입·정제규칙·증분키. §1-1/§2-3 객체 체계. Q4·Q5·Q6·Q13·Q14·Q15 선결 |
| **S-2** | DDL 초안 | CRM 21 | `CREATE TABLE` (Snowflake 컴파일 검증) |
| **S-3** | 정제 매핑표 | CRM 21 | BRONZE 컬럼 → SILVER 컬럼 1:1 (ETL 명세) |
| **S-4** | 정제 프로시저 | `SP_REFINE_CRM_*` | `CREATE OR REPLACE TABLE` 멱등 |
| **S-5** | GOLD 역산 검증 | — | §2-1/§2-2 매트릭스 대비 누락·불일치 점검 |
| **S-6** | GA4/ERP/AGENCY 설계 | 입고 후 | 트랙 B/C/D — S-1~S-5 반복 |
| **S-7** | 신원 브리지 | `IDENTITY_MEMBER_XREF` → `DIM_MEMBER_IDENTITY` | GA↔CRM 1:N 신원해소 + `MATCH_METHOD`/`MATCH_CONFIDENCE`. 입력: CRM 회원번호(=memnum) + GA `user_id`·결연아동코드. cross-source라 S-6과 분리, GA4 입고 후 |

**즉시 실행 순서**
1. (트랙 A·S-1) `S1_CRM_entity_design/` 에 CRM 21개 엔티티 설계서 작성.
2. CRM 내부 선결 **Q4·Q5·Q6·Q13·Q14·Q15** 확정 후 S-2 진행.
3. SILVER→GOLD 적재 프로시저(`SP_LOAD_GOLD_*`)는 **별도 트랙**(본 문서는 정제·연결 설계 범위).
4. GA4/ERP/AGENCY 입고 시 트랙 B/C/D(S-6) 순차 활성화, 이어 신원 브리지(S-7).
