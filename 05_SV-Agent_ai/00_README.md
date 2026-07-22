<!-- LLM-METADATA
doc_id: SV_AGENT_README
doc_role: 05_SV-Agent_ai 폴더 진입점(색인) — SERVING 의미계층(SV·Agent) 배포/운영 wrap-up
project: GN_DW (굿네이버스)
created: 2026-07-21
updated: 2026-07-22 (SV 5 배포·검증 / Agent 2 배포·CoWork 연결 / 거버넌스 문서화 완료)
canonical_plan: 01_SV-Agent 작업계획.md (v4.2)
END-METADATA -->

# 05_SV-Agent_ai — SERVING 의미계층 (Semantic View · Cortex Agent)

> `05_SV-Agent_ai/` 폴더의 **진입점(색인)**. GOLD star schema 위에 **Semantic View 5 + Cortex Agent 2**를 올려 자연어 분석(Cortex Analyst·CoWork)을 제공하는 SERVING 계층의 설계·배포·검증·거버넌스 정본을 모은다.
> 프로젝트: 굿네이버스 GN_DW. 계정: cs94293. 배치: **`GN_DW.SERVING`**(owner=`GN_DW_ADMIN`).

## 0. 현재 상태 (2026-07-22)

| 트랙 | 상태 |
|---|---|
| SV 5개 배포·검증 | ✅ `SV_MEMBER_MONTHLY`·`SV_MEMBER_EVENT`·`SV_SERVICE`·`SV_EVENT_PARTICIPATION`·`SV_BUDGET` (fan-out 0·SV=FACT 일치) |
| Agent 2개 배포 | ✅ `AGENT_MEMBER`(4 SV)·`AGENT_OVERALL`(예산+월실적/발송) — owner=GN_DW_ADMIN |
| CoWork 연결 | ✅ `SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT`에 ADD AGENT(2) · 소비 3역할 USAGE |
| 거버넌스 문서 | ✅ 사용량·비용쿼터·알림·품질 폐루프(11번) |
| **NL 스모크 검증** | 🔄 **트라이얼 `DATA_AGENT_RUN` 차단 → paid 이관 후 필수**(10 §3) |
| README wrap-up(8단계) | 🔄 본 문서 |

> **범위**: 설계 → 배포 → RBAC → CoWork 연결 → 거버넌스까지 완료. **미검증 = 에이전트 자연어 계층**(트라이얼 제약, §주의 5).

## 1. 폴더 위상
- **입력(읽기전용)**: `03_top-down_gold/` (GOLD 정본 — DIM 12·FACT 6·derived 81 SSOT), `99_provided_definition/` (지표사전·용어).
- **근거**: `08_mornitoring/` (거버넌스 SQL 근거), `20_issue/` (BLOCKING-5 등 데이터 게이트).
- **이 폴더 = SERVING(SV·Agent)**: GOLD 소비 계층. 배포 산출물(Agent YAML·매니페스트)은 워크스페이스 루트 `cortex_project/`.

---

## 2. 파일 명세 (읽는 순서 = 번호순)

| 파일 | 단계 | 역할 |
|------|------|------|
| `00_README.md` (본 문서) | — | 폴더 색인·상태·주의사항 |
| `01_SV-Agent 작업계획.md` | 정본 | 설계원칙·의사결정·구조·작업단계 1~8·**진행상태표**·changelog(v4.2) |
| `02_SERVING_setup.sql` | 0 | SERVING 스키마·WH 3·역할 6·계층 grant·CoWork object 생성 (RBAC 선행) |
| `03_SV_metric_배속.md` | 1 | derived 81 metric을 SV에 전수 배속(P1 69·P2 12) |
| `04_SV_설계.md` | 2 | 7 SV 구조·relationship·fan-out helper·아키텍처 비판검토·**데이터 게이트 발견** |
| `05_SV_DDL.sql` | 3 | Phase-1 SV 5개 `CREATE SEMANTIC VIEW` + GRANT (배포 정본) |
| `06_검증쿼리_VQR.md` | 4 | SV 라이브 검증(SV=FACT)·회귀쿼리·VQR 후보·custom instruction 6 |
| `07_평가셋_eval.md` | 4 | NL↔gold SQL↔ground truth 평가셋(2026-07-22)·가드레일 ⓖ |
| `08_AGENT_spec.md` | 5 | **Agent 2 스펙 정본**(도구·orchestration·instruction·배포절차·평가매핑) |
| `09_AGENT_spec_구현.sql` | 6 | Agent **배포 실행 로그**(소유권 이전·USAGE·ADD AGENT) + 트라이얼/paid 이관 체크리스트 |
| `10_SI연결_검증.md` | 6 | CoWork 연결 절차 + 스모크·회귀 검증표(정확도 14·가드레일 8) |
| `11_거버넌스_운영.md` | 7 | 사용량 모니터링·비용쿼터·알림·**품질 폐루프** |
| `12_paid_테스트_실행가이드.md` | 6(보강) | **paid 이관 후 Agent NL 스모크 단독 실행 가이드**(22문항·트라이얼 차단분) |
| `99_next_prompt.md` | — | 다음 세션 kickoff — **Phase-2 활성화**(마케팅 Agent·비활성 지표 승격) |
| `../cortex_project/*.agent.yaml` | — | **툴 관리 배포 산출물**(semantic_studio) — 이동/개명 금지(§주의 2) |

