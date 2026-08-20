<!-- SPLIT-CHUNK 99_NEXT_SESSION.md | 003/010 | 허브 = 99_NEXT_SESSION.md | 원문 278~401행 -->
<!-- 🔴 이 파일은 원문 무변경 조각이다. 편집은 허브 계약을 따른다 (scripts/split_doc.py --verify 로 바이트 동일성이 검사된다). -->
<!-- BODY-BEGIN (아래는 원문 무변경 · 편집 금지) -->
## 0-CCC. 🔴🔴 [2026-08-20 O90 필독 — ~~여기서 시작한다~~ **⇒ [O91 철회] 시작점은 위 §0-DDD 다**]

> 🔴🔴 **[2026-08-20 O91 철회 병기] 이 절의 ▣2「미실행·승인 필요」· ▣3「미이행」· ▣4「상위결정 미정」은 전부 stale 이다.**
> 세 건 모두 O91 에서 닫혔다(정본 = `50_dbt_…` §O91 · `30 §26 DEC-39`). 원문은 `R2-8` 로 보존한다.
> ⇒ 이 절은 **「무엇이 왜 막혀 있었나」의 원인 기록**으로만 읽어라. **현재 상태는 §0-DDD 다.**

> 🟢 **착수표 ② 가 완료됐다.** `07` 전량 실행으로 BRONZE GA4 가 적재됐다.
> 🔴 **그러나 ③ `dbt build` 는 RBAC 3건에 막혀 있다** — 실측으로 실패를 확인했다. 아래 ▣2 를 먼저 처리하라.
> 🔴 **§0-BBB 의 「② 는 다음 작업」 기재는 stale 이다**(O89 는 07 을 실행하지 않았다). 인용하지 마라.
> 상세 근거·좌표 정본 = `20_issue/02_상태상세_대시보드_갱신형.md` **§O90** ·
> RBAC 정본 = `20_issue/50_dbt_파이프라인_미결조치.md` **§O90**.

### ▣1 🟢 착수표 갱신 (2026-08-20 O90 실측)

| 단계 | 무엇 | 상태 |
|---|---|---|
| ① | 스테이지 업로드 | 🟢 충족 — **106폴더 / 817파일 / 8,100,866,944 B** |
| ② | `07` 전량 실행 | 🟢 **완료** — `BRONZE_BIGQUERY.EVENTS` **32,718,672행 / 106폴더 / 817파일** · **7장 (2-B) 0건** · 중복 0 · `EVENT_DT` NULL 0 |
| ③ | `dbt build` | 🔴 **차단 3건**(▣2). `SILVER.BIGQUERY_REFINED_DATA` 0행 · `GA4_EVENT` 0행 |

· 🔴 **세션 시작에 라이브를 다시 재라**(`P33`) — 위 수치는 2026-08-20 시점이다.
  `SELECT COUNT(*), COUNT(DISTINCT SRC_TABLE) FROM GN_DW.BRONZE_BIGQUERY.EVENTS;`
· ⚠️ 스테이지에는 3개월 90폴더 외 **16폴더**(비-6월 각 1일)가 있어 함께 적재됐다.
  `ga4_dt_ranges` 는 3개월뿐이므로 **SILVER 대상은 29,279,246행**이다(BRONZE ⊃ SILVER · 정상).
· 🔴 **`07` 을 다시 전량 실행하지 마라.** 재실행 자체는 파일 단위 스킵으로 안전하지만
  ③ 이 남아 있는 동안은 불필요하고, 10장을 되살리면 (2-B) 가 깨진다(▣3).

### ▣2 🔴🔴 최우선 = `dbt build` 차단 3건 (RBAC) — **여기서부터 하라**

실측 실패 = `EXECUTE DBT PROJECT … args='build --target dev'` →
`003001 (42501) … Your primary role GN_DW_ENGINEER must have CREATE SCHEMA granted on DATABASE 'GN_DW'`.

| # | 블로커 | 실측 |
|---|---|---|
| ㉠ | `GN_DW.dbt_test__audit` 스키마 부재 | `logs/dbt.log:455~460` · 테스트 **343노드**가 이 스키마 소속 |
| ㉡ | `GN_DW.SILVER` ENGINEER grant **전무** | FUTURE **0건** ↔ GOLD FUTURE **35건** 생존 |
| ㉢ | `GN_DW.OPS` **`USAGE` 누락** | `CREATE TABLE` 만 부여됨 |

🟢 **㉡ 원인 확정** = `ACCOUNT_USAGE.SCHEMATA` 에서 SILVER `SCHEMA_ID=44` 가 **`21:27:04.683` DELETED** 되고
`105` 로 재생성(`21:34:28.101`)됐다. ⇒ **스키마 재생성이 grant 를 지웠다**(순서 문제가 아니다 · O86 계열).
⚠️ **무엇이 드롭했는지는 미확정** — 추가 조사 대상(`TEARDOWN.sql` 의심).

