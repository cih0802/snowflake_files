# Semantic View · Agent 설계 작업계획 (GN_DW)

> 굿네이버스 GN_DW 프로젝트 **Semantic View(SV) + Cortex Agent 설계 작업계획서**.
> 입력: `02_top-down 설계/` GOLD 설계 산출물(7단계 완료) — `GOLD_파생지표 매핑.md`(derived 81 SV metric SSOT) · `GOLD_팩트 설계.md`(FACT 6·measure 61·가산성) · `GOLD_차원 설계.md`(DIM 12·conformed) · `GOLD_메타제약 확인.md`(시간가용성·미해결) · `GOLD_ddl 초안.sql`(실제 컬럼명).
> **범위: 설계 문서 산출까지.** 실제 `CREATE SEMANTIC VIEW` / `CREATE AGENT` 배포는 별도 트랙(데이터 검증 후).
> 전제: GOLD 물리 = **12 DIM + 6 FACT**. SV는 그 위 의미 계층.
> 기준: Snowflake 공식 best practice(부록 C 출처) 반영본 — v3 (구조 확정: 4 SV / 3 Agent, 마케팅 Agent만 다중 SV).

---

## ★ 실행 가이드 (이 문서를 읽는 에이전트 필독)

**작업 전 반드시:**
1. 부록 B 입력 문서를 **먼저 읽는다.** 특히 `GOLD_파생지표 매핑.md`(metric SSOT)·`GOLD_ddl 초안.sql`(실제 컬럼명).
2. 3절을 **1→7단계 순서대로** 수행한다. 각 단계 산출물은 **이 폴더(`03_SV-Agent 설계/`)** 에 단계 번호 접두사로 쓴다.
3. 진행 상태는 **§진행 상태 표**에 갱신한다(재개 가능하게).

**DO NOT (오류 방지 — 반드시 지킬 것):**
- ❌ `CREATE SEMANTIC VIEW`/`CREATE AGENT` 등 **배포·실행 금지.** 본 트랙은 **설계 문서 + YAML 초안까지.**
- ❌ `02_top-down 설계/` 파일 **수정 금지**(입력은 읽기 전용).
- ❌ 지표 번호(공N·신N)·분자/분모·base measure·컬럼명·조인키 **추정/창작 금지.** 반드시 원본 파일에서 확인 후 인용.
- ❌ derived 수식 **재정의 금지.** `GOLD_파생지표 매핑.md`를 그대로 직역(원칙 4).
- ❌ 미수령 8건 값 **추정 금지.** placeholder(비활성)로만 표기(원칙 8).
- ⚠️ **확실하지 않으면 멈추고 사용자에게 질문.** 가정으로 진행하지 않는다.

## ★ 약어 키 (Glossary)
| 약어 | 뜻 |
|---|---|
| SV / Agent | Semantic View / Cortex Agent |
| FMM | `FACT_MEMBER_MONTHLY`(월×회원 실적) |
| FTG-D / FTG-B | `FACT_TARGET` — 개발구분 grain / 후원사업 grain(ERP 미수령) |
| FSE / FGA / FAD | `FACT_SERVICE_EVENT` / `FACT_GA_BEHAVIOR` / `FACT_AD_PERFORMANCE` |
| 공N / 신N | 공통지표 N번 / 신규지표 N번 (`공통지표 정보.md`·`신규지표 정보.md`) |
| §N | `GOLD_파생지표 매핑.md`의 섹션 N |
| A / S / N | 가산(additive) / 준가산(semi) / 비가산(non-additive) measure |
| conformed | 공유 차원(DIM_DATE·DIM_ORG 등) 기준으로 정합된 조인 |
| cross | cross-source 조인(DIM_MEMBER_IDENTITY 브리지) |
| SSOT | 단일 진실원천(Single Source Of Truth) |
| VQR | Verified Query(검증쿼리) — `AI_VERIFIED_QUERIES` |
| placeholder | metric 정의만 두고 비활성(데이터 미입고) |
> 더 상세한 용어는 `02_top-down 설계/GOLD_설계 작업계획.md` 부록 Glossary 참조.

---

## 0. 설계 원칙 (확정)

1. **SV 입도(granularity)와 Agent 수는 별개 결정이다.** *(v1 정정)*
   - 정확도의 핵심 레버는 **SV를 좁고 명확하게 쪼개는 것**(metric·테이블 수 최소화 → text-to-SQL 혼동 감소).
   - **하나의 Agent는 여러 SV를 라우팅할 수 있다**(Snowflake 공식). 본 설계 확정: **SV 4개 / Agent 3개**(마케팅 Agent만 2 SV 라우팅, 2.2).

