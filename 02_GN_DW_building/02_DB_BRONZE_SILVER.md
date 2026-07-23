---
project_id: GN_DW
doc_type: work_plan_chapter
chapter: "02_DB_BRONZE_SILVER"
sections: [3.1, 3.2, 3.3, 3.4, 4]
index: "00_INDEX.md"
depends_on: ["01_환경_Role.md"]   # roles/warehouses 필요
provides: [database, schemas, bronze_tables, silver_tables, dbt_pipeline]
language: ko (설명) / en (구조 키)
---

# 02. DB / BRONZE / SILVER / dbt 파이프라인 (objects + pipeline)

> 인덱스: `00_INDEX.md` · 핵심 원칙(P1~P7)은 인덱스 참조.
> 본 챕터는 구축 step 3~5를 다룬다. **BRONZE→SILVER→GOLD 적재는 dbt 파이프라인(`GN_DW.OPS.DW_PIPELINE`)이 담당한다(라이브 2026-07-22). 구설계의 정제 프로시저 18종은 dbt 모델로 전량 대체됨(폐기).**

---

## 3.1 Database (database)

```yaml
database:
  id: GN_DW
  owner_role: GN_DW_ADMIN   # SYSADMIN에서 생성 후 이관
  data_retention_days: 1    # 기본, 운영 후 조정
```

## 3.2 Schemas (schemas)

```yaml
schemas:
  # ── BRONZE: 원천별 스키마로 물리 분리 (단일 BRONZE 아님) ──
  - id: BRONZE_CRM
    purpose: 원천 적재 — CRM (회원/납입/캠페인)
    owner: GN_DW_ADMIN
    access: MANAGED ACCESS
    note: "LOADER role 쓰기. 43테이블 실측"
  - id: BRONZE_AGENCY
    purpose: 원천 적재 — 대행사 (디지털/DRTV/재송출 광고)
    owner: GN_DW_ADMIN
    access: MANAGED ACCESS
    note: "3테이블 실측"
  - id: BRONZE_ERP
    purpose: 원천 적재 — ERP (예산 실적 원장)
    owner: GN_DW_ADMIN
    access: MANAGED ACCESS
    note: "1테이블 실측"
  - id: BRONZE_GA4
    purpose: 원천 적재 — GA4 (웹/앱 방문)
    owner: GN_DW_ADMIN
    access: MANAGED ACCESS
    note: "1테이블(1일 샤드) 실측"
  - id: SILVER
    purpose: 정제/통합 레이어
    owner: GN_DW_ADMIN
    note: "물리 테이블 32 (dbt 모델 갱신). 소스 접두 CRM_*/GA4_*/ERP_*/AGENCY_* + bridge"
  - id: GOLD
    purpose: 분석 계층 — star schema 물리 테이블(15 DIM + 9 FACT) + 평탄화 WIDE VIEW 9
    owner: GN_DW_ADMIN
    note: "데이터 프로덕트 계층. Analyst/Viewer 읽기 전용. 레거시 PoC View는 없음(WIDE 9로 대체)"
  - id: SERVING
    purpose: Semantic View + Cortex Agent (+ 보조 뷰)
    owner: GN_DW_ADMIN
    note: "소비/서비스 계층. GOLD를 cross-schema 참조. SV 5 + Agent 2 + 보조뷰 2 (P7). Streamlit 미배포"
  - id: OPS
    purpose: ETL 운영 인프라 — dbt 프로젝트 객체
    owner: GN_DW_ADMIN
    note: "DBT PROJECT DW_PIPELINE 배치. (구설계의 ETL_LOG/Task/Alert는 dbt 전환으로 미사용)"
  - id: SECURITY
    purpose: 마스킹 정책 · 네트워크 룰/정책 객체
    owner: GN_DW_ADMIN
    note: "거버넌스 정책 격리 (MANAGED ACCESS)"
schema_contents:
  BRONZE_CRM: { tables: 43, note: "CRM 원천 1:1 (원천정의 41 + 템플릿 2)" }
  BRONZE_AGENCY: { tables: 3, note: "DGT/REBRDC/VIDEO 광고 성과 내역" }
  BRONZE_ERP: { tables: 1, note: "BDGT_ACMSLT_LEDGER 예산 실적 원장" }
  BRONZE_GA4: { tables: 1, note: "events_20260501 (1일 샤드, 소문자명)" }
  SILVER: { tables: 32, pipeline: "dbt DW_PIPELINE", note: "CRM 22 + GA4 5 + ERP 2 + AGENCY 2 + bridge 1" }
  GOLD: { star_schema: 24, wide_views: 9, forecast_tables: 0, note: "star 24(15 DIM+9 FACT) + WIDE VIEW 9. forecast 제외(2026-07-10)" }
  SERVING: { semantic_views: 5, agents: 2, helper_views: 2, streamlit_apps: 0 }
  OPS: { dbt_projects: 1, note: "DW_PIPELINE (BRONZE→SILVER 32 + SILVER→GOLD 24 + WIDE 9 = 65 models)" }
  SECURITY: { policies: "masking + network", note: "거버넌스 정책 격리" }
naming_note: "PoC ANALYTICS 스키마(=현 GOLD)와 혼동 방지 위해 소비 계층은 SERVING으로 명명"
bronze_total: 48   # CRM 43 + AGENCY 3 + ERP 1 + GA4 1
live_state_20260722: |
  [라이브 실측 2026-07-22] 전 계층 배포·적재 완료:
  - BRONZE 4스키마 48테이블 적재(CRM 43 전량 수백만 행, AGENCY 3·ERP 1·GA4 1 부분 입고).
  - SILVER 32테이블·GOLD 24테이블+WIDE 9뷰·SERVING SV5/Agent2 모두 생성됨(구설계 "GOLD·SILVER 미생성" 상충 → 정정).
  - ETL = dbt `GN_DW.OPS.DW_PIPELINE` (65 models). 사용자 프로시저·Task·ETL_LOG 없음(SHOW PROCEDURES/TASKS 실측 0).
  - FACT_TARGET_BIZ / SILVER.CRM_BIZ_TARGET = 0행(E-6 CRM 사업목표 입고 대기).
```

