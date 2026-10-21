<!-- LLM-METADATA
doc_id: HANDOFF_O0249_B
doc_role: 인수인계 — 세션 `O249-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-20
created_by: O249-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0249-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O249-B-0 🔴 먼저 알아라

- `O249-B` = O249-A 후속 · 잔여·발견 이슈 일괄 시정(2026-10-20 · TRIALADMIN(SR61467) · ㉡ · 사용자 승인 전부 · 확정위반 1 = 마운트 append(`>>`) 사용 → 로그 유실 · `/tmp` 로 재실행 · 산출물 유실 0).
- dbt build(FACT_MEMBER_COHORT_SURVIVAL) 완료 확인 = 상한 80·9999 표지 각 98행 · grain 중복 0(라이브).
- 🔴 👤 dbt build 필요 = `--select DIM_SEND_REQUEST DIM_MSG_TEMPLATE DIM_MSG_TEMPLATE_BUTTON`(SK=0 unknown 멤버 · DR-31).

### ▣ O249-B-1 이번 단위 결과

| 항목 | 결과(SR61467 · 라이브 확인) |
|---|---|
| A3 CoCo 차단 | ㉠ 차단(사용자) · ㉡ 생략(사용자) · ㉢ ANALYST 롤 SV·Agent 정상 · ㉤ UNSET → -1 복귀 → 0 재적용 · status 🟢 |
| 체크리스트 ⑤ | ②-마스킹 권한 · ⑤ A2(시뮬레이터 VIEWER·SERVICE · ANALYST OPS 회수 · 90일 접근 0) · ⑥ 마스킹 12 컬럼(ADMIN 원문 · DBT·ANALYST 전량 ***) · ⑦ DMF 보류 |
| ② 캡처 | 15/15 ERROR 0(`_ENV/SR61467/` · N05 Q02 = 이 계정 build ID 로 재실행 · PASS=695 WARN=23 ERROR=0) |
| ③ 생성기 | A2(설계외부여 0 · MISSING 3 = 임시권한 회수분) · B(테이블 283 · FK 72) · N03 · N05 |
| DR-25 | 코드 해소 확인(DIM_DATE → ref CRM_HOLIDAY · 251행) · D06 재생성 |
| DR-31 | 고아 원인 = SK=0 unknown 멤버 부재(발송 3,001행) · 템플릿 마스터 부재(버튼 21행) ⇒ dim 3 모델 시정(👤 build) |
| 80 패키지 | `build_handoff.py --apply` MISSING 0(511) · 원본 유실 1(`dbt_build_fact_ad_performance_budget.sql` → `10_dbt_pipeline/` 복원) · O249 증분 20~25 등재 |
| N01 DMF | §6 「적용 여부 = 후속 작업자 결정」 판단 근거 기재 |
| 자기검토 6 | 85번 71 파일 전수(중복 블록·표 열·CSV 열·긴 줄) · 손상 0 · CSV 열 밀림 1(N04 J4) 시정 |

### ▣ O249-B-2 ㉠ 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ~~①~~ | ~~👤 dbt build `--select DIM_SEND_REQUEST DIM_MSG_TEMPLATE DIM_MSG_TEMPLATE_BUTTON` → FK 고아 0 확인~~ ➔ 🟡 [O249-C] 템플릿·버튼 고아 0 · DIM_SEND_REQUEST 는 O249-C ① 로 이관 | 👤 사용자(R4-1) |
| ~~②~~ | ~~👤 DMF 적용 여부(N01 §6) · A3 [2] 롤 동기화 채택 여부~~ ➔ 🟢 [O249-C] O249-C ㉡ 백로그로 이관 | 후속 작업자 |
| ~~③~~ | ~~현업 = 미연결 캠페인 1,608건 · VIDEO 허용 인입경로 · SND 결과 라벨(문서20 기등재) · 공11·공147·W5·W6~~ ➔ 🟢 [O249-C] O249-C ㉡ 백로그로 이관 | 현업 |
| ~~④~~ | ~~운영계 이관 = `문서실행순서.md` 「기존 환경 갱신」 20~25 + 체크리스트 ⑤~~ ➔ 🟢 [O249-C] O249-C ㉡ 백로그로 이관 | 👤 운영계 |
| ~~⑤~~ | ~~80 패키지 옛 사본 `01_실행순서_배포SQL/dbt_build_fact_ad_performance_budget.sql`(경로 정정 전 위치) 삭제 여부~~ ➔ 🟢 [O249-C] O249-C ① ② 로 이관 | 👤 사용자(R1-7-7 삭제 승인) |

### ▣ O249-B-4 ⚪ 결정 완료(재론 금지)

- ML 결과 테이블은 늘어나지 않는다 · 컬럼명 변경만 있을 수 있다(사용자 2026-10-20) ⇒ 신규회원 예측 = 배분 추정으로 확정 · 컬럼명 변경 시 `21_ML_SERVING_뷰_DDL.sql` 뷰만 고친다.
- DMF = 쿼리와 적용 방법만 문서로 남기고 적용 여부는 후속 작업자가 정한다(N01 §6).
- CoCo 차단 ㉡ 생략(사용자) · 사용자 단위 한도 0 이 정답 수단.

_Co-authored with CoCo_
