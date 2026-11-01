---
doc_id: A5
title: Agent · Semantic View 개발자 가이드
version: 0.1
as_of: 2026-10-30 (§1 Agent 도구·지표사전 행 수 갱신 · 그 밖 2026-10-20 spec 해시 대조)
source_docs:
  - 80_인수인계_프로젝트완료 및 유지보수용/01_실행순서_배포SQL/05_SV-Agent_ai/09_2_AGENT_버전업.sql (467행 전량)
  - 80_인수인계_프로젝트완료 및 유지보수용/01_실행순서_배포SQL/05_SV-Agent_ai/26_BIZ_DEFINITION_CORPUS_DDL_적재.sql (104행 전량)
  - 80_인수인계_프로젝트완료 및 유지보수용/05_RAG_지표사전/12_agent개선과제/tools/build_biz_definition_corpus.py (311행 전량)
  - 80_인수인계_프로젝트완료 및 유지보수용/01_실행순서_배포SQL/문서실행순서.md (87행 전량)
  - 80_인수인계_프로젝트완료 및 유지보수용/04_SV_Agent_스펙/cortex_project/ (spec 4파일 · 해시 대조 + 2026-10-20 yaml 기계 파싱 대조 — 도구 18/29/29 · response 5,421/5,704/4,963 · orchestration 14,841/15,968/21,358 자 = 라이브 DESCRIBE 와 일치. 본문 1,459행은 사람이 읽지 않았다 — 이 문서는 spec 의 **개수·길이·경로만** 인용하고 instruction 서술 내용은 인용하지 않기 때문이다. 서술을 인용하게 되면 그때 전량 읽는다)
  - 85_실제 인수인계 문서/_드리프트/드리프트_통합.md (DR-03·04·16·17·20·22·23)
source_queries:
  - DESCRIBE AGENT 3종 spec 파싱 · SHOW GRANTS ON AGENT · SHOW AGENTS IN SNOWFLAKE INTELLIGENCE · LIST @GN_DW.OPS.AGENT_SPEC_STAGE (2026-10-20 실행)
  - INFORMATION_SCHEMA.SEMANTIC_TABLES · BIZ_DEFINITION_CORPUS DOC_TYPE 집계 · scripts/sv_identifier_gate.py (rc=0)
owner: TBD
status: draft (S4 게이트 확인 대기)
---

# A5. Agent · Semantic View 개발자 가이드

## 1. [공통] 구성 요약 (실측)

| 항목 | 값 |
|---|---|
| SV | 전부 `GN_DW.SERVING` · 소유 GN_DW_ADMIN · base = GOLD / SERVING 뷰(개수·목록 = `D08_SV요약.csv` · 2026-10-21 ZL50263 = 45 · GOLD 30 / SERVING 15) |
| Agent | AGENT_EXECUTIVE · AGENT_MARKETING · AGENT_MEMBER · 기본 버전 [ENV] 운영계 = MEMBER VERSION$30 · EXECUTIVE VERSION$23 · MARKETING VERSION$26(2026-10-31 A6 Q07 · 3종 모두 10-30 21:39 KST 생성)(롤백 기준 = 그 직전 버전 · D10 §2) |
| Agent 도구 | Cortex Analyst(SV) + `search_biz_definition` 1 · 3종 합집합 = SV 전수(개수 = `D09_Agent도구.csv` · 🆕 2026-10-30 재생성 = EXECUTIVE 17 / MARKETING 33 / MEMBER 31 · 경영 17 = O270 W3 `analyst_ad`·`analyst_ml_realtime_simulator` 제거 — 다시 넣지 않는다) |
| Search | `SERVING.SEARCH_BIZ_DEFINITION` · 원천 `BIZ_DEFINITION_CORPUS`(🆕 O274 = 2,163행 · 원천참고 1,154 제외 1,009 · RT-31~37 추가) · lag 1 day |
| spec 정본 | 워크스페이스 `cortex_project/agents/<AGENT>/agent_spec.yaml` = 80번 `04_SV_Agent_스펙` 과 해시 일치 |
| 배포 스테이지 | `@GN_DW.OPS.AGENT_SPEC_STAGE/<AGENT>/agent_spec.yaml` (소비 롤 권한 없음 · ADMIN 전용) |
| 권한 | Agent = OWNERSHIP ADMIN + USAGE ANALYST·VIEWER·SERVICE · SV = REFERENCES+SELECT 소비 3롤 · CoWork 등록 3/3 |

