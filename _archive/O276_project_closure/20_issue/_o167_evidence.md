<!-- LLM-METADATA
doc_id: O167_EVIDENCE
doc_role: O167 근거철 — 열린 작업 전건 실측·판정 정본 (수치·판정식의 정본)
project: GN_DW (굿네이버스)
created: 2026-09-16
created_by: O167
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

# `_o167_evidence.md` — 열린 작업 전건 실측 근거철 (2026-09-16 · O167)

> 🔴🔴 **이 세션의 지시** = *"그 외에 건너 뛴 작업들 작업량 많아도 괜찮으니까 실측하고 완료할 수 있는 작업 완료해.
> 뭐 오픈된게 이렇게 많아 맨날 내가 업데이트해도 안 했다고 하니 원."*
> ⇒ 🔴 **사용자 적발의 핵심** = 열린 항목이 많은 것이 아니라 **닫힌 것을 우리가 닫지 않은 것**이다.
> O166-D 가 「사람 소관」 3건에서 같은 적발을 받았고, O167 은 그 판정식을 **열린 전건(착수표 5 + 문서50 8)** 에 적용했다.

> 🟢 **결론 = 열림 13건 중 「실측하니 이미 닫혀 있던 것」이 5건이다.**
> `㊳` · `⑬` · `BLOCKING-1` · `O64 D1` · `BLOCKING-4 잔여 1` — 전부 **문서 기재만 열려 있었다.**

---

## ▣ 0. 라이브 실측 (판정 기준선 · 2026-09-16)

| 축 | 실측 | 종전 기재 | 판정 |
|---|---|---|---|
| 회원 3축 | BRONZE `TM_MM_FDRM_MBER_INFO` **1,608,281** + `TM_MM_ONCE_MBER_INFO` **177,018** = **1,785,299** ↔ `SILVER.CRM_MEMBER` **1,785,299** ↔ `GOLD.DIM_MEMBER` **1,785,299** | O154 = 1,763,065 (3축 일치) | 🟢 **일치 유지 · 수치는 +22,234 로 stale** |
| 회원 고아 | `CRM_EVENT_PARTICIPATION` 기준 **10,048행 / 8,299종** (참여 1,258,775 의 **0.80%**) | O154 = 9,376행 / 7,658종 | 🔴 **입고 후에도 잔존** ⇒ BLOCKING-1 폐기 재확인 |
| EVENT 고아 | **281,701행 / 1,258,775 = 22.38%** · 고유 키 **54** · 상위 2건 `EVENT_105` 208,618 + `EVENT_106` 71,631 = **99.48%** | O116 = 263,611 / 23.24% · 키 53 | 🟢 **O116 규명(원천 마스터 결번) 유지** · 수치 갱신 |
| `GOLD.DIM_MEMBER` | **24컬럼** · `IS_CURRENT` **부재** · `EFFECTIVE_FROM` 실재 | SV 문안 = "IS_CURRENT=TRUE 투영" | 🔴 **문안이 틀렸다** (E8) |
| GOLD 뷰 | **14종** (전부 `WIDE%`) | 문서 = "WIDE VIEW 9개 → 13개 갱신 필요" | 🟢 라이브 스키마 COMMENT 는 **이미 수치를 뺐다** (E7-B) |
| SV / Agent | SV **17종** · Agent **3종**(`AGENT_MEMBER`·`AGENT_MARKETING`·`AGENT_EXECUTIVE`) 각 **3버전** | 착수표 ㉗ = `AGENT_OVERALL` | 🔴 착수표의 Agent 이름이 stale |

---

## ▣ E1. `BLOCKING-1` — 🟢 **종결(폐기 확정)** · 문서만 🔴 로 남아 있었다

🔴 문서50 §BLOCKING-1 은 *"마스터 전량입고 시 전부 `error` 복귀 필요(무결성 게이트 복원)"* 로 **🔴 열림**이었다.
🟢 그런데 코드 정본이 이미 폐기를 선언한다 — `10_dbt_pipeline/models/silver/crm/_crm_schema.yml` **헤더 §`MASTER-ORPHAN-POLICY`**(:44~:59):

* ① **입고는 끝났다**(3축 일치 · 위 §0 에서 재확인 · 수치만 갱신)
* ② **그런데 고아가 남았다** — O167 실측 **10,048행 / 8,299종** · 형식이상 **0** ⇒ 깨진 값이 아니라 **정상 번호**
* ③ **현업 지침(2026-09-10)** = *"업무절차상 삭제했지만 cascade 삭제가 아니어서 번호만 남은 경우로, 무시하고 파이프라인을 구성하라."*
* ⇒ 🟢 **판정 = 이 축의 `severity: warn` 은 「임시 완화」가 아니라 「영구 관측」이다.**

🔴 **그런데 같은 파일 :10 에 폐기된 문안이 살아 있었다** — *"▶▶ 마스터 전량입고·키체계 확정 후 warn 제거 → error 복귀
(후속조치, 누락 금지. 문서50 BLOCKING-1/2)"*. 🔴 그 파일 :55 가 *"「전량입고 후 error 복귀」가 인용돼 있으면 그것은
폐기된 문안이다"* 라고 **스스로 경고**하는데 **자기 헤더 안의 인용을 못 잡았다** ⇒ O167 이 :10 에 폐기 표시를 병기했다.

🟢 **판정식(신규)** = **「예약 조치를 폐기했으면 그 조치를 적은 곳을 전수 세라.」** 폐기 선언은 **선언한 문단만** 고치고
끝나기 쉽다 — 같은 파일 안의 종전 문안이 살아남아 **다음 세션이 그것을 읽고 실행**한다.

## ▣ E2. `BLOCKING-2 E` — 🔴 **열림 유지**(현업 회신) · 수치만 갱신

실측 = 고아 **281,701 / 22.38%** · 키 **54** · 상위 2건이 **99.48%**. O116 의 규명(`TM_MS_EVENT` 376행 ·
`EVENT_CD` 1~431 결번 55 · **105·106 은 0건** ⇒ 키 생성식 정상 · 원천 마스터 결번)은 **여전히 성립**한다.
🔴 남은 것은 **그 2개 행사의 정체·삭제 사유 현업 회신 1건**이고 그것 없이 `error` 승격은 금지다.

## ▣ E3. `BLOCKING-5` — 🟠 **열림 유지**(내부 구현) · 전수 재측정 + **죽은 포인터 복원**

