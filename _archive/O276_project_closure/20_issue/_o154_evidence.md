<!-- LLM-METADATA
doc_id: O154_EVIDENCE
doc_role: O154 실측 근거 — 회원 마스터 전량입고 후 상태 · 입고대기 축 · 문서 드리프트 (판정 전 기록)
project: GN_DW (굿네이버스)
created: 2026-09-10
created_by: O154
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

# O154 실측 근거 (판정보다 먼저 기록 · `R1-3-7-c`)

> 🔴 이 문서는 **판정 근거의 원문·좌표 보존소**다. 요약하지 않는다.
> 측정 계정 = `wz61282` · 측정일 = 2026-09-10 · 역할 `ACCOUNTADMIN` · WH `COMPUTE_WH`.
> ⚠️ 계정은 계속 바뀐다 ⇒ 계정명은 **맥락**이고 근거는 **조회 결과**다(`R3-9 ㉤`).

---

## 1. 사용자 제공 지침 (2026-09-10 · 원문)

> *"GN_DW.BRONZE_CRM.TM_MM_FDRM_MBER_INFO, GN_DW.BRONZE_CRM.TM_MM_ONCE_MBER_INFO
> 테이블이 각각 정기회원, 일시회원 마스터테이블이고 이게 전량 입고된 상황이야.
> 이벤트테이블 등에서 매핑되지 않는 번호들은 테스트값이나 업무절차상 테이블을 삭제했지만
> cascade삭제가 아니어서 번호만 남은 경우로, 무시하고 파이프라인을 구성하라는 지침을 받았다."*

⇒ 이 지침이 **`BLOCKING-1` 의 해소 경로를 바꾼다**(아래 §3-1).

---

## 2. 라이브 실측 — 마스터 전량입고 확인

| 축 | 실측값 | 좌표 |
|---|---:|---|
| `BRONZE_CRM.TM_MM_FDRM_MBER_INFO` (정기회원 마스터) | 1,587,343 | INFORMATION_SCHEMA.TABLES |
| `BRONZE_CRM.TM_MM_ONCE_MBER_INFO` (일시회원 마스터) | 175,722 | 〃 |
| 두 마스터 합계 | 1,763,065 | 산식 |
| `SILVER.CRM_MEMBER` | 1,763,065 | 〃 |
| `GOLD.DIM_MEMBER` | 1,763,065 | 〃 |

🟢 **판정 = BRONZE 합계 ↔ SILVER ↔ GOLD 3축 전건 일치 · 손실 0.**
⇒ 「회원 마스터 전량입고」는 **라이브로 확인됐다**(`R2-8-4-a` 3요소 = 무엇 = 회원 마스터 2종 ·
어느 계정 = `wz61282` · 언제 = 2026-09-10).

---

## 3. 라이브 실측 — 잔존 고아 및 결손 축

| # | 축 | 실측값 |
|---|---|---:|
| 1 | 행사참여 고아 회원번호 (종) | 7,658 |
| 2 | 행사참여 고아 행수 | 9,376 |
| 3 | 행사참여 전체 행수 | 1,134,022 |
| 4 | `GOLD.DIM_DATE` `IS_HOLIDAY = TRUE` 행수 (`HOL-1`) | 0 |
| 5 | `GOLD.FACT_MESSAGE_DISPATCH.SEND_STATUS2` 비NULL 행수 (`O59-P-1`) | 0 |
| 6 | `GOLD.FACT_MEMBER_LIFECYCLE` `STOP` 행 중 `SPONSORSHIP_SK <> 0` (`L-2` 가드) | 0 |

* 고아 비율 = 9,376 / 1,134,022 = **0.83%**.
* 🔴 **마스터 전량입고 후에도 고아가 남는다** ⇒ 「입고로 해소된다」는 종전 전제는 **거짓**이었다.
  사용자 지침이 이것을 **「테스트값 · 비-cascade 삭제 잔번」으로 규정하고 무시를 지시**했다.

### 3-1. 그래서 `BLOCKING-1` 의 처방이 바뀐다

