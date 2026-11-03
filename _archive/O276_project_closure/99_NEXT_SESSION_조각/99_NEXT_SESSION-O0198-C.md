<!-- LLM-METADATA
doc_id: HANDOFF_O0198_C
doc_role: 인수인계 — 세션 `O198-C` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-02
created_by: O198-C
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0198-C -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O198-C-0 🔴 먼저 알아라 (2026-10-02 · pw69582 · 세션 마무리 · **GN_DW 재구축 직전**)

- 🔴 사용자 결정 = **GN_DW 를 삭제하고 처음부터 재구축**한다. 다음 세션 시작 시점에 GN_DW 는 **없을 수 있다**(라이브 실측 먼저 · J3).
- 🟢 이 세션의 문서 산출물(재구축 입력) =
  · `50_handoff/04_데이터마이그 GN_DW_BRONZE_DDL.sql` — BRONZE 64 · 원천 재수령분 6축 차이 0(GOAL_DIV M01~M12 NUMBER(38,10))
  · `50_handoff/05_데이터마이그 GN_DW_ML_DDL_20260814.sql` — ML **12종** · 원천 무변경 발췌 · 🔴 10종 구조 대변경(VARIANT 위치 $6/$3/$3/$3/$3)
  · `50_handoff/06_데이터마이그 GN_DW_SILVER_DDL.sql` — SILVER **4** (BIGQUERY_REFINED_DATA + 예측용 집계 3)
  · `50_handoff/02_데이터마이그 A_PRODUCER.sql` — share = ML 12 GRANT + 구 LTV 4 REVOKE(2-C) + SILVER 4 · 기대 총계 80
  · `02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql` — 🆕 `GN_DW_ML_WH` 생성(크기 SMALL = 추정) · §D.5-B LOADER ML·프로시저·WH 권한
  · `02_GN_DW_building/08_After_Deploy_DBT.sql` — 🆕 §[4] 월마감 `SP_EXEC_MONTH_END` + `ML_PROCEDURE_LOG` 확인(ADMIN)
- 🟢 게이트 = `handoff_ddl_gate` 6축 0 · 테스트 17/17 · `SILVER_SCOPE`(4)·`ML_SCOPE`(12) 신설 · 축7 기준값 = 총계 80 · ML 12.
- 🟠 임시 파일 `ML스키마에 LOADER롤추가_작업후삭제.sql` = 07·08 에 편입 완료 · **삭제는 사용자 확인 후**(R4-4-3).

### ▣ O198-C-1 🟠 남은 작업 — 다음 세션(재구축)

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | 재구축 착수 실측 | `SHOW DATABASES LIKE 'GN_DW'` · 롤·WH 실재 · A share 마운트 여부 |
| 2 | 07 → 04/06/05 DDL → 데이터 적재 → 06_DDL(GOLD) → dbt(사용자) → 08 | 순서 정본 = `02_GN_DW_building/` 번호 순 · dbt 명령은 사용자 실행 |
| 3 | 🔴 SERVING ML 뷰 재배선 | `05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql` — 신 ML 12 구조(피처 컬럼 제거 · SERIES 개명 · 구 LTV 4 → 신 2)에 맞춰 수정 · SV_ML_* · Agent 도구 영향 |
| 4 | 🔴 07번 C_CONSUMER VARIANT 위치 | A.5-B.2 `TRY_PARSE_JSON($n)` = 05번 신 위치로 |
| 5 | 예측용 SILVER 3종 SV 배선 | 기획실·회원실 질의(O198-B ▣1 ⛔) — 적재 후 GOLD/SV 설계 · DATA_TYPE_NM 목표/실적·예측/실측 |
| 6 | 문서 stale 107건 | `01`·`02_1`·`03`·`07` 의 82/17 표기 → 80/12 (`handoff_ddl_gate` 축7) |
| 7 | LOADER DML 권한 | 08 §[4] 첫 실행 권한 오류 시 대상 테이블만 부여(EXECUTE AS CALLER 여부 미확인) |
| 8 | O197 계열 | MSTR 원 리포트 대조 · 이력 재적재 · 스킬화(재구축 후 GN_DW.MSTR 재배포 포함) |

### ▣ O198-C-2 ⚪ 결정 완료(재론 금지)

- ML 이관 = 12종(사용자 확정) · SILVER 이관 = 4종 · 부재값 응답 규칙 · 합계 규칙 · DEC-60.

_Co-authored with CoCo_
