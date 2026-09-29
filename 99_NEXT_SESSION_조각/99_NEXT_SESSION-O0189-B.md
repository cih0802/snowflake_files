<!-- LLM-METADATA
doc_id: HANDOFF_O0189_B
doc_role: 인수인계 — 세션 `O189-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-29
created_by: O189-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0189-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O189-B-0 🔴 먼저 알아라 (2026-09-29 · xf98254)

- 🟢 **build PASS 576 · ERROR 0 판정 완료** — 0행 4테이블 복구 · 신규 19종 적재 · DIM_ORG 활성 223 · FTP 연사업 348,024 / 팀 348,000(유형별 · 합산 금지) · WIDE_TARGET_BIZ 25컬럼.
- ⏸ **dbt 재build 필요**(▣3) — 이 단위에서 모델 3개를 고쳤다(J-2 초수 · 2차-B 1단 SILVER·GOLD). DDL·ALTER 는 **선행 적용 완료**(게이트 103/103).
- 🔴 **스모크 36문항 미실행** — `R4-4-3`(과금 LLM 대량 호출)은 별도 승인 대상. 명령 = `python3 scripts/nl_routing_smoke.py --apply`(판정 = 「중간 오류 0」 · rc=1 이면 FAIL).
- 🔴 **이번 세션 확정위반 1** — AGENT_MARKETING yaml 에 edit 3건을 병렬 전송(지시 5항). 해시·YAML 파싱·도구=리소스 집합 대조로 **손상 0** 확인.
- 🔴🔴 **신규 격상 2건** — ㉠ `SNAPSHOT` 스키마 부재 + dbt snapshots `+enabled: false` ⇒ DEC-53 「선이력」이 이 계정에서 **이력 0** ㉡ DW 정기 적재 Task **0**(B11).

### ▣ O189-B-1 🟢 이 단위가 끝낸 것

- **SV_TARGET_BIZ 배포**(+ N-24① 「연사업 기본」 규칙) · **Agent 3종 VERSION$7**(롤백 = VERSION$6) — EXEC·MKT 에 `analyst_target_biz` · 3종에 식별자 규칙(D안 ㉠) · stale 「사업목표 미입고」 문구 5곳 교정.
- **D안 ㉡** SV 5종 날짜 차원 동의어 `FULL_DATE`·`날짜` 추가 배포(DESCRIBE 확인) · **D안 ㉢** `nl_routing_smoke.py` 에 「중간 오류 0」 판정 + `--judge-only`(O188 결과 재판정 = 13문항 FAIL · rc=1 실증).
- **질문 21건** 문서20 판정줄 21/21 기재(🟢 닫힘 8 · 🟡 규칙 확정·배선 후속 7 · 👤 회신 대기 5 · 🟠 전제 불성립 1 = F-3 오픈 49만행은 전부 SND).
- **J-2 배선**(8자리 ÷ 1e6 · CAST NUMBER(9,0) · 채움 32,933 → 33,941 렌더 검증).
- **2차-B 1단** `TM_MM_FDRM_MBER_SPNSR.CMPGN_CD`·`ACMSLT_DEPT_CD` — DDL → ADMIN ALTER → 모델 순서 준수 · 후원 원천 캠페인 ≠ 대표캠페인 230건.
- **W3 8건 · B2~B12 J3 전수** → 문서50 `-024` 표(🟢 종결 7 · 🔴 격상 2 · 👤 1 · 🟡 나머지).
- **DDL 보존 2차 시정** — 신규 GOLD 9종 PK 5 + FK 8(정보성) 선언 · 팩트 3종 `DATE_SK` NUMBER(38,0) → **(8,0)**(데이터 보존 SWAP · 행수 동일) · SK COMMENT 10건 교정 · FTP 테이블 COMMENT 라이브 동기화 · 원천 거래키 9건 DEGEN 등재.
- **산출물** 03·04·05·06·07·08·09 재생성 + `09_빅테이블 VIEW.md` 재생성 → `test_generators` 21/21 · `test_verify_wide_doc` PASS(골든 `--reason` 발행 · 🟠 발행 라벨이 `UNLABELED` 로 찍혔다).
- 게이트 = table_ddl_column 103/103 · gold_erd_coverage PASS · comment_drift PASS.

### ▣ O189-B-2 🟠 남은 작업

| 순 | 구분 | 중요도 | 작업 | 상태 | 선행 |
|---|---|---|---|---|---|
| 1 | ㉠ | 🔴 | 재배포 + build(▣3) → `AGENCY_AD_BROADCAST.DURATION_SEC` 33,941 · FMSS `SPNSR_CMPGN_CD` 채움 · 재조회 | 사용자 실행 | — |
| 2 | ㉠ | 🔴 | NL 스모크 36문항(「중간 오류 0」 판정) | 🔴 과금 승인 필요 | 1 |
| 3 | ㉠ | 🟠 | 21건 중 🟡 배선 후속 7건 — F-1 DIVISION · F-2 ML 4그룹 · F-4 등급안 · L-1① D5 제외 · L-2 병기 · M-6 SEND_STATUS2 정리 · W-1 ⓑ UTM 원값 | 규칙 확정 · 🔴 **DDL 먼저** | — |
| 4 | ㉠ | 🟠 | F-3 재확인 — SND 오픈 정의 현업 확인 | 👤 | — |
| 5 | ㉠ | 🟠 | 2차-B 2단~ — 나머지 32테이블(민감·감사·메모 제외 후 테이블 단위) | 설계 완료 | — |
| 6 | ㉡ | 🔴 | 🆕 SNAPSHOT 스키마 생성·권한·snapshots 활성화 여부 결정(DEC-53 이력 0) | 👤 사용자 결정 | — |
| 7 | ㉡ | 🔴 | 🆕 DW 정기 적재 Task 부재(B11) — 스케줄 설계 | 👤 사용자 결정 | — |
| 8 | ㉡ | 🟠 | W3 🟡 잔여 — GOLD 4개(신규 9종과 중복 대조) · E-1 `DIRECT_MNYRS_YN` 배선 · O99 SV 2종 · PM040 재배선 · O91-F | 실측 완료 | — |
| 9 | ㉡ | 🟡 | B10 문서02 증분형 판단 | 👤 | — |
| 10 | ㉡ | 🟡 | 신규 19종 COMMENT 업무 문안 보강 · `WIDE_TARGET_BIZ` yml 의 stale 「0행」 문구 · `BIGQUERY_BASIC` DDL 블록 부재 | 신규 | — |
| 11 | ㉡ | 🟡 | `handoff_ddl_gate` 9건(ML ONCE_CONVERSION 원천↔인수인계) · `rename_stale_gate` 1건(사용자 신규 파일 `02_GN_DW_building/20_일배치테스트용.sql`) | 이번 변경과 무관 | — |
| 12 | ㉡ | 🟠 | DGT 2026-06 이전분 재송부 | 👤 | — |

### ▣ O189-B-3 ⏸ dbt 정지점 (`R4-1`)

```sql
USE ROLE GN_DW_DBT;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select AGENCY_AD_BROADCAST+ CRM_MEMBER_SPONSOR_SPAN+';
```

_Co-authored with CoCo_