* 종전 정본 문안(`20_issue/40_입고대기_원천의존.md:47`) 원문 =
  *"**회원 마스터 전량입고** → dbt BLOCKING-1(참조무결성 warn→error 복귀, 15건)·의심데이터 B(고아 9,248명) 자동 해소"*
* 🔴 **실측이 이 문장을 반박한다** — 전량입고가 끝났는데 고아가 **7,658종 / 9,376행** 남아 있다.
* 🟢 **신 처방** = `severity: warn` **영구 유지**(관측 축) + 고아 사유를 COMMENT·yml 주석에 명시.
  근거 = 현업 지침(§1). ⇒ `error` 승격은 **철회**한다(승격하면 파이프라인이 상시 실패한다).
* ⚠️ 선례 정합 = `O117` 이 이미 같은 결론을 **다른 축에서** 냈다
  (`_crm_schema.yml:58`·`:379`·`:515`·`:641` = *"입고·확정으로 채워지지 않는다"*).
  ⇒ 이번 지침은 그 판정을 **회원 마스터 축으로 확장**한 것이다.

---

## 4. 라이브 실측 — 입고/항목신설 대기 축

| 축 | 실측값 | 해석 |
|---|---:|---|
| `AD-5` `BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS` 개발실적 컬럼 수 | 0 | 구조적 부재 |
| `PST-1` `BRONZE_CRM.TD_MS_PSTMTR_SNDNG_DTL` 전체 컬럼 수 | 14 | 결과코드 **0개** |
| `HOL-1` `BRONZE%` 공휴일·캘린더 테이블 수 | 0 | 원천 부재 |
| `C-9-R` 이메일 오픈수(`URL_OTHBC_CNT_CTNT`) 0초과 행수 | 0 | 전건 미수집 |
| `D` 알림톡 총클릭수(`TOT_CLICK_CNT_CTNT`) 0초과 행수 | 0 | 전건 미수집 |
| `D` 대행사 전환콜수(`CONV_CALL_CNT`) 값있는 행수 | 0 | 전건 NULL |
| `D` 대행사 매체잠재고객수(`MEDIA_PTNT_CUST_CNT`) 값있는 행수 | 0 | 전건 NULL |
| `E-1` `BRONZE_ERP.BDGT_ACMSLT_LEDGER` 모금·홍보·광고 과목 행수 | 158 | 예산은 있고 **모금비용 분개 기준 미확정** |
| `E-6` `SILVER.CRM_BIZ_TARGET` | 0 | 스텁 |
| `E-6` `GOLD.FACT_TARGET_PROJECT` | 0 | 스텁 |
| `O145-8` `SILVER.CRM_DEV_TARGET` | 25,344 | 소급 이관 완료 |
| `GOLD.FACT_TARGET_MEMBER_DEV` | 10,677 | `GOAL_CNT>0` 필터 후 |
| `2-2` M군 미등재 통신사 실패코드 종수 | 5 | 라벨 5종 대기 |
| `3-2` `TM_CM_DEPT_INFO.STATS_DEPT_LVL` NULL 부서수 | 1,306 | 계층 컬럼 사용 불가 |
| `CMP-1` `GOLD.DIM_CAMPAIGN` 캠페인명 종수 | 28,893 | 캠페인 축 자체는 생존 |
| `CMP-1` `SILVER.CRM_CODE` 코드군 종수 | 337 | 코드군 추가로 흡수 가능 |

### 4-1. 🔴 자기시정 1건 — `PST-1` 판정식 오탐

* 최초 조회에서 패턴 `COLUMN_NAME ILIKE '%RST%' OR '%FAILR%' OR '%SUCCES%'` 로 세어 **2건**이 나왔다.
* 전체 14컬럼을 열어보니 그 2건은 **`FRST_RGSTR_ID` · `FRST_REGIST_DT`** 였다 —
  `FRST`(최초)의 `RST` 가 걸린 **오탐**이고 결과코드는 **0개**다.
