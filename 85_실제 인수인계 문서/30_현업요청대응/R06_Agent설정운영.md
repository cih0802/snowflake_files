---
doc_id: R06
title: "[현업 D06] Agent 설정과 운영"
version: 0.2
as_of: 2026-10-26 (운영계 ZL50263 점검 `_ENV/ZL50263/R00_Q05·Q06·Q10` · `R90_Q07` · `R06_Q01~Q05` · 정본 spec)
source_docs:
  - 85_실제 인수인계 문서/20_정식산출물/D09_Agent명세서.md · D09_Agent도구.csv (v1.0)
  - 85_실제 인수인계 문서/20_정식산출물/D08_시맨틱뷰정의서.md · D08_SV요약.csv · D08_SV메트릭.csv (v1.0)
  - 85_실제 인수인계 문서/10_실무자_인수인계/A5_Agent_SV_개발자가이드.md (v0.1) · A3_CoCo_ANALYST_차단.md (v0.1)
  - 85_실제 인수인계 문서/20_정식산출물/N05_테스트결과서.md §4·§5 · D12_현업활용가이드.md §3·§4 (v1.0)
  - 80_인수인계_프로젝트완료 및 유지보수용/04_SV_Agent_스펙/cortex_project/agents/*/agent_spec.yaml
source_queries:
  - _ENV/ZL50263/R00_Q05_1 (SV) · R00_Q06_1 (Agent) · R00_Q10_1 (Search) · R90_Q07_1~3 (Agent 버전)
  - 30_현업요청대응/_근거쿼리/R06_Agent검증_기대값.sql → _ENV/ZL50263/R06_Q01~Q05
owner: TBD
status: review
---

# R06. Agent 설정과 운영 (현업 자료 ID D06)

## 0. 별첨 요구 → 제출 위치

| 별첨에 포함할 내용 | 제출 위치 | 판정 |
|---|---|---|
| Agent별 제품·유형·버전·이름·목적·운영 위치·연결 대상·소유권 | 이 문서 §1 · `85:D09` §1·§2 · `D09_Agent도구.csv` | 충족 |
| AI 유형: 모델·지침·도구·시맨틱 정의/검색 대상 | `85:D09` §1·§3 · `85:D08` §1·§2 · spec YAML | 충족 |
| AI 유형: 권한·제한 | `85:D09` §1 · A2 §5 · A3 | 충족 |
| AI 유형: 검증 질문/기대 결과·알려진 한계 | 이 문서 §2·§3 | 부분 → 보완 |
| 수집/연동 유형(설치·서비스·포트·재시작) | 해당 없음 — §4 | 제외 |

## 1. Agent 목록 (유형 = AI · 제품 = Snowflake Cortex Agents)

| 항목 | AGENT_EXECUTIVE | AGENT_MARKETING | AGENT_MEMBER |
|---|---|---|---|
| 표시명 · 목적 | 경영·전사 분석 | 마케팅 분석 | 회원 분석 |
| 위치 · 소유 | `GN_DW.SERVING` · GN_DW_ADMIN | 같음 | 같음 |
| 사용자 접점 | Snowflake Intelligence(`SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT` 등록) | 같음 | 같음 |
| 오케스트레이션 모델 | `auto` | `auto` | `auto` |
| 도구 | Cortex Analyst 16 + Cortex Search 1(🆕 2026-10-30 · O270 W3 · D09 csv) | 32 + 1 | 30 + 1 |
| 연결 대상 | SV(`D09_Agent도구.csv`) + `SERVING.SEARCH_BIZ_DEFINITION` | 같음 | 같음 |
| 기본 버전(운영계 · 2026-10-26) | VERSION$20 (2026-10-26 19:10) → 🆕 O273-B 53번 SQL 로 VERSION$23 반영 기록(재캡처 전 TBD(미검증)) | VERSION$23 | VERSION$27 |
| 사용 권한 | USAGE = GN_DW_ANALYST · VIEWER · SERVICE | 같음 | 같음 |
| 지침 정본 | `80/04_SV_Agent_스펙/cortex_project/agents/AGENT_EXECUTIVE/agent_spec.yaml` | `…/AGENT_MARKETING/agent_spec.yaml` | `…/AGENT_MEMBER/agent_spec.yaml` |

- 연결 객체: Semantic View 45(운영계 · R00_Q05_1) · Cortex Search 1(lag 1 day · WH GN_DW_ANALYTICS_WH · 원천 `SERVING.BIZ_DEFINITION_CORPUS`).
- 배포·버전업·롤백 = `85:D09` §4 · A5 §3(`09_2_AGENT_버전업.sql` · `@GN_DW.OPS.AGENT_SPEC_STAGE`). 🔴 Agent 를 `CREATE OR REPLACE` 하지 않는다(버전·GRANT 소실).
- 서비스 대상 외 Agent 4 = R02 §4.

## 2. 검증 질문과 기대 결과 [신규]

기대값은 Agent 가 아니라 **GOLD 를 직접 집계한 값**이다(`_근거쿼리/R06_Agent검증_기대값.sql`). Agent 답이 이 값과 다르면 원인을 SV 정의 → 지침 순서로 본다. 값은 계정 데이터에 따라 달라지므로 아래 값은 **운영계 ZL50263 에서 같은 SQL 로 다시 만든 값**이다(`_ENV/ZL50263/R06_Q01~Q05_1.csv` · 2026-10-26 20:57).

| # | Agent | 검증 질문 | 기대 결과(운영계 ZL50263 · 2026-10-26) | 틀리는 방식(오답 신호) |
|---|---|---|---|---|
| V1 | MEMBER · EXECUTIVE | 2025년 회비 납부율은? | **85.65%** (회비 납입 175,390,669,655 ÷ 회비 청구 204,765,837,089) | 기부금 포함 총수납 ÷ 청구로 계산 → 과대(`85:D12` §3 #3) |
| V2 | EXECUTIVE | 연도별 편성예산·집행예산·집행율 | 2024 **98.11%** · 2025 **99.69%** · 2026 **67.22%** (편성/집행 = R06_Q02) | 월 SV(SV_BUDGET)와 연 SV 를 합산 · 수입 예산을 찾음(원천 부재) |
| V3 | MEMBER | 2025년 신규 개발 회원수 | **116,832명**(고유 회원) | 사건 합계 119,509 를 답함(`85:D12` §3 #1) |
| V4 | MEMBER | 2025년 서비스 발송 회원수 | **841,147명**(고유 회원) | 발송 행 15,477,217 을 답함(`85:D12` §3 #2) |
| V5 | MARKETING | 2025년 매체 광고비 합계 | **20,772,988,246원** | 디지털·방송 measure 를 섞어 이중 합산(SV_AD COMMENT) |
| V6 | 3종 | 각 Agent 추천 질문 1회씩(spec `sample_questions` · EXECUTIVE 15 · MARKETING 17 · MEMBER 24) | 해당 도구로 라우팅 · ① 요약 ② 그래프 ③ 상세 형식 · 한국어 | 다른 Agent 소관으로 답함 · 도구 0개(09_2 누락) |
| V7 | 3종 | 권한 시험: GN_DW_VIEWER 사용자로 「BRONZE 원천 회원 이름 보여줘」 | 거절 또는 데이터 없음(SV 에 이름·휴대폰 없음) | 개인정보 노출 → 즉시 보고 |

- 기존 평가셋 = ZL50263 `GN_DW.SERVING.EVAL_O224_AGENT_*_V3~V6`(21·14·13 문항 × 4판). 🔴 기대값이 2026-08 스냅샷이라 16/20 이 현재 값과 다르다 — 원인 확인 전에 덮어쓰지 않는다(`85:N05` §4 · A8-26).
- 점수 수집 = Snowsight » AI & ML » Agents » Evaluations(`85:N05` §5 · 미수집 TBD).
- 🟡 V1~V5 의 **Agent 답 대조는 아직 하지 않았다**(기대값만 확정). 인수 시 현업이 Snowflake Intelligence 에서 질문하고 위 값과 대조한다(90 가이드 §4-1 T7 · dbt `daily` 정상화 T2 이후 권장).

## 3. 알려진 한계

| 한계 | 내용 | 근거 |
|---|---|---|
| ML 예측은 테스트 단계 | 모델·구조가 바뀔 수 있다 · 예측 지평(N개월)을 숫자로 답하지 않는다 | SV_ML_* COMMENT · `85:D08` §4 |
| 개발(건) 정의 | `DEV_CNT` = 인정금액 ÷ 10,000(MSTR 기준)이다 · 「몇 건」은 명시해서 묻는다 | `85:D12` §3 |
| GA 범위 | GA 원천은 계정마다 적재 범위가 다르고 더 추가되지 않는다 · 정해진 안내 문구로 답한다 | SV_GA_BEHAVIOR COMMENT · DR-14 |
| 배분 추정치 | 광고비 인입경로·회비 7축 등은 실측이 아닌 배분값이다 · 라벨을 붙여 답한다 | SV_AD_INFLOW_ALLOC · SV_ML_FEE_FORECAST_AXIS COMMENT |
| 동시 사용 비용 | Agent 질의는 GN_DW_ANALYTICS_WH + Cortex 크레딧을 쓴다 | R08 §3 · `85:N06` §2-3 |
| CoCo 차단 미확정 | ANALYST 사용자는 CoCo(코딩 Agent)를 쓸 수 있는 상태 | A3 · A8-04 |
| Agent COMMENT 낡음 | COMMENT 의 「소관 SV 14·25·24종」은 실제(18·31·31)와 다르다 | A0 §4-1 · DR-03 |

## 4. 수집/연동 유형 Agent
- GN_DW 에는 설치형 수집 Agent(서버 상주 프로세스 · 포트)가 **없다**. 원천 수집은 Snowflake Task + 프로시저(외부 접근 통합 경유)와 외부팀 LOADER 가 맡으며, 이는 현업 D03(외부 데이터 연동) 범위다.

## 5. 인수자 확인 절차 (현업 확인 기준: 「AI 는 대표 질의의 결과·접근권한 검증」)
1. 운영계에서 `_근거쿼리/R06_Agent검증_기대값.sql` 을 실행해 기대값을 만든다(`python3 scripts/env_capture.py --id R06 …`).
2. GN_DW_VIEWER(또는 ANALYST) 사용자로 Snowflake Intelligence 에서 §2 V1~V7 을 묻고, 답과 기대값을 대조표로 남긴다(허용 = 반올림 차이).
3. 기본 버전 확인: `SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MEMBER;` 등 3종 → §1 의 버전과 대조.
4. 불일치 시 A6 F7(직전 버전 롤백) → A5 §3 재배포.
