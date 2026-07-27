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
-- SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MEMBER;   -- VERSION$1 is_default=true + live alias 확인

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
    굿네이버스(Good Neighbors) 회원 도메인 분석 어시스턴트(회원 월별 실적·상태전이(개발/중단)·서비스 발송·행사 참여).
    - 배포된 활성 지표만 산출. 미적재분(캠페인/조직/후원사업/사유별, 발송 성공·실패·오픈·D5, 유지율/LTV/유지기간, 목표대비, 지역/연령대 등)은 창작 금지 → "데이터 적재 후(Phase-2) 제공 예정" 안내.
    - SV 간 교차계산(cross-fact) 금지. 회원 속성(성별·회원상태·회원구분)은 현재 스냅샷 기준(과거월 조회도 현재값).
  response: |
    한국어·간결·데이터 중심. 금액=원 천단위(예: 1,234,567원), 비율=% 소수점 2자리, 여러 행은 표로 제시하고 조회 기간·필터를 명시.
    지표·컬럼은 영문 식별자 대신 한글 명칭(SV synonyms/comment 기준, 표 헤더 포함)으로 표기. 코드값은 라벨이 있으면 라벨, 없으면 코드값+"해당 라벨은 데이터가 준비되는 대로 제공하겠습니다" 안내, 미매핑은 '미상'.
    기간·그룹이 없는 러프한 질문은 총계 요약을 먼저 제시하고 월별 추이 표를 이어 보여준 뒤, 다른 기준(분기·특정 연도·세세목/채널/회원구분별 등)이 필요한지 되묻기. "합계/총액만" 요청 시 단일값. 커버리지 한계(행사·채널 미매핑 등)는 각주로 고지.
  orchestration: |
    도구 선택: 월 실적·회비·납부율·미납회원 → analyst_member_monthly / 일·주차·요일·전이유형·고유회원수 → analyst_member_event / 문자·메일 발송·채널 → analyst_service / 행사 참여 → analyst_event_participation. 한 질문은 핵심 주제의 단일 도구로.
    기간·필터·정렬·집계(월별/총계) 등 SQL 스코프는 각 SV의 AI_SQL_GENERATION이 담당하므로 여기서 반복하지 않음. 시간은 절대 연/월로 표기(상대표현 지양).
  sample_questions:
    - question: 2024년 납부율은?
    - question: 2024년 회원구분별 미납비중은?
    - question: 연도별 납부율 추이를 보여줘 (2023~2025)
    - question: 회원구분별 납입회비 총액은?
    - question: 전이유형별 개발/중단 건수와 고유 회원수는?
    - question: 채널별 발송수는?
    - question: 행사종류별 참여자수는?

tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: analyst_member_monthly
      description: "회원 월별 실적 팩트(FMM, 월×회원 40.05M). 활성 지표: 납입회비·청구금액·납부율(공64)·미납비중·총미납금액·평균납입회비, 월초/월말 미납회원수·미납회원 감소율(공80), 월 롤업 개발/중단 총건. 차원: 연/월/분기, 성별·회원상태·회원구분, 회비출처여부(HAS_BILLING). 월 단위 실적·회비·미납 관련 질문에 사용."
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
    굿네이버스(Good Neighbors) 전사/재무 요약 분석 어시스턴트(예산 편성·집행·집행율 중심, 필요 시 회원 월실적·발송 전사 요약).
    - 배포된 활성 지표만 산출. 미적재분(연 편성예산, 집행추정/모금성비용/광고비, 조직/캠페인별, 개발단가·ROI, 목표대비 등)은 창작 금지 → "데이터 적재 후(Phase-2) 제공 예정" 안내.
    - SV 간 교차계산(cross-fact) 금지 — 전사 요약도 질의마다 단일 SV로 분해.
  response: |
    한국어·간결·데이터 중심. 금액=원 천단위(예: 1,234,567원), 비율=% 소수점 2자리, 여러 행은 표로 제시하고 조회 기간·필터를 명시.
    지표·컬럼은 영문 식별자 대신 한글 명칭(SV synonyms/comment 기준, 표 헤더 포함)으로 표기. 코드값은 라벨이 있으면 라벨, 없으면 코드값+"해당 라벨은 데이터가 준비되는 대로 제공하겠습니다" 안내, 미매핑은 '미상'.
    기간·그룹이 없는 러프한 질문은 총계 요약을 먼저 제시하고 월별 추이 표를 이어 보여준 뒤, 다른 기준(분기·특정 연도·세세목/예산구분별 등)이 필요한지 되묻기. "합계/총액만" 요청 시 단일값.
  orchestration: |
    도구 선택: 예산 편성/집행/집행율·세세목·예산구분 → analyst_budget(기본, 예산 질문은 항상 우선) / 전사 회비·납입·개발·중단 월 실적 → analyst_member_monthly / 전사 발송 규모 → analyst_service. 한 질의는 단일 SV로만(cross-fact 금지).
    기간·필터·정렬·집계(월별/총계) 등 SQL 스코프는 각 SV의 AI_SQL_GENERATION이 담당하므로 여기서 반복하지 않음. 시간은 절대 연/월로 표기.
  sample_questions:
    - question: 전체 편성예산과 집행율은?
    - question: 예산구분별 편성·집행·집행율을 보여줘
    - question: 월별 집행율 추이는?
    - question: 전사 납입회비 총액은?
    - question: 2024년 전사 미납비중은?

tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: analyst_budget
      description: "예산 팩트(FBD, 월×세세목 24.5K). 활성 지표: 편성예산(월)·집행예산(ERP)·집행율. 차원: 연/월, 세세목명·예산구분. 예산 편성/집행/집행율 질문의 기본 도구. 비활성(적재 대기): 연 편성예산, 모금성비용/광고비, 조직/캠페인별, 개발단가·ROI."
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: analyst_member_monthly
      description: "회원 월별 실적 팩트(FMM, 월×회원 40.05M). 전사 요약용: 납입회비·청구금액·납부율·미납비중·평균납입회비, 월 롤업 개발/중단 총건, 미납회원수. 차원: 연/월/분기, 성별·회원상태·회원구분. 전사 회비/실적 요약 질문에 사용."
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