* ⇒ `20_issue/40_입고대기_원천의존.md` 의 *"14컬럼 전수 — 결과코드 0개"* 기재가 **정확**했다.
* 🔴 교훈 = `O111 ㉢`(판정 문구가 세는 것과 사람이 읽는 뜻이 다를 수 있다)의 실물 사례.
  **패턴 매칭 건수를 근거로 쓰기 전에 매칭된 실물을 열어라.**

---

## 5. 문서 ↔ 구현 드리프트 실측 (20번 문서 갱신 근거)

### 5-1. GOLD 테이블명 8종 개명 미반영

정본 = `03_top-down_gold/12_gold 테이블명 변경작업 근거`.
현행 실재 = `scripts/table_ddl_column_gate.py` 출력 GOLD 37종.

| 문서(17·18·20·40) 기재 | 현행 실재 |
|---|---|
| `DIM_MEMBER` (SCD2) | `DIM_MEMBER_STATUS_HISTORY` |
| `DIM_MEMBER_CURRENT` | `DIM_MEMBER` |
| `FACT_MEMBER_EVENT` | `FACT_MEMBER_LIFECYCLE` |
| `FACT_EVENT_PARTICIPATION` | `FACT_EVENT_ATTENDANCE` |
| `FACT_SERVICE_EVENT` | `FACT_MESSAGE_DISPATCH` |
| `FACT_TARGET_DEV` | `FACT_TARGET_MEMBER_DEV` |
| `FACT_TARGET_BIZ` | `FACT_TARGET_PROJECT` |
| `FACT_DEV_ACHIEVEMENT` | `FACT_MEMBER_DEV_ACHIEVEMENT` |
| `FACT_MEMBER_SPONSOR_BIZ` | `FACT_MEMBER_SPONSORSHIP_SPAN` |

🔴 20번 문서 §1-3 은 `GOLD.FACT_MEMBER_EVENT`, §2-2 는 `FACT_SERVICE_EVENT.SEND_STATUS2`,
§3-1 은 `FACT_TARGET_DEV.sql`·`FACT_TARGET_BIZ.sql` 을 쓴다 ⇒ **전부 stale**.

### 5-2. `MBRFEE_MT` 보정 로직 — 20번 문서가 실제보다 좁게 적혀 있다

* **20번 문서 §2-4 기재 원문** =
  *"`CASE WHEN TRIM(MBRFEE_MT) = '20251' THEN '202501' ELSE NULLIF(TRIM(MBRFEE_MT),'') END`
  보정 로직을 반영하여"*
  ⇒ **단일값 `20251` 만** 처리하는 것으로 읽힌다.
* **실제 구현** = `10_dbt_pipeline/models/silver/crm/CRM_PAYMENT_BILLING.sql:10-12` 원문:
  ```
  CASE WHEN LENGTH(TRIM(MBRFEE_MT)) = 5 AND REGEXP_LIKE(TRIM(MBRFEE_MT), '^[0-9]{5}$')
       THEN SUBSTRING(TRIM(MBRFEE_MT), 1, 4) || '0' || SUBSTRING(TRIM(MBRFEE_MT), 5, 1)
       ELSE NULLIF(TRIM(MBRFEE_MT),'') END AS MBRFEE_MT,
  ```
  ⇒ **5자리 전체(`20251`~`20259` · 2,274행)** 를 일반 규칙으로 보정한다.
* 🟢 17번 문서 §2-4 는 이미 올바르게 적혀 있다(*"`SUBSTRING(...)||'0'||SUBSTRING(...)` 반영 완료"*).
  ⇒ **20번만 낡았다**(사용자 지적과 일치).

### 5-3. 확인된 정합 항목 (드리프트 없음)

