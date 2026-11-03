<!-- LLM-METADATA
doc_id: REUSE_KIT_README
doc_role: 재사용 키트 설치 안내 — 새 프로젝트 루트 배치 규약 · 이름 적용 · 점검
created: 2026-11-02
END-METADATA -->

# _reuse_kit — 새 Snowflake 구축 프로젝트용 재사용 키트

> 원 프로젝트(GN_DW · O276 종료)의 지침·스킬·도구·골격을 **복사 + 일반화**한 것이다. 원본은 무변경.
> 목록 = `00_INVENTORY.md` · 자리표시자 = `01_PLACEHOLDERS.md`(`{{DB}}` · `{{ACCOUNT}}`).

## 1. 설치 — 새 프로젝트 루트 배치

| 키트 폴더 | 새 프로젝트 위치 | 비고 |
|---|---|---|
| `11_project_template/01_project_control/` · `_archive/` · `.gitignore` | `<루트>/` | 🆕 [O277] 프로젝트 관리 단일 폴더 = 이슈 원장 · 결정(DEC) · 세션 이력 · 사고사례 · 착수표 · 라벨 폴더 · `98_worklog/` · 🆕 `.gitignore` = `tmp/` 제외 |
| `11_project_template/00_표준_폴더번호표.md` | (참고) | 🆕 [O277] 표준 최상위 번호표 · `01_project_control` 내부 규약 · 원 프로젝트 → 표준 대응표 |
| `01_agent_rules/` 의 내용 | `<루트>/00_guides/` | 작업 지침 · 분할·쓰기 규약 · 단계종료 게이트 |
| `02_skill_init/*.md` | `<루트>/00_guides/` | init 스킬 정본 4종 |
| `02_skill_init/*.py` · `03_session_tools/*` · `07_ops_tools/*.py` · `08_handover_templates/*.py` | `<루트>/scripts/` | 🔴 `kit_paths.py` 와 **같은 폴더**여야 import 된다 · 🆕 [O277] 생성기 4종(`a2_matrix_build` 등)도 여기 — `gate_census` 등재표가 `scripts/` 에서 찾는다(빠지면 유령 4건 FAIL) |
| `02_skill_init/init_ihcho/` | `<루트>/.snowflake/cortex/skills/init_ihcho/` | 빌더 산출물(손으로 고치지 않는다) |
| `04_methodology/` · `05_build_skeleton/` · `06_dbt_macros/` · `08_handover_templates/` · `09_skill_mstr/` · `10_streamlit/` | 필요한 곳 | 참고·골격(위치 자유) · dbt 매크로는 `<dbt>/macros/` |

## 2. 이름 적용 · 점검

```
python3 _reuse_kit/apply_names.py --set DB=NEW_DW --set ACCOUNT=ab12345 --apply   # 설치 전 1회
python3 scripts/split_doc.py 00_guides/01_문서분할_규약.md --republish --label INIT  # 🔴 이름 적용이 조각 본문을 바꾼다 ⇒ 허브 SHA256 재발행
python3 scripts/kit_paths.py --check                 # 관례 레이아웃 실재(필수 7종 · PC_DIR = 01_project_control)
python3 scripts/verify_init_ihcho_skill.py           # 스킬 정본 ↔ 산출물
python3 scripts/index_row_gate.py --update-golden --reason "최초 설치"   # 골든 기준선 발행(최초 1회)
python3 scripts/doc_heading_gate.py --update-golden
mkdir -p tmp                                          # 🆕 임시 파일 = 워크스페이스 tmp/ (OS /tmp 는 재시작 때 지워진다)
python3 scripts/session_brief.py --write             # 첫 브리핑 · 게이트 ⚪ = 미설치/전제 부재(건너뜀)
```

- 테스트 = `03_session_tools/00_TESTS.md`(🆕 O277-B 현행 = 39종 중 통과 31 · 원 프로젝트 데이터 의존 8 — 의존분 FAIL 은 정상 · §6 ①).
- 🟢 단독 반출 실측(2026-11-02) = 이 절차대로 빈 루트에 조립 → 브리핑 게이트 ✅ 6 · 🟡 1(원 프로젝트 문서 참조 경고) · ⚪ 12 · 🔴 0.

- 루트를 바꿔 실행 = 환경변수 `KIT_ROOT=<루트>`. 폴더 이름을 바꾸려면 `kit_paths.py` 상수 + 도구 본문 문자열을 **함께** 고친다.
- 스킬 본문을 고쳤으면 `python3 scripts/build_init_ihcho_skill.py --apply`(스킬을 손으로 고치지 않는다).

## 3. 일반화 이력(2026-11-02)

- `GN_DW` → `{{DB}}` · 계정 로케이터 → `{{ACCOUNT}}`(세션 라벨 `O##` · 주석 · `굿네이버스` 문구는 유지).
- dbt 매크로 `gn_` 접두 제거 2종(`no_structural_alter` · `view_commented`).
- 도구 루트 = `kit_paths.ROOT` 일원화(47파일) · 원 프로젝트 아카이브 경로 접두(`_archive/O276_project_closure/`) 제거 12파일.
- 템플릿 본문 수치 = 원 프로젝트 샘플(`08_handover_templates/00_SAMPLE_NOTICE.md`).

