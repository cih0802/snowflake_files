## O227-B C3 단계 ① 기준선 + 단계 ② GOLD 컬럼 298 (2026-10-14 · xh20001 · ㉡ 적용 · 사용자 「이어서 진행」 · 확정위반 1)

- 착수 = 👤 dbt build PASS=14 회신 · 같은 라벨 O227 후속 단위(-B · `R1-4-3`).
- ① 확인 = 라이브 뷰 COMMENT 12 잔여 이슈ID 0 · 휴일 주장 0.
- 기준선 eval V4 `o227s1` = EXEC 0.9524 → 0.9524 · MEMBER 0.9231 → 0.9746(D3 0.33 → 1.0 = O227-A 하락은 실행 변동) · 🟠 MKT 0.9764 → 0.8814(Q31 1.0 → 0 · 원인 단정 보류).
- ② 컬럼 298 = 테이블 29(06_DDL + 라이브 ALTER) · 뷰 269(_wide_schema.yml · 👤 build 대기) · 잔여 이슈ID 0 · comment_drift_gate 뷰 PENDING 269 = 변경분 일치.
- 라이브 실측으로 거짓 주장 36 덮어쓰기 = WIDE_MEMBER_MONTHLY 플래그·캠페인·후원사업 축 · WIDE_MEMBER_EVENT 신규기존 · WIDE_SERVICE_EVENT 캠페인 축 · 행사 업무키 · 휴일축 4 · BQ 연도 · BQ IDENTITY 원인문.
- 확정위반 1: `R1-7-1` 계열 쓰기 사고 = 블록 스칼라 머리줄만 덮어써 YAML 파손(라이브 ALTER 전 중단) · 복구 `tmp/o227/repair_plan_budget.py` · 유실 0(원문 535자 복원 · 헤더 `>-` 는 _archive 사본으로 확인).
- 라이브 변경(xh20001) = GOLD 테이블 컬럼 COMMENT 29 · eval run 3.
- 근거 = `tmp/o227/02_col_evidence.md` · `tmp/o227/c3_col_diff.md`.

### 독해 기록(`R1-3-7-b`)

- `tmp/o227/c3_col.tsv` 1~298(3회 분할) · 도착 · `O51-D-C` · `HOL-1` · `O216-G`.
- `_wide_schema.yml` 1075~1086 · 1071~1091 · 도착 · `PLAN_BUDGET_MONTH` · `>-`.
- read 미반환 0 · 재호출 0.

_Co-authored with CoCo_
