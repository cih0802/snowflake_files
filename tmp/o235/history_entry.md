## O235-A 누계중단비중 「산식 미등록」 답변 시정 — 검색 도구 컬럼 배선 + 산식 질문 필터·규칙 (2026-10-15 · ua91864 작성 · jw08094 반영(사용자) · ㉡ 적용 · 사용자 승인 · 확정위반 2)

- 착수 = 사용자 지적 「캠페인별 누계중단율 산식(신규지표_20260820.csv:29)이 있는데 Agent 가 미등록이라 답함」 · 브리핑 후 지시 동봉 ⇒ 즉시 수행(`R4-4-2`).
- 원인 ① = 코퍼스 CSV 에는 MET_NEW-17 산식이 이미 있었다(CSV 결함 아님) · Agent 검색 도구가 O233-B multi-index 서비스에 컬럼을 지정하지 않아 호출 오류(`Column DOC_ID doesn't have a text index or a vector index` · `Text only search is not supported`).
- 원인 ② = 「누계중단비중」이 산식 없는 용어(TERM-0283·0284·0285)의 동의어라 상위 노출.
- 조치 ㉠ = `tools/O217_routing_curated.csv` RT-30 신설(원천 무수정 · R2-8) · 생성기 `HAS_FORMULA` 열(맨 끝 · Y = FORMULA 비어 있지 않음) · 산식 공란 지표·용어 본문에 「계산식: 이 항목에는 미등록(원천 공란)」 · 26 DDL 테이블 열·ATTRIBUTES·SELECT 추가 · 코퍼스 2,156행.
- 조치 ㉡㉢ = 정본 `cortex_project/agents/*/agent_spec.yaml` 3종에 `columns_and_descriptions`(검색 TITLE·KEYWORDS·SEARCH_TEXT · 필터 DOC_TYPE·HAS_FORMULA) + orchestration 머리 [O235 산식 질문] · [O233 유사 지표 되묻기] 「미등록」 문장에 O235 우선 단서.
- 검증(ua91864) = 백업 대비 의미 diff 3/3 = 변경 키 `tool_resources`·`instructions.orchestration` 만 · orchestration = 새 문단 + 원문(단서 1곳) 정확 일치 · spec 38K~58K자 · line_len PASS.
- 보조 = `tools/o235_patch_search_cols.py`(라이브 export 경로용 · 정본 yaml 과 COLS 일치) · `o234_probe_set.csv` 26문항(RT-30 정답 추가 · 문항 25·26 신설).
- 정리 = `cortex_project` 루트 `*.agent.yaml` 3 · `*.eval.yaml` 14 → `_archive/`(09_2 배포 정본 = `agents/*/agent_spec.yaml` 실측) · `cortex-project.yaml` 정본 3 항목만(부재 AGENT_OVERALL · dataset 3 제거).
- 라이브 변경(jw08094 · 사용자 실행) = 26 DDL(코퍼스·검색 서비스 재생성) · 09_2 = AGENT_EXECUTIVE VERSION$13→$14(도구 15) · AGENT_MARKETING $16→$17(도구 26) · AGENT_MEMBER $20→$21(도구 25) · diff 2키만 확인 후 배포 · 탐침 n=26 hit@1 22(85%) · hit@3 24(92%).
- 확정위반 2: ㉠ `R1-4-3` O235 라벨 원장 선점을 착수 시 하지 않고 종료 시 등재 · ㉡ `R1-7-8` 원장 §1 행 앵커가 O234 행 머리를 삼켜 두 행 병합(즉시 분리 복구 · index_row_gate 유실 0).
- 원본 백업 = `cortex_project/_archive/AGENT_*.agent_spec.yaml.O235-before` · `cortex-project.yaml.O235-before`.

### 독해 기록(`R1-3-7-b`)

- 지침 1~304 · 도착 · `R0-8-4` · `R4-4-4` · `O173`.
- `00_BRIEF.md` 1~155 · 도착 · `O0234-D` · `doc_coord_gate` 🔴 · `agent_object_ref_gate` 111.
- `build_biz_definition_corpus.py` 1~275 · `26_BIZ_DEFINITION_CORPUS_DDL_적재.sql` 1~97 · `o217_agent_io.py` 1~96 · 도착 · `synonym_overlay` · `AGENT_SCOPE_ARR` · `live_spec`.
- `99_NEXT_SESSION-O0234-D.md` 1~50 · 도착 · `O234-D-2` · `gold_erd_coverage_gate`.
- read 미반환 0 · 재호출 0.

_Co-authored with CoCo_
