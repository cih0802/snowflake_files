------------------------------------------------------
-- 3.7 Agent 생성
-- Cortex Agent: 7개 Semantic View를 tool로 연결
------------------------------------------------------
USE ROLE GN_DW_ADMIN;

CREATE OR REPLACE AGENT GN_DW.GOLD.GN_DW_AGENT
  COMMENT = '굿네이버스 DW 분석 Agent - 납입/회원/광고/마케팅 통합 분석'
  FROM SPECIFICATION
$$
models:
  orchestration: auto

orchestration:
  budget:
    seconds: 60
    tokens: 32000

instructions:
  response: "한국어로 답변하세요. 간결하고 정확한 데이터 분석 결과를 제공합니다."
  orchestration: "납입/회비 관련은 payment_analyst, 회원 개발은 member_dev_analyst, 회원 생애주기는 lifecycle_analyst, 광고 성과는 ad_platform_analyst, 웹/앱 분석은 web_app_analyst, 마케팅 발송은 messaging_analyst, 회원 여정은 journey_analyst 도구를 사용하세요."
  sample_questions:
    - question: "2025년 상위캠페인별 납입회비금액을 분석해줘"
    - question: "2025년 중단사유별 중단회원수는?"
    - question: "2025년 상위캠페인별 신규 개발건수는?"
    - question: "발송유형별 전환율과 평균전환소요일은?"
    - question: "2025년 매체별 광고효율(노출/클릭/CPC)은?"
    - question: "상위캠페인별 회원수, 평균발송수, 증액율, 중단율은?"

tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "payment_analyst"
      description: "납입이력 분석. 캠페인별 납입금액, 미납비중, 평균회비, 회원특성 연계 분석."
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "lifecycle_analyst"
      description: "회원 생애주기 분석. 가입→납입→중단 흐름, 유지율, 중단사유."
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "member_dev_analyst"
      description: "회원 개발 분석. 신규/재후원/증액, 캠페인별 개발 실적."
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "messaging_analyst"
      description: "마케팅 메시징 분석. SMS/알림톡/이메일 발송 성과."
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "ad_platform_analyst"
      description: "광고 플랫폼 성과 분석. 디지털 대행사 광고, GA 잠재고객, 메타(Google/Meta). 노출/클릭/CTR/CPC."
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "web_app_analyst"
      description: "웹/앱 방문 분석. GA 세션, 페이지뷰, 이벤트, PC/모바일/앱 분리."
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "journey_analyst"
      description: "회원 여정 통합 분석. 광고 노출→사이트 방문→가입→납입 전체 여정."
  - tool_spec:
      type: "data_to_chart"
      name: "data_to_chart"
      description: "데이터 시각화 생성."

tool_resources:
  payment_analyst:
    semantic_view: "GN_DW.GOLD.SV_PAYMENT_ANALYSIS"
  lifecycle_analyst:
    semantic_view: "GN_DW.GOLD.SV_MEMBER_LIFECYCLE"
  member_dev_analyst:
    semantic_view: "GN_DW.GOLD.SV_MEMBER_DEVELOPMENT"
  messaging_analyst:
    semantic_view: "GN_DW.GOLD.SV_MARKETING_MESSAGING"
  ad_platform_analyst:
    semantic_view: "GN_DW.GOLD.SV_AD_PLATFORM"
  web_app_analyst:
    semantic_view: "GN_DW.GOLD.SV_WEB_APP_ANALYTICS"
  journey_analyst:
    semantic_view: "GN_DW.GOLD.SV_MEMBER_JOURNEY"
$$;