2. **분리 기준 = FACT grain.** grain이 다른 FACT를 JOIN하는 metric은 SV를 나누거나 relationship+instruction으로 JOIN 규칙을 명시한다.

3. **SV 4개 / Agent 3개로 구성한다**(SV는 FACT grain 경계 분리, 마케팅 Agent만 2 SV 라우팅). 상세 2절.

4. **derived 정의는 `GOLD_파생지표 매핑.md`가 단일 진실원천(SSOT).** 분자/분모를 재정의하지 않고 그대로 metric expression으로 직역. (%)는 ×100, 가산성(A/S/N) 반영(N·S는 SUM 재집계 금지).

5. **시맨틱 품질 요소를 1급 산출물로 다룬다.** 각 dimension/measure/metric에 `synonyms`(**한글 동의어 필수**)·`description`·`sample_values`·`default_aggregation`·**relationships(FACT↔DIM 조인)**를 정의한다. ← Cortex Analyst 정확도의 토대.

6. **Verified Queries(검증쿼리)를 정확도 1순위 메커니즘으로 설계한다.** golden question을 단순 테스트가 아니라 SV의 `AI_VERIFIED_QUERIES`(2026-04 지원)로 등록 → 정확도 향상 + optimization 입력. (테스트셋 ≠ 검증쿼리, 둘 다 작성)

7. **시간가용성·NULL 규칙을 SV custom instruction으로 강제.** `GOLD_메타제약` 1.1 enum(전체가능/24년~/25년~/2개년/적용불가)에 따라 "24년 이전 구간 조회 시 제외/NULL" 등을 instruction에 명문화.

8. **산출제약 8건(메타4.4)은 1단계 세분류를 따른다 — placeholder 4 · 부분 1 · 보류 3.** ① placeholder 4(공7·10·98·108): SV에 정의만 두고 비활성 ② 부분 1(신8 LTV): 24년~ 구간만 활성 ③ 보류 3(신9·10·11): SV 미배속, 데이터 입고 후 결정. 모두 추정 금지, BRONZE/GA4 입고 후 활성·배속.

9. **반복 개선 폐루프를 전제한다.** 배포→피드백 수집→검증쿼리 추가→optimization→재배포. (배포는 범위 밖이나, 설계에 루프 자리를 만든다.)

---

## 0.1 핵심 의사결정 기록 (왜 이렇게)

| 결정 | 왜 |
|---|---|
| **별도 폴더(03)·설계문서만** | 02는 GOLD 물리설계로 완결(잠금). SV/Agent는 다음 트랙 → 섞으면 정합 깨짐. 데이터 미검증 상태라 배포 전 설계만 확정 |
| **derived는 SV metric(물리 비적재)** | 215지표 중 율%·LTV 등은 비가산 → 사전저장 시 grain 변경에 오집계. 정의 1곳 관리·변경 즉시 반영 |
| **SV 4개로 분리** | SV가 좁을수록 text-to-SQL 정확도↑. 경계는 FACT grain(=사용자가 한 질문에서 안 섞는 지점) |
| **FMM은 1 SV로 합침** | Cortex Analyst는 *한 질문=SV 1개*. 목표대비·활동·캠페인을 현업이 한 질문에 섞음 → 쪼개면 한 SQL로 못 묶음 |
| **Agent 3개·마케팅만 다중 SV** | Agent는 다중 SV 라우팅 가능(공식). FAD·FGA는 grain 달라 한 SQL로 안 섞임 → SV 분리+Agent 라우팅이 자연스러움 |
| **VQR을 정확도 1순위** | 검증쿼리는 테스트가 아니라 정확도를 *능동적으로* 올리는 공식 메커니즘 + optimization 입력 |
| **미수령 8건 placeholder** | base raw 미입고 → 추정 금지. 정의만 두고 입고 후 활성 |

---

## 1. 사전 비판 / 리스크 (착수 전 인지)

