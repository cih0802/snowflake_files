<!-- LLM-METADATA
doc_id: HANDOFF_O0271_A
doc_role: 인수인계 — 세션 `O271-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-30
created_by: O271-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0271-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## ▣ O271-A-0 🔴 먼저 알아라

- O270 운영계(ZL50263) 0·1단계 정지 해소 **준비**만 했다 — 라이브 변경 0(개발계·운영계 모두).
- 운영계에만 있는 SERVING 뷰 4(DIM_MEMBER_CURRENT · DIM_MONTH · FACT_AD_COMBINED · ML_LTV_SCORE_V)는 현행 정본 DDL 에 CREATE 가 없다.
  근거 = `05_SV-Agent_ai/21_ML_SERVING_뷰_DDL.sql:271`(O198 폐기) · `05_SV-Agent_ai/00_README.md:41`(helper DROP O55) · `:44`(동봉 폐지 O54).
  ⇒ 잔존 뷰 「후보」 · 🔴 원천 분류는 R98 리니지로만 · 결정 전 GRANT 0.
- 🔴 `rbac_source_gate.py --live` 는 창고 `GN_DW_DEV_WH` 로 접속한다 — 운영계 실재 미실측.
- 🔴 `O270_apply_rbac_dev.py` 는 개발계 판 48번을 읽는다 — 운영계 판과 GRANT 본문 동일(184문)이라 현재는 무해.

## ▣ O271-A-1 결과

| 단위 | 결과 | 좌표 |
|---|---|---|
| A R98 | 4뷰 GET_DDL · 재귀 리니지 · 30일 사용자 · 하류/SV · GRANT + Q09 쓰기 실적(Q07·Q08) · 컴파일 OK | `85_실제 인수인계 문서/30_현업요청대응/_근거쿼리/R98_O270_운영계잔존뷰_원천.sql` |
| B 생성기 | `--types` `--out` `--account` 인자 · 기본 출력 cmp rc=0 | `12_agent개선과제/output/O270_gen_rbac_sql.py` |
| B 운영계 판 | 미분류 4건 머리 주석 · GRANT 184(개발계와 동일) | `05_SV-Agent_ai/48_RBAC_SOURCE_ACCESS_ZL50263.sql` |
| B 게이트 | 음성 테스트 +2축(분류표 밖 무GRANT = 통과 · 무분류 GRANT = 위반) PASS | `scripts/test_rbac_source_gate.py` |
| C·E 판정 | Q09 영향 · Streamlit 소유자 권한 판정 · 1-B 처방(미승인) | `12_agent개선과제/O270_W8_운영계_실행카드.md` §1·§3 |
| D 배정표 | 14행 초안 · 제안·확정 열 공란 · 질문 4 | `12_agent개선과제/O270_운영계_사용자배정표.md` |
| F 프롬프트 | 단계 1(운영계 판) · 1-A(R98) · 1-B · 단계 2 주의 · 단계 7(확정 열만) | `12_agent개선과제/O270_운영계_LLM_프롬프트.md` |

## ▣ O271-A-2 ㉠ 이 작업의 잔여

| 순 | 작업 | 정지점 |
|---|---|---|
| ① | 👤 운영계 R98 실행 → CSV 회수 → 4뷰 판정(㉠ 분류 후 GRANT ㉡ 미부여 ㉢ DROP 백로그) | 운영계 · 🔴 사용자 결정 |
| ② | 1-B OWNERSHIP 이전 승인 여부 | 🔴 사용자 승인 |
| ③ | 배정표 「확정」 열 · 다역할 4명 사람/서비스 구분 · 보조 역할 영향 | 👤 사용자 |
| ④ | 팀장 역할 앱 USAGE 9문 = R97 Q03 앱 이름 목록 받은 뒤 작성 | 운영계 CSV |

## ▣ O271-A-3 ㉡ 워크스페이스 백로그

- 구 역할 GN_DW_ANALYST 회수 전 Streamlit 8개 소유자 이전 계획(예: GN_DW_APP_OWNER) — 🔴 이번 범위 밖.
- `rbac_source_gate.py` 창고 하드코딩 · `O270_apply_rbac_dev.py` 입력 경로 하드코딩 → 인자화 후보.
- 🔴 하지 마라 = 4뷰 이름 분류 GRANT · 운영계 뷰 DROP · 구 역할 회수 · 배정표 확정 열 대리 기입.

_Co-authored with CoCo_
