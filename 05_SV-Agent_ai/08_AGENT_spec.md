<!-- LLM-METADATA
doc_id: SV_AGENT_SPEC
doc_role: 5단계 — Cortex Agent 스펙(회원·overall) 정본 + 배포/CoWork/평가 가이드
project: GN_DW (굿네이버스)
created: 2026-07-22
depends_on: 05_1~05_9_SV_DDL_*.sql(SV 9종 배포 · [2026-08-10 O55] 종전 「5 SV」는 stale), 06_검증쿼리_VQR.md(VQR·custom instruction 6), 07_평가셋_eval.md(회귀 평가셋)
scope: Phase-1 배포 2 Agent (AGENT_MEMBER·AGENT_OVERALL) / 마케팅 Agent = Phase-2
workspace_specs: cortex_project/agents/AGENT_MEMBER/agent_spec.yaml · cortex_project/agents/AGENT_OVERALL/agent_spec.yaml   # 2026-08-05 O38 경로 정정
deploy_by: 사용자(GN_DW_ADMIN) — 에이전트는 스펙 작성·읽기전용 테스트만
END-METADATA -->

# 5단계 — Cortex Agent 스펙 (GN_DW · Phase-1)

> 배포된 5 SV(`GN_DW.SERVING`)를 도구로 하는 **2개 Cortex Agent 스펙**을 확정한다.
> 결정(2026-07-22): **2 Agent 우선(회원·overall)**, 마케팅 Agent는 SV_AD·SV_GA 미배포로 **Phase-2 유예**.
> **스코프(사용자 확정)**: 이 세션은 **스펙 작성까지**(workspace YAML + 본 문서). `CREATE AGENT`/save/publish/CoWork 연결은 **사용자(GN_DW_ADMIN)** 실행(§4). Cortex Search 백킹(R2)은 **Phase-2 유예**.

---

## 0. 착수 근거 & 전제 (실측 2026-07-22)

| 항목 | 값 |
|---|---|
| 도구 SV(**6**, live) | `SV_MEMBER_MONTHLY`·`SV_MEMBER_EVENT`·`SV_SERVICE`·`SV_EVENT_PARTICIPATION`·`SV_BUDGET`·**`SV_AD`**(2026-07-28 신설) (owner=GN_DW_ADMIN) |
| Agent 실행 WH | **`GN_DW_ANALYTICS_WH`** (Medium · comment "SV·Agent 소비") |
| Agent 배치/소유 | `GN_DW.SERVING` / `GN_DW_ADMIN` (P7 serving_separation) |
| CoWork object | `SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT` (02 §F 생성 완료 · step6 ADD AGENT) |
| orchestration model | `auto` |
| Cortex Search | Phase-2 유예(EVENT_NAME 3,786·BUDGET_ITEM_NAME 2,041 후보만 식별) |

- **왜 2 Agent만**: 회원 4 SV + overall 예산은 Phase-1 데이터로 즉시 응답 가능. 마케팅 전용 Agent는 SV_GA 1일 샤드로 유예(01 §2 게이트).
  > ▶ **2026-07-28 정정**: SV_AD "스캐폴드" 전제는 해제됨(광고 measure·축 실적재 → 04 §6). 다만 **별도 마케팅 Agent를 신설하지 않고 AGENT_OVERALL에 `analyst_ad` 도구로 편입**했다 — 광고비/개발단가가 전사·재무 관점 질문(예산과 나란히 비교)에 주로 쓰이고, OVERALL이 이미 광고비를 "Phase-2 예정"으로 안내하던 면책 문구를 실제로 해소하기 때문. SV_GA만 Phase-2 잔류.
- **왜 다중 SV 라우팅**: 한 Agent가 여러 SV를 `cortex_analyst_text_to_sql` 도구로 라우팅(공식 지원). grain이 다른 SV는 **질의마다 단일 SV로 분해**(cross-fact 계산 금지, R1).

---

## 1. Agent 구성 요약

| Agent (FQN) | 도구(SV) | 질문 도메인 |
|---|---|---|
| **`GN_DW.SERVING.AGENT_MEMBER`** (회원) | `analyst_member_monthly`→SV_MEMBER_MONTHLY · `analyst_member_event`→SV_MEMBER_EVENT · `analyst_service`→SV_SERVICE · `analyst_event_participation`→SV_EVENT_PARTICIPATION | 월 회비/납부율/미납, 개발·중단(월/일/주), 발송, 행사 참여 |
| **`GN_DW.SERVING.AGENT_OVERALL`** (overall) | `analyst_budget`→SV_BUDGET(기본) · **`analyst_ad`→SV_AD** · `analyst_member_monthly`→SV_MEMBER_MONTHLY · `analyst_service`→SV_SERVICE | 예산 편성/집행/집행율(기본), **광고비·CTR·CVR·개발단가·매체/기기별**, 전사 회비·발송 요약(선택 라우팅) |

> 도구 이름은 두 Agent에서 동일 SV라도 각 Agent 스펙 내 `tool_resources` 키와 1:1 매칭. overall의 MONTHLY/SERVICE는 **전사 요약용 보조 도구**(질의당 단일 SV 분해).

