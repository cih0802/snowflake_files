> #### 🟢 [2026-09-07 O141] P1 작업 4종 완결 (착수표 ㊵·⑫ 종결 + ⑭·BLOCKING-5 점검) + DDL-모델 정합성(79/79 PASS)
>
> - **착수 배경**: 이전 세션(O140) 인수인계(§0-NNNN) 및 `30_output_share/16_파이프라인 배선 수정.md`에 제시된 현업 확정 결과를 바탕으로 P1 4대 작업(착수표 ㊵, ⑫, ⑭, BLOCKING-5) 검토 및 집행.
> - **주요 작업 내용 및 결과**:
>   1. **착수표 ㊵ 완결 (`CRM_MEMBER.JOIN_DT` ➔ `FRST_REGIST_DT` 원천명 복원)**:
>      - `16_파이프라인 배선 수정.md` §1-6 및 문서20 §N-10 현업 회신 확정(최초등록일과 가입일 업무상 동일, 지표 28번 정합) 반영.
>      - Snowflake Live DB `ALTER TABLE GN_DW.SILVER.CRM_MEMBER RENAME COLUMN JOIN_DT TO FRST_REGIST_DT;` 실행 및 COMMENT 최신화.
>      - `04_silver_design/08_SILVER_테이블DDL_20260714.sql`, `models/silver/crm/CRM_MEMBER.sql`, `models/gold/dim/DIM_MEMBER.sql` 전수 수정.
>      - `20_issue/32_컬럼개명표.md` 13번째 개명 완료 반영 (SILVER 13건 100% 완료).
>   2. **착수표 ⑫ 완결 (활동 스냅샷 as-of 배선 및 CONF-3 종결)**:
>      - `16_파이프라인 배선 수정.md` §1-5 및 문서20 §N-11 회신 확정에 따라 `CONF-3` 「재후원 우세 (후원사업 유효 기준)」 채택.
>      - `CRM_MEMBER_SPONSOR_SPAN` 기반 `FACT_MEMBER_MONTHLY`, `FACT_MEMBER_SPONSOR_BIZ` as-of 산식 정합성 검증 완료.
>      - `DEC-47` 설계 의사결정 종결 및 착수표 ⑫ 취소선 완료 처리.
>   3. **착수표 ⑭ 검토 (`FME.SPONSORSHIP_SK(STOP)` 1.56배 팬아웃 방지)**:
>      - `16_파이프라인 배선 수정.md` §1-3(유입축 `DIM_MEMBER_ACQUISITION` vs 중단축 `DIM_SPONSORSHIP` 분리 모델링) 대조.
>      - 사건 grain 팬아웃 방지를 위한 STOP 이벤트 센티넬 0 유지 조건 확인 및 모델 무결성 유지.
>   4. **BLOCKING-5 및 DDL-dbt 전수 정합성 검증**:
>      - `08_SILVER_테이블DDL_20260714.sql` 내 `BIGQUERY_EVENT`(44열), `BIGQUERY_IDENTITY`(12열) 정본 DDL을 Live DB 및 dbt 모델과 100% 일치하도록 동기화.
>      - `table_ddl_column_gate.py` 실행 결과 GOLD 37 + SILVER 42 = **총 79개 테이블 100% 집합 일치(blocking 0건)** 달성.
>      - `30_output_share/erd/` 38종 재발행 및 `test_generators.py`(21/21 PASS), `test_pipeline_erd.py`(24/24 PASS), 단위/음성 테스트 29종 전건 PASS.
