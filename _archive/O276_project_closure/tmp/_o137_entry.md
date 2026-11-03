> #### 🟢 [2026-09-02 O137] 착수표 ㊶(영구 NULL 잔여 COMMENT) 완결 + ⑫·⑭ 실측 검증 + 비판적 자기검토 및 산출물 전수 갱신

- **배경 및 개요**:
  - 이전 세션(O136)에서 30개 추천질문 Cortex Analyst 실측(28/28 PASS), 착수표 ⑤(SERVING 표면 검증), ⑰(09 마케팅 앵커 정합), ㉟(ERD 추론 PK 명문화)이 완결된 상태에서 세션을 시작함.
  - 이전 세션 허브 재발행 대기 상태를 점검하여 정상 복구한 후, 잔여 착수표 ㊶(영구 NULL 잔여 컬럼 관리), ⑫(활동회원 스냅샷 as-of 배선 사전 검토), ⑭(FME STOP 다중사업 귀속 규칙 검토)를 순차적으로 수행함.

- **작업 내역 및 실측 결과**:
  1. 🟢 **착수표 ㊶ 영구 NULL 잔여 컬럼 5건 COMMENT 및 Live DB 동기화 완결**:
     - `03_top-down_gold/06_DDL.sql`의 영구 NULL 잔여 컬럼 5종(`FACT_MEMBER_MONTHLY` 밴드 4종 및 `NEW_EXISTING_FLAG`, `FACT_SERVICE_EVENT` 3종, `FACT_MEMBER_EVENT` 1종)에 대해 DEC-49 표준 사유(`[사유:...]`)를 DDL 및 Live DB 컬럼 COMMENT 에 100% 전파 반영 완료.
     - `comment_drift_gate.py` 실행 결과: GOLD 742건 / SILVER 832건 / 뷰 574건 드리프트 0건 확인.
     - `30_설계_의사결정_조각/30_설계_의사결정-002.md` §7-C 및 `99_NEXT_SESSION_조각/99_NEXT_SESSION-023.md` 착수표 ㊶ 완료 갱신.
  2. 🟢 **착수표 ⑫ 활동회원 스냅샷 as-of 배선 사전 검토 및 Live 실측**:
     - 정본 `DEC-47`에 따라 ㉠ 미중단 약정금액 ÷ 10,000 = 활동(건) 확정, ㉢ 센티넬(시작일 93, 중단일 2) NULL 및 COMMENT 사유 명시 확정 확인.
     - ㉡ `CONF-3`(중단 vs 재후원 우세 판정, 문서20 §N-11) 현업 회신 대기 중이므로 회신 전 dbt 실배선 금지 정지점 유지 확정.
     - Live 실측: `BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR`(2,228,064행), `BRONZE_CRM.TM_MM_FDRM_MBER_SPNSR_BSNS`(2,170,572행), `SILVER.CRM_MEMBER_SPONSOR_SPAN`(2,170,572행) 실재 및 데이터 일치 확인.
  3. 🟢 **착수표 ⑭ `FME.SPONSORSHIP_SK(STOP)` 다중사업 귀속 규칙 검토 및 Live 실측**:
     - 중단 사건의 (회원, 중단일) 키 970,486건 대비 matched pairs 1,517,797건으로 1.56배 팬아웃 발생 확인.
     - 현업의 귀속 규칙 결정 전까지 임의 추론 배선을 금지하고 `SPONSORSHIP_SK=0` 센티넬 유지 및 사유 COMMENT 명시 정지점 유지 확정.
     - Live 실측: `GOLD.FACT_MEMBER_EVENT` DEV 3,594,843건(배선 완료), STOP 1,038,262건(전부 0 유지) 실측 일치 확인.
  4. 🟢 **산출물 및 제너레이터 전수 최신화**:
     - `census_columns.py`, `dump_schema.py` 실행 후 `11_미해결이슈_요약.md`, `92_실측필요_후속작업.md`, `09_보고서필드_조립가능성.{md,csv}` 전수 재생성 및 동기화 완료.

- **비판적 자기검토 (Self-Review)**:
  - **SQL 실측**: BRONZE, SILVER, GOLD 대상 집계 쿼리 실행 결과와 정본 문서 기재 수치가 100% 일치함을 실측 검증함.
  - **DDL 수정 및 Live 동기화**: DEC-49 표준 서식 준수 및 Live ALTER 적용 후 `comment_drift_gate.py` 및 `table_ddl_column_gate.py` 전수 PASS 확인.
  - **결정 판정**: 업무 확인이 필요한 ⑫(`CONF-3`), ⑭(1.56배 팬아웃 귀속)에 대해 임의 창작 배선을 배제하고 정지점을 엄격히 준수함.
  - **규칙 준수**: R0(셸 안전), R1-3(전량 독해), R1-5(한 줄 2000자 가드), R1-6(분할 및 --expect 재발행), R1-7(쓰기 안전), R2-7(NULL 규약), R2-8-4(라이브 실재 대조), R3(게이트 및 자문 8축), R4-1(dbt 사용자 위임) 전건 100% 준수.

- **품질 및 게이트 검증**:
  - `comment_drift_gate.py`: 드리프트 0건 통과
  - `table_ddl_column_gate.py`: 79/79 모델 집합 일치 통과
  - 6대 게이트(`doc_census`, `doc_type_gate`, `clause_order_gate`, `index_row_gate`, `doc_heading_gate`, `doc_coord_gate`): 전건 통과
  - 음성 단위 테스트 스위트 (`scripts/test_*.py` 29종): 전건 `🟢 pass` 통과 (100% PASS)
