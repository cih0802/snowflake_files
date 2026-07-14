---
project_id: GN_DW
doc_type: work_plan_chapter
chapter: "02_DB_BRONZE_SILVER"
sections: [3.1, 3.2, 3.3, 3.4, 4]
index: "00_INDEX.md"
depends_on: ["01_환경_Role.md"]   # roles/warehouses 필요
provides: [database, schemas, bronze_tables, silver_tables, procedures]
language: ko (설명) / en (구조 키)
---

# 02. DB / BRONZE / SILVER / 프로시저 (objects + procedures)

> 인덱스: `00_INDEX.md` · 핵심 원칙(P1~P7)은 인덱스 참조.
> 본 챕터는 구축 step 3~5를 다룬다. **정제 프로시저(4장)가 SILVER를 산출하므로 GOLD View(03_GOLD_SERVING.md)보다 먼저 실행한다.**

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
  - id: BRONZE
    purpose: 원천 데이터 적재 (외부팀)
    owner: GN_DW_ADMIN
    note: "LOADER role 쓰기 권한"
  - id: SILVER
    purpose: 정제/변환 레이어
    owner: GN_DW_ADMIN
    note: "물리 테이블 (프로시저 갱신)"
  - id: GOLD
    purpose: 분석 계층 — star schema 물리 테이블(15 DIM + 9 FACT) + 레거시 호환 View 35
    owner: GN_DW_ADMIN
    note: "데이터 프로덕트 계층. Analyst/Viewer 읽기 전용(owner's rights)"
  - id: SERVING
    purpose: Semantic View + Agent + Streamlit
    owner: GN_DW_ADMIN
    note: "소비/서비스 계층. GOLD View를 cross-schema 참조. Viewer 소비 지점 (P7)"
  - id: OPS
    purpose: 비용 리포트 View (+향후 모니터링 객체)
    owner: GN_DW_ADMIN
    note: "운영 메타데이터. ETL_LOG·Alert는 SILVER 유지, Resource Monitor는 계정 레벨"
  - id: SECURITY
    purpose: 마스킹 정책 · 네트워크 룰/정책 객체
    owner: GN_DW_ADMIN
    note: "거버넌스 정책 격리"
schema_contents:
  BRONZE: { tables: 56, note: "CRM 41 + 외부 15, 원천 1:1. 물리 구현은 BRONZE_CRM/GA4/ERP/AGENCY 분리" }
  SILVER: { tables: 23, procedures: 22, etl_log: 1, tasks: 4, alerts: 3, note: "통합·정제 + 운영 파이프라인 객체" }
  GOLD: { star_schema: 24, legacy_views: 35, forecast_tables: 0, note: "star 24(15 DIM+9 FACT) + 레거시 View 35 병존. forecast 제외(2026-07-10)" }
  SERVING: { semantic_views: 7, agents: 1, streamlit_apps: 6 }
  OPS: { views: 2, note: "비용 리포트 View" }
  SECURITY: { policies: "masking + network", note: "거버넌스 정책 격리" }
naming_note: "PoC ANALYTICS 스키마(=현 GOLD View)와 혼동 방지 위해 소비 계층은 SERVING으로 명명"
implementation_note: |
  ⚠️ 실제 GN_DW DB는 BRONZE를 단일 스키마가 아닌 **원천별 스키마로 분리** 구현함:
  BRONZE_CRM(관리형 액세스)·BRONZE_GA4·BRONZE_ERP·BRONZE_AGENCY (2026-07 실측).
  본 문서의 단일 BRONZE 표기는 논리 계층 명칭이며, 물리 적재 스키마는 원천별 분리(BRONZE_<SOURCE>)를 따른다.
  아래 bronze_crm_tables 41개는 BRONZE_CRM, bronze_external_tables는 GA4→BRONZE_GA4 / 광고·DRTV→BRONZE_AGENCY(또는 해당 원천)로 귀속.
  SILVER/GOLD/SERVING/OPS/SECURITY 스키마 중 현재(2026-07) 생성된 것은 OPS·SECURITY뿐이며 SILVER 이후는 미생성(빌드 초기)."
  actual_state_20260713: |
    [실측 2026-07-13] 원천정의(41테이블/876컬럼)와 물리 적재가 다름:
    - BRONZE_CRM = **43테이블 / 927컬럼** (원천 41 + 템플릿 2: TD_MS_AT_TMPLAT_BTN_LIST·TM_MS_EMAIL_TMPLAT_MNG). 전량 적재(수백만 행, 예 TM_PM_MBRFEE_ACMSLT 46.4M).
    - BRONZE_GA4."events_20260501" = **287,025행**(전체 1일 샤드, 소문자명). user_id 4.22%.
    - BRONZE_AGENCY 3테이블(DGT 197,686/REBRDC 2,064/VIDEO 35,822), BRONZE_ERP.BDGT_ACMSLT_LEDGER **2,041행 적재됨**(문서 "ERP 미수령"과 상충). [실측] ERP 컬럼=예산과목·예산단위명·재원+월별금액, **캠페인·매체 연결키 없음** → 결론7(캠페인 ROI 불가) 확정.
    - **GOLD·SILVER 스키마 미생성**(DDL만 작성, CREATE 미실행)."
