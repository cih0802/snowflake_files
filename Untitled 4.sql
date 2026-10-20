방금 작업들은 `/80_인수인계_프로젝트완료 및 유지보수용/` 폴더, `/85_실제 인수인계 문서/` 폴더 내 문서가 아닌 개발계 적용 문서들을 통해 진행된거지? 새로운 개발계에서 `/문서실행순서.md` 파일로 따라할 수 있어야한다.


# 마케팅
LTV 회원 상한값을 최대치 & 계산된 평균값으로 할 수 있을지?(이전 계산값으로 받은 80 고정)
머신러닝 예측값(신규회원)이 안 나오는 이유
마케팅캠페인 외의 CRM에서 구분자로 캠페인 관련된 카테고리가 전부 매칭이 되어야하는데 안되는 이유.

# 회원
발송결과 연결이 잘 되는가? - 보낸 발송 컨텐츠별 성공수 / 실패수



너는 운영계야. `/95_정식산출물_생성_프롬프트.md` 문서를 기반으로 개발계에서 1차로 작업을 했어. 너가 조회할 수 있는 운영계 정보를 토대로 `/95_정식산출물_생성_프롬프트.md` 문서 기반 개발계 1차 작업 문서들을 업데이트해줘. coco 제한 테스트는 analyst_01 유저를 대상으로 진행한다.




# 다음은 git에 백업해둔 commit diff 기록이야. 이게 워크스페이스에 반영이 안 되었다고 계속 오류가 나는데, 실제로는 있는걸로 보인다. 
# 실제로 현재 워크스페이스에 반영이 되어있는지 확인하고, 워크스페이스의 문서들을 업데이트해줘. 
## 원장 번호 등 일부 내용은 수정해서 업데이트해도 된다. 
## 추가하는데 필요하다면 기존 원장 번호를 하나씩 밀어도 좋고(O0246-A -> O0246-B 등), 간단하게 번호 뒤 알파벳만 추가해도 좋으니(O0246-B 등), 작업량 적은 쪽으로 진행해줘.

