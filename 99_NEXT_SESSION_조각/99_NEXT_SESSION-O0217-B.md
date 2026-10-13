<!-- LLM-METADATA
doc_id: HANDOFF_O0217_B
doc_role: 인수인계 — 세션 `O217-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-13
created_by: O217-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0217-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O217-B 인수인계 (10차 마감 · 새 개발계 ua91864 재현 · 증액 ML × 마케팅캠페인 · 2026-10-13)

### ▣ O217-B-0 🔴 먼저 알아라

- 개발계가 **ua91864** 로 바뀌었다. jw08094(O217-A)·CK24285(O216) 수치는 이 계정 수치가 아니다.
- ㉡ 적용 · 승인 = 사용자 「승인이 필요한 작업은 전부 승인」 · 확정위반 1(▣ O217-B-2 ①).
- 원장 §1 O217 행 등재 ✅ · `01_세션이력-086.md` O217-B 항목 ✅ (O217-A ①② 해소).

### ▣ O217-B-1 라이브 반영 (ua91864 · 2026-10-13 · 재조회 확인)

| 객체 | 결과 | 롤백 |
|---|---|---|
| `GN_DW.SERVING.BIZ_DEFINITION_CORPUS` | 2,145행(라우팅 16 · RT-19 신설) | DROP |
| `GN_DW.SERVING.SEARCH_BIZ_DEFINITION` | 증액 질의 → RT-19 · LTV → RT-14 1순위 · USAGE 3롤 | DROP |
| `GN_DW.SERVING.ML_INC_BY_MKTG_CMPGN_V` · `SV_ML_INC_CAMPAIGN` | 202609 = 예측 70,158 · 귀속 28,324 · 정본 `05_SV-Agent_ai/23_ML_INC_MKTG_CMPGN_DDL.sql` | DROP |
| `AGENT_MARKETING` | VERSION$4 (도구 24 · spec `19_O217B_AGENT_MARKETING_spec.yaml`) | VERSION$3 |
| `AGENT_MEMBER` · `AGENT_EXECUTIVE` | VERSION$4 (도구 23 · 13 · spec `17_O217_*`) | VERSION$3 |

- 운영계 재현 = `12_agent개선과제/18_O217_운영계_재현_런북.md` (개발계에서 순서대로 실증).
- 측정 = `12_agent개선과제/output/o217b/00_O217B_전후비교.md`.

### ▣ O217-B-2 🟠 ㉠ 이 작업의 잔여

- ① 🔴 `split_doc.py --rebalance --dry-run` 이 파일을 실제로 쓴다(이 세션 실증 · 조각 18 재기록 · 유실 0) — 도구 결함 시정 + 음성 테스트.
- ② 「① 핵심 요약」 2회 출력(QM4 · F01) — response 규칙이 있는데 재현.
- ③ 사용자 결정: Q19 실적 LTV 표 기본 동반 · F23 원천 간 계산 허용 범위 · ML 경량 모델 도입 여부.
- ④ F06 DVLP_INC 「증액」 오표기 · F17 채널 코드 라벨 · F16 공통 특성 · F22 재측정(CLI 타임아웃).
- ⑤ 회원실 1·2·7·8 = AGENT_MEMBER 측정(미측정).
- ⑥ 지침 길이 축약(채팅 지적 「지침이 너무 많아 충돌」) — 이번에는 새 규칙을 코퍼스로 보내고 지침에 1문단만 더했다.
- ⑦ 음성 테스트 49종 중 `scripts/test_o125_layer_census.py` rc=1 — 옛 파일명 `05_1_SV_DDL_MEMBER_MONTHLY.sql` 참조(FileNotFoundError · 기존 결함 · O217-B 변경과 무관).

### ▣ O217-B-3 🟡 ㉡ 워크스페이스 백로그

- 전체 목록 = `12_agent개선과제/20_O21X_잔여작업_정리.md` (28건 · 열림 15 · 결정 5 · 회신 2 · 운영계 2 · 닫힘 4).
- 다음 세션 착수 프롬프트 = `12_agent개선과제/21_다음세션_착수프롬프트_O218.md`.

### ▣ O217-B-4 ⚪ 결정 완료(재론 금지)

- 증액 예측 캠페인 귀속 = 기준월이 속한 해 1월~기준월 MSTR 개발(신규·증액·재후원) 최근 1건의 마케팅캠페인.
- 캠페인 비교 지표 = 기대 증액 회원수(증액확률 합) · 모델 분류(0.5)는 4명뿐이라 비교에 쓰지 않는다.
- E·A~D = `14_O217_작업계획.md` §0.

_Co-authored with CoCo_