---

## 3. 구조 요약 (배포본)

| Agent (FQN) | 도구(SV) | 도메인 |
|---|---|---|
| `GN_DW.SERVING.AGENT_MEMBER` | MEMBER_MONTHLY·MEMBER_EVENT·SERVICE·EVENT_PARTICIPATION | 월 회비/납부율/미납·개발중단·발송·행사 |
| `GN_DW.SERVING.AGENT_OVERALL` | BUDGET(기본)+MEMBER_MONTHLY·SERVICE | 예산 편성/집행/집행율·전사 요약 |

- **정확도 메커니즘**: orchestration 라우팅(질의당 단일 SV)·synonyms(한글)·custom instruction 6(가드레일)·(권장)VQR·평가셋 폐루프.
- **가드레일 이중구조**: 비활성 지표는 SV에 dim 자체가 없어 **구조적 차단**(강함) + 기간스코프·Unknown 고지는 instruction(모델 의존, 스모크 검증 필요).

---

## 4. ⚠️ 주의사항 (운영 필독)

1. **SV 재배포 grant 삭제**: `CREATE OR REPLACE SEMANTIC VIEW`는 기존 grant를 **삭제**한다 → 재배포 후 `GRANT REFERENCES, SELECT`(ANALYST/VIEWER/SERVICE) 3줄 재실행 필수(05 §6). Agent는 `cortex_agent_save`(in-place)로 grant 보존.
2. **`cortex_project/` 이동·개명 금지**: semantic_studio 툴이 매니페스트를 `cortex_project/` 또는 루트에서만 탐색 → 개명 시 배포 파손·폴더 재생성. 번호부여 금지(08 §3 참조).
3. **`cortex_agent_save` 소유권 gotcha**: 툴이 워크스페이스 연결(ACCOUNTADMIN)로 Agent를 생성 → 세션 `USE ROLE`을 무시. 배포 후 `GRANT OWNERSHIP … TO ROLE GN_DW_ADMIN COPY CURRENT GRANTS`로 소유권 보정 필요(08-1 로그).
4. **PK 미선언 FACT**: FME/FSE/FEP는 예상 grain 키가 실측 비유일 → SV에서 PK 미선언(기저 FACT·집계 무해). 유일 FMM·FBD만 PK 선언(05·20_issue 10 §6).
5. **트라이얼 제약**: `SNOWFLAKE.CORTEX.DATA_AGENT_RUN`/`cortex_agent_query`가 트라이얼 차단('Access denied for trial accounts') → **에이전트 NL 실행·스모크 불가**. paid 이관 후 10 §3 필수 실행(08-1 [6]).
6. **납부율 기간 스코프**: 전기간 무필터 납부율 = 100.36%(재청구·이월 왜곡). 반드시 연/월 스코프로 답. Agent instruction에 반영됨.
7. **비활성 지표 = Phase-2 안내**: 캠페인/조직/후원사업/납입방식별·성공률·D5·유지율/LTV·목표대비·개발단가/ROI는 미적재 → 임의 산출 금지, "데이터 적재 후 제공" 안내(R8).
8. **회원 속성은 현재 스냅샷**: 성별·회원상태·회원구분은 과거월 조회에도 현재값. 지역·연령대는 미적재.
9. **행사/서비스 Unknown**: 행사 미매칭 ~23%(EVENT_SK=0). 행사명별 집계는 부분 커버 → 커버리지 고지.
10. **ground truth 재생성**: GOLD 재적재 시 07 평가셋 기대값 재실행·갱신 후 회귀.

---

## 5. Phase-2 트리거 (데이터 입고 시 착수)

| 항목 | 트리거 |
|---|---|
| 마케팅 Agent(SV_AD·SV_GA) | FAD 차원FK 보강(Q10)·FGA 전기간(G-5) |
| Cortex Search 백킹(EVENT_NAME·BUDGET_ITEM_NAME) | 리터럴 오매칭 관측 시 |
| 캠페인/조직/후원사업/납입방식별 분해 | CAMPAIGN/ORG/SPONSORSHIP/PAYMENT_SK 적재 |
| 성공/실패/오픈·D5 코호트 | 코드매핑·D5 적재(신31~53) |
| 유지율/LTV/유지기간 | LAST_STOP_DATE·가입↔중단 브리지 |
| 목표대비·개발단가/ROI | FTG_D/FTG_B·비용 적재·conform 브리지(E-6·신9~11) |

> Phase-2 활성 = 동일 SV에 metric/dim 추가(구조 불변) → Agent 도구설명·평가셋 ⓖ 승격.

---

## 6. 다음
- **paid 이관 즉시**: 10 §3 스모크·회귀(정확도 14·가드레일 8) → 판정표 채움.
- (권장) VQR 등록(06 §3) → 정확도 스티어링. (선택) Agent PROFILE 표시명.
- 재개용 상세: `99_next_prompt.md`.

---
_Co-authored with CoCo_