```

---

## 3.2.1 CRM 원천 테이블 인벤토리 (crm_source_inventory)

> 입고팀 회신 CRM 원천 테이블/컬럼 정의서 기반. BRONZE 적재의 **source of truth**.
> ★ **기준 = 현재 측정 데이터(실측 2026-07-13): `GN_DW.BRONZE_CRM` = 43테이블 / 927컬럼, 전량 적재.**
> 참고(원천정의서 `BRONZE_CRM 테이블 정보.MD` = 41테이블/876컬럼)는 초기 정의이며, 이후 템플릿 2테이블(`TD_MS_AT_TMPLAT_BTN_LIST`·`TM_MS_EMAIL_TMPLAT_MNG`) 추가 + per-table 컬럼수 실측 상이 → **아래 인벤토리·수치는 실측을 기준으로 읽을 것**.
> **설계 원칙:** CRM 원천 테이블을 BRONZE에 1:1 전량 적재한다. 통합·정제(consolidation)는 SILVER 단계에서 수행.

```yaml
crm_source_summary:
  total_tables: 43        # ★실측 2026-07-13 (GN_DW.BRONZE_CRM). 원천정의서=41(참고)
  total_columns: 927      # ★실측 2026-07-13. 원천정의서=876(참고, per-table 상이)
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
  CRM 41개 원천 → GN_DW.BRONZE 41개 테이블로 1:1 전량 적재 (원천 구조 보존).
  통합·정제(consolidation)는 SILVER 단계에서 수행한다 (3.4절 silver_consolidation_map 참조).
  ※ 상세 컬럼 매핑은 BRONZE_CRM 테이블 정보.MD 참조

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

> CRM 원천 41개 + 외부 소스(GA/광고/DRTV) = **총 56개** 테이블을 1:1 전량 적재.
> **원칙:** BRONZE는 원천 구조를 그대로 보존한다. 통합·정제(consolidation)는 SILVER에서 수행.

