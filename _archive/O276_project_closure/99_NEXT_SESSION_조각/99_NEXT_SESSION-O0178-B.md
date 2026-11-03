<!-- LLM-METADATA
doc_id: HANDOFF_O0178_B
doc_role: 인수인계 — 세션 `O178-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-22
created_by: O178-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0178-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O178-B-0 🔴🔴 먼저 알아라 — 이 단위가 확정한 판정식

1. 🔴🔴 **개명은 「토큰 치환」이 아니라 「계보 판정」이다.**
   같은 문자열 `GA4` 가 **4가지**였다 = ⓐ 개명 대상 식별자 ⓑ **원천 시스템(Google Analytics 4) 서술**
   ⓒ 다른 계보의 실물 이름(`BRONZE_GA4`) ⓓ **역사 기록**(O130 이전 옛 모델명).
   🔴 일괄 치환하면 *「GA4 는 UTC/로컬 경계에서 오늘+1 이 섞인다」*처럼 **참인 문장이 거짓**이 된다.
   🟢 그래서 `_o130_ga4_rename.py`(O130 의 개명기)가 **절반만 개명한 상태**로 남아 있었던 것이다 —
   모델명은 `BIGQUERY_*` 로 갔는데 매크로·var·테스트가 `ga4_` 로 남았다. **절반 개명이 더 혼란스럽다.**

2. 🔴🔴 **「리터럴 값을 바꾸는 변경」에는 「전량 백필 의무」가 붙는다.**
   `DW_SOURCE_SYSTEM='GA4'` → `'BIGQUERY'` 를 모델에서 고쳤지만
   `RANGED_MODELS = ['BIGQUERY_EVENT','BIGQUERY_BASIC']` 은 **롤링 윈도우**이고 창이 비어 있었다
   ⇒ 그냥 build 하면 **10,332,737행 전건이 옛 값으로 남는다**(에러 0 · 무증상).
   🟢 `O177-A-2 #4`(컬럼 배선 후 백필 의무)와 **같은 class** 다 — 그쪽은 배선, 이쪽은 상수.
   🔴🔴 **판정식 = 증분 모델에서 「과거를 다시 쓰지 않는 변경」은 절반만 반영된다.**

3. 🟢🟢 **「`CREATE OR REPLACE` 는 GRANT 를 잃는다」는 FUTURE GRANTS 가 없을 때의 규약이다.**
   사용자가 `06_DDL.sql`+`08_SILVER_테이블DDL` 을 **전체 재실행**했고 나는 손실을 의심했으나
   **실측 손실 0** 이었다 — 스키마에 **FUTURE GRANTS(GOLD 35건)** 가 걸려 있어 재생성 테이블이
   자동으로 권한을 받는다(OWNERSHIP `GN_DW_ADMIN` 보존 · 5역할 전건 · 재부여 `23:03:08`).
   🔴 **단 뷰·SV 는 별도 축이다** — 이번엔 무사했으나 같은 근거로 일반화하지 마라.

4. 🔴 **파일 정본을 고쳤다고 라이브가 바뀌는 것이 아니고, 라이브를 바꾸는 방법이 하나가 아니다.**
   테이블레벨 COMMENT 5건은 **DDL 재실행 대신 `ALTER TABLE … SET COMMENT`**(메타데이터 전용)로
   전파했다. 🔴 DDL 재실행은 `CREATE OR REPLACE` 라 데이터를 파괴하고 그것이 `O178 ▣2` 사고의 기제다.

5. 🔴 **마운트가 세션 중에 재생성될 수 있다** — `cd /workspace/…` 가 `No such file or directory` 를
   냈고 python 이 **다른 스테이지 경로**를 찾았다. 파일이 사라진 것이 아니라 심링크가 재생성돼
   셸 `cwd` 가 낡은 inode 를 잡은 것이다. 🟢 **「파일이 없다」를 믿기 전에 마운트를 재라.**

### ▣ O178-B-1 🟢 이 단위가 끝낸 것

🔴 **상세 정본 = 이력 `§O178-B`**(원장 §1 `O178-B` 행은 색인이다). 사용자 결정 **6건**.

