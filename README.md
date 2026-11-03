<!-- LLM-METADATA
doc_id: ROOT_README
doc_role: 워크스페이스 개요 — 무엇을 담은 곳인지 · 폴더별 역할 · 현재 상태 · 남은 일
created: 2026-11-03
created_by: O277-B
related: 00_WORKSPACE_MAP.md(상세 지도) · _archive/O276_project_closure/00_REFERENCE_CLEANUP_PLAN.md(종료 정리 경위) · _reuse_kit/00_README.md(재사용 키트)
END-METADATA -->

# 굿네이버스 데이터 플랫폼 — 프로젝트 워크스페이스 (종료 · 보관)

> Snowflake 기반 굿네이버스 데이터 플랫폼(`GN_DW`) 구축 프로젝트의 설계·구축·운영·인수인계 산출물을 모은 워크스페이스다.
> 🔴 **프로젝트는 2026-11-01 종료됐다.** 세션 운영물(이슈 원장·인수인계·작업기록)은 `_archive/O276_project_closure/` 로 보관했고,
> 다음 프로젝트용 재사용 자산은 `_reuse_kit/` 로 추출했다(O276~O277).

## 1. 먼저 볼 문서

| 목적 | 문서 |
|---|---|
| 폴더 전체 지도 · 정리 이력 | `00_WORKSPACE_MAP.md` |
| 종료 정리(O276~O277) 경위 · 검증 · 롤백 | `_archive/O276_project_closure/00_REFERENCE_CLEANUP_PLAN.md` |
| 정식 납품 문서 목록 | `85_실제 인수인계 문서/00_INDEX_산출물목록.md` |
| 다음 프로젝트에 키트 설치 | `_reuse_kit/00_README.md` |
| 설계 결정(DEC-nn) · 이슈 · 사고 사례 | `_archive/O276_project_closure/20_issue/` (`30_설계_의사결정.md` · `00_INDEX_이슈원장.md` · `91_사고사례집.md`) |

## 2. 폴더 구성

| 폴더 | 내용 | 비고 |
|---|---|---|
| `00_guides/` | 작업 지침 · 문서 분할/쓰기 규약 · 단계종료 게이트 · 방법론 · `init_ihcho` 스킬 정본 | 스킬 실행본은 여기서 빌드 |
| `10_design/` | 설계 — Gold 탑다운(11) · Silver(12) · 스냅샷(13) | |
| `10_dbt_pipeline/` | dbt 프로젝트 소스 · 배포·Task SQL | 🔴 위치 고정 — `GN_DW.OPS.DW_PIPELINE` 배포 경로 |
| `20_build/` | 구축 — 환경·RBAC(21) · Streamlit 앱(22) · SV/Agent(23) · 일적재(24) · MSTR 이관(25·26) · Streamlit 인증(27) · Cortex(28) · BRONZE 인계(29) | |
| `30_operate/` | 운영 — 모니터링(31) · Agent 개선(32) · 계정 부트스트랩(33) | |
| `50_handover/` | 인수인계 작업분 — 실행 순서 · 후속 프로젝트 골격 · 인계/현업 요청 | |
| `60_share/` | 현업 공유 산출물 · 업무 의사결정 회신 | |
| `70_reference/` | 참고 — PoC 백업 · 레거시 샘플 · MSTR 스킬 원본 | |
| `85_실제 인수인계 문서/` | **정식 납품본**(A0~A8 · D01~D14 · N01~N08) | 🔴 원문 보존 — 본문의 `80_…` 경로는 작성 당시 기준 |
| `90_provided_definition/` | 현업 제공 원본 — 지표 사전 · 원천 DDL · 정의서 csv/xlsx | 🔴 원본 고정 |
| `scripts/` | 게이트 · 운영 도구 · 생성기 | 세션 운영 게이트는 대상이 보관돼 「파일 없음」이 정상 |
| `_archive/` | 스냅샷 · 종료 보관(`O276_project_closure/`) · 재편 전 원본(`RESTRUCTURE_20261031-pre/`) · O277 롤백본 · 키트 반출본 | 🔴 내부는 원문 보존(치환 금지) |
| `_reuse_kit/` | 다음 Snowflake 구축 프로젝트용 재사용 키트(지침·스킬·도구·골격·템플릿 · `{{DB}}`/`{{ACCOUNT}}` 자리표시자) | 설치 = 키트 README |
| `tmp/` | 세션 임시 파일(실행 출력 · 검증 결과) | `.gitignore` 대상 · 지침 `R0-8-5` |
| `.snowflake/cortex/skills/` | 스킬 설치본(`init_ihcho` · `mstr-migration`) | `init_ihcho` 는 빌더 산출물 — 손으로 고치지 않는다 |

- 「10」 번이 둘(`10_design/` · `10_dbt_pipeline/`)인 것은 의도다 — dbt 폴더는 배포 경로라 옮기지 않았다.
- 보관된 옛 폴더(`20_issue/` · `40_worklog/` · `80_인수인계_프로젝트완료 및 유지보수용/` · `99_NEXT_SESSION*` · 옛 `tmp/`) = `_archive/O276_project_closure/` 아래 같은 이름.

## 3. 현재 상태 (2026-11-03)

- 🟢 종료 정리 완료 — O275 대응표 2,665행 · O276 대응표 5,477행 스테이지 대조 = **손실 0** · 끊긴 참조 정리 완료.
- 🟢 재사용 키트 완료 — 239파일 · 빈 루트 조립 테스트 39종 중 31 통과(나머지 8 = 원 프로젝트 데이터 의존 · 정상) · 반출본 `_archive/O277_reuse_kit_export/_reuse_kit_20261103.zip`.
- 🟢 `init_ihcho` 스킬 = 임시 파일 위치를 워크스페이스 `tmp/` 로 개정 · 재빌드 verify 통과.
  ⚠️ 이 워크스페이스에서 실행하면 Step 2(이슈 원장 · 인수인계) 대상이 보관돼 FAIL 이 정상이다 — 원장은 `_archive/O276_project_closure/20_issue/` 에서 읽는다.

## 4. 남은 일

- 이 워크스페이스 = 필수 작업 없음.
- 새 환경 = `_reuse_kit/00_README.md` §6(이름 적용 · 문구 정리 결정 · 골든 발행 · 번호표 적용 · 데이터 의존 테스트 픽스처 교체 · 원 프로젝트 근거 좌표 처리).

## 5. 주의

- `_archive/` · `85_실제 인수인계 문서/` · `90_provided_definition/` 은 원문 보존 대상이다 — 경로 치환 등으로 고치지 않는다.
- `10_dbt_pipeline/` 의 SQL·YAML 주석에 남은 `20_issue/…` 는 재배포 diff 를 피하려고 의도적으로 두었다(대응 = `_archive/O276_project_closure/20_issue/`).
- 폴더째 반출은 zip 으로 한다 — `cortex ws cp <폴더>/` 는 하위 폴더 구조를 평탄화한다.
- 임시 파일은 워크스페이스 `tmp/` 에 둔다 — OS `/tmp` 는 샌드박스 재시작 때 지워진다.