### 1.1 orchestration 라우팅 키워드 (질문→SV)

**AGENT_MEMBER**
- 월별 회비/납입/청구/납부율, 월초·월말 미납회원수·미납회원 감소율, 월 롤업 개발/중단 총건, 회원구분·성별별 월 실적 → `analyst_member_monthly`
- 일·주차·요일·전이유형(개발/중단)별 건수, 개발/중단 **고유 회원수** → `analyst_member_event`
- 문자/메일 발송수, 발송 고유회원수, 채널·서비스유형·발송상태별 → `analyst_service`
- 행사/이벤트 참여자수·참여건수·고유 참여회원수, 행사명/종류/구분별 → `analyst_event_participation`

**AGENT_OVERALL**
- 예산 편성/집행/집행율, 세세목·예산구분·월별 예산 → `analyst_budget` (기본)
- 전사 회비/납입/개발·중단 월 실적 요약 → `analyst_member_monthly`
- 전사 발송 규모 요약 → `analyst_service`

---

## 2. custom instruction 반영 매핑 (06 §4 / 07 §6 → Agent instructions)

> 6항 전부를 Agent `instructions`(system/response/orchestration)에 반영. 아래는 근거↔반영 위치.

| # (06 §4) | 지침 | 반영 위치 |
|---|---|---|
| ① 납부율 기간 스코프 필수(전기간 100.36% vs 연도별 ~94%) | 무필터 시 최근 연/명시 기간 한정, 전기간 총율은 참고치 | 두 Agent `orchestration` |
| ② 미납회원(수)·감소율 = 월 그룹 전제(COUNT DISTINCT) | 반드시 month(연/월) 차원과 함께 | MEMBER `orchestration` |
| ③ 행사·서비스 Unknown 고지(행사 ~23%) | 부분 커버 고지·확정치 단정 금지 | MEMBER `orchestration`+`response` |
| ④ 회원 속성 = 현재 스냅샷(성별·상태·구분), 지역/연령대/후원사업 비활성 | 과거월도 현재값, 미적재 속성 사용 금지 | 두 Agent `system` |
| ⑤ 회비 지표 = HAS_BILLING=TRUE 전제 권장 | 회비 관련 질의 전제 | 두 Agent `orchestration` |
| ⑥ 비활성 지표 = Phase-2 안내(추정 금지, R8) | 캠페인/납입방식/조직/후원사업별·성공/실패/오픈·D5·활동/누계·유지율/LTV·목표대비·개발단가/ROI | 두 Agent `system` |
| 시간(04 §0.4·07_메타) | 절대 연/월 표기, 상대 표현 지양, 미래연도(2026~) 미유입 가능 | 두 Agent `orchestration` |

---

## 3. Agent 스펙 (정본 — workspace YAML)

> 🔴 **정본 파일(2026-08-05 O38 정정)**: `cortex_project/agents/AGENT_MEMBER/agent_spec.yaml` · `cortex_project/agents/AGENT_OVERALL/agent_spec.yaml`.
> 종전 이 자리에 적혀 있던 `cortex_project/AGENT_*.agent.yaml`(루트)은 **정본이 아니며 `_archive/` 로 이관됐다** — MEMBER 쪽은 도구 4개·샘플 8개의 **O33 이전 판본**이었다(정본은 도구 6개·샘플 19개).
> 정본이 두 경로로 선언돼 서로 모순이던 상태였고, 실제 배포가 `09_2` 의 `ADD VERSION FROM <디렉터리>` 로 `agents/<AGENT>/agent_spec.yaml` 을 읽으므로 **그쪽이 정본**이다. 아래는 동기화된 사본.

> ⚠️ **`cortex_project/` 폴더 = semantic_studio 툴이 관리하는 배포 매니페스트 폴더 — 이동·개명 금지.**
> - **성격**: 사람용 설계문서(본 `08_AGENT_spec.md`)와 별개인 **기계 관리 배포 IaC**(dbt project·Terraform state에 해당). `cortex-project.yaml`(매니페스트)이 `path(상대) → Snowflake FQN` 매핑을 보관하고, `cortex_agent_save`/`publish`/`deploy`가 이를 읽어 배포 대상을 해석한다.
> - **하드 제약(개명/이동 금지 사유)**: 툴은 `cortex-project.yaml`을 **`cortex_project/` 폴더 또는 워크스페이스 루트**에서만 탐색한다. 폴더를 `06_*` 등으로 개명·번호부여하면 → 미탐색으로 save/publish 경로 해석 실패 + 다음 `cortex_agent_write` 시 `cortex_project/`를 **재생성**(폴더 이중화·혼선). 매니페스트의 `path:`는 상대경로라 파일만 다른 폴더로 옮겨도 깨진다.
> - **번호체계와의 관계**: 루트의 `_archive/`·`scripts/`처럼 **비번호 기능 폴더**로 두는 것이 정합(번호 접두사 = 사람 문서 순서, 툴 관리 폴더는 예외). 설계 정본 `08_AGENT_spec.md`는 SV 파이프라인(`05_SV_DDL`·`06_VQR`·`07_eval`)과 응집하도록 `05_SV-Agent_ai/`에 유지한다.
> - **배포 방법**: 본 문서 §4(권장 `cortex_agent_save`→`publish`). 수정은 semantic_studio `cortex_agent_write`로 이 파일들을 갱신(직접 편집·이동 금지).