---

## 3.2.1 CRM 원천 테이블 인벤토리 (crm_source_inventory)

> 입고팀 회신 CRM 원천 테이블/컬럼 정의서 기반. BRONZE 적재의 **source of truth**.
> ★ **기준 = 현재 측정 데이터(실측): `GN_DW.BRONZE_CRM` = 43테이블 / 927컬럼, 전량 적재.**
> 참고(원천정의서 `BRONZE_CRM 테이블 정보.MD` = 41테이블/876컬럼)는 초기 정의이며, 이후 템플릿 2테이블(`TD_MS_AT_TMPLAT_BTN_LIST`·`TM_MS_EMAIL_TMPLAT_MNG`) 추가 + per-table 컬럼수 실측 상이 → **아래 인벤토리·수치는 실측을 기준으로 읽을 것**.
> **설계 원칙:** CRM 원천 테이블을 BRONZE_CRM에 1:1 전량 적재한다. 통합·정제(consolidation)는 SILVER 단계에서 수행.

```yaml
crm_source_summary:
  total_tables: 43        # ★실측 (GN_DW.BRONZE_CRM). 원천정의서=41(참고)
  total_columns: 927      # ★실측. 원천정의서=876(참고, per-table 상이)
  added_beyond_def: [TD_MS_AT_TMPLAT_BTN_LIST, TM_MS_EMAIL_TMPLAT_MNG]  # 정의서에 없던 템플릿 2테이블
  common_code_master: { group: TC_CMMN_CD, detail: TC_CMMN_DTL_CD }
  code_lookup: "코드여부=Y인 컬럼은 TC_CMMN_DTL_CD.CD_ID에서 코드값 조회"

crm_source_tables:
  # ── 발송(SND) 계열 ──
  - { id: SND_MEMBER_LIST, cols: 96, prefix: SND_, desc: "발송 대상 회원 목록 (후원정보/아동정보/발송상태 통합)" }
  - { id: SND_REQ_MST, cols: 56, prefix: SND_, desc: "발송 요청 마스터 (알림톡/이메일/SMS 발송 관리)" }

  # ── 공통코드(TC) 계열 ──
  - { id: TC_CMMN_CD, cols: 10, prefix: TC_, desc: "공통코드 그룹 마스터 (CD_ID, CD_NM)" }
  - { id: TC_CMMN_DTL_CD, cols: 15, prefix: TC_, desc: "공통코드 상세 (CD_ID+DTL_CD_ID → 코드값)" }

  # ── 마케팅 상세(TD_MS) 계열: 발송 이력/참여 트랜잭션 ──
  - { id: TD_MS_CRMN_PRTCPNT, cols: 19, prefix: TD_MS_, desc: "행사(세레모니) 참여자 상세" }
  - { id: TD_MS_EMAIL_LQY_SNDNG, cols: 24, prefix: TD_MS_, desc: "이메일 대량 발송 집계 (성공/실패/수신건수)" }
  - { id: TD_MS_EMAIL_SNDNG_DTLS, cols: 12, prefix: TD_MS_, desc: "이메일 발송 상세 (회원별 발송결과)" }
  - { id: TD_MS_EVENT_PRTCPNT_DTL, cols: 15, prefix: TD_MS_, desc: "이벤트 참여 상세 (참여채널/경로/당첨)" }
  - { id: TD_MS_MSG_AT_LQY_SNDNG, cols: 18, prefix: TD_MS_, desc: "알림톡 대량 발송 집계 (성공/대체발송/클릭)" }
  - { id: TD_MS_MSG_AT_SNDNG_DTLS, cols: 17, prefix: TD_MS_, desc: "알림톡 발송 상세 (회원별 전송상태)" }
  - { id: TD_MS_PSTMTR_LQY_SNDNG, cols: 9, prefix: TD_MS_, desc: "우편물 대량 발송 집계" }
  - { id: TD_MS_PSTMTR_SNDNG_DTL, cols: 15, prefix: TD_MS_, desc: "우편물 발송 상세 (주소/결연KEY)" }

  # ── 이력(TH) 계열 ──
  - { id: TH_MM_FDRM_MBER_STNG_DTLS, cols: 6, prefix: TH_, desc: "정기회원 세팅 이력" }
  - { id: TH_PM_SETLE_INFO_HIST, cols: 53, prefix: TH_, desc: "결제정보 변경 이력" }

  # ── 공통 마스터(TM_CM) 계열: 코드/조직/캠페인 ──
  - { id: TM_CM_BRND_MNG, cols: 9, prefix: TM_CM_, desc: "브랜드 관리 마스터" }
  - { id: TM_CM_CMPGN_MNG, cols: 32, prefix: TM_CM_, desc: "캠페인 관리 마스터 (후원구분/법인구분/홍보방법/국내해외·사업사례·카테고리·인입경로·마케팅캠페인 2026-06 +5)" }
  - { id: TM_CM_MKTNG_CMPGN_MNG, cols: 8, prefix: TM_CM_, desc: "마케팅캠페인명 마스터 (2026-06 신규, MK_CMPGN_CD↔MK_CMPGN_NM)" }
  - { id: TM_CM_DEPT_INFO, cols: 12, prefix: TM_CM_, desc: "부서 정보 (계층구조, 실적부서)" }
  - { id: TM_CM_MBER_DVLP_GOAL, cols: 9, prefix: TM_CM_, desc: "회원 개발 목표 (연월/부서별)" }
  - { id: TM_CM_SPNSR_BSNS_INFO, cols: 13, prefix: TM_CM_, desc: "후원사업 정보" }

  # ── 회원 관리(TM_MM) 계열: 정기/일시 회원 ──
  - { id: TM_MM_FDRM_MBER_DVLP_AMT, cols: 20, prefix: TM_MM_, desc: "정기회원 개발 실적 (후원번호/금액/구분)" }
  - { id: TM_MM_FDRM_MBER_INFO, cols: 41, prefix: TM_MM_, desc: "정기회원 마스터 (연락처/주소/상태/캠페인)" }
  - { id: TM_MM_FDRM_MBER_IRSD, cols: 15, prefix: TM_MM_, desc: "정기회원 증감액 이력" }
  - { id: TM_MM_FDRM_MBER_RE_SPNSR, cols: 5, prefix: TM_MM_, desc: "정기회원 재후원 이력 (ROW 누적)" }
  - { id: TM_MM_FDRM_MBER_SPNSR_BSNS, cols: 7, prefix: TM_MM_, desc: "정기회원 후원사업 매핑 (ROW 누적)" }
  - { id: TM_MM_FDRM_MBER_SPNSR_DSCNTC, cols: 7, prefix: TM_MM_, desc: "정기회원 후원중단 이력 (사유/경로)" }
  - { id: TM_MM_ONCE_MBER_INFO, cols: 32, prefix: TM_MM_, desc: "일시후원 회원 마스터 (연락처/주소/수신동의)" }

  # ── 마케팅 마스터(TM_MS) 계열: 발송/이벤트/세레모니 ──
  - { id: TM_MS_CRMN, cols: 31, prefix: TM_MS_, desc: "세레모니 마스터 (행사정보/모집/설문)" }
  - { id: TM_MS_EMAIL_SNDNG, cols: 15, prefix: TM_MS_, desc: "이메일 발송 마스터 (유형/기준일/처리상태)" }
  - { id: TM_MS_EVENT, cols: 11, prefix: TM_MS_, desc: "이벤트 마스터 (기간/당첨인원)" }
  - { id: TM_MS_MSG_AT_SNDNG, cols: 21, prefix: TM_MS_, desc: "알림톡 발송 마스터 (유형/시간구분/대체발송)" }
  - { id: TM_MS_PSTMTR_SNDNG, cols: 14, prefix: TM_MS_, desc: "우편물 발송 마스터 (유형/처리상태/대량여부)" }

  # ── 납입/결제(TM_PM) 계열 ──
  - { id: TM_PM_DNTN_DTLS, cols: 25, prefix: TM_PM_, desc: "일시후원 기부금 상세 (캠페인/결제/환급)" }
  - { id: TM_PM_MBRFEE_ACMSLT, cols: 51, prefix: TM_PM_, desc: "회비 청구/납입 실적 (정기후원 핵심 트랜잭션)" }
  - { id: TM_PM_SETLE_INFO, cols: 48, prefix: TM_PM_, desc: "결제수단 정보 (은행/카드/빌키/인증)" }

  # ── 결연 관리(TM_RM) 계열: 아동/사업장/서신/선물금 ──
  - { id: TM_RM_BPLC_MNG, cols: 18, prefix: TM_RM_, desc: "사업장 관리 (국가/결연사업/선물금/서신 가능여부)" }
  - { id: TM_RM_CHILD_MSTR_INFO, cols: 16, prefix: TM_RM_, desc: "아동 마스터 (사업장/성별/결연상태/아동상태)" }
  - { id: TM_RM_RELATNSP_CHG_INFO, cols: 7, prefix: TM_RM_, desc: "결연 교체 정보 (교체사유/결과)" }
  - { id: TM_RM_RELATNSP_GFTMNEY_INFO, cols: 19, prefix: TM_RM_, desc: "결연 선물금 정보 (결제/금액/발송)" }
  - { id: TM_RM_RELATNSP_LETTER_INFO, cols: 14, prefix: TM_RM_, desc: "결연 서신 정보 (수신/발송/온라인)" }
  - { id: TM_RM_RELATNSP_MSTR_INFO, cols: 11, prefix: TM_RM_, desc: "결연 마스터 (후원번호↔아동코드 매핑, 결연시작/중단)" }

crm_to_bronze_note: |
  CRM 원천 → GN_DW.BRONZE_CRM 43개 테이블로 1:1 전량 적재 (원천 구조 보존).
  통합·정제(consolidation)는 SILVER 단계에서 수행한다 (3.4절 silver 인벤토리 참조).
  ※ 상세 컬럼 매핑은 99_provided_definition/BRONZE_CRM 테이블 정보.MD 참조

crm_key_references:
  common_code: "TC_CMMN_CD(그룹) + TC_CMMN_DTL_CD(상세). 코드여부=Y 컬럼은 코드그룹ID로 조인"
  campaign: "TM_CM_CMPGN_MNG.CMPGN_CD — 후원사업/브랜드/캠페인 계층 구조"
  member_regular: "TM_MM_FDRM_MBER_INFO.MBER_NO — 정기후원 회원 PK"
  member_once: "TM_MM_ONCE_MBER_INFO.ONCE_MBER_NO — 일시후원 회원 PK"
  relationship: "TM_RM_RELATNSP_MSTR_INFO.RELATNSP_KEY — 결연(후원자↔아동) PK"
  child: "TM_RM_CHILD_MSTR_INFO.CHILD_CD — 아동 PK"
  payment: "TM_PM_MBRFEE_ACMSLT.MBRFEE_KEY — 회비 납입 PK"
  department: "TM_CM_DEPT_INFO.DEPT_ID — 부서 코드 (계층, 실적부서)"
```

