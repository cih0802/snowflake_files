<!-- LLM-METADATA
doc_role: _archive 출처 색인 — 스냅샷 명명 규칙 · 원래 문서 · 보존 정책
created: 2026-11-01
created_by: O275-C
related: 00_guides/02_파일쓰기_안전규약.md R1-7-10 · scripts/snapshot_util.py
END-METADATA -->

# _archive — 스냅샷 보관소 출처 색인

> 🔴 **고정 영역** — 이동·이름 변경·본문 치환 금지(O275). 이 README 만 신규로 더했다.
> 생성 시점 실측 = 직속 파일 985 · 하위 폴더 6 · 명명 규칙 불일치 40. 🔴 수는 갱신되지 않는다.

## 1. 명명 규칙

- 파일 스냅샷 = `<원본 파일명>.<라벨>-<태그>` (예: `00_INDEX_이슈원장-001.md.O105-final` = 원장 조각 001 · 세션 O105 · 태그 final).
  - 라벨 = `--label` 인자 → `SESSION_LABEL` → `UNLABELED`(`R1-7-10`) · 같은 이름이면 덮지 않고 `.2`·`.3` 접미.
  - 생성 경로 = `scripts/snapshot_util.py` 만(`R1-7-10`) · 그 이전 스냅샷은 손으로 만든 이름이 섞여 있다.
- 폴더 스냅샷 = 일괄 작업 단위 백업(아래 §2).

## 2. 하위 폴더

| 폴더 | 출처 |
|---|---|
| `O55_helper_rollback_20260810/` | 세션 `O55` 일괄 작업 백업 |
| `O85_snapshots/` | 세션 `O85` 일괄 작업 백업 |
| `O92B_pre_rebalance/` | 세션 `O92B` 일괄 작업 백업 |
| `O92_pre_rebalance/` | 세션 `O92` 일괄 작업 백업 |
| `O96_99NEXT_presplit/` | 세션 `O96` 일괄 작업 백업 |
| `RESTRUCTURE_20261031-pre/` | O275 재편 백업(4A README · 4B MOVE_MAP v1 · 4C 치환 원본 · residual 정정 원본) — 되돌리기 정본 |

## 3. 원본 문서별 스냅샷 수 (상위 40)

