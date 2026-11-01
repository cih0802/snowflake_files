<!-- LLM-METADATA
doc_id: HANDOFF_O0275_A
doc_role: 인수인계 — 세션 `O275-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-11-01
created_by: O275-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0275-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## ▣ O275-A-0 현황

- 문서정리(워크스페이스 목적별 재편) = 4-A·4-B·4-C 완료(2026-10-31 · TRIALADMIN · TQ68205).
- 계획 정본 = `00_WORKSPACE_RESTRUCTURE_PLAN.md` §6 체크리스트 · 전후 매핑표 = 루트 `MOVE_MAP.csv`(요약) · `MOVE_MAP_files.csv`(파일 단위 2,665행).
- 🔴 **옛 경로를 만나면 `MOVE_MAP_files.csv` 의 `old_path` 로 찾는다** — `20_issue`·`99_NEXT_SESSION_조각`·80·85·90·`_archive` 는 치환 금지 영역이라 옛 경로가 그대로 남아 있다(의도).
- 고정 영역(이동 없음) = `00_guides` · `20_issue` · `99_NEXT_SESSION_조각` · `scripts` · `10_dbt_pipeline` · `_archive` · `tmp` · 80 · 85 · 90 · `.snowflake`.

## ▣ O275-A-1 이번 세션 결과

- 4-A = 26폴더 README 목적·상태 기입 · 기존 README 누락 보완 · 스냅샷 `_archive/RESTRUCTURE_20261031-pre/4A/`.
- 4-B = 사용자 결정 ㉠ 80·85·90 고정 ㉡ 고정 외 전부 이동 ㉢ 파일명 날짜<20261001 중복 → 같은 폴더 `_archive/`(4건) ㉣ archive 도 매핑표 기재.
- 4-C = 7그룹 2,665파일 이동 · 스테이지 대조 신규 부재 0 · 원본 잔존 0 · 경로 치환 499건(`scripts` · `00_guides` · README/INDEX · `versions/live/` 배포 코드).
- 🔴 소실 1건 = `30_output_share/_archive/20260830/20260826_아키텍처 지도 요약본.html.O104-pre` → 배치 예정 `60_share/61_output_share/_archive/20260830/` · 사용자 원본 백업 보유(복원 대기) · 목록 `tmp/restructure/LOST_FILES.csv`.
- 🔴 확정위반 2 = R1-7-2 같은 파일 병렬 edit 4건(유실 0) · 경로 치환이 `scripts/golden/doc_headings.json`·`index_rows.json` 의 **값**까지 바꿈 → 4C 이전본 복원 + 문서 경로 키만 갱신(게이트 PASS).
- 도구 = `tmp/restructure/`(`exec_group.py` 재개형 실행기 · `chunk_move.py` · `final_verify.py` · `golden_fix.py`).

## ▣ O275-A-2 ㉠ 이 작업의 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 소실 파일 1건 복원(사용자 백업 → 배치 예정 경로) 후 `LOST_FILES.csv` 에 복원 표기 | 👤 사용자 |
| ② | 4-D 스킬 재생성 = 정본(`00_guides/03_init_ihcho_스킬_*.md`) 경로는 치환됨 → 기존 빌더로 설치본 재생성 · `mstr-migration` 스킬의 `05_SV-Agent_ai/` 참조 갱신 | 다음 세션 |
| ③ | 최종 검증 = `scripts/*.py` 하드코딩 옛 경로 잔존 스캔(치환 경계 밖 표기) · 음성 테스트 전건 · 선택 게이트 | 다음 세션 |
| ④ | 4-E = 새 상위 폴더 README 7개 · `_archive` 색인 README · `00_WORKSPACE_MAP.md` 새 구조 갱신 · `문서실행순서*.md` 4종 통합 · `tmp` 60일 초과 삭제 후보 목록 | 다음 세션 |
| ⑤ | 🔴 하지 마라 = `scripts/golden/*.json` 에 경로 치환 재적용 · 80·85·90 이동 · 대용량 그룹 단일 실행(샌드박스 재시작 3회 실측 → `chunk_move.py` 분할) | 금지 |

## ▣ O275-A-3 ㉡ 워크스페이스 백로그 (O274-B 승계 · 경로만 새 구조로)

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 운영계 O270 단계 6 게이트 재실행(`rbac_source_gate.py --live` · 음성) | 👤 운영계 |
| ② | 롤 전환 = `30_operate/32_agent_improvement/O273_롤전환_작업순서.md` 표 3(A~E) | 👤 IT팀·사용자 |
| ③ | 현업 회신문 · W9 공지 발송 · 회신(LTV 이상치 · 방송 총비용 9·10월) · R96(`tmp/root_scratch/R96쿼리결과.md`) | 👤 데이터팀·현업 |
| ④ | 구 역할 회수(48번 [6]) — 롤 ⑦·⑨ 후에만 | 🔴 사용자 승인 |
| ⑤ | 운영계 enum 게이트 조각 2/4·3/4 · 운영계 default 고정 원인 | 선택 |

_Co-authored with CoCo_