```yaml
bronze_crm_tables:   # CRM 원천 41개 (3.2.1 인벤토리와 1:1 대응)
  # ── 발송(SND) 계열 ──
  - { id: SND_MEMBER_LIST, desc: "발송 대상 회원 목록" }
  - { id: SND_REQ_MST, desc: "발송 요청 마스터" }
  # ── 공통코드(TC) 계열 ──
  - { id: TC_CMMN_CD, desc: "공통코드 그룹 마스터" }
  - { id: TC_CMMN_DTL_CD, desc: "공통코드 상세" }
  # ── 마케팅 상세(TD_MS) 계열 ──
  - { id: TD_MS_CRMN_PRTCPNT, desc: "행사 참여자 상세" }
  - { id: TD_MS_EMAIL_LQY_SNDNG, desc: "이메일 대량 발송 집계" }
  - { id: TD_MS_EMAIL_SNDNG_DTLS, desc: "이메일 발송 상세" }
  - { id: TD_MS_EVENT_PRTCPNT_DTL, desc: "이벤트 참여 상세" }
  - { id: TD_MS_MSG_AT_LQY_SNDNG, desc: "알림톡 대량 발송 집계" }
  - { id: TD_MS_MSG_AT_SNDNG_DTLS, desc: "알림톡 발송 상세" }
  - { id: TD_MS_PSTMTR_LQY_SNDNG, desc: "우편물 대량 발송 집계" }
  - { id: TD_MS_PSTMTR_SNDNG_DTL, desc: "우편물 발송 상세" }
  # ── 이력(TH) 계열 ──
  - { id: TH_MM_FDRM_MBER_STNG_DTLS, desc: "정기회원 세팅 이력" }
  - { id: TH_PM_SETLE_INFO_HIST, desc: "결제정보 변경 이력" }
  # ── 공통 마스터(TM_CM) 계열 ──
  - { id: TM_CM_BRND_MNG, desc: "브랜드 관리 마스터" }
  - { id: TM_CM_CMPGN_MNG, desc: "캠페인 관리 마스터 (2026-06 +5: 국내해외/사업사례/카테고리/인입경로/마케팅캠페인)" }
  - { id: TM_CM_MKTNG_CMPGN_MNG, desc: "마케팅캠페인명 마스터 (2026-06 신규)" }
  - { id: TM_CM_DEPT_INFO, desc: "부서 정보" }
  - { id: TM_CM_MBER_DVLP_GOAL, desc: "회원 개발 목표" }
  - { id: TM_CM_SPNSR_BSNS_INFO, desc: "후원사업 정보" }
  # ── 회원 관리(TM_MM) 계열 ──
  - { id: TM_MM_FDRM_MBER_DVLP_AMT, desc: "정기회원 개발 실적" }
  - { id: TM_MM_FDRM_MBER_INFO, desc: "정기회원 마스터" }
  - { id: TM_MM_FDRM_MBER_IRSD, desc: "정기회원 증감액 이력" }
  - { id: TM_MM_FDRM_MBER_RE_SPNSR, desc: "정기회원 재후원 이력" }
  - { id: TM_MM_FDRM_MBER_SPNSR_BSNS, desc: "정기회원 후원사업 매핑" }
  - { id: TM_MM_FDRM_MBER_SPNSR_DSCNTC, desc: "정기회원 후원중단 이력" }
  - { id: TM_MM_ONCE_MBER_INFO, desc: "일시후원 회원 마스터" }
  # ── 마케팅 마스터(TM_MS) 계열 ──
  - { id: TM_MS_CRMN, desc: "세레모니 마스터" }
  - { id: TM_MS_EMAIL_SNDNG, desc: "이메일 발송 마스터" }
  - { id: TM_MS_EVENT, desc: "이벤트 마스터" }
  - { id: TM_MS_MSG_AT_SNDNG, desc: "알림톡 발송 마스터" }
  - { id: TM_MS_PSTMTR_SNDNG, desc: "우편물 발송 마스터" }
  # ── 납입/결제(TM_PM) 계열 ──
  - { id: TM_PM_DNTN_DTLS, desc: "일시후원 기부금 상세" }
  - { id: TM_PM_MBRFEE_ACMSLT, desc: "회비 청구/납입 실적" }
  - { id: TM_PM_SETLE_INFO, desc: "결제수단 정보" }
  # ── 결연 관리(TM_RM) 계열 ──
  - { id: TM_RM_BPLC_MNG, desc: "사업장 관리" }
  - { id: TM_RM_CHILD_MSTR_INFO, desc: "아동 마스터" }
  - { id: TM_RM_RELATNSP_CHG_INFO, desc: "결연 교체 정보" }
  - { id: TM_RM_RELATNSP_GFTMNEY_INFO, desc: "결연 선물금 정보" }
  - { id: TM_RM_RELATNSP_LETTER_INFO, desc: "결연 서신 정보" }
  - { id: TM_RM_RELATNSP_MSTR_INFO, desc: "결연 마스터" }

bronze_external_tables:   # CRM 외부 소스 (GA/광고/DRTV) — 15개
  - { id: FACT_AD_GA_AUDIENCE, desc: GA 잠재고객 세션 }
  - { id: FACT_AD_GOOGLE_DEMANDGEN, desc: Google 디맨드젠 광고 }
  - { id: FACT_AD_GOOGLE_PMAX, desc: Google P-MAX 광고 }
  - { id: FACT_AD_META, desc: Meta 광고 성과 }
  - { id: FACT_DIGITAL_AD_DETAIL, desc: 디지털 광고 상세 }
  - { id: FACT_DIGITAL_MONTHLY_DEV, desc: 디지털 월별 개발 목표/실적 }
  - { id: FACT_DRTV_BROADCAST_EFF, desc: DRTV 방송효과 }
  - { id: FACT_DRTV_MONTHLY_DEV, desc: DRTV 월별 개발 목표/실적 }
  - { id: FACT_GA_FEEDBACK_PAGE, desc: GA 피드백 페이지 }
  - { id: FACT_GA_VISITS_APP, desc: "GA 방문(앱)" }
  - { id: FACT_GA_VISITS_MOBILE, desc: "GA 방문(모바일)" }
  - { id: FACT_GA_VISITS_PC, desc: "GA 방문(PC)" }
  - { id: FACT_GA_VISITS_TOTAL, desc: "GA 방문(전체)" }
  - { id: FACT_RETRANSMIT_BROADCAST_CONV, desc: 재송출 방송 전환 }
  - { id: FACT_RETRANSMIT_MONTHLY_DEV, desc: 재송출 월별 개발 }

bronze_total: 56   # CRM 41 + 외부 15
```

