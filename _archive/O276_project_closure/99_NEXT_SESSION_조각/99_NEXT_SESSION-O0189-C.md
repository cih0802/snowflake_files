<!-- LLM-METADATA
doc_id: HANDOFF_O0189_C
doc_role: 인수인계 — 세션 `O189-C` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-29
created_by: O189-C
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0189-C -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O189-C-0 🔴 먼저 알아라 — O189 계열 현행 정본 (2026-09-29 · 종료 계정 xf98254)

- 🟢 재build `AGENCY_AD_BROADCAST+ CRM_MEMBER_SPONSOR_SPAN+` = **PASS 118 · WARN 1 · ERROR 0**(사용자 보고 · 🔴 재조회 판정은 하지 않았다 — 계정 종료).
- 🔴🔴 **다음 세션은 새 개발 계정**이다 — 이 계정(xf98254)의 라이브 수치는 **전부 인용 금지**(재측정 대상). BRONZE 재적재가 선행된다.
- 🔴 **원천 정의 갱신(2026-09-29)** 이 인수인계 DDL 에만 반영됐고 **하류 모델·DDL·SV 에는 아직 반영되지 않았다**(▣2 1행).
  ㉠ `BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV` + `BDGT_PRCD_NM`('예산절차') · 2번째 컬럼(YEAR 뒤)
  ㉡ `ML.ML_RST_DATA_ONCE_CONVERSION` 컬럼 COMMENT 4 · 테이블 COMMENT · 🔴 **타입 3 이 VARCHAR 로 바뀜**(ONCE_MBER_NO·CONVERSION_YN·DATA_TYPE)
  ㉢ `BRONZE_AGENCY.SP_LOAD_*` 3종 본문 변경(테이블 영향 0 · 인수인계 04 는 프로시저를 싣지 않는다)
  ⇒ `50_handoff/04`·`05` 는 원천과 `handoff_ddl_gate` **7축 전건 일치**(수정 완료).

### ▣ O189-C-1 🟢 사용자 결정(2026-09-29 · 정본 = 문서50 `-024` O189-C 표)

- **스냅샷 = GN_DW 범위 밖 종결** — 현업이 이력을 관리 · snapshots `+enabled: false` 유지 · SNAPSHOT 스키마를 만들지 않는다.
- **DW 정기 적재 Task = 운영계용 보류** — 개발 계정에서 만들지 않는다(운영계 이관 시 사용자 지시).
- **문서02(갱신형) = 전체 삭제 후 현재 측정 상태만 재서술** · 이력이 남아 문서가 늘면 이력을 **전부 없앤다**.
- **NL 스모크 36문항 = 다음 세션**(착수 시 과금 재확인).
- **산출물(`30_output_share`) 재생성 = 잔여 작업이 없을 때만**(중간 재생성 금지).

### ▣ O189-C-2 🟠 남은 작업

| 순 | 구분 | 중요도 | 작업 | 상태 | 선행 |
|---|---|---|---|---|---|
| 1 | ㉠ | 🔴 | **원천 갱신 하류 반영** — GOAL_DIV `BDGT_PRCD_NM` 실측(값 분포 = 당초/추경 축인가) → SILVER `CRM_BIZ_TARGET`(TARGET_TYPE '당초' 고정 · DK 해시) · `08_SILVER` DDL · `_sources.yml` · GOLD FTP·WIDE_TARGET_BIZ · SV_TARGET_BIZ(추경 제외 규칙) · ML ONCE_CONVERSION 타입 변경 → SERVING ML 뷰 CAST | 🔴 DDL 먼저 | BRONZE 재적재 |
| 2 | ㉠ | 🔴 | 새 계정 재구축 검증 — build · 게이트(table_ddl_column 103 · gold_erd_coverage · comment_drift · handoff_ddl) | 신규 | 1 |
| 3 | ㉠ | 🔴 | NL 스모크 36문항(「중간 오류 0」 · `nl_routing_smoke.py --apply`) | 과금 재확인 | 2 |
| 4 | ㉠ | 🟠 | 21건 중 배선 후속 7건 — F-1 DIVISION · F-2 ML 4그룹 · F-4 등급안 · L-1① D5 제외 · L-2 병기 · M-6 SEND_STATUS2 · W-1 ⓑ | 규칙 확정 | 2 |
| 5 | ㉠ | 🟠 | 2차-B 2단~(문서32 §3 · 나머지 32테이블 · 테이블 단위) | 설계 완료 | 2 |
| 6 | ㉡ | 🟠 | 문서02 갱신형 정리 — 조각 `-006`~`-008` 이력성 절 제거 · 현재 측정 상태로 재서술 | 규칙 확정 | 2 |
| 7 | ㉡ | 🟠 | W3 🟡 잔여 — GOLD 4개(신규 9종과 중복 대조) · E-1 `DIRECT_MNYRS_YN` 배선 · O99 SV 2종 · PM040 재배선 · O91-F | 실측 완료(구 계정) | 2 |
| 8 | ㉡ | 🟡 | 신규 19종 COMMENT 업무 문안 · `WIDE_TARGET_BIZ` yml stale 「0행」 · `BIGQUERY_BASIC` DDL 블록 부재 · `rename_stale_gate` 1건(`02_GN_DW_building/20_일배치테스트용.sql`) | 신규 | — |
| 9 | ㉡ | 🟠 | 👤 현업 회신 — F-3 SND 오픈 정의 · 문서20 👤 5건 · DGT 2026-06 이전분 | 대기 | — |
| 10 | ㉡ | ⏸ | DW 정기 적재 Task | 운영계 보류 | 사용자 지시 |
| 11 | ㉡ | ⏸ | 산출물 03~09 재생성 + 골든 | 잔여 0 일 때만 | 1~9 |

