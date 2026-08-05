<!-- LLM-METADATA
doc_id: SV_AGENT_NEXT_PROMPT
doc_role: 다음 세션 kickoff — Phase-2 활성화(마케팅 Agent·비활성 지표 승격) 착수 프롬프트
project: GN_DW (굿네이버스)
account: kd03246 (2026-07-28 재이전 · 종전 cs94293 기록은 폐기)
created: 2026-07-21
updated: 2026-07-29 (순서9-F~9-L 반영: SV 6종·라벨화·원천규칙·SV_AD 배포·Agent VERSION$2·배포경로 규명. 종전 2026-07-22 스냅샷의 "5 SV·SV_AD 미배포·Agent 3도구" 기술은 **폐기**)
canonical_plan: 05_SV-Agent_ai/01_SV-Agent 작업계획.md (v4.2)
END-METADATA -->

# SV·Agent kickoff — Phase-2 활성화 (2026-07-29 기준)

> 이 문서 하나로 다음 세션에서 **Phase-2(마케팅 Agent 신설 + 비활성 지표 승격)** 를 바로 착수한다.
> **Phase-1(0~7단계) = 완료**: SERVING·배속·설계·SV DDL 배포·검증·평가셋·**Agent 2개 배포·CoWork 연결·거버넌스**까지 끝. 정본 계획 = `01_SV-Agent 작업계획.md (v4.2)`.
> **정합성 원칙**: §0 문서 맵의 P0를 먼저 읽고, 충돌 시 **"실측 + 최신 정정" 우선**(문서 내 최신 정정/결정 로그가 이전 스냅샷에 우선).

> 🔴 **[2026-07-29] 착수 전 필독 — 이 문서 §2 이하의 종전 스냅샷이 여러 곳에서 갱신됐다**
> | 항목 | 종전(07-22) | **현행(07-29 실측)** |
> |---|---|---|
> | 배포 SV | 5종 | **6종** — `SV_AD` 배포 완료(순서9-J/K, `REBRDC_DEV_UNIT_PRICE` 포함) |
> | `AGENT_OVERALL` 도구 | 3종(BUDGET·MEMBER_MONTHLY·SERVICE) | **4종** — `analyst_ad` 추가 |
> | Agent 버전 | VERSION$1 | **VERSION$2 = default**(기간 기본창 규칙), VERSION$1 롤백용 보존 |
> | 마케팅 Agent 트리거 | SV_AD·SV_GA 둘 다 미배포 | **SV_AD 는 이미 배포** → 잔여는 `SV_GA`(G-5 GA4 전기간 입고) 뿐 |
> | 계정 | cs94293 | **kd03246** |
> | 산출물 | ~12번 | **13_SV_AD_배포_추가작업.sql** 추가 |
>
> **신규 교훈 P24~P26**(반드시 숙지 — `20_issue/10_진단_원인분석.md` §11-G)
> - **P24** instruction 개정은 *추가*가 아니라 *제자리 교체*. 위임 선언("여기서 다루지 않음")에 규칙을 덧붙이면 자기모순 → LLM이 비결정적으로 무시.
> - **P25** **배포 ≠ 발행**. `cortex_agent_save` 단독은 미발행(live 만 갱신). 순수 SQL 경로는 **5단계**(live 선복구 → MODIFY → COMMIT → live 재생성 → SET COMMENT/PROFILE). `COMMENT`·`PROFILE` 은 spec 이 아닌 DDL 속성.
> - **P26** 멱등 가드는 관측 대상이 실제 상태를 반영하는지 **변화를 일으켜** 검증. 두 관측이 우연히 같으면 무력한 가드가 정상처럼 보인다.
>
> ⚠ **Agent spec 변경 시 경로**: 기존 계정은 **`09` [4-B]**(이력·grant·SI 보존) 또는 `cortex_agent_deploy`. **`09` [1-ALT](CREATE OR REPLACE)는 신규 계정 전용** — 버전 이력을 초기화하고 grant·SI 등록을 파괴한다.
> ⚠ **`08 §3.1`(AGENT_MEMBER YAML 사본)은 구버전 부채** — 근거는 `cortex_project/agents/AGENT_MEMBER/agent_spec.yaml`(정본)을 직독할 것.
> 🔴 2026-08-05 O38: 종전 이 자리가 지목했던 루트 `cortex_project/AGENT_MEMBER.agent.yaml` 은 **O33 이전 판본이었고 `_archive/` 로 이관**됐다 — 그 파일을 근거로 삼으면 도구 2개(코호트·달성율)와 O33~O38 규칙이 통째로 누락된다.