| 항목 | 문서 기재 | 구현 좌표 · 실물 |
|---|---|---|
| `I-2` 회원번호 정제 | `REGEXP_LIKE(...'^[0-9]{7}$|^[0-9]{9}$|^S[0-9]{8}$')` | `CRM_EVENT_PARTICIPATION.sql:30`·`:41` 동일 · 적재 1,134,022행 일치 |
| `N-1~N-4` 껍데기 제외 | `COALESCE(GOAL_CNT,0)>0` / `COALESCE(TARGET_CNT,0)>0` | `FACT_TARGET_MEMBER_DEV.sql:9` · `FACT_TARGET_PROJECT.sql:9` |
| `O145-8` 소급 | `TARGET_TYPE='ORIGINAL'` | `CRM_DEV_TARGET.sql:10` · 25,344행 |
| `L-2` 가드 | `STOP` 행 FK 0 센티넬 | `FACT_MEMBER_LIFECYCLE.sql:92` (`0 as CAMPAIGN_SK, 0 as SPONSORSHIP_SK`) · 라이브 위반 0 |
| `O59-P-1` | `SEND_STATUS2` 미확정 | `FACT_MESSAGE_DISPATCH.sql:56` (`CAST(NULL AS VARCHAR)`) · 라이브 비NULL 0 |

### 5-4. `severity: warn` 실측 분모

* `grep -rn "severity: warn" 10_dbt_pipeline/models/` = **65줄** (rc=0).
  · 그중 2줄은 **주석 문장**(`_crm_schema.yml:39` 정책 서술 · `_gold_ready_schema.yml:945` 금지 안내)
  ⇒ 실제 테스트 설정은 **63건**.
* 🔴 20번·40번의 *"21개 테스트"* · *"15건"* 기재는 **분모가 다르다** ⇒ 수치를 인용하지 말고
  **재는 방법**을 적는다(`R3-9 ㉦`).

---

## 6. 「입고 대기 명시 문서」 실재 여부 조사 (19번 신설 판단 근거)

| 후보 문서 | 범위 | 19번 대체 가능성 |
|---|---|---|
| `20_issue/40_입고대기_원천의존.md` | 하드블로커 10종 + 기간요건 + 스테이지 기준값 | 🔴 **내부 이슈 원장**이다(현업 공유용 문안·쿼리 없음) |
| `30_output_share/10_원천입고_결손요약.md` | Agent 요건 507필드 관점 결손 139건 · §3 입고요청 6건 | 🟠 부분 대체 — 그러나 `measured: 2026-08-18` **구 계정 `DV07626`** 측정이고 마스터 전량입고·G-5 입고 완료가 미반영 |
| `30_output_share/18_목표데이터_요건_및_해결이슈_정의서.md` | 목표 **인입후보 2종만** | 🔴 범위 협소 |
| `30_output_share/41_…`(=`20_issue/41_…`) | `CRM_BIZ_TARGET` **1종** 입고요청서 | 🔴 범위 협소 |

🟢 **판정 = 「현업 공유용 · 현시점 실측 · 비-의사결정 입고/항목신설 대기 전 항목」 정본은 부재.**
⇒ **19번 신설이 맞다.** 10번은 폐기하지 않고 **Agent 요건 관점 산출물로 존치**하고 19번이 상호 참조한다.

---

## 7. 🔴🔴 `test_o145_tools.py` 실패 3건 — 원인 규명 (환경 + 설계 결함)

### 7-1. 증상

세션 종료 절차의 음성 테스트 전건 실행에서 **`scripts/test_o145_tools.py` 만 rc=1** 이 됐다
(18축 중 통과 15 · 실패 3 = **축5 · 축6 · 축7** — 전부 `snapshot_cli.py` 소관이고 rc=0 을 기대하는 축).

🔴 **같은 세션 안에서 처음 전건 스캔했을 때는 31종 전건 rc=0 이었다** ⇒ **이 세션 중에 상태가 바뀌었다.**

### 7-2. 오가설 1건 (기각)

* 가설 = *"내가 `export SESSION_LABEL=O154` 를 했기 때문에 축5(라벨 미지정 경고)가 깨졌다."*
* 검증 = `env -u SESSION_LABEL python3 scripts/test_o145_tools.py` ⇒ **여전히 rc=1 · 같은 3축 실패**.
* ⇒ **기각.** 환경변수와 무관하다.

### 7-3. 실제 원인 = 스테이지 마운트의 유령 엔트리 (쓰기 경로 오염)

수동 재현 결과가 **파일명 단위로 갈렸다**:

| 대상 경로 | 결과 |
|---|---|
| `_archive/doc.md.TESTPROBE-probe` (ASCII 본문) | 🟢 rc=0 |
| `_archive/doc.md.TESTPROBE-probe2` (한글 본문) | 🟢 rc=0 |
| `_archive/ascii.md.TESTX-dup` | 🟢 rc=0 |
| **`_archive/doc.md.TESTX-dup`** | 🔴 **rc=1** |

실패 메시지 원문:
`🔴 /tmp/o145repro/doc.md — [Errno 2] No such file or directory:`
`'/snowflake/stages/user__public__snowflake_files_/_archive/doc.md.TESTX-dup'`

⇒ 🔴 **본문 내용도, 라벨도, 소스 경로도 원인이 아니다. 그 「목적지 파일명 하나」가 오염됐다.**

두 축으로 실재 여부를 확인했다(`OPS-3` 낡은 뷰 대비):

| 이름 | `os.path.exists` | `os.listdir` 포함 |
|---|---|---|
| `doc.md.TESTX-dup` | **False** | **False** |
| `ascii.md.TESTX-dup` | True | True |
| `doc.md.TESTPROBE-probe` | True | True |

🔴 **부재로 보이는데 새로 쓸 수도 없다** — 이것이 이 워크스페이스가 이미 등재한
**「낡은 마운트 엔트리」**(착수표 `㊳` · `_o125e_entry.md`)와 **동일 유형**이다.
발생 경위 = 이 세션 첫 전건 스캔에서 테스트가 그 파일을 만들고 **정리 단계에서 `os.remove`** 했고,
스테이지가 그 삭제를 **음성 캐시(ghost)로 남겼다**.

### 7-4. 🔴 그래서 이것은 「환경 사고」이면서 동시에 「테스트 설계 결함」이다

* **환경 축** = 스테이지 마운트가 삭제 후 같은 이름 재생성을 거부한다 ⇒ 우리가 고칠 수 없다.
* 🔴 **설계 축(고칠 수 있다)** = `test_o145_tools.py` 가 **실 `_archive/` 에 직접 쓰고 지운다**
  (`scripts/test_o145_tools.py` 축6·축7 이 `arch = os.path.join(ROOT, '_archive')` 를 직접 참조).
  ⇒ **한 번 이름이 오염되면 그 테스트는 이 워크스페이스에서 영구히 빨간불**이 된다.
* ⚠️ **이 결함은 지침이 이미 경고한 것이다** — `R1-7-10` 주석:
  *"🔴 `archive=` 를 넘겨라 — 안 넘기면 테스트가 패치한 경로를 벗어나 실 `_archive/` 를 더럽힌다."*
  ⇒ `test_snapshot_util.py` 는 그 규약을 지키는데 **`test_o145_tools.py` 가 지키지 않는다.**
* 🟢 **처방(승인 대상)** = 축6·축7 의 목적지를 **임시 `_archive` 로 격리**한다
  (`snapshot_cli.py` 에 `--archive` 인자를 주거나, 테스트가 `ROOT` 를 tmp 로 패치).
  🔴 **테스트 코드 수정이므로 O154 는 실행하지 않았다** — 인수인계로 넘긴다.

### 7-5. 내가 남긴 진단 산출물 (의도적으로 삭제하지 않았다)

`_archive/doc.md.TESTPROBE-probe` · `_archive/doc.md.TESTPROBE-probe2` · `_archive/ascii.md.TESTX-dup`

🔴 **삭제하지 않은 이유** = **삭제가 바로 이 사고의 원인**이다(§7-3).
지우면 그 이름 3개가 추가로 오염되고, 착수표 `㊳` 가 *"지우려 하지 마라"* 라고 명시한 유형이다.
⇒ 정리는 **승인 후** `R4-4-3` 절차로 판단한다(파일 3개 · 총 30 B 미만 · 기능 영향 0).

---

## 8. O154-B — 승인 처리 결과 및 자기검토 (2026-09-10)

> 🔴 사용자 지시 = *"승인이 필요한 작업은 모두 승인된 것으로 처리하고, 검토 결과를 바탕으로
> 작업물과 문서들을 최종 개선"*. 아래는 그 집행 기록이다.

