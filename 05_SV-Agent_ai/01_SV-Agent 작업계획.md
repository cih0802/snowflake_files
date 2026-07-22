<!-- LLM-METADATA
doc_id: SV_AGENT_WORKPLAN
doc_role: Semantic View + Cortex Agent 설계·배포 작업계획 (정본, v4.2)
project: GN_DW (굿네이버스)
created: 2026-07-21
supersedes: _archive/00_SV-Agent 작업계획_legacy.md (v3.1 — 설계문서 only)
scope: SV/Agent 실배포 + Snowflake Intelligence(CoWork) 연결 + 평가·거버넌스
inputs: 03_top-down_gold/ (GOLD 실물 star schema) + 20_issue/ (데이터 게이트·미결)
END-METADATA -->

# Semantic View · Agent 작업계획 (GN_DW · v4.2)

> 굿네이버스 GN_DW **Semantic View(SV) + Cortex Agent 설계·배포·운영 작업계획서**.
> **레거시(`_archive/00_SV-Agent 작업계획_legacy.md`, v3.1)와의 결정적 차이**: 레거시는 *"설계 문서 산출까지, `CREATE` 금지"* 였다. **본 v4는 GOLD 스타스키마 실물이 완성(2026-07-20)된 것을 전제로, 실제 `CREATE SEMANTIC VIEW`/`CREATE AGENT` 배포 → Snowflake Intelligence(CoWork) 연결 → 평가·거버넌스까지의 end-to-end 계획이다.**
> 사용자 확정 사항(2026-07-21): ① 범위 = **실배포까지** ② SV base = **GOLD base DIM/FACT**(WIDE 뷰 아님) ③ **Agent 3개 고정(회원/마케팅/overall)** ④ **SV 개수는 text-to-SQL 정확도 best practice로 설계**(개수 고정 아님).

---

## ★ 실행 가이드 (이 문서를 실행하는 에이전트 필독)

**착수 전 반드시:**
1. 입력 SSOT를 먼저 읽는다 — `03_top-down_gold/04_SV파생 매핑.md`(derived 81 분자/분모·소속 FACT), `03_테이블 설계.md`(9 FACT·15 DIM grain), `06_DDL.sql`(실제 컬럼명), `07_메타.md`(시간가용성·미해결 충돌), `20_issue/00_INDEX_이슈원장.md`(데이터 게이트).
 2. `_archive/1_SV_metric 배속.md`는 **레거시 4-SV 구조 기준**이다 → 본 v4의 **7-SV 구조로 재배속(1단계)** 하기 전까지 그대로 신뢰하지 말 것(metric↔FACT 매핑만 재사용).
3. 3절 단계를 **순서대로** 수행하고, 산출물은 이 폴더(`05_SV-Agent_ai/`)에 단계번호 접두사로 쓴다. 진행상태표를 갱신한다.

**DO NOT (오류 방지):**
- ❌ 지표 번호(공N·신N)·분자/분모·base measure·컬럼명·조인키 **추정/창작 금지.** 반드시 SSOT에서 확인 후 인용.
- ❌ derived 수식 **재정의 금지** — `04_SV파생 매핑.md` 직역(율%는 ×100, 가산성 N/S는 SUM 재집계 금지).
- ❌ `03_top-down_gold/` 입력 문서 **수정 금지**(읽기 전용).
- ❌ 데이터 미입고·미해결(FTG_B 0행·FGA 1일 샤드·FAD 차원FK 0·현업 A~G) 항목을 **채워 넣지 말 것** → placeholder/보류로만 표기.
- ⚠️ 불확실하면 멈추고 질문. 가정으로 배포하지 않는다.

## ★ 약어 키
| 약어 | 뜻 |
|---|---|
| SV / Agent | Semantic View / Cortex Agent |
| SI / CoWork | Snowflake Intelligence / Snowflake CoWork (Agent 소비 UI) |
| FMM·FME·FTG_D·FTG_B·FSE·FGA·FAD·FEP·FBD | 9 GOLD FACT (아래 1절 표) |
| 공N / 신N | 공통지표 N / 신규지표 N |
| A / S / N | 가산 / 준가산 / 비가산 measure |
| conformed / cross | 공유차원 정합 조인 / cross-source(IDENTITY 브리지) 조인 |
| VQR | Verified Query (`AI_VERIFIED_QUERIES`) — 정확도 1순위 메커니즘 |
| placeholder | metric 정의만 두고 비활성(base raw 미입고) |

---

## 0. 설계 원칙 (v4 확정)

1. **실배포 트랙이다.** GOLD 물리(15 DIM + 9 FACT + 9 WIDE view)가 `GN_DW.GOLD`에 배포 완료됨(2026-07-20). SV/Agent를 실제 `CREATE` 하고 SI/CoWork에 연결한다.

2. **SV base = GOLD base DIM/FACT 테이블 + relationships.** WIDE 뷰가 아니라 정규 star(FACT + conformed DIM)를 SV logical table로 쓰고 relationship(FACT↔DIM 조인키)을 명시한다. 근거: Snowflake 공식 — *"We recommend starting with a simple star schema."* 조인 규칙을 SV가 governed하게 관리 → Routing Mode 정확도↑.

3. **SV 경계 = FACT grain (정확도 레버).** Snowflake 공식: *"Start with a small, focused scope (3–5 tables per view). This ensures higher accuracy than a massive do-it-all model."* + Cortex Analyst는 **한 질문 = SV 1개**로 SQL을 만든다 → **grain이 다른 FACT는 SV를 나눈다.** 9 FACT → **7 SV**(목표 FACT 2개는 conformed 폴딩, 1절).