---

## 0. 착수 전 필독 문서 맵 (정합성 유지용)

> 읽는 순서 = P0 → P1. P2/P3는 해당 소단계에서 참조. 경로는 `05_SV-Agent_ai/` 기준(타 폴더는 명시).

### P0 — Phase-2 착수 직접 근거 (반드시 통독)
| 문서 | 용도 | 핵심 앵커 |
|---|---|---|
| `01_SV-Agent 작업계획.md` (v4.2) | **정본**. 원칙12·리스크 R1~R8·Agent↔SV 라우팅·결정 로그·진행표 | §1.1 매핑·**§1.2 Agent(최종3/Phase-1 배포2)**·§2 데이터 게이트·§1.1 하단 **결정 로그(2026-07-22)** |
| `04_SV_설계.md` (정정본) | 7 SV 구조·relationship·가산성·**§0.4 시간/NULL instruction**·§0.6 적재 완결성 | 마케팅 SV(SV_AD·SV_GA) 설계·브리지 원칙(R1) |
| `03_SV_metric_배속.md` (정정본) | derived 81→SV 배속·**활성/Phase 태깅** | 비활성 지표(캠페인·성공률·유지율·목표대비) → 승격 대상 |
| `05_1~05_7_SV_DDL_*.sql` | 배포된 5 SV 정의(=Agent 도구). **⚠ 헤더의 COUNT_IF(행수) vs metric SUM 구분 주석** | 각 CREATE 블록·§6 GRANT(재배포 시 grant 재실행) |
| `08_AGENT_spec.md` | **배포 2 Agent 스펙 정본** + 마케팅 Agent Phase-2 유예 근거 | §1 구성·§5 평가매핑 |

### P1 — Phase-2 트리거·데이터 상태 (승격 조건)
| 문서 | 용도 |
|---|---|
| `20_issue/40_입고대기_원천의존.md` | 입고 트리거 **G-5(GA4 전기간)·E-6(사업목표)·E-1/E-4(비용)·Q10(캠페인 연결키)** = Phase-2 승격 조건 |
| `20_issue/50_dbt_파이프라인_미결조치.md` | A1/A3 적재·**B계열(B1 성공/실패·B2 SPONSORSHIP/PAYMENT·B3 CAMPAIGN)** 유예 |
| `20_issue/00_INDEX_이슈원장.md` | 이슈 E(FEP 고아 23%) 등 교차확인 |
| `03_top-down_gold/07_메타.md` | **시간 가용시점 enum** — custom instruction 시간 근거 |

### P2 — 운영·검증·거버넌스
| 문서 | 용도 |
|---|---|
| `06_검증쿼리_VQR.md` | VQR 후보·custom instruction 6·검증 매트릭스 |
| `07_평가셋_eval.md` | NL↔gold SQL↔ground truth·가드레일(ⓖ) — **Phase-2 활성 시 ⓖ→정상 케이스 승격** |
| `10_SI연결_검증.md` | CoWork 연결 절차 + §3 스모크·회귀 검증표(정확도 14·가드레일 8) |
| `11_거버넌스_운영.md` | 사용량·비용쿼터·알림·품질 폐루프 |
| `12_paid_테스트_실행가이드.md` | **paid 이관 후 NL 스모크 단독 실행 가이드**(트라이얼 차단분) |

---

## 1. 완료 상태 (Phase-1, 0~7단계)