### 3.1 AGENT_MEMBER

> 🔴 **[2026-07-29 발견] 본 절 YAML 사본은 구버전이다 — 정본 대조 필수.**
> 아래 사본은 **순서9-F/9-G 개정 이전** 판본이다(장문 서술형 `response`·`orchestration`, `analyst_*` 4종 라우팅 문장형). 실제 정본 `cortex_project/agents/AGENT_MEMBER/agent_spec.yaml` 및 배포본(**VERSION$5**, 2026-08-05 O38)은 **컴팩트 판본 + `*_NAME` 라벨 차원 + 원천(provenance) 규칙 + 기본 창 규칙 + 도구 6개**(`analyst_member_cohort`·`analyst_dev_achievement` 포함)를 포함한다.
> 즉 §3.2(AGENT_OVERALL)는 동기화 상태이나 **§3.1만 뒤처져 있다**. 이는 이번 세션 변경분이 아니라 **누적 부채**이며, 전면 재작성은 범위가 커 별도 작업으로 분리했다(리스크: 사본을 근거로 재배포하면 라벨화·원천 규칙이 **소실**된다).
> **당분간 AGENT_MEMBER 스펙의 근거는 반드시 `cortex_project/agents/AGENT_MEMBER/agent_spec.yaml` 을 직접 읽을 것.** 후속 착수 시 `semantic_studio cortex_agent_read`(source=workspace) 결과로 본 절을 통째로 교체한다.

```yaml
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
    execution_environment: { type: warehouse, warehouse: GN_DW_ANALYTICS_WH }
    semantic_view: GN_DW.SERVING.SV_MEMBER_MONTHLY
  analyst_member_event:
    execution_environment: { type: warehouse, warehouse: GN_DW_ANALYTICS_WH }
    semantic_view: GN_DW.SERVING.SV_MEMBER_EVENT
  analyst_service:
    execution_environment: { type: warehouse, warehouse: GN_DW_ANALYTICS_WH }
    semantic_view: GN_DW.SERVING.SV_SERVICE
  analyst_event_participation:
    execution_environment: { type: warehouse, warehouse: GN_DW_ANALYTICS_WH }
    semantic_view: GN_DW.SERVING.SV_EVENT_PARTICIPATION
```

### 3.2 AGENT_OVERALL

