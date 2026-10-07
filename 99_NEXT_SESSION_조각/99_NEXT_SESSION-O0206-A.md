<!-- LLM-METADATA
doc_id: HANDOFF_O0206_A
doc_role: 인수인계 — 세션 `O206-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-07
created_by: O206-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0206-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
## O206-A 인수인계

### ▣ O206-A-0 🔴 먼저 알아라 (2026-10-07 · JU93656 · ㉡ 적용 · 확정위반 1 = R1-7-2 병렬 edit 4회 · 유실 0)

- 🟢 **표 헤더 한글 강제(전 Agent)** = 3중 — ① SV 28종 `AI_SQL_GENERATION` 머리에 `[O206 출력 규칙]`(큰따옴표 한글 별칭 · 동의어 첫 항목 + 단위) ② Agent orchestration `[O206 · O201-B 개정]`(종전 「영문 별칭만」 규칙 폐기) ③ response `[O206 표 헤더 한글 강제]` + `[O206-B 차트]`.
- 🟢 라이브 = SV 28/28 규칙 실재(DESCRIBE 대조) · AGENT_EXECUTIVE VERSION$5 · AGENT_MARKETING VERSION$5 · AGENT_MSTR VERSION$6 · AGENT_MEMBER VERSION$4(1차 규칙만 · A안 미반영).
- 🟢 스모크 = `tmp/o206_smoke/`·`tmp/o206_smoke_b/` · 판정기 `tmp/o206_judge.py`(table 블록 rowType · chart field/title) · 표 헤더 10/10 한글 · 차트 `Value` 1건은 O206-B 로 해소.
- 🔴 이 계정의 Agent 버전 번호는 O205-C 기재($14·$9)와 다르다 — 판정은 SHOW VERSIONS 로 한다.
- 🟢 **N-27 처리(사용자 지시 · 회신 대기 해제)** = 근거 `20_issue/_o206_evidence.md` · 문서20 N-27 결과표.
- 🟢 샘플 개발계를 운영계처럼 간주하고 개발한다(사용자 결정 · 차이 = ML 회원 PK 1행 · bigquery_refined_data 1일 단위 전량 적재 · 그 외 자잘한 차이 미명시).

### ▣ O206-A-1 🟠 남은 작업

㉠ 이 작업의 잔여

| 순 | 작업 | 다음 행동 |
|---|---|---|
| ~~1~~ | ~~👤 dbt build `WIDE_MEMBER_SERVICE_COHORT` (A안 · 코드 우선 → 제목)~~ ➔ 🟢 [O206-B] 사용자 build PASS=1 | 🔴 다시 실행하지 마라 — 완료 |
| ~~2~~ | ~~build 후 SV 05_18 배포 · AGENT_MEMBER 발행~~ ➔ 🟢 [O206-B] 05_18 배포 · AGENT_MEMBER VERSION$5 · Q1~Q4 ⭕ | 🔴 다시 실행하지 마라 — 완료 |
| ~~3~~ | ~~build 후 산출물 재생성~~ ➔ 🟢 [O206-B] 04~09 재생성 · 골든 재발행(신규 WIDE 컬럼은 11개가 아니라 **9개**) · 06 만 실패(O206-B ㉠-3) | 🔴 다시 실행하지 마라 — 완료 |

㉡ 워크스페이스 백로그

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 9 | ~~㉡ 👤 MSTR 일일 적재~~ ➔ O206-E 이관 | ⏸ 현업 회신 대기(MSTR 스키마 테스트 중 · 2024-01~ 최신 적재 완료) |

### ▣ O206-A-2 ⚪ 결정 완료(재론 금지)

- 서비스그룹 = **A안**(4그룹 유지 · 판정 순서 코드 → 제목 · MATCH_BASIS 고지).
- 서비스 법인은 grain 에 넣지 않는다 — 법인별 수신 플래그 3개(평균 지표 중복 가중 방지).
- 서비스 법인 = 서비스코드명의 법인 표기 → 템플릿 CPR_DIV_CD · 담당부서 = 템플릿 CHRG_DEPT_ID.
- SV_SERVICE 는 서비스 카테고리 축을 신설하지 않는다(규칙으로 제목 매핑 고지) — GOLD 신규 모델 파급 회피.
- 「O205-C-2 장기회원 (사단) 한계 고지」 결정은 원천 법인 경로 발견으로 대체됐다(획득 법인구분 대체 금지는 유지).

_Co-authored with CoCo_