- 🟢 [O250-C] Agent COMMENT 는 수치 없이 조회 데이터 카테고리만 적는다(DR-03 해소). 도구 수는 spec 에서 센다(§4 [5]).

## 2. [공통] Semantic View 수정 규칙

1. **정본 = 파일**: `01_실행순서_배포SQL/05_SV-Agent_ai/05_NN_SV_DDL_*.sql` · ML 계열은 `21_ML_SERVING_뷰_DDL.sql`(base 뷰) → `22_ML_SV_DDL.sql`·`23`·`24`·`25`(SV). 라이브에서 직접 고치지 않는다.
2. **파일 전체를 실행한다.** `CREATE OR REPLACE SEMANTIC VIEW` 는 부여를 지운다 — 파일 끝 GRANT(REFERENCES+SELECT × ANALYST·VIEWER·SERVICE)까지 실행해야 한다. SV 는 FUTURE grant 가 없다.
3. **base 뷰 권한과 SV 권한을 같은 롤 집합으로 맞춘다.** Cortex Analyst 는 caller 권한으로 base 를 읽는다. 🔴 반례 = `SV_ML_REALTIME_SIMULATOR`(SV 는 소비 3롤 · base 뷰는 ANALYST 만 · DR-04 · 미결).
4. **metric·synonym·VQR**
   - metric 은 그 SV 의 grain 에서만 가산성을 보장한다. 비가산 지표(비율·중복제거 회원수)는 COMMENT 에 「비가산」을 쓴다 — 코퍼스 생성기가 이 단어로 `IS_ADDITIVE='N'` 을 판정한다(py :60~63).
   - synonym 첫 항목 = 표 헤더 한글명으로 쓰인다(Agent 응답 규칙 「표 헤더 한글 강제」).
   - VQR(검증 질의)은 한글 별칭·반올림 규칙을 SV 와 같게 둔다(문서실행순서 :72 O242).
   - `Invalid metric definition … must directly refer to another aggregate-level expression` (010220) = metric 이 다른 metric 을 잘못 참조. 최근 7일 실측 1건(A7 Q05).
5. **SV 를 바꾸면 spec 서술도 본다.** instruction 이 SV 규칙을 사실로 안내하므로, SV 재배포 후 정본 yaml 서술이 여전히 맞는지 확인한다(09_2 :40~41).
6. 신규 SV = 파일 신설 → 문서실행순서 목록에 추가 → spec `tools`·`tool_resources` 에 배선 → §4 버전업.

## 3. [공통] Agent 버전업 절차 (`09_2_AGENT_버전업.sql` · 🔴 사람이 실행)

| 단계 | 내용 | 판정 |
|---|---|---|
| 사전 | `python3 scripts/sv_identifier_gate.py` | exit 0 · 🔴 09_2 [0] 정적 목록은 SV 4종이 빠져 낡았다(DR-16) ⇒ 게이트를 정본으로 쓴다 |
| [0-B] | spec 을 워크스페이스 → `@OPS.AGENT_SPEC_STAGE` 로 `COPY FILES`(PATTERN 필수) | — |
| [0-C] | 스테이지 ↔ 워크스페이스 대조(size · last_modified) | 전건 `OK` · 🔴 md5 로 대조하지 않는다(암호화 blob 해시) |
| [1] | `SHOW VERSIONS` — 🔴 **롤백 기준 버전 번호를 적어 둔다** | — |
| [2] | live 버전 선소진(COMMIT) | — |
| [3] | `ALTER AGENT … ADD VERSION FROM '@GN_DW.OPS.AGENT_SPEC_STAGE/<AGENT>'` | 새 버전이 자동 default(O184 실측) |
| [5] | 도구 수 · grant 4행 · CoWork 3행 확인 · COMMENT 동기화(09_1 [5]) | spec 도구 수 = `D09_Agent도구.csv` 로 확인(문서에 적지 않는다) |
| [6] | 롤백 = `ALTER AGENT … SET DEFAULT_VERSION = 'VERSION$n'` | 명명 버전은 불변 스냅샷 |