```yaml
models:
  orchestration: auto

instructions:
  system: |
    굿네이버스(Good Neighbors) 전사/재무 요약 분석 어시스턴트(예산 편성·집행·집행율, 광고 실적(비용·CTR·CVR·개발단가), 필요 시 회원 월실적·발송 전사 요약).
    - 배포된 활성 지표만 산출. 미적재분(연 편성예산, 집행추정/모금성비용, 조직별 예산, 캠페인별/소재별 광고 분해, 예산 기반 ROI(신9~11), 사업목표 대비 등)은 창작 금지 → "데이터 적재 후(Phase-2) 제공 예정" 안내.
  <!-- 🔴 [2026-08-05 O38] 이 사본은 구버전이다. 배포본(VERSION$4)에는 **"목표는 두 가지"** 절이 추가돼
       사업목표(FTG_B 미입고 → 산출 불가)와 **회원개발 목표(산출 가능 · AGENT_MEMBER 소관)** 를 분리한다.
       이 사본만 보고 "목표는 전부 미적재"로 읽지 말 것 — 정본은 cortex_project/agents/AGENT_OVERALL/agent_spec.yaml -->
    - SV 간 교차계산(cross-fact) 금지 — 전사 요약도 질의마다 단일 SV로 분해.
    - 광고 지표 주의: 노출·클릭·CTR·CVR·CRM개발건·개발단가는 **디지털(AD_SOURCE_TYPE=DIGITAL) 전용**, 인바운드콜·방송횟수·전환콜·방송개발건은 **방송(VIDEO/REBROADCAST) 전용**. 혼합집계 금지. 광고비만 전체 합산 허용.
    - 개발단가(공7)는 **2026-05까지만** 산출 가능. 2026-06부터 원천이 개발건수 대신 단가를 직접 제공하는 포맷으로 바뀌어 산출 불가 → 최신월 기준 질문은 2026-05까지로 한정하고 사유를 명시.
    - CRM개발건(CRM_DEV_CNT)은 소수값 포함(189,252행 중 24,614행 비정수, 기여도 배분 추정) — 정수 "건수"로 단정 금지.
    - 방송 개발건수는 커버리지 5.2%(37,886행 중 1,982행)의 **부분합** — 방송 전체 개발 규모로 단정 금지.
    - **방송 개발단가는 제공하지 않음** — 분모 커버리지 부족(5.2%)으로 41% 왜곡되어 SV에서 제외했다. 요청 시 "방송 개발건수 적재 확대 후(Phase-2) 제공 예정" 안내.
    - 기기별 분석은 디지털 전용(방송은 기기 개념 없음). 기기 코드값은 'M'(모바일)·'PC'이며 'MOBILE'/'TABLET'이 아니다.
    - 대행사 산정 비율(_SRC: CTR_SRC·CVR_SRC·CPC_SRC·DEV_UNIT_PRICE_SRC 등)은 행 단위 참고값이며 SUM/AVG 재집계 금지.
  response: |
    한국어·간결·데이터 중심. 금액=원 천단위(예: 1,234,567원), 비율=% 소수점 2자리, 여러 행은 표로 제시하고 조회 기간·필터를 명시.
    지표·컬럼은 영문 식별자 대신 한글 명칭(SV synonyms/comment 기준, 표 헤더 포함)으로 표기. 코드값은 라벨이 있으면 라벨, 없으면 코드값+"해당 라벨은 데이터가 준비되는 대로 제공하겠습니다" 안내, 미매핑은 '미상'.
    기간·그룹이 없는 러프한 질문은 기본 창 총계를 먼저, 이어 기간별 추이 표를 제시한 뒤, 다른 기준(분기·특정 연도·세세목/예산구분별)이나 전체 기간이 필요한지 되묻기. "합계/총액만" 요청 시 단일값.
    기간 범위는 물결표(~)가 아니라 하이픈(-)으로 표기합니다. 예: "2024-01 - 2024-12"(O), "2024-01~2024-12"(X).
    데이터 포인트가 충분하면(여러 기간의 추이 또는 여러 범주 비교) 표와 함께 그래프로 시각화합니다 — 시계열 추이는 선 그래프, 범주 비교는 막대 그래프.
  orchestration: |
    도구 선택:
    - 예산 편성/집행/집행율·세세목·예산구분 → analyst_budget (기본, 예산 질문은 항상 우선)
    - 광고비·노출·클릭·CTR·CVR·개발단가·인바운드콜·방송횟수·매체·기기별 → analyst_ad
    - 전사 회비·납입·개발·중단 월 실적 → analyst_member_monthly
    - 전사 발송 규모 → analyst_service
    한 질의는 단일 SV로만(cross-fact 금지). 예산(FBD)과 광고(FAP)는 서로 다른 원천이므로 교차 불가.
    기간·필터·정렬·집계 등 SQL 스코프는 각 SV의 AI_SQL_GENERATION이 담당하므로 여기서 반복하지 않되, 사용자가 기간을 안 밝히면 SV 그레인에 맞는 기본 창을 질의에 명시해 전달한다(월 그레인=최근 12개월 월별, 일 그레인=최근 7일 일별). "전체·전기간" 명시 시 미적용. 시간은 절대 연/월로 표기.
  sample_questions:
    - question: 전체 편성예산과 집행율은?
    - question: 예산구분별 편성·집행·집행율을 보여줘
    - question: 월별 집행율 추이는?
    - question: 전사 납입회비 총액은?
    - question: 2024년 전사 미납비중은?
    - question: 2025년 디지털 광고 CTR과 개발단가는?
    - question: 방송 채널사별 광고비와 인바운드콜은?
    - question: 연도별 총 광고비 추이를 보여줘

tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: analyst_budget
      description: "예산 팩트(FBD, 월×세세목 24.5K). 활성 지표: 편성예산(월)·집행예산(ERP)·집행율. 차원: 연/월, 세세목명·예산구분. 예산 편성/집행/집행율 질문의 기본 도구. 비활성(적재 대기): 연 편성예산, 모금성비용, 조직/캠페인별, ROI."
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: analyst_ad
      description: "광고 실적 팩트(FAP+위성, 235K). 활성 지표: 광고비(514.4억)·노출수·클릭수·CTR(공9)·CVR(공10)·CRM개발건·개발단가(공7, 디지털 2024-01~2026-05)·인바운드콜·방송횟수·전환콜·방송개발건. 차원: 실적일·연/월, 출처유형(DIGITAL/VIDEO/REBROADCAST)·기기유형(M/PC)·광고유형(디지털)·채널사·시간대·프로그램(방송). 광고비·CTR·개발단가·매체별·기기별 질문에 사용. ⚠디지털/방송 measure 상호배타. ⚠개발단가 2026-06~ 산출 불가. 비활성: 캠페인별/소재별 분해(FK=0), 방송 개발단가(커버리지 5.2%)."
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
    execution_environment: { type: warehouse, warehouse: GN_DW_ANALYTICS_WH }
    semantic_view: GN_DW.SERVING.SV_BUDGET
  analyst_ad:
    execution_environment: { type: warehouse, warehouse: GN_DW_ANALYTICS_WH }
    semantic_view: GN_DW.SERVING.SV_AD
  analyst_member_monthly:
    execution_environment: { type: warehouse, warehouse: GN_DW_ANALYTICS_WH }
    semantic_view: GN_DW.SERVING.SV_MEMBER_MONTHLY
  analyst_service:
    execution_environment: { type: warehouse, warehouse: GN_DW_ANALYTICS_WH }
    semantic_view: GN_DW.SERVING.SV_SERVICE
```