```yaml
bronze_load_policy:
  poc_flow: "Excel -> Stage -> pandas -> Snowpark DataFrame -> RAW 테이블"
  comparison:
    - { item: 적재주체, poc: "ACCOUNTADMIN, 노트북 수동", gn_dw: "GN_DW_LOADER(최소권한)" }
    - { item: 적재방식, poc: "Snowpark create_dataframe 단건", gn_dw: "대용량은 Excel→Parquet→COPY INTO 권장" }
    - { item: 멱등성, poc: "APPEND 반복 중복 위험", gn_dw: "MERGE 또는 DELETE+INSERT" }
    - { item: 검증, poc: "row count만", gn_dw: "SP_VALIDATE_BRONZE_DATA(4.3)" }
    - { item: 스케줄, poc: 수동, gn_dw: "태스크 05:30 VALIDATE_BRONZE 이전 적재 완료 가정" }
  boundary: "BRONZE 적재 파이프라인 구현은 외부팀(LOADER) 담당으로 범위 밖. 본 문서 책임은 SILVER 정제부터. 적재 표준안=Excel_to_Table_개선.ipynb"
```

---

## 3.4 SILVER 정제 레이어 (silver_tables)

> SILVER는 BRONZE 56개 테이블을 **통합·정제(consolidation)**하여 GOLD가 소비할 **23개** 분석용 테이블로 축소한다.
> 역할: (1) 타입 캐스팅·NULL 처리 (2) 여러 원천을 JOIN/UNION하여 분석 모델 구성 (3) GOLD View가 소비하지 않는 테이블 제외.

