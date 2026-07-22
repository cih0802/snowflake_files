<!-- LLM-METADATA
doc_id: SV_AGENT_NEXT_PROMPT
doc_role: 다음 세션 kickoff — Phase-2 활성화(마케팅 Agent·비활성 지표 승격) 착수 프롬프트
project: GN_DW (굿네이버스)
account: cs94293 (계정이전 후 신규)
created: 2026-07-21
updated: 2026-07-22 (Phase-1 전 단계(0~7) 완료 → Phase-2 kickoff로 재작성. 문서 재넘버링 반영: SI연결=10·거버넌스=11·paid가이드=12)
canonical_plan: 05_SV-Agent_ai/01_SV-Agent 작업계획.md (v4.2)
END-METADATA -->

# SV·Agent kickoff — Phase-2 활성화 (2026-07-22 기준)

> 이 문서 하나로 다음 세션에서 **Phase-2(마케팅 Agent 신설 + 비활성 지표 승격)** 를 바로 착수한다.
> **Phase-1(0~7단계) = 완료**: SERVING·배속·설계·SV DDL 배포·검증·평가셋·**Agent 2개 배포·CoWork 연결·거버넌스**까지 끝. 정본 계획 = `01_SV-Agent 작업계획.md (v4.2)`.
> **정합성 원칙**: §0 문서 맵의 P0를 먼저 읽고, 충돌 시 **"실측 + 최신 정정" 우선**(문서 내 2026-07-22 정정/결정 로그가 이전 스냅샷에 우선).
> **Agent 스코프 유의**: 최종 설계는 **3 Agent**(회원·마케팅·overall)이나, **Phase-1 실배포는 2 Agent**(회원·overall)뿐이다. **마케팅 Agent는 base FACT(FAD·FGA)의 원천 bronze가 불완전**하여 Phase-2로 유예됨 — 본 세션의 핵심 대상.

---

## 0. 착수 전 필독 문서 맵 (정합성 유지용)

> 읽는 순서 = P0 → P1. P2/P3는 해당 소단계에서 참조. 경로는 `05_SV-Agent_ai/` 기준(타 폴더는 명시).

### P0 — Phase-2 착수 직접 근거 (반드시 통독)
| 문서 | 용도 | 핵심 앵커 |
|---|---|---|
| `01_SV-Agent 작업계획.md` (v4.2) | **정본**. 원칙12·리스크 R1~R8·Agent↔SV 라우팅·결정 로그·진행표 | §1.1 매핑·**§1.2 Agent(최종3/Phase-1 배포2)**·§2 데이터 게이트·§1.1 하단 **결정 로그(2026-07-22)** |
| `04_SV_설계.md` (정정본) | 7 SV 구조·relationship·가산성·**§0.4 시간/NULL instruction**·§0.6 적재 완결성 | 마케팅 SV(SV_AD·SV_GA) 설계·브리지 원칙(R1) |
| `03_SV_metric_배속.md` (정정본) | derived 81→SV 배속·**활성/Phase 태깅** | 비활성 지표(캠페인·성공률·유지율·목표대비) → 승격 대상 |
| `05_SV_DDL.sql` | 배포된 5 SV 정의(=Agent 도구). **⚠ 헤더의 COUNT_IF(행수) vs metric SUM 구분 주석** | 각 CREATE 블록·§6 GRANT(재배포 시 grant 재실행) |
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
- ✅ **3단계** `05_SV_DDL.sql` — **5 SV 배포·검증**(fan-out/가산성 DoD PASS·PK 정정).
- ✅ **4단계** `06_검증쿼리_VQR.md`·`07_평가셋_eval.md` — 라이브 검증(SV=FACT)·VQR 후보·평가셋.
- ✅ **5단계** `08_AGENT_spec.md` — **Agent 2개 스펙**(회원 4 SV·overall 예산+월실적/발송). 마케팅 Agent = Phase-2 유예.
- ✅ **6단계** `09_AGENT_spec_구현.sql`(배포 실행 로그·소유권·USAGE·ADD AGENT) + `10_SI연결_검증.md`(CoWork 연결·검증표).
- ✅ **7단계** `11_거버넌스_운영.md` — 사용량·비용쿼터·알림·품질 폐루프.
- 🔄 **NL 스모크 검증** — 트라이얼 `DATA_AGENT_RUN` 차단 → **paid 이관 후** `12_paid_테스트_실행가이드.md`(=10 §3)로 실행 대기.

---

## 2. 배포 실측 자산 (GN_DW.SERVING, owner=GN_DW_ADMIN, 2026-07-22)

| Agent (FQN) | 도구(SV) | 도메인 |
|---|---|---|
| `GN_DW.SERVING.AGENT_MEMBER` | MEMBER_MONTHLY·MEMBER_EVENT·SERVICE·EVENT_PARTICIPATION | 월 회비/납부율/미납·개발중단·발송·행사 |
| `GN_DW.SERVING.AGENT_OVERALL` | BUDGET(기본)+MEMBER_MONTHLY·SERVICE | 예산 편성/집행/집행율·전사 요약 |

- 5 SV 전부 `GRANT REFERENCES, SELECT` → GN_DW_ANALYST·GN_DW_VIEWER·GN_DW_SERVICE.
- CoWork: `SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT`에 ADD AGENT(2).
- **미배포(Phase-2)**: `SV_AD`(FAD 스캐폴드)·`SV_GA`(FGA 1일 샤드) → 마케팅 Agent.

---

## 3. ▶ 이번 세션 과제 — Phase-2 활성화

> **전제**: Phase-2는 **원천 bronze 데이터 입고가 트리거**다. 아래 항목은 해당 데이터가 GOLD까지 적재된 뒤 착수한다. 데이터 미입고 상태에서는 **스펙·DDL 초안만** 준비하고 배포는 유예(추정값 산출 금지 — R8).

### 3.1 마케팅 Agent 신설 (최종 3 Agent 완성)
- **트리거**: FAD 차원FK 보강(Q10)·FGA 전기간 적재(G-5).
- 절차: `SV_AD`·`SV_GA` `CREATE SEMANTIC VIEW` 배포(04 설계) → GRANT 3역할 → `AGENT_MARKETING` 스펙 작성(08 패턴 재사용) → `cortex_agent_save`→소유권 이전→USAGE→`ADD AGENT`.
- ⚠ grain 상이(FAD 일×캠페인×소재 vs FGA 일×identity×이벤트) → **질의당 단일 SV 분해**(cross-fact 금지, R1). GA 의존 cross(공81·신32)는 conformed 브리지 뷰로만.

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
- **DO NOT**: 지표·수식·조인키 추정 금지. `03_top-down_gold/` 입력문서 수정 금지. 문서 충돌 시 최신 정정(2026-07-22)·실측 우선.

---

## 5. 산출물 위치·명명 (2자리 순차)

`00_README.md`(색인) · `01_작업계획` · `02_SERVING_setup.sql` · `03_SV_metric_배속.md` · `04_SV_설계.md` · `05_SV_DDL.sql` · `06_검증쿼리_VQR.md` · `07_평가셋_eval.md` · `08_AGENT_spec.md` · `09_AGENT_spec_구현.sql` · `10_SI연결_검증.md` · `11_거버넌스_운영.md` · `12_paid_테스트_실행가이드.md`. 레거시 = `_archive/`.

> Phase-2 신규 산출물은 다음 순번(13~)으로 부여하거나 기존 문서에 in-place 추가. `cortex_project/*.agent.yaml`은 이동·개명 금지.

---
_Co-authored with CoCo_