## 4. 🆕 [O277 · 2026-11-02] 레이아웃 = `01_project_control/`

- 세션 운영물(`20_issue/` · `99_NEXT_SESSION*` · `40_worklog/`)을 `01_project_control/` 한 폴더로 모았다 ⇒ 종료 = 이 폴더 하나만 `_archive/` 로.
- `kit_paths.py` = `PC_DIR` 신설 · `ISSUE_DIR`·`ISSUE_INDEX`·`NEXT_FILE`·`NEXT_DIR`·`WORKLOG_DIR` 이 그 아래.
- 경로 치환 = 42파일 284행(도구 · 테스트 · 지침 · init 스킬 정본/산출물 · `09_skill_mstr`) · 제외 = `08_handover_templates/`(샘플) · 개발이력(각주) · `00_INVENTORY.md`(복사 시점 기록).
- 분모 보정 3건 = `doc_type_gate`(순회 ∪ EXTRA_DOCS 중복 제거 · `98_worklog` 제외) · `classify_doc_type`(`98_worklog` 제외) · `decision_closure_gate`(`98_worklog`·라벨 폴더 제외 = 종전 분모 유지).
- 테스트 픽스처 보정 1건 = `test_handoff_write`(허브를 `01_project_control/` 아래에 만든다).
- 템플릿 추가 = `30_설계_의사결정.md`(§0 등재) · `98_worklog/00_README.md`.
- 검증 = 빈 루트 조립 → 테스트 35종 rc 기준선과 동일(24 통과 · 실패 11 = 원 데이터 의존 10 + `test_gate_census` 기존 실패) · `kit_paths --check` · `verify_init_ihcho_skill` · `doc_type_gate` · `doc_census` · `decision_closure_gate` · `session_brief --write` PASS.

## 5. 🆕 [O277-B · 2026-11-03] 정합 보정

- 과거 기록 13곳 복원 = O277 치환이 사고 서술·근거 좌표(`20_issue/91_사고사례집.md §Cnn` 6곳 등)까지 바꿨다 → 원 표기로 되돌림(지시문만 새 경로).
- 테스트 보정 = 설치 규약에 생성기 4종(`08_handover_templates/*.py` → `scripts/`) 추가 → `test_gate_census` 통과 · `test_mutating_guard`·`test_snapshot_util` = 원 프로젝트 도구 이름 단정 → 키트 반입분만 판정.
- 임시 파일 규칙 = 지침 `R0-8-5` · init 스킬 Step 0·G1 = 워크스페이스 `tmp/` · 템플릿 `.gitignore` 추가.
- 키트 위생 = `07_ops_tools/__pycache__/*.pyc` 삭제 · 마운트 ↔ 스테이지 파일 239/239 일치 확인.
- 재현 도구(원 워크스페이스) = `_archive/O276_project_closure/o277_kit_assemble.py`(조립) · `o277_kit_pc_replace.py`(경로 치환) · `o276_kit_selftest.py`(자가 테스트).
- 롤백본 = `_archive/O277_kit_pc_pre/` · `O277_kit_fix_pre/` · `O277_tmp_rule_pre/`.

## 6. 🔴 새 환경에서 할 일 (키트 반출 후 · 원 워크스페이스에서는 하지 않는다)

> 이 항목들은 **새 프로젝트의 데이터·이름이 정해져야** 할 수 있다 — 키트 단계에서 미리 하면 원 프로젝트 기준으로 굳는다.

| # | 할 일 | 언제 | 방법 |
|---|---|---|---|
| ① | 데이터 의존 테스트 8종 픽스처 교체 | 해당 산출물이 생긴 뒤 | `03_session_tools/00_TESTS.md` §1 표의 「새 프로젝트 처리」 열 — 원장 분할 후(`decision_closure`·`doc_census`·`doc_type_gate_denominator`) · 문서 축적 후(`split_doc_toc`) · SV DDL 배치 후(`sv_*` 3종) · RBAC 분류표 작성 후(`rbac_source_gate`) |
| ② | 이름 적용 | 설치 직후 1회 | §2 `apply_names.py --set DB=… --set ACCOUNT=… --apply` → 분할 허브 `--republish` |
| ③ | `굿네이버스` 문구 · 세션 라벨(`O###`) 정리 여부 결정 | 설치 직후 | 지침·규약 본문의 사례 서술에 남아 있다(일반화 이력 §3 = 의도 잔존). 지울지·「원 프로젝트 사례」로 표기할지 결정 |
| ④ | 골든 기준선 최초 발행 | 원장에 첫 행이 생긴 뒤 | §2 `index_row_gate --update-golden` · `doc_heading_gate --update-golden` |
| ⑤ | 원 프로젝트 근거 좌표 처리 | 필요할 때 | 규약·스킬의 `20_issue/91_사고사례집.md §Cnn` 등은 **원 워크스페이스** 좌표다 — 새 프로젝트에는 없다. 사례집을 함께 가져가거나 「원 프로젝트 사례」로 읽는다 |
| ⑥ | 표준 폴더 번호 적용 | 착수 시 | `11_project_template/00_표준_폴더번호표.md` §1 · 배포 경로가 될 폴더(dbt 등)는 처음부터 최종 위치에 |