```yaml
silver_tables:
  dim: [DIM_CAMPAIGN_CODE, DIM_MEMBER_ATTRIBUTE, DIM_ORG_CODE, DIM_TEMP_TO_REGULAR_MATCH]
  member_payment: [FACT_MEMBER_DEV_ALL, FACT_PAYMENT_HISTORY, FACT_DISCONTINUED_MEMBER]
  media_ad: [FACT_DRTV_BROADCAST_EFF, FACT_DRTV_MONTHLY_DEV, FACT_DIGITAL_AD_DETAIL, FACT_DIGITAL_MONTHLY_DEV, FACT_RETRANSMIT_BROADCAST_CONV, FACT_RETRANSMIT_MONTHLY_DEV]
  digital_ga: [FACT_AD_GA_AUDIENCE, FACT_AD_META, FACT_GA_VISITS_TOTAL, FACT_GA_VISITS_PC, FACT_GA_VISITS_MOBILE, FACT_GA_VISITS_APP]
  messaging_etc: [FACT_SMS_ALIMTALK_SEND, FACT_MARKETING_SEND_NEW, FACT_GA_FEEDBACK_PAGE, FACT_TEMP_MEMBER_DONATION]
silver_total: 23

# BRONZE → SILVER 통합 매핑 (여러 원천 → 하나의 SILVER 테이블)
# ⚠️ [결론4] 인입콜 타입 불일치: 재송출(RETRANSMIT).INBOUND_CALL_CNT=TEXT vs DRTV(영상).INBOUND_CALL_CNT=NUMBER.
#   통합/집계 전 TRY_TO_NUMBER 캐스팅 필수. 영상 원천의 CONV_CALL_CNT(전환콜)는 인입콜과 별개 지표로 분리 유지.
# ⚠️ [결론5] 대행사 3원천(DRTV/RETRANSMIT/DIGITAL)은 행 단위 출처 플래그(_SOURCE_SYSTEM)가 원천에 없음.
#   GA_/CRM_ 접두는 귀속 시스템, 3테이블은 광고유형 구분 → GOLD FAD 통합 시 명시적 _SOURCE_SYSTEM 컬럼을 SILVER에서 부여할 것.
silver_consolidation_map:
  DIM_CAMPAIGN_CODE: { sources: [TM_CM_CMPGN_MNG, TM_CM_BRND_MNG, TM_CM_MKTNG_CMPGN_MNG], work: "캠페인+브랜드+마케팅캠페인명 코드 통합, 중복 제거, TRIM" }
  DIM_MEMBER_ATTRIBUTE: { sources: [TM_MM_FDRM_MBER_INFO, TM_MM_ONCE_MBER_INFO], work: "정기+일시 회원 속성(성별/연령대/지역) 추출 통합" }
  DIM_ORG_CODE: { sources: [TM_CM_DEPT_INFO], work: "부서코드 TRIM, 중복 제거" }
  DIM_TEMP_TO_REGULAR_MATCH: { sources: [TM_MM_FDRM_MBER_INFO, TM_MM_ONCE_MBER_INFO, TM_PM_DNTN_DTLS], work: "일시→정기 전환 매칭 생성" }
  FACT_MEMBER_DEV_ALL: { sources: [TM_MM_FDRM_MBER_DVLP_AMT, TM_CM_MBER_DVLP_GOAL], work: "개발실적+목표 JOIN, 날짜 캐스팅" }
  FACT_PAYMENT_HISTORY: { sources: [TM_PM_MBRFEE_ACMSLT, TM_PM_SETLE_INFO], work: "납입실적+결제수단 JOIN, 미납금액 계산" }
  FACT_DISCONTINUED_MEMBER: { sources: [TM_MM_FDRM_MBER_SPNSR_DSCNTC, TM_MM_FDRM_MBER_INFO], work: "중단이력+회원정보 JOIN, 유지일수 계산" }
  FACT_SMS_ALIMTALK_SEND: { sources: [TD_MS_MSG_AT_LQY_SNDNG, TD_MS_MSG_AT_SNDNG_DTLS, TM_MS_MSG_AT_SNDNG], work: "알림톡 집계+상세+마스터 통합" }
  FACT_MARKETING_SEND_NEW: { sources: [TD_MS_EMAIL_LQY_SNDNG, TD_MS_EMAIL_SNDNG_DTLS, TM_MS_EMAIL_SNDNG], work: "이메일 집계+상세+마스터 통합" }
  FACT_TEMP_MEMBER_DONATION: { sources: [TM_PM_DNTN_DTLS, TM_MM_ONCE_MBER_INFO], work: "기부금상세+일시회원정보 JOIN" }
  FACT_DRTV_BROADCAST_EFF: { sources: [FACT_DRTV_BROADCAST_EFF], work: "타입 정제(NUMBER/DATE 캐스팅). 인입콜=NUMBER, 전환콜(CONV_CALL_CNT) 별도 유지" }
  FACT_DRTV_MONTHLY_DEV: { sources: [FACT_DRTV_MONTHLY_DEV], work: "타입 정제" }
  FACT_DIGITAL_AD_DETAIL: { sources: [FACT_DIGITAL_AD_DETAIL], work: "FLOAT→NUMBER, NULL→0" }
  FACT_DIGITAL_MONTHLY_DEV: { sources: [FACT_DIGITAL_MONTHLY_DEV], work: "타입 정제" }
  FACT_RETRANSMIT_BROADCAST_CONV: { sources: [FACT_RETRANSMIT_BROADCAST_CONV], work: "타입 정제 — ⚠️ 인입콜(INBOUND_CALL_CNT)=TEXT 원천 → TRY_TO_NUMBER 캐스팅 필수(결론4)" }
  FACT_RETRANSMIT_MONTHLY_DEV: { sources: [FACT_RETRANSMIT_MONTHLY_DEV], work: "타입 정제" }
  FACT_AD_GA_AUDIENCE: { sources: [FACT_AD_GA_AUDIENCE], work: "세션수/활성사용자 NUMBER, 날짜 DATE" }
  FACT_AD_META: { sources: [FACT_AD_META], work: "노출/클릭/지출 NUMBER, 보고기간 DATE" }
  FACT_GA_VISITS_TOTAL: { sources: [FACT_GA_VISITS_TOTAL], work: "TEXT→NUMBER" }
  FACT_GA_VISITS_PC: { sources: [FACT_GA_VISITS_PC], work: "TEXT→NUMBER" }
  FACT_GA_VISITS_MOBILE: { sources: [FACT_GA_VISITS_MOBILE], work: "TEXT→NUMBER" }
  FACT_GA_VISITS_APP: { sources: [FACT_GA_VISITS_APP], work: "TEXT→NUMBER" }
  FACT_GA_FEEDBACK_PAGE: { sources: [FACT_GA_FEEDBACK_PAGE], work: "이탈률/참여율 NUMBER" }

# BRONZE 중 SILVER에 포함되지 않는 테이블 (현재 GOLD View 미참조)
bronze_not_in_silver:
  - { id: SND_MEMBER_LIST, reason: "현재 GOLD View 미참조 (향후 발송 분석 확장 시 추가)" }
  - { id: SND_REQ_MST, reason: "현재 GOLD View 미참조" }
  - { id: TC_CMMN_CD, reason: "공통코드 — SILVER 통합 시 lookup으로만 사용" }
  - { id: TC_CMMN_DTL_CD, reason: "공통코드 상세 — SILVER 통합 시 lookup으로만 사용" }
  - { id: TD_MS_CRMN_PRTCPNT, reason: "세레모니 — 현재 분석 범위 밖" }
  - { id: TD_MS_EVENT_PRTCPNT_DTL, reason: "이벤트 참여 — 현재 분석 범위 밖" }
  - { id: TD_MS_PSTMTR_LQY_SNDNG, reason: "우편물 — 현재 분석 범위 밖" }
  - { id: TD_MS_PSTMTR_SNDNG_DTL, reason: "우편물 — 현재 분석 범위 밖" }
  - { id: TH_MM_FDRM_MBER_STNG_DTLS, reason: "세팅이력 — 현재 GOLD View 미참조" }
  - { id: TH_PM_SETLE_INFO_HIST, reason: "결제변경이력 — FACT_PAYMENT_HISTORY에 현재값 반영" }
  - { id: TM_CM_SPNSR_BSNS_INFO, reason: "후원사업정보 — DIM_CAMPAIGN_CODE에 통합" }
  - { id: TM_MM_FDRM_MBER_IRSD, reason: "증감액이력 — 현재 GOLD View 미참조" }
  - { id: TM_MM_FDRM_MBER_RE_SPNSR, reason: "재후원이력 — 현재 GOLD View 미참조" }
  - { id: TM_MM_FDRM_MBER_SPNSR_BSNS, reason: "후원사업매핑 — 현재 GOLD View 미참조" }
  - { id: TM_MS_CRMN, reason: "세레모니 마스터 — 현재 분석 범위 밖" }
  - { id: TM_MS_EVENT, reason: "이벤트 마스터 — 현재 분석 범위 밖" }
  - { id: TM_MS_PSTMTR_SNDNG, reason: "우편물 마스터 — 현재 분석 범위 밖" }
  - { id: TM_RM_BPLC_MNG, reason: "사업장 — 현재 GOLD View 미참조" }
  - { id: TM_RM_CHILD_MSTR_INFO, reason: "아동 — 현재 GOLD View 미참조" }
  - { id: TM_RM_RELATNSP_CHG_INFO, reason: "결연교체 — 현재 GOLD View 미참조" }
  - { id: TM_RM_RELATNSP_GFTMNEY_INFO, reason: "결연선물금 — 현재 GOLD View 미참조" }
  - { id: TM_RM_RELATNSP_LETTER_INFO, reason: "결연서신 — 현재 GOLD View 미참조" }
  - { id: TM_RM_RELATNSP_MSTR_INFO, reason: "결연마스터 — 현재 GOLD View 미참조" }
  - { id: FACT_AD_GOOGLE_DEMANDGEN, reason: "현재 GOLD View 미참조" }
  - { id: FACT_AD_GOOGLE_PMAX, reason: "현재 GOLD View 미참조" }
  note: "향후 분석 요건 추가 시 SILVER 정제 프로시저를 확장하여 포함 가능"
```