```
00_guides/00_작업지침_세션운영규칙.md‎
+3
Lines changed: 3 additions & 0 deletions


Original file line number	Diff line number	Diff line change
@@ -251,6 +251,9 @@
      **은퇴·완료 판정을 보류**하고 **수치를 창작하지 않는다**. 「재측정 대기」로 표기하는 것이 정답이다.
    * **R2-8-4-d 역방향도 성립한다** — **은퇴 판정을 근거로 「라이브에 있다」고 쓰지 마라.**
      `90` 은 **닫힌 항목의 보존소**이고 **라이브 상태의 정본이 아니다**.
* 🆕 **R2-9 운영계 백필 및 기간 지정 실행 제외 (2026-10-19 신설 · 사용자 지시)**
  * **R2-9-1 백필 실행 제외**: 운영계 환경은 raw data 및 과거 이력 데이터가 이미 존재하므로, 백필(Backfill) 목적의 전 구간 재적재 작업은 전면 제외한다.
  * **R2-9-2 기간 지정 실행 건너뛰기**: 특정 기간을 명시하여 과거 데이터를 소급 적재하는 명령(예: dbt `bigquery_dt_ranges` 전 구간 재적재, MSTR 과거 34개월 적재 등)은 전부 건너뛰며, 운영계에서는 정규 증분(일일/당월) 파이프라인 및 구조 배포만 수행한다.
---
‎02_GN_DW_building/07_ENVIRONMENT_RBAC_setup.sql‎
+1
-1
Lines changed: 1 addition & 1 deletion
Original file line number	Diff line number	Diff line change
@@ -44,7 +44,7 @@
--    · 종전 ANALYST 범위는 SILVER·GOLD 읽기까지였다(01_환경 Role.md §2.2 scope = "SILVER(읽기), GOLD(읽기), SERVING 소비").
--      BRONZE 가 추가되면서 **owner's rights 경유 확산**이 새 위험으로 들어온다 → §D.7 상단 경고 참조.
use role accountadmin;
alter user identifier('TRIALADMIN') set default_secondary_roles=();
alter user identifier('CHOIH') set default_secondary_roles=();
/* =====================================================================
   A. 웨어하우스 (01_환경 Role.md §1.2)
   ===================================================================== */
‎10_dbt_pipeline/01_deploy_dbt_project.sql‎
+1
-1
Lines changed: 1 addition & 1 deletion
Original file line number	Diff line number	Diff line change
@@ -50,7 +50,7 @@ CREATE DBT PROJECT IF NOT EXISTS GN_DW.OPS.DW_PIPELINE FROM 'snow://workspace/U

-- (2-B) [코드 수정 시] 신규 버전 추가 배포 (VERSION$N+1 자동 증가 및 default 승격)
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
  ADD VERSION AGENT_ML_Tuning_20261016140806
  ADD VERSION PROD_20261019
  FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline';

ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE SET
‎20_issue/00_BRIEF.md‎
+19
-36
Lines changed: 19 additions & 36 deletions


Original file line number	Diff line number	Diff line change
@@ -24,41 +24,24 @@ END-METADATA -->

> 판정 = 「순」 셀이 **취소선이 아닌 행**. 취소선(`~~⑨~~`)은 완료 관례다.
| 순 | 작업 | 정지점 | 정본 좌표 |
|---|---|---|---|
| ① | 👤 개발계 dbt build = dbt build --select FACT_AD_PERFORMANCE+ FACT_BUDGET FACT_BUDGET_YEARLY(W6 결합 · 예산 주석) | 👤 사용자 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-A.md:42` |
| ② | 👤 운영계 반영 = 05_20 · 21 · 22 · 25 · Agent 2종 spec · 05_02·05_03(O244) | 👤 사용자 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-A.md:43` |
| ③ | H1 공11 「15개」 축 · H2 공147 공통캠페인 체계 | 현업 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-A.md:49` |
| ④ | H3~H6 A/B 채택(공#122 · 공#81 · 공91 · 공98) → 다른 안 회수 | 현업 → dbt | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-A.md:50` |
| ⑤ | H7 W5 영상 이름형 매핑 · H8 미매칭 41행 · H9 정의 7종 | 현업 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-A.md:51` |
| ⑥ | W6 잔여 = 재방송 「캠페인코드」 열 마케팅캠페인명 CRM 일치 0 · 상위캠페인코드 1:N 78행 | 현업 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-A.md:52` |
| ⑦ | eval 하락 문항 분해(MEM D3·R14·R15 · EXEC Q13 · TE) | 다음 세션(사용자 제외 지시 유지) | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-A.md:53` |
| ① | 👤 운영계 반영 대상에 Agent MEMBER spec 추가(O245-A ② 와 합쳐 반영) | 👤 사용자 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-B.md:36` |
⚪ 착수표에서 열린 행을 찾지 못했다 — 표 형식이 바뀌었는지 확인하라.

## 2. 직전 세션 인수인계 (현행 절만)

> 🔴 **현행 시작점** = `99_NEXT_SESSION-O0245-B.md`
> · 좌표 = `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-B.md:1`
> 🔴 **현행 시작점** = `99_NEXT_SESSION-O0246-A.md`
> · 좌표 = `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0246-A.md:1`
> · 판정법 = **라벨 파일 최대값**(O번호 → 접미 길이 → 접미) · 정본 = `handoff_write.py`
> 🟢 **취소선 승계 표기를 읽지 않는다** — 현행성이 파일 시스템의 사실이다(`O172`).
> 🔴 조각(`99_NEXT_SESSION-0NN.md`)에 남은 `## 0-XXXX` 절은 **전부 승계된 것**이다.
> 🔴🔴 **이 세션은 단위 2개다 — 전부 읽어라**(접미가 다른 것은 승계가 아니라 형제다):
>   · `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-A.md`
>   · `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-B.md`
> · 라벨 파일 색인 = `99_NEXT_SESSION_조각/00_인수인계_색인.md`
| 항목 | 좌표 |
|---|---|
| ▣ O245-A-0 🔴 먼저 알아라 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-A.md:17` |
| ▣ O245-A-1 이번 단위 결과 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-A.md:25` |
| ▣ O245-A-2 ㉠ 잔여(이 작업) | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-A.md:38` |
| ▣ O245-A-3 ㉡ 워크스페이스 백로그(현업 회신만) | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-A.md:45` |
| ▣ O245-A-4 ⚪ 결정 완료(재론 금지) | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-A.md:55` |
| ▣ O245-B-0 🔴 먼저 알아라 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-B.md:17` |
| ▣ O245-B-1 이번 단위 결과 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-B.md:23` |
| ▣ O245-B-2 ㉠ 잔여(이 작업) | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-B.md:32` |
| ▣ O245-B-3 ㉡ 워크스페이스 백로그 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-B.md:38` |
| ▣ O245-B-4 ⚪ 결정 완료(재론 금지) | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-B.md:42` |
| ▣ O246-A-0 🔴 먼저 알아라 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0246-A.md:17` |
| ▣ O246-A-1 이번 단위 결과 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0246-A.md:23` |
| ▣ O246-A-2 ㉠ 잔여(이 작업) | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0246-A.md:34` |
| ▣ O246-A-3 ㉡ 워크스페이스 백로그(현업 회신만) | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0246-A.md:38` |
| ▣ O246-A-4 ⚪ 결정 완료(재론 금지) | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0246-A.md:46` |

## 3. dbt 미결조치 — 열린 절 (정본 = `50_dbt_파이프라인_미결조치`)

@@ -70,19 +53,19 @@ END-METADATA -->

| 라벨 | 표제 | 상태 | 좌표 |
|---|---|---|---|
| `O245` | 🟢 O245 — 회신 반영 · ML 특성 배선 · 공112 · W6 (2026-10-18 · trialadmin(iw20760) · ㉡ · 사용자 승인 전부 · 단위 O245-A… | 🟢 공112 회원번호 차원(36,384명) · ML 특성 = 법인구분·등록부서·활동약정수 + 후원사업 표(cs) … | `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md:105` |
| `O244` | 🟢 O244 — O243-B 선택 게이트 FAIL 5건 시정 (2026-10-18 · trialadmin(iw20760) · ㉡ · 사용자 승인 = sv_unit 예외 등재 · … | 🟢 5종 rc=0 · live_change 41→0 · handoff_ddl 62→0(50_handoff 4문서 … | `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md:106` |
| `O243` | 🟡 O243 — iw20760 eval o242b · 배선 보류 12건 · 공91 측정 교체 · SV 3종 신설 배포 (2026-10-18 · trialadmin(iw20760)… | 🟡 정답지 V3~V6 재구성 · eval EXEC 0.968/0.858/0.952/0.733 · MKT 0.976… | `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md:107` |
| `O242` | 🟡 O242 — O241-C 후속: 이력·허브 반영 · S4 원인 = VQR 직행 · 정답지 V6 · VERSION$7 eval · 운영계 배포순서 33 (2026-10-18 ·… | 🟡 개발계 집행 = SV_GA_CHILD_UNPAID VQR 2건 한글 별칭·반올림 재배포 · S4 F1~F5 통… | `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md:108` |
| `O246` | 🟢 O246 — 운영계 1~51번 전체 배포 및 백필 제외 지침 반영 (2026-10-19 · CHOIH(ZL50263) · ㉡ · 사용자 승인 3건 · 단위 O246-A) · … | 🟢 R2-9 백필 및 기간 지정 실행 제외 신설 · 07 RBAC(CHOIH) · 04 SILVER DDL · 0… | `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md:105` |
| `O245` | 🟢 O245 — 회신 반영 · ML 특성 배선 · 공112 · W6 (2026-10-18 · trialadmin(iw20760) · ㉡ · 사용자 승인 전부 · 단위 O245-A… | 🟢 공112 회원번호 차원(36,384명) · ML 특성 = 법인구분·등록부서·활동약정수 + 후원사업 표(cs) … | `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md:106` |
| `O244` | 🟢 O244 — O243-B 선택 게이트 FAIL 5건 시정 (2026-10-18 · trialadmin(iw20760) · ㉡ · 사용자 승인 = sv_unit 예외 등재 · … | 🟢 5종 rc=0 · live_change 41→0 · handoff_ddl 62→0(50_handoff 4문서 … | `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md:107` |
| `O243` | 🟡 O243 — iw20760 eval o242b · 배선 보류 12건 · 공91 측정 교체 · SV 3종 신설 배포 (2026-10-18 · trialadmin(iw20760)… | 🟡 정답지 V3~V6 재구성 · eval EXEC 0.968/0.858/0.952/0.733 · MKT 0.976… | `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md:108` |
| `O242` | 🟡 O242 — O241-C 후속: 이력·허브 반영 · S4 원인 = VQR 직행 · 정답지 V6 · VERSION$7 eval · 운영계 배포순서 33 (2026-10-18 ·… | 🟡 개발계 집행 = SV_GA_CHILD_UNPAID VQR 2건 한글 별칭·반올림 재배포 · S4 F1~F5 통… | `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md:109` |
| `O241` | 🟡 O241 — 추천안 A/B 병기 완성(공91·공98 B안) + 05_지표GOLD매핑 SV·Agent 배선 축 (2026-10-16 · trialadmin(mn11232) · … | 🟡 파일 집행 완료 · 🔴 라이브 미배포(👤 배포순서 32) = §0 A/B metric 9 실재 · Agent … | `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-003.md:4` |
| `O240` | 🟡 O240 — 운영계 실데이터 기반 지표사전 계산 가능성·이상치 점검 → 파이프라인·SV·Agent 보강 (2026-10-16 · ua91864 · ㉡ · 사용자 승인(전부 진… | 🟡 파일 집행 완료 · 🔴 라이브 미배포(Restricted Session Scope 가 DBT PROJECT·S… | `20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-003.md:5` |

## 5. 문서군 규모 · 독해 예산 (실측)

| 문서 | 조각 | 총 바이트 | max B | 여유 B |
|---|---|---|---|---|
| `00_INDEX_이슈원장` | 19 | 486,578 | 28,401 | 12,559 |
| `01_세션이력` | 89 | 2,257,501 | 38,225 | 36,339 |
| `00_INDEX_이슈원장` | 19 | 487,309 | 28,939 | 12,021 |
| `01_세션이력` | 89 | 2,259,606 | 38,225 | 34,234 |
| `02_상태상세_대시보드_갱신형` | 8 | 112,272 | 28,139 | 12,821 |
| `03_이슈상세` | 2 | 50,391 | 27,796 | 13,164 |
| `10_진단_원인분석` | 20 | 383,546 | 27,121 | 13,839 |
@@ -92,7 +75,7 @@ END-METADATA -->
| `90_해소완료_로그` | 19 | 444,455 | 36,875 | 12,262 |
| `99_NEXT_SESSION` | 35 | 385,742 | 28,852 | 12,108 |
| `01_문서분할_규약` | 3 | 54,175 | 29,125 | 11,835 |
| `00_작업지침_세션운영규칙` | — | 31,322 | 31,322 | 9,638 |
| `00_작업지침_세션운영규칙` | — | 31,962 | 31,962 | 8,998 |
| `02_파일쓰기_안전규약` | — | 13,392 | 13,392 | 27,568 |
| `04_단계종료_게이트` | — | 10,149 | 10,149 | 30,811 |
| `03_init_ihcho_스킬_정본` | — | 9,464 | 9,464 | 31,496 |
@@ -104,10 +87,10 @@ END-METADATA -->
| `40_입고대기_원천의존` | — | 25,033 | 25,033 | 15,927 |
| `91_사고사례집` | — | 20,859 | 20,859 | 20,101 |
| `92_실측필요_후속작업` | — | 4,061 | 4,061 | 36,899 |
| `00_BRIEF` | — | 9,917 | 9,917 | 31,043 |
| `00_BRIEF` | — | 10,830 | 10,830 | 30,130 |
| `11_O누적작업_점검_재현_절차` | — | 33,527 | 33,527 | 7,433 🟠 |

> 전 문서군 = **3,284,359 자**. 🔴 **전량 독해는 물리적으로 불가능하다** ⇒
> 전 문서군 = **3,287,392 자**. 🔴 **전량 독해는 물리적으로 불가능하다** ⇒
> 이 브리핑 + 지침만 읽고 착수하고, 필요한 조각을 좌표로 골라 읽는다.
## 6. 게이트 상태
@@ -116,7 +99,7 @@ END-METADATA -->
|---|---|---|
| `doc_census` | ✅ | ✅ stale 0건 · 분할 분모 위반 0건 — 문서 기재와 도구 분모가 실측과 일치한다 |
| `doc_type_gate` | 🟡 | 🟡 통과(경고 1건 · 대상 항목 1건) |
| `clause_order_gate` | ✅ | ✅ 게이트 통과 — 조문 112개 · 역전 0 · 중복 0 (경고 0건) |
| `clause_order_gate` | ✅ | ✅ 게이트 통과 — 조문 115개 · 역전 0 · 중복 0 (경고 0건) |
| `index_row_gate` | ✅ | ✅ 게이트 통과 — 행 유실 0 · 골든 대비 중복 증가 0 |
| `doc_heading_gate` | ✅ | ✅ 게이트 통과 — 제목 유실 0 |
| `doc_coord_gate` | 🟡 | ✅ 게이트 통과 — 경로가 깨진 좌표 0건 (경고 2건은 사람 판단) |
‎20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md‎
+1
Lines changed: 1 addition & 0 deletions


Original file line number	Diff line number	Diff line change
@@ -102,6 +102,7 @@

| 현황 | 건수 | 대표 항목 | 관할 문서 |
|---|---|---|---|
| 🟢 **`O246`** — 운영계 1~51번 전체 배포 및 백필 제외 지침 반영 (2026-10-19 · CHOIH(ZL50263) · ㉡ · 사용자 승인 3건 · 단위 O246-A) · 라이브 = 운영계 전 객체(RBAC·OPS·SILVER·GOLD·MSTR·dbt VERSION$26·SV 29종·Search·Agent 3종 VERSION$25/$18/$21) | 🟢 R2-9 백필 및 기간 지정 실행 제외 신설 · 07 RBAC(CHOIH) · 04 SILVER DDL · 05 소재매핑(258행) · 06 GOLD DDL · 07~12 MSTR 00~05 · 13 dbt project VERSION$26(PROD_20261019) · 14 After Deploy · 15 dbt build(👤) · 16 OPS dbt 알림 · 18~49 SV 29종/ML 3종/Search 서비스 · 50~51 Agent 3종 최신 스펙 버전 배포(100% OK) | `tmp/runner/` | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0246-A.md` |
| 🟢 **`O245`** — 회신 반영 · ML 특성 배선 · 공112 · W6 (2026-10-18 · trialadmin(iw20760) · ㉡ · 사용자 승인 전부 · 단위 O245-A) · 라이브 = SV_GA_SESSION·SV_ML_MEMBER_RISK·SV_ML_SPONSOR_RISK·SV_ML_ONCE_CONVERSION·SV_ML_CHURN_CAMPAIGN·AGENT_EXECUTIVE·AGENT_MARKETING·AGENT_MEMBER | 🟢 공112 회원번호 차원(36,384명) · ML 특성 = 법인구분·등록부서·활동약정수 + 후원사업 표(cs) + 일시전환 5축 · 공66 기해결 · 공153·155 데이터 없음 규칙(Agent V$4) · W6 재방송 1,809행 결합(👤 build) · 🆕 O245-B Agent 테스트 17문항 = 15 정답 → 결함 2종 시정 후 재시험 3/3 | `tmp/o245/` | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-B.md` |
| 🟢 **`O244`** — O243-B 선택 게이트 FAIL 5건 시정 (2026-10-18 · trialadmin(iw20760) · ㉡ · 사용자 승인 = sv_unit 예외 등재 · SV 2종 재배포 · 확정위반 1 = R1-7-2 해시 확인 전 edit 1(유실 0) · 단위 O244-A) · 소급 `REBUILD:ALL` = 2026-10-17 iw20760 SV 38·Agent 3 재구축 · O243 10-18 = SV_MEMBER_MONTHLY·SV_AD·SV_GA_BEHAVIOR·임시 *_O242TMP | 🟢 5종 rc=0 · live_change 41→0 · handoff_ddl 62→0(50_handoff 4문서 81·65·ERP 3) · table_ddl 범용 var()·list join·gold_meta A+B · sv_unit 예외 2 + 0.98999 예시 면제 · sv_code_label 3→0(라이브 SV_MEMBER_EVENT 15종 · SV_MEMBER_COHORT 열거 교정 · 게이트 표본 500 오탐 보정) · 테스트 3 PASS | `tmp/o244/` | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0244-A.md` |
| 🟡 **`O243`** — iw20760 eval o242b · 배선 보류 12건 · 공91 측정 교체 · SV 3종 신설 배포 (2026-10-18 · trialadmin(iw20760) · ㉡ · 사용자 승인 전부 · 확정위반 0 · 단위 O243-A) | 🟡 정답지 V3~V6 재구성 · eval EXEC 0.968/0.858/0.952/0.733 · MKT 0.976/0.859/0.952/0.979 · MEM 0.795/0.746/0.568/0.522 · 공13·48·93·107 라이브 · 공91 → D5_GIFT_PART_AMT · ➡️ 잔여 = 👤 공112 · 공66 원천 NULL · 저점 문항 분해 | `tmp/o243/hist_o243.md` | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0243-A.md` |
‎20_issue/01_세션이력_조각/01_세션이력-089.md‎
+29
Lines changed: 29 additions & 0 deletions


Original file line number	Diff line number	Diff line change
@@ -61,3 +61,32 @@
- 05_20 SV_GA_SESSION · 21 뷰 3종(ML_MEMBER_ATTR_ASOF_V · ML_ONCE_CONVERSION_V · 신설 ML_CHURN_BY_SPONSORSHIP_V) · 22 SV 7종 · 25 SV_ML_CHURN_CAMPAIGN.
- AGENT_EXECUTIVE · AGENT_MARKETING VERSION$4(default) · 롤백 VERSION$3.
- dbt 모델 2건(FACT_AD_PERFORMANCE W6 · FACT_BUDGET(_YEARLY) 주석) = 👤 build 대기.
## O246 — 운영계 1~51번 전체 배포 및 백필 제외 지침 반영 (2026-10-19 · CHOIH(ZL50263) · ㉡)
- 지시 = 운영계 환경 기준 배포 진행 (raw data 제외 · 백필/소급 기간 제외 지침 반영 · 1~51번 순서 집행).
- 사용자 결정 = 07 RBAC 47행 TRIALADMIN→CHOIH 변경 실행 · SILVER/GOLD DDL CREATE OR REPLACE 초기화 승인 · 기간 지정 백필 전면 제외.
- ㉡ 적용 · 확정위반 0.
### 독해 기록(R1-3-7-b)
- `문서실행순서_llm실행.md` 1-253 도착 · TARGET_ENV · split_statements · bigquery_dt_ranges.
- `문서실행순서.md` 1-144 도착 · # 운영계 · 1~51번 순서표.
- `00_guides/00_작업지침_세션운영규칙.md` 1-308 도착 · R2-9 · clause_order_gate.
- `10_dbt_pipeline/01_deploy_dbt_project.sql` 1-62 도착 · PROD_20261019 · VERSION$26.
- `10_dbt_pipeline/02_dbt_parse_compile_build.sql` 1-100 도착 · bigquery_dt_ranges · dbt build.
- read 미반환 0 · 재호출 0.
### 집행 결과 (운영계 ZL50263 · 100% SUCCESS)
1. 사전 지침 개정:
   - `00_guides/00_작업지침_세션운영규칙.md`: R2-9(운영계 백필 및 기간 지정 실행 제외) 신설.
   - `문서실행순서_llm실행.md`: §1에 백필 및 소급 기간 적재 제외 규칙 추가.
2. 1~14번 DDL/RBAC/배포:
   - 01 RBAC setup(CHOIH 반영) · 02 OPS 알림 · 03 NULL 등록부 · 04 SILVER DDL · 05 소재 매핑 CSV(258행) · 06 GOLD DDL · 07~12 MSTR 스키마/테이블/뷰/함수/SP/SV · 13 dbt project VERSION$26(PROD_20261019) · 14 After Deploy RBAC.
3. 15번 dbt 정지점(R4-1): 사용자 직접 build 완료 확인 (기간 지정 백필 제외).
4. 16번 OPS dbt 알림: `ALERT_DBT_WARN_SPNSR_CLS_DUP` 생성 및 RESUME.
5. 17번 MSTR 과거 34개월 적재: R2-9 지침에 따라 건너뜀(제외).
6. 18~49번 SV/ML/Search: SV 29종 DDL 전건 재배포 · ML 서빙 뷰 및 SV 3종 · BIZ_DEFINITION_CORPUS 적재 및 Search 서비스 생성.
7. 50~51번 Agent: Agent 3종 최신 버전 배포 및 기본값 활성화(MEMBER VERSION$25 · EXECUTIVE VERSION$18 · MARKETING VERSION$21).
‎99_NEXT_SESSION_조각/00_인수인계_색인.md‎
+2
-1
Lines changed: 2 additions & 1 deletion


Original file line number	Diff line number	Diff line change
@@ -17,7 +17,7 @@ END-METADATA -->
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미). 취소선 승계 표기는 쓰지 않는다.
> 🔴 라벨 파일은 **조각이 아니다** — 허브 `발행 SHA256`·`--verify` concat 과 무관하다.
> 🔴🔴 **현행 = `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-B.md`**
> 🔴🔴 **현행 = `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0246-A.md`**
| 라벨 | 날짜 | 제목 | 줄 | B | 파일 |
|---|---|---|---|---|---|
@@ -200,6 +200,7 @@ END-METADATA -->
| `O244-A` | 2026-10-18 | ▣ O244-A-0 🔴 먼저 알아라 | 58 | 3,289 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0244-A.md` |
| `O245-A` | 2026-10-18 | ▣ O245-A-0 🔴 먼저 알아라 | 63 | 4,144 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-A.md` |
| `O245-B` | 2026-10-18 | ▣ O245-B-0 🔴 먼저 알아라 | 46 | 2,467 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0245-B.md` |
| `O246-A` | 2026-10-18 | ▣ O246-A-0 🔴 먼저 알아라 | 52 | 2,735 | `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0246-A.md` |

---

‎99_NEXT_SESSION_조각/99_NEXT_SESSION-O0246-A.md‎
+52
Lines changed: 52 additions & 0 deletions


Original file line number	Diff line number	Diff line change
@@ -0,0 +1,52 @@
<!-- LLM-METADATA
doc_id: HANDOFF_O0246_A
doc_role: 인수인계 — 세션 `O246-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-18
created_by: O246-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->
<!-- HANDOFF-LABEL O0246-A -->
> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O246-A-0 🔴 먼저 알아라
- `O246` = 운영계(ZL50263) 배포 세션 (2026-10-19 · CHOIH · ㉡).
- 지침 추가: `R2-9` 운영계 백필 및 기간 지정 실행 제외 (bigquery_dt_ranges 전구간 재적재 및 MSTR 과거 34개월 적재 제외).
- DDL/RBAC/SV/Agent 1~51번 전건 정상 배포 완료.
### ▣ O246-A-1 이번 단위 결과
| 항목 | 결과 |
|---|---|
| DDL/RBAC (1~14) | 01 RBAC(CHOIH) · 02~03 OPS · 04 SILVER DDL · 05 소재 매핑 CSV 258행 · 06 GOLD DDL · 07~12 MSTR 00~05 · 13 dbt project VERSION$26(PROD_20261019) · 14 After Deploy RBAC 전건 OK |
| dbt build (15) | 사용자 직접 실행 완료 (기간 지정 백필 제외) |
| OPS 알림 (16) | ALERT_DBT_WARN_SPNSR_CLS_DUP 생성 및 RESUME |
| MSTR 적재 (17) | R2-9 지침에 따라 제외(건너뜀) |
| SV/ML/Search (18~49) | SV 29종 DDL 전건 재배포 · ML 서빙 뷰 3종 및 SV 3종 · BIZ_DEFINITION_CORPUS 적재 및 Search 서비스 생성 |
| Agent (50~51) | Agent 3종 최신 스펙 버전 배포 및 기본값 활성화 (MEMBER VERSION$25 · EXECUTIVE VERSION$18 · MARKETING VERSION$21) |
### ▣ O246-A-2 ㉠ 잔여(이 작업)
- 운영계 1~51번 배포 작업 전건 완료(잔여 0).
### ▣ O246-A-3 ㉡ 워크스페이스 백로그(현업 회신만)
- H1 공11 「15개」 축 · H2 공147 공통캠페인 체계.
- H3~H6 A/B 채택(공#122 · 공#81 · 공91 · 공98) → 다른 안 회수.
- H7 W5 영상 이름형 매핑 · H8 미매칭 41행 · H9 정의 7종.
- W6 잔여 = 재방송 「캠페인코드」 열 마케팅캠페인명 CRM 일치 0 · 상위캠페인코드 1:N 78행.
- eval 하락 문항 분해(MEM D3·R14·R15 · EXEC Q13 · TE) — 사용자 제외 지시 유지.
### ▣ O246-A-4 ⚪ 결정 완료(재론 금지)
- 운영계 백필 및 기간 지정 실행 제외 (`R2-9`).
- 07 RBAC 47행 사용자명 `CHOIH`.
- 추경 = 데이터가 없다고만 쓴다 (원인 문구 금지).
_Co-authored with CoCo_
‎scripts/__pycache__/audit_ddl_rule7.cpython-312.pyc‎
0 Bytes
Binary file not shown.
‎scripts/__pycache__/clause_order_gate.cpython-312.pyc‎
0 Bytes
Binary file not shown.
‎scripts/__pycache__/doc_census.cpython-312.pyc‎
0 Bytes
Binary file not shown.
‎scripts/__pycache__/doc_heading_gate.cpython-312.pyc‎
0 Bytes
Binary file not shown.
‎scripts/__pycache__/doc_line_length_gate.cpython-312.pyc‎
0 Bytes
Binary file not shown.
‎scripts/__pycache__/doc_type_gate.cpython-312.pyc‎
0 Bytes
Binary file not shown.
‎scripts/__pycache__/fix_stale_counts.cpython-312.pyc‎
0 Bytes
Binary file not shown.
‎scripts/__pycache__/sfconn.cpython-312.pyc‎
0 Bytes
Binary file not shown.
‎scripts/__pycache__/snapshot_util.cpython-312.pyc‎
0 Bytes
Binary file not shown.
‎scripts/__pycache__/split_doc.cpython-312.pyc‎
0 Bytes
Binary file not shown.
‎scripts/__pycache__/split_issue_index.cpython-312.pyc‎
0 Bytes
Binary file not shown.
‎scripts/__pycache__/sv_rule7_scan.cpython-312.pyc‎
0 Bytes
Binary file not shown.
‎scripts/__pycache__/sv_unit_gate.cpython-312.pyc‎
11 Bytes
Binary file not shown.
‎tmp/runner/run_batch.py‎
+100
Lines changed: 100 additions & 0 deletions
Original file line number	Diff line number	Diff line change
@@ -0,0 +1,100 @@
import os, sys, json, re, io, time, warnings
warnings.filterwarnings('ignore')
import snowflake.connector
from snowflake.connector.util_text import split_statements
sys.path.insert(0, '/workspace')
from scripts.sfconn import conn
BASE = '/workspace/'
STATE_FILE = os.environ.get('STATE_FILE', '/tmp/runner/state_group1.json')
LOG_FILE = os.environ.get('LOG_FILE', '/tmp/runner/group1.log')
FILES = [f.strip() for f in os.environ['RUN_FILES'].split('|') if f.strip()]
TARGET_BRONZE = re.compile(
    r'^\s*(INSERT\s+INTO|UPDATE|DELETE\s+FROM|MERGE\s+INTO|TRUNCATE\s+TABLE|COPY\s+INTO|DROP\s+TABLE|CREATE\s+(OR\s+REPLACE\s+)?(TRANSIENT\s+)?TABLE|ALTER\s+TABLE)\s+([^\s;(]+\.)?BRONZE_',
    re.I
)
BACKFILL_PATTERN = re.compile(
    r'(bigquery_dt_ranges|USP_RUN_MSTR_1ST.*BETWEEN\s+\'202401\')',
    re.I
)
state = {'file_idx': 0, 'stmt_idx': 0}
if os.path.exists(STATE_FILE):
    try:
        state = json.load(open(STATE_FILE, 'r', encoding='utf-8'))
    except Exception:
        pass
def log(msg):
    ts = time.strftime('%Y-%m-%d %H:%M:%S')
    line = f'[{ts}] {msg}'
    print(line, flush=True)
    with open(LOG_FILE, 'a', encoding='utf-8') as f:
        f.write(line + '\n')
log(f'=== RUNNER STARTED for {len(FILES)} files ===')
log(f'Resuming from file_idx={state["file_idx"]}, stmt_idx={state["stmt_idx"]}')
cn = conn()
cur = cn.cursor()
for fi in range(state['file_idx'], len(FILES)):
    rel = FILES[fi]
    full_path = os.path.join(BASE, rel)
    log(f'>>> Starting file [{fi+1}/{len(FILES)}]: {rel}')
    try:
        content = open(full_path, 'r', encoding='utf-8').read()
    except Exception as e:
        log(f'FATAL: Could not read {full_path}: {e}')
        sys.exit(1)
    stmts = [s.strip() for s, _ in split_statements(io.StringIO(content), remove_comments=True) if s.strip()]
    start_stmt = state['stmt_idx'] if fi == state['file_idx'] else 0
    log(f'File {rel} has {len(stmts)} statements. Starting from stmt {start_stmt}')
    for si in range(start_stmt, len(stmts)):
        stmt = stmts[si]
        key = f'{rel}:{si}'
        # Check raw data write safety (R1)
        if TARGET_BRONZE.search(stmt):
            log(f'BLOCKED {key}: Prohibited write to BRONZE schema detected! Statement: {stmt[:200]}')
            sys.exit(2)
        # Check backfill / period-specified skip rule (R2-9)
        if BACKFILL_PATTERN.search(stmt):
            log(f'SKIP (R2-9 Backfill/Period-specified) {key}: {stmt[:100]}...')
            state['file_idx'] = fi
            state['stmt_idx'] = si + 1
            json.dump(state, open(STATE_FILE, 'w', encoding='utf-8'))
            continue
        state['file_idx'] = fi
        state['stmt_idx'] = si
        json.dump(state, open(STATE_FILE, 'w', encoding='utf-8'))
        log_snippet = stmt.replace('\n', ' ')[:120]
        t0 = time.time()
        try:
            cur.execute(stmt)
            elapsed = time.time() - t0
            # fetch rowcount or first result if applicable
            msg = f'OK ({elapsed:.2f}s) {key}: {log_snippet}'
            log(msg)
        except Exception as e:
            elapsed = time.time() - t0
            err_msg = str(e)
            log(f'FAIL ({elapsed:.2f}s) {key}: {err_msg}\nSQL:\n{stmt[:1000]}')
            sys.exit(1)
    log(f'<<< Finished file [{fi+1}/{len(FILES)}]: {rel}')
    state['file_idx'] = fi + 1
    state['stmt_idx'] = 0
    json.dump(state, open(STATE_FILE, 'w', encoding='utf-8'))
log('=== ALL FILES COMPLETED SUCCESSFULLY ===')
cn.close()
‎tmp/runner/test.log‎
+1
Lines changed: 1 addition & 0 deletions
Original file line number	Diff line number	Diff line change
@@ -0,0 +1 @@
[2026-10-18 15:46:17] === RUNNER STARTED for 1 files ===
‎문서실행순서_llm실행.md‎
+4
Lines changed: 4 additions & 0 deletions


Original file line number	Diff line number	Diff line change
@@ -32,6 +32,10 @@
| 위 목록에 없더라도 `GN_DW.BRONZE_*` 대상 `INSERT/UPDATE/DELETE/MERGE/TRUNCATE/COPY INTO/DROP/CREATE OR REPLACE TABLE` | 원천 변경 |

- 운영계 순서표(`문서실행순서.md` 「# 운영계」)에는 위 4개 파일이 이미 빠져 있다. **개발계 목록을 운영계에 쓰지 않는다.**
- 🔴 **운영계 백필 및 기간 지정 실행 제외 (2026-10-19 신설 · 사용자 지시)**:
  - 운영계는 raw data 및 과거 데이터가 이미 있으므로, **백필(Backfill) 목적의 전 구간 재적재나 특정 기간을 지정하여 과거 데이터를 소급 적재하는 작업은 전부 건너뛴다.**
  - 예: `10_dbt_pipeline/02_dbt_parse_compile_build.sql` 의 `bigquery_dt_ranges` 전 구간 재적재(`1945-01-01~9999-12-31`), `15_MSTR 이관 PoC/snowflake 적용 ddl/06_MSTR_적재_실행.sql` 의 과거 34개월(`202401~현재월`) 루프 적재 등.
  - 운영계 배포 및 갱신 시에는 구조 배포(DDL) 및 정규 증분(일일/당월) 파이프라인만 수행한다.
- 실행 직전, 각 파일에 원천 쓰기 문장이 있는지 검사한다(§3 실행기에 내장). 걸리면 **실행하지 말고 멈춰 사용자에게 보고**한다.
- `GRANT ... ON ... SCHEMA GN_DW.BRONZE_*`(1번 파일)는 권한 부여일 뿐 데이터를 바꾸지 않으므로 허용한다.

0 commit comments
Comments
0
 (0)
```