| 항목 | 결과 |
|---|---|
| `O178-A-2 #1` 종결 | 배포 런북 **Step 3-3** 신설(`deploy_dbt_project.sql:107-175`) · 두 쿼리 라이브 실증 |
| Task 위험 판정 | 🟢 **`TASK_DW_*` 부재 확정**(`SHOW TASKS` 0건 · 26종 전건이 Snowflake 시스템 Task) ⇒ **잠재** |
| 식별자 개명 | **18파일 / 103건** + 파일 **7개**(매크로 2 · 테스트 5) · `TOTAL 564 불변` |
| 고아 정리 | `OPS.WARN_GA4_*` **3테이블 DROP**(승인 · 전부 0행) ⇒ `OPS` 9 복귀 |
| 🔴 `DW_SOURCE_SYSTEM` | SILVER 7객체 `GA4`/`GA4+CRM` → **`BIGQUERY`/`BIGQUERY+CRM`** · `GA4` **0행** |
| 테이블레벨 COMMENT | `[원천: GA4 →]` **5건** → `BIGQUERY` · `ALTER … SET COMMENT` 로 전파 · 드리프트 **0 복귀** |
| 전량 재적재 검증 | 사용자 DDL 재실행 + build 후 **행수 전 축 기준선 일치** · GRANT 손실 **0** |

### ▣ O178-B-2 🟠 다음이 할 일 — ㉠ 이 작업의 잔여

1. 🔴🔴 **최우선 = `ADD VERSION` 재배포 1회**(build 불필요).
   파일은 백필 슬롯을 **잠갔으나**(`dbt_project.yml` `bigquery_dt_ranges` 주석 복귀)
   **배포된 DBT PROJECT 버전에는 아직 열려 있다.**
   ```sql
   USE ROLE GN_DW_ADMIN; USE WAREHOUSE GN_DW_DEV_WH;
   ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE
     ADD VERSION LOCK_BACKFILL_SLOT_20260922
     FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline';
   ```
   🔴 이것을 빠뜨리면 **다음 run 이 매번 전 기간을 재적재**한다(일일 배치를 켜면 낭비가 상주한다).
   🟢 검증 = 다음 build 의 `DELETE FROM … BIGQUERY_BASIC` 창이 `[오늘-3, 9999-12-31]` 인지
   `INFORMATION_SCHEMA.QUERY_HISTORY` 로 본다(⚠️ `ROWS_DELETED` 컬럼은 없다 · `ROWS_PRODUCED`).

2. 🟠 **`BRONZE_GA4` 개명 문항 작성** — 사용자 결정 ④ = **현황 유지**이나 명칭 정책과 어긋난 채 남는다.
   대상 = `BRONZE_GA4` 스키마 · `GA4_USER_DEMOGRAPHIC`(**45,569행**) · `SYNC_ERR_INFO`(0행).
   🔴 **우리가 개명하면 외부 Python 적재가 깨진다** ⇒ 적재 담당자에게 보낼 문항만 만든다.
   ⚠️ 이 계보는 `bigquery_refined_data` 와 **다르다**(GA4 인구통계 export) — 「유래」 판정을 다시 하라.

3. 🟠 **`_wide_schema.yml:669` 잔존 `GA4` 재판정** — 「원천 트랙이 GA4 다 … `GA4_USER` 정제 예정」.
   이번에 **유지**했다(그 트랙이 `BRONZE_GA4` 계보이므로 결정 ④ 해당). 🔴 phase-2 에서 그 모델을
   실제로 만들 때 이름을 무엇으로 할지가 **미결**이다(`BIGQUERY_USER` vs `GA4_USER`).

4. 🟠 **`O178-A-2` 잔여 승계** = `FACT_EVENT_ATTENDANCE.DATE_SK=0` **50**(정정 · 🔴🔴 [2026-09-22 O178-C 정정] 종전 기재 **162,888** 은 **재현되지 않는다** — 사용자가 `06_DDL`+`08_SILVER_테이블DDL` 전체 재실행 후 전량 재적재한 뒤 실측 = **50** 이고 문서20 §C 원 기재(`FEP.DATE_SK 50→0`)와 일치한다. 총행 **1,258,775** = 원천 `CRM_EVENT_PARTICIPATION` 과 **1:1**. 🔴 원인 미규명 — 후보 = GOLD 팩트 **5종**에 모델 리터럴 `pre_hook=TRUNCATE` 가 남아 있고 `gold_fact_purge` else 분기도 TRUNCATE 라 **hook 이 이중 실행**된다(`dbt_project.yml:239-244` 가 경고한 누적 구조) ⇒ 조사 대상.) ·
   `A4-W` 배선 6건(🔴 배선 후 전량 백필 의무 — 위 판정식 2와 **같은 절차**) ·
   `bigquery_lookback_days` 재검토 · 2단계 DISTINCT 차원 MERGE(운영 일일 런 실측 선행) ·
   `MUTATES` 무플래그 **기지목록 11건** 처분 · `AGE` COMMENT CM014 정정 3테이블 ·
   PII 전제 기록 · `stage_mount_size_gate` 드리프트 8건 처분.

