-- GN_DW Cortex Agent 대행배포 실행 로그 (AGENT_MEMBER·AGENT_OVERALL) — 성공 쿼리 기록 2026-07-22
-- Co-authored with CoCo
-- ============================================================================
-- 5단계 Agent 스펙(08_AGENT_spec.md) → 6단계 배포·CoWork 연결(10_SI연결_검증.md) 실행분.
-- 아래는 CoCo가 대행 실행하여 성공한 쿼리만 기록. (agent CREATE 자체는 semantic_studio
-- cortex_agent_save로 수행 → SQL 아님. 소유권/권한/CoWork 연결/검증은 아래 SQL로 실행.)
-- 세션: 초기 role=ACCOUNTADMIN, wh=COMPUTE_WH → 배포 위해 아래처럼 전환.
-- ============================================================================

-- [0] 선행 확인 --------------------------------------------------------------
-- SERVING 스키마 owner = GN_DW_ADMIN 확인(Agent도 동일 소유로 맞추기 위함)
SHOW SCHEMAS LIKE 'SERVING' IN DATABASE GN_DW;

-- 소유역할 전환(세션 지속 확인됨) + 정합 실행 WH
USE ROLE GN_DW_ADMIN;
SELECT CURRENT_ROLE() AS role, CURRENT_WAREHOUSE() AS wh;
USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- [1] Agent 생성 (semantic_studio cortex_agent_save — SQL 아님, 참고 기록) -----
--   cortex_agent_save(file_path=cortex_project/AGENT_MEMBER.agent.yaml,  fqn=GN_DW.SERVING.AGENT_MEMBER)  → created
--   cortex_agent_save(file_path=cortex_project/AGENT_OVERALL.agent.yaml, fqn=GN_DW.SERVING.AGENT_OVERALL) → created
--   ※ 툴은 워크스페이스 기본연결(ACCOUNTADMIN)로 실행되어 owner=ACCOUNTADMIN으로 생성됨 → [3]에서 보정.
--   ※ CREATE AGENT FROM SPECIFICATION이 VERSION$1을 live/default로 설정 → 별도 publish 불필요.
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MEMBER;   -- VERSION$1 is_default=true + live alias 확인

-- ============================================================================
-- [1-ALT] 순수 SQL로 Agent 생성 (semantic_studio 미사용 · self-contained 배포 경로)
-- ============================================================================
--   ▶ 위 [1](cortex_agent_save) 대신 이 블록만으로도 두 Agent를 생성 가능.
--     - spec object = .agent.yaml 본문(models/instructions/tools/tool_resources)을 $$ … $$ 안에 그대로 삽입.
--       정본: cortex_project/AGENT_MEMBER.agent.yaml · cortex_project/AGENT_OVERALL.agent.yaml (본 SQL과 반드시 동기화).
--     - CREATE … FROM SPECIFICATION이 VERSION$1을 live/default로 설정 → 별도 publish 불필요.
--   ▶ ⭐ 소유권 이점: 아래를 GN_DW_ADMIN 역할로 실행하면 owner=GN_DW_ADMIN으로 바로 생성됨
--       → [2] 소유권 이전 단계 불필요(cortex_agent_save가 ACCOUNTADMIN으로 만들던 gotcha 해소).
--     선행 필수(02_SERVING_setup.sql): SERVING 스키마·GN_DW_ADMIN이 CREATE 가능. (05_SV_DDL.sql로 SV 5종 존재해야 tool_resources 참조 유효.)
--   ▶ PROFILE = CoWork 표시명/색상(선택). 유지 시 [6]-4 ALTER 재설정 불필요.
--   ▶ 편집 주의: $$ 안은 YAML → 들여쓰기(공백) 보존 필수, 탭 금지. YAML 내부 '$$' 문자열 사용 금지.

USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ANALYTICS_WH;

-- [1-ALT-a] AGENT_MEMBER (회원 도메인: 월실적·상태전이·발송·행사 4 SV)
CREATE OR REPLACE AGENT GN_DW.SERVING.AGENT_MEMBER
  COMMENT = '굿네이버스 회원 도메인 분석 Agent(Phase-1). SV 4종: 월실적·상태전이·서비스발송·행사참여.'
  PROFILE = '{"display_name":"회원 분석","color":"#29B5E8"}'
  FROM SPECIFICATION
