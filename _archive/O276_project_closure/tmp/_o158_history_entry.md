
> #### 🟢 [2026-09-14 O158] 라이브 고아 테이블 정리 + 임시폴더 은퇴(R1-7-7) + 개명 잔여 1순위 정제(20건) + 산출물 제너레이터 동기화
>
> - **배경 및 목적**:
>   - O157에서 사용자 라이브 배포 및 실측(463.3만행 정상적재, Two-tier 제거, 코멘트 드리프트 0건)이 완료됨에 따라 잔여 정리 및 백로그 정비 진행.
>   - 라이브 고아 테이블 정리, 임시작업폴더 은퇴, 현업 1순위 활용가이드 개명 잔여 정제, 산출물 제너레이터 동기화 완결.
> - **작업 내역**:
>   1. 🟢 **라이브 고아 테이블 정리**:
>      - `DROP TABLE IF EXISTS GN_DW.GOLD.FACT_MEMBER_LIFECYCLE;` 실행 완료 (`FACT_MEMBER_EVENT` 4,633,105행 단일 테이블 유지).
>   2. 🟢 **임시 폴더 은퇴 및 안전 정리 (R1-7-7)**:
>      - `12_임시작업폴더_배선수정/` 내 3개 파일(`01_작업계획.md`, `02_다음프롬프트.md`, `03_운영계_적용SQL.sql`)을 `20_issue/90_해소완료_로그.md`로 은퇴 이관(`split_doc --rollover`).
>      - R1-7-7 안전 규약 준수: `os.listdir` 사전 실사 후 개별 파일 3종 삭제 및 디렉터리 정리(`cortex ws ls` 0 items 확인).
>   3. 🟢 **개명 잔여 1순위 정비 (`30_output_share/01_DW_현업활용가이드.md`)**:
>      - 현업 직접 조회 문서인 `01_DW_현업활용가이드.md` 내 개명 잔여 표기 20건 전량 정제 완료 (잔여 0건).
>      - `rename_stale_gate.py --baseline` 재발행 (축1 441건 ➔ 421건, -20건 감축 달성).
>   4. 🟢 **자동 생성 산출물 동기화 및 ERD 정비**:
>      - `dump_schema.py` 및 `census_columns.py`로 최신 스키마 및 census 갱신 후, `gen_column_mapping.py`, `gen_metric_gold_mapping.py`, `gen_gold_erd.py`, `gen_pipeline_erd.py`, `gen_concept_diagram.py`, `gen_arch_map.py`, `gen_section_assembly.py` 등 산출물 제너레이터 전수 재실행 완료.
>      - `30_output_share/erd/` 내 구 테이블명 잔여 HTML 7종 정리 및 `test_pipeline_erd.py` 24개 단정 ALL PASS 검증.
>      - `test_generators.py` 골든 갱신 및 21개 단정 ALL PASS 검증. 축2 자동 생성 산출물 잔여 878건 ➔ 461건 (-417건 감축).
>   5. 🟢 **품질 게이트 및 테스트 전수 검증**:
>      - 핵심 게이트 9종 전건 `rc=0` 통과 (`doc_census`, `doc_type_gate`, `clause_order_gate`, `index_row_gate`, `doc_heading_gate`, `doc_coord_gate`, `decision_closure_gate`, `rename_stale_gate`, `test_generators`).
>      - 음성 회귀 테스트 32종 전건 `rc=0` 통과 (`failed=0`, `total=32`).
> - **독해 및 측정 기록**:
>   - `read` 미반환 = 0건, 재호출 = 0건 (`R1-3-7-a` 준수).
> - **정본 좌표**: `20_issue/90_해소완료_로그.md` · `30_output_share/01_DW_현업활용가이드.md` · `30_output_share/` · `scripts/golden/outputs.json` · `scripts/golden/rename_stale_baseline.json`.