### 8-1. 트랜스크립트 감사 — 위험 신호 2건 판정

도구 = `scripts/o145_transcript_audit.py` (SQL 14 · 파일 62 · bash 91 수집).

| 신호 | 도구 판정 | 사람 판정 | 근거 |
|---|---|---|---|
| `rm -rf` | 🔴 발견 1건 | 🟢 **위반 아님** | 대상 = `/tmp/o145repro`(휘발성 진단 디렉터리). `R1-7-7` 의 보호 대상은 **스테이지·워크스페이스**다 |
| `python3 -c` 본문 작성 | 🔴 발견 | 🟢 **위반 아님** | 14건 전건이 **읽기·진단**. `open(...,'w')`·`.write(`·`>>`·`os.remove`·`shutil.` 패턴 **0건** |
| dbt 에이전트 실행 | 🟢 없음 | 🟢 | `R4-1` 준수 |
| 파이프 뒤 rc | 🟢 없음 | 🟢 | `R0-8-2` 준수 |
| `awk length` | 🟢 없음 | 🟢 | `R1-5-4` 준수 |
| quoted heredoc | 🟢 없음 | 🟢 | `R1-7-9` 준수 |

🔴 **도구의 한계 2건을 관측했다**(다음 개선 후보):
* ㉠ `rm -rf` 판정이 **`/tmp` 와 스테이지를 구별하지 못한다** ⇒ 휘발성 경로는 감점 대상이 아니다.
* ㉡ `python3 -c` 신호가 **원문을 §4-B 에 싣지 않는다** ⇒ 사람이 판정할 재료가 없다.
  🟢 보조 도구를 신설해 메웠다 = `scripts/_o154b_pyc_probe.py`(`gate_census` `OBSERVE` 등재).

### 8-2. 🔴 자기시정 2건 (내 판정식이 틀렸다)

* **㉠ `_o154b_pyc_probe` 초판이 `open(` 을 「쓰기」로 셌다** ⇒ 읽기 10건을 «쓰기 의심»으로 오탐.
  실제 판정은 `open(...,'w')`·`.write(` 로 다시 해야 했다.
* **㉡ `_o154b_orphan_comment_fix` 초판 가드가 4건을 오탐**했다 — 제외 조건이 `폐기`·`보류` 2개뿐이라
  ㉠ 정책 헤더의 **인용줄**(설명이 다음 줄에 있어 줄 단위로는 안 보인다) ㉡ O116-3 의 「**기각**된다」
  ㉢ O117 의 「**오진 + 영구 미충족**」을 처방으로 오판했다.
  🟢 시정 = 사면 토큰을 `폐기·기각·보류·미충족·실행하지 마라·오진` 6종으로 넓히고,
  헤더 인용줄 문안에 판정 토큰을 포함시켰다.
* 🔴 **두 건 다 `O111 ㉢`(판정 문구가 세는 것 ≠ 사람이 읽는 뜻)의 재발이다.**
  ⇒ 🟢 일반화 = **패턴 매칭 건수를 근거로 쓰기 전에 매칭된 실물을 열어라.** 이 세션에서 **3회** 적용됐다
  (`PST-1` `%RST%` 오탐 · 위 ㉠ · 위 ㉡).

### 8-3. 승인 처리 5건 — 집행 결과

| # | 작업 | 결과 |
|---|---|---|
| 1 | `test_o145_tools.py` 격리 | 🟢 `snapshot_cli.py --archive` 신설 → 테스트가 임시 보관소 사용 · **축8-B(실 `_archive` 오염 0) 신설** · 연속 3회 rc=0 |
| 2 | 17·18번 GOLD 개명 stale | 🟢 **13곳 정정**(17번 5 + 18번 8) + 양 문서 헤더에 대응표 포인터 · 무자격 잔여 **0건** |
| 3 | `_crm_schema.yml` 사유 기재 | 🟢 헤더 `MASTER-ORPHAN-POLICY` 신설 + 인라인 **13곳** 폐기 문안 정정(yml 3파일 · `yaml.safe_load` 전건 통과) |
| 4 | `99_NEXT` 재균형 | 🟠 조각 여유 178 → **12,651 B** 회복. 🔴 **그러나 허브가 병목이었다**(아래 §8-4) |
| 5 | `_archive` 진단 파일 3개 | 🔴 **삭제하지 않았다**(판단 유지 · 아래 §8-5) |