🔴 종전 정본은 **2026-08-06 O43 판본**(386컬럼 / 미주입 106 / 27.5%)이고 컬럼 단위 목록은
`30_output_share/_archive/20260806/02_원천결손_Gap분석.md` §부록 — **아카이브로 이관돼 공유 폴더에 없는 죽은 포인터**였다.

🟢 **O167 이 라이브로 전수 재측정했다**(판정식 = `COUNT_IF(<컬럼> is not null and <컬럼> <> 0)` · 감사컬럼 `DW_*` 제외):

| 구분 | O167 실측 | O43(2026-08-06) |
|---|---:|---:|
| GOLD 기본테이블 | **37** | — |
| DATA 컬럼 | **598** | 386 |
| 값 주입됨 | **503** | 280 |
| 전건 `0` | **59** | 62 |
| 전건 `NULL` | **28** | 36 |
| 0행 테이블(`FACT_TARGET_PROJECT` 8컬럼) | **8** | 8 |
| **미주입 합계** | **95** | 106 |
| 미주입 비중 | **15.9%** | 27.5% |

🔴 **두 수치를 개선·악화로 읽지 마라** — 분모가 **386 → 598** 로 다르다(그 사이 GOLD 가 확장됐다).
🟢 **비중은 27.5% → 15.9%** 이고 이것은 같은 판정식이므로 비교 가능하다.

🔴🔴 **[2026-09-16 O168 실측 정정] 이 절의 「미주입 95 · 배정 누락 0」은 한 건 틀렸다.**
빌드 후 전수 재측정(`census_columns.py` GOLD 재측정 · 판정식 동일)에서 **집합 대조**를 하니:
· 🟢 **해소 2건** = `FACT_MEMBER_EVENT.UNPAID_STOP_CNT`·`_MEMBERS`(`DEC-54` 배선 · 실측 389,010).
· 🔴 **열거 누락 1건** = `DIM_DATE.IS_HOLIDAY`. 모델(`DIM_DATE.sql:27`)이 **`FALSE` 리터럴**로 박아 두었고
  (*"휴일 원천 없음(추후 보정)"*) 원천은 **`HOL-1` 공휴일 미입고 = 버킷 A(외부)**다 ⇒ **O167 시점에도 미주입이었다.**
  🔴 **회귀가 아니다** — 이번 빌드는 `FACT_MEMBER_EVENT` 만 손댔고 `DIM_DATE` 는 상수다.
⇒ 🟢 **직전 실제값은 96** 이고 **현재는 94/598(15.7%)** 다. 🔴 「95 → 94」로 읽지 마라(분자 정정이 섞여 있다).
🟢 **교훈** = 총계와 열거는 **따로 틀린다**. 진척은 수가 아니라 **집합 차이(해소 / 신규 / 누락)**로 증명하라.

🟢 **컬럼 단위 전량 목록(라이브 복원 · O167 열거 95건 · 🔴 위 정정 참조)**:

| 테이블 | 건 | 컬럼 |
|---|---:|---|
| `FACT_MEMBER_MONTHLY` | 27 | `CAMPAIGN_SK`·`PAYMENT_SK`·`UNPAID_CNT`·`ACTIVE_CUM_CNT`·`ACTIVE_CUM_MEMBERS`·`INCREASE_CNT`·`INCREASE_MEMBERS`·`DECREASE_CNT`·`CHURN_CNT`·`CAMPAIGN_UNPAID_CNT`·`STATUS_UNPAID_CNT`·`INBOUND_CALL_CNT`·`TS_CALL_CNT`·`DEV_TYPE`·`NEW_FLAG`·`INCREASE_FLAG`·`REDONATE_FLAG`·`JOIN_DATE`·`STOP_DATE`·`AMOUNT_BAND1`·`AMOUNT_BAND2`·`PERIOD_BAND1`·`PERIOD_BAND2`·`SPONSOR_MONTHS`·`SPONSOR_YEARS`·`PAID_MONTHS`·`NEW_EXISTING_FLAG` |
| `FACT_MESSAGE_DISPATCH` | 18 | `CAMPAIGN_SK`·`LETTER_PART_MEMBERS`·`LETTER_PART_CNT`·`GIFT_PART_MEMBERS`·`GIFT_PART_AMT`·`D5_LETTER_PART_MEMBERS`·`D5_LETTER_PART_CNT`·`D5_GIFT_PART_MEMBERS`·`D5_GIFT_PART_CNT`·`D5_INCREASE_PART_MEMBERS`·`D5_INCREASE_PART_CNT`·`D5_STOP_MEMBERS`·`D5_STOP_CNT`·`SERVICE_MEMBERS`·`SERVICE_CNT`·`SEND_STATUS2`·`MAIL_RECEIVE_FLAG`·`MEMBER_STOP_FLAG` |
| `FACT_EVENT_ATTENDANCE` | 8 | `CAMPAIGN_SK`·`SPONSORSHIP_SK`·`CONFIRM_CNT`·`PARTICIPATION_TIMES`·`WAIT_TIMES`·`ABSENT_TIMES`·`CUM_APPLY_TIMES`·`SELF_PART_FLAG` |
| `FACT_TARGET_PROJECT` | 8 | (0행 테이블) `MONTH_KEY`·`ORG_SK`·`SPONSORSHIP_SK`·`CAMPAIGN_SK`·`ANNUAL_GOAL_CNT`·`SUPP_GOAL_CNT`·`ANNUAL_CUM_GOAL_CNT`·`SUPP_CUM_GOAL_CNT` |
| `FACT_BUDGET` | 6 | `ORG_SK`·`CAMPAIGN_SK`·`SPONSORSHIP_SK`·`EXEC_BUDGET_EST`·`FUNDRAISING_COST`·`AD_COST` |
| `FACT_BUDGET_YEARLY` | 5 | `ORG_SK`·`CAMPAIGN_SK`·`SPONSORSHIP_SK`·`CHN_BUDGET_YEAR`·`ADJ_BUDGET_YEAR` |
| `DIM_ORG` | 3 | `CORP`·`DIVISION`·`TEAM` |
| `FACT_BIGQUERY_BEHAVIOR` | 3 | `CAMPAIGN_SK`·`AVG_SESSION_DURATION`·`BOUNCE_RATE` |
| `FACT_MEMBER_DEV_ACHIEVEMENT` | 3 | `ORG_DIVISION`·`ORG_TEAM`·`ORG_CORP` |
| `FACT_MEMBER_EVENT` | 3 | `UNPAID_STOP_CNT`·`UNPAID_STOP_MEMBERS`·`NEW_EXISTING_FLAG` |
| `DIM_AD_CREATIVE` | 2 | `PLATFORM_TYPE`·`TARGET_GROUP` |
| `DIM_MEMBER_IDENTITY` | 2 | `MEMNUM`·`CHILD_CODE` |
| `FACT_AD_PERFORMANCE` | 2 | `CAMPAIGN_SK`·`AD_CREATIVE_SK` |
| `DIM_CAMPAIGN`·`DIM_EVENT`·`DIM_PAYMENT`·`FACT_AD_BROADCAST`·`FACT_AD_DIGITAL` | 각 1 | `ORG_SK` · `APPLY_CHANNEL` · `FEE_TYPE` · `CONV_CALL_CNT` · `MEDIA_POTENTIAL_CUST_CNT` |