### ▣ O178-B-3 ⚪ 이 세션의 소관이 아닌 것 — ㉡ 워크스페이스 백로그

🔴 **`O178-A-3` 을 그대로 승계한다**(좌표 = `99_NEXT_SESSION_조각/99_NEXT_SESSION-O0178-A.md:96`).
· 현업 회신 대기 8건(`§N-13` 교체본 · `§N-18` · `§N-17` · `§M-2` · `§M-6` · `Q10` 등 · 🔴 `J3` 로 실측 선행)
· `V1` `ML_RST_DATA_SPNSR_CHURN_12M` **0행** = 외부 적재기 소관(형제 91,423행 · 동일 배치)
· §4 밖 미결 결정 2건(개명 런북 3안 · 스킬 본문 분할) · `decision_closure_gate` 미봉합 2건
· `O167` 이력 항목 부재 · `DEC-44` 붕괴 재현 실패 · 정보량0 잔여 · 미정의 `P` 334종
· 🔴 착수표 ⑭·⑩ 무변경

### ▣ O178-B-4 🔴 환경 함정 (이번에 실제로 밟은 것)

· 🔴🔴 **마운트 재생성** — `/workspace` 심링크가 `05:35` 에 다시 만들어져 셸 `cwd` 가 낡았다.
  증상 = `cd` 실패 + python 이 `user__public_default_` 경로를 찾음. 🟢 처방 = 스테이지 실경로
  `/snowflake/stages/user__public__snowflake_files_` 로 `cd` 를 다시 잡는다.
· 🔴 **`edit` 툴 `replace_all` 이 동일 장문 줄 2곳에서 듣지 않았다**(「multiple times」 거절)
  ⇒ 🟢 **python 줄 인덱스 치환**(`R1-7-8` 이 이미 권하는 경로) · 백틱 포함이라 `_scratch_` 파일 경유.
· 🔴 **`grep --include` 를 또 썼다** — BusyBox 미지원. `O176-A-4` 기재 함정 **2회 답습**이다.
· 🔴 `SHOW SEMANTIC VIEWS … IN SCHEMA GN_DW.GOLD` → 0건. **SV 는 `GN_DW.SERVING`** 에 있다.
· 🟢 스테이지 파일 크기는 **16 B 패딩**된다(30,857 → 30,864) — 불일치로 오판하지 마라.
· 🟢 `INFORMATION_SCHEMA.QUERY_HISTORY` 의 **렌더된 술어**가 「어느 버전이 돌았는가」의 유일한 증거다.

### ▣ O178-B-5 📏 종료 기준선 (2026-09-22 · 계정 `LK96056` · 🔴 인용하지 말고 재라)

· dbt build **PASS 527 / WARN 37 / ERROR 0 / TOTAL 564**(개명 전후 불변)
· `DW_SOURCE_SYSTEM` = SILVER 7객체 **BIGQUERY**(XREF `BIGQUERY+CRM`) · GOLD **BIGQUERY** · **`GA4` 0행**
· `BIGQUERY_BASIC`·`EVENT` **10,332,737 / 33일** · `FACT_BIGQUERY_BEHAVIOR` **1,620,857**
· `FACT_MEMBER_EVENT` **4,716,360** · `FACT_BUDGET` **1,332** / `_YEARLY` **111** ·
  `FACT_MESSAGE_DISPATCH` **41,969,590** · `DIM_DATE` **73,414 + 1** · `DIM_MONTH` **2,413** · `WIDE_*` **14**
· `OPS` **9테이블** · 감시 5종 **전부 0행** · 🟢 `WARN_GA4_*` 3테이블 DROP 완료
· `comment_drift_gate` **rc=0** = 746/746 · 892/892 · 뷰 **574/574** · 테이블레벨 37/37 · 47/47 · 금지문안 0
· `dbt_schema_lint` **3,228 rc=0** · `doc_coord_gate` 깨진 좌표 **0** · `line_len` PASS
· GRANT = GOLD **FUTURE GRANTS 35** · `FACT_BIGQUERY_BEHAVIOR` **20** · `SV_SERVICE` **7**(전건 보존)
· 🔴 **배포 버전에 백필 슬롯이 열려 있다** — `ADD VERSION` 1회 미이행(`▣2 #1`)
· 🔴 `BRONZE_GA4` 는 **현황 유지**(사용자 결정 ④) — 개명하지 마라
· 🔴 `SILVER.BIGQUERY_REFINED_DATA` DDL 은 **현업 제공 · 불변**(사용자 확정) — 고치지 마라

_Co-authored with CoCo_

_Co-authored with CoCo_