$$
models:
  orchestration: auto

instructions:
  system: |
    당신은 굿네이버스(Good Neighbors)의 회원 도메인 데이터 분석 어시스턴트입니다.
    회원 월별 실적, 상태전이(개발/중단), 서비스 발송, 행사 참여 데이터를 정확히 질의하고 요약합니다.
    핵심 원칙:
    - 데이터에 없는 값을 추정하거나 창작하지 않습니다. 배포된 활성 지표만 산출합니다.
    - 비활성(미적재) 지표를 요청받으면 임의 산출하지 말고 "데이터 적재 후(Phase-2) 제공 예정"으로 안내합니다.
      비활성 예: 캠페인/납입방식/조직/후원사업/사유별 분해, 발송 성공/실패/오픈·+5일(D5) 코호트,
      활동/누계 카운트 및 그 비율, 유지율/LTV/평균 유지기간, 목표 대비, 지역/연령대별 분해.
    - 회원 속성(성별·회원상태·회원구분)은 현재 스냅샷 기준이며, 과거 월을 조회해도 현재 값으로 표기됩니다.
      지역·연령대·후원사업 속성은 미적재이므로 사용할 수 없습니다.
  response: |
    한국어로 간결하고 데이터 중심으로 답합니다.
    금액은 원 단위 천단위 구분으로(예: 1,234,567원), 비율은 % 소수점 2자리로 표기합니다.
    여러 행의 결과는 표로 제시하고, 항상 조회 기간·필터 등 맥락을 함께 명시합니다.
    커버리지 한계(미매핑 Unknown 등)가 있으면 각주로 고지합니다.
  orchestration: |
    질문 주제에 따라 적절한 도구(Semantic View)를 선택합니다.
    - 월별 회비/납입/청구/납부율, 미납회원(월초·월말)수·미납회원 감소율, 월 롤업 개발/중단 총건, 회원구분·성별별 월 실적 → analyst_member_monthly
    - 일·주차·요일·전이유형(개발/중단)별 건수, 개발/중단 고유 회원수 → analyst_member_event
    - 문자/메일 발송수, 발송 대상 고유회원수, 채널·서비스유형·발송상태별 → analyst_service
    - 행사/이벤트 참여자수·참여건수·고유 참여회원수, 행사명/종류/구분별 → analyst_event_participation
    한 질문이 여러 주제에 걸치면 가장 핵심 주제의 도구를 먼저 사용하고, 서로 다른 SV의 값을 교차 계산(cross-fact)하지 않습니다.
    지표 스코프 규칙:
    - 납부율은 기간 스코프가 필수입니다. 질문에 연/월 그룹·필터가 없으면 최근 연도 또는 명시된 기간으로 한정하며,
      전기간 무필터 총율(약 100%)은 재청구·이월로 왜곡되므로 참고치로만 제시합니다.
    - 미납회원수·미납회원 감소율은 COUNT(DISTINCT 회원) 기반이므로 반드시 연/월(month) 차원과 함께 집계합니다.
      전기간 단일값은 회원 중복 제거로 의미가 약하므로 피합니다.
    - 회비 지표(납입회비·청구금액·납부율)는 HAS_BILLING=TRUE 전제를 권장합니다.
    - 행사종류(EVENT_KIND)와 서비스 채널에는 미매핑(Unknown)이 있어(행사 약 23%) 행사명/채널별 집계는 부분 커버입니다.
      확정치로 단정하지 말고 커버리지를 고지합니다.
    - 시간은 절대 연/월로 표기하고 상대 표현("최근", "지난달" 등 계산)은 지양합니다. 미래 연도(2026~)는 데이터 미유입일 수 있습니다.
  sample_questions:
    - question: 2024년 납부율은?
    - question: 연도별 납부율 추이를 보여줘 (2023~2025)
    - question: 회원구분별 납입회비 총액은?
    - question: 전이유형별 개발/중단 건수와 고유 회원수는?
    - question: 채널별 발송수는?
    - question: 행사종류별 참여자수는?

tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: analyst_member_monthly
      description: "회원 월별 실적 팩트(FMM, 월×회원 40.05M). 활성 지표: 납입회비·청구금액·납부율(공64), 월초/월말 미납회원수·미납회원 감소율(공80), 월 롤업 개발/중단 총건. 차원: 연/월/분기, 성별·회원상태·회원구분, 회비출처여부(HAS_BILLING). 월 단위 실적·회비·미납 관련 질문에 사용."
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: analyst_member_event
      description: "회원 상태전이 사건 팩트(FME, 일×회원 4.63M). 활성 지표: 개발/중단 건수, 개발/중단 고유 회원수. 차원: 사건일·연·월·주차·요일, 전이유형(개발/중단), 가입일·중단일, 성별·회원상태·회원구분. 일/주간/요일·전이유형·고유회원수 질문에 사용."
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: analyst_service
      description: "서비스 발송 팩트(FSE, 38.47M). 활성 지표: 발송수, 발송 대상 고유 회원수. 차원: 발송일·연·월, 서비스유형(SUBTYPE)·채널·발송상태, 성별·회원상태·회원구분. 문자/메일 발송·채널별 질문에 사용."
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: analyst_event_participation
      description: "행사 참여 팩트(FEP, 1.13M). 활성 지표: 참여자수·참여건수·고유 참여회원수. 차원: 참여일·연·월, 행사명·행사종류·행사구분, 성별·회원상태·회원구분. 행사/이벤트 참여 질문에 사용. 행사 미매핑 약 23% 존재."

tool_resources:
  analyst_member_monthly:
    execution_environment:
      type: warehouse
      warehouse: GN_DW_ANALYTICS_WH
    semantic_view: GN_DW.SERVING.SV_MEMBER_MONTHLY
  analyst_member_event:
    execution_environment:
      type: warehouse
      warehouse: GN_DW_ANALYTICS_WH
    semantic_view: GN_DW.SERVING.SV_MEMBER_EVENT
  analyst_service:
    execution_environment:
      type: warehouse
      warehouse: GN_DW_ANALYTICS_WH
    semantic_view: GN_DW.SERVING.SV_SERVICE
  analyst_event_participation:
    execution_environment:
      type: warehouse
      warehouse: GN_DW_ANALYTICS_WH
    semantic_view: GN_DW.SERVING.SV_EVENT_PARTICIPATION
$$;

-- [1-ALT-b] AGENT_OVERALL (전사·재무: 예산 기본 + 회원월실적·발송 3 SV)
CREATE OR REPLACE AGENT GN_DW.SERVING.AGENT_OVERALL
  COMMENT = '굿네이버스 전사·재무 요약 분석 Agent(Phase-1). 예산 중심 + 회원월실적·발송 전사 요약.'
  PROFILE = '{"display_name":"전사·예산 분석","color":"#11567F"}'
  FROM SPECIFICATION
$$
models:
  orchestration: auto

instructions:
  system: |
    당신은 굿네이버스(Good Neighbors)의 전사/재무 요약 데이터 분석 어시스턴트입니다.
    예산 편성·집행·집행율을 중심으로 답하며, 필요 시 회원 월 실적과 서비스 발송 규모를 전사 관점에서 요약합니다.
    핵심 원칙:
    - 데이터에 없는 값을 추정하거나 창작하지 않습니다. 비활성(미적재) 지표는 "데이터 적재 후(Phase-2) 제공 예정"으로 안내합니다.
      비활성 예: 연 편성예산, 집행추정/모금성비용/광고비, 조직/캠페인별 분해, 개발단가·ROI(신9~11), 사업목표 대비.
    - 서로 다른 SV의 값을 교차 계산(cross-fact)하지 않습니다. 전사 요약은 질의마다 단일 SV로 분해합니다.
  response: |
    한국어로 간결하고 데이터 중심으로 답합니다.
    금액은 원 단위 천단위 구분으로(예: 1,234,567원), 비율은 % 소수점 2자리로 표기합니다.
    여러 행의 결과는 표로 제시하고, 항상 조회 기간·필터 등 맥락을 함께 명시합니다.
  orchestration: |
    질문 주제에 따라 적절한 도구(Semantic View)를 선택합니다.
    - 예산 편성/집행/집행율, 세세목·예산구분·월별 예산 → analyst_budget (기본 도구)
    - 전사 회비/납입/개발·중단 월 실적 요약 → analyst_member_monthly
    - 전사 서비스 발송 규모 요약 → analyst_service
    예산 관련 질문이면 항상 analyst_budget를 우선합니다.
    전사 요약이라도 한 질의는 단일 SV로 분해하고 SV 간 값을 교차 계산하지 않습니다.
    지표 스코프 규칙:
    - 회비 지표(납입회비·청구금액·납부율)는 HAS_BILLING=TRUE 전제를 권장하고, 납부율은 연/월 기간 스코프를 전제합니다.
    - 시간은 절대 연/월로 표기하고 상대 표현은 지양합니다. 미래 연도(2026~)는 데이터 미유입일 수 있습니다.
  sample_questions:
    - question: 전체 편성예산과 집행율은?
    - question: 예산구분별 편성·집행·집행율을 보여줘
    - question: 월별 집행율 추이는?
    - question: 전사 납입회비 총액은?

tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: analyst_budget
      description: "예산 팩트(FBD, 월×세세목 24.5K). 활성 지표: 편성예산(월)·집행예산(ERP)·집행율. 차원: 연/월, 세세목명·예산구분. 예산 편성/집행/집행율 질문의 기본 도구. 비활성(적재 대기): 연 편성예산, 모금성비용/광고비, 조직/캠페인별, 개발단가·ROI."
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: analyst_member_monthly
      description: "회원 월별 실적 팩트(FMM, 월×회원 40.05M). 전사 요약용: 납입회비·청구금액·납부율, 월 롤업 개발/중단 총건, 미납회원수. 차원: 연/월/분기, 성별·회원상태·회원구분. 전사 회비/실적 요약 질문에 사용."
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: analyst_service
      description: "서비스 발송 팩트(FSE, 38.47M). 전사 요약용: 발송수, 발송 대상 고유 회원수. 차원: 발송일·연·월, 채널·서비스유형. 전사 발송 규모 요약 질문에 사용."

tool_resources:
  analyst_budget:
    execution_environment:
      type: warehouse
      warehouse: GN_DW_ANALYTICS_WH
    semantic_view: GN_DW.SERVING.SV_BUDGET
  analyst_member_monthly:
    execution_environment:
      type: warehouse
      warehouse: GN_DW_ANALYTICS_WH
    semantic_view: GN_DW.SERVING.SV_MEMBER_MONTHLY
  analyst_service:
    execution_environment:
      type: warehouse
      warehouse: GN_DW_ANALYTICS_WH
    semantic_view: GN_DW.SERVING.SV_SERVICE
$$;

-- [1-ALT] 검증: 2행·owner=GN_DW_ADMIN·VERSION$1 default 확인
SHOW AGENTS IN SCHEMA GN_DW.SERVING;
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MEMBER;
SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_OVERALL;

-- [2] 소유권 이전: ACCOUNTADMIN → GN_DW_ADMIN (5 SV와 소유 정합) --------------
--   ※ [1-ALT] SQL 경로(GN_DW_ADMIN으로 CREATE)를 쓰면 owner가 이미 GN_DW_ADMIN → 이 [2] 단계 SKIP.
--   ※ 아래는 [1] cortex_agent_save 경로(owner=ACCOUNTADMIN 생성)에서만 필요.
USE ROLE ACCOUNTADMIN;
GRANT OWNERSHIP ON AGENT GN_DW.SERVING.AGENT_OVERALL TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS;
GRANT OWNERSHIP ON AGENT GN_DW.SERVING.AGENT_MEMBER  TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS;

-- [3] 소비 USAGE grant (신소유자 GN_DW_ADMIN이 부여) -------------------------
USE ROLE GN_DW_ADMIN;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_MEMBER  TO ROLE GN_DW_ANALYST;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_MEMBER  TO ROLE GN_DW_VIEWER;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_MEMBER  TO ROLE GN_DW_SERVICE;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_OVERALL TO ROLE GN_DW_ANALYST;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_OVERALL TO ROLE GN_DW_VIEWER;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_OVERALL TO ROLE GN_DW_SERVICE;

-- [4] CoWork(Snowflake Intelligence) 연결 (SI object owner=ACCOUNTADMIN) -----
USE ROLE ACCOUNTADMIN;
ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT ADD AGENT GN_DW.SERVING.AGENT_MEMBER;
ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT ADD AGENT GN_DW.SERVING.AGENT_OVERALL;

