<!-- LLM-METADATA
doc_id: REUSE_KIT_INVENTORY
doc_role: 재사용 키트 목록 — 원본 경로 · 키트 경로 · 해시 대조 · 고유어 잔존(일반화 대상)
created: 2026-11-02
created_by: O276-C (00_REFERENCE_CLEANUP_PLAN.md §8)
END-METADATA -->

# 재사용 키트 목록 (_reuse_kit)

> 원본은 무변경이다. 이 폴더는 **복사본**이며 일반화 편집은 여기서만 한다.
> 잔존 열 = 키트 사본 안의 고유어 출현 횟수(GN_DW · 굿네이버스 · 계정로케이터 · 세션라벨 `O##`) — 0 이 될 때까지 일반화 대상이다.
> 🆕 [2026-11-02] 이 표는 **복사 시점** 값이다. 이후 `GN_DW` → `{{DB}}` · 계정 로케이터 → `{{ACCOUNT}}` 치환 완료(잔존 0) ⇒ 현황 = `01_PLACEHOLDERS.md` · 실제 이름 적용 = `apply_names.py`.

## 1. 요약

| 그룹 | 파일 | 해시 일치 | GN_DW | 굿네이버스 | 계정 | 라벨 |
|---|---|---|---|---|---|---|
| `01_agent_rules` | 10 | 10/10 | 5 | 5 | 0 | 236 |
| `02_skill_init` | 10 | 10/10 | 4 | 4 | 0 | 92 |
| `03_session_tools` | 49 | 49/49 | 19 | 8 | 0 | 1108 |
| `04_methodology` | 5 | 5/5 | 4 | 5 | 0 | 1 |
| `05_build_skeleton` | 8 | 8/8 | 14 | 1 | 0 | 1 |
| `06_dbt_macros` | 7 | 7/7 | 7 | 0 | 0 | 18 |
| `07_ops_tools` | 31 | 31/31 | 87 | 3 | 2 | 322 |
| `08_handover_templates` | 34 | 34/34 | 200 | 1 | 84 | 43 |
| `09_skill_mstr` | 59 | 59/59 | 73 | 0 | 0 | 8 |
| `10_streamlit` | 3 | 3/3 | 125 | 0 | 0 | 0 |

- 원본 부재(목록에서 제외) = 0건

## 2. 파일별