- ✅ **0단계** `02_SERVING_setup.sql` — WH 3·역할 6·계층 grant + `GN_DW.SERVING` + helper 뷰 + CoWork object.
- ✅ **1단계** `03_SV_metric_배속.md` — derived 81 전수 배속(활성/Phase 태깅).
- ✅ **2단계** `04_SV_설계.md` — 7 SV 구조 + fan-out helper + 정정 로그.
- ✅ **3단계** `05_1~05_7_SV_DDL_*.sql` — **SV 6종 배포·검증**(fan-out/가산성 DoD PASS·PK 정정). SV_AD 는 순서9-J/K 추가.
- ✅ **4단계** `06_검증쿼리_VQR.md`·`07_평가셋_eval.md` — 라이브 검증(SV=FACT)·VQR 후보·평가셋.
- ✅ **5단계** `08_AGENT_spec.md` — **Agent 2개 스펙**(회원 4 SV · overall 예산+광고+월실적/발송 4 SV). 마케팅 Agent = Phase-2 유예.
- ✅ **6단계** `09_AGENT_spec_구현.sql`(배포 실행 로그·소유권·USAGE·ADD AGENT 멱등·[4-B] 갱신 경로) + `10_SI연결_검증.md`.
- ✅ **7단계** `11_거버넌스_운영.md` — 사용량·비용쿼터·알림·품질 폐루프.
- ✅ **순서9-F~9-L 후속 개정** — 라벨화(`*_NAME`) · BRONZE 원천 규칙 · 공8 오진 철회 · **기간 기본창 규칙**.
- 🔄 **NL 스모크 검증** — 트라이얼 `DATA_AGENT_RUN` 차단 → **paid 이관 후** `12_paid_테스트_실행가이드.md`(=10 §3)로 실행 대기. **PRV-3**(기간 기본창 실동작)도 동일 게이트.

---

## 2. 배포 실측 자산 (GN_DW.SERVING, owner=GN_DW_ADMIN, **2026-07-29 실측**)

| Agent (FQN) | 도구(SV) | 도메인 |
|---|---|---|
| `GN_DW.SERVING.AGENT_MEMBER` | MEMBER_MONTHLY·MEMBER_EVENT·SERVICE·EVENT_PARTICIPATION | 월 회비/납부율/미납·개발중단·발송·행사 |
| `GN_DW.SERVING.AGENT_OVERALL` | BUDGET(기본)·**AD**·MEMBER_MONTHLY·SERVICE | 예산 편성/집행/집행율·**광고 실적**·전사 요약 |

- 두 Agent **VERSION$2 = default**(기간 기본창 규칙 포함), VERSION$1 은 `is_default=false` 로 보존(롤백 가능).
- **SV 6종** 배포·`GRANT REFERENCES, SELECT` → GN_DW_ANALYST·GN_DW_VIEWER·GN_DW_SERVICE:
  `SV_MEMBER_MONTHLY`·`SV_MEMBER_EVENT`·`SV_SERVICE`·`SV_EVENT_PARTICIPATION`·`SV_BUDGET`·**`SV_AD`**
- CoWork: `SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT` 에 ADD AGENT(2) — `09` [4] 멱등 블록으로 재실행 안전.
- **미배포(Phase-2)**: **`SV_GA`(FGA 1일 샤드)만 잔여** → 마케팅 Agent 트리거는 G-5(GA4 전기간 입고).
  ⚠ 종전 "SV_AD 미배포" 기술은 폐기 — 순서9-J/K 에서 배포·검증 완료(`REBRDC_DEV_UNIT_PRICE` 157,969원 포함).


---

## 3. ▶ 이번 세션 과제 — Phase-2 활성화

> **전제**: Phase-2는 **원천 bronze 데이터 입고가 트리거**다. 아래 항목은 해당 데이터가 GOLD까지 적재된 뒤 착수한다. 데이터 미입고 상태에서는 **스펙·DDL 초안만** 준비하고 배포는 유예(추정값 산출 금지 — R8).

### 3.1 마케팅 Agent 신설 (최종 3 Agent 완성)
- **트리거**: `SV_GA` = FGA 전기간 적재(G-5). ⚠ `SV_AD` 는 **이미 배포됨**(순서9-J/K) → 신규 배포 대상은 `SV_GA` 뿐.
- 절차: `SV_GA` `CREATE SEMANTIC VIEW` 배포(04 설계) → GRANT 3역할 → `AGENT_MARKETING` 스펙 작성(08 패턴 재사용)
  → `cortex_agent_deploy`(또는 `09` [1-ALT] 패턴) → 소유권 확인 → USAGE → `09` [4] 멱등 블록으로 ADD AGENT.