---

## 3.3 BRONZE 테이블 (bronze_tables)

> BRONZE는 **원천별 스키마로 물리 분리**되어 있으며(단일 BRONZE 아님), 원천 구조를 그대로 1:1 보존한다.
> **총 48테이블** = CRM 43 + AGENCY 3 + ERP 1 + GA4 1 (라이브 실측 2026-07-22).
> CRM 43개 세부 목록·컬럼수는 3.2.1 인벤토리 참조. 통합·정제는 SILVER에서 dbt 모델로 수행.

```yaml
bronze_schemas:
  BRONZE_CRM:   # 43테이블 (3.2.1 인벤토리 전량 = source of truth)
    tables: 43
    note: "회원/납입/캠페인/발송/결연 등 CRM 전 도메인. 수백만 행 전량 적재(예 TM_PM_MBRFEE_ACMSLT 46.4M · SND_MEMBER_LIST 8.3M)."

  BRONZE_AGENCY:   # 3테이블 (대행사 광고 성과)
    - { id: DGT_AD_CMPGN_DTLS, rows: 197686, desc: "디지털 광고 성과 내역" }
    - { id: VIDEO_AD_CMPGN_DTLS, rows: 35822, desc: "영상(DRTV) 광고 성과 내역" }
    - { id: REBRDC_AD_CMPGN_DTLS, rows: 2064, desc: "재송출 광고 성과 내역" }

  BRONZE_ERP:   # 1테이블 (예산 원장)
    - { id: BDGT_ACMSLT_LEDGER, rows: 2041, desc: "예산 실적 원장 (예산과목·예산단위·재원 + 월별금액). ⚠️[결론7] 캠페인·매체 연결키 없음" }

  BRONZE_GA4:   # 1테이블 (1일 샤드)
    - { id: events_20260501, rows: 287025, desc: "GA4 이벤트 (2026-05-01 전체 1일 샤드, 소문자 테이블명). user_id 채움 4.22%. ⚠️[G-5] 전기간 샤드 입고 대기" }

bronze_total: 48   # CRM 43 + AGENCY 3 + ERP 1 + GA4 1

ingest_status:
  CRM: "✅ 전수 수령 (43테이블)"
  AGENCY: "◐ 부분 (3테이블 스캐폴드)"
  ERP: "◐ 부분 (예산원장 1 · 모금성비용 원천 부재 E-1)"
  GA4: "◐ 부분 (1일 샤드만 · 전기간 대기 G-5)"
  note: "잔여 입고분(GA4 전기간·ERP 모금성비용·CRM 사업목표 등)은 입고 후 SILVER/GOLD/SV로 자동 확장(의도된 대기)."
```