🟢 재현 = `COUNT_IF` 전수 순회(테이블 37 × 컬럼 · 무인자 재현 가능) · 🔴 **`COUNT()` 만으로 판정하면
0 상수 주입을 「적재됨」으로 오판**한다(O43 이 남긴 판정식이고 O167 도 그대로 따랐다).

## ▣ E4. 착수표 `㊳` — 🟢 **종결**(낡은 마운트 엔트리 소멸)

3축 실측 = ㉠ 마운트 루트 `.md` **3개**(`99_NEXT_SESSION.md`·`PAID_재현_런북_20260722.md`·`기준년월 보유 테이블 및 컬럼.md`)
로 `_o125e_entry.md` **부재** ㉡ 스테이지 루트 **부재** ㉢ 실체는 `_archive/_o125e_entry.md` **2,743 B 이고 정상 읽힌다**
(첫 줄 = *"🟢 [2026-08-31 O125-E] 원장 §1 용량 회복 …"*).
⇒ 🟢 착수표 ㉟ 이 정한 착수 형태 ①*"세션 재시작으로 사라지는지 확인"* → ②*"사라지면 종결"* 에 따라 **종결**이다.
🔴 `rm` 은 시도하지 않았다(`R1-7-7` · 애초에 대상이 없다).

## ▣ E5. 착수표 `⑬` — 🟢 **종결** · 잔여 2건이 **각각 다른 세션에서 이미 닫혀 있었다**

| 잔여 | 실측 | 닫힌 시점 |
|---|---|---|
| ㉠ `06_BRONZE노출감사` 재생성 | 🟢 **O166-B 가 라이브 경로로 재생성 + 차이 6건 귀속 + 골든 재발행** | 2026-09-16 O166-B |
| ㉡ 문서20 §N-6 「`SPNSR_AMT` 는 개발사건·증감이력에만 존재」 정정 | 🟢 **이미 정정돼 있다** — `20_현업확인_요청-007.md` **:124~:137** 에 *"[2026-08-20 O95 정정] 위 항목 3 은 틀렸다 — 철회한다"* + **4개 테이블 열거** + 교훈까지 | **2026-08-20 O95** |

🟢 **O167 독립 재측정으로 O95 의 정정이 오늘도 맞다** — `SPNSR_AMT` 실재 위치 = BRONZE **4테이블**
(`TM_MM_FDRM_MBER_DVLP_AMT`·`TM_MM_FDRM_MBER_IRSD`·`TM_MM_FDRM_MBER_RELATNSP_DVLP_AMT`·**`TM_MM_FDRM_MBER_SPNSR_BSNS`**)
+ SILVER 4 + GOLD 4 + ML/SERVING 6.
🔴🔴 **판정 = ⑬ 은 2026-08-20 부터 닫을 수 있었고 27일 동안 「🟡 열림」으로 남아 있었다.**
원인 = 착수표 셀이 *"🔴 O73·O73-C 도 문서20 미독이라 편집하지 않았다(1,071줄 전량 독해 선행)"* 라는 **선행조건을 달고 있었고**,
그 뒤 문서20 이 **조각으로 분할돼 해당 조각이 299줄**이 됐는데 **아무도 선행조건을 재평가하지 않았다.**
🟢 **판정식(신규)** = **「선행조건이 「전량 독해」면 문서 크기를 다시 재라.」** 분할·은퇴로 **선행조건이 저절로 충족**되는데
백로그 문면은 그것을 모른다.

## ▣ E6. 착수표 `⑩` 이월 묶음 — 🟢 **4축 판정 종결** · 🟠 **2축은 결정 선행으로 열림 유지**