> ▶ **2026-07-28 개정**: `analyst_ad`(SV_AD) 4번째 도구 추가. system instruction에서 "광고비"를 **비활성 목록에서 제거**(활성 승격)하고 디지털/방송 상호배타 가드 3줄 신설. 잔여 비활성은 모금성비용·조직별 예산·캠페인/소재별 광고 분해·예산기반 ROI.
> ⚠ ~~**정합 주의**: 2026-07-28 실측 시 배포된 Agent가 본 문서보다 구버전~~ → 🟢 **해소(2026-07-29, 순서9-L)**: 두 Agent 모두 정본 yaml → `cortex_agent_deploy` 로 재배포·발행 완료(**VERSION$2 = default**).
>
> ▶ **2026-07-29 개정(순서9-L) — 기간 미지정 시 "기본 창(default window)" 규칙**
> **트리거**: CoWork에서 "예산구분별 편성·집행·집행율을 보여줘"(기간 미지정) → Agent가 **전체 기간 집계**로 응답. 사용자 기대는 "최근 1년 월별".
> **원인**: 순서9-G에서 기간 스코프를 SV `AI_SQL_GENERATION`으로 이전할 때 발동 조건을 **"기간·그룹이 모두 없을 때"** 로 좁혔다. 이번 질문은 **그룹(예산구분)이 지정**되어 조건에서 벗어나 ROLLUP이 발동하지 않았고, 기간 기본값을 줄 규칙이 어디에도 없었다.
> **변경(두 Agent 공통, instruction 2줄 *제자리 교체*)**
> - `orchestration`: "…SQL 스코프는 SV의 AI_SQL_GENERATION 담당이므로 여기서 반복하지 않**음**" → "…반복하지 않**되, 기간 미지정 시 기본 창을 질의에 명시해 전달**한다". `"전체·전기간"` 명시 시 미적용.
>   - **AGENT_OVERALL**: SV 그레인 기준(월=최근 12개월 월별, 일=최근 7일 일별)
>   - **AGENT_MEMBER**: **도구명 직접 명시**(`analyst_member_monthly`=최근 12개월 월별, 그 외 3종=최근 7일 일별) — MEMBER는 월 그레인 1종+일 그레인 3종이 섞여 그레인 추론 오류 위험이 커 결정론적으로 고정
> - `response`: "총계 요약 먼저 + **월별** 추이" → "**기본 창** 총계 먼저 + **기간별** 추이", 되묻기 선택지에 **'전체 기간'** 추가(암묵적 필터링 혼란 방지)
>
> ⚠ **설계 판단 — 신규 블록을 추가하지 않은 이유**: orchestration에 이미 "기간 스코프는 SV 담당, 여기서 반복하지 않음"이 있어 **별도 기간 규칙 블록을 덧붙이면 자기모순**이 되고 LLM이 둘 중 하나를 무작위로 무시한다. 또 "적용 기간을 응답에 명시"는 `response` 1행 "조회 기간·필터를 명시"와 **완전 중복**이라 넣지 않았다(토큰 순증 ≈ 0). → 신규 교훈 **P24**.
> ⚠ **폐기한 초안**: "결과 행 수 7~12개가 되도록" — 예산구분(2)×12개월=**24행**이므로 행 수 기준은 LLM이 기간을 임의 절단하게 만든다. 기준은 **시간 버킷 수**여야 한다. "연도별 최근 3개년"도 근거 없이 만든 값이라 폐기.
> ⚠ **기본 창의 트레이드오프**(수용한 리스크): 암묵적 필터링이므로 "왜 2022년이 없지?"라는 혼란이 가능하다 → ① 적용 기간을 응답에 항상 명시(기존 규칙 재사용) ② 되묻기에 '전체 기간' 선택지 노출 ③ `"전체"` 키워드로 규칙 무시 — 3중으로 완화.

---

## 4. 배포 절차 (사용자 = GN_DW_ADMIN 실행)

> ✅ **실행 완료(2026-07-22, CoCo 대행)**: save(2)·소유권 GN_DW_ADMIN 이전·USAGE grant(3역할)·CoWork ADD AGENT 모두 완료. 실행 로그 = `09_AGENT_spec_구현.sql`, 상세 = `10_SI연결_검증.md`. 아래는 절차 정본(재배포·paid 이관 시 재사용).

> 스펙은 workspace에 작성됨(save 안 됨). 아래를 사용자가 순서대로 실행. **권장: semantic_studio save/publish**, DDL은 참고.

### 4.1 (권장) semantic_studio로 save → publish
1. 🔴 **`cortex_agent_save`/`cortex_agent_deploy` 를 쓰지 않는다**(2026-08-05 O38 정정). 이 도구는 **live 버전**을 만드는데 이 프로젝트는 **명명 버전 방식**(VERSION$n)이고 `ADD VERSION FROM` 은 live 가 있으면 **거부**된다. 정본 경로 = `agents/<AGENT>/agent_spec.yaml` 갱신 → `ALTER WORKSPACE … COMMIT` → **`09_2_AGENT_버전업.sql`** → `SET DEFAULT_VERSION`(P66: 발행만으로 default 가 되지 않는다).
2. `SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MEMBER;` 로 미게시 버전 확인 후 `cortex_agent_publish` (필요 시).

