<!-- LLM-METADATA
doc_id: HANDOFF_O0191_C
doc_role: 인수인계 — 세션 `O191-C` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-30
created_by: O191-C
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0191-C -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O191-C-0 🔴 먼저 알아라 (2026-09-30 · bt97381)

- 사용자 승인 = 순1~11(과금·권한 포함) · 순12 는 다음 프롬프트. 정본 결정 = **DEC-57**(`30_설계` -017).
- 🔴 `GN_DW.ML` 권한 방침이 **바뀌었다** — ANALYST 에 USAGE·SELECT(ALL·FUTURE) 부여(종전 「권한 없음」은 취소선).
- 🔴 자기적발 = 이 세션이 넣은 VQR 3건이 **물리 컬럼명**(org.DEPARTMENT·fme.*_AT_EVENT·fee.SPONSORSHIP_NAME)을 써서 Agent 가 따라 틀렸다(스모크 1차 6건) · FEE 규칙에 「fee.SPONSORSHIP 은 없다」를 **거꾸로** 적었다 ⇒ 논리 차원명으로 정정 후 재스모크 PASS.

### ▣ O191-C-1 🟢 이 단위가 끝낸 것

- SV 6종 배포(EVENT·COHORT·SERVICE·BUDGET·AD·ML_ONCE) · ANALYST 조회 실증.
- 조직 코드 축(41.3) · 직접모금비1·2(42) · 11개 폐기(43) · 오픈=링크 클릭(44) · ML 최신행 불가 명시+요청(45) · 전년 동월 VQR(46) · ML 권한(추1) · 법인 동의어+VQR(추2 = 매체운영팀 사단 2026-07 60명·72건) · 카테고리 중단 VQR(추3).
- 문서20 F-1·F-2·F-3 판정 정정 + 허브 재발행 · 요청서 `45_` ML 실행순번 요청.
- Agent 3종 stale 9곳 정정 · MEMBER V5 · EXECUTIVE V5 · MARKETING V6(default).
- 스모크 39문항 = 최종 실패 0 · 중간 오류 **2**(기준선 3 → 2 갱신).

### ▣ O191-C-2 🟠 남은 작업

㉠ 이 작업의 잔여

| 순 | 작업 | 남은 이유 | 다음 행동 |
|---|---|---|---|
| 1 | ML 일시전환 최신행 | 원천에 실행순번 부재(창작 금지) | ML 담당 회신(`45_`) → SERVING 뷰 최신 1행 |
| 2 | 스모크 잔여 2 | 같은 물리명 패턴(`__ad.MARKETING_CAMPAIGN` · `__fme.PARENT_CAMPAIGN_NAME`) | SV_AD·EVENT 규칙에 논리명 목록 추가 |
| 3 | 44 오픈 ML 공유 | 사용자 전달 | 「오픈 = 링크 클릭 · SND 전용」 |

㉡ 워크스페이스 백로그(순12) = `SV_AD.CREATIVE_TYPE` 종수 4→5 · `test_o125` 하드코딩 · 2차-B 2단 32 · 문서02 · 산출물 03~09.

_Co-authored with CoCo_