**처방 = `GN_DW_ADMIN` 으로 8문장** (🔴 미실행 · 승인 필요):

```
CREATE SCHEMA IF NOT EXISTS GN_DW.dbt_test__audit COMMENT = 'dbt 테스트 실패 감사 — dbt 자동 생성 회피용 선생성';
GRANT USAGE, CREATE TABLE ON SCHEMA GN_DW.dbt_test__audit TO ROLE GN_DW_ENGINEER;
GRANT USAGE ON SCHEMA GN_DW.OPS TO ROLE GN_DW_ENGINEER;
GRANT USAGE, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE, CREATE FUNCTION ON SCHEMA GN_DW.SILVER TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON ALL TABLES IN SCHEMA GN_DW.SILVER TO ROLE GN_DW_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA GN_DW.SILVER TO ROLE GN_DW_ENGINEER;
GRANT INSERT, TRUNCATE, DELETE ON ALL TABLES IN SCHEMA GN_DW.SILVER TO ROLE GN_DW_ENGINEER;
GRANT INSERT, TRUNCATE, DELETE ON FUTURE TABLES IN SCHEMA GN_DW.SILVER TO ROLE GN_DW_ENGINEER;
```

· 🔴 **DB 레벨 `CREATE SCHEMA` 는 부여하지 마라** — `07 §D.6` 의 거부 판단은 옳다. audit 스키마를
  **선생성**하면 dbt 는 `create schema` 를 호출하지 않는다(SILVER 가 그 경로로 통과한 것이 증거다).
· 🔴 **`DELETE` 를 넣는 근거** = O87 `silver_purge` 가 range 모델에 **범위 DELETE** 를 낸다.
  `07 §D.5:297` 의 *"merge 없음 ⇒ UPDATE/DELETE 불요"* 는 **stale** 이다.
· 🟠 문서 수정 미이행 = `07_ENVIRONMENT_RBAC_setup.sql` **4건**(A~D) + `01_환경 Role.md` **3건**
  ⇒ 목록·근거 = `50_dbt_…` **§O90**.

### ▣3 🟢 `07` 결함 2건 — **이미 시정됨**(재발 감시만)

· **PATTERN 기재 오류** — O86 ④ 가 *"FROM 경로 상대"* 로 「정정」한 것이 **오히려 오류**였고 실제는
  **스테이지 루트 기준**이다. 그 결과 스모크가 `files=0 / rows=0 / errors=0`(0장 (4) 가 경고한
  조용한 실패)를 냈다. ⇒ 선행 `.*` + 스키마 명시로 시정(`07:633~654` 철회 병기).
  🟢 **교훈** = 「안전장치가 작동하는지 실측하라」(`P22`)의 변형 = **「정정이라고 쓴 것이 정말 정정인지 실측하라」.**
· **10장 1214행** `ALTER STAGE … SET DIRECTORY = (ENABLE = FALSE);` 가 **유일한 비주석 문장**이었다
  ⇒ 전량 실행 시 디렉터리가 꺼져 **(2-B) 재검증이 불가능**해진다. 주석 처리했다(`07:1217~1224`).
· 🔴 **라이브 프로시저 `SANDBOX.TOOLS.LOAD_GA4_EVENTS` 의 COMMENT 에 `[O89]` 가 남아 있다**
  (라벨 도용 잔존 · 파일은 `O90` 으로 정정됨). `CREATE OR REPLACE PROCEDURE` 로 정정 필요 = **미이행**.

### ▣4 🟠 GA4 원천 전환 — 사용자 신규 요구 · **상위 결정 미정**

사용자 제시 = `Untitled 4.sql` **119컬럼 고정 DDL**(`SILVER.BIGQUERY_REFINED_DATA` 재정의) ·
「다음주 Python 프로시저가 평탄화 담당」 · 「`BRONZE_BIGQUERY` 는 임시」 · 「dbt 는 `CREATE` 최소화·업데이트만」.

· 실측 델타 = 현 51컬럼 중 **41개가 새 DDL 에 같은 이름으로 없다.** `GA4_EVENT.sql:43~93` 이 **28개** 참조.
· 🔴🔴 **먼저 정해야 하는 상위 결정 = 메달리온 최하층 결손.** 원천이 SILVER 에 있고 BRONZE 가 임시면
  `04_silver_design/00_README:51` `P2`(`SERVING→GOLD→SILVER→BRONZE`)의 **최하층이 사라진다.**
  선택지 = ㉠ 프로시저 산출물을 **BRONZE 에 두고** SILVER 는 정제만 ㉡ **SILVER 를 원천 겸용으로 승인**(원칙 개정).
  ⇒ **어댑터 설계보다 상위다. 이것을 정하지 않고 코드를 고치지 마라.**
