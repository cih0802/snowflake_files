<!-- LLM-METADATA
doc_id: HANDOFF_O0190_E
doc_role: 인수인계 — 세션 `O190-E` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-30
created_by: O190-E
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0190-E -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O190-E-0 🔴 먼저 알아라 (2026-09-30 · bt97381)

- 🟢 사용자 build(BigQuery 전구간 백필 + FMD) = PASS 95 · WARN 1 · ERROR 0 — 재조회 판정:
  - BigQuery 체인 복구 — BASIC·EVENT **9,264,762 / 33일**(= 원천) · FBB **1,398,512** · UTM 채움 800,591 · `WARN_BIGQUERY_LOAD_GAP` **0**.
  - L-1① 반영 — D5 중단 귀속 157,097 → **111,268**(정확히 −45,829) · 처리통보성 제목에 남은 D5 귀속 **0**.
- 🟢 전 모델 적재 방식 정리(사용자 질의) — 창 증분은 `BIGQUERY_BASIC`·`BIGQUERY_EVENT`·`FACT_BIGQUERY_BEHAVIOR` 3개뿐 ·
  SILVER/GOLD fact 나머지 = TRUNCATE+append · dim = merge(삭제 미전파) · 전구간 백필 = `build --vars bigquery_dt_ranges` 1줄.

### ▣ O190-E-1 🟢 이 단위가 끝낸 것

- **Agent MEMBER VERSION$4 · MARKETING VERSION$5** — ML 등급 3종 · 데려온 사업(L-2) 도구 설명 반영 · 도구 집합 불변 · 기본 버전 텍스트 재조회 확인.

### ▣ O190-E-2 🟠 남은 작업 + 추천안

| 순 | 작업 | 못 한 이유 | 추천안 |
|---|---|---|---|
| 1 | 스모크 중간 오류 10(metric-as-CTE 7 · 추측 식별자 3) | Analyst 생성 거동 · 지시문 효과 0 실증 | ⓐ 추측 식별자는 실차원화(FULL_DATE 처방 효과 7→1 실증) — `date.YEAR`·`fme.EVENT_DATE` 추가 ⓑ metric-as-CTE 는 VQR(검증 쿼리) 로 정답 SQL 패턴을 SV 에 심는다 ⓒ 판정 기준을 「최종 응답 오류 0」 + 「중간 오류 추이」 2축으로 분리 |
| 2 | ML ONCE_CONVERSION grain 붕괴 | 현행 예측 판별 키가 원천에 없음 | ML 담당에게 ① 회원당 다중행의 의미(모델 버전? 재실행?) ② 실행 순번·시각 컬럼 추가 요청 · 회신 전 SV 에 「회원수 과대 가능」 경고 1줄 |
| 3 | F-1 본부/지부 | 조직표에 조직구분 없음 · 트리 2단계는 지부 소실 | **실적트리(`ACMSLT_UPPER_DEPT_ID`) 기준**을 제안 — DEC-5 실측상 실적부서의 98% 가 실적트리 5단에 모인다 ⇒ 그 상위 노드를 본부/지부로 채택 · 현업에 1줄 확인 |
| 4 | E-1 FUNDRAISING_COST | YN_1 vs YN_2 정의 회신 대기(문서20 -009:103) | 우선 **원천 플래그 2개를 FACT_BUDGET degen 으로 싣기**(판정 중립 · 회신 즉시 지표화) |
| 5 | 2차-B 2단 32테이블 | 공수(테이블 단위 DDL→ALTER→모델) | 이용 빈도 상위 5테이블부터 1세션 1묶음(문서32 §3 순서) |
| 6 | 문서02 재서술 | 문서 전체 재작성(파괴적 · 증분형 규약 확인 필요) | 새 조각 1개에 「현재 측정 상태」만 생성 → 구 조각은 은퇴(retire_rows · 별도 승인) |
| 7 | 신규 19종 COMMENT 업무 문안 | 업무 의미 원천 없음(창작 금지) | 현업에 19종 × 핵심 컬럼만 추린 질의표 발송 · 그 전엔 BRONZE 상속본 유지 |
| 8 | 현업 회신 — F-2 「11개」 · F-3 SND 오픈 · 문서20 👤 5 · DGT 2026-06 이전 | 외부 | 1장짜리 회신 요청서로 묶어 발송 |
| 9 | 산출물 03~09 재생성 + 골든 | 잔여 0 조건 | 1~8 중 DW 소관(1·4·5) 종료 시점에 1회 |

_Co-authored with CoCo_