| 리스크 | 내용 | 완화 |
|---|---|---|
| 질문 카탈로그 부재 | 현업 질문 카탈로그가 PoC 소실로 미수령 → 도메인 경계·검증쿼리가 **가설** | golden Q/VQR을 가설로 작성, 현업 수령 시 재정렬·optimization |
| 데이터 미입고 | ① derived placeholder 8건(공7·10·98·108·신8·9·10·11, 메타4.4) 산출불가 ② FACT/raw 레벨 결손(FTG-B 목표·FAD 편성비/모금성비용 raw) — 층위 구분 | 원칙 8(placeholder)·BRONZE 컨트랙트 |
| SV_MEMBER 비대 | FMM 기반 metric ~48개 → "전사 vs 캠페인별" 필터축 혼동 | synonyms·VQR·instruction으로 필터축 고정, 검증으로 조기 발견; 필요시 SV 추가 분할 |
| 중복정의 지표 | #69↔70·#37↔157·신20↔#35+38 등 GOLD 미해결 충돌이 SV로 전파 | 3단계 착수 전 `GOLD_메타제약` 미해결 목록 재확인, 충돌 metric 보류 |
| 한글 NL 다양성 | "활동율/활동률/액티브" 등 표기 흔들림 | synonyms 광범위 등록(원칙 5) |

---

## 2. SV·Agent 구조 (4 SV / 3 Agent — Agent 3만 다중 SV)

> **설계 결정(확정)**: SV는 **FACT grain 경계로 4개** 분리(정확도 레버), Agent는 **3개**. 회원실적·서비스는 1 SV ↔ 1 Agent, 마케팅 Agent만 **2 SV를 라우팅**한다.
> **분리 경계 근거**: Cortex Analyst는 *한 질문당 SV 1개*로만 SQL을 만든다 → **한 질문에서 섞이는 metric은 같은 SV에 둔다**. FMM 기반(목표대비·활동·중단·캠페인·유지 등)은 현업이 한 질문에 섞으므로 **합친다**(SV_MEMBER). 반대로 FAD·FGA는 grain이 달라 한 SQL로 안 섞이므로 **나누고 Agent가 라우팅**한다.

### 2.1 Semantic View (4개)
> metric 수(~)는 **잠정 추정치**이며, 확정값은 1단계 산출물(`1_SV_metric_배속.md`)에서 81 전수 배속으로 잠근다. 본 표 수치로 코딩하지 말 것.

| # | Semantic View | base FACT | 공유 DIM | derived 범위(매핑표) | metric 수(잠정) |
|---|---|---|---|---|---|
| 1 | `SV_MEMBER` 회원실적 | FMM (+FTG-D conformed, +FGA cross) | DATE·MEMBER·CAMPAIGN·SPONSORSHIP·PAYMENT·ORG·REASON | §1 목표대비(공1~3)+§2 FMM내부(공45~80)+§6 캠페인성과(신2~29)+§5 cross(공81)+§9 시계열(공59·60) | ~48 |
| 2 | `SV_SERVICE` 서비스효과 | FSE (+FMM 코호트 JOIN) | DATE·MEMBER·SERVICE·CAMPAIGN·SPONSORSHIP | §7 서비스효과(신30~53) | ~24 |
| 3 | `SV_AD` 광고성과 | FAD (+FMM 개발연계) | DATE·CAMPAIGN·AD_CREATIVE | §3 광고(공7~10) | 4 (공7·10 placeholder) |
| 4 | `SV_GA` GA행동 | FGA | DATE·CAMPAIGN·GA_EVENT·GA_SOURCE·MEMBER_IDENTITY | §4 GA행동(공98·108) | 2 (전부 placeholder) |

> **신9·10·11 배속 보류(1단계 정정)**: 작업계획 초안은 §8(신9~11 개발단가·ROI)을 SV_GA에 잠정 배속했으나, 1단계에서 ① 소속 FACT=`FAD÷FMM`(광고)로 FGA와 grain 불일치, ② GA4/AGENCY/ERP raw 미입고로 grain 미확정이 확인됨 → **SV 배속 보류**(데이터 입고 후 결정, ▼아래 "데이터 입고 후 작업" 참조). 셋 다 placeholder라 81 총합·활성 metric 수 불변. 상세: `1_SV_metric_배속.md` §5.

### 2.2 Agent (3개) ↔ SV 매핑
| Agent | 라우팅 SV | 다중SV | 질문 도메인 |
|---|---|---|---|
| **1. 회원실적 Agent** | `SV_MEMBER` | — | 목표대비·활동율·중단율·미납율·캠페인성과·유지율·LTV·미납서비스전환(cross) |
| **2. 서비스 Agent** | `SV_SERVICE` | — | 발송율·수신율·참여율·증액율·서비스별 유지/중단 |
| **3. 마케팅 Agent** | `SV_AD` + `SV_GA` | ✅ | 광고 CTR·개발단가(SV_AD) / 세션·이탈율·스크롤(SV_GA) — grain 다름, Agent가 질문별 SV 선택 |

