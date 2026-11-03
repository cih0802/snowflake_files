<!-- LLM-METADATA
doc_id: HANDOFF_O0191_A
doc_role: 인수인계 — 세션 `O191-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-30
created_by: O191-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0191-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O191-A-0 🔴 먼저 알아라 (2026-09-30 · bt97381)

- 사용자 결정 = 추천안 순1~10 **과금 포함 전부 승인**(순11 제외).
- ⏸ **dbt build 1회 필요** — DIM_ORG 4컬럼(F-1 선배선) · DDL·ADMIN ALTER 선행 완료(게이트 103/103 · DIM_ORG 20/20).
- 🔴 확정위반 1 = 세션 착수 브리핑(`R4-4-1`)을 작업(스모크·F-1 실측) 뒤에 출력(O190-F 와 같은 결함 · 2회 연속).
- 🟢 `R4-4-2 ㉡`(지시 동봉 즉시 수행) 적용 세션.

### ▣ O191-A-1 🟢 이 단위가 끝낸 것

- **스모크 11 → 3**(PASS · 기준선 10 → 3 갱신 · 직전 요약 = `tmp/nlsmoke/_summary_O190G_pre.json`).
  원인 = 「기간 미지정 = 최근 12개월」 규칙이 Agent 에 **기준 시점 헬퍼 CTE** 를 짜게 했고 그 CTE 를 틀리게 조립했다
  (별칭 누수 · 추측 날짜 컬럼 · metric 이름 컬럼 참조 · 상관 서브쿼리).
  처방 = SV 7종 AI_SQL_GENERATION 에 `R-O191` 기준시점 규칙 + 정답 VQR 7건 · 배포 7/7 · 라이브 GET_DDL 실재 · ANALYST 조회 7/7.
- **F-1** 부서코드 접두 = 실적트리 단계(ZB 구분 · ZC 단위) 실측 · `DIM_ORG` 4컬럼(`ACMSLT_DIV_GROUP_ID/NM` · `ACMSLT_DIV_ID/NM`)
  모델·yml·DDL + 라이브 ALTER · SILVER 등가 쿼리로 454/450 재현 · `DIVISION` 은 NULL 유지.
- **19종 COMMENT** 라이브 19/19 + DDL 2파일 · `ACCOUNT_DIV_CD` 두 원천 도메인 상이 실측 → 「ACCOUNT_KIND 동반」 명시.
- 현업 요청서 항목별 분해 `30_output_share/41`~`46` · COMMENT 초안 `47`.
- `test_agent_tool_claim_gate.py` 축10(키 순서 픽스처) · 단정 21/0.

### ▣ O191-A-2 🟠 남은 작업

㉠ 이 작업의 잔여

| 순 | 작업 | 남은 이유 | 다음 행동 |
|---|---|---|---|
| 1 | dbt build(DIM_ORG) | 사용자 실행(`R4-1`) | ▣3 명령 → `ACMSLT_DIV_*` 도달 454/450 재조회 |
| 2 | 스모크 잔여 3 | 새 패턴 | MEMBER_01 `__FEE.` 별칭(규칙 효과 부분) · MEMBER_14 `PREDICTED_ONCE_MEMBERS` · EXEC_09 `FI.AVG_SCORE`(ML SV) |
| 3 | 현업 요청 발송 | 사용자 | `41`~`46` 수신처별 · `45` 는 ML 담당 |

㉡ 워크스페이스 백로그(이 작업과 무관) = 2차-B 2단 32테이블 · 문서02 재서술 · 산출물 03~09 재생성(잔여 0 조건).
- 🟠 기존 결함(이 세션 무관) = `test_o125_layer_census.py` 축3·4 가 표본 컬럼수를 **하드코딩**(FMD 38 · 현재 DDL·모델 모두 43 · 게이트 일치)
  ⇒ 테스트 rc=1 · 처방 = 하드코딩 대신 `table_ddl_column_gate` 의 모델 컬럼수와 대조(`R3-9 ㉦` 계열).

### ▣ O191-A-3 ⏸ dbt 정지점 (`R4-1`)

```sql
USE ROLE GN_DW_DBT;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select DIM_ORG';
```

_Co-authored with CoCo_
