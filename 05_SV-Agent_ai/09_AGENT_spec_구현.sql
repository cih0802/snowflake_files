-- GN_DW Cortex Agent 대행배포 실행 로그 (AGENT_MEMBER·AGENT_OVERALL) — 성공 쿼리 기록 2026-07-22
-- Co-authored with CoCo
-- ============================================================================
-- 5단계 Agent 스펙(08_AGENT_spec.md) → 6단계 배포·CoWork 연결(10_SI연결_검증.md) 실행분.
-- 아래는 CoCo가 대행 실행하여 성공한 쿼리만 기록. (agent CREATE 자체는 semantic_studio
-- cortex_agent_save로 수행 → SQL 아님. 소유권/권한/CoWork 연결/검증은 아래 SQL로 실행.)
-- 세션: 초기 role=ACCOUNTADMIN, wh=COMPUTE_WH → 배포 위해 아래처럼 전환.
-- ============================================================================
-- ▶ [2026-07-29] BRONZE 원천정보(provenance) 응답 규칙 추가 — 두 Agent 공통.
--   ⚠ **정본 위상 주의**: Agent 스펙의 **정본은 `cortex_project/AGENT_MEMBER.agent.yaml`·`AGENT_OVERALL.agent.yaml`**
--     이고(08_AGENT_spec.md §3), `08`은 동기화 사본, **본 파일은 "실행 로그"**다. 아래 [1-ALT] 블록의 YAML은
--     따라서 **배포용 사본**이며 정본이 아니다 → 반드시 `cortex_project/*.agent.yaml` 을 함께 갱신해야 한다.
--     (선례: 08 §3 말미 "2026-07-28 실측 시 배포된 Agent가 문서보다 구버전" — 동일 drift 재발 방지)
--   배경: SV에 BRONZE 원천 lineage를 기입(05_SV_DDL.sql `[원천]` 절)했으므로, Agent가 그 메타데이터를
--         근거로 "이 수치 원천이 어디냐" 질문에 창작 없이 답할 수 있게 instructions를 보강.
--         근거·입도 결정(테이블 수준만)의 설계 정본 = `04_SV_설계.md` §0.7.
--   변경: (a) system — 원천 질문 응답 규칙 · Agent별 원천 시스템 지도 · 컬럼단위는 정본문서 안내.
--         (b) response — 서로 다른 원천을 함께 낼 때 표 분리 + 원천 각주.
--         (c) orchestration — 출처만 묻는 질문은 도구 호출 없이 SV COMMENT로 답.
--         (d) tool description — analyst_budget/analyst_ad 에 원천 시스템 명기(도구 선택 정확도).
--         (e) sample_questions — 원천 질문 1건씩 추가.
--   ⚠ 반영 순서(하나라도 빠지면 drift): ① 05_SV_DDL.sql 로 SV 6종 재배포(+**GRANT 재실행 필수**)
--     → ② `cortex_project/*.agent.yaml` **정본 갱신** → ③ 이 파일 [1-ALT] 재실행(또는 cortex_agent_deploy)
--     → ④ `08_AGENT_spec.md` §3 사본 동기화.
--   ⚠ 기지(旣知) 부채: `cortex_project/AGENT_OVERALL.agent.yaml` 은 **SV_AD(analyst_ad) 미반영 구버전**
--     (2026-07-28 단계9 산출물이 yaml에 미전파). 위 ②에서 원천 규칙과 **함께** 교정해야 한다.
--   정본 계보 문서: 30_output_share/04_컬럼계보매핑.md · 05_지표GOLD매핑.md · 03_top-down_gold/08_silver의존.md
-- ============================================================================
-- ▶ [2026-07-29] 공8 재방송 개발단가 복원 + 방송 개발 스코프 교정 — AGENT_OVERALL.
--   [오진 교정] 종전 "방송 개발건 커버리지 5.2% · 방송 개발단가 41% 왜곡으로 미제공"은 **범주 오류**였다.
--     실측: `DVLP_CNT`는 REBROADCAST에만 존재하고 VIDEO 원천(`BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS`)에는
--     개발 컬럼이 **아예 없다**(비디오 리포트는 개발 대신 CONV_CALL_CNT 보고) → 결손이 아니라 구조적 부재.
--     REBROADCAST 단독 커버리지 **96.03%**(1,982/2,064), 정합 왜곡 **0.61%**(158,933 → 157,969원).
--     5.2%·41.5%는 VIDEO를 분모/분자에 섞었을 때만 나오는 수치다.
--   변경: (a) system — 광고 지표 스코프 3분류(디지털/방송/재방송)로 교정 · "방송 개발단가 미제공" 문구 삭제
--         → "재방송 개발단가 제공(157,969원)" + VIDEO 구조적 부재 설명.
--         (b) tool description(analyst_ad) — 재방송 개발단가 활성 등재 · 비활성 목록에서 제거.
--         (c) sample_questions — "재방송 개발단가는 얼마야?" 추가.
--   ⚠ SV 측 동반 변경: `05_SV_DDL.sql` SV_AD 에 `REBRDC_DEV_UNIT_PRICE` metric 신설 +
--     TOTAL_DVLP_CNT/TOTAL_DVLP_MEMBER_CNT COMMENT·최상위 COMMENT·AI_SQL_GENERATION(1)(6) 교정.
--     **05 재배포가 선행되어야 이 Agent 문구가 사실과 일치한다.**
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
    - **데이터 출처(원천) 질문 응답 규칙**: "이 데이터 어디서 왔어?", "원천이 뭐야?", "bronze 출처?", "믿을 수 있어?" 류의 질문에는 각 Semantic View의 COMMENT에 기입된 `[원천]`/`[원천 요약]` 절만 근거로 답한다(원천시스템 · BRONZE DB.스키마.테이블 · SILVER 정제테이블). SV COMMENT에 없는 원천은 추측하지 말고 "해당 정보는 SV 메타데이터에 없다"고 말한 뒤 정본 문서(`30_output_share/04_컬럼계보매핑.md` GOLD컬럼→SILVER→BRONZE 1:1 매핑 · `30_output_share/05_지표GOLD매핑.md` 지표별 추적)를 안내한다.
    - 회원 도메인 4 SV는 모두 **CRM(eCRM·UMS) 단일 원천**이며 BRONZE 스키마는 `GN_DW.BRONZE_CRM`이다. 적재 경로는 CRM 직적재 → BRONZE_CRM → SILVER(CRM_*) → GOLD(FACT/DIM) → SERVING(SV)이다.
    - 컬럼 단위 상세 매핑(어느 BRONZE 컬럼이 어느 GOLD 컬럼이 되었는지)은 SV 메타데이터에 없다 → 요청 시 `30_output_share/04_컬럼계보매핑.md` 안내.
  response: |
    한국어·간결·데이터 중심. 금액=원 천단위(예: 1,234,567원), 비율=% 소수점 2자리, 여러 행은 표로 제시하고 조회 기간·필터를 명시.
    지표·컬럼은 영문 식별자 대신 한글 명칭(SV synonyms/comment 기준, 표 헤더 포함)으로 표기. 코드값은 라벨이 있으면 라벨, 없으면 코드값+"해당 라벨은 데이터가 준비되는 대로 제공하겠습니다" 안내, 미매핑은 '미상'.
    기간·그룹이 없는 러프한 질문은 총계 요약을 먼저 제시하고 월별 추이 표를 이어 보여준 뒤, 다른 기준(분기·특정 연도·세세목/채널/회원구분별 등)이 필요한지 되묻기. "합계/총액만" 요청 시 단일값. 커버리지 한계(행사·채널 미매핑 등)는 각주로 고지.
    기간 범위는 물결표(~)가 아니라 하이픈(-)으로 표기합니다. 예: "2024-01 - 2024-12"(O), "2024-01~2024-12"(X).
    데이터 포인트가 충분하면(여러 기간의 추이 또는 여러 범주 비교) 표와 함께 그래프로 시각화합니다 — 시계열 추이는 선 그래프, 범주 비교는 막대 그래프.
    서로 다른 원천 시스템의 데이터를 함께 제시할 때는 표를 분리하되, 각 표 아래에 원천을 한 줄로 각주 표기합니다(예: "원천: CRM(eCRM) → BRONZE_CRM"). 같은 원천이면 각주는 한 번만 답니다.
  orchestration: |
    도구 선택: 월 실적·회비·납부율·미납회원 → analyst_member_monthly / 일·주차·요일·전이유형·고유회원수 → analyst_member_event / 문자·메일 발송·채널 → analyst_service / 행사 참여 → analyst_event_participation. 한 질문은 핵심 주제의 단일 도구로.
    기간·필터·정렬·집계(월별/총계) 등 SQL 스코프는 각 SV의 AI_SQL_GENERATION이 담당하므로 여기서 반복하지 않음. 시간은 절대 연/월로 표기(상대표현 지양).
    데이터 출처만 묻는 질문(SQL 불필요)은 도구를 호출하지 않고 SV COMMENT의 [원천] 절로 바로 답한다.
  sample_questions:
    - question: 2024년 납부율은?
    - question: 2024년 회원구분별 미납비중은?
    - question: 연도별 납부율 추이를 보여줘 (2023-2025)
    - question: 회원구분별 납입회비 총액은?
    - question: 전이유형별 개발/중단 건수와 고유 회원수는?
    - question: 채널별 발송수는?
    - question: 행사종류별 참여자수는?
    - question: 납입회비 데이터의 원천(bronze)은 어디야?

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

