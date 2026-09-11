#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""DEC-52 전사 코멘트 4블록 표준화 딕셔너리 및 적용 스크립트.

표준 템플릿:
  1. 테이블: [엔티티 정의]. [Grain: 키1 × 키2 (1행=1엔티티)]. [주의: 조인/집계 제약]. [원천: 원천시스템 → BRONZE → SILVER]
  2. Semantic View: [SV 목적 (base: GOLD.테이블)]. [Grain: ...]. [활성 지표: ...]. [주의: Cross-fact/비가산 경고]. [원천: ...]

규칙7 준수: 고정된 행수·실측 수치 기입 금지
sv_unit_gate 필수 문안 및 Agent [원천], [주의] 태그 100% 보존.
"""

GOLD_TABLE_COMMENTS = {
    "DIM_DATE": "날짜 차원. [Grain: DATE_SK (1행=1일)]. [주의: 월/연 집계 시 팬아웃 방지를 위해 월팩트는 DIM_MONTH 조인 권장]. [원천: DW 생성 → BRONZE_CALENDAR → SILVER_DATE].",
    "DIM_MONTH": "월 차원. [Grain: MONTH_KEY (1행=1월)]. [주의: 월 단위 팩트와 일 차원(DIM_DATE) 직접 조인 시 팬아웃 방지 전용]. [원천: DW 생성 → DIM_DATE 사영].",
    "DIM_ORG": "조직/부서 차원. [Grain: ORG_SK (1행=1부서, SCD1)]. [주의: 과거 소속 이력 미관리(현재 부서 기준)]. [원천: CRM → BRONZE_CRM.TM_CM_DEPT_MNG → SILVER.CRM_ORG].",
    "DIM_MEMBER_STATUS_HISTORY": "회원 상태전이 이력 차원. [Grain: MEMBER_SK (1행=1회원상태버전, SCD2)]. [주의: 팩트와 MEMBER_DK 직접 조인 시 팬아웃 발생, 시점조인 필수]. [원천: CRM → BRONZE_CRM.TM_MM_MBER_MNG → SILVER.CRM_MEMBER_STATUS_HIST].",
    "DIM_MEMBER": "정규 회원 마스터 차원 (분석 기본 진입점). [Grain: MEMBER_DK (1행=1회원, IS_CURRENT 투영)]. [주의: 과거 시점 상태 분석은 DIM_MEMBER_STATUS_HISTORY 시점조인 사용]. [원천: SILVER.CRM_MEMBER_STATUS_HIST(IS_CURRENT)].",
    "DIM_MEMBER_ACQUISITION": "회원 획득(가입) 귀속 차원. [Grain: MEMBER_DK (1행=1회원)]. [주의: 팩트와 LEFT JOIN 필수(개발사건 없는 회원 유실 방지)]. [원천: GOLD.FACT_MEMBER_COHORT].",
    "DIM_MEMBER_IDENTITY": "회원 신원 식별 브릿지 차원. [Grain: IDENTITY_SK (1행=1식별키)]. [주의: 웹/앱 행동과 CRM 회원 연계용]. [원천: GA4/CRM → SILVER.IDENTITY_MEMBER_XREF].",
    "DIM_CAMPAIGN": "캠페인 차원. [Grain: CAMPAIGN_SK (1행=1캠페인)]. [주의: 분류체계 카테고리/상위/홍보방법 매핑]. [원천: CRM → BRONZE_CRM.TM_CM_CMPGN_MNG → SILVER.CRM_CAMPAIGN].",
    "DIM_MARKETING_CAMPAIGN": "마케팅 캠페인 Conformed 차원. [Grain: MKTG_CAMPAIGN_SK (1행=1마케팅캠페인)]. [주의: 광고(AGENCY)와 CRM 개발 결합의 유일 결합축]. [원천: SILVER.CRM_MARKETING_CAMPAIGN].",
    "DIM_SPONSORSHIP": "후원사업 차원. [Grain: SPONSORSHIP_SK (1행=1후원사업)]. [주의: 정기/일시 구분 및 상위 사업군 분류]. [원천: CRM → BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO → SILVER.CRM_SPONSORSHIP].",
    "DIM_AD_CREATIVE": "광고 소재/매체 차원. [Grain: AD_CREATIVE_SK (1행=1소재)]. [주의: 대행사 3원천 소재 통합]. [원천: AGENCY 3소스 → SILVER.AGENCY_AD_CREATIVE].",
    "DIM_BIGQUERY_SOURCE": "BigQuery 트래픽소스 차원. [Grain: BIGQUERY_SOURCE_SK (1행=1트래픽소스)]. [주의: 세션 소스/매체/캠페인 결합]. [원천: GA4 → SILVER.BIGQUERY_TRAFFIC_SOURCE].",
    "DIM_BIGQUERY_EVENT": "BigQuery 이벤트분류 차원. [Grain: BIGQUERY_EVENT_SK (1행=1이벤트)]. [주의: GA4 이벤트명 및 주요 파라미터 매핑]. [원천: GA4 → SILVER.BIGQUERY_EVENT_DIM].",
    "DIM_SERVICE": "발송 서비스 채널 차원. [Grain: SERVICE_SK (1행=1채널유형)]. [주의: 대/중/소 상세분류는 DIM_SEND_TYPE 참조]. [원천: CRM → BRONZE_CRM.TM_MS_* → SILVER.CRM_SEND_REQUEST].",
    "DIM_SEND_TYPE": "발송구분 대/중/소 차원. [Grain: SEND_TYPE_SK (1행=1분류경로)]. [주의: 발송 메시지 세부 카테고리 매핑]. [원천: CRM → BRONZE_CRM.TM_MS_EMAIL/MSG/PSTMTR → SILVER.CRM_SEND_REQUEST].",
    "DIM_PAYMENT": "납입 결제수단 차원. [Grain: PAYMENT_SK (1행=1결제유형)]. [주의: 금융결제원/카드사 수납방식 분류]. [원천: CRM → SILVER.CRM_PAYMENT_METHOD].",
    "DIM_REASON": "중단/미납 사유코드 차원. [Grain: REASON_SK (1행=1사유)]. [주의: 후원중단 및 청구미납 사유 통합]. [원천: CRM → BRONZE_CRM.TM_CM_CODE_DTL → SILVER.CRM_CODE].",
    "DIM_DEVICE": "디바이스/기기 차원. [Grain: DEVICE_SK (1행=1디바이스)]. [주의: PC/모바일/방송(해당없음) 분류]. [원천: GA4/AGENCY → SILVER.BIGQUERY_DEVICE].",
    "DIM_EVENT": "행사/이벤트 마스터 차원. [Grain: EVENT_SK (1행=1행사)]. [주의: 일반행사 및 캠페인행사 통합]. [원천: CRM → BRONZE_CRM.TM_MS_EVENT/CRMN → SILVER.CRM_EVENT].",
    "DIM_BUDGET_ITEM": "예산 세세목 차원. [Grain: BUDGET_ITEM_SK (1행=1세세목)]. [주의: 장/관/항/목/세목/세세목 계층 매핑]. [원천: ERP → BRONZE_ERP → SILVER.ERP_BUDGET_ITEM].",
    "FACT_MEMBER_MONTHLY": "회원 월별 스냅샷 팩트. [Grain: MONTH_KEY × MEMBER_DK (1행=1회원월)]. [주의: FACT_MEMBER_FEE와 합산 시 회비 과대계상 위험(형제팩트중복)]. [원천: SILVER.CRM_PAYMENT_BILLING ∪ CRM_MEMBER_DEV/DISCONTINUE].",
    "FACT_MEMBER_LIFECYCLE": "회원 생애주기 전이 팩트. [Grain: DATE_SK × MEMBER_DK × EVENT_TYPE (1행=1상태전이)]. [주의: 개발(신규/증액/재후원)과 중단 사건의 통합 이력]. [원천: SILVER.CRM_MEMBER_DEV ∪ CRM_MEMBER_DISCONTINUE].",
    "FACT_TARGET_MEMBER_DEV": "회원개발 부문 목표 팩트. [Grain: MONTH_KEY × ORG_SK × DEV_TYPE (1행=1목표)]. [주의: 부서별 신규/증액/재후원 목표 관리]. [원천: CRM → BRONZE_CRM.TM_CM_MBER_DVLP_GOAL → SILVER.CRM_DEV_TARGET].",
    "FACT_TARGET_PROJECT": "사업/프로젝트 목표 팩트. [Grain: MONTH_KEY × ORG_SK × SPONSORSHIP_SK (1행=1목표)]. [주의: 원천 미입고 시 0행 유지(E-6)]. [원천: CRM → SILVER.CRM_BIZ_TARGET].",
    "FACT_MESSAGE_DISPATCH": "메시지 발송 및 결과 팩트. [Grain: DATE_SK × MEMBER_DK × SERVICE_SK × CAMPAIGN_SK (1행=1발송)]. [주의: 이메일/문자/알림톡/우편 발송 성공·실패 이력]. [원천: CRM → SILVER.CRM_SEND_MEMBER/REQUEST].",
    "FACT_BIGQUERY_BEHAVIOR": "BigQuery 웹/앱 사용자 행동 팩트. [Grain: DATE_SK × IDENTITY_SK × EVENT/SOURCE/DEVICE × PAGE (1행=1행동)]. [주의: 비가산 지표(활성사용자/이탈률) 단순 합산 금지]. [원천: GA4 → SILVER.BIGQUERY_EVENT].",
    "FACT_AD_PERFORMANCE": "광고 성과 코어 팩트. [Grain: AD_PERF_DK (1행=1광고집행)]. [주의: 디지털/방송 3원천 공통 지표(비용/노출/클릭)]. [원천: AGENCY 3소스 → SILVER.AGENCY_AD_PERFORMANCE].",
    "FACT_AD_BROADCAST": "방송광고 성과 위성 팩트. [Grain: AD_PERF_DK (코어 1:1)]. [주의: TV/케이블 방송 송출 고유 속성]. [원천: AGENCY → SILVER.AGENCY_AD_BROADCAST].",
    "FACT_AD_DIGITAL": "디지털광고 성과 위성 팩트. [Grain: AD_PERF_DK (코어 1:1)]. [주의: 매체별 성과 및 대행사 산정 비율 지표]. [원천: AGENCY → SILVER.AGENCY_AD_DIGITAL].",
    "FACT_AD_BROADCAST_CASE": "방송광고 사례 정규화 위성 팩트. [Grain: AD_PERF_DK × CASE_SEQ (1행=1사례)]. [주의: 코어 대비 1:N 조인 팬아웃 주의]. [원천: AGENCY → SILVER.AGENCY_AD_BROADCAST_CASE].",
    "FACT_EVENT_ATTENDANCE": "행사 출석/참여 팩트. [Grain: DATE_SK × MEMBER_DK × EVENT_SK (1행=1참여)]. [주의: 신청/대기/취소/참석 상태별 집계]. [원천: CRM → SILVER.CRM_EVENT_PARTICIPATION].",
    "FACT_BUDGET": "월 예산 팩트. [Grain: MONTH_KEY × ORG_SK × BUDGET_ITEM_SK (1행=1예산)]. [주의: 부서/계정별 편성·집행액 관리]. [원천: ERP → BRONZE_ERP.BDGT_ACMSLT_LEDGER → SILVER.ERP_BUDGET].",
    "FACT_BUDGET_YEARLY": "연 예산 팩트. [Grain: YEAR × ORG_SK × BUDGET_ITEM_SK (1행=1연예산)]. [주의: 연 총액 관리 전용(월 팩트와 합산 금지)]. [원천: ERP → SILVER.ERP_BUDGET_YEARLY].",
    "FACT_MEMBER_COHORT": "회원 획득 코호트 팩트. [Grain: MEMBER_DK (1행=1회원)]. [주의: 캠페인별 12개월 고정 이탈률 및 유지기간 정본]. [원천: GOLD.FACT_MEMBER_LIFECYCLE].",
    "FACT_MEMBER_FEE": "회비 분해 팩트. [Grain: MEMBER_DK × MONTH_KEY × SPONSORSHIP_SK × FEE_DIV × PAYMENT × SETLE (1행=1납입)]. [주의: FACT_MEMBER_MONTHLY와 동일 원천 다른 Grain, 합산 금지]. [원천: CRM → SILVER.CRM_PAYMENT_BILLING].",
    "FACT_MEMBER_DEV_ACHIEVEMENT": "회원개발 목표 대비 실적 월 Conform 팩트. [Grain: MONTH_KEY × ORG_SK × DEV_TYPE (1행=1달성)]. [주의: 목표(FTG_D) × 실적(FME) FULL OUTER 조인, 달성률은 분모·분자 재계산]. [원천: GOLD.FACT_TARGET_MEMBER_DEV × FACT_MEMBER_LIFECYCLE].",
    "FACT_MEMBER_SPONSORSHIP_SPAN": "회원×후원약정 기간 팩트. [Grain: MEMBER_DK × SPNSR_BSNS_NO (1행=1약정)]. [주의: 캠페인별/후원사업별 활동회원 질의 전용]. [원천: CRM → SILVER.CRM_MEMBER_SPONSOR_SPAN]."
}

SILVER_TABLE_COMMENTS = {
    "CRM_MEMBER": "회원 통합 마스터 (정기∪일시). [Grain: MBER_NO (1행=1회원)]. [주의: 정기회원과 일시회원 통합]. [원천: CRM → BRONZE_CRM.TM_MM_MBER_MNG].",
    "CRM_MEMBER_STATUS_HIST": "회원 상태전이 이력 (SCD2). [Grain: MBER_NO × HIST_SN (1행=1상태버전)]. [주의: 상태변경 시작~종료일 구간 이력 관리]. [원천: CRM → BRONZE_CRM.TH_MM_MBER_STAT_HIST].",
    "CRM_MEMBER_DEV": "개발약정 이력 (신규/증액/재후원/중단). [Grain: SPNSR_NO × SPNSR_BSNS_NO × OCCRRNC_DE × SER_NO (1행=1개발약정)]. [주의: DVLP_DIV_CD(1 신규, 2 증액, 3 감액, 4 재후원, 5 중단)]. [원천: CRM → BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT].",
    "CRM_MEMBER_AMT_CHANGE": "약정 금액 변경 이력 (증액/감액). [Grain: MBER_NO × CHG_DE × SER_NO (1행=1금액변경)]. [주의: 약정금액 증감 이력 추적]. [원천: CRM → BRONZE_CRM.TM_MM_FDRM_MBER_IRSD].",
    "CRM_MEMBER_DISCONTINUE": "후원 중단 사건 이력. [Grain: MBER_NO × SPNSR_DSCNTC_DE × SPNSR_NO (1행=1중단사건)]. [주의: 중단사유 및 중단채널 관리]. [원천: CRM → BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_DSCNTC].",
    "CRM_MEMBER_RESPONSOR": "재후원 사건 이력. [Grain: MBER_NO × RSPNSR_DE (1행=1재후원)]. [주의: 중단 후 재후원 전이 관리]. [원천: CRM → BRONZE_CRM.TM_MM_FDRM_MBER_RSPNSR].",
    "CRM_MEMBER_SPONSOR_BIZ": "회원×후원사업 약정 관계. [Grain: MBER_NO × SPNSR_BSNS_ID (1행=1약정관계)]. [주의: 회원과 후원사업 간 결합]. [원천: CRM → BRONZE_CRM.TM_MM_MBER_SPNSR_BSNS].",
    "CRM_SPONSOR_RELATION": "결연 아동 관계 마스터. [Grain: MBER_NO × CHLDRN_NO (1행=1결연)]. [주의: 결연 후원자와 아동 매핑]. [원천: CRM → BRONZE_CRM.TM_MM_CHLDRN_STLM_INFO].",
    "CRM_PAYMENT_BILLING": "납입 및 청구 통합 원장 (회비∪기부금). [Grain: MBER_NO × MBRFEE_MT × SPNSR_BSNS_ID × SETLE_CD (1행=1납입청구)]. [주의: 회비 납입결과(PAY_STAT_CD) 및 청구/납입액 관리]. [원천: CRM → BRONZE_CRM.TM_PM_MBRFEE_ACMSLT ∪ TM_PM_DNTN_DTLS].",
    "CRM_PAYMENT_METHOD": "회원별 결제수단 마스터. [Grain: MBER_NO × SETLE_CD (1행=1결제수단)]. [주의: CMS/카드 자동이체 등 수납방식 관리]. [원천: CRM → BRONZE_CRM.TM_PM_SETLE_MNG].",
    "CRM_CAMPAIGN": "캠페인 마스터 (비정규화 통합). [Grain: CMPGN_CD (1행=1캠페인)]. [주의: 카테고리/인입경로/국내해외/마케팅캠페인 속성 통합]. [원천: CRM → BRONZE_CRM.TM_CM_CMPGN_MNG].",
    "CRM_SPONSORSHIP": "후원사업 마스터. [Grain: SPNSR_BSNS_ID (1행=1후원사업)]. [주의: 정기/일시 사업구분 및 상위 사업분류]. [원천: CRM → BRONZE_CRM.TM_CM_SPNSR_BSNS_INFO].",
    "CRM_ORG": "조직/부서 마스터. [Grain: DEPT_ID (1행=1부서)]. [주의: 본부/지부 계층 및 실적부서 매핑]. [원천: CRM → BRONZE_CRM.TM_CM_DEPT_MNG].",
    "CRM_DEV_TARGET": "회원개발 부문 목표 마스터. [Grain: STDYY × STDR_MT × DEPT_ID × MBER_DVLP_DIV_CD (1행=1개발목표)]. [주의: 부서별 월별 신규/증액/재후원 목표치]. [원천: CRM → BRONZE_CRM.TM_CM_MBER_DVLP_GOAL].",
    "CRM_SEND_REQUEST": "메시지 발송 요청 마스터. [Grain: SNDNG_REQ_NO (1행=1발송요청)]. [주의: 발송채널 및 대/중/소 발송구분 보유]. [원천: CRM → BRONZE_CRM.TM_MS_EMAIL/MSG/PSTMTR_SNDNG].",
    "CRM_SEND_MEMBER": "메시지 발송 대상 회원 상세. [Grain: SNDNG_REQ_NO × MBER_NO (1행=1발송회원)]. [주의: 수신자별 발송결과 및 오픈일시 관리]. [원천: CRM → BRONZE_CRM.TD_MS_*_DTLS].",
    "CRM_SEND_RESULT": "메시지 발송 채널별 성과 집계. [Grain: SNDNG_REQ_NO × SNDNG_RST_CD (1행=1발송성과)]. [주의: 발송 성공/실패 건수 집계]. [원천: CRM → BRONZE_CRM.TD_MS_*_LQY_SNDNG].",
    "CRM_EVENT": "행사/이벤트 마스터. [Grain: EVENT_KEY (1행=1행사)]. [주의: 일반행사 및 캠페인행사 통합]. [원천: CRM → BRONZE_CRM.TM_MS_EVENT ∪ TM_MS_CRMN].",
    "CRM_EVENT_PARTICIPATION": "행사 참여자 상세. [Grain: EVENT_KEY × MBER_NO (1행=1참여)]. [주의: 신청/취소/참석 상태 및 납입금액 관리]. [원천: CRM → BRONZE_CRM.TD_MS_EVENT_PRTCPNT_DTL ∪ TD_MS_CRMN_PRTCPNT].",
    "CRM_RELATION_ACTIVITY": "결연 활동 내역 (서신∪선물금). [Grain: ACTV_NO (1행=1활동)]. [주의: 서신교환 및 선물금 전달 이력]. [원천: CRM → BRONZE_CRM.TM_MM_LTR_EXCHG ∪ TM_MM_GIFT_DLVRY].",
    "CRM_CODE": "공통 코드 사전 마스터. [Grain: CD_ID × DTL_CD_ID (1행=1코드값)]. [주의: 코드그룹별 상세코드 및 한글 라벨 매핑]. [원천: CRM → BRONZE_CRM.TM_CM_CODE_DTL].",
    "ERP_BUDGET_ITEM": "예산 계정과목 마스터. [Grain: BDGT_ITEM_CD (1행=1예산과목)]. [주의: 장/관/항/목/세목/세세목 계층 매핑]. [원천: ERP → BRONZE_ERP.BDGT_ACMSLT_LEDGER].",
    "ERP_BUDGET": "월별 예산 편성 및 집행 원장. [Grain: BDGT_ITEM_CD × DEPT_ID × MONTH_KEY (1행=1월예산)]. [주의: 12개월 wide 컬럼을 월 long으로 언피벗]. [원천: ERP → BRONZE_ERP.BDGT_ACMSLT_LEDGER].",
    "ERP_BUDGET_YEARLY": "연도별 예산 총액 원장. [Grain: BDGT_ITEM_CD × DEPT_ID × YEAR (1행=1연예산)]. [주의: 연 총액 편성/집행액 관리]. [원천: ERP → BRONZE_ERP.BDGT_ACMSLT_LEDGER].",
    "CRM_MEMBER_SPONSOR_SPAN": "회원×후원사업 활동구간 마스터. [Grain: MBER_NO × SPNSR_BSNS_NO (1행=1활동구간)]. [주의: 시작월~중단월 기반 활동회원 as-of 판정]. [원천: CRM → BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT/SPNSR_DSCNTC].",
    "CRM_BIZ_TARGET": "사업/프로젝트 목표 마스터. [Grain: STDYY × STDR_MT × DEPT_ID × SPNSR_BSNS_ID (1행=1사업목표)]. [주의: 원천 미입고 시 스키마 전용 0행 유지(E-6)]. [원천: CRM → 신규 목표 테이블 입고 대기].",
    "AGENCY_AD_CREATIVE": "광고 소재/매체 통합 차원. [Grain: MEDIA_NM × PLATFORM_NM × CREATIVE_NM (1행=1소재)]. [주의: 디지털/비디오/재방송 3소스 소재 결합]. [원천: AGENCY 3소스 → BRONZE_AGENCY].",
    "AGENCY_AD_PERFORMANCE": "광고 성과 통합 원장. [Grain: AD_PERF_DK (1행=1광고성과)]. [주의: 디지털/방송 3원천 성과 지표 통합]. [원천: AGENCY 3소스 → BRONZE_AGENCY].",
    "AGENCY_AD_ROW_DGT": "디지털 광고 원천 무손실 Staging. [Grain: AD_PERF_DK (1행=1디지털광고)]. [주의: 디지털 광고 원천 36컬럼 보존]. [원천: AGENCY → BRONZE_AGENCY.DGT_AD_CMPGN_DTLS].",
    "AGENCY_AD_ROW_VIDEO": "비디오 방송 광고 원천 무손실 Staging. [Grain: AD_PERF_DK (1행=1비디오광고)]. [주의: 방송 광고 원천 32컬럼 보존]. [원천: AGENCY → BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS].",
    "AGENCY_AD_ROW_REBRDC": "재방송 광고 원천 무손실 Staging. [Grain: AD_PERF_DK (1행=1재방송광고)]. [주의: 재방송 광고 원천 34컬럼 보존]. [원천: AGENCY → BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS].",
    "AGENCY_AD_DIGITAL": "디지털 광고 고유속성 위성. [Grain: AD_PERF_DK (코어 1:1)]. [주의: 매체사 산정 CTR/CVR/CPC 비율 지표]. [원천: AGENCY → BRONZE_AGENCY.DGT_AD_CMPGN_DTLS].",
    "AGENCY_AD_BROADCAST": "방송 광고 고유속성 위성. [Grain: AD_PERF_DK (코어 1:1)]. [주의: 시청률/송출시간/SPOT구분 방송 속성]. [원천: AGENCY → BRONZE_AGENCY.VIDEO/REBRDC_AD_CMPGN_DTLS].",
    "AGENCY_AD_BROADCAST_CASE": "재방송 사례 정규화 언피벗 위성. [Grain: AD_PERF_DK × CASE_SEQ (1행=1사례)]. [주의: 반복군 15컬럼을 언피벗 정규화]. [원천: AGENCY → BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS].",
    "BIGQUERY_BASIC": "GA4 웹/앱 이벤트 기본 Staging. [Grain: EVENT_DT × EVENT_SEQ (1행=1이벤트)]. [주의: 12컬럼 DDL 타입 캐스팅 정제]. [원천: GA4 → BRONZE_BIGQUERY.EVENTS].",
    "BIGQUERY_TRAFFIC_SOURCE": "GA4 트래픽 소스 차원. [Grain: SOURCE × MEDIUM × CAMPAIGN (1행=1소스)]. [주의: 세션 획득 채널 분류]. [원천: GA4 → BRONZE_BIGQUERY.EVENTS].",
    "BIGQUERY_EVENT_DIM": "GA4 이벤트 분류 차원. [Grain: EVENT_NAME × PARAM_NAME (1행=1이벤트분류)]. [주의: 주요 웹/앱 이벤트 정의]. [원천: GA4 → BRONZE_BIGQUERY.EVENTS].",
    "BIGQUERY_DEVICE": "GA4 디바이스 차원. [Grain: DEVICE_CATEGORY × OPERATING_SYSTEM (1행=1디바이스)]. [주의: 접속 기기 및 OS 분류]. [원천: GA4 → BRONZE_BIGQUERY.EVENTS].",
    "BIGQUERY_EVENT": "GA4 사용자 행동 팩트 소스. [Grain: EVENT_DT × EVENT_SEQ (1행=1이벤트)]. [주의: 체류시간/스크롤/이탈률 행동 지표]. [원천: GA4 → BRONZE_BIGQUERY.EVENTS].",
    "BIGQUERY_IDENTITY": "GA4 사용자 신원 차원. [Grain: USER_PSEUDO_ID × ID_SCHEME (1행=1사용자)]. [주의: GA 쿠키 식별자와 CRM 회원 매핑]. [원천: GA4 → BRONZE_BIGQUERY.EVENTS].",
    "IDENTITY_MEMBER_XREF": "온-오프라인 신원 연계 브릿지. [Grain: USER_PSEUDO_ID × MEMBER_DK (1행=1연계)]. [주의: GA4 사용자 식별자와 CRM 회원번호 연결]. [원천: GA4/CRM → SILVER.BIGQUERY_IDENTITY].",
    "CRM_MARKETING_CAMPAIGN": "마케팅 캠페인 마스터. [Grain: MKTG_CAMPAIGN_BK (1행=1마케팅캠페인)]. [주의: AGENCY(광고)와 CRM(개발)을 잇는 Conformed 축]. [원천: CRM → BRONZE_CRM.TM_CM_MKTNG_CMPGN_INFO].",
    "CRM_CAMPAIGN_SPONSOR_BIZ_BRIDGE": "캠페인 ↔ 후원사업 다대다(1:N) 브릿지. [Grain: CMPGN_CD × SPNSR_BSNS_ID (1행=1매핑)]. [주의: 캠페인별 복수 후원사업 귀속 해소]. [원천: CRM → BRONZE_CRM.TM_CM_CMPGN_SPNSR_BSNS]."
}

SV_COMMENTS = {
    "SV_MEMBER_MONTHLY": "회원 월별 스냅샷 지표 분석 (base: GOLD.FACT_MEMBER_MONTHLY). [Grain: 월 × 회원]. [활성 지표: 회비/청구/미납/개발/중단]. [주의: 집계필요 배분규칙필요 형제팩트중복 앵커_경합 이중계상 방지]. [원천: CRM → BRONZE_CRM → SILVER.CRM_PAYMENT_BILLING ∪ CRM_MEMBER_DEV/DISCONTINUE → GOLD.FACT_MEMBER_MONTHLY].",
    "SV_MEMBER_EVENT": "회원 생애주기 상태전이 사건 분석 (base: GOLD.FACT_MEMBER_LIFECYCLE). [Grain: 사건일 × 회원 × 전이유형]. [활성 지표: 개발(신규/증액/재후원)/중단 건수·금액]. [주의: 집계필요 배분규칙필요 앵커_경합 방지]. [원천: CRM → BRONZE_CRM → SILVER.CRM_MEMBER_DEV ∪ CRM_MEMBER_DISCONTINUE → GOLD.FACT_MEMBER_LIFECYCLE].",
    "SV_MEMBER_COHORT": "회원 획득 코호트 및 캠페인별 12개월 고정 이탈률 분석 (base: GOLD.FACT_MEMBER_COHORT). [Grain: MEMBER_DK (1행=1회원)]. [활성 지표: 12개월 이탈률/유지기간/코호트]. [주의: 개발이력 보유 회원 한정(미보유 중단회원은 SV_MEMBER_EVENT 사용)]. [원천: GOLD.FACT_MEMBER_LIFECYCLE → FACT_MEMBER_COHORT].",
    "SV_SERVICE": "메시지 발송 성과 및 고객 접점 서비스 분석 (base: GOLD.FACT_MESSAGE_DISPATCH). [Grain: 발송일 × 회원 × 서비스 × 캠페인]. [활성 지표: 발송/성공/실패/오픈수, WIDE_GA_BEHAVIOR]. [주의: 배분규칙필요 앵커_경합 방지]. [원천: CRM → BRONZE_CRM → SILVER.CRM_SEND_MEMBER/REQUEST → GOLD.FACT_MESSAGE_DISPATCH].",
    "SV_EVENT_PARTICIPATION": "행사/이벤트 신청 및 참석 성과 분석 (base: GOLD.FACT_EVENT_ATTENDANCE). [Grain: 행사일 × 회원 × 행사]. [활성 지표: 모집/신청/대기/취소/참석 인원수]. [주의: 일반/캠페인 행사별 상태코드 구분 집계]. [원천: CRM → BRONZE_CRM → SILVER.CRM_EVENT_PARTICIPATION → GOLD.FACT_EVENT_ATTENDANCE].",
    "SV_BUDGET": "예산 편성 및 집행 실적 분석 (base: GOLD.FACT_BUDGET). [Grain: 월 × 부서 × 예산과목]. [활성 지표: 편성예산/집행예산/집행률(%)]. [주의: 연 총액은 SV_BUDGET_YEARLY 사용(월 집행액과 합산 금지)]. [원천: ERP → BRONZE_ERP → SILVER.ERP_BUDGET → GOLD.FACT_BUDGET].",
    "SV_AD": "온-오프라인 광고 성과 통합 분석 (base: GOLD.WIDE_AD_COMBINED). [Grain: 집행일 × 캠페인 × 소재 × 디바이스]. [활성 지표: 광고비/노출/클릭/전환/CTR/CVR/CPC/CPM/ROAS]. [주의: _SRC 접미 비율 지표 단순 재합산 금지]. [원천: AGENCY 3소스 + GA4 → SILVER.AGENCY_AD_* → GOLD.WIDE_AD_COMBINED].",
    "SV_DEV_ACHIEVEMENT": "회원개발 부문 목표 대비 실적 달성률 분석 (base: GOLD.FACT_MEMBER_DEV_ACHIEVEMENT). [Grain: 월 × 부서 × 개발구분]. [활성 지표: 월/연 목표건수, 실적건수, 달성률(%)]. [주의: 앵커_경합 방지, 달성률은 GOAL_CNT>0 스코프 필수]. [원천: GOLD.FACT_TARGET_MEMBER_DEV × FACT_MEMBER_LIFECYCLE].",
    "SV_MEMBER_FEE": "회비 세부 분해 및 납입/미납 정밀 분석 (base: GOLD.WIDE_MEMBER_FEE). [Grain: 회원 × 회비월 × 사업 × 납입방식 × 결제수단]. [활성 지표: 청구액/납입액/미납액/수납률(%)]. [주의: 배분규칙필요 형제팩트중복 앵커_경합 이중계상 방지(SV_MEMBER_MONTHLY와 합산 금지)]. [원천: CRM → SILVER.CRM_PAYMENT_BILLING → GOLD.FACT_MEMBER_FEE].",
    "SV_MEMBER_SPONSOR_BIZ": "회원×후원약정 기간 및 캠페인/사업별 활동회원 분석 (base: GOLD.FACT_MEMBER_SPONSORSHIP_SPAN). [Grain: 회원 × 후원약정번호]. [활성 지표: 약정 활동회원수]. [주의: 전체 활동회원수 정본은 SV_MEMBER_MONTHLY 사용]. [원천: CRM → SILVER.CRM_MEMBER_SPONSOR_SPAN → GOLD.FACT_MEMBER_SPONSORSHIP_SPAN].",
    "SV_ML_MEMBER_RISK": "회원 단위 ML 예측 분석 (중단·증액·충성) (base: SERVING.ML_MEMBER_RISK_V). [Grain: 기준월 × 회원]. [활성 지표: 중단확률/증액확률/충성도스코어]. [주의: 예측치이며 실적 아님, 기준월별 독립 산출(합산 금지)]. [원천: ML 예측 결과 3종 → SERVING.ML_MEMBER_RISK_V].",
    "SV_ML_SPONSOR_RISK": "후원계좌 단위 이탈 예측 분석 (base: SERVING.ML_SPONSOR_RISK_V). [Grain: 기준월 × 회원 × 후원사업 × 약정번호]. [활성 지표: 후원계좌 이탈확률]. [주의: 1회원 다수 약정 보유(회원수는 COUNT DISTINCT 집계)]. [원천: ML 이탈모델 → SERVING.ML_SPONSOR_RISK_V].",
    "SV_ML_DVLP_FORECAST": "개발금액 시계열 예측 5계열 분석 (base: SERVING.ML_DVLP_FORECAST_V). [Grain: 기준월 × 계열유형 × 계열 × 예측월]. [활성 지표: 예측 개발금액(만원)]. [주의: 단위=만원, 계열유형 간 단순 합산 금지(독립 예측)]. [원천: ML 시계열모델 5종 → SERVING.ML_DVLP_FORECAST_V].",
    "SV_ML_FEE_FORECAST": "캠페인 카테고리별 회비 예측 분석 (base: SERVING.ML_FEE_FORECAST_V). [Grain: 기준월 × 캠페인카테고리 × 예측월]. [활성 지표: 예측 회비금액(원)]. [주의: 단위=원, 개발금액(만원)과 단위 상이(합산 금지)]. [원천: ML 회비예측모델 → SERVING.ML_FEE_FORECAST_V].",
    "SV_ML_LTV_FORECAST": "캠페인 LTV 월별 시계열 예측 분석 (base: SERVING.ML_LTV_FORECAST_V). [Grain: 기준월 × LTV유형 × 계열 × 예측월]. [활성 지표: 예측 LTV 금액]. [주의: 상위캠페인 회원평균 LTV와 캠페인 후원총액 LTV 분리]. [원천: ML LTV모델 2종 → SERVING.ML_LTV_FORECAST_V].",
    "SV_ML_LTV_SCORE": "캠페인 단위 LTV 총 스코어 분석 (base: SERVING.ML_LTV_SCORE_V). [Grain: 기준월 × LTV유형 × 계열]. [활성 지표: LTV 종합 점수]. [주의: 월별 예측(SV_ML_LTV_FORECAST)과 Grain 상이]. [원천: ML LTV스코어모델 → SERVING.ML_LTV_SCORE_V].",
    "SV_ML_FEATURE_IMPORTANCE": "머신러닝 피처 중요도 분석 (base: SERVING.ML_FEATURE_IMPORTANCE_V). [Grain: 기준월 × 분석유형 × 피처]. [활성 지표: 피처별 기여도(0~1)]. [주의: 모델 해석용 지표(분석유형 내 합계=1), 업무 실적치 아님]. [원천: ML 피처중요도모델 → SERVING.ML_FEATURE_IMPORTANCE_V]."
}