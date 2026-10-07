<!-- LLM-METADATA
doc_id: HANDOFF_O0205_B
doc_role: 인수인계 — 세션 `O205-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-07
created_by: O205-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0205-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O205-B 인수인계

### ▣ O205-B-0 🔴 먼저 알아라 (2026-10-07 · JU93656 · ㉡ 적용 · 확정위반 0)

- 🟢 라이브 배포 = SV_MEMBER_FEE(획득 8축) · SV_MEMBER_SERVICE_COHORT(신설) · AGENT_MEMBER VERSION$12(analyst_service_cohort).
- 🟢 재질문(VERSION$11) Q1 ⭕ · Q4 ⭕ · Q2·Q3 △ → VERSION$12 + 모델 교정(빌드 대기). 원문 = `tmp/o205_smoke/`.
- 🔴 캠페인행사 1970 날짜 = DW 결함(DIM_EVENT TEXT→DATE epoch 해석) · BRONZE 정상 · `DIM_EVENT.sql` 교정 완료(파일).
- 🔴 장기회원 2026 급감 = 제목 변경(「장기회원」 단어 없음) · 패턴 보강(파일) · 2026 수신 2,278 → 161,967.
- 🔴 중단 사건 행의 후원금액·가입일은 원천 구조상 NULL — D5 후원금액은 획득 시점 약정금액으로 답한다.

### ▣ O205-B-1 🟠 남은 작업

㉠ 이 작업의 잔여

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | 👤 dbt build | `dbt build --select DIM_EVENT+ WIDE_MEMBER_SERVICE_COHORT --project-dir /10_dbt_pipeline` |
| 2 | 검증 | FEA 캠페인행사 DATE_SK 1970 = 0 · 장기회원 2026 수신 161,967 · Q2·Q3 재질문(`tmp/o205_smoke.py`) |
| 3 | 문서 | `python3 scripts/build_wide_doc.py` → test_verify_wide_doc 복구 |
| 4 | 👤 현업 확인 | ① 서비스명 ↔ 제목·서비스코드(MS0505/0201) 규칙 ② 문화이벤트 = 캠페인행사? ③ 효과 대조군 ④ 장기회원 제목 법인 표기 |

㉡ 워크스페이스 백로그

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 9 | ㉡ 👤 MSTR 일일 적재 | ⏸ 현업 회신 대기 |
| — | 기존 게이트 FAIL 3 | sv_rule7(05_15·05_17) · agent_tool_claim(681,134 등) · test_generators 골든 4 — 규명 전 골든 갱신 금지 |

### ▣ O205-B-2 ⚪ 결정 완료(재론 금지)

- 서비스 코호트는 수신 행만 수신 분석 모수다(SV 규칙 (8)).
- 장기회원 「(사단)」은 제목 법인 축이 없어 서비스그룹 전체로 답한다(획득 법인구분으로 대체 금지).

_Co-authored with CoCo_
