<!-- LLM-METADATA
doc_id: SV_AGENT_SPEC
doc_role: 5단계 — Cortex Agent 스펙(회원·overall) 정본 + 배포/CoWork/평가 가이드
project: GN_DW (굿네이버스)
created: 2026-07-22
depends_on: 05_SV_DDL.sql(5 SV 배포), 06_검증쿼리_VQR.md(VQR·custom instruction 6), 07_평가셋_eval.md(회귀 평가셋)
scope: Phase-1 배포 2 Agent (AGENT_MEMBER·AGENT_OVERALL) / 마케팅 Agent = Phase-2
workspace_specs: cortex_project/AGENT_MEMBER.agent.yaml · cortex_project/AGENT_OVERALL.agent.yaml
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
| 도구 SV(5, live) | `SV_MEMBER_MONTHLY`·`SV_MEMBER_EVENT`·`SV_SERVICE`·`SV_EVENT_PARTICIPATION`·`SV_BUDGET` (owner=GN_DW_ADMIN) |
| Agent 실행 WH | **`GN_DW_ANALYTICS_WH`** (Medium · comment "SV·Agent 소비") |
| Agent 배치/소유 | `GN_DW.SERVING` / `GN_DW_ADMIN` (P7 serving_separation) |
| CoWork object | `SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT` (02 §F 생성 완료 · step6 ADD AGENT) |
| orchestration model | `auto` |
| Cortex Search | Phase-2 유예(EVENT_NAME 3,786·BUDGET_ITEM_NAME 2,041 후보만 식별) |

- **왜 2 Agent만**: 회원 4 SV + overall 예산은 Phase-1 데이터로 즉시 응답 가능. 마케팅(SV_AD 스캐폴드·SV_GA 1일 샤드)은 base FACT 미완 → 오답 방지 위해 유예(01 §2 게이트).
- **왜 다중 SV 라우팅**: 한 Agent가 여러 SV를 `cortex_analyst_text_to_sql` 도구로 라우팅(공식 지원). grain이 다른 SV는 **질의마다 단일 SV로 분해**(cross-fact 계산 금지, R1).

---

## 1. Agent 구성 요약

| Agent (FQN) | 도구(SV) | 질문 도메인 |
|---|---|---|
| **`GN_DW.SERVING.AGENT_MEMBER`** (회원) | `analyst_member_monthly`→SV_MEMBER_MONTHLY · `analyst_member_event`→SV_MEMBER_EVENT · `analyst_service`→SV_SERVICE · `analyst_event_participation`→SV_EVENT_PARTICIPATION | 월 회비/납부율/미납, 개발·중단(월/일/주), 발송, 행사 참여 |
| **`GN_DW.SERVING.AGENT_OVERALL`** (overall) | `analyst_budget`→SV_BUDGET(기본) · `analyst_member_monthly`→SV_MEMBER_MONTHLY · `analyst_service`→SV_SERVICE | 예산 편성/집행/집행율(기본), 전사 회비·발송 요약(선택 라우팅) |

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

> 정본 파일: `cortex_project/AGENT_MEMBER.agent.yaml` · `cortex_project/AGENT_OVERALL.agent.yaml` (semantic_studio `cortex_agent_write`로 작성). 아래는 동기화된 사본.

