<!-- LLM-METADATA
doc_id: HANDOFF_O0237_A
doc_role: 인수인계 — 세션 `O237-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-16
created_by: O237-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0237-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O237-A-0 🔴 먼저 알아라

- 작성 = ua91864 · 2026-10-16 · ㉡ 적용(사용자 지시 동봉). 라이브 SERVING·Agent·코퍼스는 **아직 무변경**이다(배포 = 👤 승인 대상 · R4-4-3).
- 🔴 LLM 매핑표 정본 = `12_agent개선과제/tools/O237_formula_wiring_overlay.csv` — 손으로 고치지 말고 `tools/o237_build_formula_map.py` 를 고쳐 재생성한다(`--check` = 라이브 필드 실재 대조).
- 🔴 사람이 보는 문서는 **대응 100% 후** 작성한다(사용자 결정) — 이번 단위에서 만들지 않았다.
- 확정위반 1 = 배경 셸 `>>` append(마운트 미지원 · rc 기록만 유실 · 게이트 결론은 개별 출력 파일로 확인).

### ▣ O237-A-1 이번 단위 결과

| 순 | 결과 |
|---|---|
| ① 매핑 | 산식 146건 전건 = C1 52 · C2 15 · C3 8 · C4 19 · C5 18 · G1 31 · G2 3 · 도구 배선 12 → 115 |
| ② SV | metric +12(05_01 6 · 05_09 1 · 05_19 1 · 05_24 1 · 05_04 3) · 납부율의 동의어 '납입률'(05_01)·'납입율'(05_09) 제거(공62 납입율 분리) |
| ③ 사전 검증 | GN_DW.OPS probe SV 5종 컴파일 OK · 202609 값 = GOLD 직접 계산과 일치(누계납입율 1~9월 96.3905) · probe 5종 DROP 완료 |
| ④ 코퍼스·Agent | 생성기 오버레이 + 열 COVERAGE·ANSWER_GUIDE(26 DDL · Search ATTRIBUTES) · 2,156행 유지 · 변경 행 = 산식 146 · Agent 3종 검색 열 +4 · [O237 산식 대응] 규칙 1 |
| ⑤ 게이트 | sv_identifier · sv_unit · sv_code_label · sv_comment_object · sv_rule7(시정 후 0) · agent_tool_claim · agent_object_ref · agent_source_lineage · eval_expectation · null_reason · line_len = PASS |

### ▣ O237-A-2 ㉠ 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ~~①~~ | ~~👤 `05_SV-Agent_ai/27_O237_산식대응_배포순서.sql` [1] SV 5종 → [2] 26 코퍼스 → [3] 09_2 → [4] 검증 → [5] 스모크 4문항~~ ➔ 🟢 [O237-C] 라이브 확인 완료(ua91864 · metric 12 · 코퍼스 146 · 스모크 통과) | 배포 |
| ~~②~~ | ~~G1 31건 해소 = 캠페인 월 팩트(후원건 캠페인 귀속 · 활동·전월말활동·당월중단·개발·이탈·납입·미납·납입방식) 신설 → SV 확장 (G1 캠페인 17)~~ ➔ 🟢 [O237-B] FACT_CAMPAIGN_MONTHLY · SV_CAMPAIGN_MONTHLY(라이브 대사 BAD 0) | dbt |
| ~~③~~ | ~~G1 서비스 코호트 확장 = D5 서신·선물금 참여 플래그 · 참여 후 N개월 유지 · 납입 연결 (G1 서비스 11)~~ ➔ 🟢 [O237-B] WIDE_MEMBER_SERVICE_COHORT +6열 · SV 05_18(라이브) | dbt |
| ~~④~~ | ~~G1 개별 3 = 최종캠페인 차원 · 결연아동코드(URL 파싱) · 후원사업별 미납율 grain · 미납서비스·클릭 전환 매칭~~ ➔ 🟡 [O237-C] 3건 작성(28_O237C 배포 대기) · 잔여 2 = O237-C-2 ③ | dbt |
| ~~⑤~~ | ~~현업 확인 = 공6 GA 광고비 산식 문구 · 공166 단위(건/명) · 신규6 이탈율 문구 · 발송 성공 코드(EMAIL·SND) · 서비스 참여율 분모~~ ➔ [O237-C] O237-C-2 ⑤ 로 흡수 | 현업 |
| ⑥ | 100% 대응 후 사람용 지표-SV 대응 문서 작성 | 문서 |

㉡ 워크스페이스 백로그 = O236-B ①(Agent 스모크) ②(현업 8.88%) 승계.

### ▣ O237-A-4 ⚪ 결정 완료(재론 금지)

- 매핑표 = LLM 소비용(사용자) · COVERAGE 7종 코드 정의 = `o237_build_formula_map.py` 머리말.
- G1 은 근사하지 않는다 — 「현재 산출 불가 — 모델 추가 예정」 + 대체 지표 제시.
- 공49 연도초활동 = SV_CAMPAIGN_CUM_STOP(FMM 월 행 값은 월마다 달라 쓰지 않음 · 202609 = 1,412,377 vs 1,535,149).

_Co-authored with CoCo_