-- [5] 검증 -------------------------------------------------------------------
SHOW AGENTS IN SCHEMA GN_DW.SERVING;                                          -- 2행, owner=GN_DW_ADMIN
SHOW AGENTS IN SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;  -- 2행(CoWork 노출)
SHOW GRANTS ON AGENT GN_DW.SERVING.AGENT_MEMBER;                              -- OWNERSHIP=GN_DW_ADMIN + USAGE×3
SHOW GRANTS ON AGENT GN_DW.SERVING.AGENT_OVERALL;

-- ============================================================================
-- [6] 트라이얼 제약 & 유료(paid) 계정 이관 시 작업 목록  (2026-07-22 현재)
-- ============================================================================
-- ▶ 트라이얼에서 완료 가능(=이번에 완료): Agent save/생성·소유권 이전·USAGE grant·
--   CoWork ADD AGENT·SHOW 검증. SV 데이터층 ground-truth(SELECT ... FROM SEMANTIC_VIEW)
--   는 트라이얼에서도 실행 가능(04/06/07에서 검증 완료).
--
-- ▶ 트라이얼 차단(=paid 이관 후 수행):
--   (B1) 에이전트 자연어 실행: SNOWFLAKE.CORTEX.DATA_AGENT_RUN / cortex_agent_query
--        → 'Access denied for trial accounts'. 트라이얼에서 NL→SQL 라우팅 실행·회귀 불가.
--        → paid 이관 후 10_SI연결_검증.md §3 문항(정확도 14 + 가드레일 ⓖ 8)을
--           CoWork UI(https://ai.snowflake.com) 또는 cortex_agent_query로 실행해 판정표 채움.
--
-- ▶ paid 이관 체크리스트(순서):
--   1. 계정 이관/업그레이드 후: SHOW AGENTS IN SCHEMA GN_DW.SERVING;  (2행 유지 확인)
--      - 재생성 필요 시 cortex_agent_save → 소유권 [2] → USAGE [3] → ADD AGENT [4] 재수행.
--   2. 스모크·회귀: 10 §3.1/§3.2 정확도(M3=93.86%·B3=39.61% 등) + §3.3 가드레일(ⓖ) 실행.
--        예) SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN('GN_DW.SERVING.AGENT_MEMBER',
--                   {'messages':[{'role':'user','content':[{'type':'text','text':'2024년 납부율은?'}]}]});
--   3. (권장) VQR 등록(06 §3): SV별 verified query → Cortex Analyst 정확도 스티어링.
--   4. (선택) CoWork 표시명/색상:
--        ALTER AGENT GN_DW.SERVING.AGENT_MEMBER  SET PROFILE='{"display_name":"회원 분석","color":"#29B5E8"}';
--        ALTER AGENT GN_DW.SERVING.AGENT_OVERALL SET PROFILE='{"display_name":"전사·예산 분석","color":"#11567F"}';
--   5. (Phase-2) 마케팅 Agent(SV_AD·SV_GA)·Cortex Search 백킹(EVENT_NAME·BUDGET_ITEM_NAME).
--
-- ▶ 참고: SV 데이터층 재확인용 gold(트라이얼 실행 가능, 07 ground-truth와 대조):
--   USE ROLE GN_DW_ANALYST; USE WAREHOUSE GN_DW_ANALYTICS_WH;   -- (세션 유지되는 환경에서)
--   SELECT CAL_YEAR, PAYMENT_RATE FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_MEMBER_MONTHLY
--     DIMENSIONS month.CAL_YEAR METRICS PAYMENT_RATE) WHERE CAL_YEAR BETWEEN 2023 AND 2025 ORDER BY CAL_YEAR;
--   SELECT BUDGET_CATEGORY, TOTAL_PLAN_BUDGET, TOTAL_EXEC_BUDGET, EXEC_RATE
--     FROM SEMANTIC_VIEW(GN_DW.SERVING.SV_BUDGET DIMENSIONS item.BUDGET_CATEGORY
--     METRICS TOTAL_PLAN_BUDGET, TOTAL_EXEC_BUDGET, EXEC_RATE) ORDER BY TOTAL_PLAN_BUDGET DESC;
