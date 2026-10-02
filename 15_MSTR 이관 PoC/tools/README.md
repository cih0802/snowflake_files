# MSTR → Snowflake 이관 도구 (`15_MSTR 이관 PoC/tools`)

1차 PoC(O197)에서 정리한 도구입니다. 리포트 쿼리 1개를 Snowflake 객체 6종 파일로 바꿔 배포하고 검증합니다.
다음 단계인 **전체 MSTR 이관 스킬화**의 모듈로 쓰는 것을 전제로 만들었습니다.
이 폴더 밖(`/workspace/scripts`)에는 의존하지 않습니다.

## 구성

| 파일 | 역할 | 데이터 변경 |
|---|---|---|
| `mstr_common.py` | 경로·연결·원본(UTF-16) 파서 · 대상 DB/스키마 상수 | 없음 |
| `mstr_deps.py` | 리포트 쿼리 → 원본 4종 재귀 탐색(테이블·뷰·함수 + 적재 SP + 헬퍼) · BRONZE 실재 확인 | 없음 |
| `mstr_extract.py` | 매니페스트 대상 원문을 UTF-8 로 추출(제외 근거 포함) | 추출 폴더 4파일 덮어씀 |
| `mstr_gen.py` | `templates/<batch>_*.tmpl.sql` + 원본 데이터 주입 → `snowflake 적용 ddl/` · `--bake` 로 역반영 | ddl 파일 덮어씀 |
| `mstr_deploy.py` | ddl 파일 문장 단위 실행(첫 오류 정지) · `--drop` · `--check`(매니페스트↔라이브) | 🔴 라이브 |
| `mstr_verify.py` | `templates/<batch>_verify.sql` 의 `@CHECK` 실행 → 매니페스트 baseline 대조 | 없음(`--set-baseline` 은 매니페스트 갱신) |
| `mstr_pipeline.py` | 위 단계 순차 실행 · deploy/run 은 `--apply` 필요 | 🔴 `--apply` 시 |
| `manifests/<batch>.json` | 대상 객체 · 신규 객체 · 근거 보존(evidence) · **결정(decisions)** · baseline | — |
| `templates/` | 배치별 템플릿 · 검증 쿼리 | — |

## 실행

```
cd "15_MSTR 이관 PoC/tools"
python3 mstr_pipeline.py manifests/1차.json --steps deps,extract,gen,verify --ym 202601        # 무변경
python3 mstr_pipeline.py manifests/1차.json --steps deploy,run,verify --ym 202601 --apply       # 라이브
```

## 새 배치(리포트) 추가 절차 — 스킬 단계 정의

1. **매니페스트 생성**: `manifests/<batch>.json` 에 `report_query`·`extract_dir`·`deps_snapshot` 를 적는다.
2. **deps**: `mstr_pipeline.py … --steps deps` 를 돌린다.
   ⚠ 로 출력된 미결정 객체는 사람이 `objects`(이관) 또는 `evidence`+`decisions`(제외) 로 분류한다.
   `BRONZE 부재` 원천은 IT 확인 대상이다(1차 사례 = ExplCampList → 결정 X1).
3. **extract**: 원문 근거 파일을 만든다.
4. **변환(사람/LLM)**: 추출본을 읽고 `templates/<batch>_NN_*.tmpl.sql` 을 작성한다.
   기계 추출이 필요한 상수 데이터는 마커 `--@@KEY@@` 와 `mstr_gen.INJECTORS` 로 처리한다.
5. **gen → deploy → run → verify**: 처음 실행에서 `--set-baseline` 으로 기준선을 기록한다.
6. **결정 기록**: 제외·NULL·타입 확대 같은 판단은 반드시 `decisions` 에 근거와 함께 남긴다.

## 변환 규칙 (1차에서 확정 · 04 헤더와 동일)

- `[mart].[X]`·`dbo.FN_X` → `GN_DW.MSTR.X` · `MSTR_ODS.DBO.<T>` → `GN_DW.BRONZE_CRM.<T>`
- 타입: `varchar/char/nvarchar` → `VARCHAR` · `datetime` → `TIMESTAMP_NTZ` · `int/bigint` → `NUMBER` · `bit` → `BOOLEAN`
- 함수: `ISNULL`→`IFNULL` · `CONVERT(CHAR(8),d,112)`→`TO_CHAR(d,'YYYYMMDD')` · 문자열 `+`→`||` · `TOP 1`→`LIMIT 1`
- TVF → SQL UDTF(`RETURNS TABLE` 컬럼 명시) · 🔴 `SELECT *` UNION 은 위치 정렬 → 컬럼 순서를 명시한다
- SP → Snowflake Scripting:
  - `@@ROWCOUNT` → `SQLROWCOUNT`
  - `TRY/CATCH` → `EXCEPTION WHEN OTHER`(SQLCODE·SQLERRM 은 지역 변수로 받은 뒤 바인딩)
  - `EXEC` → `CALL`
  - `FROM FN(@p)` → `FROM TABLE(FN(:P))`
  - `INSERT … WITH` 는 서브쿼리로 바꾼다
- BRONZE 메타 컬럼(`_LOAD_DT`·`_BATCH_ID`·`_STDR_YM`)은 `SELECT *` 로 끌어오지 않는다

## 알려진 함정

- 파일 앞머리의 주석과 `USE` 문을 한 문장으로 보내면 서버가 빈 문장으로 처리한 사례가 있었다
  ⇒ `mstr_deploy` 가 선두 주석 줄을 떼고 실행한다.
- `SHOW PROCEDURES IN SCHEMA` 는 시스템 내장 프로시저도 함께 반환한다 ⇒ `is_builtin = 'N'` 으로 거른다.
- 원본 이름 충돌 사례: 1차의 `D_STRD_DE_CD`(VIEW/TABLE) ⇒ 결정 X2.

_Co-authored with CoCo_
