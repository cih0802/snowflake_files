<!-- LLM-METADATA
doc_id: HANDOFF_O0237_D
doc_role: 인수인계 — 세션 `O237-D` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-16
created_by: O237-D
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0237-D -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O237-D-0 🔴 먼저 알아라

- 작성 = ua91864 · 2026-10-16 · ㉡ · 사용자 승인 = 「dbt 실행 권한도 승인 · 니가 다 해」. GA 백필은 사용자가 먼저 실행했다.
- O237 은 🟢 로 닫혔다 — A·B·C 배포·대사·스모크가 라이브에서 전부 통과했다.
- Agent 기본 버전 = MEMBER VERSION$6 · MARKETING VERSION$5 · EXECUTIVE VERSION$5(롤백 = 각 VERSION$4).
- dbt 프로젝트 기본 버전 = `O237C_20261016_B`(워크스페이스 정본에서 배포).

### ▣ O237-D-1 이번 단위 결과

| 순 | 결과 |
|---|---|
| ① 집행 | FSM 생성(소유 GN_DW_ADMIN · grant 형제와 동일) · FK · 열 3 ALTER · build(1차 accepted_values 실패 → yml·06_DDL·라이브 COMMENT 에 `UPPER_CODE` 추가 → 재 build PASS) |
| ② 대사 | FSM 465개월 BAD 0 · 중복 0 · LAST_CAMPAIGN 1,621,462 · 클릭 126,799/377/1,839 · 영상 UPPER_CODE 3,406행 · 미매핑 5,924,770,020원 |
| ③ 배포 | SV 5종(`deploy_sv.py --apply`) · 코퍼스 [1]~[6] 재적재(146 = C1 65·C2 17·C3 8·C4 20·C5 31·G1 2·G2 3) |
| ④ 스모크 | ② 후원사업별 미납율 1차 실패(청구 대비 미납율로 답함) → 규칙 추가 → 15.70% 통과 · ① 최종캠페인 1차 실패(대표캠페인 축) → 규칙 추가 → LAST_CAMPAIGN_NAME 통과 · ③ 클릭 5일 0.30%·30일 1.45% · 특집 = 방송 14,801,599,992원 |

### ▣ O237-D-2 ㉠ 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | G1 2 설계 = 결연아동코드(GA PAGE_LOCATION childnum 파싱 · 원천 196,282행) · 미납서비스 전환(GA 미납 페이지 클릭 → 납입) | dbt |
| ② | O238 W3 나머지(L1 미매칭 4값 · L3 UTM 미매칭 33값 · L2 GOLD 결합 확인) · W5 영상 이름형 · W6 재송출 코드 입고 | 현업·dbt |
| ③ | 현업 확인 = 최종캠페인 정의 · 클릭 전환 창 · 납입방식 잠정 축 · 수신 후 납입 창 · 공6·공166·신규6 · 발송 성공 코드 · 서비스 참여율 분모 | 현업 |

㉡ 워크스페이스 백로그 = `sv_unit_gate` O237-A metric 3 예외 등재 판단 · 기존 실패 테스트 3(test_generators 측정일 · test_gold_erd FACT_MEMBER_COHORT · test_verify_wide_doc 환경 경고) · `문서실행순서.md` 에 05_24·05_25 누락.

### ▣ O237-D-4 ⚪ 결정 완료(재론 금지)

- 공79 = analyst_member_sponsor_biz SPONSORSHIP_UNPAID_RATE(청구 대비 미납율로 대체 금지) · 공31 = analyst_member_monthly LAST_CAMPAIGN_NAME.

_Co-authored with CoCo_
