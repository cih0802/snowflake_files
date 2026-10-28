<!-- LLM-METADATA
doc_id: HANDOFF_O0265_C
doc_role: 인수인계 — 세션 `O265-C` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-28
created_by: O265-C
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0265-C -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O265-C-0 🔴 먼저 알아라

- `O265-C` = O265-B 후속(같은 날 2026-10-28 · TRIALADMIN · 개발계 ZS83821 · ㉡ 적용). O265-A·B 의 결과·근거는 그대로 유효하다.
- 🔴 **dbt build 는 아직 하지 않았다**(에이전트 미실행 원칙). A 재정의(O265-C)는 **코드 + 사전 DDL([D1-C]) 까지**만 라이브에 있다.
- 🔴 신규 테이블 3종(`SILVER.MAP_AT_GA_LINK` · `GOLD.FACT_AT_GA_LINK_MAP` · `GOLD.FACT_AT_GA_CLICK`)은 **빈 테이블**이다 · FMD `GA_CLICK_MAP_SRC` 는 전건 NULL.
- 🔴 라이브 `SV_SERVICE` 는 **O265-C 이전 정의**다(atclk 미배선) — build 후 05_04 를 재배포해야 바뀐다.
- 확정위반 3(유실 0): R1-7-2 ×2(FMD 병렬 edit 2 · 게이트 스크립트 병렬 edit 2 · 전건 반영 확인) · 🔴 FMD **꼬리 4줄 유실 사고**(edit 직후 `gift_attr`·`active_m` 조인·`where` 가 사라짐 · 해시 2회 동일 = 실유실) → 직전 read 원문으로 복원 · 줄 수 등식(315 + 9 = 324) 확인.

### ▣ O265-C-1 결과

| 영역 | 결과 | 정본 좌표 |
|---|---|---|
| 개발계 구축 22~59 | SV 28 · ML 뷰/SV 7 · 코퍼스 1 · Agent 생성·버전업 전건 OK(오류 0) · Agent 3 = VERSION$3 · CoWork 등록 3 · `agent_object_ref_gate` PASS | `문서실행순서.md` 개발계 22~59 |
| A 우선순위 | ① 질문 시 템플릿·링크 > ② 고정 매핑(seed MANUAL·WEB_TEAM + DIRECT) > ③ 추정(INFER) | `models/gold/fact/FACT_AT_GA_LINK_MAP.sql` 머리 주석 |
| ③ 추정 규칙 | 묶음 = 발송구분 대>소 · 전용성은 **창 없이**(창을 걸면 전용 링크도 15% · 실측) · ≥ 0.95 · ≥ 5명 | 같은 파일 · var `at_ga_infer_min_share`·`_members` |
| 사전 측정(렌더 실측) | 매핑 MANUAL 4 · DIRECT 2,500 · INFER 66 템플릿 · 클릭 108,107행 · 판정 가능 (발송,회원) 10,750 / 14,992 · A 8,236 · 행운의 카드 A 22 → 9(타 캠페인 혼입 제거) · B 22 | `45` [D2-2] 기대값 |
| FMD | A = 템플릿 패턴 일치 클릭 · 매핑 없음 NULL · 근거 열 `GA_CLICK_MAP_SRC` · A ⊆ B 유지 | `FACT_MESSAGE_DISPATCH.sql` ga_attr·ga_map |
| SV 05_04 | 표 atclk · 차원 7 · 지표 `AT_LINK_CLICK_MEMBERS_DISTINCT` · 규칙 (아)(자) · 임시 이름 컴파일 성공 후 DROP | `05_SV-Agent_ai/05_04_SV_DDL_SERVICE.sql` |
| 배포 | 45 [D1-C](개발계 실행 완료) · [D2-2] · 문서실행순서 기존 환경 갱신 **44번** | `45_DEPLOY_SEND_GBN_AT_OPEN.sql` |

### ▣ O265-C-2 ㉠ 이 작업의 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 👤 dbt 재배포 → `seed --select MAP_AT_GA_LINK` → `build --select MAP_AT_GA_LINK+` | 차단 요인 |
| ② | 45 [D2-2] 대사 → 기대값 대조 → 05_04 재배포 → Analyst 「행운의 카드 열람 A·B·중단」 재검증 | ① 후 |
| ③ | 현업 확인 = AT006038·AT006040 행운의 카드 여부 · 하위 페이지(child.gn) 포함 여부 · 웹팀 리다이렉트 대상표 요청 | 회신 대기 |
| ④ | 운영계 반영 = 문서실행순서 43·44 | ② 후 |
| ⑤ | 🟠 [D2] SND GA 합 사전 7,610 ↔ 실측 4,893 원인 규명 | 미착수 |

### ▣ O265-C-3 ㉡ 워크스페이스 백로그

- `00_BRIEF` 착수표 열린 항목은 이 세션에서 건드리지 않았다(범위 밖).

_Co-authored with CoCo_
