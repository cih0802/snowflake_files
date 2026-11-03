> #### 🟢 [2026-09-11 O156] GOLD 팩트 개명 원복(`FACT_MEMBER_EVENT`) + 스냅샷 탈배선 + 게이트 반전 + DEC-53 확정
>
> - **작업 배경**:
>   - 현업이 운영계에서 `FACT_MEMBER_EVENT`를 「중단고객 분석 보고서」에 이미 사용 중이므로 개명을 철회하고 `FACT_MEMBER_EVENT`로 원복 요청.
>   - 스냅샷 11종의 dbt 다운스트림 소비처 및 실효성 실측 결과, 과거 이력 소급 불가로 Two-tier 컬럼이 현재명과 100% 동일하여 소비처 0 정합화(선이력·후배선) 필요.
> - **주요 조치 내역**:
>   1. **FACT_MEMBER_EVENT 개명 원복**:
>      - dbt 모델 파일명 변경: `FACT_MEMBER_LIFECYCLE.sql` ➔ `FACT_MEMBER_EVENT.sql` (2축 확인 삭제/생성).
>      - 수기 정본 89건 전수 치환 완료 (`06_DDL.sql` 29건, `_wide_schema.yml` 21건, SV 3종, 공유문서 4종 등).
>      - `WIDE_MEMBER_EVENT` 뷰와의 명칭 정합 복원. 나머지 GOLD 개명 7종은 현업 미조회 상태로 유지.
>   2. **스냅샷 탈배선 정합화 (소비처 0)**:
>      - `DIM_MEMBER_ACQUISITION.sql`에서 snapshot ref 2건 및 CTE, `ACQ_CAMPAIGN_NAME_AT_ACQ`/`ACQ_DEPARTMENT_AT_ACQ` 제거.
>      - `06_DDL.sql` 및 `_gold_ready_schema.yml`에서 해당 컬럼 동기 제거 (`table_ddl_column_gate` 80/80 PASS).
>   3. **개명 감시 게이트 반전**:
>      - `scripts/rename_stale_gate.py` 감시 방향 반전 (`FACT_MEMBER_LIFECYCLE`을 옛 이름으로 감시).
>      - `test_rename_stale_gate.py` 8축 음성 테스트 통과, 기준선 재발행(축1 441건, 95건 감소).
>   4. **문서 및 설계 의사결정 (DEC-53)**:
>      - `06_snapshot/01_스냅샷_아키텍처_및_네이밍룰.md` 보강 (§1-1 향후왜곡방지 정정, §2-3 Stream 6대 기각사유, §2-4 YAGNI 기각 및 check_cols 감사, §3-4 소비처 0 실측, §5-2 Two-tier 배선대기 강등).
>      - `20_issue/30_설계_의사결정.md`에 `DEC-53` 신규 등재 및 허브 재발행.
>   5. **결함 등재 및 운영계 SQL 작성**:
>      - 원장 `O151` 행 라이브 Task 0건 실측 결함 정정 (`R2-8-4-d`).
>      - `12_임시작업폴더_배선수정/03_운영계_적용SQL.sql`에 운영계 적용 쿼리 전량 작성 (실행 0건).
> - **검증 결과**:
>   - 게이트 9종 전건 PASS (`line_len`, `table_ddl_column`, `rename_stale`, `clause_order`, `index_row`, `doc_heading`, `doc_coord`, `doc_census`, `decision_closure`).
>   - 음성 테스트 32종 전건 PASS (`test_*.py`).
> - **정본 좌표**: `12_임시작업폴더_배선수정/01_작업계획.md` · `20_issue/30_설계_의사결정.md`(DEC-53) · `06_snapshot/01_스냅샷_아키텍처_및_네이밍룰.md`.