| 원본 파일명 | 스냅샷 수 | 현행 위치 |
|---|---|---|
| `00_INDEX_이슈원장.md` | 267 | `20_issue/00_INDEX_이슈원장.md` |
| `99_NEXT_SESSION.md` | 144 | `99_NEXT_SESSION.md` |
| `90_해소완료_로그.md` | 36 | `20_issue/90_해소완료_로그.md` |
| `30_설계_의사결정.md` | 32 | `20_issue/30_설계_의사결정.md` |
| `50_dbt_파이프라인_미결조치.md` | 31 | `20_issue/50_dbt_파이프라인_미결조치.md` |
| `01_세션이력.md` | 28 | `20_issue/01_세션이력.md` |
| `agent_spec.yaml` | 21 | (현행 위치 없음 — 은퇴·개명 · `MOVE_MAP_files.csv` 또는 이력 검색) |
| `20_현업확인_요청.md` | 18 | `20_issue/20_현업확인_요청.md` |
| `SKILL.md` | 13 | `.snowflake/cortex/skills/init_ihcho/SKILL.md` · `.snowflake/cortex/skills/mstr-migration/SKILL.md` |
| `00_INDEX_이슈원장-001.md` | 11 | `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-001.md` |
| `01_문서분할_규약.md` | 10 | `00_guides/01_문서분할_규약.md` |
| `02_상태상세_대시보드_갱신형.md` | 10 | `20_issue/02_상태상세_대시보드_갱신형.md` |
| `10_진단_원인분석.md` | 10 | `20_issue/10_진단_원인분석.md` |
| `99_NEXT_SESSION-020.md` | 8 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-020.md` |
| `03_이슈상세.md` | 7 | `20_issue/03_이슈상세.md` |
| `06_BRONZE노출감사.csv` | 7 | (현행 위치 없음 — 은퇴·개명 · `MOVE_MAP_files.csv` 또는 이력 검색) |
| `08_SILVER_테이블DDL_20260714.sql` | 7 | (현행 위치 없음 — 은퇴·개명 · `MOVE_MAP_files.csv` 또는 이력 검색) |
| `06_BRONZE노출감사.md` | 6 | (현행 위치 없음 — 은퇴·개명 · `MOVE_MAP_files.csv` 또는 이력 검색) |
| `00_INDEX_이슈원장-002.md` | 5 | `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md` |
| `03_init_ihcho_스킬_본문.md` | 4 | `00_guides/03_init_ihcho_스킬_본문.md` |
| `06_DDL.sql` | 4 | (현행 위치 없음 — 은퇴·개명 · `MOVE_MAP_files.csv` 또는 이력 검색) |
| `09_빅테이블 VIEW.md` | 4 | (현행 위치 없음 — 은퇴·개명 · `MOVE_MAP_files.csv` 또는 이력 검색) |
| `90_해소완료_로그-017.md` | 4 | `20_issue/90_해소완료_로그_조각/90_해소완료_로그-017.md` |
| `91_사고사례집.md` | 4 | `20_issue/91_사고사례집.md` |
| `00_작업지침_세션운영규칙.md` | 3 | `00_guides/00_작업지침_세션운영규칙.md` |
| `02_상태상세_대시보드_갱신형-006.md` | 3 | `20_issue/02_상태상세_대시보드_갱신형_조각/02_상태상세_대시보드_갱신형-006.md` |
| `02_상태상세_대시보드_갱신형-008.md` | 3 | `20_issue/02_상태상세_대시보드_갱신형_조각/02_상태상세_대시보드_갱신형-008.md` |
| `05_01_SV_DDL_MEMBER_MONTHLY.sql` | 3 | (현행 위치 없음 — 은퇴·개명 · `MOVE_MAP_files.csv` 또는 이력 검색) |
| `05_04_SV_DDL_SERVICE.sql` | 3 | (현행 위치 없음 — 은퇴·개명 · `MOVE_MAP_files.csv` 또는 이력 검색) |
| `05_10_SV_DDL_MEMBER_SPONSOR_BIZ.sql` | 3 | (현행 위치 없음 — 은퇴·개명 · `MOVE_MAP_files.csv` 또는 이력 검색) |
| `05_2_SV_DDL_MEMBER_EVENT.sql` | 3 | (현행 위치 없음 — 은퇴·개명 · `MOVE_MAP_files.csv` 또는 이력 검색) |
| `22_ML_SV_DDL.sql` | 3 | (현행 위치 없음 — 은퇴·개명 · `MOVE_MAP_files.csv` 또는 이력 검색) |
| `50_dbt_파이프라인_미결조치-014.md` | 3 | `20_issue/50_dbt_파이프라인_미결조치_조각/50_dbt_파이프라인_미결조치-014.md` |
| `90_해소완료_로그-008.md` | 3 | `20_issue/90_해소완료_로그_조각/90_해소완료_로그-008.md` |
| `90_해소완료_로그-016.md` | 3 | `20_issue/90_해소완료_로그_조각/90_해소완료_로그-016.md` |
| `99_NEXT_SESSION-016.md` | 3 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-016.md` |
| `_wide_schema.yml` | 3 | (현행 위치 없음 — 은퇴·개명 · `MOVE_MAP_files.csv` 또는 이력 검색) |
| `01_세션이력-035.md` | 2 | `20_issue/01_세션이력_조각/01_세션이력-035.md` |
| `03_init_ihcho_스킬_정본.md` | 2 | `00_guides/03_init_ihcho_스킬_정본.md` |
| `04_데이터마이그 GN_DW_BRONZE_DDL.sql` | 2 | (현행 위치 없음 — 은퇴·개명 · `MOVE_MAP_files.csv` 또는 이력 검색) |

## 4. 보존 정책

- **무기한 보존**(계획 §5 · 사용자 결정 2026-10-31) — 삭제하지 않는다. 되돌리기 수단이다.
- 검색 시 = `ls _archive/ | grep <문서명>` 으로 파일명부터 좁힌다(대용량 · 60초 초과 · `R0-8-3`).
- 각 폴더 아래의 `_archive/`(예: `20_build/23_sv_agent/_archive/`)는 **폴더별 구버전 보관**이다 — 이 색인 범위 밖.

_Co-authored with CoCo · O275-C_
