<!-- LLM-METADATA
doc_id: REUSE_KIT_PLACEHOLDERS
doc_role: 키트 자리표시자 치환 기록 — 무엇을 무엇으로 바꿨나 · 새 프로젝트 적용법
created: 2026-11-02
END-METADATA -->

# 자리표시자 (_reuse_kit)

| 자리표시자 | 원래 값 | 치환 건수 |
|---|---|---|
| `{{DB}}` | `GN_DW` (역할·창고 접두 포함 · 예 `GN_DW_ADMIN` → `{{DB}}_ADMIN`) | 547 |
| `{{ACCOUNT}}` | 계정 로케이터 `tq68205` · `zl50263` · `xh20001` · `sr61467` · `iw20760` · `ny60473` · `zs83821` · `ju93656` · `ad50130` (대소문자 무관) | 100 |

- 유지(사용자 결정 2026-11-02) = 세션 라벨 `O##` · 주석 · `굿네이버스` 문구.
- `00_INVENTORY.md` 의 해시·잔존 열은 **치환 전 복사 시점** 값이다.

## 새 프로젝트 적용

```
python3 _reuse_kit/apply_names.py --check                                   # 남은 자리표시자
python3 _reuse_kit/apply_names.py --set DB=NEW_DW --set ACCOUNT=ab12345     # dry-run
python3 _reuse_kit/apply_names.py --set DB=NEW_DW --set ACCOUNT=ab12345 --apply
```

## 목록 밖 로케이터 후보(형식 `XX99999` · 확인 필요)

- 없음

## 파일별