> ⚠️ **`cortex_project/` 폴더 = semantic_studio 툴이 관리하는 배포 매니페스트 폴더 — 이동·개명 금지.**
> - **성격**: 사람용 설계문서(본 `08_AGENT_spec.md`)와 별개인 **기계 관리 배포 IaC**(dbt project·Terraform state에 해당). `cortex-project.yaml`(매니페스트)이 `path(상대) → Snowflake FQN` 매핑을 보관하고, `cortex_agent_save`/`publish`/`deploy`가 이를 읽어 배포 대상을 해석한다.
> - **하드 제약(개명/이동 금지 사유)**: 툴은 `cortex-project.yaml`을 **`cortex_project/` 폴더 또는 워크스페이스 루트**에서만 탐색한다. 폴더를 `06_*` 등으로 개명·번호부여하면 → 미탐색으로 save/publish 경로 해석 실패 + 다음 `cortex_agent_write` 시 `cortex_project/`를 **재생성**(폴더 이중화·혼선). 매니페스트의 `path:`는 상대경로라 파일만 다른 폴더로 옮겨도 깨진다.
> - **번호체계와의 관계**: 루트의 `_archive/`·`scripts/`처럼 **비번호 기능 폴더**로 두는 것이 정합(번호 접두사 = 사람 문서 순서, 툴 관리 폴더는 예외). 설계 정본 `08_AGENT_spec.md`는 SV 파이프라인(`05_SV_DDL`·`06_VQR`·`07_eval`)과 응집하도록 `05_SV-Agent_ai/`에 유지한다.
> - **배포 방법**: 본 문서 §4(권장 `cortex_agent_save`→`publish`). 수정은 semantic_studio `cortex_agent_write`로 이 파일들을 갱신(직접 편집·이동 금지).

### 3.1 AGENT_MEMBER

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
    execution_environment: { type: warehouse, warehouse: GN_DW_ANALYTICS_WH }
    semantic_view: GN_DW.SERVING.SV_BUDGET
  analyst_member_monthly:
    execution_environment: { type: warehouse, warehouse: GN_DW_ANALYTICS_WH }
    semantic_view: GN_DW.SERVING.SV_MEMBER_MONTHLY
  analyst_service:
    execution_environment: { type: warehouse, warehouse: GN_DW_ANALYTICS_WH }
    semantic_view: GN_DW.SERVING.SV_SERVICE
```

---

## 4. 배포 절차 (사용자 = GN_DW_ADMIN 실행)

> ✅ **실행 완료(2026-07-22, CoCo 대행)**: save(2)·소유권 GN_DW_ADMIN 이전·USAGE grant(3역할)·CoWork ADD AGENT 모두 완료. 실행 로그 = `09_AGENT_spec_구현.sql`, 상세 = `10_SI연결_검증.md`. 아래는 절차 정본(재배포·paid 이관 시 재사용).

> 스펙은 workspace에 작성됨(save 안 됨). 아래를 사용자가 순서대로 실행. **권장: semantic_studio save/publish**, DDL은 참고.

### 4.1 (권장) semantic_studio로 save → publish
1. `cortex_agent_save` — `file_path=cortex_project/AGENT_MEMBER.agent.yaml`, `fqn=GN_DW.SERVING.AGENT_MEMBER` (OVERALL 동일).
2. `SHOW VERSIONS IN AGENT GN_DW.SERVING.AGENT_MEMBER;` 로 미게시 버전 확인 후 `cortex_agent_publish` (필요 시).

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

---

## 5. 검증 계획 (배포 후 · 07 평가셋으로 회귀)

> 배포 후 `semantic_studio` `cortex_agent_query`(또는 CoWork)로 아래 문항을 질의 → 생성 SQL·답변을 07 gold SQL/값과 대조. PASS = SV·metric·dim 일치 + 값 일치(비율 ±0.01%p) + 가드레일 준수.

### 5.1 AGENT_MEMBER (07 §1~4-SV)
| # | 질문 | 기대 라우팅 | 기대값 |
|---|---|---|---|
| M3 | 2024년 납부율은? | member_monthly / PAYMENT_RATE·CAL_YEAR=2024 | 93.86% |
| M4 | 연도별 납부율 추이(2023~2025) | member_monthly / PAYMENT_RATE·CAL_YEAR | 93.66·93.86·93.98% |
| M5 | 회원구분별 납입회비 총액 | member_monthly / TOTAL_PAID_FEE·MEMBER_TYPE | 1=756.6B·2=132.1B·3=6.36B |
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
| — | 전사 납입회비 총액 | member_monthly / TOTAL_PAID_FEE | 895,178,309,108 |
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