---

## 4. 프로시저 생성 (procedures)

> **실행 위치:** GOLD View 생성 전(step 5). SILVER 산출을 담당.

### 4.1 BRONZE → SILVER 통합·정제 프로시저 (refine_procedures)

> 각 프로시저는 BRONZE의 원천 테이블을 참조하여 SILVER 분석 테이블을 산출한다.
> 통합 대상(여러 BRONZE → 1 SILVER)은 프로시저 내에서 JOIN/UNION 수행.

```yaml
refine_procedures:
  - { id: 1,  proc: SP_REFINE_DIM_CAMPAIGN, target: [DIM_CAMPAIGN_CODE], sources: [TM_CM_CMPGN_MNG, TM_CM_BRND_MNG, TM_CM_MKTNG_CMPGN_MNG, TC_CMMN_DTL_CD], work: "캠페인+브랜드+마케팅캠페인명 통합, 코드 TRIM, 사용여부 필터" }
  - { id: 2,  proc: SP_REFINE_DIM_MEMBER, target: [DIM_MEMBER_ATTRIBUTE], sources: [TM_MM_FDRM_MBER_INFO, TM_MM_ONCE_MBER_INFO], work: "정기+일시 회원 속성 통합, NULL 처리, 연령대/지역 표준화" }
  - { id: 3,  proc: SP_REFINE_FACT_PAYMENT, target: [FACT_PAYMENT_HISTORY], sources: [TM_PM_MBRFEE_ACMSLT, TM_PM_SETLE_INFO], work: "납입+결제수단 JOIN, DATE 캐스팅, 미납금액 계산" }
  - { id: 4,  proc: SP_REFINE_FACT_MEMBER_DEV, target: [FACT_MEMBER_DEV_ALL], sources: [TM_MM_FDRM_MBER_DVLP_AMT, TM_CM_MBER_DVLP_GOAL], work: "개발실적+목표 JOIN, 날짜 캐스팅, 신청월 파생" }
  - { id: 5,  proc: SP_REFINE_FACT_DISCONTINUED, target: [FACT_DISCONTINUED_MEMBER], sources: [TM_MM_FDRM_MBER_SPNSR_DSCNTC, TM_MM_FDRM_MBER_INFO], work: "중단이력+회원정보 JOIN, 유지일수 계산" }
  - { id: 6,  proc: SP_REFINE_FACT_DIGITAL_AD, target: [FACT_DIGITAL_AD_DETAIL], sources: [FACT_DIGITAL_AD_DETAIL], work: "FLOAT→NUMBER 캐스팅, NULL 0 대체" }
  - { id: 7,  proc: SP_REFINE_FACT_SMS, target: [FACT_SMS_ALIMTALK_SEND], sources: [TD_MS_MSG_AT_LQY_SNDNG, TD_MS_MSG_AT_SNDNG_DTLS, TM_MS_MSG_AT_SNDNG], work: "알림톡 집계+상세+마스터 통합, TIMESTAMP/NUMBER 캐스팅" }
  - { id: 8,  proc: SP_REFINE_FACT_AD_GA, target: [FACT_AD_GA_AUDIENCE], sources: [FACT_AD_GA_AUDIENCE], work: "세션수/활성사용자 NUMBER, 날짜 DATE" }
  - { id: 9,  proc: SP_REFINE_FACT_AD_META, target: [FACT_AD_META], sources: [FACT_AD_META], work: "노출/클릭/지출 NUMBER, 보고기간 DATE" }
  - { id: 10, proc: SP_REFINE_FACT_GA_VISITS, target: [FACT_GA_VISITS_TOTAL, FACT_GA_VISITS_PC, FACT_GA_VISITS_MOBILE, FACT_GA_VISITS_APP], sources: [FACT_GA_VISITS_TOTAL, FACT_GA_VISITS_PC, FACT_GA_VISITS_MOBILE, FACT_GA_VISITS_APP], work: "세션/페이지뷰/방문수 TEXT→NUMBER (4개 테이블)" }
  - { id: 11, proc: SP_REFINE_FACT_GA_FEEDBACK, target: [FACT_GA_FEEDBACK_PAGE], sources: [FACT_GA_FEEDBACK_PAGE], work: "이탈률/참여율/평균세션시간 NUMBER" }
  - { id: 12, proc: SP_REFINE_DIM_ORG, target: [DIM_ORG_CODE], sources: [TM_CM_DEPT_INFO], work: "부서코드 TRIM, 중복 제거" }
  - { id: 13, proc: SP_REFINE_DIM_TEMP_MATCH, target: [DIM_TEMP_TO_REGULAR_MATCH], sources: [TM_MM_FDRM_MBER_INFO, TM_MM_ONCE_MBER_INFO, TM_PM_DNTN_DTLS], work: "일시→정기 전환 매칭, 전환일 DATE" }
  - { id: 14, proc: SP_REFINE_FACT_DRTV, target: [FACT_DRTV_BROADCAST_EFF, FACT_DRTV_MONTHLY_DEV], sources: [FACT_DRTV_BROADCAST_EFF, FACT_DRTV_MONTHLY_DEV], work: "횟수/광고비/인입콜/시청률 NUMBER, 방송일자 DATE (2개)" }
  - { id: 15, proc: SP_REFINE_FACT_DIGITAL_DEV, target: [FACT_DIGITAL_MONTHLY_DEV], sources: [FACT_DIGITAL_MONTHLY_DEV], work: "예산/목표/실적 NUMBER, 날짜 DATE" }
  - { id: 16, proc: SP_REFINE_FACT_RETRANSMIT, target: [FACT_RETRANSMIT_BROADCAST_CONV, FACT_RETRANSMIT_MONTHLY_DEV], sources: [FACT_RETRANSMIT_BROADCAST_CONV, FACT_RETRANSMIT_MONTHLY_DEV], work: "횟수/편성비/인입콜 NUMBER, 날짜 DATE (2개)" }
  - { id: 17, proc: SP_REFINE_FACT_MARKETING_SEND, target: [FACT_MARKETING_SEND_NEW], sources: [TD_MS_EMAIL_LQY_SNDNG, TD_MS_EMAIL_SNDNG_DTLS, TM_MS_EMAIL_SNDNG], work: "이메일 집계+상세+마스터 통합, TIMESTAMP 캐스팅" }
  - { id: 18, proc: SP_REFINE_FACT_TEMP_DONATION, target: [FACT_TEMP_MEMBER_DONATION], sources: [TM_PM_DNTN_DTLS, TM_MM_ONCE_MBER_INFO], work: "기부금+일시회원 JOIN, 후원일 DATE, 금액 NUMBER" }
refine_principles:
  - "CREATE OR REPLACE TABLE (전체 재생성, 멱등성)"
  - "SILVER = BRONZE 원천 통합 + 파생 컬럼 + 올바른 타입 (구조가 달라질 수 있음)"
  - "NULL key 레코드는 WHERE로 제외"
  - "통합 대상 프로시저는 여러 BRONZE 테이블을 JOIN/UNION하여 단일 SILVER 테이블 산출"
```