| 그룹 | 키트 경로 | 원본 | 해시 | GN_DW | 굿네이버스 | 계정 | 라벨 |
|---|---|---|---|---|---|---|---|
| 01_agent_rules | `01_agent_rules/00_작업지침_세션운영규칙.md` | `00_guides/00_작업지침_세션운영규칙.md` | OK | 0 | 0 | 0 | 46 |
| 01_agent_rules | `01_agent_rules/01_문서분할_규약.md` | `00_guides/01_문서분할_규약.md` | OK | 1 | 1 | 0 | 3 |
| 01_agent_rules | `01_agent_rules/02_파일쓰기_안전규약.md` | `00_guides/02_파일쓰기_안전규약.md` | OK | 1 | 1 | 0 | 27 |
| 01_agent_rules | `01_agent_rules/04_단계종료_게이트.md` | `00_guides/04_단계종료_게이트.md` | OK | 1 | 1 | 0 | 27 |
| 01_agent_rules | `01_agent_rules/01_문서분할_규약_조각/00_FOLDER_INDEX.md` | `00_guides/01_문서분할_규약_조각/00_FOLDER_INDEX.md` | OK | 0 | 0 | 0 | 0 |
| 01_agent_rules | `01_agent_rules/01_문서분할_규약_조각/00_README.md` | `00_guides/01_문서분할_규약_조각/00_README.md` | OK | 0 | 0 | 0 | 1 |
| 01_agent_rules | `01_agent_rules/01_문서분할_규약_조각/00_선택표.md` | `00_guides/01_문서분할_규약_조각/00_선택표.md` | OK | 1 | 1 | 0 | 41 |
| 01_agent_rules | `01_agent_rules/01_문서분할_규약_조각/01_문서분할_규약-001.md` | `00_guides/01_문서분할_규약_조각/01_문서분할_규약-001.md` | OK | 1 | 1 | 0 | 3 |
| 01_agent_rules | `01_agent_rules/01_문서분할_규약_조각/01_문서분할_규약-002.md` | `00_guides/01_문서분할_규약_조각/01_문서분할_규약-002.md` | OK | 0 | 0 | 0 | 50 |
| 01_agent_rules | `01_agent_rules/01_문서분할_규약_조각/01_문서분할_규약-003.md` | `00_guides/01_문서분할_규약_조각/01_문서분할_규약-003.md` | OK | 0 | 0 | 0 | 38 |
| 02_skill_init | `02_skill_init/03_init_ihcho_스킬_본문.md` | `00_guides/03_init_ihcho_스킬_본문.md` | OK | 1 | 1 | 0 | 1 |
| 02_skill_init | `02_skill_init/03_init_ihcho_스킬_정본.md` | `00_guides/03_init_ihcho_스킬_정본.md` | OK | 1 | 1 | 0 | 7 |
| 02_skill_init | `02_skill_init/03_init_ihcho_스킬_참조_세션종료.md` | `00_guides/03_init_ihcho_스킬_참조_세션종료.md` | OK | 1 | 1 | 0 | 9 |
| 02_skill_init | `02_skill_init/03_init_ihcho_스킬_개발이력.md` | `00_guides/03_init_ihcho_스킬_개발이력.md` | OK | 1 | 1 | 0 | 52 |
| 02_skill_init | `02_skill_init/build_init_ihcho_skill.py` | `scripts/build_init_ihcho_skill.py` | OK | 0 | 0 | 0 | 8 |
| 02_skill_init | `02_skill_init/verify_init_ihcho_skill.py` | `scripts/verify_init_ihcho_skill.py` | OK | 0 | 0 | 0 | 7 |
| 02_skill_init | `02_skill_init/init_ihcho/SKILL.md` | `.snowflake/cortex/skills/init_ihcho/SKILL.md` | OK | 0 | 0 | 0 | 0 |
| 02_skill_init | `02_skill_init/init_ihcho/references/doc-map.md` | `.snowflake/cortex/skills/init_ihcho/references/doc-map.md` | OK | 0 | 0 | 0 | 0 |
| 02_skill_init | `02_skill_init/init_ihcho/references/new-doc.md` | `.snowflake/cortex/skills/init_ihcho/references/new-doc.md` | OK | 0 | 0 | 0 | 0 |
| 02_skill_init | `02_skill_init/init_ihcho/references/session-end.md` | `.snowflake/cortex/skills/init_ihcho/references/session-end.md` | OK | 0 | 0 | 0 | 8 |
| 03_session_tools | `03_session_tools/session_brief.py` | `scripts/session_brief.py` | OK | 1 | 1 | 0 | 83 |
| 03_session_tools | `03_session_tools/doc_census.py` | `scripts/doc_census.py` | OK | 0 | 0 | 0 | 60 |
| 03_session_tools | `03_session_tools/doc_line_length_gate.py` | `scripts/doc_line_length_gate.py` | OK | 0 | 0 | 0 | 57 |
| 03_session_tools | `03_session_tools/doc_heading_gate.py` | `scripts/doc_heading_gate.py` | OK | 0 | 0 | 0 | 43 |
| 03_session_tools | `03_session_tools/doc_coord_gate.py` | `scripts/doc_coord_gate.py` | OK | 0 | 0 | 0 | 29 |
| 03_session_tools | `03_session_tools/doc_type_gate.py` | `scripts/doc_type_gate.py` | OK | 0 | 0 | 0 | 30 |
| 03_session_tools | `03_session_tools/decision_closure_gate.py` | `scripts/decision_closure_gate.py` | OK | 0 | 0 | 0 | 43 |
| 03_session_tools | `03_session_tools/split_doc.py` | `scripts/split_doc.py` | OK | 2 | 2 | 0 | 105 |
| 03_session_tools | `03_session_tools/retire_sections.py` | `scripts/retire_sections.py` | OK | 0 | 0 | 0 | 19 |
| 03_session_tools | `03_session_tools/retire_rows.py` | `scripts/retire_rows.py` | OK | 0 | 0 | 0 | 12 |
| 03_session_tools | `03_session_tools/handoff_ddl_gate.py` | `scripts/handoff_ddl_gate.py` | OK | 7 | 0 | 0 | 12 |
| 03_session_tools | `03_session_tools/handoff_write.py` | `scripts/handoff_write.py` | OK | 2 | 2 | 0 | 16 |
| 03_session_tools | `03_session_tools/line_len.py` | `scripts/line_len.py` | OK | 0 | 0 | 0 | 3 |
| 03_session_tools | `03_session_tools/snapshot_util.py` | `scripts/snapshot_util.py` | OK | 0 | 0 | 0 | 14 |
| 03_session_tools | `03_session_tools/snapshot_cli.py` | `scripts/snapshot_cli.py` | OK | 0 | 0 | 0 | 6 |
| 03_session_tools | `03_session_tools/id_collision_gate.py` | `scripts/id_collision_gate.py` | OK | 0 | 0 | 0 | 36 |
| 03_session_tools | `03_session_tools/clause_order_gate.py` | `scripts/clause_order_gate.py` | OK | 0 | 0 | 0 | 12 |
| 03_session_tools | `03_session_tools/index_row_gate.py` | `scripts/index_row_gate.py` | OK | 0 | 0 | 0 | 35 |
| 03_session_tools | `03_session_tools/stage_mount_size_gate.py` | `scripts/stage_mount_size_gate.py` | OK | 0 | 0 | 0 | 12 |
| 03_session_tools | `03_session_tools/gate_census.py` | `scripts/gate_census.py` | OK | 4 | 0 | 0 | 88 |
| 03_session_tools | `03_session_tools/new_tool.py` | `scripts/new_tool.py` | OK | 0 | 0 | 0 | 9 |
| 03_session_tools | `03_session_tools/mutating_guard.py` | `scripts/mutating_guard.py` | OK | 0 | 0 | 0 | 4 |
| 03_session_tools | `03_session_tools/classify_doc_type.py` | `scripts/classify_doc_type.py` | OK | 0 | 0 | 0 | 1 |
| 03_session_tools | `03_session_tools/build_folder_index.py` | `scripts/build_folder_index.py` | OK | 0 | 0 | 0 | 0 |
| 03_session_tools | `03_session_tools/split_narrative.py` | `scripts/split_narrative.py` | OK | 1 | 1 | 0 | 31 |
| 03_session_tools | `03_session_tools/split_issue_index.py` | `scripts/split_issue_index.py` | OK | 2 | 2 | 0 | 9 |
| 03_session_tools | `03_session_tools/wrap_for_read.py` | `scripts/wrap_for_read.py` | OK | 0 | 0 | 0 | 4 |
| 03_session_tools | `03_session_tools/ws_stage_verify.py` | `scripts/ws_stage_verify.py` | OK | 0 | 0 | 0 | 10 |
| 03_session_tools | `03_session_tools/fix_stale_counts.py` | `scripts/fix_stale_counts.py` | OK | 0 | 0 | 0 | 12 |
| 03_session_tools | `03_session_tools/test_session_brief.py` | `scripts/test_session_brief.py` | OK | 0 | 0 | 0 | 73 |
| 03_session_tools | `03_session_tools/test_doc_census.py` | `scripts/test_doc_census.py` | OK | 0 | 0 | 0 | 13 |
| 03_session_tools | `03_session_tools/test_doc_coord_gate.py` | `scripts/test_doc_coord_gate.py` | OK | 0 | 0 | 0 | 20 |
| 03_session_tools | `03_session_tools/test_doc_type_gate_denominator.py` | `scripts/test_doc_type_gate_denominator.py` | OK | 0 | 0 | 0 | 2 |
| 03_session_tools | `03_session_tools/test_decision_closure_gate.py` | `scripts/test_decision_closure_gate.py` | OK | 0 | 0 | 0 | 35 |
| 03_session_tools | `03_session_tools/test_split_doc_dryrun.py` | `scripts/test_split_doc_dryrun.py` | OK | 0 | 0 | 0 | 4 |
| 03_session_tools | `03_session_tools/test_split_doc_expect.py` | `scripts/test_split_doc_expect.py` | OK | 0 | 0 | 0 | 10 |
| 03_session_tools | `03_session_tools/test_split_doc_toc.py` | `scripts/test_split_doc_toc.py` | OK | 0 | 0 | 0 | 24 |
| 03_session_tools | `03_session_tools/test_split_doc_truncated_table.py` | `scripts/test_split_doc_truncated_table.py` | OK | 0 | 0 | 0 | 2 |
| 03_session_tools | `03_session_tools/test_retire_sections.py` | `scripts/test_retire_sections.py` | OK | 0 | 0 | 0 | 26 |
| 03_session_tools | `03_session_tools/test_retire_rows.py` | `scripts/test_retire_rows.py` | OK | 0 | 0 | 0 | 3 |
| 03_session_tools | `03_session_tools/test_handoff_ddl_gate.py` | `scripts/test_handoff_ddl_gate.py` | OK | 0 | 0 | 0 | 4 |
| 03_session_tools | `03_session_tools/test_handoff_write.py` | `scripts/test_handoff_write.py` | OK | 0 | 0 | 0 | 18 |
| 03_session_tools | `03_session_tools/test_snapshot_util.py` | `scripts/test_snapshot_util.py` | OK | 0 | 0 | 0 | 33 |
| 03_session_tools | `03_session_tools/test_index_row_gate.py` | `scripts/test_index_row_gate.py` | OK | 0 | 0 | 0 | 24 |
| 03_session_tools | `03_session_tools/test_stage_mount_size_gate.py` | `scripts/test_stage_mount_size_gate.py` | OK | 0 | 0 | 0 | 5 |
| 03_session_tools | `03_session_tools/test_gate_census.py` | `scripts/test_gate_census.py` | OK | 0 | 0 | 0 | 1 |
| 03_session_tools | `03_session_tools/test_mutating_guard.py` | `scripts/test_mutating_guard.py` | OK | 0 | 0 | 0 | 7 |
| 03_session_tools | `03_session_tools/test_split_narrative.py` | `scripts/test_split_narrative.py` | OK | 0 | 0 | 0 | 5 |
| 03_session_tools | `03_session_tools/optional_gates.sh` | `scripts/optional_gates.sh` | OK | 0 | 0 | 0 | 4 |
| 04_methodology | `04_methodology/01_데이터설계 업무단계 방법론_킴볼 일반론.md` | `00_guides/01_데이터설계 업무단계 방법론_킴볼 일반론.md` | OK | 1 | 2 | 0 | 0 |
| 04_methodology | `04_methodology/02_모던 엔터프라이즈 데이터 아키텍처 설계 가이드.md` | `00_guides/02_모던 엔터프라이즈 데이터 아키텍처 설계 가이드.md` | OK | 1 | 2 | 0 | 0 |
| 04_methodology | `04_methodology/04_YAGNI_원천중심_과잉모델링_방지_원칙.md` | `00_guides/04_YAGNI_원천중심_과잉모델링_방지_원칙.md` | OK | 2 | 1 | 0 | 1 |
| 04_methodology | `04_methodology/MFA 로 인한 로그인 방법 가이드.md` | `00_guides/MFA 로 인한 로그인 방법 가이드.md` | OK | 0 | 0 | 0 | 0 |
| 04_methodology | `04_methodology/로그인 인증 Authentication 설정을 위한 준비_Account Admin.sql` | `00_guides/로그인 인증 Authentication 설정을 위한 준비_Account Admin.sql` | OK | 0 | 0 | 0 | 0 |
| 05_build_skeleton | `05_build_skeleton/53_followup_project/00_FOLDER_INDEX.md` | `50_handover/53_followup_project/00_FOLDER_INDEX.md` | OK | 0 | 0 | 0 | 0 |
| 05_build_skeleton | `05_build_skeleton/53_followup_project/00_README_N07.md` | `50_handover/53_followup_project/00_README_N07.md` | OK | 3 | 1 | 0 | 1 |
| 05_build_skeleton | `05_build_skeleton/53_followup_project/01_RBAC_골격.sql` | `50_handover/53_followup_project/01_RBAC_골격.sql` | OK | 2 | 0 | 0 | 0 |
| 05_build_skeleton | `05_build_skeleton/53_followup_project/02_dbt_골격.md` | `50_handover/53_followup_project/02_dbt_골격.md` | OK | 4 | 0 | 0 | 0 |
| 05_build_skeleton | `05_build_skeleton/53_followup_project/03_SV_Agent_작성규칙.md` | `50_handover/53_followup_project/03_SV_Agent_작성규칙.md` | OK | 2 | 0 | 0 | 0 |
| 05_build_skeleton | `05_build_skeleton/53_followup_project/04_모니터링_SQL.sql` | `50_handover/53_followup_project/04_모니터링_SQL.sql` | OK | 1 | 0 | 0 | 0 |
| 05_build_skeleton | `05_build_skeleton/53_followup_project/05_인수인계문서_규약.md` | `50_handover/53_followup_project/05_인수인계문서_규약.md` | OK | 1 | 0 | 0 | 0 |
| 05_build_skeleton | `05_build_skeleton/53_followup_project/readme.md` | `50_handover/53_followup_project/readme.md` | OK | 1 | 0 | 0 | 0 |
| 06_dbt_macros | `06_dbt_macros/generate_schema_name.sql` | `10_dbt_pipeline/macros/generate_schema_name.sql` | OK | 0 | 0 | 0 | 0 |
| 06_dbt_macros | `06_dbt_macros/gn_no_structural_alter.sql` | `10_dbt_pipeline/macros/gn_no_structural_alter.sql` | OK | 5 | 0 | 0 | 5 |
| 06_dbt_macros | `06_dbt_macros/gn_view_commented.sql` | `10_dbt_pipeline/macros/gn_view_commented.sql` | OK | 1 | 0 | 0 | 6 |
| 06_dbt_macros | `06_dbt_macros/gold_fact_purge.sql` | `10_dbt_pipeline/macros/gold_fact_purge.sql` | OK | 0 | 0 | 0 | 3 |
| 06_dbt_macros | `06_dbt_macros/silver_purge.sql` | `10_dbt_pipeline/macros/silver_purge.sql` | OK | 1 | 0 | 0 | 4 |
| 06_dbt_macros | `06_dbt_macros/gold_helpers.sql` | `10_dbt_pipeline/macros/gold_helpers.sql` | OK | 0 | 0 | 0 | 0 |
| 06_dbt_macros | `06_dbt_macros/silver_helpers.sql` | `10_dbt_pipeline/macros/silver_helpers.sql` | OK | 0 | 0 | 0 | 0 |
| 07_ops_tools | `07_ops_tools/sfconn.py` | `scripts/sfconn.py` | OK | 6 | 0 | 0 | 1 |
| 07_ops_tools | `07_ops_tools/run_sql_file.py` | `scripts/run_sql_file.py` | OK | 10 | 0 | 0 | 9 |
| 07_ops_tools | `07_ops_tools/run_sql_block.py` | `scripts/run_sql_block.py` | OK | 0 | 0 | 0 | 2 |
| 07_ops_tools | `07_ops_tools/sv_no_rollup_gate.py` | `scripts/sv_no_rollup_gate.py` | OK | 0 | 0 | 0 | 8 |
| 07_ops_tools | `07_ops_tools/sv_common_block_gate.py` | `scripts/sv_common_block_gate.py` | OK | 5 | 0 | 0 | 4 |
| 07_ops_tools | `07_ops_tools/sv_code_label_gate.py` | `scripts/sv_code_label_gate.py` | OK | 1 | 0 | 0 | 38 |
| 07_ops_tools | `07_ops_tools/sv_enum_newvalue_gate.py` | `scripts/sv_enum_newvalue_gate.py` | OK | 4 | 0 | 1 | 11 |
| 07_ops_tools | `07_ops_tools/sv_identifier_gate.py` | `scripts/sv_identifier_gate.py` | OK | 4 | 0 | 0 | 9 |
| 07_ops_tools | `07_ops_tools/sv_unit_gate.py` | `scripts/sv_unit_gate.py` | OK | 4 | 0 | 0 | 104 |
| 07_ops_tools | `07_ops_tools/sv_rule7_scan.py` | `scripts/sv_rule7_scan.py` | OK | 0 | 0 | 0 | 7 |
| 07_ops_tools | `07_ops_tools/dbt_schema_lint.py` | `scripts/dbt_schema_lint.py` | OK | 0 | 0 | 0 | 1 |
| 07_ops_tools | `07_ops_tools/jinja_config_gate.py` | `scripts/jinja_config_gate.py` | OK | 0 | 0 | 0 | 15 |
| 07_ops_tools | `07_ops_tools/comment_drift_gate.py` | `scripts/comment_drift_gate.py` | OK | 5 | 0 | 0 | 24 |
| 07_ops_tools | `07_ops_tools/env_capture.py` | `scripts/env_capture.py` | OK | 0 | 0 | 0 | 0 |
| 07_ops_tools | `07_ops_tools/live_change_gate.py` | `scripts/live_change_gate.py` | OK | 6 | 0 | 0 | 5 |
| 07_ops_tools | `07_ops_tools/rbac_source_gate.py` | `scripts/rbac_source_gate.py` | OK | 13 | 0 | 0 | 2 |
| 07_ops_tools | `07_ops_tools/null_reason_registry_gate.py` | `scripts/null_reason_registry_gate.py` | OK | 0 | 0 | 0 | 0 |
| 07_ops_tools | `07_ops_tools/table_ddl_column_gate.py` | `scripts/table_ddl_column_gate.py` | OK | 11 | 0 | 0 | 33 |
| 07_ops_tools | `07_ops_tools/test_run_sql_block.py` | `scripts/test_run_sql_block.py` | OK | 3 | 0 | 0 | 2 |
| 07_ops_tools | `07_ops_tools/test_sv_no_rollup_gate.py` | `scripts/test_sv_no_rollup_gate.py` | OK | 0 | 0 | 0 | 2 |
| 07_ops_tools | `07_ops_tools/test_sv_common_block_gate.py` | `scripts/test_sv_common_block_gate.py` | OK | 0 | 0 | 0 | 3 |
| 07_ops_tools | `07_ops_tools/test_sv_enum_newvalue_gate.py` | `scripts/test_sv_enum_newvalue_gate.py` | OK | 0 | 0 | 0 | 3 |
| 07_ops_tools | `07_ops_tools/test_sv_identifier_gate.py` | `scripts/test_sv_identifier_gate.py` | OK | 3 | 0 | 0 | 2 |
| 07_ops_tools | `07_ops_tools/test_sv_unit_gate_agent.py` | `scripts/test_sv_unit_gate_agent.py` | OK | 1 | 3 | 0 | 6 |
| 07_ops_tools | `07_ops_tools/test_sv_rule7_scan.py` | `scripts/test_sv_rule7_scan.py` | OK | 0 | 0 | 0 | 8 |
| 07_ops_tools | `07_ops_tools/test_jinja_config_gate.py` | `scripts/test_jinja_config_gate.py` | OK | 0 | 0 | 0 | 10 |
| 07_ops_tools | `07_ops_tools/test_env_capture.py` | `scripts/test_env_capture.py` | OK | 0 | 0 | 0 | 0 |
| 07_ops_tools | `07_ops_tools/test_live_change_gate.py` | `scripts/test_live_change_gate.py` | OK | 0 | 0 | 0 | 7 |
| 07_ops_tools | `07_ops_tools/test_rbac_source_gate.py` | `scripts/test_rbac_source_gate.py` | OK | 9 | 0 | 1 | 2 |
| 07_ops_tools | `07_ops_tools/test_null_reason_registry_gate.py` | `scripts/test_null_reason_registry_gate.py` | OK | 0 | 0 | 0 | 0 |
| 07_ops_tools | `07_ops_tools/README_운영도구.md` | `scripts/README_운영도구.md` | OK | 2 | 0 | 0 | 4 |
| 08_handover_templates | `08_handover_templates/00_INDEX_산출물목록.md` | `85_실제 인수인계 문서/00_INDEX_산출물목록.md` | OK | 2 | 0 | 4 | 7 |
| 08_handover_templates | `08_handover_templates/00_작업계획서.md` | `85_실제 인수인계 문서/00_작업계획서.md` | OK | 12 | 0 | 2 | 2 |
| 08_handover_templates | `08_handover_templates/00_FOLDER_INDEX.md` | `85_실제 인수인계 문서/20_정식산출물/00_FOLDER_INDEX.md` | OK | 0 | 0 | 0 | 0 |
| 08_handover_templates | `08_handover_templates/00_README.md` | `85_실제 인수인계 문서/20_정식산출물/00_README.md` | OK | 3 | 0 | 18 | 1 |
| 08_handover_templates | `08_handover_templates/D01_요구사항_지표정의서.md` | `85_실제 인수인계 문서/20_정식산출물/D01_요구사항_지표정의서.md` | OK | 1 | 0 | 3 | 2 |
| 08_handover_templates | `08_handover_templates/D02_아키텍처정의서.md` | `85_실제 인수인계 문서/20_정식산출물/D02_아키텍처정의서.md` | OK | 25 | 0 | 4 | 0 |
| 08_handover_templates | `08_handover_templates/D03_환경구성서_RBAC매트릭스.md` | `85_실제 인수인계 문서/20_정식산출물/D03_환경구성서_RBAC매트릭스.md` | OK | 27 | 0 | 5 | 0 |
| 08_handover_templates | `08_handover_templates/D04_테이블컬럼정의서.md` | `85_실제 인수인계 문서/20_정식산출물/D04_테이블컬럼정의서.md` | OK | 0 | 0 | 3 | 0 |
| 08_handover_templates | `08_handover_templates/D05_ERD.md` | `85_실제 인수인계 문서/20_정식산출물/D05_ERD.md` | OK | 1 | 0 | 2 | 0 |
| 08_handover_templates | `08_handover_templates/D05_ERD_GOLD_자동생성.md` | `85_실제 인수인계 문서/20_정식산출물/D05_ERD_GOLD_자동생성.md` | OK | 1 | 0 | 2 | 0 |
| 08_handover_templates | `08_handover_templates/D06_원천타깃매핑_계보.md` | `85_실제 인수인계 문서/20_정식산출물/D06_원천타깃매핑_계보.md` | OK | 1 | 0 | 3 | 1 |
| 08_handover_templates | `08_handover_templates/D07_ETL_파이프라인설계서.md` | `85_실제 인수인계 문서/20_정식산출물/D07_ETL_파이프라인설계서.md` | OK | 11 | 0 | 4 | 0 |
| 08_handover_templates | `08_handover_templates/D08_시맨틱뷰정의서.md` | `85_실제 인수인계 문서/20_정식산출물/D08_시맨틱뷰정의서.md` | OK | 2 | 0 | 2 | 8 |
| 08_handover_templates | `08_handover_templates/D09_Agent명세서.md` | `85_실제 인수인계 문서/20_정식산출물/D09_Agent명세서.md` | OK | 4 | 0 | 2 | 8 |
| 08_handover_templates | `08_handover_templates/D10_운영매뉴얼.md` | `85_실제 인수인계 문서/20_정식산출물/D10_운영매뉴얼.md` | OK | 18 | 0 | 2 | 2 |
| 08_handover_templates | `08_handover_templates/D11_모니터링_비용관리정의서.md` | `85_실제 인수인계 문서/20_정식산출물/D11_모니터링_비용관리정의서.md` | OK | 7 | 0 | 2 | 0 |
| 08_handover_templates | `08_handover_templates/D12_현업활용가이드.md` | `85_실제 인수인계 문서/20_정식산출물/D12_현업활용가이드.md` | OK | 2 | 0 | 3 | 2 |
| 08_handover_templates | `08_handover_templates/D13_의사결정_이슈대장.md` | `85_실제 인수인계 문서/20_정식산출물/D13_의사결정_이슈대장.md` | OK | 0 | 0 | 0 | 3 |
| 08_handover_templates | `08_handover_templates/D14_인수인계서.md` | `85_실제 인수인계 문서/20_정식산출물/D14_인수인계서.md` | OK | 2 | 0 | 0 | 2 |
| 08_handover_templates | `08_handover_templates/N01_DMF_정의서.md` | `85_실제 인수인계 문서/20_정식산출물/N01_DMF_정의서.md` | OK | 4 | 0 | 1 | 1 |
| 08_handover_templates | `08_handover_templates/N02_PII_정책정의서.md` | `85_실제 인수인계 문서/20_정식산출물/N02_PII_정책정의서.md` | OK | 13 | 0 | 2 | 0 |
| 08_handover_templates | `08_handover_templates/N03_통합데이터사전.md` | `85_실제 인수인계 문서/20_정식산출물/N03_통합데이터사전.md` | OK | 0 | 0 | 1 | 0 |
| 08_handover_templates | `08_handover_templates/N04_배치SLA_스케줄정의서.md` | `85_실제 인수인계 문서/20_정식산출물/N04_배치SLA_스케줄정의서.md` | OK | 5 | 0 | 3 | 0 |
| 08_handover_templates | `08_handover_templates/N05_테스트결과서.md` | `85_실제 인수인계 문서/20_정식산출물/N05_테스트결과서.md` | OK | 1 | 0 | 6 | 3 |
| 08_handover_templates | `08_handover_templates/N06_비용산정_용량계획서.md` | `85_실제 인수인계 문서/20_정식산출물/N06_비용산정_용량계획서.md` | OK | 13 | 0 | 8 | 0 |
| 08_handover_templates | `08_handover_templates/N08_사업완료보고서.md` | `85_실제 인수인계 문서/20_정식산출물/N08_사업완료보고서.md` | OK | 1 | 1 | 2 | 1 |
| 08_handover_templates | `08_handover_templates/a2_matrix_build.py` | `scripts/a2_matrix_build.py` | OK | 15 | 0 | 0 | 0 |
| 08_handover_templates | `08_handover_templates/b_struct_build.py` | `scripts/b_struct_build.py` | OK | 1 | 0 | 0 | 0 |
| 08_handover_templates | `08_handover_templates/n03_catalog_build.py` | `scripts/n03_catalog_build.py` | OK | 0 | 0 | 0 | 0 |
| 08_handover_templates | `08_handover_templates/n05_report_build.py` | `scripts/n05_report_build.py` | OK | 0 | 0 | 0 | 0 |
| 08_handover_templates | `08_handover_templates/test_a2_matrix_build.py` | `scripts/test_a2_matrix_build.py` | OK | 28 | 0 | 0 | 0 |
| 08_handover_templates | `08_handover_templates/test_b_struct_build.py` | `scripts/test_b_struct_build.py` | OK | 0 | 0 | 0 | 0 |
| 08_handover_templates | `08_handover_templates/test_n03_catalog_build.py` | `scripts/test_n03_catalog_build.py` | OK | 0 | 0 | 0 | 0 |
| 08_handover_templates | `08_handover_templates/test_n05_report_build.py` | `scripts/test_n05_report_build.py` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/mstr-migration/SKILL.md` | `.snowflake/cortex/skills/mstr-migration/SKILL.md` | OK | 8 | 0 | 0 | 8 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/00_FOLDER_INDEX.md` | `70_reference/73_skill_mstr_dw_to_ods/00_FOLDER_INDEX.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/00_README.md` | `70_reference/73_skill_mstr_dw_to_ods/00_README.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/SNOWFLAKE.md` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/SNOWFLAKE.md` | OK | 2 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/05_COCO_TASK_TEMPLATE.md` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/05_COCO_TASK_TEMPLATE.md` | OK | 1 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/06_REFERENCE_MANIFEST.yaml` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/06_REFERENCE_MANIFEST.yaml` | OK | 1 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/common/00_COCO_READ_FIRST_ODS_ONLY.md` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/common/00_COCO_READ_FIRST_ODS_ONLY.md` | OK | 2 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/common/01_ODS_PHYSICAL_MODEL.yaml` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/common/01_ODS_PHYSICAL_MODEL.yaml` | OK | 16 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/common/04_VALIDATION_GATES.yaml` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/common/04_VALIDATION_GATES.yaml` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/common/07_SNAPSHOT_AND_DIFFERENCE_POLICY.md` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/common/07_SNAPSHOT_AND_DIFFERENCE_POLICY.md` | OK | 2 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/examples/diagnose_decrease_gap_and_snapshot_limits_202601.sql` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/examples/diagnose_decrease_gap_and_snapshot_limits_202601.sql` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/examples/diagnose_remaining_dw_ods_difference_202601.sql` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/examples/diagnose_remaining_dw_ods_difference_202601.sql` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/examples/mstr_dept_member_development_to_crm_final_202606.sql` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/examples/mstr_dept_member_development_to_crm_final_202606.sql` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/examples/ods_fee_forecast_decrease_new_old_202601.sql` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/examples/ods_fee_forecast_decrease_new_old_202601.sql` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/legacy_dw/snowflake_coco_conversion_examples_semantic_reference.md` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/legacy_dw/snowflake_coco_conversion_examples_semantic_reference.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/legacy_dw/snowflake_coco_mstr_dw_reference.md` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/legacy_dw/snowflake_coco_mstr_dw_reference.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/legacy_dw/snowflake_coco_mstr_virtual_structure_reference.md` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/legacy_dw/snowflake_coco_mstr_virtual_structure_reference.md` | OK | 1 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/reports/02_REPORT_CONDITION_MATRIX.md` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/reports/02_REPORT_CONDITION_MATRIX.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/reports/member_activity/03_ACTIVITY_MEMBER_SOURCE_OF_TRUTH.md` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/reports/member_activity/03_ACTIVITY_MEMBER_SOURCE_OF_TRUTH.md` | OK | 1 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/reports/member_activity/member_activity_2_1_detail_reference.md` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/reports/member_activity/member_activity_2_1_detail_reference.md` | OK | 1 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/skills/snowflake-mstr-dw-to-ods/SKILL.md` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/skills/snowflake-mstr-dw-to-ods/SKILL.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/skills/snowflake-mstr-dw-to-ods/agents/openai.yaml` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/skills/snowflake-mstr-dw-to-ods/agents/openai.yaml` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/skills/snowflake-mstr-dw-to-ods/references/conversion-rules.md` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/skills/snowflake-mstr-dw-to-ods/references/conversion-rules.md` | OK | 1 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/skills/snowflake-mstr-dw-to-ods/references/planner-request-template.md` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/skills/snowflake-mstr-dw-to-ods/references/planner-request-template.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/skills/snowflake-mstr-dw-to-ods/references/validation-checklist.md` | `70_reference/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/skills/snowflake-mstr-dw-to-ods/references/validation-checklist.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/.cortex/skills/mstr-ods-crm-schema/SKILL.md` | `70_reference/74_skill_mstr_ods_crm/.cortex/skills/mstr-ods-crm-schema/SKILL.md` | OK | 1 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/00_FOLDER_INDEX.md` | `70_reference/74_skill_mstr_ods_crm/00_FOLDER_INDEX.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/DIRECTORY_TREE.md` | `70_reference/74_skill_mstr_ods_crm/DIRECTORY_TREE.md` | OK | 1 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/README.md` | `70_reference/74_skill_mstr_ods_crm/README.md` | OK | 1 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/05_COCO_TASK_TEMPLATE.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/05_COCO_TASK_TEMPLATE.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/06_REFERENCE_MANIFEST.yaml` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/06_REFERENCE_MANIFEST.yaml` | OK | 1 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/07_PLANNER_GUIDE.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/07_PLANNER_GUIDE.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/08_PROMPT_INDEX.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/08_PROMPT_INDEX.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/SNOWFLAKE.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/SNOWFLAKE.md` | OK | 1 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/00_COCO_READ_FIRST_ODS_ONLY.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/00_COCO_READ_FIRST_ODS_ONLY.md` | OK | 1 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/01_APPROVED_TABLES.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/01_APPROVED_TABLES.md` | OK | 1 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/02_SOURCE_PHYSICAL_CATALOG.json` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/02_SOURCE_PHYSICAL_CATALOG.json` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/03_JOIN_CONTRACTS.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/03_JOIN_CONTRACTS.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/04_BUSINESS_RULES.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/04_BUSINESS_RULES.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/05_SEND_KEY_CONTRACT.yaml` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/05_SEND_KEY_CONTRACT.yaml` | OK | 1 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/06_RELEVANT_CODE_MAP.json` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/06_RELEVANT_CODE_MAP.json` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/07_VALIDATION_GATES.yaml` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/07_VALIDATION_GATES.yaml` | OK | 1 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/08_SNAPSHOT_AND_DIFFERENCE_POLICY.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/08_SNAPSHOT_AND_DIFFERENCE_POLICY.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/09_PRIVACY_POLICY.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/09_PRIVACY_POLICY.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/10_EVIDENCE_REGISTER.yaml` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/10_EVIDENCE_REGISTER.yaml` | OK | 1 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/examples/01_PLANNER_QUICK_START.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/examples/01_PLANNER_QUICK_START.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/examples/02_NATURAL_LANGUAGE_PROMPT_GUIDE.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/examples/02_NATURAL_LANGUAGE_PROMPT_GUIDE.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/examples/03_BUILD_NEW_STREAMLIT_EXAMPLES.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/examples/03_BUILD_NEW_STREAMLIT_EXAMPLES.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/examples/04_CHANGE_EXISTING_STREAMLIT_EXAMPLES.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/examples/04_CHANGE_EXISTING_STREAMLIT_EXAMPLES.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/examples/05_VALIDATE_AND_DIAGNOSE_EXAMPLES.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/examples/05_VALIDATE_AND_DIAGNOSE_EXAMPLES.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/examples/06_COCO_RESPONSE_READING_GUIDE.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/examples/06_COCO_RESPONSE_READING_GUIDE.md` | OK | 1 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/legacy_dw/README.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/legacy_dw/README.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/reports/CRM_SEND_PERFORMANCE/01_REPORT_CONTRACT.yaml` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/reports/CRM_SEND_PERFORMANCE/01_REPORT_CONTRACT.yaml` | OK | 1 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/reports/CRM_SEND_PERFORMANCE/02_METRIC_DEFINITIONS.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/reports/CRM_SEND_PERFORMANCE/02_METRIC_DEFINITIONS.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/reports/CRM_SEND_PERFORMANCE/03_UI_REQUIREMENTS.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/reports/CRM_SEND_PERFORMANCE/03_UI_REQUIREMENTS.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/reports/CRM_SEND_PERFORMANCE/04_VALIDATION_CASES.yaml` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/reports/CRM_SEND_PERFORMANCE/04_VALIDATION_CASES.yaml` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/reports/CRM_SEND_PERFORMANCE/05_PLANNER_PROMPT.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/reports/CRM_SEND_PERFORMANCE/05_PLANNER_PROMPT.md` | OK | 0 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/scripts/01_PROFILE_SEND_KEY_CONTRACT.sql` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/scripts/01_PROFILE_SEND_KEY_CONTRACT.sql` | OK | 23 | 0 | 0 | 0 |
| 09_skill_mstr | `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/skills/mstr-ods-crm-schema/SKILL.md` | `70_reference/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/skills/mstr-ods-crm-schema/SKILL.md` | OK | 2 | 0 | 0 | 0 |
| 10_streamlit | `10_streamlit/27_streamlit_auth/00_FOLDER_INDEX.md` | `20_build/27_streamlit_auth/00_FOLDER_INDEX.md` | OK | 0 | 0 | 0 | 0 |
| 10_streamlit | `10_streamlit/27_streamlit_auth/00_README.md` | `20_build/27_streamlit_auth/00_README.md` | OK | 0 | 0 | 0 | 0 |
| 10_streamlit | `10_streamlit/27_streamlit_auth/analyst-selfservice-streamlit.md` | `20_build/27_streamlit_auth/analyst-selfservice-streamlit.md` | OK | 125 | 0 | 0 | 0 |
