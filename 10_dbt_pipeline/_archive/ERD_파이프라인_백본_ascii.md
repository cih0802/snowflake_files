# GN_DW 파이프라인 백본 ERD (ASCII)

> 테이블명 + 키 컬럼만. 상세 컬럼 생략. 좌 Bronze / 중 Silver / 우 Gold.
> 실측: BRONZE 4스키마 -> SILVER 32 -> GOLD 15 DIM + 8 FACT (+WIDE 8).
> (보류) = 원천 미입고: FACT_TARGET_BIZ / WIDE_TARGET_BIZ (E-6 대기).

================================================================================
## 1. 브론즈별 (소스 도메인 레인)
================================================================================

  BRONZE (원천 1:1)              SILVER (GN_DW.SILVER 32)          GOLD (15 DIM + 8 FACT)
  ------------------------      ------------------------------    ----------------------------

[CRM] ---------------------------------------------------------------------------------------
  BRONZE_CRM (43)               CRM_MEMBER      [MEMBER_DK] ----> DIM_MEMBER  [MEMBER_SK/DK]
   회원마스터 [MEMBER_DK] --->                              \---> DIM_MEMBER_IDENTITY [IDENTITY_SK]
   캠페인/브랜드[CMPGN_CD]--->  CRM_CAMPAIGN    [CMPGN_CD] ----> DIM_CAMPAIGN [CAMPAIGN_SK]
   후원사업[SPNSR_BSNS_ID]-->  CRM_SPONSORSHIP [SPNSR_BSNS_ID]-> DIM_SPONSORSHIP [SPONSORSHIP_SK]
   부서 [DEPT_ID] --------->    CRM_ORG         [DEPT_ID] -----> DIM_ORG      [ORG_SK]
   행사 [EVENT_KEY] ------->    CRM_EVENT       [EVENT_KEY] ----> DIM_EVENT    [EVENT_SK]
   발송 [SND_REQ_MST] ----->    CRM_SEND_REQUEST -------------->  DIM_SERVICE  [SERVICE_SK]
   회비/기부/결제 --------->    CRM_PAYMENT_METHOD ------------>  DIM_PAYMENT  [PAYMENT_SK]
   공통코드 --------------->    CRM_MEMBER_DISCONTINUE -------->  DIM_REASON   [REASON_SK]
                                CRM_CODE (라벨조인)
                                CRM_MEMBER_STATUS_HIST \
                                CRM_MEMBER_DEV          \
                                CRM_MEMBER_AMT_CHANGE    >------> FACT_MEMBER_MONTHLY (FMM)
                                CRM_MEMBER_RESPONSOR    /          [MEMBER_DK x MONTH]
                                CRM_MEMBER_SPONSOR_BIZ /
                                CRM_PAYMENT_BILLING   /
                                CRM_MEMBER_DEV + DISCONTINUE ----> FACT_MEMBER_EVENT (FME)
                                CRM_DEV_TARGET ----------------->  FACT_TARGET_DEV (FTG_D)
                                CRM_SEND_REQ/MEMBER/RESULT \
                                CRM_RELATION_ACTIVITY       >----> FACT_SERVICE_EVENT (FSE)
                                CRM_EVENT_PARTICIPATION -------->  FACT_EVENT_PARTICIPATION (FEP)

[GA4] ---------------------------------------------------------------------------------------
  BRONZE_GA4                    GA4_TRAFFIC_SOURCE ------------>  DIM_GA_SOURCE [GA_SOURCE_SK]
   events_YYYYMMDD 샤드  --->   GA4_EVENT_DIM ----------------->  DIM_GA_EVENT  [GA_EVENT_SK]
   [event/user_pseudo_id]      GA4_DEVICE -------------------->  DIM_DEVICE    [DEVICE_SK]
                                GA4_IDENTITY -> IDENTITY_MEMBER_XREF -> DIM_MEMBER_IDENTITY
                                    [GA_MEMBER_ID] [PSEUDO<->MEMBER_DK]  [IDENTITY_SK]
                                GA4_EVENT [GA_SESSION_ID] -----> FACT_GA_BEHAVIOR (FGA)
                                                          \----> FACT_AD_PERFORMANCE (FAD, 전환)

[ERP] ---------------------------------------------------------------------------------------
  BRONZE_ERP                    ERP_BUDGET_ITEM --------------->  DIM_BUDGET_ITEM [BUDGET_ITEM_SK]
   BDGT_ACMSLT_LEDGER --->      ERP_BUDGET -------------------->  FACT_BUDGET (FBD) [MONTH_KEY]
   [예산과목 x 월]              ERP_BIZ_TARGET (schema-only) -.-> FACT_TARGET_BIZ (보류)

