<!-- LLM-METADATA
doc_id: HANDOFF_O0249_A
doc_role: 인수인계 — 세션 `O249-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-20
created_by: O249-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0249-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O249-A-0 🔴 먼저 알아라

- `O249-A` = LTV 상한 계산형 전환 · O248-A ②~⑤ 집행 · CoCo 차단 테스트 적용(2026-10-20 · TRIALADMIN(SR61467) · ㉡ · 사용자 승인 전부 · 확정위반 1 = 같은 파일 edit 병렬 · 유실 0).
- 상한 80 = 현업 상수였다 ⇒ `CEIL(AVG(관측 중 회원 유지개월))`(현재 80) · 컬럼 `LTV_CAP_AVG_ACTIVE_MONTHS` · 🔴 데이터가 쌓이면 81 등으로 움직인다.
- 정본 근거 = `20_issue/01_세션이력` §O249 · 스크립트 `tmp/o249/`.

### ▣ O249-A-1 이번 단위 결과

| 항목 | 결과(SR61467 · 라이브 확인) |
|---|---|
| LTV 상한 | 라이브 RENAME · SV_MEMBER_COHORT 재배포(80 → 52.7438 · 9999 → 130.3604) · 코퍼스 3행 · MKT spec |
| ② 배분 | ML_DVLP_FORECAST_ALLOC_V 개발구분 축 · SV_ML_DVLP_FORECAST · VQR 단위 별칭 시정 |
| ③ SV | SV_AD_INFLOW_ALLOC · SV_MEMBER_EVENT_COHORT(`05_SV-Agent_ai/35_O249_…sql`) |
| ④ Agent | 공통 가드레일 · 도구 2 배선 ⇒ EXEC $4 · MKT $5 · MEM $4(롤백 $3 · $4 · $3) |
| ⑤ 스모크 | 5/5 새 도구 라우팅 |
| A3 | GN_ANALYST_01 CoCo 한도 3종 = 0(USER) |

### ▣ O249-A-2 ㉠ 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ~~①~~ | ~~👤 dbt build `--select FACT_MEMBER_COHORT_SURVIVAL` → 테스트 assert_fmcs(㉥ 계산식 대조 포함)~~ ➔ 🟢 [O249-B] 사용자 build 완료 · 라이브 상한 80·9999 각 98행 · 중복 0 | 👤 사용자(R4-1) |
| ~~②~~ | ~~👤 GN_ANALYST_01 로그인 → A3 §4-3 ㉠~㉤ 기록 · 롤백 = A3 [1-R]~~ ➔ 🟢 [O249-B] ㉠ 사용자 확인 · ㉡ 생략(사용자) · ㉢㉤ 에이전트 확인 · A3 status 🟢 | 👤 사용자 |
| ~~③~~ | ~~마케팅캠페인 미연결 명단(`12_agent개선과제/output/O249_…csv`) 현업 송부 · 공147·W6~~ ➔ 🟢 [O249-B] O249-B ③ 현업 항목으로 이관 | 현업 |
| ~~④~~ | ~~신규회원 ML 예측 테이블 복원 여부 ML 담당 확인(현재는 배분 추정으로 답함)~~ ➔ 🟢 [O249-B] 사용자 결정 = ML 테이블 증가 없음 · 배분 추정으로 확정 | ML 담당 |
| ~~⑤~~ | ~~발송결과 SND 라벨 미매핑(코드 有 · 라벨 無 ≈ 10%p) 코드군 확인~~ ➔ 🟢 [O249-B] 코드사전 결번(O116-B) · 문서20 기등재 · 라벨 창작 금지 ⇒ O249-B ③ 현업 대기로 이관 | 다음 세션 |
| ~~⑥~~ | ~~운영계 이관 시 = 05_03 · 21(배분 뷰) · 22(SV_ML_DVLP_FORECAST) · 35 · Agent 3종 spec · 06_DDL RENAME 1문~~ ➔ 🟢 [O249-B] O249-B ④(문서실행순서 20~25)로 이관 | 👤 운영계 |

### ▣ O249-A-4 ⚪ 결정 완료(재론 금지)

- LTV 상한 = CEIL(AVG(관측 중 회원 최종중단 기준 유지개월)) · 전체 모집단 1값 · 컬럼명 LTV_CAP_AVG_ACTIVE_MONTHS(사용자 2026-10-20).
- 예측 가드레일 순서 = ① ML → ② 비중 배분 → ③ 부서 수식 → ④ 추세 참고치(3 Agent 공통).

_Co-authored with CoCo_