### 4.2 SILVER → GOLD 프로시저 (load_gold)

> GOLD는 **star schema 물리 테이블 적재**(DIM/FACT MERGE)로 구성. `SP_LOAD_GOLD`가 SILVER를 GOLD 15 DIM + 9 FACT로 적재하며, `TASK_LOAD_GOLD`가 정제 완료 후 실행(04_운영.md 5장).
> ⛔ **[forecast 제외 결정 2026-07-10]** GOLD 예측(Forecast) 파이프라인은 **비활성**한다. star schema 24에 예측 테이블이 없으며, 레거시 예측 자산(`FORECAST_*` 5종 테이블·`V_FORECAST_*`/`V_CAMPAIGN_*_FORECAST` 뷰·`SP_REFRESH_FORECAST_DATA`·`TASK_REFRESH_FORECAST`)은 전환 대상에서 제외한다. 아래 정의는 이력 참고용이며 운영 파이프라인에서 실행하지 않는다.

```yaml
load_gold:
  proc: SP_LOAD_GOLD
  method: "SILVER FACT/DIM → GOLD star schema MERGE (15 DIM + 9 FACT)"
  location: GN_DW.GOLD
  trigger: "TASK_LOAD_GOLD (정제 완료 후 실행, 04_운영.md 5장)"

# ⛔ 비활성 (forecast 제외 결정). 실행하지 않음 — 이력 참고용.
forecast_pipeline_DEPRECATED:
  proc: SP_REFRESH_FORECAST_DATA
  engine: SNOWFLAKE.ML.FORECAST   # 브랜드별 월간 개발건수/평균납입액 예측
  steps:
    - "학습데이터 생성: SILVER(FACT_MEMBER_DEV_ALL, FACT_PAYMENT_HISTORY) -> FORECAST_TRAINING_DATA -> 브랜드·월 집계로 TRAIN_DEV_COUNT, TRAIN_AVG_PAYMENT"
    - "모델 학습/예측: TRAIN_* 입력으로 ML.FORECAST 모델 생성 후 FORECAST() 호출"
    - "결과 저장: FORECAST_DEV_COUNT_RESULT, FORECAST_AVG_PAYMENT_RESULT"
    - "노출: V_FORECAST_DEV_COUNT, V_FORECAST_AVG_PAYMENT가 TRAIN_*(actual) + FORECAST_*_RESULT(forecast) UNION ALL"
  location: GN_DW.GOLD
  status: "DEPRECATED — forecast 제외 결정(2026-07-10)로 미운영"
```

### 4.3 유틸리티 프로시저 (utility_procedures)

> 의존성 상 ETL_LOG 테이블과 SP_LOG_ETL_STATUS는 4.1보다 먼저 정의 (4.1이 내부 호출).

```yaml
utility_procedures:
  - { id: 1, proc: SP_RUN_ALL_REFINEMENT, desc: "4.1 모든 정제 프로시저 순차 호출(오케스트레이션)" }
  - { id: 2, proc: SP_LOG_ETL_STATUS, desc: "ETL 실행 로그 기록(시작/종료/에러/row count)" }
  - { id: 3, proc: SP_VALIDATE_BRONZE_DATA, desc: "BRONZE 품질 체크(NULL 비율, row count 변동)" }
```

---

> **이전 단계:** `01_환경_Role.md` · **다음 단계:** `03_GOLD_SERVING.md` (GOLD View → Semantic View → Agent → 권한 → Streamlit)
