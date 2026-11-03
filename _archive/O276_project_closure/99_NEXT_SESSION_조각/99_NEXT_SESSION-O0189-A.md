<!-- LLM-METADATA
doc_id: HANDOFF_O0189_A
doc_role: 인수인계 — 세션 `O189-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-29
created_by: O189-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0189-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O189-A-0 🔴 먼저 알아라 (2026-09-29 · xf98254)

- 🔴 **사용자가 2026-09-29 00:21 에 build 를 이미 돌렸다 — 597 중 14 실패(전부 권한).**
  원인 = O188-A~F 가 **모델만 고치고 DDL 정본(06_DDL · 08_SILVER)을 갱신하지 않았다**
  (`dbt_project.yml:256` 절차 ①DDL ②ADMIN ALTER 를 건너뜀).
  ㉠ 신규 19종 CTAS → GN_DW_DBT 에 CREATE TABLE 없음 ㉡ 증설 컬럼 `ALTER ADD COLUMN` → MODIFY 없음.
- 🔴🔴 **pre-hook TRUNCATE 가 ALTER 보다 먼저 성공해 4테이블이 0행으로 남아 있다**:
  `SILVER.CRM_ORG` · `SILVER.CRM_SEND_MEMBER` · `SILVER.CRM_MEMBER_SPONSOR_SPAN` · `GOLD.DIM_MEMBER`
  (+ 원래 0행 `AGENCY_AD_BROADCAST_CASE`·`FACT_AD_BROADCAST_CASE`). ⇒ 재 build 로 복구된다.
- 🟢 **이 단위가 고쳤다**(GN_DW_ADMIN 적용 · 재조회 확인):
  - 두 DDL 파일에 O189 절 추가 — 기존 8테이블 **24컬럼**(CREATE 블록 말미 + `ALTER … ADD COLUMN IF NOT EXISTS`) · 신규 **19테이블** CREATE
  - 타입 = 모델 렌더 실측(상류 TEMP 그림자 + DESCRIBE · 임시 계측기 2종은 세션 종료 시 삭제) · `*_SK` 는 규약 NUMBER(38,0)
  - 43문 TEMP 치환 실행 PASS → 라이브 적용 43문 · 신규 19종 ADMIN 소유 · FUTURE GRANT 로 DBT DML 권한 확인
  - `scripts/table_ddl_column_gate.py` 결함 3건 수정(DDL 없는 GOLD 모델 미탐지 · `bronze_crm_ref` 스키마 오해석 · 1건 실패 시 전체 크래시)
    ⇒ 결과 **집합 일치 103/103** · 순서 드리프트 🟠 2(FACT_MEMBER_MONTHLY 기존 · CRM_ORG 감사컬럼 뒤 LAST_UPDT_DT = 라이브 ordinal 과 일치)
- ⚠️ 신규 19종 컬럼 COMMENT 는 **BRONZE 원천 COMMENT 상속 1차본**(출처 표기) — 업무 문안 보강은 후속(▣2 9행).

### ▣ O189-A-1 🟢 판정

- ▣2 1행(build) = **실행됨 · 실패** → DDL 선행 시정 완료 · **재 build 대기**(명령 = ▣3).
- O188-G ▣1 사용자 결정 3건은 유효(미집행 — build 선행 · 이 단위는 build 차단 해소에 한정).

### ▣ O189-A-2 🟠 남은 작업

| 순 | 구분 | 중요도 | 작업 | 상태 | 선행 |
|---|---|---|---|---|---|
| 1 | ㉠ | 🔴 | 재배포 + build(▣3) → 0행 4테이블 복구 · DIM_ORG 223 · FTP 348,024/348,000 · 신규 19 행수 · 새 컬럼 채움률 | 사용자 실행 | — |
| 2 | ㉠ | 🔴 | `05_11` SV_TARGET_BIZ 배포 + Agent EXEC·MKT 도구 | 대기 | 1 |
| 3 | ㉠ | 🔴 | 질문 21건 §4 확정안 집행(문서20 판정줄) | 결정 완료 | 1 |
| 4 | ㉠ | 🟠 | Agent 처방 D안 → SV 5종·Agent 3종 재배포 + 스모크 | 결정 완료 | 1 |
| 5 | ㉠ | 🟠 | 2차-B 연결 테이블 누락 컬럼(문서32 §3) — 🔴 **DDL 먼저**(이번 사고 재발 금지) | 설계 완료 | 1 |
| 6 | ㉡ | 🟠 | W3 8건 · B2~B12 실측 → 종결 | 결정 완료 · 미착수 | — |
| 7 | ㉡ | 🟠 | DGT 원천 2026-06 이전분 재송부 | 사용자 확인 | — |
| 8 | ㉡ | 🔴 | 03·08·09 재생성 → test_generators 골든 · test_verify_wide_doc 25 | 세션 정리 직전 | 1 |
| 9 | ㉡ | 🟡 | 신규 19종 컬럼 COMMENT 업무 문안 보강 + `BIGQUERY_BASIC` DDL 블록 부재 확인(dbt_project.yml:192 외부 적재 여부) | 신규 | — |
| 10 | ㉡ | 🟢 | ~~임시 계측기 2종 정리~~ — O189-A 종료 시 삭제 완료 | 닫힘 | — |

### ▣ O189-A-3 ⏸ dbt 정지점 (`R4-1`)

```sql
USE ROLE GN_DW_DBT;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build';
```
(전체 build 권장 — 0행 4테이블 하류 전파분까지 복구)

_Co-authored with CoCo_
