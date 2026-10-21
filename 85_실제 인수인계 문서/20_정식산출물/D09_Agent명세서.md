---
doc_id: D09
title: Agent 명세서
version: 1.0
as_of: 2026-10-21 (O250-C 갱신 · 버전은 운영계 실측)
source_docs:
  - 라이브 DESCRIBE AGENT · SHOW GRANTS ON AGENT · SHOW AGENTS IN SNOWFLAKE INTELLIGENCE (정본)
  - cortex_project/agents/*/agent_spec.yaml (spec 정본 파일 · 80번 04_SV_Agent_스펙 과 해시 동일 · DR-20)
  - 01_실행순서_배포SQL/05_SV-Agent_ai/09_2_AGENT_버전업.sql (배포 절차)
source_queries:
  - DESCRIBE AGENT 3종 spec 파싱(2026-10-20 실행) · A6 Q07(버전)
  - 생성 = python3 scripts/b_struct_build.py <계정> → D09_Agent도구.csv
owner: TBD
status: review
---

# D09. Agent 명세서

본문 데이터 = `D09_Agent도구.csv`(행 수는 파일에서 센다 · Agent × 도구 이름 · 종류 · 대상 SV/Search · 설명 앞 200자).

## 1. Agent 개요 (실측)

| 항목 | AGENT_EXECUTIVE | AGENT_MARKETING | AGENT_MEMBER |
|---|---|---|---|
| 표시명(profile) | 경영·전사 분석 | 마케팅 분석 | 회원 분석 |
| 위치 · 소유 | `GN_DW.SERVING` · GN_DW_ADMIN | 같음 | 같음 |
| 기본 버전 [ENV] 운영계(ZL50263) | D10 §2 참조 | D10 §2 참조 | D10 §2 참조 |
| 오케스트레이션 모델 | auto | auto | auto |
| 도구 | 19 = Cortex Analyst 18 + Cortex Search 1 | 32 = 31 + 1 | 32 = 31 + 1 |
| 추천 질문 | 15 | 17 | 24 |
| 지침 길이(문자) response / orchestration / system | 5,421 / 15,429 / 5,963 | 5,704 / 16,817 / 3,976 | 4,963 / 22,273 / 6,161 |
| 사용 권한 | USAGE = ANALYST · VIEWER · SERVICE | 같음 | 같음 |
| Snowflake Intelligence 등록 | `SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT` 3/3 | | |

- Search 도구 = `search_biz_definition` → `SERVING.SEARCH_BIZ_DEFINITION`(비즈니스 정의 · 수치는 analyst 도구로만 낸다).
- 배선 SV 합집합 = SV 전수(D08 · 2026-10-21 ZL50263 = 45).

## 2. 소관 범위

| Agent | 핵심 질문 영역 | 대표 SV |
|---|---|---|
| EXECUTIVE | 전사 경영 요약 · 예산 편성/집행 · 광고비 · 회원 월실적 · 지출결의 · ML 개발금액·LTV 예측 | SV_BUDGET · SV_BUDGET_YEARLY · SV_AD · SV_MEMBER_MONTHLY · SV_EXPENSE_RESOLUTION · SV_ML_DVLP_FORECAST |
| MARKETING | 광고 효율 · 캠페인 · 개발 목표 · GA 방문·검색 · 획득 코호트 · 증액 예측 | SV_AD · SV_AD_INFLOW_ALLOC · SV_GA_* · SV_SEARCH_CONSOLE · SV_CAMPAIGN_* · SV_ML_INC_CAMPAIGN · SV_ML_FEE_FORECAST_AXIS |
| MEMBER | 회원 상태전이 · 회비 · 서비스 발송 · 행사 · 결연 · 중단·전환 예측 · 부서 자체 집계 | SV_MEMBER_* · SV_SERVICE · SV_EVENT_PARTICIPATION · SV_RELATION_ACTIVITY · SV_ML_MEMBER_RISK · SV_ML_FEE_FORECAST_AXIS |

- 3종 공통 SV 8: SV_CAMPAIGN_CUM_STOP · SV_CAMPAIGN_MONTHLY · SV_ML_CHURN_CAMPAIGN · SV_ML_FEATURE_IMPORTANCE · SV_ML_MEMBER_PRED_AXIS · SV_ML_MEMBER_PRED_BRIDGE · SV_ML_REALTIME_SIMULATOR · SV_MSTR_SPNSR_DVLP.
- 🆕 [O250] 7축 예측 도구 = `analyst_ml_pred_axis`(SV_ML_MEMBER_PRED_AXIS · 3종) · `analyst_ml_fee_axis`(SV_ML_FEE_FORECAST_AXIS · MEMBER·MARKETING) — 증액·중단·미납·회비 예측을 신규기존·본부지부·후원사업·법인·공통브랜드·캠페인카테고리·마케팅캠페인명으로 나눈다.

## 3. 응답 규칙 (spec `instructions` 요약 · 3종 공통)

| 규칙 | 내용 |
|---|---|
| 형식 | ① 핵심 요약(3줄) · ② 그래프 · ③ 상세 — 각 1회 · 차트는 ① 앞에 생성 |
| 수치 | 도구 결과 셀 값만 쓴다(직접 합산·차감 금지) · 금액 원 천단위 쉼표 · 비율 소수 2자리 |
| 표기 | 표·차트 헤더 한글 · 기준(MSTR / GN_DW) 명시 · `(미매핑)` 그대로 표기 |
| 어휘 | NGO 친화 표현(「이탈」→「중단」 등) · 한국어만 |
| 미정의 지표 | 사전 산식이 없으면 가정을 제시하고 계산 여부를 먼저 묻는다 |

- 정본은 spec 파일이다. 규칙 변경 = spec 수정 → `09_2` 로 새 버전 발행(A5 §3).

## 4. 배포 · 롤백

| 단계 | 방법 |
|---|---|
| 배포 | `ALTER AGENT … ADD VERSION FROM '@GN_DW.OPS.AGENT_SPEC_STAGE/<AGENT>'` — 새 버전이 자동 기본값 |
| 사전 점검 | `scripts/sv_identifier_gate.py`(spec ↔ 라이브 SV) · 09_2 [0-C] 스테이지 대조 |
| 롤백 | `ALTER AGENT … SET DEFAULT_VERSION = 'VERSION$n'` |
| 검증 | Snowflake Intelligence 에서 추천 질문 1회씩(라우팅 확인) |

## 5. [ENV] 사용 현황 (최근 7일 · A7 Q03)

| Agent | 운영계 |
|---|---|
| MEMBER | TBD(미검증) |
| EXECUTIVE | TBD(미검증) |
| MARKETING | TBD(미검증) |

## 6. 드리프트

| # | 문서 기재 | 실측 | 처리 |
|---|---|---|---|
| DR-03 | Agent COMMENT「소관 SV 14·25·24종」 | 17·28·28 | 🟢 O250-C 해소 = COMMENT 를 수치 없는 카테고리 문안으로 교체(09_1 [5] · 운영계 반영 대기) |
| DR-16 | 09_2 [0] 정적 목록 · [3] COMMENT「도구 15·26·25종」 | 도구 18·29·29 | 게이트(`sv_identifier_gate`)를 정본으로 · 🟢 O250-C = [3] COMMENT 수치 제거 · [0] 에 O250 5행 추가 |
| DR-17 | 09_2 [0-C] 시각 비교 | 계정 이동 직후 `STAGE_STALE` 오탐 | [0-B] 재복사 |
| DR-04 | 시뮬레이터 SV 3종 배선 ↔ base 뷰 권한 | VIEWER·SERVICE 불가 | 결정 = 뷰 개방(적용 대기) |