> ⚠⚠ **배포 3경로의 버전 의미 차이 — 실측 검증 완료(2026-07-29, 순서9-L)**
> `SHOW VERSIONS` 의 `is_default=true` 행이 **실사용자에게 서비스되는 버전**이다. `live` 는 편집 중 버전이며 default가 아니다.
>
> | 경로 | 결과 | 버전 이력 | 판정 |
> |---|---|---|---|
> | ① `CREATE OR REPLACE AGENT` (`09` [1-ALT]) | VERSION$1(신 spec)+live 생성, `is_default=true` → **즉시 발행**, COMMIT 불요 | 🔴 **VERSION$1 하나로 초기화 → 기존 전 버전 소멸(롤백 불가)**. 추가로 USAGE grant 3건·CoWork SI 등록도 파괴(순서9-J §2) | 최초 생성 전용 |
> | ② `cortex_agent_save` **단독** | live만 갱신, default는 **기존 VERSION$N 유지** | 보존 | 🔴 **함정** — 저장 성공 메시지가 나오지만 **미발행**. 사용자는 계속 구 spec을 받는다 |
> | ③ `cortex_agent_deploy` (=save+publish) | **VERSION$N+1 신규 생성 + default 승격** | 🟢 보존(직전 버전 롤백 가능) | ★**권장** |
> | ③′ **순수 SQL** (`09` [4-B]) | ③과 **동일** | 🟢 보존 | ★**CoCo 없이 SQL만으로 가능** |
>
> **③′ 순수 SQL 등가 경로** — semantic_studio 없이 SQL만으로 ③과 같은 결과를 낸다(실측 검증 2026-07-29, 임시 agent `ZZ_TMP_SQLPUB`·`ZZ_TMP_GAP`). **구버전 agent가 있는 계정의 표준 경로**이며 **0·4단계를 빠뜨리면 실패한다**:
> ```sql
> -- 0) ★ live 선복구 — 없으면 1)이 "Live version is not found." 로 실패
> ALTER AGENT <fqn> ADD LIVE VERSION FROM LAST;    -- 이미 있으면 에러 → 09 [4-B-0] 멱등 블록 사용
> -- 1) spec 전체 교체 (⚠ SPECIFICATION 뒤 = 필수)
> ALTER AGENT <fqn> MODIFY LIVE VERSION SET SPECIFICATION = $$ <YAML 전문> $$;
> -- 2) 발행 (VERSION$N+1 생성 + default 승격)
> ALTER AGENT <fqn> COMMIT COMMENT = '...';
> -- 3) 개발 재개용 live 재생성 (⚠ 생략 시 다음 편집 불가)
> ALTER AGENT <fqn> ADD LIVE VERSION FROM LAST;
> -- 4) ★ COMMENT·PROFILE 은 spec 이 아니라 DDL 속성 → 1~3 으로 안 바뀜 (⚠ 콤마 구분 필수)
> ALTER AGENT <fqn> SET COMMENT = '...', PROFILE = '{"display_name":"...","color":"#..."}';
> ```
>
> | 단계 | 놓치면 생기는 일 | 실측 증거 |
> |---|---|---|
> | **0** | 🔴 1)이 즉시 실패 — `COMMIT`·CoWork UI 발행이 live 를 소진하므로 **구버전 계정은 live 가 없을 수 있다** | `ZZ_TMP_GAP`: COMMIT 후 `SHOW VERSIONS` 에 live 행 소멸 → `MODIFY LIVE VERSION` → `Live version is not found.` → `ADD LIVE VERSION FROM LAST` 후 3행 복구 |
> | **1** | `=` 누락 시 `syntax error … unexpected '$$…'` / YAML 미포함 필드는 **삭제**(전체 교체) | 실측 |
> | **2** | 미실행 시 live 만 바뀌고 사용자는 구 버전 수신(P25). ⚠ **spec 무변경이어도 새 버전 생성 → 멱등 아님** | `ZZ_TMP_GAP`: 무변경 COMMIT → `VERSION$2` 생성 |
> | **3** | 다음 편집 불가. 성공 메시지의 `null` 은 alias 미지정이며 정상 | `Live version nullsuccessfully created` |
> | **4** | 🔴 CoWork **표시명·색상·설명이 구버전으로 남는다** | `ZZ_TMP_GAP`: spec v3 커밋 후에도 `old-comment`·`구버전표시명` 유지. `SET COMMENT='…' PROFILE='…'`(콤마 없음) → `unexpected 'PROFILE'`, 콤마 추가 후 성공 |
>
> ↔ **①과의 결정적 차이**: ①(`CREATE OR REPLACE`)은 COMMENT·PROFILE 을 매번 재지정해야 하고 누락 시 소실되지만, ③′은 건드리지 않아 **기존 표시설정·grant·SI 등록이 모두 보존**된다. 대신 표시설정을 *바꾸려면* 4단계를 명시해야 한다.
> 구현체 = `09` **[4-B]**(`[4-B-0]` 멱등 live 복구 · `[4-B-a]`/`[4-B-b]` 양 Agent YAML 전문 · `[4-B-c]` COMMENT·PROFILE). **운영 계정 업데이트의 기본 경로.**
>
> **실측 근거**: ① 임시 agent `ZZ_TMP_VERTEST` 로 v1 생성→v2 REPLACE 시 VERSION$2가 생기지 않고 VERSION$1 내용만 교체됨. ③ 두 Agent 배포 후 VERSION$2 `is_default=true`(신 규칙 포함)·VERSION$1 `is_default=false` 보존 확인.
> **운영 원칙**: 최초 생성만 ①, **이후 모든 변경은 ③ 또는 ③′**. ②로 끝내지 말 것. → 신규 교훈 **P25**.