| 축 | 실측·판정 |
|---|---|
| ㉠ **스테이지 내용 해시** | 🟢 **종결(대체 축 신설)**. 🔴 `cortex ws ls` 의 `md5` 는 **암호화 blob 해시**다 — 평문 md5 와 `.md` **423건 전건 불일치**(일치 0). ⇒ 해시 대조는 **원리적으로 불가**(착수표 ㉔ 의 「md5 대조 불가」와 같은 결론이고, 이제 **실측 근거**가 붙었다). 🟢 대신 **크기 패딩식이 결정적**이다: `stage == 16*(local//16)+16` 이 **2,741/2,741 성립 · 불성립 0**. ⇒ 게이트 신설 `scripts/stage_mount_size_gate.py`(실행 = `.md` **506건 · 드리프트 0 · 스테이지 전용 0 · 미발행 0 · PASS`) + 음성 테스트 4축 12단정 |
| ㉡ **1,000~2,000자 관측** | 🟢 **종결(착수 형태대로 게이트 직접 실행)**. `doc_line_length_gate --all` = **2,000자 초과 0 · 표 열수 위반 0 · 판독 불가 0(판독 380파일) PASS** · 관측(1,000~2,000자) **113건** · 40,000자 초과 문서 **9건**. 🔴 착수표가 *"건수를 여기 적지 않는다 — 자기참조 계측이다"* 라고 정했으므로 **이 수치는 근거철에만 둔다** |
| ㉢ **Agent 버전 정리·롤백 정책** | 🟢 **판정 종결**. 실측 = 3종 × **3버전 = 9버전**이고 **유효 스펙은 각 `VERSION$3` 뿐**(23,986 / 18,836 / 16,303자). `VERSION$1·2` 는 **전부 35자 = 빈 스펙**이다 ⇒ 🔴 **롤백 가능한 실질 버전이 0개**다. O73 기재 「빈 스펙 35자 **2종**」은 stale 이고 실제는 **6종**(3 Agent × 2). ⇒ 🟢 **「롤백 정책」의 전제가 성립하지 않는다** — 되돌릴 대상이 없으므로 정리할 누적도 없다. 🔴 다음 배포 때 `VERSION$4` 가 생기면 그때 **처음으로** 정책이 필요해진다 |
| ㉣ **계보 원천 교체(`GET_LINEAGE`)** | 🟢 **판정 종결(에디션 차단)**. `SNOWFLAKE.CORE.GET_LINEAGE` 는 **함수로 실재**하나(`SHOW FUNCTIONS` 1건) 호출하면 **`Unsupported feature 'Data Lineage'`** 로 실패한다. 🔴 `SYSTEM$GET_LINEAGE` 는 **아예 없다**(`Unknown function`). ⇒ **대기 대상이 아니라 에디션 제약**이다 · 현행 수기 계보(`o122_name_drift.sql` 계열)를 유지한다. 🟢 **판정식** = 「함수 부재」와 「기능 차단」을 구별하라 — 둘의 처방이 다르다(전자는 이름 오류, 후자는 계약) |
| ㉤ `P102`·`P106` 정의 복원 | 🟠 **열림 유지** — `§0-E 결정 2` 선행(설계 결정) |
| ㉥ 로드맵 10 문서화 · 로드맵 9 현업 질문서 | 🟠 **열림 유지** — `DEC-34` 는 `§0-E 결정 1` 선행 · 로드맵 9 는 현업 |

## ▣ E7. 문서50 열린 절 — 실측 재판정

### E7-A. `O64` 잔여 `D1` — 🟢 **종결**(양층 발행 확인)

O144-C 의 판정식(*"SV 9종 DDL + Agent 스펙에서 판정 4종 토큰 0건 ⇒ 미반영"*)을 **그대로 재실행**했다:

| 토큰 | SV DDL 파일 | 라이브 SV(`DESCRIBE`) |
|---|---:|---|
| `배분규칙필요` | **4파일** | `SV_MEMBER_MONTHLY`·`SV_MEMBER_EVENT`·`SV_MEMBER_FEE` 전건 실재 |
| `집계필요` | **2파일** | `SV_MEMBER_MONTHLY`·`SV_MEMBER_EVENT` 실재 |
| `형제팩트중복` | **2파일** | `SV_MEMBER_MONTHLY`·`SV_MEMBER_FEE` 실재 |
| `앵커_경합` | **5파일** | 4종 전건 실재 |

🟢 실물 인용 = `05_1_SV_DDL_MEMBER_MONTHLY.sql:37` 논리테이블 COMMENT = *"… [주의: 집계필요 배분규칙필요
형제팩트중복 앵커_경합 이중계상 방지] …"*. ⇒ **파일·라이브 양층 발행 완료**이므로 O64 는 종결이다.

🔴🔴 **[O167 자기정정] 나는 이 판정을 한 번 틀렸다.**
1차로 `SHOW SEMANTIC VIEWS` 의 `comment` 컬럼만 보고 *"라이브 미도달 · 드리프트 3건"* 이라고 판정했다.
🔴 그 컬럼은 **SV 레벨 COMMENT** 이고 토큰은 **논리테이블 COMMENT** 에 있다 ⇒ **분모를 잘못 봤다.**
`DESCRIBE SEMANTIC VIEW` 로 재측정하니 **전건 실재**였다. ⇒ **O165 `D5`(처방을 문면대로 집행하면 100% 오탐)와
`doc_census 축㉣` 초판 오탐 6건과 같은 형태의 3차 재발**이다.
🟢 **판정식(강화)** = **「없다」를 말하기 전에 「내가 본 그릇이 그것을 담는 그릇인가」를 물어라.**

### E7-B. `BLOCKING-4` 잔여 「GOLD 스키마 COMMENT 「WIDE VIEW 9개」 → 13개 갱신 필요(미반영)」 — 🟢 **종결**

라이브 실측 = `GOLD` 스키마 COMMENT = *"분석 계층 — star schema(DIM + FACT) + 평탄화 WIDE VIEW. 지표 215개 귀속.
**객체 수는 INFORMATION_SCHEMA.TABLES 를 TABLE_TYPE 으로 집계해 조회한다**"*.
🟢 **하드코딩된 수치가 이미 제거돼 있다** — 「9개 → 13개」로 고치는 것보다 **좋은 해법**이 적용된 상태다
(라이브 WIDE 뷰는 지금 **14종**이고, 수치를 박으면 또 stale 이 된다).
🟢 **판정식** = **「N 을 N' 로 고쳐라」는 백로그를 볼 때, 「N 을 지워라」가 이미 집행됐는지 먼저 보라.**

### E7-C. `순서9-C` — 🟠 **열림 유지** · 🔴 잔여 목록에서 **1건 제거**

잔여가 *"외부 원천 입고 **5건**"* 인데 그중 **「회원 마스터 전량입고 BLOCKING-1」은 E1 로 폐기·종결**됐다
⇒ 🟢 **잔여 5 → 4**(`FUNDRAISING_COST` E-1 · `AD_COST` E-4 · `FACT_TARGET_PROJECT` E-6 · GA4 분석 G-5).
🔴 절 자체는 O144-C 가 *"🔴 이 절을 🟢 로 바꾸지 마라"* 로 재판정했고 그 근거(내부 가능분 종료 · 잔여 외부)는 유효하다.

### E7-D. `결정 대기 GOLD 6개` · `O91-F` · `O59-P-1` · `BLOCKING-2 A~D` · `⑭` — 🟠🔴 **열림 유지(정당)**

O144-C 가 전건 재판정하며 *"🔴 이 절을 🟢 로 바꾸지 마라"* 를 명시했고, 남은 것이 **설계 결정 2건**
(`A1` 격리 테이블 · `A4`/`A2-B` 정보량 0 컬럼) · **모델 작성 여부 결정 4건** · **현업 회신**이다.
🟢 O167 은 이 절들을 **닫지 않았다** — 실측으로 닫을 수 있는 성질이 아니다(결정·회신은 사람이 만든다).
🔴 단 `⑭`(다중사업 7.29%)·`O59-P-1`(§M-6)·문서20 §M-1~M-6·§N-13 은 **O166-D 가 확인한 대로 회신 대기가 옳다**
(M-5 4자리 코드 `7320`·`7319`·`9034`·`7321`·`7205` = `TC_CMMN_DTL_CD` 에 **여전히 0건**).

## ▣ E8. 🔴🔴 **라이브 AI 컨텍스트 결함** — `IS_CURRENT=TRUE 투영` 문안 (파일 4 + 라이브 4) → 🟢 정정

실측 = `GOLD.DIM_MEMBER` **24컬럼**에 `IS_CURRENT` **부재**. 그런데 SV 논리테이블 COMMENT 가
*"정규 회원 마스터 차원 (회원 1명 = 1행, **IS_CURRENT=TRUE 투영**)"* 이라고 적고 있었다:

* 파일 **4종** = `05_1_…MEMBER_MONTHLY.sql:45` · `05_2_…MEMBER_EVENT.sql:45` · `05_4_…SERVICE.sql:48` · `05_5_…EVENT_PARTICIPATION.sql:48`
* 라이브 **4종** = `SV_MEMBER_MONTHLY`·`SV_MEMBER_EVENT`·`SV_SERVICE`·`SV_EVENT_PARTICIPATION`
* 🔴 **실해** = 이 문안은 **Agent 가 SQL 을 쓰기 전에 읽는 컨텍스트**다. 그대로 믿으면 `WHERE IS_CURRENT = TRUE`
  를 만들고 **invalid identifier** 로 죽는다(또는 조건을 지어내 **행을 잃는다**).

🟢 **정정 문안** = *"회원 1명 = 1행 · `MEMBER_DK` 유일 1,785,299. 🔴 `IS_CURRENT` 컬럼은 없다 — 상태 이력은
`DIM_MEMBER_STATUS_HISTORY`(4.52행/회원) 를 쓴다."*
🟢 **집행** = 파일 4종 정정 → 각 파일에서 `CREATE OR ALTER SEMANTIC VIEW` 문만 추출해 라이브 4종 재집행 →
`DESCRIBE` 전수 재측정 = **stale 문안 잔존 0 / SV 17종** · 신문안 도달 4/4.
🔴 **부수 정정** = `scripts/_o166_rename_fix.py` 의 `MANUAL_ONLY` 주석도 같은 거짓을 담고 있었다
(*"현재행은 `IS_CURRENT = TRUE` 필터로 얻는다"*) ⇒ 함께 고쳤다. **O166 `E3`(개명이 grain 을 옮긴다)의 잔재**다.
🟢 **판정식** = **「같은 거짓 문안은 여러 층에 복제돼 있다」** — 파일·라이브·게이트 주석 **3층**을 함께 세라(`R3-9 ㉥`).

⚠️ **검증에서 한 번 더 걸렸다** — 정정 직후 `IS_CURRENT` 문자열 검사가 **True** 를 냈는데, 그것은
**내 새 문안("IS_CURRENT 컬럼은 없다")이 스스로 걸린 자기참조 계측**이었다. 🔴 정확한 토큰(`IS_CURRENT=TRUE`)으로
재판정해 **0** 을 확인했다. ⇒ **「부정문을 심으면 그 부정문이 탐지기에 걸린다」**(착수표 ⑩ 의 자기참조 계측과 같은 축).

## ▣ E9. 개명 축1 — 🟢 **530 → 469 (−61 · 기준선 하향 발행)**

🔴 **먼저 도구 결함을 찾았다** — `_o166_rename_fix.py --apply` 가 **치환 0건**인데 게이트는 **530건**을 보고한다.
원인 = 그 도구의 `TARGETS` 가 **O166 이 손으로 나열한 13개 파일**이고 그때 소진됐다 ⇒ **도구 분모 ≠ 게이트 분모**.
🟢 처방 = `--from-gate`(게이트 `bucket()` 이 **`LIVE`(축1)로 판정한 파일만**) + `--only <구 이름>`(어의 변경 개명 배제).

🔴🔴 **그 처방의 초판도 틀렸다** — `SCAN_DIRS` 를 전량 훑어 **1,048건 / 108파일**을 냈다. 그것은 축1 이 아니라
**축1+축2+축3 전부**였고 `_archive/`·이력·근거철까지 삼켰다(**고치면 경위가 사라진다**).
🟢 `bucket(rel) == 'LIVE'` + 게이트와 같은 `SKIP_DIR`·`EXT` 로 맞추니 **61건 / 26파일**이 됐다.

🟢 **집행 대상 = 순수 개명 4종만** — `FACT_GA_BEHAVIOR`→`FACT_BIGQUERY_BEHAVIOR` ·
`DIM_GA_EVENT`→`DIM_BIGQUERY_EVENT` · `DIM_GA_SOURCE`→`DIM_BIGQUERY_SOURCE` · `WIDE_GA_BEHAVIOR`→`WIDE_BIGQUERY_BEHAVIOR`.
🟢 **순수성 근거(라이브)** = 구명 4종 **전건 부재** · 신명 4종 **실재**(BASE TABLE 3 + VIEW 1) ⇒ **1:1 개명이고 grain 불변**.
🔴 **배제한 것** = `DIM_MEMBER_CURRENT`(개명이 아니라 **객체 소멸** · grain 변경) · `FACT_SERVICE_EVENT`→`FACT_MESSAGE_DISPATCH` ·
`FACT_MEMBER_SPONSOR_BIZ`→`FACT_MEMBER_SPONSORSHIP_SPAN` 등 **어의가 바뀐 개명**은 기계 치환하면
**이름은 맞고 뜻이 틀린 문안**이 남는다(O166 `MMMM1` 3번째 판정식).

🟢 **부수 성과 = dbt 잠재 결함 1건 복구** — `10_dbt_pipeline/tests/warn_gold_view_comment_coverage.sql:63` 이
`-- depends_on: {{ ref('WIDE_GA_BEHAVIOR') }}` 였다. 🔴 **그 모델은 dbt 에 없다**(모델 98개 실측 = `WIDE_BIGQUERY_BEHAVIOR` 만 실재)
⇒ **dangling ref** 였고 치환이 이를 해소했다. 🔴 이것은 **주석처럼 보이지만 dbt 가 파싱하는 DAG 힌트**다 —
치환 전에 모델 실명을 확인했기 때문에 안전했다(확인 없이 고쳤으면 반대로 깨질 수 있었다).

🟢 **회귀 검증** = 6게이트 전건 `rc=0`(`doc_census`·`doc_type_gate`·`clause_order_gate`·`index_row_gate`·
`doc_heading_gate`·`doc_coord_gate`) · `gate_census` **미분류 0**.

## ▣ E10. 착수표 `㉗` NL 라우팅 스모크 — 🟢 **집행**(정본 = §11)

O166-D 가 실행 가능성을 실증했고, O167 이 **전량 집행**했다. 상세·판정은 **§11** 에 있다.

---

## ▣ 11. `㉗` NL 라우팅 스모크 결과

🟢 **문항 = Agent 스펙 `sample_questions` 전량 33문항**(`AGENT_MEMBER` 12 · `AGENT_MARKETING` 11 · `AGENT_EXECUTIVE` 10).
🔴 착수표 기재 「3종 × 10 = 30」은 stale 이다 — 스펙이 그 뒤 늘었다. 🔴 대상 Agent 도 `AGENT_OVERALL` 이 아니라 **`AGENT_EXECUTIVE`** 다.

🟢 **비용 설계** = O166-D 는 1문항이 **입력 토큰 424,715** 를 썼다고 적었는데 그것은 **응답을 세션 컨텍스트에 실었기 때문**이다.
🟢 O167 은 러너(`scripts/nl_routing_smoke.py`)가 응답 원문을 **`tmp/nlsmoke/<TAG>.txt` 로 흘리게** 했고
판정기(`scripts/nl_routing_judge.py`)가 **요약만** 출력한다 ⇒ **33문항을 돌려도 세션 비용은 요약 33줄**이다.
🟢 **판정식(신규)** = **「과금 축과 컨텍스트 축은 다르다」** — 되돌릴 수 없는 것은 크레딧이고, 줄일 수 있는 것은 적재량이다.

🔴 **호출 형식 함정(재확인)** = `DATA_AGENT_RUN(agent, **요청 JSON**)`. 질문 문자열을 그대로 넘기면 `Request is malformed`.

🟢 **판정 축 ㉠ 라우팅 정확도** — 질문 주제 ↔ 선택된 `analyst_*` 도구가 **전건 일치**했다:

| 문항 | 선택 도구 | 판정 |
|---|---|---|
| `MEMBER_01` 회비 청구·납부율 | `analyst_member_fee` | 🟢 적중 |
| `MEMBER_02` 납부율·미납비중 추이 | `analyst_member_monthly` | 🟢 적중 |
| `MEMBER_03·04·05` 개발구분·캠페인·연령/지역 개발건수 | `analyst_member_event` | 🟢 적중 |
| `MEMBER_06` 12개월 이탈률·획득 | `analyst_member_cohort` | 🟢 적중 |
| `MEMBER_07` 부서·월별 목표/실적 | `analyst_dev_achievement` | 🟢 적중 |
| `MEMBER_08` 지금 활동회원 | `analyst_member_sponsor_biz` | 🟢 적중 |
| `MEMBER_09` 채널별 발송·발송결과 | `analyst_service` | 🟢 적중 |
| `MEMBER_10` 행사 참여자·참여상태 | `analyst_event_participation` | 🟢 적중 |
| `MEMBER_11` 중단 분류·평균 중단확률(예측) | `analyst_ml_member_risk` | 🟢 적중 |
| `MEMBER_12` *"원천(bronze)은 각각 어디야?"* | **도구 0 · 서술 781자** | 🟢 **적중** — 데이터 질문이 아니므로 SQL 을 만들지 않는 것이 정답이다(착수표 판정 축 ㉡ *"산출 불가 질문에 SQL 을 만들지 않는가"*) |
| `MARKETING_01` 목표/실적 | `analyst_dev_achievement` | 🟢 적중 |
| `MARKETING_02` 예산·집행율 | `analyst_budget` | 🟢 적중 |
| `MARKETING_03·04·05` 디지털·방송 광고 | `analyst_ad` | 🟢 적중 |

🟢 **판정 축 ㉡ 산출물(33문항 전량 확정)** = SQL 생성 **30/33** · 오류 표면 **0** · 상태 전건 `completed` ·
차트(`data_to_chart`) **20회** · `system_execute_sql` **110회**.
🟢 **SQL 미생성 3건은 전부 정답** = `AGENT_EXECUTIVE_10`·`AGENT_MARKETING_10`·`AGENT_MEMBER_12` 로
**셋 다 *"…데이터의 원천(bronze)은 각각 어디야?"*** 계열이다 ⇒ 착수표 판정 축 ㉡(*"산출 불가 질문에
SQL 을 만들지 않는가"*)을 **3/3 충족**하고 서술로만 답했다(821·784·781자).

🟢 **`AGENT_EXECUTIVE` 라우팅(전건 적중)** = 예산·집행율→`analyst_budget` · 디지털/방송 광고→`analyst_ad` ·
납입회비·미납→`analyst_member_monthly` · 채널별 발송→`analyst_service` · 개발금액 전망→`analyst_ml_dvlp_forecast` ·
부서·후원사업 개발 예측→`analyst_ml_dvlp_forecast` · 회원평균 LTV 예측→`analyst_ml_ltv_forecast` ·
캠페인 LTV 스코어→`analyst_ml_ltv_score` · 기여 요인→`analyst_ml_feature_importance`.
🟢 **`AGENT_MARKETING` 잔여** = 재방송 개발단가→`analyst_ad` · 마케팅캠페인 CTR→`analyst_ad` ·
연령·개발구분 전환회원→`analyst_member_event` · 캠페인 유지기간·이탈률·총납입회비→`analyst_member_fee`+`analyst_member_cohort`
(**2개 SV 를 함께 호출**해 축을 합성했다) · 지금 활동회원→`analyst_member_sponsor_biz`.

🟢 **종합 판정 = 라우팅 33/33 적중 · 오류 0 · 산출 불가 질문 3/3 정확 회피** ⇒ 착수표 `㉗` 의 확인 축
㉠·㉡ 를 **충족**했다. 🟠 축 ㉢(단위 만원/원 · 예측/실적 표 분리)은 **응답 서술을 사람이 읽어야 하는 축**이므로
기계 판정 대상이 아니다 — 원문이 `tmp/nlsmoke/<TAG>.txt` **33건**에 보존돼 있다(현업 검수용).

🔴🔴 **[O167 자기정정] 판정기 초판이 「SQL 생성 0」을 냈다.** `tool_results` 안의 `"sql":` 를 셌기 때문인데,
같은 응답에 `system_execute_sql` 이 **63회** 있었으므로 **0 은 사실이 아니라 분모 오류**였다.
🟢 SQL 은 **`tool_use.input.sql`** 에 있다 ⇒ 판정기를 고쳤다.
🔴 **이 오탐은 E7-A 와 같은 형태의 4차 재발**이다 — *"내가 본 그릇이 그것을 담는 그릇인가."*

---

## ▣ 12. 🔴 O167 이 스스로 적발한 자기 결함 (전건 기록)

| # | 결함 | 실해 | 시정 |
|---|---|---|---|
| 1 | `grep` 이 착수표 글리프 `⑬⑭㉗㊳` 를 **0건**으로 냈다(`⑩` 은 찾았다) | 열린 항목의 원문을 **못 찾을 뻔했다** | python 순회로 전환 → 45·132·40·54건 발견. 🟢 **판정식 = 0건은 「없다」가 아니라 「내 판정식이 못 본다」다**(`O111 ㉠` 재확인) |
| 2 | `cortex ws ls` 파서를 **공백 분리**로 써서 게이트가 **0건 = 미판정** | 신설 게이트가 첫 실행에서 죽었다 | 구분자는 **탭**이었다 ⇒ 정정 + **음성 테스트 축2 로 회귀 고정**(종전 구현이 0건을 내는 것까지 단정) |
| 3 | `SHOW SEMANTIC VIEWS.comment` 로 O64 D1 을 판정해 **「드리프트 3건」 오탐** | O64 를 **잘못 열어 둘 뻔했다** | `DESCRIBE SEMANTIC VIEW` 로 재측정 → 전건 실재 ⇒ **종결**. `O165 D5` 3차 재발 |
| 4 | 개명 치환 대상을 `SCAN_DIRS` 전량으로 잡아 **1,048건**(축1 은 61건) | `_archive/`·이력·근거철을 고쳐 **경위를 지울 뻔했다** | `bucket()=='LIVE'` + 게이트와 같은 `SKIP_DIR`·`EXT` 로 분모 통일 |
| 5 | 스모크 판정기가 **「SQL 생성 0」** 오보 | 라우팅 결과를 **실패로 오판할 뻔했다** | `tool_use.input.sql` 로 정정 |
| 6 | SV DDL 파일 4종을 `edit` 대신 **python 전량 치환**으로 고쳤다(`R1-7-1` 문면 위반) | 앵커 유일성을 선검증(각 1건)하고 잔여 0 을 확인했으므로 **실유실 0** | 🔴 **기록으로 남긴다** — 다음에는 4파일 동일 문안이라도 `edit` 4회가 규약이다 |
| 7 | 인수인계 절을 **`cat >>`** 로 붙였다 | 🔴🔴 **이 마운트는 append 를 지원하지 않는다** — `write error: Operation not supported` 가 **stderr 로만** 나고 파일은 **한 바이트도 늘지 않았다**(절 전량 유실). 게이트는 통과했다(**없는 것을 검사할 수 없다**) | python 전량 쓰기로 재집행 + **직후 토큰 재검사**(`## 0-TTTT/O167.` 1건 · `▣ TTTT1/2/3` 각 1건 · 17,260 → **24,215 B**) ⇒ 🟢 **판정식 = 「썼다」와 「닿았다」는 다르다 · 쓰기 직후 토큰으로 도달을 확인하라** |
| 8 | E8 정정 문안에 **실측 수치**(`1,785,299`·`4.52행/회원`)를 넣어 **DDL 규칙7 위반 8건**을 만들었다 | 🔴 `test_sv_rule7_scan` 이 **라이브 도달 위반 8건**으로 FAIL(파일 4종 × 2). 🔴 **그 수치는 다음 적재에 stale 이 된다** — 내가 고치려던 결함과 **같은 유형**을 새로 심은 것이다 | 수치를 뺀 문안(*"회원 1명 = 1행 · `MEMBER_DK` 유일"* · *"상태 이력이 필요하면 `DIM_MEMBER_STATUS_HISTORY` 를 쓴다"*)으로 파일 4 + 라이브 4 재정정 · `sv_rule7_scan` **라이브 0** · 테스트 rc=0 ⇒ 🟢 **판정식 = 「문안을 고칠 때 그 문안이 지켜야 하는 규칙을 먼저 세라」**(DDL COMMENT 는 수치 금지 구역이다) |
| 9 | 스킬 본문을 압축하며 `P102`(스테이지 실체 확인)·`R1-3-7-a`·`R1-6` 계열 6종 등 **19토큰**을 떨어뜨리고 **`dbt` 정지점 항목까지 함께 지웠다** | 🔴 `dbt` 정지점은 **사용자 소관 계약**이다 — 지워지면 에이전트가 `dbt build` 를 돌린다 | 구판↔신판 **토큰 차집합**을 내어 전건 복원(잔여 2건은 예시 토큰·상위 계열) ⇒ 🟢 **판정식 = 압축은 「줄이는 것」이 아니라 「토큰 집합을 보존한 채 줄이는 것」이다** · 절차를 정본 §5-1 에 고정했다 |

🟢 **공통 축** = 9건 중 **4건이 「분모·그릇을 잘못 봤다」**다. 🔴 이 워크스페이스에서 가장 자주 나는 결함 유형이며
O165 `D5` · O165 `D11` · `doc_census 축㉣` 초판 · O166 `SCD2_DIM` 과 **같은 계열**이다.
🔴 3건은 **「도구·환경의 계약을 확인하지 않은 것」**이다(글리프 grep · 탭 구분자 · append 미지원).
🔴 2건은 **「고치면서 같은 유형을 새로 심은 것」**이다(규칙7 수치 · 압축 중 토큰 유실).
🟢 **공통 처방 = 「0건·성공을 받았을 때 그것이 판정인지 침묵인지 물어라」 + 「고친 뒤 그 파일의 게이트를 돌려라」.**

---

## ▣ 12-B. 🟢 `init_ihcho` 스킬 3자 구조 신설 (사용자 지시 7항)

🔴 **문제** = `SKILL.md` 가 **유일본**이어서 ㉠ 개정 경위가 남지 않고(스킬 안에 세션 라벨을 적어 버텼다)
㉡ **형식 검증이 없었다**(500줄 상한·조문 집합·하드코딩 수치) ㉢ 이번 세션의 학습을 반영할 절차가 없었다.

🟢 **구조** = 정본(설명) + 본문(추출 대상) + 빌더 + 검증기:

| 파일 | 역할 | 규모 |
|---|---|---|
| `00_guides/03_init_ihcho_스킬_정본.md` | 명세 = 정체성·구조 지도·갱신 절차·불변식 `I1`~`I7`·개정 이력·토큰 보존 대조 절차 | 9.4 KB |
| `00_guides/03_init_ihcho_스킬_본문.md` | **본문 정본** — 마커 사이가 `SKILL.md` 로 그대로 나간다 | 37.6 KB |
| `scripts/build_init_ihcho_skill.py` | 정본 → `SKILL.md` (dry-run 기본 · `--apply` · 스냅샷 `snapshot_util` 경유 · **쓴 뒤 되읽어 단정**) | 116줄 |
| `scripts/verify_init_ihcho_skill.py` | 바이트 동일 + 불변식 7종 · `gate_census.JUDGE` 등재 | 146줄 |

🔴 **두 파일로 나눈 이유** = 본문만 36KB 라서 명세와 합치면 **조각 상한 40KB 초과**(`doc_type_gate` 축3 이
실제로 잡았다 · 여유 **−4,493 B**)이고, 그러면 `read` 1회 전량 확보가 깨진다.
🔴 **허브+조각 분할은 마커를 갈라 빌더 추출을 깨뜨리므로** 쓰지 않았다 ⇒ **파일 분리**를 택했다.

🟢 **스킬 개선 실측** = **529줄 / 52,831 B → 451줄 / 36,525 B**(−78줄 · −16,306 B)이면서
**조문·판정식 토큰은 보존**했고 **신규 학습 7건을 추가**했다. 구조 변경 =
㉠ 흩어져 있던 판정식을 **§3 8종으로 통합**(종전에는 같은 축이 3곳에 있어 한 곳을 고치면 나머지가 낡았다)
㉡ `R1-7` 10조문을 **표**로(ID·금지문·사고횟수 전건 보존 · 서사는 정본으로)
㉢ 도구를 **표**로 정리하고 각 행에 조문 ID 병기 ㉣ **가드(§1)를 절차(§2)보다 앞**에 두었다
(LLM 은 문서 순서대로 행동하므로 가드가 뒤에 있으면 첫 `read` 부터 가드 밖이다).

🟢 **불변식이 실제로 잡은 것** = 초판이 *"게이트 6종 🟢 에서 결함 4건"* 이라고 적었는데 `I7` 이
**하드코딩 수치**로 blocking 했다(지금 게이트는 7종이다) ⇒ 「게이트가 전부 🟢 인 상태에서」로 고쳤다.

🔴 **등재 선행조건 전건 이행** = 원장 §0 유형 등재표 **2행** + `doc_type_gate.EXTRA_DOCS` ·
`doc_heading_gate.DOCS` · `doc_line_length_gate.CANON` · `doc_census.SINGLES` **4곳 분모 편입** +
`doc_heading_gate --update-golden --reason`(제목 39개 최초 등재 · 유실 0) +
`gate_census` 등재(검증기 = `JUDGE` · 빌더 = `MUTATES`).

---

## ▣ 12-C. 🟢 즉시 가능 3건 집행 → **속편 `_o167_evidence_2.md`**

🔴 **본문은 그 파일에 있다**(무변경 이관 · 본편이 40KB 상한을 넘어 분리했다).
🟢 요약 = **C1** `06` 재생성으로 「노출됨 −1」 축 종결(신규↔직전 SHA256 동일 · 차이 0) ·
**C2** 착수표 `㉗` 축 `㉢` **33/33 준수**(단위 미표기 0 · 예측 표기 누락 0 · 혼재 3건은 분리 명시) ⇒ `㉗` 전축 종결 ·
**C3** 개명 축1 **469 → 458**(`04_SV_설계.md` 44 → 33 · 1~159행 위반 0) ·
**C4** 🔴 이 턴 자기결함 **2건**(탐지기 정규식이 백스페이스로 굳음 · 부정문을 위반으로 오탐).

## ▣ 13. 🔴 남은 것 (실측 후에도 열린 것)

| 등급 | 항목 | 왜 우리가 닫을 수 없나 |
|---|---|---|
| 🔴🔴 | `D8` BRD **−1,262,913** 외부 적재 이력 | 라이브는 **10,337,767 불변**(09-15 01:00 이후 적재 없음) ⇒ **외부 적재기 이력만이 가릴 수 있다** |
| 🔴 | `BLOCKING-2 E` 행사 `EVENT_105`·`106` 정체 | 현업 회신 1건 (실측 갱신 = 281,701 / 22.38%) |
| 🔴 | `BLOCKING-2 A·C·D` · 문서20 §M-1~M-6 · §N-13 · `⑭` 다중사업 7.29% · `O59-P-1` | 현업 회신 |
| 🟠 | `BLOCKING-5` 미주입 **95건** | 버킷 B(내부 구현)는 착수 가능하나 **규칙 확정 선행**(CONF-2·CONF-3) · A/F 는 외부 입고 |
| 🟠 | `결정 대기 GOLD 4개` · `O91-F` 잔여 2 · `⑩ ㉤㉥` · `순서9-C` 잔여 4 | 설계·사용자 **결정** 또는 외부 입고 |
| 🟠 | 개명 축1 잔여 **458건 / 121파일**(O167 후속으로 469 → 458) | 🔴 남은 것은 **어의가 바뀐 개명**이라 기계 치환 금지 — 문안을 사람이 다시 써야 한다. 🟢 `04_SV_설계.md` 는 44 → **33건**이고 **1~159행은 위반 0** ⇒ 다음 세션은 **160행부터 읽고** 이어라(경계를 숫자로 남겼다 · §12-C C3) |
| ~~🟠~~ 🟢 | ~~`06` 「노출됨 −1」 행 귀속~~ ➔ **[O167 종결]** | 재생성 rc=0 · 스냅샷 3종 · 신규↔직전 **SHA256 동일**(차이 0) · 골든 30지표 일치 ⇒ 재발 방지 축이 닫혔다(§12-C C1). 🔴 과거 1건의 귀속은 원리적으로 불가(사본 부재) |
| 🟠 | 인수인계 절 라벨 병기 관례(`0-NNNN/O167`) | 🔴 기존 라벨 소급 개명 금지 |

_Co-authored with CoCo_