[AGENCY] ------------------------------------------------------------------------------------
  BRONZE_AGENCY (3)             AGENCY_AD_CREATIVE ------------>  DIM_AD_CREATIVE [AD_CREATIVE_SK]
   DGT/REBRDC/VIDEO ----->      AGENCY_AD_PERFORMANCE ---------> FACT_AD_PERFORMANCE (FAD)
   _AD_CMPGN_DTLS                  [AD_DATE]

  공통: DIM_DATE [DATE_SK/MONTH_KEY] = ETL 생성 캘린더 (원천 무관, 모든 일/월 팩트 조인)


================================================================================
## 2. gold별 (스타 스키마 백본: FACT <-> 공유 DIM)
================================================================================

                        DIM_DATE[DATE_SK/MONTH_KEY]
                        DIM_MEMBER[MEMBER_DK]
                        DIM_CAMPAIGN[CAMPAIGN_SK]
             (공유 차원) DIM_SPONSORSHIP[SPONSORSHIP_SK]
                        DIM_ORG[ORG_SK]  DIM_REASON[REASON_SK]

  FACT_MEMBER_MONTHLY (FMM) -- MEMBER_DK, CAMPAIGN, SPONSORSHIP, PAYMENT, REASON
  FACT_MEMBER_EVENT   (FME) -- DATE, MEMBER_DK, CAMPAIGN, SPONSORSHIP, ORG, REASON
  FACT_TARGET_DEV     (FTGD)-- ORG, MONTH_KEY
  FACT_SERVICE_EVENT  (FSE) -- DATE, MEMBER_DK, SERVICE, CAMPAIGN
  FACT_EVENT_PARTICIP (FEP) -- DATE, MEMBER_DK, EVENT, CAMPAIGN, SPONSORSHIP
  FACT_GA_BEHAVIOR    (FGA) -- DATE, IDENTITY, GA_EVENT, GA_SOURCE, DEVICE, CAMPAIGN
  FACT_AD_PERFORMANCE (FAD) -- PERF_DATE, AD_CREATIVE, CAMPAIGN, DEVICE
  FACT_BUDGET         (FBD) -- MONTH_KEY, BUDGET_ITEM, ORG
  FACT_TARGET_BIZ     (FTGB)-- (보류: 원천 E-6 미입고)

  차원키(SK) 요약:
   DIM_MEMBER[MEMBER_SK/MEMBER_DK]        DIM_MEMBER_IDENTITY[IDENTITY_SK]
   DIM_CAMPAIGN[CAMPAIGN_SK]              DIM_SPONSORSHIP[SPONSORSHIP_SK]
   DIM_ORG[ORG_SK]  DIM_SERVICE[SERVICE_SK]  DIM_PAYMENT[PAYMENT_SK]
   DIM_REASON[REASON_SK]  DIM_EVENT[EVENT_SK]  DIM_DATE[DATE_SK/MONTH_KEY]
   DIM_GA_SOURCE[GA_SOURCE_SK]  DIM_GA_EVENT[GA_EVENT_SK]  DIM_DEVICE[DEVICE_SK]
   DIM_AD_CREATIVE[AD_CREATIVE_SK]  DIM_BUDGET_ITEM[BUDGET_ITEM_SK]


================================================================================
## 3. 단일 통합 (스키마 3열)
================================================================================

   BRONZE (4)              SILVER (32)                      GOLD (15 DIM + 8 FACT + 8 WIDE)
  -----------            ---------------------------        --------------------------------
  BRONZE_CRM (43) -----> CRM_* (21)                  ---->  DIM x15  [*_SK, MEMBER_DK, MONTH_KEY]
                         [MEMBER_DK/CMPGN_CD/           \-> FACT x8  [MEMBER_DK/*_SK/DATE_SK/MONTH_KEY]
                          SPNSR_BSNS_ID/DEPT_ID/EVENT_KEY]
  BRONZE_GA4 --------->  GA4_* (5) [GA_SESSION_ID/GA_MEMBER_ID]
                              |
                              v
                         IDENTITY_MEMBER_XREF [PSEUDO<->MEMBER_DK]
  BRONZE_ERP --------->  ERP_* (3) [예산과목/MONTH] ----->  (DIM_BUDGET_ITEM / FACT_BUDGET)
  BRONZE_AGENCY (3) -->  AGENCY_* (2) [AD_DATE/소재] --->   (DIM_AD_CREATIVE / FACT_AD_PERFORMANCE)

                                                            DIM + FACT ----> WIDE view x8

  단방향 계약: SERVING -> GOLD -> SILVER -> BRONZE (GOLD의 BRONZE 직참조 금지)
