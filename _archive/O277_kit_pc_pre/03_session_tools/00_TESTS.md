<!-- LLM-METADATA
doc_id: REUSE_KIT_TESTS
doc_role: 키트 음성 테스트 목록 — 이식 가능 / 원 프로젝트 데이터 의존 구분(2026-11-02 조립 실측)
created: 2026-11-02
END-METADATA -->

# 테스트 목록 (_reuse_kit)

> 실측 = 빈 템플릿(`11_project_template/`)으로 조립한 새 루트에서 `test_*.py` 를 각 120초 제한으로 실행(2026-11-02).
> 결과 = **이식 가능 29 · 원 프로젝트 데이터 의존 10**. 의존 10종은 키트 결함이 아니라 **원 프로젝트 실데이터를 단정**한다.

## 1. 원 프로젝트 데이터 의존 (새 프로젝트에서 FAIL 이 정상)

| 테스트 | 무엇을 단정하나 | 새 프로젝트 처리 |
|---|---|---|
| `test_decision_closure_gate.py` | 분할된 이슈 원장 허브 · `_o118_sv_live_census.md` 실재 | 원장이 분할된 뒤 픽스처를 새 파일명으로 바꾼다 |
| `test_doc_census.py` | 분할 문서 12종 전건 누락 보고 | 분할 문서가 생기면 기대 건수를 실측으로 바꾼다 |
| `test_doc_type_gate_denominator.py` | `99_NEXT_SESSION` 조각 편입(조각 35개) | 착수표가 분할된 뒤 통과 |
| `test_mutating_guard.py` | 원 프로젝트 도구 `_o170_reserve.py` 를 피해자로 쓴다 | 피해자를 키트 MUTATES 도구(예 `run_sql_file`)로 바꾼다 |
| `test_rbac_source_gate.py` | `30_operate/…` 원천 분류표 csv | 분류표를 만든 뒤 통과 |
| `test_snapshot_util.py` 축7 | 스냅샷 쓰는 원 도구 전수(`gen_gold_erd.py` 등) | 축7 대상 목록을 키트 도구로 줄인다 |
| `test_split_doc_toc.py` | 실제 문서 제목 100개 이상(분모 붕괴 판정) | 문서가 쌓이면 통과 |
| `test_sv_identifier_gate.py` ③④ | SV DDL 정본(`20_build/23_sv_agent/`) | SV DDL 을 둔 뒤 통과 |
| `test_sv_no_rollup_gate.py` | 같은 SV 폴더 | 같은 |
| `test_sv_rule7_scan.py` | `22_ML_SV_DDL.sql` 등 원 SV 파일 | 같은 |

## 2. 이식 가능 (빈 루트에서 PASS)

- 세션 도구 = `test_session_brief` · `test_handoff_write` · `test_handoff_ddl_gate` · `test_index_row_gate` · `test_doc_coord_gate`
  · `test_retire_rows` · `test_retire_sections` · `test_split_doc_dryrun` · `test_split_doc_expect` · `test_split_doc_truncated_table`
  · `test_split_narrative` · `test_stage_mount_size_gate` · `test_gate_census`
- 운영 도구 = `test_audit_ddl_rule7` · `test_env_capture` · `test_jinja_config_gate` · `test_live_change_gate` · `test_null_reason_registry_gate`
  · `test_run_sql_block` · `test_sv_common_block_gate` · `test_sv_enum_newvalue_gate` · `test_sv_unit_gate_agent`
- 생성기 = `test_a2_matrix_build` · `test_b_struct_build` · `test_n03_catalog_build` · `test_n05_report_build`
- 그 밖 = `kit_paths --check` · `verify_init_ihcho_skill` · `session_brief --write`

## 3. 키트에서 고친 결함 (조립 실측으로 발견)

- `gate_census` 등재표 = 원 프로젝트 스크립트 95종 유령 → 키트 집합으로 정리 · `kit_paths`(LIB) · `build_folder_index`(MUTATES) 등재.
- `audit_ddl_rule7` · `deploy_sv` 누락(`sv_rule7_scan`·`gate_census` 테스트가 요구) → 키트 편입.
- `doc_heading_gate` = 부재 문서를 골든에 `None` 으로 써 다음 판정이 죽었다 → 부재 문서는 기준선에서 제외.
- `session_brief` 게이트 표 = 미설치 게이트·전제 경로 부재를 🔴 로 냈다 → **⚪ 건너뜀**(`kit_paths.GATE_REQUIRES`).