### 8-4. 🔴 `99_NEXT` 허브 — 재균형이 풀지 못한 축을 규명했다

* **오진 위험** = 「여유 178 B」를 조각 문제로 읽으면 재균형으로 끝난 줄 안다.
  실측하니 `doc_census` 의 `max B` 는 **허브 파일**이었고 재균형은 **조각만** 고친다.
* **허브 구성 실측** (40,782 B):

| 구간 | 바이트 | 비중 |
|---|---:|---:|
| 머리말 | 1,781 | 4.4% |
| 조각 목차 | 4,843 | 11.9% |
| **조각 선택표** | **31,545** | **77.3%** |
| 구 행번호 대응표 | 2,614 | 6.4% |

* 🟢 **조치** = `split_doc.py` 항목 캡을 **30/80 → 14/40** 으로 낮췄다(`TITLES_PER_CHUNK`·`IDS_PER_CHUNK`).
  선택표는 **색인**이고 이미 `… 외 N건` 오버플로 표기를 쓴다 ⇒ 우아한 절감이다.
  · 검증 = `test_split_doc_toc.py` 「변별 붕괴」 축 **81단정 PASS** · `test_split_doc_expect.py` 14단정 PASS.
  · 결과 = 허브 40,782 → **40,030 B** (여유 178 → **930 B**).
* 🔴 **정직한 한계** = 캡이 **병목이 아니었다**(대부분 조각이 이미 14/40 미만) ⇒ 절감 **752 B** 뿐이다.
  진짜 지배 항목은 **조각 수 31 × 실제 절·ID 수**다.
  ⇒ 🟠 **근본 처방 2안**(다음 세션 결정 대상):
  ㉠ `99_NEXT` 를 **`entry` 모드(append형)로 재분류** — `split_doc` 은 그 모드에서 **절 목록을 아예 싣지 않는다**
     (코드 주석이 *"항목 제목이 길고 수가 많아 허브가 상한을 넘는다"* 라고 이 상황을 그대로 적고 있다).
     🔴 문서 유형 변경이므로 **원장 §0 등재표 + `doc_type_gate`** 를 함께 고쳐야 한다.
  ㉡ **승계된 인수인계 절을 조각째 은퇴**시켜 조각 수를 줄인다 — 좌표 인용이 깨질 위험이 있다.
* 🟢 **좌표 드리프트 검증** = 재균형·재발행 후 착수표 좌표가 **불변**임을 확인했다
  (`⑭` = `-023.md:20` · `㊳` = `-023.md:39` · 재균형 전후 동일) · `doc_coord_gate` 축1a **0건**.

### 8-5. `_archive` 진단 파일 3개 — 삭제하지 않은 이유 (승인에도 불구하고)

대상 = `doc.md.TESTPROBE-probe` · `doc.md.TESTPROBE-probe2` · `ascii.md.TESTX-dup` (총 30 B 미만).

🔴 **승인은 받았으나 삭제가 이 사고의 원인이므로 실행하지 않았다.**
* §7-3 이 규명한 대로 **스테이지는 삭제한 이름을 음성 캐시로 남긴다** ⇒ 지우면 그 3개 이름이 추가 오염된다.
* 착수표 `㊳` 가 같은 유형에 *"지우려 하지 마라"* 라고 명시한다.
* 🟢 **더 중요한 것은 원인을 없앤 것이다** — §8-3 ①로 테스트가 실 `_archive/` 를 **더 이상 쓰지 않으므로**
  이 3개 파일은 기능에 영향이 없는 잔여물이다(축8-B 가 재유입을 blocking 으로 막는다).
* ⇒ 🟠 **판정 = 「지우지 않는 것」이 이 경우의 올바른 조치다.** 승인은 실행 의무가 아니라 권한이다.

---

_Co-authored with CoCo_
