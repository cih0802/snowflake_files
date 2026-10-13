<!-- LLM-METADATA
doc_id: HANDOFF_O0217_A
doc_role: 인수인계 — 세션 `O217-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-13
created_by: O217-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0217-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O217-A 인수인계 (비즈니스 정의 Cortex Search 신설 · Agent 3종 배선 · 마케팅 피드백_2 반영 · 2026-10-13 · jw08094)

### ▣ O217-A-0 🔴 먼저 알아라 (㉡ 적용 · 승인 = 사용자 「1~4 전부 승인」 · 확정위반 1)

- 🔴 확정위반 1 = 전후 비교표 「전」 칸 2곳을 원문 독해 전에 적었다(R1-3-7-c) → 독해 후 같은 턴 정정(`output/o217_eval/00_O217_전후비교.md`).
- 🔴 **원장 §1 O217 행 미등재** — `00_INDEX_이슈원장-002.md` 여유 8 B.
  · 승인받은 은퇴(`retire_rows` O200-C~O203)는 dry-run 절감 **150 B**(셀만 이관 · 행 키 보존 방식)라 부족 ⇒ 미실행.
  · 대안 = `split_doc.py 20_issue/00_INDEX_이슈원장.md --rebalance` dry-run 🟢 PASS(18조각 재기록 · 유실 0 · 최소 여유 12,543 B) — **별도 승인 대기**.
- 🔴 `01_세션이력` 항목 미작성 — `--rollover` 가 R4-4-3 승인 대상이라 보류. 이 파일이 O217 의 유일한 기록이다.
- 계정 축 주의 = 원장의 「Agent 3종 VERSION$7」은 CK24285 기준이다. jw08094 라이브는 아래 버전이다.

### ▣ O217-A-1 라이브 반영 (jw08094 · 2026-10-13 · 재조회 확인)

| 객체 | 결과 | 롤백 |
|---|---|---|
| `GN_DW.SERVING.BIZ_DEFINITION_CORPUS` | 2,144행(라우팅 15 · 지표 236 · 용어 517 · 조직 222 · 원천참고 1,154) | DROP |
| `GN_DW.SERVING.SEARCH_BIZ_DEFINITION` | 원천참고 제외 · 11문항 1순위 적중 · USAGE → ANALYST·VIEWER·SERVICE | DROP |
| `SV_AD` | `GA_DEV_CNT` 추가(정본 `05_SV-Agent_ai/05_7_SV_DDL_AD.sql` · 배포 전 라이브 대조 = 차이 0 · VQR 3 보존) | 정본에서 metric 2줄 삭제 후 재배포 |
| `AGENT_MARKETING` | VERSION$5 (도구 23 · search + 회원실 예측 2종 · 결정 A~D · LTV 산식 정정) | VERSION$3 |
| `AGENT_MEMBER` · `AGENT_EXECUTIVE` | VERSION$4 (search 도구 + 정의 조회 1문단) | VERSION$3 |

- 생성기(재실행 안전) = `12_agent개선과제/tools/build_biz_definition_corpus.py [--apply]` · `o217_patch_marketing_spec.py` · `o217_patch_search_tool.py`.
- 사용자 결정 A~D 정본 = `12_agent개선과제/14_O217_작업계획.md` §0 · 코퍼스 `RT-01`~`RT-13`.

### ▣ O217-A-2 🟠 ㉠ 이 작업의 잔여

- ① 원장 재균형 승인 → O217 행 등재 · ② 세션이력 롤오버 승인 → 항목 작성.
- ③ Q19 — 실적 LTV(평균 월 납입회비 × 평균 유지개월수) 표를 기본으로 함께 낼지 결정 필요(현재 제안만).
- ④ 중간 메시지 영어 1문장 잔존(Q19 「I'll check …」).
- ⑤ 피드백_2 나머지 문항(나눔마케팅 1·2·4·6·16·17·22·23 · 회원실 1·2·7·8)은 미측정.
- ⑥ 지표사전 공통 #147 「공통캠페인」은 사용자 결정 C(오타 = 공통브랜드)와 별개 개념 — 코퍼스에 따로 둔다.

### ▣ O217-A-3 🟡 ㉡ 이월 (O216-G 착수표 그대로)

- 전건 NULL 컬럼 검출 → 등록부 적재 → 사유 판정 → COMMENT → 게이트(`99_NEXT_SESSION-O0216-G.md:44`~`48`).
- 08_mornitoring 05~07 배포 · 운영계 반영(보류).

### ▣ O217-A-4 ⚪ 결정 완료(재론 금지)

- E. 지표 정의는 테이블 → Cortex Search 로 두고 Agent 3종에 배선한다(사용자 2026-10-13).
- A~D = `14_O217_작업계획.md` §0.

_Co-authored with CoCo_