주의:
- 🔴 `cortex_agent_save`·Snowsight UI 저장은 **live 버전**을 만든다. 섞어 쓰면 매번 [2] 가 COMMIT 하며 의미 없는 버전이 쌓인다 ⇒ 파일 경로만 쓴다(09_2 :43~48).
- 🔴 [0-B]·[0-C] 를 건너뛰면 **구버전 spec 이 에러 없이 배포**된다.
- 🔴 [0-C] 는 파일을 다른 계정으로 옮긴 직후 **크기가 같아도 `STAGE_STALE`** 을 낸다(워크스페이스 시각이 더 늦다 · DR-17). 그때는 [0-B] 를 한 번 더 돌린다.
- ⚠️ 배포 경로 `USER$.PUBLIC."snowflake_files"` 는 실행하는 사람의 개인 워크스페이스다. 운영계는 배포 담당자의 워크스페이스에 파일이 있어야 한다. GN_DW_ADMIN 의 `USER$` 접근 오류 48건이 관찰됐다(원인 미확정 · DR-23).
- Agent 를 새로 만들면 소비 3롤 USAGE + `ALTER SNOWFLAKE INTELLIGENCE … ADD AGENT` 가 필요하다(09_1 · 08 §F).

## 4. [공통] 응답 품질 규칙 관리

- 응답 규칙(형식·한글 헤더·NGO 표현·수치 근거 자가점검 등)은 spec `instructions.response`·`orchestration` 에 있다. 실측 길이(문자) = response 5,421 / 5,704 / 4,963 · orchestration 14,841 / 15,968 / 21,358(EXECUTIVE / MARKETING / MEMBER).
- 규칙을 고치면 3종에 같이 반영할지 먼저 정한다(대부분 「전 Agent 공통」 규칙).
- 버전업 후 최소 스모크 = 각 Agent 추천 질문을 Snowflake Intelligence 에서 1회씩 실행해 도구 라우팅을 본다(09_2 [7] · 「배포 완료」 ≠ 「라우팅 검증 완료」).
- 현재 열린 스모크·eval 과제 = A8 (O246-D ①·②).

## 5. [공통] RAG 지표사전 코퍼스 재생성

```
# ① 코퍼스 CSV 재생성 (워크스페이스 · 원천 = 05_RAG_지표사전/90_provided_definition/ + 12_agent개선과제/tools/*.csv)
python3 12_agent개선과제/tools/build_biz_definition_corpus.py          # CSV 만
# ② Snowflake 적재 — 둘 중 하나
python3 12_agent개선과제/tools/build_biz_definition_corpus.py --apply  # TRUNCATE + write_pandas
#    또는 26_BIZ_DEFINITION_CORPUS_DDL_적재.sql [3]·[4] (COPY FILES → COPY INTO)
```

- 원칙: 셀 값은 요약·가필하지 않는다. 동의어·산식 배선은 **오버레이 csv**(`O233_synonym_overlay.csv` · `O237_formula_wiring_overlay.csv`)로만 덧붙인다 — 원천(`90_provided_definition/`)을 고치지 않는다.
- 생성기가 멈추는 조건 = DOC_ID 중복 · 오버레이 DOC_ID 부재 · 이미 값이 있는 동의어 덮어쓰기 · 산식 없는 행에 산식 오버레이.
- 🔴 26 SQL [1] 은 `CREATE OR REPLACE TABLE` 이다 — 다시 돌리면 [6] GRANT 까지 다시 실행한다. 데이터만 바꿀 때는 [3]·[4] 또는 `--apply` 만 쓴다.
- Search 는 `TARGET_LAG = '1 day'` 라 적재 후 반영까지 시간이 걸릴 수 있다. 바로 반영하려면 서비스를 갱신한다.
- 검증: 26 [7] 의 DOC_TYPE 기대값은 낡았다(DR-22). 판정 등식을 쓴다.
  - 산식 행(`HAS_FORMULA='Y'`) = COVERAGE 채워진 행(2026-10-20 = 146 = 146).
    - 🔴 [2026-10-30 재측정 · CSV] `HAS_FORMULA='Y'` 153 ≠ COVERAGE 채워진 행 146 — O274 신규 7행(RT-31~37)이 `HAS_FORMULA='Y'` · COVERAGE 빈칸이다(CSV 실측) ⇒ 등식 재정의 또는 COVERAGE 보강 필요(A8).
  - Search 원천 행수 = 전체 − 원천참고(2026-10-30 CSV = 2,163 − 1,154 = 1,009 · SHOW CORTEX SEARCH `source_data_num_rows` 대조 = TBD(미검증)).

## 6. [ENV] 운영계 반영 시 확인

| 항목 | 운영계 |
|---|---|
| Agent 기본 버전 | MEMBER VERSION$30 · EXECUTIVE VERSION$23 · MARKETING VERSION$26(2026-10-31 A6 Q07) |
| spec 스테이지 size | TBD(미검증) |
| 코퍼스 행수 | TBD(미검증) |
| Search `source_data_num_rows` | TBD(미검증) |
