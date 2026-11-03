<!-- LLM-METADATA
doc_id: HANDOFF_O0200_A
doc_role: 인수인계 — 세션 `O200-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-02
created_by: O200-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0200-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O200-A-0 🔴 먼저 알아라 (2026-10-02 · pw69582 · ㉡ 적용 · 확정위반 0)

- 🟢 SILVER 회원실 집계 3종 적재 확인 = 96 · 924 · 495행 · grain 중복 0 · 키 NULL 0.
- 🟢 GOLD dbt 뷰 3종 build 완료(사용자 · 2026-10-02 16:12 생성) · 라이브 실측 = 576 · 924 · 495행 · grain 중복 0 · 컬럼 COMMENT 8/8 · 32/32 · 10/10.
  · `WIDE_DVLP_GOAL_ACMSLT` = M01~M12 언피벗 · 목표/실적 열 분리(예상 576행).
  · `WIDE_MBRFEE_PRDT_ACTL` = 예측/실측 행 유지 + `IS_FORECAST` · 율 컬럼 [비가산] 표기.
  · `WIDE_SPNSR_CLS_AGGR` = VALUE1·VALUE2 잠정 COMMENT 「후원분류집계 예측값1/2」.
- 🟢 O199-A 임시 스크립트 3 삭제 완료.

### ▣ O200-A-1 🟠 남은 작업

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | 🟢 ~~dbt build · build 후 실측~~ | 완료(▣0 참조) |
| 2 | SV 신설 | `SERVING.SV_*` 3종(grain 상이 ⇒ 분리 기본안) · 도구 설명에 「부서 자체 수식 · ML 아님」·「예측/실측 합산 금지」 |
| 3 | Agent 도구 추가 | 소관 Agent 결정(사용자 · MEMBER 유력) → 스펙 수정 → `09_2` 버전업 → CoWork 스모크 2~3문항 |
| 4 | 현업 확인 | VALUE1·VALUE2 집계 유형별 의미 → COMMENT 확정(문서20 등재 후보) |
| 5 | O199-A 승계 | ▣O199-A-1 1~5 · ▣O199-A-2 3~6(MSTR 재배포·07 C_CONSUMER·LOADER·현업 회신) 그대로 |

### ▣ O200-A-2 ⚪ 결정 완료(재론 금지)

- SILVER 3종 = GOLD(ML 아님) · dbt view(`gn_view_commented`) · VALUE1/2 잠정 문안.

_Co-authored with CoCo_