> **추적**: 81 전수 배속(중복0·누락0)은 1단계 산출물에서 잠금. cross-source(IDENTITY 브리지)는 **공81(SV_MEMBER, FMM×FGA)·신33(SV_SERVICE, FMM×FSE)·신32(SV_SERVICE, FSE×FGA·클릭 GA측 조건부)** 3건 → 각 SV에서 relationship+instruction으로 IDENTITY JOIN 단독 명시(상세 `1_SV_metric_배속.md` §7).
> **SV_MEMBER 비대 대비**: FMM은 결합질문 보존을 위해 *분할하지 않는다*(분할 시 한 SQL로 못 묶음). 비대(~48 metric)는 synonyms·VQR·필터축 instruction으로 잡고, 검증에서 혼동이 재현되면 그때 재평가.
> **마케팅 다중SV 라우팅 근거**: FAD·FGA를 한 SQL로 JOIN할 일이 없음(필요 시 IDENTITY cross는 SV_MEMBER 공81에서 처리) → Agent orchestration instruction이 질문 키워드(광고/클릭/단가 vs 세션/이탈/스크롤)로 SV를 선택.

---

## 3. 작업 단계

### 3.0 단계 공통 규칙 & 완료 기준(DoD)
- **착수 전**: 해당 단계가 참조하는 입력 파일(부록 B)을 읽고, 인용하는 지표번호·컬럼명을 원본에서 1:1 확인.
- **완료 기준(공통)**: ① 산출물 파일이 이 폴더에 생성됨 ② 81개 metric 추적 시 중복0·누락0 ③ 추정값 0건(불확실 항목은 "보류/placeholder/질문"으로 명시) ④ §진행 상태 표 갱신.
- **단계 간 의존**: 앞 단계 산출물이 없으면 다음 단계 착수 금지(순서 고정).

### 1단계 — derived → SV metric 배속 확정
- 매핑표 81개를 4 SV에 전수 배속. 산출가능/placeholder·가산성·시간가용성 태그 동반.
- **산출물**: `1_SV_metric_배속.md`
- **DoD**: 81행 표 완성, 각 행에 SV·base FACT·활성여부 명기. 합계 = SV별 합 = 81 검증.

### 2단계 — SV 구조 정의 (logical table · relationship · dimension · measure)
- SV별 base_table(GOLD 물리)·**relationships(FACT↔DIM 조인키)**·노출 dimension·base measure 선정.
- 각 요소에 `description`·`synonyms`(한글)·`sample_values`·`default_aggregation` 기재. 가산성 N/S는 집계 제약 명시.
- **산출물**: `2_SV_MEMBER_설계.md` · `2_SV_SERVICE_설계.md` · `2_SV_AD_설계.md` · `2_SV_GA_설계.md`

### 3단계 — SV metric expression 작성
- 매핑표 분자/분모를 metric expression으로 직역(×100·conformed JOIN·필터축·NULL 규칙 반영).
- 중복정의·미해결 충돌 metric은 "보류" 표기(원칙 4·1절).
- **산출물**: 위 4개 설계 문서 metric 절 + `SV_*.yaml` 초안(검증용, deploy 아님)

### 4단계 — Verified Queries + 평가셋 (정확도 핵심)
- SV별 대표질문→검증SQL(논리 테이블/컬럼명 사용)을 **검증쿼리**로 작성 → `AI_VERIFIED_QUERIES` 등록 대상.
- 별도로 **Cortex Analyst Evaluation용 eval dataset(질문·기대결과) + metric** 설계(공식 평가 프레임워크 정합).
- **산출물**: `4_검증쿼리_VQR.md` · `4_평가셋_eval.md`

### 5단계 — Agent 설계 (3 Agent·라우팅·instruction·tool)
- **구조 확정(2.2)**: Agent 3개. 회원실적·서비스는 1 SV, **마케팅 Agent만 SV_AD+SV_GA 2 SV 라우팅**.
- 각 Agent: 연결 SV, **orchestration instruction**(마케팅은 SV 선택 키워드 규칙 / 공통: 필터축·JOIN·시간·NULL), **response instruction**(톤·형식), `sample_questions`, tool(`cortex_analyst_text_to_sql` + 리포팅용 `data_to_chart`).
- **산출물**: `5_AGENT_spec.md` (3 Agent)