### 4.2 (참고) SQL — save 대체 시
```sql
USE ROLE GN_DW_ADMIN;
USE WAREHOUSE GN_DW_ANALYTICS_WH;
-- CREATE AGENT ... FROM SPECIFICATION $$ <위 YAML> $$;  (실 배포는 semantic_studio save 권장)
```

### 4.3 소비 권한(USAGE) — CREATE 직후 필수 (02 §E.1: AGENT는 FUTURE grant 미지원)
```sql
USE ROLE GN_DW_ADMIN;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_MEMBER  TO ROLE GN_DW_ANALYST;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_MEMBER  TO ROLE GN_DW_VIEWER;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_MEMBER  TO ROLE GN_DW_SERVICE;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_OVERALL TO ROLE GN_DW_ANALYST;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_OVERALL TO ROLE GN_DW_VIEWER;
GRANT USAGE ON AGENT GN_DW.SERVING.AGENT_OVERALL TO ROLE GN_DW_SERVICE;
```
> 소비 역할은 이미 GOLD SELECT + SV REFERENCES,SELECT + ANALYTICS_WH USAGE 보유(02·05 §6). Cortex 사용권(SNOWFLAKE.CORTEX_USER)은 PUBLIC 상속.

### 4.4 CoWork 연결 = 6단계(`10_SI연결_검증.md`)
> 계정에 명시적 SI object(`SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT`) 존재(02 §F) → **advanced 경로**.
```sql
ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT ADD AGENT GN_DW.SERVING.AGENT_MEMBER;
ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT ADD AGENT GN_DW.SERVING.AGENT_OVERALL;
-- object USAGE는 02 §F에서 소비 3역할에 이미 부여. CoWork URL: https://ai.snowflake.com
```

> ⚠ **재실행 안전성(멱등) — 실측 정리(2026-07-29, 순서9-L)**
> 위 `ADD AGENT` 는 **이미 등록된 agent에 재실행하면 에러**다. 재실행 가능한 배포 스크립트로 만들려면:
> - `ADD AGENT IF NOT EXISTS` → **syntax error**(미지원). 실측 확인.
> - 제거 구문은 `REMOVE AGENT` 가 **아니라 `DROP AGENT`** 다 — `ALTER SNOWFLAKE INTELLIGENCE <si> DROP AGENT <fqn>` (정본: docs *Configure the visibility of agents in Snowflake CoWork*).
> - → **해법**: `SHOW AGENTS IN SNOWFLAKE INTELLIGENCE <si>` 로 사전 확인 후 조건 분기. 구현체 = `09` [4] `EXECUTE IMMEDIATE` 블록(실행 검증: 기등록 상태 재실행 → `AGENT_MEMBER=skipped AGENT_OVERALL=skipped`).
>
> ⚠ **가드의 전제를 반드시 실측할 것**: `SHOW AGENTS IN SNOWFLAKE INTELLIGENCE` 결과가 `SHOW AGENTS IN ACCOUNT` 와 **우연히 동일**할 수 있다(본 계정은 2건이 정확히 일치했다). 그 경우 "계정 전체 목록"인지 "SI 멤버십"인지 구분되지 않아 **가드가 항상 skip 하는 무력 상태**일 수 있다. → `DROP AGENT` 직후 행이 사라지고(0) 재-`ADD` 시 복귀(1)함을 확인해 **멤버십 반영임을 검증 완료**. 유사 가드를 만들 때 동일 검증을 거칠 것. → 신규 교훈 **P26**.
>
> ⚠ Snowflake Scripting 제약: `FOR rec IN (…) DO` 의 커서 변수(`rec.col`)는 **스크립팅 표현식에서 참조 불가**(`invalid identifier 'REC.AGENT_NAME'`). agent 목록 루프를 만들지 말고 **명시 분기**로 작성한다.

---

## 5. 검증 계획 (배포 후 · 07 평가셋으로 회귀)

> 배포 후 `semantic_studio` `cortex_agent_query`(또는 CoWork)로 아래 문항을 질의 → 생성 SQL·답변을 07 gold SQL/값과 대조. PASS = SV·metric·dim 일치 + 값 일치(비율 ±0.01%p) + 가드레일 준수.