| 파일 | DB | ACCOUNT |
|---|---|---|
| `01_agent_rules/01_문서분할_규약.md` | 1 | 0 |
| `01_agent_rules/02_파일쓰기_안전규약.md` | 1 | 0 |
| `01_agent_rules/04_단계종료_게이트.md` | 1 | 0 |
| `01_agent_rules/01_문서분할_규약_조각/00_선택표.md` | 1 | 0 |
| `01_agent_rules/01_문서분할_규약_조각/01_문서분할_규약-001.md` | 1 | 0 |
| `02_skill_init/03_init_ihcho_스킬_개발이력.md` | 1 | 0 |
| `02_skill_init/03_init_ihcho_스킬_본문.md` | 1 | 0 |
| `02_skill_init/03_init_ihcho_스킬_정본.md` | 1 | 0 |
| `02_skill_init/03_init_ihcho_스킬_참조_세션종료.md` | 1 | 0 |
| `03_session_tools/gate_census.py` | 3 | 0 |
| `03_session_tools/handoff_ddl_gate.py` | 7 | 0 |
| `03_session_tools/handoff_write.py` | 2 | 0 |
| `03_session_tools/session_brief.py` | 1 | 0 |
| `03_session_tools/split_doc.py` | 2 | 0 |
| `03_session_tools/split_issue_index.py` | 2 | 0 |
| `03_session_tools/split_narrative.py` | 1 | 0 |
| `04_methodology/01_데이터설계 업무단계 방법론_킴볼 일반론.md` | 1 | 0 |
| `04_methodology/02_모던 엔터프라이즈 데이터 아키텍처 설계 가이드.md` | 1 | 0 |
| `04_methodology/04_YAGNI_원천중심_과잉모델링_방지_원칙.md` | 2 | 0 |
| `04_methodology/MFA 로 인한 로그인 방법 가이드.md` | 0 | 3 |
| `05_build_skeleton/53_followup_project/00_README_N07.md` | 3 | 0 |
| `05_build_skeleton/53_followup_project/01_RBAC_골격.sql` | 2 | 0 |
| `05_build_skeleton/53_followup_project/02_dbt_골격.md` | 4 | 0 |
| `05_build_skeleton/53_followup_project/03_SV_Agent_작성규칙.md` | 2 | 0 |
| `05_build_skeleton/53_followup_project/04_모니터링_SQL.sql` | 1 | 0 |
| `05_build_skeleton/53_followup_project/05_인수인계문서_규약.md` | 1 | 0 |
| `05_build_skeleton/53_followup_project/readme.md` | 1 | 0 |
| `06_dbt_macros/no_structural_alter.sql` | 5 | 0 |
| `06_dbt_macros/silver_purge.sql` | 1 | 0 |
| `06_dbt_macros/view_commented.sql` | 1 | 0 |
| `07_ops_tools/README_운영도구.md` | 2 | 0 |
| `07_ops_tools/audit_ddl_rule7.py` | 1 | 0 |
| `07_ops_tools/comment_drift_gate.py` | 5 | 0 |
| `07_ops_tools/deploy_sv.py` | 2 | 0 |
| `07_ops_tools/live_change_gate.py` | 6 | 0 |
| `07_ops_tools/rbac_source_gate.py` | 13 | 0 |
| `07_ops_tools/run_sql_file.py` | 10 | 0 |
| `07_ops_tools/sfconn.py` | 6 | 0 |
| `07_ops_tools/sv_code_label_gate.py` | 1 | 1 |
| `07_ops_tools/sv_common_block_gate.py` | 5 | 0 |
| `07_ops_tools/sv_enum_newvalue_gate.py` | 4 | 2 |
| `07_ops_tools/sv_identifier_gate.py` | 4 | 0 |
| `07_ops_tools/sv_unit_gate.py` | 4 | 0 |
| `07_ops_tools/table_ddl_column_gate.py` | 11 | 0 |
| `07_ops_tools/test_live_change_gate.py` | 0 | 1 |
| `07_ops_tools/test_rbac_source_gate.py` | 9 | 1 |
| `07_ops_tools/test_run_sql_block.py` | 3 | 0 |
| `07_ops_tools/test_sv_identifier_gate.py` | 3 | 0 |
| `07_ops_tools/test_sv_unit_gate_agent.py` | 1 | 0 |
| `08_handover_templates/00_INDEX_산출물목록.md` | 2 | 4 |
| `08_handover_templates/00_README.md` | 3 | 18 |
| `08_handover_templates/00_SAMPLE_NOTICE.md` | 1 | 1 |
| `08_handover_templates/00_작업계획서.md` | 12 | 2 |
| `08_handover_templates/D01_요구사항_지표정의서.md` | 1 | 3 |
| `08_handover_templates/D02_아키텍처정의서.md` | 25 | 4 |
| `08_handover_templates/D03_환경구성서_RBAC매트릭스.md` | 27 | 5 |
| `08_handover_templates/D04_테이블컬럼정의서.md` | 0 | 3 |
| `08_handover_templates/D05_ERD.md` | 1 | 2 |
| `08_handover_templates/D05_ERD_GOLD_자동생성.md` | 1 | 2 |
| `08_handover_templates/D06_원천타깃매핑_계보.md` | 1 | 3 |
| `08_handover_templates/D07_ETL_파이프라인설계서.md` | 11 | 4 |
| `08_handover_templates/D08_시맨틱뷰정의서.md` | 2 | 2 |
| `08_handover_templates/D09_Agent명세서.md` | 4 | 2 |
| `08_handover_templates/D10_운영매뉴얼.md` | 18 | 2 |
| `08_handover_templates/D11_모니터링_비용관리정의서.md` | 7 | 2 |
| `08_handover_templates/D12_현업활용가이드.md` | 2 | 3 |
| `08_handover_templates/D14_인수인계서.md` | 2 | 0 |
| `08_handover_templates/N01_DMF_정의서.md` | 4 | 1 |
| `08_handover_templates/N02_PII_정책정의서.md` | 13 | 2 |
| `08_handover_templates/N03_통합데이터사전.md` | 0 | 1 |
| `08_handover_templates/N04_배치SLA_스케줄정의서.md` | 5 | 3 |
| `08_handover_templates/N05_테스트결과서.md` | 1 | 8 |
| `08_handover_templates/N06_비용산정_용량계획서.md` | 13 | 8 |
| `08_handover_templates/N08_사업완료보고서.md` | 1 | 2 |
| `08_handover_templates/a2_matrix_build.py` | 15 | 1 |
| `08_handover_templates/b_struct_build.py` | 1 | 1 |
| `08_handover_templates/n03_catalog_build.py` | 0 | 1 |
| `08_handover_templates/n05_report_build.py` | 0 | 1 |
| `08_handover_templates/test_a2_matrix_build.py` | 28 | 0 |
| `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/SNOWFLAKE.md` | 2 | 0 |
| `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/05_COCO_TASK_TEMPLATE.md` | 1 | 0 |
| `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/06_REFERENCE_MANIFEST.yaml` | 1 | 0 |
| `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/common/00_COCO_READ_FIRST_ODS_ONLY.md` | 2 | 0 |
| `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/common/01_ODS_PHYSICAL_MODEL.yaml` | 16 | 0 |
| `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/common/07_SNAPSHOT_AND_DIFFERENCE_POLICY.md` | 2 | 0 |
| `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/legacy_dw/snowflake_coco_mstr_virtual_structure_reference.md` | 1 | 0 |
| `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/reports/member_activity/03_ACTIVITY_MEMBER_SOURCE_OF_TRUTH.md` | 1 | 0 |
| `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/references/reports/member_activity/member_activity_2_1_detail_reference.md` | 1 | 0 |
| `09_skill_mstr/73_skill_mstr_dw_to_ods/snowflake-coco-workspace-v3/skills/snowflake-mstr-dw-to-ods/references/conversion-rules.md` | 1 | 0 |
| `09_skill_mstr/74_skill_mstr_ods_crm/DIRECTORY_TREE.md` | 1 | 0 |
| `09_skill_mstr/74_skill_mstr_ods_crm/README.md` | 1 | 0 |
| `09_skill_mstr/74_skill_mstr_ods_crm/.cortex/skills/mstr-ods-crm-schema/SKILL.md` | 1 | 0 |
| `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/06_REFERENCE_MANIFEST.yaml` | 1 | 0 |
| `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/SNOWFLAKE.md` | 1 | 0 |
| `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/00_COCO_READ_FIRST_ODS_ONLY.md` | 1 | 0 |
| `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/01_APPROVED_TABLES.md` | 1 | 0 |
| `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/05_SEND_KEY_CONTRACT.yaml` | 1 | 0 |
| `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/07_VALIDATION_GATES.yaml` | 1 | 0 |
| `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/common/10_EVIDENCE_REGISTER.yaml` | 1 | 0 |
| `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/examples/06_COCO_RESPONSE_READING_GUIDE.md` | 1 | 0 |
| `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/references/reports/CRM_SEND_PERFORMANCE/01_REPORT_CONTRACT.yaml` | 1 | 0 |
| `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/scripts/01_PROFILE_SEND_KEY_CONTRACT.sql` | 23 | 0 |
| `09_skill_mstr/74_skill_mstr_ods_crm/snowflake-mstr-ods-crm/snowflake-coco-workspace-ods-v1/skills/mstr-ods-crm-schema/SKILL.md` | 2 | 0 |
| `09_skill_mstr/mstr-migration/SKILL.md` | 8 | 0 |
| `10_streamlit/27_streamlit_auth/analyst-selfservice-streamlit.md` | 125 | 1 |
| `11_project_template/99_NEXT_SESSION.md` | 1 | 0 |
| `11_project_template/20_issue/00_INDEX_이슈원장.md` | 1 | 0 |
| `11_project_template/20_issue/01_세션이력.md` | 1 | 0 |
| `11_project_template/20_issue/50_dbt_파이프라인_미결조치.md` | 1 | 0 |
| `11_project_template/20_issue/90_해소완료_로그.md` | 1 | 0 |
| `11_project_template/20_issue/91_사고사례집.md` | 1 | 0 |
