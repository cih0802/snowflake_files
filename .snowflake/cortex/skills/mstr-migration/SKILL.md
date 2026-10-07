---
name: mstr-migration
description: "MSTR(MicroStrategy · 구 SQL Server mart) 리포트를 GN_DW.MSTR 로 이관하는 배치 절차. 리포트 쿼리 1개 → 의존성 탐색 → 원문 추출 → Snowflake 변환 → 배포 → 실행 → baseline 검증 → SV·Agent 배선. Use when: 새 MSTR 리포트(2차 이후 배치) 이관, MSTR 이관 재배포, MSTR 이력 재적재, MSTR 결과 검증. Triggers: MSTR 이관, MSTR 배치, MSTR 리포트 이관, mstr_pipeline, 2차 이관, MSTR 재배포, MSTR baseline."
---

# MSTR 리포트 이관 (배치 단위)

정본 도구 = `15_MSTR 이관 PoC/tools/` · 🔴 **사용법·변환 규칙·함정의 정본은 `tools/README.md` 다**(이 스킬은 순서·멈춤·금지만 정한다 — 규칙을 여기 복사하지 않는다).
1차 사례 = `manifests/1차.json`(결정 X1~X3 · K1~K3 · baseline 202601) · 작업계획 = `MSTR_1차이관_Snowflake전환_작업계획.md`.

## 전제 (착수 전 확인)

- 대상 = `GN_DW.MSTR`(원천 `GN_DW.BRONZE_CRM`) · 서빙뷰·SV = `GN_DW.SERVING`(MSTR 매니페스트 대상 아님).
- 🔴 **라이브 DDL 은 반드시 `GN_DW_ADMIN` 역할로** 실행한다 — ACCOUNTADMIN 이면 owner 가 어긋나 재배포가 막힌다
  (사고 = `20_issue/10_진단_원인분석_조각/10_진단_원인분석-015.md:57` · O200-C 재발).
- dbt 와 무관하다(MSTR 은 Snowflake Scripting SP) — dbt 정지점 대상이 아니다.

## Workflow

### Step 1. 매니페스트 생성
`tools/manifests/<batch>.json` 에 `batch`·`label`·`report_query`·`extract_dir`·`deps_snapshot` 을 적는다(1차.json 형식).
**⚠️ STOP**: 대상 리포트·배치명을 사용자에게 확인받는다.

### Step 2. deps (무변경)
```
cd "15_MSTR 이관 PoC/tools"
python3 mstr_pipeline.py manifests/<batch>.json --steps deps
```
- ⚠ 로 출력된 미결정 객체를 `objects`(이관) 또는 `evidence`+`decisions`(제외) 로 분류한다.
- `BRONZE 부재` 원천은 IT 확인 대상이다(1차 X1 = ExplCampList).
**⚠️ STOP**: 미결정 객체 분류는 **사람이 결정**한다 — 근거 없이 제외·NULL 처리하지 않는다.

### Step 3. extract → 변환 (무변경 · 파일)
- `--steps extract` 로 원문 근거 파일을 만든다.
- 추출본을 **전량 읽고** `templates/<batch>_NN_*.tmpl.sql` 을 작성한다(변환 규칙 = README §변환 규칙).
- 판단(제외·NULL·타입 확대)은 전부 매니페스트 `decisions` 에 `id`·`object`·`action`·`effect`·`basis` 로 남긴다.

### Step 4. gen (무변경 · 파일)
`--steps gen` → `snowflake 적용 ddl/` 산출 · 한 줄 2000자 가드(`python3 scripts/line_len.py`).
**⚠️ STOP**: 라이브 배포 전 사용자 승인.

### Step 5. deploy → run → verify (🔴 라이브)
```
python3 mstr_pipeline.py manifests/<batch>.json --steps deploy,run,verify --ym <YYYYMM> --apply
```
- 첫 실행이면 `mstr_verify.py … --set-baseline` 으로 기준선을 기록한다.
- 이력 재적재가 필요하면 `--hist`(기준월 이하 전 월 · 장시간 → background 실행 후 폴링).
- 배포 후 `mstr_deploy.py manifests/<batch>.json --check` = 매니페스트 ↔ 라이브 일치.