- ⚠ grain 상이(FAD 일×캠페인×소재 vs FGA 일×identity×이벤트) → **질의당 단일 SV 분해**(cross-fact 금지, R1). GA 의존 cross(공81·신32)는 conformed 브리지 뷰로만.
- ⚠ 신규 Agent instruction 작성 시 **기간 기본창 규칙(순서9-L)을 처음부터 포함**할 것 — SV 그레인이 일(day)이므로 기본 창 = **최근 7일 일별**. 도구명을 직접 명시해 그레인 추론 오류를 차단한다(AGENT_MEMBER 패턴).

### 3.2 기존 SV 비활성 지표 승격 (구조 불변·in-place)
> 동일 SV의 같은 테이블·관계 위에 **METRIC/DIMENSION만 추가** → 재설계 불요. 07 평가셋 ⓖ 케이스를 **정상 산출 케이스로 승격** + 기대값 추가.

| 승격 항목 | 트리거(문서40/50) | 대상 SV |
|---|---|---|
| 캠페인/조직/후원사업/납입방식별 분해 | CAMPAIGN/ORG/SPONSORSHIP/PAYMENT_SK 적재(B2·B3·Q10) | MEMBER_MONTHLY·SERVICE·BUDGET |
| 서비스 성공/실패/오픈·D5 코호트(신31~53) | B1 코드매핑·D5 적재 | SERVICE |
| 유지율/LTV/유지기간(신2~8) | LAST_STOP_DATE·가입↔중단 브리지 | MEMBER_EVENT |
| 목표대비(공1~3)·개발단가/ROI(신9~11) | FTG_B(E-6)·비용(E-1/E-4)·conform 브리지 | MEMBER_MONTHLY·BUDGET |
| 활동/누계/미납 카운트 비율(공45~78) | ACTIVE/CUM/MONTH_END_ACTIVE_CNT 적재 | MEMBER_MONTHLY |

### 3.3 paid 이관 후 즉시 (Phase-1 미완 잔여)
- **NL 스모크·회귀**: `12_paid_테스트_실행가이드.md`(=10 §3) 22문항 → 판정표 채움(정확도 14·가드레일 8).
- **VQR 등록**: SV별 검증쿼리(06 §3)를 `AI_VERIFIED_QUERIES`로 등록 → 정확도 스티어링.

### 3.4 회귀 (Phase-2 배포마다)
- GOLD 재적재 시 **07 평가셋 ground truth 재생성**(§4 gold SQL 재실행) → 회귀.
- SV `CREATE OR REPLACE`는 grant 삭제 → REFERENCES,SELECT 3역할 재부여(05 §6).

---

## 4. 반드시 지킬 가드레일 (정합성)

- **실측 우선**: 활성 판정은 `COUNT_IF` 후. 빈 measure/dim Agent 노출 금지(R8). ⚠ COUNT_IF(행수) ≠ metric SUM(값) — 05 헤더 주석 참고.
- **비활성 지표 요청**: 데이터 미입고분은 **"데이터 적재 후(Phase-2) 안내"**(산출·추정 금지).
- **fan-out/가산성**: SV가 helper 뷰로 차단. 다월 distinct는 `COUNT(DISTINCT)` metric. grain 상이 SV 병합 금지.
- **DO NOT**: 지표·수식·조인키 추정 금지. `03_top-down_gold/` 입력문서 수정 금지. 문서 충돌 시 최신 정정·실측 우선.
- **판정·구문을 단정하기 전 실측**: 순서9-L 에서 미검증 단정 5건이 자기검토로 뒤집혔다(미발행을 "배포 완료"로 오인 · `REMOVE AGENT` 미지원으로 오기록(정답 `DROP AGENT`) · 무력할 수 있던 멱등 가드 · live 선복구 누락 · COMMENT/PROFILE 미갱신). **문서 근거를 확인하고, 가드는 상태를 변화시켜 검증**한다(P25·P26).
- **정본↔사본 동기화**: Agent spec 정본 = `cortex_project/agents/<AGENT>/agent_spec.yaml`. 변경 시 ① 05 재배포(+GRANT) → ② 정본 yaml → ③ `09_2` 실행 → ④ `08 §3` 서술 동기화. **동일 drift 4회 재발**(P23) → 2026-07-31 구조 변경으로 **SQL 사본을 없앴다**(09_2 가 stage 정본을 직접 읽는다). `08 §3` 서술만 사본으로 남아 있으니 착수·종료 시 정본과 대조할 것.

