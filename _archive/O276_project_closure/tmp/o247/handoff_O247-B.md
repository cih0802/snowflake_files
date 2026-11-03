### ▣ O247-B-0 🔴 먼저 알아라

- `O247-B` = O247-A 후속 · 95 프롬프트 산출물의 **개발계 반영**(2026-10-20 · trialadmin(iw20760) · ㉡ · 사용자 승인 전부 · 확정위반 1 = 병렬 SQL 호출 2건이 세션 롤 전환과 섞여 ADMIN 으로 ACCOUNT_USAGE 조회 실패 → 순차 재실행 · 유실·오적용 0).
- 다음 계획(사용자) = 개발계 이상 없음 확인 → 워크스페이스 통째로 운영계 이관 → 적용 → 95 기반 수치 재측정(저가 모델).
- 운영계 정본 = `85_실제 인수인계 문서/_ENV/운영계_반영_체크리스트.md`(순서 = ① → ⑤ → ② → ③ → ④ → ⑥).

### ▣ O247-B-1 이번 단위 결과

| 항목 | 결과(IW20760 · 라이브 확인) |
|---|---|
| 선행 권한 | ADMIN 에 APPLY MASKING POLICY · MANAGE DATA QUALITY · EXECUTE DATA METRIC FUNCTION · DATA_METRIC_USER(`SHOW GRANTS` 4건) |
| DR-25 | `SILVER.CRM_HOLIDAY` 생성(FUTURE GRANT 정상 · DBT INSERT) · dbt 새 버전 `O247_DR25_CRM_HOLIDAY` |
| A2 | [1] 시뮬레이터 뷰 SELECT 5롤 · [2] 90일 접근 0 → ANALYST OPS 회수(OPS USAGE = ADMIN·ENGINEER·DBT) |
| 마스킹 | `MP_PII_STRING` · 부착 12 · ADMIN 가림 0 · DBT(보조 롤 끔) 2,491,633/2,491,633 `***` |
| N01 DMF | 136문장 OK(`tmp/o247/n01_apply.csv`) · GOLD 스케줄 `0 8 * * * Asia/Seoul` · 표본 3 테이블 부착 확인 |
| 파일명 | `_미실행` → `_적용완료` 3종(11_BRONZE · A2_권한조정 · N01_DMF) · 옛 파일 각 `_archive/` · 참조 42건 치환 · 80번 재빌드 MISSING 0 · INDEX 「_미실행」 0 |
| 도구 | `scripts/n01_dmf_apply.py`(MUTATES 등재 · gate_census PASS) |
| 운영계 문서 | 체크리스트 ⑤ = 개발계 실행 순서·문장 그대로 · ④ = 칸 ← csv·컬럼 대응표 |

### ▣ O247-B-2 ㉠ 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 👤 `EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build'` — ERROR 0 · SKIP 0 · `SILVER.CRM_HOLIDAY` 251 | 👤 사용자(R4-1) |
| ② | ① 후 `b_struct_build.py IW20760` → `n03_catalog_build.py IW20760` 재생성(D06 DIM_DATE 원천 = CRM_HOLIDAY) | 에이전트 |
| ③ | DMF 첫 실행(08:00 KST) 후 `SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS` 확인 — DR-31 2 간선 외 위반 0 기대 | 다음 세션 |
| ④ | 👤 운영계 이관 → 체크리스트 | 👤 사용자 |

### ▣ O247-B-4 ⚪ 결정 완료(재론 금지)

- N01 DMF = 전부 적용(DR-31 2 간선 위반 관측 포함) · N02 [1][2] 이메일 마스킹 = 적용 안 함.
- 적용한 파일은 `_적용완료` · 옛 이름은 같은 폴더 `_archive/`(삭제 아님) · 부분 적용 N02 는 이름 유지 + 머리 표기.
