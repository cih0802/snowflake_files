<!-- LLM-METADATA
doc_id: HANDOFF_O0218_A
doc_role: 인수인계 — 세션 `O218-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-13
created_by: O218-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0218-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O218-A 인수인계 (11차 Agent 개선 · 지침 축약 및 코퍼스 이관 · 결함 해소 · 2026-10-13)

### ▣ O218-A-0 🔴 먼저 알아라

- 개발계는 **ua91864** 이다.
- 11차 Agent 개선 완료 (마케팅 Agent 지침 축약/코퍼스 이관, 2회 출력 결함 시정, 피드백_2 잔여 실측 완료).
- 코퍼스 2,154행 적재 및 CORTEX SEARCH SERVICE(SEARCH_BIZ_DEFINITION) 최신화 완료.

### ▣ O218-A-1 라이브 반영 (ua91864 · 2026-10-13 · 재조회 확인)

| 객체 | 결과 | 롤백 |
|---|---|---|
| `GN_DW.SERVING.BIZ_DEFINITION_CORPUS` | 2,154행 (RT-20~28 추가) | TRUNCATE & COPY |
| `GN_DW.SERVING.SEARCH_BIZ_DEFINITION` | RT-20~28 검색 지원 | CREATE OR REPLACE |
| `AGENT_MARKETING` | VERSION$4 (도구 24 · 1회 출력 규칙 및 지침 축약 정본) | VERSION$3 |

### ▣ O218-A-2 🟠 ㉠ 이 작업의 성과 및 잔여

- ① `split_doc.py --rebalance --dry-run` 무쓰기 보장 결함 수정 및 `test_split_doc_dryrun.py` 음성 테스트 통과.
- ② 마케팅 Agent 「① 핵심 요약」 2회 출력 결함 해소 (QM4, F01 단 1회 출력 실증).
- ③ 지침 축약 및 코퍼스 이관 (RT-20~28 코퍼스 편입으로 지침 간소화).
- ④ 사용자 결정 3종 반영 (Q19 실적 LTV 기본 동반, F23 사용자 산식 지정 시 사후계산 허용, ML 모델 추세 표현 정리).
- ⑤ 피드백_2 잔여 문항(F06, F16, F17, F22) 및 회원실 1·2·7·8(AGENT_MEMBER) 실측 완료 (rc=0).

### ▣ O218-A-3 🟡 ㉡ 워크스페이스 백로그

- 전체 목록 = `12_agent개선과제/20_O21X_잔여작업_정리.md`.
- 차기 권장 = NULL 사유 등록부 및 COMMENT 반영, 종료 게이트에 Agent/Eval/SV 게이트 5종 편입, 10/11차 운영계 배포 런북 점검.

### ▣ O218-A-4 ⚪ 결정 완료(재론 금지)

- LTV 질문 시 ML 예측 표와 실적 LTV 표를 기본 동시 분리 제시 (RT-27).
- 원천 간 결합 계산은 사용자 산식 지정 시 각 도구 결과로 사후 계산 허용 (RT-28).

_Co-authored with CoCo_