### 5.1 AGENT_MEMBER (07 §1~4-SV)
| # | 질문 | 기대 라우팅 | 기대값 |
|---|---|---|---|
| M3 | 2024년 납부율은? | member_monthly / **PAYMENT_RATE_FEE**·CAL_YEAR=2024 | **85.77%** | 🔴[O56-C EXPO-2] `PAYMENT_RATE` 제거 · 종전 기대값은 폐기식 값 |
| M4 | 연도별 납부율 추이(2023~2025) | member_monthly / **PAYMENT_RATE_FEE**·CAL_YEAR | **86.05·85.77·85.65%** | 🔴[O56-C EXPO-2 재측정] |
| M5 | 회원구분별 **총수납액** | member_monthly / **TOTAL_PAID_ALL**·MEMBER_TYPE_NAME | 개인=756.6B·기업=132.1B·단체=6.36B | 🔴[O56-C] 개명 · 값 불변 |
| E4 | 전이유형별 개발/중단 건수·회원수 | member_event / EVENT_TYPE | 개발 3,594,843/회원 1,585,949 · 중단 1,038,262/903,064 |
| S3 | 채널별 발송수 | service / TOTAL_SEND_MEMBERS·CHANNEL | MSG_AT 20.56M·SND 8.30M·EMAIL 7.81M·PSTMTR 1.79M·(미매핑)11,313 |
| P3 | 행사종류별 참여자수 | event_participation / EVENT_KIND | EVENT 718,438·(Unknown)263,611·CRMN 152,077 |
| **M10ⓖ** | 캠페인별 납부율 | (비활성) | "캠페인 FK 미적재→Phase-2" 안내(산출 금지) |
| **E5ⓖ** | 평균 유지기간 | (비활성) | "페어링 불가→Agent/Phase-2" 안내 |
| **S5ⓖ** | 발송 성공률 | (비활성) | "SUCCESS/FAIL 미적재→Phase-2" 안내 |

### 5.2 AGENT_OVERALL (07 §5)
| # | 질문 | 기대 라우팅 | 기대값 |
|---|---|---|---|
| B1 | 전체 편성예산 | budget / TOTAL_PLAN_BUDGET | 503,070,876,000 |
| B3 | 전체 집행율 | budget / EXEC_RATE | 39.61% |
| B4 | 예산구분별 편성·집행·집행율 | budget / BUDGET_CATEGORY | 지출 254.06B/80.49B/31.68% · 수입 249.01B/118.79B/47.71% |
| — | 전사 **총수납액**(회비+기부금) | member_monthly / **TOTAL_PAID_ALL** | 895,178,309,108 | 🔴[O56-C] 회비만은 `TOTAL_PAID_FEE_BILLABLE` 768,800,286,349 |
| **B5ⓖ** | 캠페인별 ROI(개발단가) | (비활성) | "CAMPAIGN_SK·비용·FMM 연계 미적재→Phase-2(신9~11)" 안내 |

> **가드레일(ⓖ)**: 비활성 지표는 임의 산출 없이 Phase-2 안내(R8). 납부율 무필터는 기간 스코프로 재해석(전기간 100.36% 단정 금지). 행사/서비스 Unknown 커버리지 고지.

### 5.3 VQR 등록(정확도 1순위 · 06 §3)
> 각 SV의 검증쿼리(06 §3)를 `AI_VERIFIED_QUERIES`(또는 SVA vqr_management)로 등록해 Cortex Analyst 스티어링. Agent 배포와 병행/후속. (semantic_studio `semantic_view/vqr_management`)

---

## 6. Phase-2 유예 (데이터 입고 트리거)

| 항목 | 트리거(문서40) |
|---|---|
| **마케팅 Agent**(SV_AD·SV_GA 도구) | FAD 차원FK 보강(Q10)·FGA 전기간(G-5) |
| Cortex Search 백킹(EVENT_NAME·BUDGET_ITEM_NAME) | 리터럴 오매칭 관측 시 활성(현 저빈도 → 유예) |
| 캠페인/조직/후원사업/납입방식별 분해 | CAMPAIGN/ORG/SPONSORSHIP/PAYMENT_SK 적재(B2·B3·Q10) |
| 발송 성공/실패/오픈·D5(신31~53) | B1 코드매핑·D5 적재 |
| 유지율/LTV/유지기간(신4·6~8) | LAST_STOP_DATE·가입↔중단 코호트 브리지 |
| 목표대비(공1~3)·개발단가/ROI(신9~11) | FTG_D/FTG_B·비용 적재·conform 브리지 |

> Phase-2 활성 시: 동일 SV에 metric/dimension 추가(구조 불변) → Agent 도구 설명·평가셋 ⓖ 케이스를 정상 산출로 승격.

---

## 7. 다음 단계
`10_SI연결_검증.md` (CoWork ADD AGENT·자연어 스모크) → `11_거버넌스_운영.md` (사용량/비용쿼터/폐루프) → `00_README.md` 갱신.

---
_Co-authored with CoCo_
