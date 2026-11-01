# N07-02 · dbt 프로젝트 골격

> doc_id: N07 · as_of: 2026-10-20 · 원본 = GN_DW `10_dbt_pipeline/` · `85_…/A4_dbt_파이프라인_개발자가이드.md`

## 1. 레이어

| 레이어 | 모델 폴더 | 물리화 | 규칙 |
|---|---|---|---|
| BRONZE | (dbt 밖 · 원천 적재) | 테이블 | 원천 그대로 · `source()` 로만 읽는다 |
| SILVER | `models/silver/<원천>/` | incremental(append) | 정제 · 코드 표준화 · 민감 컬럼 제외 |
| GOLD | `models/gold/{dim,fact}/` | incremental · 테이블 | star schema · 미상·범위밖 값은 SK=0 Unknown 멤버 |
| WIDE(소비) | `models/gold/wide/` | view | SV 의 base · 소비 롤 SELECT |

- 🔴 GOLD 는 BRONZE 를 직접 읽지 않는다(`source()` 금지) — 필요하면 SILVER 모델을 하나 끼운다(GN_DW DR-25).
- 🔴 같은 원천을 다른 grain 으로 담은 팩트(형제 팩트)는 한 쿼리에서 조인하지 않는다 — 문서·SV COMMENT 에 명시한다.

## 2. 구조 소유와 적재 분리

- 테이블 **구조**(DDL · COMMENT · FK)는 정본 DDL 파일이 소유한다(ADMIN 실행).
- dbt 는 **적재만** 한다(`INSERT`/`TRUNCATE` · `on_schema_change: append_new_columns`). ⇒ dbt 롤에 GOLD `CREATE TABLE` 을 주지 않는다.
- 컬럼 변경 = ① 물리 `ALTER` ② 같은 세션에 정본 DDL 수정 ③ 모델 수정 ④ build ⑤ 정본↔물리 양방향 대조.
- ⚠️ incremental 모델은 대상 테이블에 없는 산출 컬럼을 **에러 없이 버린다** — 모델만 고치면 컬럼이 조용히 사라진다.

## 3. 배포 · 실행

```sql
-- 최초
CREATE DBT PROJECT IF NOT EXISTS <DB>.OPS.<PIPELINE> FROM '<워크스페이스 경로>/<dbt 폴더>';
-- 모델 수정 후 — 🔴 EXECUTE 는 배포본을 돈다(워크스페이스 수정이 자동 반영되지 않는다)
ALTER DBT PROJECT <DB>.OPS.<PIPELINE> ADD VERSION FROM '<워크스페이스 경로>/<dbt 폴더>';
-- 실행 (<PRJ>_DBT · <WH_ETL>)
EXECUTE DBT PROJECT <DB>.OPS.<PIPELINE> ARGS = 'build';
EXECUTE DBT PROJECT <DB>.OPS.<PIPELINE> ARGS = 'retry';   -- 실패 지점부터
```

- 실행 롤은 `profiles.yml` 에 1개로 고정한다. 다른 롤로 돌리면 뷰 소유가 섞여 다음 build 가 실패한다.
- 결과 판정 = ERROR 0 **그리고** SKIP 0. SKIP 은 상류 실패로 하위가 건너뛰어진 것이다.
- `--full-refresh` 는 막아 둔다(정본 DDL 구조가 지워진다).
- 테스트 실패 행은 `store_failures` 로 OPS 에 남기고 Alert 로 메일을 보낸다 — 감시 대상은 **소유 기준 동적 조회**로 잡는다(이름 목록 고정 금지 · GN_DW DR-24).

## 4. 정기 실행

```sql
CREATE TASK IF NOT EXISTS <DB>.OPS.TSK_DBT_BUILD_DAILY
  WAREHOUSE = <WH_ETL>
  SCHEDULE = 'USING CRON 1 6 * * * Asia/Seoul'
  SUSPEND_TASK_AFTER_NUM_FAILURES = 2
AS EXECUTE DBT PROJECT <DB>.OPS.<PIPELINE> ARGS = 'build';
-- RESUME 전에 수동 build 1회 + 실패 저장 테이블 0행 확인
```

- 후속 Task 를 `AFTER` 로 걸려면 같은 스키마 · 같은 소유 롤이어야 한다. 안 되면 고정 시각으로 띄우고 앞 작업 소요를 감시한다.
- 스냅샷(dbt snapshot)은 실제로 쓸 때만 단계에 넣는다(GN_DW DEC-61 = 영구 미가동).

_Co-authored with CoCo_