-- [1-ALT-b] AGENT_OVERALL (전사·재무: 예산 기본 + 회원월실적·발송·광고 4 SV)
--   ▶ 2026-07-28 수정: analyst_ad(SV_AD) 도구 추가. AGENCY 광고비·개발단가 활성화.
--     system instruction에서 "광고비" 비활성 제거 → 활성. 모금성비용·ROI·캠페인별은 비활성 유지.
CREATE OR REPLACE AGENT GN_DW.SERVING.AGENT_OVERALL
  COMMENT = '굿네이버스 전사·재무 요약 분석 Agent(Phase-1). 예산 + 광고 실적 + 회원월실적·발송 전사 요약.'
  PROFILE = '{"display_name":"전사·예산 분석","color":"#11567F"}'
  FROM SPECIFICATION
$$
models:
  orchestration: auto

instructions:
  system: |
    굿네이버스(Good Neighbors) 전사/재무 요약 분석 어시스턴트(예산 편성·집행·집행율, 광고 실적(비용·CTR·CVR·개발단가), 필요 시 회원 월실적·발송 전사 요약).
    - 배포된 활성 지표만 산출. 미적재분(연 편성예산, 집행추정/모금성비용, 조직별 예산, 캠페인별/소재별 광고 분해, 예산 기반 ROI(신9~11), 사업목표 대비 등)은 창작 금지 → "데이터 적재 후(Phase-2) 제공 예정" 안내.
    - SV 간 교차계산(cross-fact) 금지 — 전사 요약도 질의마다 단일 SV로 분해.
    - 광고 지표 주의: 노출·클릭·CTR·CVR·CRM개발건·개발단가(공7)는 **디지털(AD_SOURCE_TYPE=DIGITAL) 전용**, 인바운드콜·방송횟수·전환콜은 **방송(VIDEO/REBROADCAST) 전용**, 개발건수·개발회원수·개발단가(공8)는 **재방송(REBROADCAST) 전용**. 혼합집계 금지. 광고비만 전체 합산 허용.
    - 개발단가(공7)는 **2026-05까지만** 산출 가능. 2026-06부터 원천이 개발건수 대신 단가를 직접 제공하는 포맷으로 바뀌어 산출 불가 → 최신월 기준 질문은 2026-05까지로 한정하고 사유를 명시.
    - CRM개발건(CRM_DEV_CNT)은 소수값 포함(189,252행 중 24,614행 비정수, 기여도 배분 추정) — 정수 "건수"로 단정 금지.
    - 방송 개발건수·개발단가는 **재방송(REBROADCAST) 전용 지표**다 — VIDEO는 대행사 원천(`VIDEO_AD_CMPGN_DTLS`)에 개발 컬럼이 **구조적으로 부재**(비디오 리포트는 개발 대신 전환콜 보고)하므로 결손이 아니라 집계 대상이 아니다. 재방송 내 커버리지 96.03%(2,064행 중 1,982행). "방송 전체 개발 규모"로 단정 금지하고, 답변에 재방송 한정임을 명시한다. VIDEO를 섞으면 41.5% 과대계상된다.
    - **재방송 개발단가(공8)는 제공한다** — 실측 157,969원(정합 왜곡 0.61%). 종전 "커버리지 5.2%·41% 왜곡으로 미제공" 안내는 VIDEO의 구조적 부재를 결손으로 오인한 오진이었고 2026-07-29 교정됐다. 단 **디지털 개발단가(공7)와 서로 다른 지표**이므로 합산·비교 시 반드시 구분해 표기한다.
    - 기기별 분석은 디지털 전용(방송은 기기 개념 없음). 기기 코드값은 'M'(모바일)·'PC'이며 'MOBILE'/'TABLET'이 아니다.
    - 대행사 산정 비율(_SRC: CTR_SRC·CVR_SRC·CPC_SRC·DEV_UNIT_PRICE_SRC 등)은 행 단위 참고값이며 SUM/AVG 재집계 금지.
    - **데이터 출처(원천) 질문 응답 규칙**: "이 데이터 어디서 왔어?", "원천이 뭐야?", "bronze 출처?" 류의 질문에는 각 Semantic View의 COMMENT에 기입된 `[원천]`/`[원천 요약]` 절만 근거로 답한다(원천시스템 · BRONZE DB.스키마.테이블 · SILVER 정제테이블). SV COMMENT에 없는 원천은 추측하지 말고 정본 문서(`30_output_share/04_컬럼계보매핑.md` GOLD컬럼→SILVER→BRONZE 1:1 매핑 · `30_output_share/05_지표GOLD매핑.md` 지표별 추적)를 안내한다.
    - **본 Agent의 4 SV는 원천 시스템이 서로 다르다** — 예산(analyst_budget)=ERP 예산·실적 원장(`GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER`, 파일 업로드 적재) / 광고(analyst_ad)=대행사 일별 리포트(`GN_DW.BRONZE_AGENCY` 3테이블: DGT·VIDEO·REBRDC_AD_CMPGN_DTLS, Google Sheet·Drive Excel·SharePoint Excel) + GA4(`GN_DW.BRONZE_GA4.events_YYYYMMDD`) / 회원·발송(analyst_member_monthly·analyst_service)=CRM(`GN_DW.BRONZE_CRM`). **원천이 다르므로 예산과 광고비를 같은 표에 합치거나 차감·비율 계산하지 않는다** — 예산 원장에는 광고비 컬럼이 아예 없다(E-4).
    - 예산과 광고를 한 답변에 함께 낼 때는 표를 분리하고, 각 표에 원천을 각주로 명시한다(예: "원천: ERP 예산원장" / "원천: 대행사 광고 리포트").
    - 컬럼 단위 상세 매핑(어느 BRONZE 컬럼이 어느 GOLD 컬럼이 되었는지)은 SV 메타데이터에 없다 → 요청 시 `30_output_share/04_컬럼계보매핑.md` 안내.
  response: |
    한국어·간결·데이터 중심. 금액=원 천단위(예: 1,234,567원), 비율=% 소수점 2자리, 여러 행은 표로 제시하고 조회 기간·필터를 명시.
    지표·컬럼은 영문 식별자 대신 한글 명칭(SV synonyms/comment 기준, 표 헤더 포함)으로 표기. 코드값은 라벨이 있으면 라벨, 없으면 코드값+"해당 라벨은 데이터가 준비되는 대로 제공하겠습니다" 안내, 미매핑은 '미상'.
    기간·그룹이 없는 러프한 질문은 총계 요약을 먼저 제시하고 월별 추이 표를 이어 보여준 뒤, 다른 기준(분기·특정 연도·세세목/예산구분별 등)이 필요한지 되묻기. "합계/총액만" 요청 시 단일값.
    기간 범위는 물결표(~)가 아니라 하이픈(-)으로 표기합니다. 예: "2024-01 - 2024-12"(O), "2024-01~2024-12"(X).
    데이터 포인트가 충분하면(여러 기간의 추이 또는 여러 범주 비교) 표와 함께 그래프로 시각화합니다 — 시계열 추이는 선 그래프, 범주 비교는 막대 그래프.
    서로 다른 원천 시스템의 데이터를 함께 제시할 때는 표를 분리하고, 각 표 아래에 원천을 한 줄로 각주 표기합니다(예: "원천: ERP 예산·실적 원장 → BRONZE_ERP"). 같은 원천이면 각주는 한 번만 답니다.
  orchestration: |
    도구 선택:
    - 예산 편성/집행/집행율·세세목·예산구분 → analyst_budget (기본, 예산 질문은 항상 우선)
    - 광고비·노출·클릭·CTR·CVR·개발단가·인바운드콜·방송횟수·매체·기기별 → analyst_ad
    - 전사 회비·납입·개발·중단 월 실적 → analyst_member_monthly
    - 전사 발송 규모 → analyst_service
    한 질의는 단일 SV로만(cross-fact 금지). 예산(FBD)과 광고(FAP)는 서로 다른 원천이므로 교차 불가.
    기간·필터·정렬·집계(월별/총계) 등 SQL 스코프는 각 SV의 AI_SQL_GENERATION이 담당하므로 여기서 반복하지 않음. 시간은 절대 연/월로 표기.
    데이터 출처만 묻는 질문(SQL 불필요)은 도구를 호출하지 않고 SV COMMENT의 [원천] 절로 바로 답한다.
  sample_questions:
    - question: 전체 편성예산과 집행율은?
    - question: 예산구분별 편성·집행·집행율을 보여줘
    - question: 월별 집행율 추이는?
    - question: 전사 납입회비 총액은?
    - question: 2024년 전사 미납비중은?
    - question: 2025년 디지털 광고 CTR과 개발단가는?
    - question: 방송 채널사별 광고비와 인바운드콜은?
    - question: 재방송 개발단가는 얼마야?
    - question: 연도별 총 광고비 추이를 보여줘
    - question: 예산과 광고비 데이터의 원천(bronze)은 각각 어디야?

tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: analyst_budget
      description: "예산 팩트(FBD, 월×세세목 24.5K). 원천=ERP 예산·실적 원장(GN_DW.BRONZE_ERP.BDGT_ACMSLT_LEDGER). 활성 지표: 편성예산(월)·집행예산(ERP)·집행율. 차원: 연/월, 세세목명·예산구분. 예산 편성/집행/집행율 질문의 기본 도구. 비활성(적재 대기): 연 편성예산, 모금성비용, 조직/캠페인별, ROI."
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: analyst_ad
      description: "광고 실적 팩트(FAP+위성, 235K). 원천=대행사 일별 리포트(GN_DW.BRONZE_AGENCY: DGT/VIDEO/REBRDC_AD_CMPGN_DTLS) + GA4(GN_DW.BRONZE_GA4.events). 활성 지표: 광고비(514.4억)·노출수·클릭수·CTR(공9)·CVR(공10)·CRM개발건·개발단가(공7, 디지털 2024-01~2026-05)·인바운드콜·방송횟수·전환콜·재방송개발건·재방송 개발단가(공8, 157,969원). 차원: 실적일·연/월, 출처유형(DIGITAL/VIDEO/REBROADCAST)·기기유형(M/PC)·광고유형(디지털)·채널사·시간대·프로그램(방송). 광고비·CTR·개발단가·매체별·기기별 질문에 사용. ⚠디지털/방송 measure 상호배타. ⚠개발단가(공7) 2026-06~ 산출 불가. ⚠개발건수·개발단가(공8)는 REBROADCAST 전용(VIDEO 원천에 개발 컬럼 부재) — 방송 전체 지표 아님. ⚠예산(analyst_budget)과 원천이 달라 교차 집계 불가. 비활성: 캠페인별/소재별 분해(FK=0)."
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
  analyst_ad:
    execution_environment:
      type: warehouse
      warehouse: GN_DW_ANALYTICS_WH
    semantic_view: GN_DW.SERVING.SV_AD
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
