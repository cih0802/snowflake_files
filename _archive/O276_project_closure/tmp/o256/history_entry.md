## O256-A — 80 헤더 통일 재빌드(원본 표준 헤더 + clean80 1회 · build_handoff 빌드 훅) (2026-10-21 · TRIALADMIN(SR61467) · ㉡ · 사용자 지시·승인 · dbt parse/compile 에이전트 실행 승인 · 확정위반 0)

- 요청 = 인수인계 기준 O256 작업 정리 → 승인 「dbt parse/compile 포함 · run·build 만 사용자」 → 「전부 작업」.
- 라벨 = `id_collision_gate --next O` = O257(참조 256 = 예고) · 원장 rc=1(O256 미정의) 확인 후 선점 등재 · `index_row_gate` PASS.
- 독해 = 지침 1~312 · `00_BRIEF` 1~152 · 인수인계 O0255-B 1~44 · O0255-D 1~40 · O0254-B 1~45 · 이력-089 245~287 · 95 `00_작업계획.md` 1~38 · `build_handoff.py` 1~242 · tools 4종 전량 · read 미반환 0 · 재호출 0.
- 사전 실측(`o256_measure.py`) = 530 중 same 187 · repro 307 · new 15 · diff 21 — diff 는 원본 최신(파일명 NN_DEPLOY · DEC-63 SV · 16번 복원 · 원장) · 80 전용 줄은 계정 스크럽뿐(훅 재현 · 런북 ⑯행 닫는 괄호 유실 버그는 재빌드로 시정).
- 헤더(`o256_header.py`) = SQL 285 · Purpose 첫 서술 주석(스냅샷 = source 유도) · Target = CREATE/ALTER/EXECUTE/CALL · Run order = 문서실행순서(운영계·기존 환경 갱신 번호) · Depends on = ref/source · FQN · Issue 토큰 · dry-run 보정 4건(`{# #}` · USE 줄 · `GRANT … ON` 오검출 · SV TABLES 의존).
- dbt = 프로젝트 profiles.yml 은 user 공란(Snowsight 실행용)이라 /tmp OAuth 프로필 사본으로 실행 · 원본 profiles.yml 무변경 · 1차 compile 중 샌드박스 /tmp 초기화로 기준선·로그 유실 → `o256_dbt_cmp.py`(로컬 /tmp 실행 · 로그 = `tmp/o256/`)로 재실행 · compiled 72 차이 = invocation_id 단일 패턴 → 정규화 후 0.
- 빌드 = 1차 재빌드에서 헤더 정렬 접힘(0/298) · O254 원장 행 init_ihcho 2 발견 → 훅 보정 후 298/298 · 0.
- 🟠 기타 = heredoc + `</dev/null` 로 python 미실행 1회(O252·O253·O255 와 같은 함정 · 스크립트 파일로 대체) · 실행 중 `build_handoff.py` 편집 1회(README 문구 반영 위해 무변경 재실행 1회 추가 · overwrite 0).
- 정본 3곳 = 원장 O256 행 · 이 항목 · 인수인계 O0256-A.