### 6단계 — 거버넌스·운영 설계
- **객체 배치 스키마(확정): `GN_DW.SERVING`** (신규 소비 계층). SV·Agent·Streamlit을 여기 배치하고, GOLD는 분석 View+예측 테이블의 **데이터 프로덕트 계층**으로 유지(오염 방지). SV는 `GN_DW.GOLD.V_*`를 cross-schema 참조.
  - 스키마 명명 주의: PoC `ANALYTICS`(=현 GOLD View)와 혼동 방지를 위해 소비 계층은 `analytics`가 아닌 `SERVING`으로 명명.
  - 전체 스키마 셋: `BRONZE`/`SILVER`/`GOLD`(데이터) · `SERVING`(소비) · `OPS`(운영) · `SECURITY`(정책). 레거시 `01_프로젝트 진행 샘플/00_GN_DW_PROJECT.md` 3.2와 정합.
- 네이밍 규약·소유권(`GN_DW_ADMIN`)·CORTEX_USER 등 권한·warehouse·query timeout.
- **권한 핵심(Viewer)**: ① `USAGE` on SERVING + `USAGE` on SV/Agent/Streamlit, ② SV가 참조하는 `GN_DW.GOLD.V_*`에 `SELECT`(Snowflake Intelligence text-to-SQL은 **호출자 세션**에서 base 객체에 실행 → underlying GOLD View SELECT 필수). GOLD View는 owner's rights라 SILVER/BRONZE 직접 권한 불필요 → Viewer는 분석된 데이터만 조회. Streamlit은 owner's rights라 `USAGE`만으로 동작.
- **반복 개선 루프**: 피드백 수집(agent feedback)→VQR 추가→Cortex Analyst optimization→재배포 절차.
- **산출물**: `6_거버넌스_운영.md`

### 7단계 — 폴더 색인·인계
- **산출물**: `00_폴더개요.md` + 배포 트랙 인계 메모

---

## 진행 순서 요약

```
1 metric배속 → 2 SV구조(relationship/synonyms) → 3 metric expr → 4 VQR+평가셋 → 5 Agent설계 → 6 거버넌스/루프 → 7 색인
                                  (deploy·optimization 실행은 범위 밖 — 데이터 검증 후 별도 트랙)
```

- **본 계획 산출물**: 설계 문서 + SV YAML 초안 + VQR/평가셋 + Agent spec (CREATE 실행 X)
- **다음 트랙(별도)**: 데이터 검증 → SV/Agent 배포 → 평가 측정 → 피드백·VQR·optimization 폐루프 → placeholder 활성

---

## 데이터 입고 후 작업 (보류 — GA4 / AGENCY / ERP 입고 트랙)

> 1단계에서 base raw 미입고·grain 미확정으로 **SV 배속을 보류**한 항목. 데이터 입고 시 grain 확정 후 배속·활성화한다.

| 트리거(입고 데이터) | 보류 metric | 할 작업 |
|---|---|---|
| **AGENCY 편성비** | 신9 캠페인별 개발단가 | grain 확정(캠페인 단위) → SV_AD 후보 배속 → metric 활성 |
| **ERP 모금성비용 세세목** | 신10 매체별 개발단가 | grain 확정(매체 단위) → SV_AD 후보 배속 → metric 활성 |
| **ERP 캠페인별 비용 + 기준 합의** | 신11 캠페인별 ROI | 캠페인별 ERP 기준 합의 선행 → grain 확정 → 배속(현재 적용불가) |
| **GA4 raw** (engagement_time·bounce·전환수·클릭) | 공98·공108·공10 | FGA/FAD placeholder 활성 + GA의존 활성지표(공81·신32·신33) 분모 산출 검증 |
| **24년 이전 평균납입회비** | 신8 LTV | 부분(24년~)→전체 기간 산출 확장 |

> 상세 배속 보류 근거·grain 미확정 사유: `1_SV_metric_배속.md` §5·§6.

---

## 진행 상태 (재개용 — 단계 완료 시 갱신)