---

## 5. 산출물 위치·명명 (2자리 순차)

`00_README.md`(색인) · `01_작업계획` · `02_SERVING_setup.sql` · `03_SV_metric_배속.md` · `04_SV_설계.md` · `05_SV_DDL.sql` · `06_검증쿼리_VQR.md` · `07_평가셋_eval.md` · `08_AGENT_spec.md` · **`09_1_AGENT_생성.sql`**(껍데기) · **`09_2_AGENT_버전업.sql`**(yaml 기반 스펙 발행) · `10_SI연결_검증.md` · `11_거버넌스_운영.md` · `12_paid_테스트_실행가이드.md` · ~~`09_AGENT_spec_구현.sql`~~·~~`13_SV_AD_배포_추가작업.sql`~~(**DEPRECATED 2026-07-31**, 포인터 스텁만 잔존). 레거시 = `_archive/`.

> **실행 순서 (2026-07-31 확정, mq60369 재현 실증)**: `02_SERVING_setup` → dbt(BRONZE→GOLD) → `05_SV_DDL`(§7 GRANT·§8 검증 포함) → `09_1_AGENT_생성`(껍데기+grant+SI) → `09_2_AGENT_버전업`(정본 yaml 발행 ★도구가 붙는 단계). 4번만 하면 tool 이 없어 데이터 질문에 답하지 못한다 — 5번까지가 1세트다. **05는 최초·재배포 공용 단일 파일이며 별도 update 스크립트가 없다.**

> **변경 시 — "무엇을 바꾸는가"로 갈린다**: SV/데이터만 변경 → `05` 통째 재실행 → `05 §8` 스모크 / Agent 스펙 변경 → `cortex_project/agents/<AGENT>/agent_spec.yaml` 갱신 → **`09_2`** / COMMENT·PROFILE 변경 → **`09_1 [5]`**(spec 이 아닌 DDL 속성). 🔴 운영 중 Agent 에 `09_1 [1]` `CREATE OR REPLACE` 재실행 금지 — 버전 이력 초기화 + USAGE grant·CoWork SI 파괴.

> **Agent 스펙은 SQL 에 사본을 두지 않는다 (2026-07-31 구조 변경)**: 구 09 는 YAML 전문을 네 블록에 사본으로 갖고 "정본 변경 시 함께 갱신" 규약에 의존했고, 그 규약이 지켜지지 않아 **동일 유형 drift 가 4회 재발**(P23)했다. `09_2` 는 `ALTER AGENT … ADD VERSION FROM <stage>` 로 워크스페이스 정본 파일을 직접 읽으므로 사본이 0개 = drift 구조적 불가. **실측 규약**: 스펙 파일명은 **`agent_spec.yaml`**(공식 문서의 `agent.yaml` 예시는 부정확 — 틀리면 `No spec file present for the agent`) · 인자는 **디렉터리** · **live 가 있으면 거부**되므로 COMMIT 선행 · 발행된 버전은 **자동 is_default=true**, 이전 버전 보존.

> **SV COMMENT 규약 (2026-07-31 신설, 05 헤더 정본)**: COMMENT에 **수치를 넣지 않는다**(행수·합계·커버리지%·건수·금액·적재기간). Agent가 COMMENT를 원천 답변 근거로 인용하므로 박아둔 수치는 적재량이 바뀌는 순간 Agent가 거짓을 말하게 된다. `[원천]` 절은 `시스템=… · BRONZE=DB.스키마.테이블(핵심컬럼) · SILVER=…` 형식으로 **이름만** 적고, 컬럼 단위 완전 매핑은 `30_output_share/04_컬럼계보매핑.md`로 안내한다. 저카디널리티 코드 차원은 **실제 코드값을 열거**한다(틀리면 Analyst가 0행을 반환하는 무증상 오답).

> Phase-2 신규 산출물은 다음 순번(14~)으로 부여하거나 기존 문서에 in-place 추가. `cortex_project/*.agent.yaml`은 이동·개명 금지.

---
_Co-authored with CoCo_
