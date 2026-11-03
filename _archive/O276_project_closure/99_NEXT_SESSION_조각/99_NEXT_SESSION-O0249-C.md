<!-- LLM-METADATA
doc_id: HANDOFF_O0249_C
doc_role: 인수인계 — 세션 `O249-C` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-20
created_by: O249-C
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0249-C -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O249-C-0 🔴 먼저 알아라

- `O249-C` = O249 세션 마감(2026-10-20 · TRIALADMIN(SR61467) · ㉡ · 확정위반 1 = DIM_SEND_REQUEST 센티넬을 compile 로만 검증 → 런타임 100038 실패).
- 👤 사용자 dim 3종 build 결과(쿼리 `01c7ddae-0208-f4ee-0005-869e000effa2`) = DIM_MSG_TEMPLATE·BUTTON 🟢(고아 0) · DIM_SEND_REQUEST 🔴 `Numeric value '(미매핑)'`.
- 원인 = `SNDNG_KEY` 가 NUMBER ⇒ 센티넬 키 `0` 으로 시정(원천에 0 없음 · 실행 검증 통과). 🔴 다음 세션 첫 작업 = 재배포 + build.

### ▣ O249-C-1 이번 단위 결과

| 항목 | 결과 |
|---|---|
| dim 시정 | `DIM_SEND_REQUEST.sql` 센티넬 `select 0, 0, '(미매핑)', …` · 라이브 타입 UNION 실행 검증 1행 |
| 세션 종료 | doc_census stale 0 · 92 재생성 0항목 · decision_closure 경고 = 기존분(O249·O246-E 0) |
| 음성 테스트 | 59종 중 재실행 후 FAIL 1(`test_mutating_tool_safety` = `n01_dmf_apply` 무플래그 MUTATES · O247-B 기존) · `test_o178_axis_probe` rc=2(인자 필수 · 규약상 FAIL 아님) |

### ▣ O249-C-2 ㉠ 잔여(이 작업)

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 👤 `dbt_build.sql` 그대로 재실행(ADD VERSION → `build --select DIM_SEND_REQUEST`) → `SEND_REQUEST_SK=0` 1행 · FACT_MESSAGE_DISPATCH 고아 3,001 → 0 확인 | 👤 사용자(R4-1) → 에이전트 확인 |
| ② | 80 패키지 옛 사본 `01_실행순서_배포SQL/dbt_build_fact_ad_performance_budget.sql` 삭제 여부 | 👤 승인(R1-7-7) |
| ③ | ① 후 `build_handoff.py --apply` 재실행(DIM_SEND_REQUEST 수정본 반영) | 에이전트 |

### ▣ O249-C-3 ㉡ 워크스페이스 백로그

- `scripts/n01_dmf_apply.py` 에 `--dry-run`(기본) 플래그 추가 → `test_mutating_tool_safety` 복구(DMF 적용 결정과 무관하게 도구 안전성).
- 후속 작업자 결정 = DMF 적용(N01 §6) · A3 [2] 롤 동기화 채택.
- 현업 = 미연결 캠페인 1,608건(`12_agent개선과제/output/O249_…csv`) · VIDEO 허용 인입경로 · SND 결과 라벨(문서20 기등재) · 공11·공147·W5·W6.
- 운영계 이관 = `문서실행순서.md` 「기존 환경 갱신」 20~25 + 체크리스트 ⑤(DMF 제외).

### ▣ O249-C-4 ⚪ 결정 완료(재론 금지)

- O249-A·B 결정 그대로(LTV 상한 계산형 · 예측 가드레일 순서 · ML 테이블 증가 없음 · DMF 후속 결정 · CoCo ㉡ 생략).
- unknown 센티넬은 키 타입을 따른다(NUMBER = 0 · 문자 = '(미매핑)').

_Co-authored with CoCo_