```yaml
bronze_load_policy:
  loader: "외부팀(GN_DW_LOADER) — BRONZE 적재는 본 문서 책임 범위 밖"
  method: "원천 → BRONZE_<SOURCE> 1:1 적재 (원천 구조 보존)"
  idempotency: "재적재 시 중복 방지(MERGE 또는 재생성). 감사컬럼 표준(_LOAD_DT 등)"
  boundary: "본 문서 책임은 SILVER 정제(dbt)부터. BRONZE 신선도 점검은 06_RUNBOOK.md 참조"
```

---

## 3.4 SILVER 정제 레이어 (silver_tables)

> SILVER는 BRONZE 48테이블을 **정제·통합**하여 GOLD가 소비할 **32개** 테이블로 재구성한다(dbt 모델).
> 역할: (1) 타입 캐스팅·NULL 처리·코드→라벨 (2) 정기∪일시 등 UNION/JOIN 통합 (3) 행 granularity 유지(집계는 GOLD).
> 명명: 소스 접두 `CRM_*` / `GA4_*` / `ERP_*` / `AGENCY_*` + 교차소스 브리지 1(`IDENTITY_MEMBER_XREF`).

```yaml
silver_total: 32   # CRM 22 + GA4 5 + ERP 2 + AGENCY 2 + bridge 1

silver_tables:
  crm:   # 22
    - { id: CRM_CAMPAIGN, desc: "캠페인 마스터 (코드 라벨·조인키)" }
    - { id: CRM_CODE, desc: "코드→라벨 사전 (CD_ID,DTL_CD_ID 복합키)" }
    - { id: CRM_ORG, desc: "조직 마스터 (실적팀=재귀 LVL5)" }
    - { id: CRM_SPONSORSHIP, desc: "후원사업 마스터 (실측 50)" }
    - { id: CRM_MEMBER, desc: "회원 통합(정기∪일시). Q6 UNION" }
    - { id: CRM_MEMBER_STATUS_HIST, desc: "회원 상태전이 이력 (SCD2 range)" }
    - { id: CRM_MEMBER_DEV, desc: "개발약정 (Q13 스파인)" }
    - { id: CRM_MEMBER_AMT_CHANGE, desc: "약정 증감(증액/감액)" }
    - { id: CRM_MEMBER_DISCONTINUE, desc: "후원중단" }
    - { id: CRM_MEMBER_RESPONSOR, desc: "재후원" }
    - { id: CRM_MEMBER_SPONSOR_BIZ, desc: "회원×후원사업 약정" }
    - { id: CRM_PAYMENT_BILLING, desc: "납입/청구(회비∪기부금). Q14 dedup" }
    - { id: CRM_PAYMENT_METHOD, desc: "결제수단(현재상태)" }
    - { id: CRM_DEV_TARGET, desc: "회원개발 목표 (월×조직×개발구분) → FTG-D" }
    - { id: CRM_BIZ_TARGET, desc: "사업목표 → FTG-B. ⛔E-6 CRM 입고 대기, 0행 스켈레톤" }
    - { id: CRM_EVENT, desc: "행사 마스터(이벤트∪캠페인행사)" }
    - { id: CRM_EVENT_PARTICIPATION, desc: "행사×참여자" }
    - { id: CRM_SEND_REQUEST, desc: "발송요청 마스터 (Q5 발송키 이원화)" }
    - { id: CRM_SEND_MEMBER, desc: "발송×회원 상세" }
    - { id: CRM_SEND_RESULT, desc: "발송×채널 집계" }
    - { id: CRM_RELATION_ACTIVITY, desc: "결연활동(서신∪선물금)" }
    - { id: CRM_SPONSOR_RELATION, desc: "결연(아동). Q15 크로스워크" }
  ga4:   # 5
    - { id: GA4_EVENT, desc: "GA 이벤트 팩트 소스 → FGA. 원천 PK 중복 dedup(GA-1)" }
    - { id: GA4_EVENT_DIM, desc: "GA 이벤트분류 → DIM_GA_EVENT" }
    - { id: GA4_TRAFFIC_SOURCE, desc: "GA 트래픽소스(session/last-click) → DIM_GA_SOURCE" }
    - { id: GA4_DEVICE, desc: "GA 디바이스 → DIM_DEVICE(GA분)" }
    - { id: GA4_IDENTITY, desc: "GA 신원(Q1) → 브리지 입력. 접두사 분기 S%→ONCE_MBER_NO" }
  erp:   # 2
    - { id: ERP_BUDGET, desc: "예산 편성/추경/조정/집행 월 grain(wide→long) → FBD" }
    - { id: ERP_BUDGET_ITEM, desc: "예산과목 마스터(장/관/항/목/세목/세세목×재원) → DIM_BUDGET_ITEM" }
  agency:   # 2
    - { id: AGENCY_AD_CREATIVE, desc: "광고 소재/매체 차원(3소스 UNION distinct) → DIM_AD_CREATIVE" }
    - { id: AGENCY_AD_PERFORMANCE, desc: "광고성과 3소스 UNION(원천 1행 grain) → FAD" }
  bridge:   # 1 (교차소스 유일 예외)
    - { id: IDENTITY_MEMBER_XREF, desc: "S-7 신원 브리지: GA4_IDENTITY ↔ CRM_MEMBER 자연키 해소 + MATCH_METHOD/CONFIDENCE. 미매칭 보존" }

silver_notes:
  - "[결론4] 인입콜 타입 불일치(재송출 TEXT vs 영상 NUMBER) → TRY_TO_NUMBER 캐스팅 후 AGENCY_AD_PERFORMANCE UNION."
  - "[결론5/A-2] AGENCY 3소스 행 단위 출처 플래그 부재 → _SOURCE_SYSTEM='AGENCY' 상수 + 매체구분 속성 부여."
  - "[S-5] CRM_MEMBER_DEV/AMT_CHANGE의 AREA_CD(CM018)·AGE = DIM_MEMBER REGION/AGE_BAND 스냅샷 소스."
  - "[S-7] IDENTITY_MEMBER_XREF만 교차소스 조인 허용(SK 없음, GOLD 소관). CHILD_CODE 제외(fan-out)."
  - "센티넬: 미매칭·범위밖·NULL 차원키는 GOLD Unknown 멤버 SK=0으로 라우팅(구설계 -1 UNKNOWN 표기 폐기)."
```