### Step 6. SV · Agent 배선
- 서빙뷰 + SV DDL = `05_SV-Agent_ai/23_MSTR_SV_DDL.sql` 형식(파일 단독 실행 · 🔴 `USE ROLE GN_DW_ADMIN` 부터).
- 도구 추가 = `cortex_project/agents/AGENT_{MEMBER,MARKETING,EXECUTIVE}/agent_spec.yaml` → `05_SV-Agent_ai/09_2_AGENT_버전업.sql` [0]·[0-B]·[2]·[3] · 패치 예 = `tmp/o207_agent_patch.py`.
- 🟢 [O207 · 2026-10-07 · 사용자 결정 C안 → O207-C AGENT_MSTR 은퇴] MSTR 도구(analyst_mstr_spnsr_dvlp · SV_MSTR_SPNSR_DVLP)는 AGENT_MEMBER·AGENT_MARKETING·AGENT_EXECUTIVE 에 배선돼 있고 개발 실적·목표·연도말 전망의 정본이다. AGENT_MSTR 는 DROP 됐다(스펙 사본 = _archive/agent_spec.yaml.O207-C-retire-agent-mstr).
- Agent 정의 = `05_SV-Agent_ai/09_0_AGENT_정의서.md`.
- ~~🔴 **[O203 · 사용자 결정 2026-10-06] 다른 Agent 배선은 A안(붙이지 않음)이 현행이다.**~~ ➔ 폐기(O207) — 아래 3줄의 질문은 더 하지 않는다. MSTR 도구는 AGENT_MSTR 에만 있고 AGENT_MEMBER·AGENT_EXECUTIVE·AGENT_MARKETING 에는 배선되지 않았다.
  ⇒ 이 단계에 오면 **사용자에게 반드시 묻는다**: 「MSTR 결과는 아직 AGENT_MSTR 에만 배선돼 있습니다(A안). 회원 분석(AGENT_MEMBER)에도 붙이는 B안으로 전환할까요?」
  · B안 선택 시 = AGENT_MEMBER 스펙에 SV_MSTR_* 도구 추가 + 답변마다 「MSTR 기준」 표기 문구를 사용자에게 받는다 · 선택지 원문 = `05_SV-Agent_ai/41_현업요청서_MSTR반영_누계개발.md` 요청 1.
  · 답이 없으면 A안 유지(임의 전환 금지).
**⚠️ STOP**: B안 전환 여부 질문 · CoWork UI 스모크는 사용자(트라이얼 계정은 Agent NL 실행 불가).

### Step 7. 기록
원장 §1 행 · 세션이력 · 인수인계 라벨 파일(`init_ihcho` §5) · 작업계획 문서 체크리스트.

## 금지 규칙

- 🔴 **MSTR 기준과 GN_DW 기준 수치를 한 표에 합산·차감하지 않는다**(같은 지표명이라도 정의가 다르다).
- 🔴 MSTR 「개발(건)」 = 후원금액 ÷ 10,000 — 사건 건수로 바꾸지 않는다(1차 확정).
- 🔴 원 리포트 대조(MSTR 측 수치)가 없으면 「MSTR 과 일치」라고 쓰지 않는다 — baseline 은 **자기 일관성** 증거일 뿐이다.
- 🔴 `--apply` 없는 단계만 자율 실행한다. 라이브 단계는 사용자 승인 후.

## Stopping Points

- ✋ Step 1 대상 확인 · ✋ Step 2 미결정 객체 분류 · ✋ Step 4 라이브 배포 승인 · ✋ Step 6 CoWork 스모크

## Output

배치 매니페스트(결정 포함) · `snowflake 적용 ddl/` · 라이브 `GN_DW.MSTR` 객체 + baseline · 서빙뷰·SV·Agent 도구 · 기록 3곳.

_Co-authored with CoCo · O200-D (O197-A-1 ③ 스킬화)_