· 🟢 고정 DDL 유지 가능 근거 3개 — ① `EVENT_DATE VARCHAR` 는 `YYYYMMDD` 라 **사전순=시간순** ⇒ 리터럴
  문자열 범위 비교로 프루닝 유지(⚠️ 새 테이블 클러스터링은 **미측정**) ② `08:1023~1024` `SRC_TABLE`·
  `SRC_FILE_NAME` **NULL 허용** ⇒ 하류 5테이블 DDL 무변경 ③ `STSLC_MC_*`→`UTM_*` · `STSLC_CRC_*`→
  `XCHAN_*`/`DEFAULT_CHANNEL_GROUP` **1:1 완전 매핑**(설계의 last-click 단독 원칙과 일치).
· 🔴 **폐기된 제안 1건** = 「`EVENT_SEQ` 정렬 튜플을 `BATCH_EVENT_INDEX`+`EVENT_BUNDLE_SEQUENCE_ID` 로
  바꾸면 `GA4-SEQ-1` 을 닫을 수 있다」 ⇒ **실측 반증**(▣5).
· 🔴 리스크 = 금액·시각·세션ID 가 전부 `VARCHAR(16777216)` ⇒ `TRY_TO_NUMBER` 실패가 **조용한 NULL**
  (`P19`/`AD-4` 무증상 오답). DDL 고정이면 **영구화**된다 ⇒ 승인받을 리스크로 올려라.
· 🟢 균형 = 고정 DDL 은 저장 페널티가 없고 **`GA4-LEN-1`(길이 초과 실패) 유형이 구조적으로 불가능**해진다.
· 🟠 어댑터 뷰를 DDL 소유로 두려면 `dbt_project.yml:139~142`(*"뷰는 dbt 소유가 맞다"*)를 뒤집는
  **`DEC` 등재가 선행**돼야 한다(미이행).

### ▣5 🔴 통합대장 9행 `GA4-SEQ-1` — **등급 상향 필요** (실측 반증)

`BRONZE_BIGQUERY.EVENTS` 2025-06 **9,028,480행** 실측:

| 키 | 중복 행수 | 비율 |
|---|---|---|
| 3키 | 1,515,709 | 16.79% |
| 4키 +`batch_event_index` | 781,910 | 8.66% |
| **5키 +`event_bundle_sequence_id`** | **781,910** | **8.66% — 전혀 줄지 않음** |

· 두 컬럼 NULL **0건** ⇒ 값 자체가 중복이다. `ROW_NUMBER` 정렬 튜플 동일 행이 8.66% 남아 **비결정적**이다.
· 고정 DDL 로 가면 `SRC_FILE_NAME` 도 없어 **종전보다 나빠진다.**
· ⇒ §0-BBB 통합대장 9행의 **「🟠 급하지 않음」은 유효하지 않다.**

### ▣6 🔴 O90 자기검토 — 확정위반 **8** · 판정약점 **4** (`R4-4` ㉡ 적용 세션)

**반복하지 말 것 4개**(전문 = `02 §O90`):
· **`R1-3-7-c`** 판정 근거를 파일에 쓰지 않고 판정 — 세션 말미에 소급 기록했다. **순서를 지켜라.**
· **`R1-4-3`** 게이트 미실행 상태로 `07` 에 **`O89` 라벨 도용**(타 세션 = 후원사업 3계층).
  🔴 O89 도 같은 위반을 했다(`02 §O89`) ⇒ **3회 연속**이다. 라벨은 게이트 → 원장 선점 → 코드 순서다.
· **Step 0.8** 브리핑에 「미반환 0」을 자기신고 — 이후 실제로 ㉡ 가 발생했다. **시점을 명시하라.**
· **`R1-3`** `50_dbt_…` 13조각 중 2개만 읽고 판정. **`-013`(순서9-C = dbt build 선결조건) 미독.**

**미측정으로 남은 것 2개** = ⑩ 「OPS `USAGE` 없으면 store_failures 테스트 실패」 ⑪ 새 테이블
`EVENT_DATE` 클러스터링. ⇒ **인용하려면 먼저 재라.**

🟢 **닫힌 것**(다시 손대지 마라) = `07` 5판 PATTERN 시정 · 10장 주석 처리 · BRONZE 적재 + (2-B) 0건 ·
RBAC 3블로커 원인 확정 · `EVENT_SEQ` 대안 반증 · O90 라벨 정정 · 원장 §1·`02 §O90`·`50_dbt §O90` 등재.