---

## 4. dbt 파이프라인 (dbt_pipeline)

> **실행 주체:** dbt 프로젝트 `GN_DW.OPS.DW_PIPELINE` (라이브 배포). 구설계의 정제 프로시저(`SP_REFINE_*` 18)·오케스트레이션(`SP_RUN_ALL_REFINEMENT`)·`SP_LOAD_GOLD`·`ETL_LOG`·Task DAG는 **전량 폐기**되고 dbt 모델로 대체됨.
> **정본 위치:** `10_dbt_pipeline/` (모델·schema.yml·배포 스크립트). 저작 정본 SQL = `04_silver_design/09_SILVER_적재쿼리_*` + `03_top-down_gold/06_DDL.sql`.

```yaml
dbt_project:
  name: DW_PIPELINE
  fqn: GN_DW.OPS.DW_PIPELINE
  dbt_version: 1.9.4
  source_location: "snow://workspace/USER$.PUBLIC.\"snowflake_files\"/versions/live/10_dbt_pipeline/"
  models_total: 65   # SILVER 32 + GOLD 24(dim15+fact9) + WIDE 9
  layers:
    silver: { models: 32, materialization: table, source: "BRONZE_<SOURCE>", note: "CRM 22 + GA4 5 + ERP 2 + AGENCY 2 + bridge 1" }
    gold_star: { models: 24, materialization: table, source: SILVER, note: "15 DIM + 9 FACT (센티넬 SK=0 시드 포함)" }
    gold_wide: { models: 9, materialization: view, source: "GOLD FACT/DIM", note: "평탄화 WIDE VIEW (BLOCKING-4 해소)" }

pipeline_flow: "BRONZE_<SOURCE> → (dbt) SILVER 32 → (dbt) GOLD star 24 → (dbt) WIDE VIEW 9"

quality_tests:
  framework: "dbt schema tests (not_null/unique/relationships)"
  policy: "참조무결성 relationships는 severity:warn(메달리온 BP) · 핵심 PK/not_null은 error"
  note: "구설계 SP_VALIDATE_BRONZE_DATA·ETL_LOG는 dbt test·run 로그로 대체"

dbt_principles:
  - "멱등성: dbt run이 CREATE OR REPLACE(table) / view 재생성 → 재실행 안전"
  - "SILVER = BRONZE 정제·통합(행 grain 유지) / GOLD = 집계·star schema"
  - "센티넬 규약: 13개 GOLD DIM 전량 SK=0 Unknown 시드 + gold_helpers COALESCE(...,0)"
  - "스캐폴드 팩트(FACT_TARGET_BIZ)는 원천 미입고 시 0행 통과(스켈레톤)"

deploy_ref: "배포·운영 총괄 = 10_dbt_pipeline/00_배포운영_통합_*.md · deploy_dbt_project.sql"
```

---

> **이전 단계:** `01_환경_Role.md` · **다음 단계:** `03_GOLD_SERVING.md` (GOLD star schema → WIDE VIEW → Semantic View → Agent → 권한)
