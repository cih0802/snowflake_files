<!-- LLM-METADATA
doc_id: HANDOFF_O0248_A
doc_role: 인수인계 — 세션 `O248-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-20
created_by: O248-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0248-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O248-A-0 🔴 먼저 알아라

- `O248-A` = 마케팅 광고비 인입경로 배분 · 회원 개발사건 코호트 신설 · 3 Agent 예측 가드레일 진단(2026-10-20 · trialadmin(iw20760) · ㉡ · 사용자 승인 · 확정위반 0).
- 🔴 세션 말 계정 정지(결제 수단) — 라이브 재조회 불가 상태로 종료 · build 결과는 사용자 보고(PASS=13 ERROR=0)만 근거다.
- 정본 근거 = `20_issue/01_세션이력` §O248 · 렌더 도구 `tmp/o248/render_check.py` · DDL 추출본 `tmp/o248/ddl_new2.sql`.

### ▣ O248-A-1 이번 단위 결과

| 항목 | 결과(IW20760) |
|---|---|
| `FACT_AD_INFLOW_ALLOC` | 신설 · 06_DDL + CREATE · 렌더 실측 배분 446.1억 + 미배분 110.4억 = 원천 556.4억 |
| `FACT_MEMBER_EVENT_COHORT` | 신설 · 06_DDL + CREATE · 17,442,802행 · M0 개발(건) = FME 1,467,783 |
| 테스트 | `assert_faia_ad_cost_preserved` · `assert_fmec_event_preserved` · schema yml 2 모델 |
| build | 👤 PASS=13 WARN=0 ERROR=0(사용자 보고) |
| 진단 | MKT 에 O193/O203 예측 절차 없음 · 구조문 3종 잔존 · 배분 뷰 개발구분 축 부재 |

### ▣ O248-A-2 ㉠ 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 계정 복구 후 두 팩트 행수 재조회(17,442,802 · 배분 합 556.4억) | 재측정 대기 |
| ② | `ML_DVLP_FORECAST_ALLOC_V` 에 ALLOC_AXIS = 개발구분(신규·증액·재후원) 추가 · SV_ML_DVLP_FORECAST 반영 | 에이전트 |
| ③ | SV 2종 신설 = `SV_AD_INFLOW_ALLOC`(MKT) · `SV_MEMBER_EVENT_COHORT`(MEMBER) · 도구 배선 | 에이전트 |
| ④ | 3 Agent 공통 예측 가드레일 교체(① ML → ② 비중 배분 → ③ 부서 수식 → ④ 추세 참고치) · 구조문 3종 삭제 · MKT `analyst_ml_dvlp_forecast` 설명 갱신 · 광고비÷CRM 금지 조문 → 배분 도구 라우팅 | 에이전트 |
| ⑤ | 재질의 = MKT Q13·Q14·인입경로 개발단가·Q19·Q21 · MEMBER 증액 상위 10 원문 + 신규→증액·개발 당일 알림톡·오픈 · `부서별agent답변.md` 반영 | 에이전트 |

### ▣ O248-A-3 ㉡ 워크스페이스 백로그

- 👤 VIDEO 허용 인입경로(영상광고·방송·콜개발·디지털) 현업 확인 — 확정 전 가정(SV COMMENT 명시 예정).
- 🟠 VIDEO 미배분 16.2억(24%) — 방송 효과 시차(익월 개발) 가능성 · 시차 배분 여부 결정 대상.
- O247 잔여(자기검토 보고서 · 운영계 체크리스트 · DMF 확인)는 그대로 승계 — 이 단위와 무관.

### ▣ O248-A-4 ⚪ 결정 완료(재론 금지)

- 광고비 인입경로 = 원천 구분자 1차 매핑 + 개발(건) 비중 배분(사용자 2026-10-20).
- 예측 = 기준값 1개 + 나머지 비중 배분 · 「없다·못한다」로 끝내지 않는다(사용자 2026-10-20).
- 개발사건 코호트 = 팩트 1개 · 개발구분은 필터 · 회원 Agent 전용(다른 Agent 요건 없음).
- 3 Agent 공통 조문 정리 범위 = 공통 조문만(도메인 조문 유지).

_Co-authored with CoCo_