### ▣ O189-C-3 📋 다음 세션 복붙 프롬프트

```
@(skill:init_ihcho) 새 개발 계정 첫 세션이다. 인수인계 99_NEXT_SESSION-O0189-C.md 를 정본으로 삼는다(▣0 → ▣1 → ▣2).
0. 60_repeat_어카운트시작/readme.md 를 읽고, 그 표의 11_O누적작업_점검_재현_절차.md 절차대로
   O180~O189 세션 이력을 비판적으로 검토한다(판정식 카탈로그 · 「열림은 기재다」 J3 · 이전 계정 수치 인용 금지).
   ⇒ 검토 결과(확정위반 · 판정약점 · 되살아난 전제)를 먼저 한 표로 보고한다.
1. 계정 판정 — 현재 계정명을 SELECT CURRENT_ACCOUNT() 로 재고, BRONZE 재적재 완료 여부를 실측한다
   (BRONZE_CRM 53 · AGENCY 4 · ERP 2 · 행수 0 테이블 목록). 미완료면 07_데이터마이그 C_CONSUMER 절차를 제시하고 기다린다.
2. ▣2 1행(원천 갱신 하류 반영)을 먼저 한다:
   ㉠ BRONZE_CRM.TM_CM_MBER_DVLP_GOAL_DIV.BDGT_PRCD_NM 값 분포를 실측해 「당초/추경 축인가」를 판정한다.
   ㉡ 판정에 따라 SILVER CRM_BIZ_TARGET(TARGET_TYPE 고정값·DK 해시·컬럼 추가) · 08_SILVER DDL · _sources.yml ·
      GOLD FACT_TARGET_PROJECT(ANNUAL/SUPP 분기) · 06_DDL · WIDE_TARGET_BIZ yml · SV_TARGET_BIZ(추경 규칙) 반영안을 만든다.
   ㉢ ML.ML_RST_DATA_ONCE_CONVERSION 타입 변경(VARCHAR)이 SERVING ML 뷰·SV_ML_ONCE_CONVERSION 에 주는 영향을 확인한다.
   🔴 순서 = DDL(06·08) → GN_DW_ADMIN ALTER → 모델 → Jinja 전개 EXPLAIN → dbt 명령 제시(R4-1) · table_ddl_column_gate 로 검증.
3. 사용자 결정(▣1)은 이미 확정 — 되묻지 말 것. 스모크만 착수 시 과금을 재확인한다.
4. 같은 파일 병렬 edit 금지(O189 확정위반 재발 방지) · 산출물 재생성은 잔여 작업 0 일 때만.
5. 각 단위 종료 시 원장 행 · 세션이력 · 인수인계 라벨 파일 갱신 + 게이트(gate_census --final · doc_census · index_row_gate · line_len).
6. 끝나면 남은 작업을 같은 형식으로 정리한다.
```

_Co-authored with CoCo_