4. **Agent 3개 고정, 다중 SV 라우팅.** 한 Agent가 여러 SV를 tool(`cortex_analyst_text_to_sql`)로 라우팅할 수 있다(공식). 회원/마케팅/overall Agent가 도메인 SV들을 라우팅한다(2절). orchestration instruction이 질문 키워드로 SV를 선택.

5. **derived 정의는 `04_SV파생 매핑.md`가 SSOT.** 분자/분모를 metric expression으로 직역. 물리 비적재(P7: 율·누계·증감은 SV time-intelligence). 예외: GA4 사전집계 비가산(#98·#108)은 FGA 물리컬럼 직접 노출.

6. **시맨틱 품질을 1급 산출물로.** 모든 dimension/measure/metric에 `synonyms`(**한글 동의어 필수**)·`description`·`sample_values`·`default_aggregation`·relationships. Cortex Analyst 정확도의 토대.

7. **VQR을 정확도 1순위.** golden question → `AI_VERIFIED_QUERIES` 등록. 평가(Cortex Analyst Evaluation)는 VQR을 ground truth로 사용(**run당 SV 1개**). 피드백→VQR 추가→optimization→재배포 폐루프.

8. **시간가용성·NULL을 custom instruction으로 강제.** `07_메타.md` 시간 enum(전체가능/24년~/25년~/2개년/적용불가)을 SV instruction에 명문화("24년 이전 구간 조회 시 제외/NULL").

9. **데이터 현황이 배포 순서를 가른다.** 실적재된 FACT부터 배포(Phase 1), 입고 대기 FACT는 placeholder/보류(Phase 2). 추정 금지 — 2절.

10. **1 SV = 1 base FACT (fan-out 방지).** 한 SV에 grain이 다른 FACT 2개를 직접 조인하면 Cortex Analyst가 measure를 중복집계(fan-out)할 수 있다. 목표대비(FMM×FTG_D)·cross-source(FMM×FGA=공81·FSE×FGA=신32·FSE↔FMM=신33)는 **① conformed grain으로 미리 집계한 GOLD 브리지 뷰를 단일 논리테이블로 노출**하거나, **② 정합이 확실치 않으면 Phase 2로 보류**한다. raw 다중 FACT 조인 SV 금지. (검증: fan-out 스모크 = 조인 후 measure 합 = 단일 FACT 합)

11. **고카디널리티 텍스트 차원 = Cortex Search 백킹.** 회원명·캠페인명·조직명·세세목명처럼 값이 많은 문자열 차원은 SV dimension에 `cortex_search_service`를 연결해 리터럴 필터를 해소한다(미연결 시 "값 못 찾음"·오매칭). 저카디널리티 코드/enum은 `sample_values`로 충분.

12. **SV·Agent는 형상관리·재현 배포(IaC).** 모든 `CREATE SEMANTIC VIEW`/`CREATE AGENT` DDL을 소스관리(가능하면 dbt `semantic_view` materialization 또는 DCM)로 버전관리하고, **GOLD DDL 변경 시 SV 회귀검증(스모크 + eval 재실행) 후 재배포**한다. 손수 실행분도 `05_SV_DDL.sql`·`08_AGENT_spec.md`에 정본으로 보존.

---

## 0.1 핵심 의사결정 기록 (왜 이렇게)

| 결정 | 왜 |
|---|---|
| **레거시 4-SV → v4 7-SV** | 레거시는 metric 많은 4 FACT(FMM·FSE·FAD·FGA)만 SV화했으나, GOLD 9 FACT 실물이 완성됨 → 모든 grain을 covered. grain당 1 SV가 best practice(focused scope) |
| **SV base = GOLD base 테이블(WIDE 뷰 아님)** | 사용자 확정. relationship을 SV가 governed 관리 → 조인 정확도↑. WIDE 뷰는 조인 pre-bake돼 편하나 relationship 표현력·필터축 제어를 잃음. GOLD 뷰 SELECT 권한만 있으면 base 조인 가능 |
| **Agent 3개(회원/마케팅/overall)** | 사용자 확정. 현업 질문 도메인 경계와 일치. 레거시도 Agent는 3개였음(회원/서비스/마케팅) → 서비스를 회원 도메인에 흡수, 예산·전사를 overall로 신설 |
| **SV는 grain당 분리(개수 비고정)** | 정확도 레버. 한 SV에 grain 섞으면 text-to-SQL 혼동. 7개는 focused SV들의 결과지 목표가 아님 |
| **실배포 + SI/CoWork 연결** | GOLD 실물 완성 → 소비 계층까지 가치사슬 완결. CoWork에서 자연어 질의 |
| **미입고 FACT = Phase 2** | FTG_B(0행)·FGA(1일 샤드)·FAD(차원FK 0)는 지금 배포해도 오답/공란 → placeholder·보류로 격리, 입고 후 활성 |
| **객체 배치: SV·Agent → `GN_DW.SERVING` (정본 02 P7)** | 정본 `02_GN_DW_building` **P7(serving_separation)** 에 정합 — SV/Agent(/Streamlit)는 GOLD가 아닌 **SERVING** 스키마에 배치하고 `GN_DW.GOLD.FACT_*/DIM_*`를 **cross-schema 참조**. 데이터 격리는 스키마가 아니라 **GOLD owner's rights(P3) + role scope + row access policy**로 달성(Cortex Analyst는 caller 세션에서 GOLD base에 직접 실행 → 소비 role은 GOLD SELECT 필요). Agent는 임의 스키마 가능하므로 SERVING에 두고 **가시성은 CoWork object로 큐레이션**. ※ 구 `SNOWFLAKE_INTELLIGENCE.AGENTS`는 **deprecated → 사용 안 함**. |

---

## 0.2 리스크·가드레일 (착수 전 체크리스트)

> 후속 단계에서 오답·버그를 유발하는 알려진 함정. 각 단계 DoD에서 확인.

| # | 리스크 | 가드레일 | 반영 위치 |
|---|---|---|---|
| R1 | 다중 FACT 조인 **fan-out**(목표대비·cross-source) → measure 중복집계 | conformed 브리지 뷰로 단일 논리테이블화 or Phase 2 보류. fan-out 스모크 필수 | 원칙10·1절·3단계 DoD |
| R2 | **고카디널리티 차원** 리터럴 미해소 → "값 못 찾음"/오매칭 | Cortex Search 백킹(`cortex_search_service`) | 원칙11·2단계 |
| R3 | **GA4 1일 샤드**(4.22%)로 cross/GA metric 왜곡 | GA 의존 metric = Phase 2·instruction에 커버리지 고지 | 2절·R1 |
| R4 | **FEP EVENT_KEY 고아 23%**(이슈 E) → 참여 누락 | Unknown(0) 라우팅·instruction 커버리지 고지 | 2절 |
| R5 | **가산성 오집계**(N/S measure를 SUM) | `default_aggregation` 명시·율/누계/증감은 metric로만(P7). ⚠2026-07-22: DDL 배포 시 `default_aggregation`은 **YAML 모델 개념** → DDL에선 **METRIC=SUM/COUNT 집계식·FACT=행수준**으로 구현(S-class는 `NON ADDITIVE BY`). `05_SV_DDL.sql`·04 정정로그#5·6 | 원칙5·6·2단계 |
| R6 | **GOLD DDL 변경 → SV stale** | 회귀검증(스모크+eval) 후 재배포·형상관리(IaC) | 원칙12·7단계 |
| R7 | **시간범위 밖 조회**(24년 이전 등) → 잘못된 0/부분값 | custom instruction에 시간 enum 명문화 | 원칙8·2단계 |
| R8 | placeholder metric을 **추정값으로 채움** | 정의만·비활성 주석. 추정 금지 | DO NOT·1절 |

---

## 1. SV 구조 (best practice — 최종 7 SV / 3 Agent · **Phase-1 배포 = 5 SV / 2 Agent**)

> 원칙 3: **SV = FACT grain + conformed DIM(3~6 테이블)**. 목표 FACT(FTG_D·FTG_B)는 독립 SV가 아니라 소비 SV에 conformed 폴딩. 각 SV의 metric 전수 배속은 **1단계 산출물**(`03_SV_metric_배속.md` 재작성)에서 잠근다 — 아래 표의 metric 수는 잠정.

### 1.1 9 FACT → 7 SV 매핑

| SV | base FACT (grain) | conformed/cross | 소속 Agent | 데이터 상태 | derived 범위(04매핑) |
|---|---|---|---|---|---|
| `SV_MEMBER_MONTHLY` | **FMM** 월×회원 | +FTG_D(목표대비 conformed)·+FGA(공81 cross) | 회원 | ✅ 40.05M | §2 활동/중단/미납/납입(공45~80)·§1 목표대비(공1~3)·§6 캠페인성과(신12~29)·§9 시계열(공59·60)·공81 |
| `SV_MEMBER_EVENT` | **FME** 일×회원×상태전이 | — | 회원 | ✅ 4.6M | §3-1 유지기간·LTV(신2~8)·주간/일 중단(공58)·cohort base |
| `SV_SERVICE` | **FSE** 일×회원×서비스×캠페인 | +FMM(코호트 조인)·+FGA(신32 cross 조건부) | 회원 | ✅ 38.5M | §7 서비스효과(신30~53) |
| `SV_EVENT_PARTICIPATION` | **FEP** 일×회원×행사 | — | 회원 | ✅ 1.1M | 행사 참여(O11 총참여수 등 base 집계) |
| `SV_AD` | **FAD** 일×캠페인×소재 | +FMM(개발단가 연계) | 마케팅 | ⚠️ 235K **스캐폴드**(measure/날짜만·차원FK=0) | §3 광고 CTR/개발단가(공7~10) |
| `SV_GA` | **FGA** 일×identity×이벤트×소스 | +DIM_MEMBER_IDENTITY | 마케팅 | ⚠️ 44.9K **GA4 1일 샤드만** | §4 GA행동(공98·108) |
| `SV_BUDGET` | **FBD** 월×ORG×세세목 | +FTG_B(사업목표)·+FMM(ROI 연계) | overall | ✅ 24.5K(편성/집행) · FTG_B **0행** | 예산/집행/개발단가·ROI(신9~11 보류) |

> **7 SV 근거**: FMM(월 스냅샷)·FME(일 전이)·FSE(발송)·FEP(참여)·FAD(광고)·FGA(GA)·FBD(예산)는 grain이 전부 달라 한 SQL에 안 섞임 → 분리가 정확도에 유리. 목표 FACT FTG_D(개발목표)·FTG_B(사업목표)는 독립 질의 대상이 아니라 "실적 대비 목표" 형태로만 쓰이므로 각각 SV_MEMBER_MONTHLY·SV_BUDGET에 conformed 폴딩.
> ⚠️ **위 `+conformed/+cross` 표기는 "raw 다중 FACT 조인"이 아니다(원칙 10·R1).** 목표대비(FMM×FTG_D)·cross-source(공81·신32·신33)는 반드시 **conformed grain 브리지 뷰**(GOLD에 사전집계)를 단일 논리테이블로 노출하거나, 정합 미확정 시 **Phase 2 보류**. 2단계에서 브리지 설계 없이 두 FACT를 직접 relationship으로 잇지 말 것. cross-source(FGA 의존)는 기본 Phase 2.

> **▶ 결정 로그 (2026-07-22) — Phase-1 스코프 & 검토 결과**
> - **배포 = 5 SV**(SV_MEMBER_MONTHLY·SV_MEMBER_EVENT·SV_SERVICE·SV_EVENT_PARTICIPATION·SV_BUDGET). SV_AD·SV_GA는 base FACT(FAD 스캐폴드·FGA 1일 샤드) 미완 → **Phase-2 신규 추가**(트리거 G-5).
> - **얇은 SV도 현행 유지**: 데이터 입고 시 동일 SV의 같은 테이블·관계 위에 **METRIC/DIMENSION만 추가(in-place)**로 두꺼워짐 → 재설계 불요. grain 상이 SV(FMM 월×회원 vs FME 일×전이) **병합 금지**(fan-out·가산성 붕괴).
> - **문서 정정(2026-07-22)**: 03·04·01의 A1/A3 이전 stale 스냅샷 정정(FMM 40.05M·DEV/STOP·SERVICE_SK 활성), FME grain 비유일 반영, `default_aggregation`→DDL METRIC 용어 정합.
> - **DDL 검증 결과**: 5 SV fan-out/가산성 DoD PASS(06 §1). **PK 정정**(유일 FMM·FBD만 선언). **결함 수정**: `SV_MEMBER_EVENT.AVG_RETENTION_MONTHS` 전건 NULL(가입↔중단 페어링 불가) → 제거·재배포 완료(SV=FACT 재검증 일치).

### 1.2 Agent (최종안 3개 · Phase-1 실배포 2개) ↔ SV 라우팅

> **▶ Agent 배포 스코프 (2026-07-22)**: **최종 설계 = 3 Agent**(회원·마케팅·overall). 단 **Phase-1 실배포 = 2 Agent**(회원·overall)뿐이다. **마케팅 Agent는 base FACT(FAD·FGA)의 원천 bronze 데이터 자체가 불완전**(FAD 스캐폴드·차원FK=0, FGA GA4 1일 샤드만)하여 오답 방지를 위해 **Phase-2로 유예**한다(트리거 G-5·Q10). 아래 표의 마케팅 Agent 행은 **최종 설계 기준**이며 Phase-1에서는 미배포다. 이하 문서 전반의 "3 Agent" 표기는 모두 **최종안**을 뜻하며, 실제 배포본은 항상 **2 Agent**임에 유의.

| Agent | 라우팅 SV | 다중SV | 질문 도메인 |
|---|---|---|---|
| **1. 회원 Agent** | `SV_MEMBER_MONTHLY` · `SV_MEMBER_EVENT` · `SV_SERVICE` · `SV_EVENT_PARTICIPATION` | ✅ (4) | 목표대비·활동/중단/미납/납입율·캠페인성과·유지율·LTV·서비스 발송/참여/증액·행사참여·미납서비스전환(cross) |
| **2. 마케팅 Agent** ⚠️Phase-2 | `SV_AD` · `SV_GA` | ✅ (2) | 광고 CTR·개발단가(AD) / 세션·이탈율·스크롤·GA 행동(GA) — grain 다름, 질문별 SV 선택. **bronze 원천 미완으로 Phase-1 미배포** |
| **3. overall Agent** | `SV_BUDGET` (Phase 1) · 전사요약 시 `SV_MEMBER_MONTHLY`·`SV_SERVICE` 추가 라우팅(선택) | ✅ (1~3) | 예산 편성/집행·개발단가·ROI·사업목표 대비·재무 요약. **전사 cross-domain 요약은 다중 SV 라우팅으로, 질의마다 단일 SV로 분해**(cross-fact 계산 금지) |

> **cross-source/cross-fact 3건은 raw relationship 금지(원칙10·R1)** — 공81(FMM×FGA)·신33(FMM×FSE)·신32(FSE×FGA)는 **conformed grain 브리지 뷰**로만 구현하고 해당 SV에 단일 논리테이블로 노출. GA 의존분(공81·신32)은 기본 **Phase 2**에서 커버리지 재검증(FGA 1일 샤드 4.22%).
> **회원 Agent 4-SV 라우팅**: orchestration instruction이 질문 키워드로 SV 선택(월실적→MONTHLY / 주간·일·유지→EVENT / 발송·참여·증액→SERVICE / 행사→PARTICIPATION). 각 SV는 focused(정확도↑), Agent가 라우팅(공식 지원).

---

## 2. 데이터 현황 게이트 (배포 Phase 결정)

> 실측 행수(2026-07-20)와 `20_issue/` 게이트. 배포 순서를 이 표가 가른다(원칙 9).

| SV | FACT 행수 | Phase | 근거·게이트 |
|---|---:|---|---|
| SV_MEMBER_MONTHLY | 40,054,883 | **1 (즉시)** | 실적재(2026-07-22 정정: 구 37,792,336은 HAS_BILLING 부분집합). 목표대비(공1~3)의 FTG_D=7,272 ✅ / FTG_B(사업목표대비)는 **0행 → Phase 2**(문서40 E-6) |
| SV_MEMBER_EVENT | 4,633,105 | **1 (즉시)** | 실적재. 유지율/LTV cohort는 FME 기반 산출가능(신8 LTV는 24년~ 부분) |
| SV_SERVICE | 38,470,780 | **1 (즉시)** | 실적재. 단 신32/33 GA 클릭명은 FGA 의존 → 해당 metric만 Phase 2 |
| SV_EVENT_PARTICIPATION | 1,134,126 | **1 (즉시)** | 실적재. ⚠️ EVENT_KEY→DIM_EVENT 고아 23%(이슈 E, Unknown(0) 라우팅) → instruction에 커버리지 고지 |
| SV_BUDGET | 24,480 | **1 (부분)** | FBD 편성/집행 ✅ / 모금성비용·광고비(E-1·E-4)·FTG_B(E-6)·캠페인 ROI(O3) = **Phase 2** |
| SV_AD | 235,572 | **2 (보류)** | FAD **스캐폴드**(measure/날짜만·CAMPAIGN/CREATIVE/DEVICE FK=0). CTR(공9)은 부분 가능하나 개발단가(공7·8)는 conform 조인 불가 → 차원FK 보강(Q10 캠페인 연결키) 후 |
| SV_GA | 44,905 | **2 (보류)** | FGA **GA4 1일 샤드만**(G-5 전기간 입고 대기). #98·108 placeholder. identity 4.22% → 커버리지 확정치 오인 금지 |

**Phase 1 (즉시 배포 가능)**: 회원 Agent(4 SV) + overall Agent(SV_BUDGET 부분) → 현업 회원/서비스/예산 질의 대부분 커버.
**Phase 2 (데이터 입고 후)**: 마케팅 Agent(SV_AD·SV_GA), 목표대비 사업(FTG_B), 개발단가·ROI(신9~11), GA cross metric(공81 분모·신32·33). 트리거: G-5(GA4 전기간)·E-6(CRM 사업목표)·E-1/E-4(ERP/AGENCY 비용)·Q10(캠페인 연결키).

---

## 3. 작업 단계

### 3.0 단계 공통 규칙 & 완료기준(DoD)
- **착수 전**: 참조 입력 파일을 읽고 인용 지표번호·컬럼명을 원본에서 1:1 확인.
- **완료기준(공통)**: ① 산출물 생성 ② 81 derived 추적 시 중복0·누락0 ③ 추정값 0(불확실=보류/placeholder/질문 명시) ④ 진행상태표 갱신.
- **단계 의존**: 앞 단계 산출물 없이 다음 단계 착수 금지.

### 0단계 (전제) — SERVING 스키마·권한·CoWork object 생성 [⚠️ 미생성 상태]
> `SHOW SCHEMAS`(2026-07-20) 기준 `GN_DW.SERVING` **미생성**(BRONZE_*/SILVER/GOLD/SECURITY/OPS/PUBLIC만 존재). 3단계 CREATE SV 전에 반드시 선행.
- `CREATE SCHEMA GN_DW.SERVING`(정본 6스키마 셋, `02_GN_DW_building` P7).
- 권한: 소비 역할(`GN_DW_ANALYST`/`VIEWER`/`SERVICE`)에 SERVING USAGE + GOLD SELECT(§7 권한). SV/Agent 생성·소유 역할 지정.
- CoWork object: `CREATE SNOWFLAKE INTELLIGENCE …`(가시성 큐레이션용, 5·6단계에서 `ADD AGENT`). 구 `SNOWFLAKE_INTELLIGENCE.AGENTS` 미사용.
- **산출물**: `02_SERVING_setup.sql`. **DoD**: SERVING 생성 확인·소비 역할 grant 검증.

### 1단계 — derived → 7 SV 재배속
- `04_SV파생 매핑.md` 81개(+215 base measure)를 **v4의 7 SV**에 전수 재배속. 각 행: SV·base FACT·활성여부(활성/부분/placeholder/보류)·가산성·시간가용성.
- 레거시 `_archive/1_SV_metric 배속.md`(4-SV)를 참고하되 **SV_MEMBER 48 → MONTHLY/EVENT/SERVICE/PARTICIPATION로 재분해**, SV_AD/SV_GA 유지, SV_BUDGET 신설.
- **산출물**: `03_SV_metric_배속.md` (재작성). **DoD**: SV별 합 = 81, 데이터 Phase 태그 동반.

### 2단계 — SV 구조 정의 (logical table·relationship·dimension·measure)
- SV별 base_table(GOLD 물리)·relationships(FACT↔DIM 조인키, `06_DDL.sql` 실컬럼)·노출 dimension·base measure(fact) 선정.
- 각 요소 `description`·`synonyms`(한글)·`sample_values`·`default_aggregation`. 가산성 N/S 집계 제약 명시(R5).
- **cross-fact/목표대비 브리지 설계(R1)**: 공81·신32·신33·목표대비는 GOLD에 conformed grain 사전집계 **브리지 뷰**를 정의(2단계 산출물에 DDL 초안). raw 다중 FACT relationship 금지.
- **고카디널리티 차원 = Cortex Search 백킹(R2)**: 회원명·캠페인명·조직명·세세목명 등은 backing `cortex_search_service` 대상으로 식별(GOLD/SERVING에 서비스 생성 항목 명시).
- **산출물**: `04_SV_설계.md` (7개, SV당 1개 또는 Agent 도메인별 묶음).

### 3단계 — SV metric expression + `CREATE SEMANTIC VIEW` DDL
- 분자/분모를 metric expression으로 직역(×100·conformed JOIN·필터축·시간/NULL instruction).
- **Phase 1 SV 5개 실제 `CREATE SEMANTIC VIEW` 배포**(`GN_DW.SERVING`, GOLD FACT/DIM cross-schema 참조). placeholder metric은 정의만(비활성 주석). Phase 2 SV는 DDL 초안만.
- **산출물**: `05_SV_DDL.sql`(CREATE 문) + 배포 검증(`SELECT FROM SEMANTIC_VIEW(...)` 스모크).
- **DoD**: Phase 1 SV 5개 `SHOW SEMANTIC VIEWS`에 존재, 대표 질의 semantic SQL 성공. **fan-out 스모크(R1)**: 브리지/조인 measure 합 = 단일 FACT 합 일치 확인. 가산성 N/S measure의 SUM 오집계 없음.

### 4단계 — Verified Queries + 평가셋
- SV별 대표질문→검증SQL을 VQR로 작성 → Snowsight SV 에디터/`AI_VERIFIED_QUERIES` 등록.
- Cortex Analyst Evaluation 셋(질문·기대SQL) 설계 → `EXECUTE_AI_EVALUATION`으로 baseline 측정(run당 SV 1개). 절대 날짜 사용(time-relative 금지).
- **산출물**: `06_검증쿼리_VQR.md` · `07_평가셋_eval.md` + 등록/실행.

### 5단계 — Agent `CREATE AGENT` + 라우팅 (최종 3개 / Phase-1 배포 2개)
- 최종 설계 Agent 3개(회원/마케팅/overall): 연결 SV, **orchestration instruction**(SV 선택 키워드·필터축·JOIN·시간·NULL), **response instruction**(톤·형식), `sample_questions`, tools(`cortex_analyst_text_to_sql` per SV + `data_to_chart`).
- **Phase 1 실배포 = 2개**(회원 Agent + overall Agent). **마케팅 Agent는 base FACT(FAD·FGA) 원천 bronze 데이터가 불완전**(FAD 스캐폴드·FGA GA4 1일 샤드) → spec만 확정하고 **Phase 2 배포로 유예**(SV_AD/GA 입고 대기).
- **산출물**: `08_AGENT_spec.md` + `CREATE AGENT` DDL.

### 6단계 — Snowflake Intelligence(CoWork) 연결
- 배포 Agent를 SI/CoWork에 노출(Agent가 SI 소비 UI에 나타남). CoWork custom tool 대비 stage/proc/function USAGE 부여.
- 스모크: CoWork 챗에서 회원/예산 자연어 질의 → 정답 SQL·차트 확인.
- **산출물**: `10_SI연결_검증.md`.

### 7단계 — 거버넌스·운영·폐루프
- **객체 배치(정본 `02_GN_DW_building` P7 정합)**: **SV·Agent(·Streamlit) → `GN_DW.SERVING`**(소비 계층). GOLD는 star 데이터 모델 계층으로 유지하고, SV는 `GN_DW.GOLD.FACT_*/DIM_*`를 **cross-schema 참조**(`SERVING→GOLD→SILVER→BRONZE` 단방향). WIDE 뷰(OBT)는 현업 BI/Streamlit용 owner's rights 뷰로 유지. **Agent는 임의 스키마 배치 가능 → `GN_DW.SERVING`에 두고 가시성은 CoWork object(`CREATE SNOWFLAKE INTELLIGENCE …` + `ADD AGENT`)로 큐레이션**. ※ 구 `SNOWFLAKE_INTELLIGENCE.AGENTS` 스키마는 **deprecated → 사용하지 않음**. (스키마 정본 DDL: `02_GN_DW_building/02_DB_BRONZE_SILVER.md` §3.1의 6스키마 / GOLD 통합형 `01_project_sample_legacy/`는 참고용)
- **권한(정본 02 role scope 정합)**: 소비 역할 `GN_DW_ANALYST`·`GN_DW_VIEWER`·`GN_DW_SERVICE` = `GN_DW.SERVING` USAGE + SV/Agent USAGE + **`GN_DW.GOLD` SELECT**(Cortex Analyst가 caller 세션에서 GOLD base에 직접 실행 → 필수. GOLD는 owner's rights(P3)라 SILVER/BRONZE 직접권한 불필요). **부서/role별 데이터 제한**은 스키마가 아니라 `GN_DW.SECURITY`의 **row access policy·masking policy** + role로. CoWork custom tool용 stage/proc/function USAGE.
- **폐루프**: agent feedback → VQR 추가 → Cortex Analyst optimization(Improve) → 재배포.
- **형상관리·회귀(IaC, 원칙12·R6)**: SV/Agent DDL을 소스관리(dbt `semantic_view` 또는 DCM). **GOLD DDL 변경 시** 영향 SV 스모크 + eval 재실행 후에만 재배포. 배포 이력·버전 태그 보존.
- **Phase 2 활성화 절차**: 입고 트리거별(G-5/E-6/E-1·4/Q10) SV placeholder→활성, 마케팅 Agent 배포, eval 재측정.
- **산출물**: `11_거버넌스_운영.md`.

### 8단계 — 폴더 색인·인계
- `00_README.md` 갱신(v4 구조), 인계 메모.

---

## 진행 순서 요약

```
0 SERVING 스키마·권한·CoWork object 생성(전제) → 1 재배속(7 SV) → 2 SV구조+브리지/Search설계
→ 3 CREATE SV(Phase1 5개) → 4 VQR+평가셋 → 5 CREATE AGENT(회원·overall) → 6 SI/CoWork 연결
→ 7 거버넌스/폐루프 → 8 색인
   Phase 2(데이터 입고 후): SV_AD·SV_GA 배포 → 마케팅 Agent 배포 → placeholder 활성 → eval 재측정
```

---

## 진행 상태 (재개용)

| 단계 | 산출물 | 상태 |
|---|---|---|
| — | 작업계획(본 문서 v4.2) `01_SV-Agent 작업계획.md` | ✅ 완료 |
| 0 | `02_SERVING_setup.sql` (SERVING 스키마·권한·CoWork object) | ✅ 완료 (2026-07-21) — RBAC 전체 선행 구축(WH 3·역할 6·계층·GOLD/SILVER/BRONZE grant) + SERVING(owner GN_DW_ADMIN) + CoWork object. DoD 검증: ANALYST GOLD SELECT ✅·VIEWER SERVING USAGE ✅ |
| 1 | `03_SV_metric_배속.md` (7 SV 재배속) | ✅ 완료 (2026-07-21) — derived 81 전수 재배속(MONTHLY 40·EVENT 8·SERVICE 24·PARTICIPATION 0·AD 4·GA 2·BUDGET 3=81, 중복0·누락0). Phase: P1 69·P2 12. 레거시 SV_MEMBER 48→grain분리(FME 8 이관) |
| 2 | `04_SV_설계.md` (+브리지·Cortex Search 식별) | ✅ 설계완료 / ⛔ **데이터 게이트 발견** (2026-07-21) — 7 SV 구조·비판검토·fan-out helper 검증 완료. **단 실측 결과 GOLD 차원 FK(CAMPAIGN/SERVICE/PAYMENT/ORG_SK)·FMM 카운트 measure·NEW_EXISTING_FLAG 전건 미적재** → 실활성 지표 극소수(§0.6). 3단계 스코프 결정 필요 |
| 3 | `05_SV_DDL.sql` (Phase 1 CREATE) | ✅ **배포·검증 완료** (2026-07-22) — SV 5개 `CREATE SEMANTIC VIEW` + GRANT REFERENCES,SELECT(ANALYST/VIEWER/SERVICE) 사용자(GN_DW_ADMIN) 실행 완료. **fan-out 스모크 PASS**: 납입회비 SV=FACT 895,178,309,108 일치·발송수 38,470,780 일치·성별×개발건 합 3,594,843=FME 총계(회원조인 fan-out 0). 실측 활성분만 노출(공64·공80·개발/중단·유지기간·발송·참여·예산). **PK 정정**: 유일 FMM·FBD만 선언, 비유일 FME/FSE/FEP 미선언. SHOW: 5개 SV owner=GN_DW_ADMIN 확인 |
| 4 | `06_검증쿼리_VQR.md`·`07_평가셋_eval.md` | ✅ 완료 (2026-07-22) — `06`: 5 SV 라이브 검증(SV=FACT 일치)·회귀쿼리 V1~V6·SV별 VQR 후보·custom instruction 후보 6. `SV_MEMBER_EVENT` retention 제거 재배포·재검증(+`CREATE OR REPLACE`로 삭제된 grant 재부여, SHOW GRANTS 7행 확인). `07`: 5 SV 평가셋(NL↔gold SQL↔ground truth, 2026-07-22)·가드레일(ⓖ) 케이스 포함. **배포본=파일 정합 확인**(DESCRIBE: FME/FSE PK 없음·retention 없음·grant 정상) |
| 5 | `08_AGENT_spec.md` (CREATE AGENT) | ✅ 스펙완료 (2026-07-22) — 2 Agent(AGENT_MEMBER 4SV·AGENT_OVERALL 예산+MONTHLY/SERVICE) 스펙 작성. model=auto·WH=GN_DW_ANALYTICS_WH·orchestration 라우팅·custom instruction 6(06§4)·sample_questions·평가셋 매핑(07). workspace YAML=`cortex_project/AGENT_MEMBER.agent.yaml`·`AGENT_OVERALL.agent.yaml`. Cortex Search=Phase-2 유예. **배포(save/publish)·CoWork ADD AGENT·USAGE grant는 사용자(GN_DW_ADMIN)** — §4 절차 |
| 6 | `10_SI연결_검증.md` | ✅ 배포·연결 완료 / 🔄 스모크 대기 (2026-07-22) — CoCo 대행배포: 2 Agent `cortex_agent_save`(GN_DW.SERVING) → **소유권 GN_DW_ADMIN 이전**(생성 시 ACCOUNTADMIN → GRANT OWNERSHIP COPY CURRENT GRANTS) → USAGE grant(ANALYST/VIEWER/SERVICE) → **CoWork SI object `ADD AGENT`**(2행 등록 확인). 실행로그=`09_AGENT_spec_구현.sql`. **스모크**: `cortex_agent_query`(DATA_AGENT_RUN API)가 **트라이얼 계정 차단** → CoWork UI(ai.snowflake.com)에서 10 §3 문항 수동 검증 필요 |
| 7 | `11_거버넌스_운영.md` | ✅ 완료 (2026-07-22) — 08_mornitoring 근거로 GN_DW 맞춤 거버넌스: 과금 매핑(CORTEX_AGENTS·AI_SERVICES·SNOWFLAKE_INTELLIGENCE·WH), 사용량 정본뷰(중복합산 금지), Budget(소프트)·Per-user quota/RBAC(하드)·Alert(2h), **품질 폐루프**(오답→instruction/VQR 재배포), 거버넌스 체크리스트, 트라이얼 제약·paid 이관표 |
| 8 | `00_README.md` 갱신·인계 | ⬜ 대기 |

> 상태: ⬜ 대기 / 🔄 진행 / ✅ 완료 / ⛔ 보류(사유). Phase 2 항목은 데이터 입고 트리거 충족 시 착수.
> **파일 넘버링 규칙**: 폴더 내 2자리 순차 접두사(`00_README`·`01_작업계획`·`02_`=step0 ··· `10_`=step7). 단계번호≠파일번호(파일=00부터 문서순). 레거시는 `_archive/`.

---

## 부록 A. 입력 문서 (SSOT)
| 입력 | 위치 | 용도 |
|---|---|---|
| derived 매핑(SSOT) | `03_top-down_gold/04_SV파생 매핑.md` | metric 분자/분모·소속 FACT·conform 축 |
| 테이블 설계 | `03_top-down_gold/03_테이블 설계.md` | 9 FACT·15 DIM grain·FK 참조 |
| 필드 인벤토리 | `03_top-down_gold/05_필드 인벤토리.md` | base measure 물리 컬럼명 |
| DDL | `03_top-down_gold/06_DDL.sql` | base_table·relationship 실컬럼 |
| 메타·미해결 | `03_top-down_gold/07_메타.md` | 시간가용성 enum·중복정의 충돌 |
| 1단계(레거시) | `05_SV-Agent_ai/_archive/1_SV_metric 배속.md` | 4-SV 배속(metric↔FACT 매핑 재사용) |
| 데이터 게이트 | `20_issue/00_INDEX_이슈원장.md` 외 | Phase 2 트리거(G-5·E-6·E-1/4·Q10·A~G) |

## 부록 B. Best practice 출처 (Snowflake 공식)
- Semantic views overview / getting started(star schema 권장): `/user-guide/views-semantic/overview`
- Best practices — Autopilot("start simple, 3–5 tables, focused scope, VQR로 복잡 로직 흡수"): `/user-guide/views-semantic/autopilot`
- Best practices — dev(RBAC·owner's rights·CoWork용 stage/proc/function USAGE·dbt·CI/CD): `/user-guide/views-semantic/best-practices-dev`
- Routing Mode(semantic SQL 우선·정확도): `/user-guide/snowflake-cortex/cortex-analyst/cortex-analyst-routing-mode`
- Cortex Analyst evaluations(VQR ground truth·run당 SV 1개·optimization 폐루프): `/user-guide/snowflake-cortex/cortex-analyst-evaluations`
- Custom instructions: `/user-guide/snowflake-cortex/cortex-analyst/custom-instructions`
- Cortex Agents / CoWork build-agents(다중 SV 라우팅·tools·feedback): `/user-guide/snowflake-cortex/cortex-agents`, `/user-guide/snowflake-cortex/snowflake-cowork/build-agents`
- YAML spec(synonyms·description·sample_values·relationships): `/user-guide/views-semantic/semantic-view-yaml-spec`

## 부록 C. 변경 이력
- **v4.2** (2026-07-21): **비판적 검토·가드레일 강화(후속 오류 방지)**. 원칙 10~12 신설(1 SV=1 FACT fan-out 방지·고카디널리티 차원 Cortex Search 백킹·SV/Agent IaC 형상관리+회귀). §0.2 리스크·가드레일 체크리스트(R1~R8) 신설. **0단계(SERVING 스키마·권한·CoWork object 생성) 전제 추가**(SERVING 미생성 상태 명시). cross-fact/목표대비는 conformed 브리지 뷰로만 구현(raw 다중 FACT 조인 금지) 명문화. overall Agent 스코프 명확화(예산+선택적 다중 SV, 질의당 단일 SV 분해). 2·3·7단계 DoD에 브리지/Search/fan-out/회귀 반영.
- **v4.1** (2026-07-21): **객체 배치 정합화** — 정본 `02_GN_DW_building`(P7 serving_separation) 확인 후, SV·Agent 배치를 `GN_DW.GOLD`→**`GN_DW.SERVING`**으로 복원. Agent는 SERVING 배치 + **CoWork object로 가시성 큐레이션**(구 `SNOWFLAKE_INTELLIGENCE.AGENTS`는 deprecated). 데이터 격리는 스키마가 아니라 owner's rights(P3)+role scope+`SECURITY` row access policy로 명문화. (`01_project_sample`은 GOLD 통합 레거시로 확인 → `01_project_sample_legacy/`로 참고용 보존)
- **v4** (2026-07-21): 레거시 v3.1 대체. **범위 = 설계→실배포+SI/CoWork+평가·거버넌스**로 확장(GOLD 실물 완성 전제). SV base = GOLD base DIM/FACT. **구조 4 SV → 7 SV**(grain당 1개, 9 FACT covered), **Agent 3개(회원/마케팅/overall)**. 데이터 현황 게이트로 Phase 1/2 분리. 단계 3·5·6에 실제 CREATE·SI 연결 추가.
- v3.1 이전: `_archive/00_SV-Agent 작업계획_legacy.md` 참조(설계문서 only·4 SV/3 Agent).

---
_Co-authored with CoCo_