| 단계 | 산출물 | 상태 |
|---|---|---|
| 0 | 작업계획(본 문서) | ✅ 완료 |
| 1 | `1_SV_metric_배속.md` | ✅ 완료 (81 전수 배속: MEMBER48·SERVICE24·AD4·GA2·보류3) |
| 2 | `2_SV_*_설계.md`×4 | ⬜ 대기 |
| 3 | metric expr + `SV_*.yaml` 초안 | ⬜ 대기 |
| 4 | `4_검증쿼리_VQR.md`·`4_평가셋_eval.md` | ⬜ 대기 |
| 5 | `5_AGENT_spec.md` | ⬜ 대기 |
| 6 | `6_거버넌스_운영.md` | ⬜ 대기 |
| 7 | `00_폴더개요.md`·인계메모 | ⬜ 대기 |

> 상태 enum: ⬜ 대기 / 🔄 진행 / ✅ 완료 / ⛔ 보류(사유 명시).

---

## 부록 A. 변경 이력 (changelog)

- **v3.1** (현재): 6단계 객체 배치 스키마 **확정 — `GN_DW.SERVING`**(신규 소비 계층, SV·Agent·Streamlit). GOLD는 데이터 프로덕트 계층으로 분리 유지. Viewer 권한(SERVING USAGE + GOLD View SELECT) 명문화. 레거시 `00_GN_DW_PROJECT.md`(3.2/3.6/3.7/3.8/3.9)와 정합.
- **v3**: 구조 확정 — SV 4개(`SV_MEMBER`·`SV_SERVICE`·`SV_AD`·`SV_GA`)/Agent 3개, 마케팅 Agent만 다중 SV 라우팅. 실행 가이드·약어 키·DoD·진행 상태표 추가(LLM 실행 안정화).
- **v2**: Snowflake 공식 best practice 반영(아래 표).

### v1 → v2 best practice 반영표

| 항목 | v1 | v2 정정 |
|---|---|---|
| Agent↔SV | 1:1 강제 | **분리**: SV 입도(정확도 레버) vs Agent 수(거버넌스) 별개. Agent는 다중 SV 라우팅 가능 |
| 검증쿼리 | 없음 | **VQR `AI_VERIFIED_QUERIES`를 정확도 1순위로 추가**(4단계) |
| 시맨틱 품질 | 미언급 | synonyms(한글)·description·sample_values·relationships·default_aggregation 의무화(2단계) |
| 평가 | 임의 golden Q | **공식 Evaluation 프레임워크** 정합 eval dataset+metric(4단계) |
| 개선 | 일방향 | **피드백→VQR→optimization 폐루프**(원칙 9·6단계) |
| 거버넌스 | 없음 | 스키마/네이밍/권한/warehouse/timeout(6단계) |
| 리포팅 | 없음 | `data_to_chart` 툴(5단계) |
| 시간/NULL | 없음 | custom instruction 강제(원칙 7) |

## 부록 B. 입력 문서 참조
| 입력 | 위치 | 용도 |
|---|---|---|
| derived 매핑(SSOT) | `02_top-down 설계/GOLD_파생지표 매핑.md` | metric 분자/분모·소속 FACT |
| FACT 설계 | `02_top-down 설계/GOLD_팩트 설계.md` | base measure·가산성·grain |
| DIM 설계 | `02_top-down 설계/GOLD_차원 설계.md` | dimension·conformed·조인키 |
| 메타·미해결 | `02_top-down 설계/GOLD_메타제약 확인.md` | 시간가용성 enum·중복정의 충돌 |
| DDL | `02_top-down 설계/GOLD_ddl 초안.sql` | base_table 실제 컬럼명 |

## 부록 C. Best practice 출처 (Snowflake 공식 문서)
- Create and manage agents — 다중 SV 라우팅·orchestration/response instruction·sample_questions·tools(data_to_chart)·feedback: `/user-guide/snowflake-cortex/cortex-agents-manage`
- Cortex Analyst Verified Query Repository / Semantic View 검증쿼리(`AI_VERIFIED_QUERIES`, 2026-04): `/user-guide/snowflake-cortex/cortex-analyst/verified-query-repository`
- Optimize semantic view/model with verified queries(폐루프): `/user-guide/snowflake-cortex/cortex-analyst/analyst-optimization`
- YAML spec for semantic views(synonyms·description·sample_values·relationships): `/user-guide/views-semantic/semantic-view-yaml-spec`
- Cortex Analyst / Agent evaluations: `/user-guide/snowflake-cortex/cortex-analyst-evaluations`, `/user-guide/snowflake-cortex/cortex-agents-evaluations`
- Custom instructions in Cortex Analyst: `/user-guide/snowflake-cortex/cortex-analyst/custom-instructions`
