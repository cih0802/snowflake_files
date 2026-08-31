<!-- LLM-METADATA
doc_id: O116_WARN_CENSUS
doc_role: O116 근거철 — dbt WARN 36건 전수 정본화 + 판정식 결함 + 미규명 건 규명 실측
project: GN_DW (굿네이버스)
created: 2026-08-29
created_by: O116
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

# O116 근거철 — WARN 36건 전수 정본화

> 🔴🔴 **[2026-08-29 O116-B 정정] 이 파일은 정본이 아니다 — 정본은 문서50 §O116 이다.**
> 이유 = 이 파일은 **`20_issue/` 밖 루트 파일**이라 게이트 분모(제목·줄길이·센서스·유형)에 들어 있지
> 않다 ⇒ 손상·stale 을 잡아 주는 장치가 없다. 첫 회에 이 파일을 「목록의 정본」이라 선언한 것은
> **구조결함**이었고 O116-B 가 문서50 §O116 으로 이관했다.
> 🟢 이 파일은 **쿼리·중간 관측·기각된 가설**을 담은 **부속 근거**로 남긴다(`R2-8-3` — 지우지 않는다).
> 🔴 **수치를 인용할 때는 문서50 §O116 을 인용하라.**

> 🔴 이 파일은 **근거철**이다(`R1-3-7-c` — 판정 근거를 판정보다 먼저 쓴다).
> 정본 요약은 `99_NEXT §0-VVV ▣VVV3` 와 이력 §O116 에 병기한다.

## 0. 회차 귀속 (🔴 분모의 전제)

`10_dbt_pipeline/logs/dbt.log` 는 **한 파일에 여러 회차가 섞여 있다**(회전 `.1`~`.5` 별도).
회차 경계 = `Running with dbt=` · 판정 = 각 블록의 마지막 `Done.` 줄.

| 축 | 실측 |
|---|---|
| `dbt.log` 총 줄 수 | **57,198** 줄 |
| 이 파일에 든 회차 수 | **10**(선두에 회전으로 잘린 블록 1개 별도 — `Running with dbt=` 헤더 없음) |
| 🟢 **채택 회차** | **회차 10 · 줄 28,999~57,198** |
| 채택 회차 요약 | `Done. PASS=425 WARN=36 ERROR=0 SKIP=0 TOTAL=461` |
| 그 블록의 WARN 출현 / 고유 테스트 | **36 / 36**(1:1 ⇒ 중복 없음) |

🔴 **회차를 분리하지 않으면 분모가 뒤섞인다** — 같은 파일에
`PASS=414 WARN=33 TOTAL=447` 등 **다른 회차**가 함께 들어 있다.

## 1. 🔴🔴 판정식 결함 — 인수인계의 재현법은 그대로는 0건을 낸다

`▣VVV3` 이 준 재현법:

```
grep -oE "WARN [0-9]+ [A-Za-z0-9_]+" 10_dbt_pipeline/logs/dbt.log | sort -u
```

| 실행 | 결과 |
|---|---|
| 위 명령 그대로 | 🔴 **0건** |
| `-a` 추가(`grep -aoE …`) | 🟢 **36건**(고유) |

원인 = 이 로그에 **ANSI 제어문자**가 있어 BusyBox `grep` 이 **binary 로 판정**하고
`Binary file matches` 로 빠진다 ⇒ `-o` 출력이 사라진다. **파일에는 문제가 없다.**

🟢 **교정된 재현법**(회차 분리까지 포함하려면 아래 2단계):

```
grep -anE "Running with dbt=" 10_dbt_pipeline/logs/dbt.log        # 회차 경계 확인
grep -aoE "[0-9]+ of [0-9]+ WARN [0-9]+ [A-Za-z0-9_]+" 10_dbt_pipeline/logs/dbt.log
```

🔴 **`O111 ㉠` 의 실물 사례다** — 「0건」은 「없다」가 아니라 **「내 판정식이 못 본다」**였다.

## 2. WARN 36건 전수 (채택 회차 · 건수 내림차순)

| # | 테스트 | WARN 행수 | 계열 |
|---|---|---|---|
| 1 | `not_null_CRM_SEND_MEMBER_SEND_RESULT_NAME` | 1,401,419 | not_null |
| 2 | `relationships_CRM_EVENT_PARTICIPATION_EVENT_KEY__EVENT_KEY__ref_CRM_EVENT_` | 263,611 | 관계 |
| 3 | `relationships_CRM_SEND_MEMBER_MBER_NO__MEMBER_DK__ref_CRM_MEMBER_` | 31,486 | 관계·MEMBER_DK |
| 4 | `relationships_FACT_SERVICE_EVENT_MEMBER_DK__MEMBER_DK__ref_DIM_MEMBER_` | 31,486 | 관계·MEMBER_DK |
| 5 | `not_null_CRM_CAMPAIGN_MKTG_UTM_NM` | 21,682 | not_null |
| 6 | `relationships_CRM_CAMPAIGN_SPNSR_BSNS_ID__SPNSR_BSNS_ID__ref_CRM_SPONSORSHIP_` | 18,091 | 관계 |
| 7 | `relationships_CRM_SEND_MEMBER_SNDNG_KEY__SNDNG_KEY__ref_CRM_SEND_REQUEST_` | 11,313 | 관계 |
| 8 | `relationships_CRM_EVENT_PARTICIPATION_MBER_NO__MEMBER_DK__ref_CRM_MEMBER_` | 9,480 | 관계·MEMBER_DK |
| 9 | `relationships_FACT_EVENT_PARTICIPATION_MEMBER_DK__MEMBER_DK__ref_DIM_MEMBER_` | 9,480 | 관계·MEMBER_DK |
| 10 | `not_null_CRM_CAMPAIGN_MK_CMPGN_NM` | 7,052 | not_null |
| 11 | `not_null_CRM_PAYMENT_BILLING_RQEST_RST_CD` | 1,096 | not_null |
| 12 | `not_null_CRM_SEND_MEMBER_MBER_NO` | 745 | not_null |
| 13 | `warn_erp_budget_month_grain` | 528 | 예산(DEC-44) |
| 14 | `relationships_CRM_PAYMENT_BILLING_MBER_NO__MEMBER_DK__ref_CRM_MEMBER_` | 309 | 관계·MEMBER_DK |
| 15 | `relationships_FACT_MEMBER_EVENT_MEMBER_DK__MEMBER_DK__ref_DIM_MEMBER_` | 271 | 관계·MEMBER_DK |
| 16 | `relationships_CRM_MEMBER_DEV_MBER_NO__MEMBER_DK__ref_CRM_MEMBER_` | 270 | 관계·MEMBER_DK |
| 17 | `relationships_FACT_MEMBER_MONTHLY_MEMBER_DK__MEMBER_DK__ref_DIM_MEMBER_` | 199 | 관계·MEMBER_DK |
| 18 | `relationships_GA4_IDENTITY_MBER_NO__MEMBER_DK__ref_CRM_MEMBER_` | 153 | 관계·MEMBER_DK |
| 19 | `relationships_CRM_MEMBER_STATUS_HIST_MBER_NO__MEMBER_DK__ref_CRM_MEMBER_` | 85 | 관계·MEMBER_DK |
| 20 | `warn_fep_nonnumeric_member_dk` | 62 | singular |
| 21 | `warn_erp_budget_yearly_grain` | 44 | 예산(DEC-44) |
| 22 | `warn_erp_budget_procedure_merge` | 42 | 예산(DEC-44) |
| 23 | `relationships_CRM_PAYMENT_METHOD_MBER_NO__MEMBER_DK__ref_CRM_MEMBER_` | 37 | 관계·MEMBER_DK |
| 24 | `relationships_CRM_MEMBER_DEV_CMPGN_CD__CMPGN_CD__ref_CRM_CAMPAIGN_` | 18 | 관계 |
| 25 | `relationships_FACT_MEMBER_COHORT_MEMBER_DK__MEMBER_DK__ref_DIM_MEMBER_` | 16 | 관계·MEMBER_DK |
| 26 | `relationships_CRM_SEND_RESULT_SNDNG_KEY__SNDNG_KEY__ref_CRM_SEND_REQUEST_` | 9 | 관계 |
| 27 | `not_null_CRM_PAYMENT_BILLING_MBER_NO` | 5 | not_null |
| 28 | `relationships_CRM_MEMBER_CMPGN_CD__CMPGN_CD__ref_CRM_CAMPAIGN_` | 4 | 관계 |
| 29 | `not_null_CRM_EVENT_PARTICIPATION_PARTCPT_CHNNL_NM` | 2 | not_null |
| 30 | `not_null_CRM_EVENT_PARTICIPATION_PARTCPT_PATH_NM` | 2 | not_null |
| 31 | `not_null_CRM_EVENT_PARTICIPATION_PARTCPT_STAT_NM` | 2 | not_null |
| 32 | `relationships_CRM_PAYMENT_BILLING_SPNSR_BSNS_ID__SPNSR_BSNS_ID__ref_CRM_SPONSORSHIP_` | 1 | 관계 |
| 33 | `accepted_values_CRM_CAMPAIGN_CMPGN_TYPE1_NM_________` | 1 | accepted_values |
| 34 | `relationships_CRM_MEMBER_RESPONSOR_MBER_NO__MEMBER_DK__ref_CRM_MEMBER_` | 1 | 관계·MEMBER_DK |
| 35 | `relationships_CRM_MEMBER_DISCONTINUE_MBER_NO__MEMBER_DK__ref_CRM_MEMBER_` | 1 | 관계·MEMBER_DK |
| 36 | `accepted_values_FACT_EVENT_PARTICIPATION_PART_STATUS__1__2__3__4__5__6__110__120__130__140__150__160__170__180__190__200__210__220` | 1 | accepted_values |

## 3. 계열 분류 — 🔴 판정 축과 관측 축을 분리한다 (`O111 ㉢`)

**축 A = 테스트 유형별**(합 = 36 · 창작 0):

| 유형 | 테스트 수 |
|---|---|
| `relationships` | **21** |
| `not_null` | **9** |
| 예산 singular(`warn_erp_budget_*`) | **3** |
| `accepted_values` | **2** |
| 기타 singular(`warn_fep_nonnumeric_member_dk`) | **1** |
| 합 | **36** |

**축 B = 주제별**(합 = 36):

| 주제 | 테스트 수 | 비고 |
|---|---|---|
| `MEMBER_DK` 고아(관계) | **14** | `BLOCKING-1` 소관 |
| `MEMBER_DK` 비수치(singular) | **1** | `warn_fep_nonnumeric_member_dk` 62 |
| 그 밖의 관계 고아 | **7** | EVENT_KEY · SPNSR_BSNS_ID 2 · SNDNG_KEY 2 · CMPGN_CD 2 |
| 채움률(`not_null`) | **9** | |
| 코드 라벨(`accepted_values`) | **2** | |
| 예산 그레인 | **3** | `DEC-44` 소관 |
| 합 | **36** | |

🔴 **`▣VVV3` 의 「예산 3 / MEMBER_DK 13 / 채움률·라벨 20」은 「표 행 수」였다** —
표 한 행에 테스트 2~3종을 묶은 행이 3개 있어(`_DISCONTINUE`·`_RESPONSOR` /
`CMPGN_CD` 2종 / `not_null_CRM_EVENT_PARTICIPATION_*` 3종) **테스트 수와 다르다.**
⇒ 그 자체는 오류가 아니지만 **분모로 인용하면 틀린다.**

## 4. 🔴 `▣VVV3` 전수표 누락 1건 적발

| 축 | 값 |
|---|---|
| `▣VVV3` A+B+C 표가 담은 테스트 | **35** |
| 실측 전수 | **36** |
| 🔴 누락 | **`not_null_CRM_PAYMENT_BILLING_MBER_NO` = 5건** |

⇒ `▣VVV3 C` 에 `relationships_CRM_PAYMENT_BILLING_MBER_NO`(309)는 있는데
**`not_null_` 쪽(5)이 빠졌다** — 두 테스트는 **다른 축**이다(관계 고아 vs NULL).
🟢 이 근거철의 §2 표가 정본이고, `▣VVV3` 에 누락 1건을 병기했다.

## 5. 🟢 미규명 ㉠ 규명 완료 — `not_null_CRM_SEND_MEMBER_SEND_RESULT_NAME` = 1,401,419

### 5-1. 분모 (🔴 `R2-6` — 분모 없이 인용하면 과장·축소로 읽힌다)

라이브 실측 · `GN_DW.SILVER.CRM_SEND_MEMBER`:

| 축 | 값 | 비율 |
|---|---|---|
| 총 행수 | **38,467,887** | 100% |
| `SEND_RESULT_CD IS NOT NULL`(= **테스트 분모**) | **26,252,471** | 68.25% |
| 라벨 부착(`SEND_RESULT_NAME` NOT NULL) | **24,851,052** | — |
| 🔴 WARN 대상(코드 있고 라벨 없음) | **1,401,419** | **테스트 분모의 5.34%** · 총행의 3.64% |
| 라벨 커버리지 | — | **94.66%** |

🟢 **WARN 값 1,401,419 가 라이브에서 정확히 재현됐다** ⇒ 테스트 판정은 신뢰할 수 있다.

🔴 **「1,401,419건 NULL」을 「채움률 결손」으로 읽으면 틀린다.** 테스트에는
`where: "SEND_RESULT_CD is not null"` 이 걸려 있다(`_crm_schema.yml:612`)
⇒ 세는 대상은 **「코드값은 있는데 사전 라벨이 안 붙은 행」**이고 구조적 NULL 이 아니다.

**채널별 분해**(구조적 부재가 분모에서 이미 배제돼 있음을 확인):

| 채널 | 행수 | 코드 보유 | 라벨 | 미라벨 |
|---|---|---|---|---|
| `EMAIL` | 7,811,125 | **0** | 0 | 0(분모 밖) |
| `PSTMTR` | 1,798,680 | **0** | 0 | 0(분모 밖) |
| `MSG_AT` | 20,561,448 | 18,440,452 | 17,934,911 | **505,541** |
| `SND` | 8,296,634 | 7,812,019 | 6,916,141 | **895,878** |
| 합 | 38,467,887 | 26,252,471 | 24,851,052 | **1,401,419** ✅ |

🟢 `EMAIL`·`PSTMTR` 은 모델이 `CAST(NULL AS VARCHAR)` 로 두는 **구조적 부재**이고
(`CRM_SEND_MEMBER.sql:23·37` — 원천에 컬럼이 없다) 테스트 `where` 가 이를 정확히 배제한다.

### 5-2. 원인 분해 — 17종 (합 = 1,401,419 · 정확 일치)

| 원인 | 행수 | 비율 | 코드값 |
|---|---|---|---|
| ㉠ `SND` 단자리 코드가 `MS056` 에 미등재 | **824,030** | 58.8% | `9`·`3`·`5`·`4`·`0`·`6`·`8` |
| ㉡ 4자리 코드가 사전에 **아예 없음** | **577,389** | 41.2% | `7320`·`7319`·`9034`·`7321`·`7205` |
| 합 | **1,401,419** | 100% | 17종(채널×코드) |

**사전 실측**(`SILVER.CRM_CODE` · 모델이 조인하는 4그룹):

| 코드군 | 등재 수 | 대역 | 미매칭 값과의 관계 |
|---|---|---|---|
| `MS056` | 55 | `1`·`2` · `90xx`·`92xx`·`99xx` · 영문자 | 🔴 단자리는 **`1`·`2` 만** — `0,3,4,5,6,8,9` 없음 |
| `MS057` | 26 | `7000`~`7521` | 🔴 `7318`·`7322` 는 있고 **`7319`~`7321` 결번** · `7203`·`7204` 는 있고 **`7205` 결번** |
| `MS058` | 29 | `4100`~`4437` | 무관 |
| `MS059` | 36 | `6600`~`6670` | 무관 |

### 5-3. 🔴🔴 판정 — 「데이터(사전) 실상」이고 **테스트도 모델도 낡지 않았다**

* 🟢 **테스트는 의도대로 작동한다.** `_crm_schema.yml:612` 주석이 이미
  *"사전 초과값 실재(DEC-17-B 관측 · 라벨 NULL 유지)"* 라고 선언해 둔 그 현상이다.
* 🟢 **모델의 코드군 지정도 유지한다.** `MS057` 의 결번(`7319`~`7321`·`7205`)은
  **대역 안의 구멍**이므로 「다른 코드군을 골라야 한다」가 아니라 **사전이 원천을 못 따라간 것**이다.
* 🔴🔴 **관측 축 하나를 판정 근거로 쓰면 안 된다**(`O111 ㉢`) — 초기 조회에서 단자리 코드가
  `MM294`·`RM004` 등 **수십 개 타 코드군에 실재**한다고 나왔지만, 단자리 값은 **여러 코드군이
  공유하는 일반 연번**이라 **라벨 후보가 아니다.** 「사전에 있다」와 「이 코드군에 있다」는 다른 축이다.
* ⇒ **처방** = ㉠ 🔴 라벨 창작 금지(`DEC-17-B`·`R2-7-1`) ㉡ 🟠 **현업·원천에 사전 추가 요청**
  (제시할 값 = `MS056` 에 `0,3,4,5,6,8,9` / `MS057` 에 `7319,7320,7321,7205` / `9034` 소관 확인)
  ㉢ 🟢 **`severity: warn` 유지가 정당하다** — 사전 등재는 우리 소관이 아니다.
* 🟠 **잔여 질문(사람 소관)** = `SND.CALL_STATUS` 단자리 체계가 `MS056`(문자·`90xx` 혼재)과
  같은 코드공간이라는 모델 주석의 *"conformed"* 판단이 맞는가.
  🔴 데이터는 **부분 부정**을 가리킨다(단자리 7종 824,030행이 사전 밖) ⇒ 문서20 질의 후보.

## 6. 🟢 미규명 ㉡ 규명 완료 — `relationships_CRM_EVENT_PARTICIPATION_EVENT_KEY` = 263,611

### 6-1. 분모

| 축 | 값 |
|---|---|
| `SILVER.CRM_EVENT_PARTICIPATION` 총 행수 | **1,134,126** |
| 🔴 고아 행수(마스터 `CRM_EVENT` 에 없는 `EVENT_KEY`) | **263,611** = **23.24%** |
| 고유 고아 키 | **53**종(직접 실측 · 산술 합산 아님) |

🟢 WARN 값·비율이 모두 재현됐다 — `_crm_schema.yml:258` 의 「고아 263,611(23%)」과 일치.

### 6-2. 🔴 고아의 99.5%가 **키 2개**다

| `EVENT_KEY` | 참여 행수 | 고유 회원 | 참여기간 | 상태코드 |
|---|---|---|---|---|
| `EVENT_105` | **195,544** | 148,446 | 2022-10-16 ~ 2026-07-01 | 1종(전건 채움) |
| `EVENT_106` | **66,642** | 41,738 | 2022-10-16 ~ 2026-07-01 | 1종(전건 채움) |
| 소계 | **262,186** | — | — | 전건 `TD_MS_EVENT_PRTCPNT_DTL` |
| 그 밖 51종 | 1,425 | — | — | — |

🟢 **잔여 51종은 꼬리다**(각 1~59행) — 형태별로도 `EVENT_NNNN` 286 · `CRMN_` 계열 50 등 소규모다.

### 6-3. 🔴🔴 판정 — 「원천 마스터 결번」이고 **키체계 미확정이 아니다**

원천 직접 실측(`R2-3` · `GN_DW.BRONZE_CRM.TM_MS_EVENT`):

| 축 | 값 |
|---|---|
| 원천 행수 | **376** |
| `EVENT_CD` distinct | **376**(전건 유일) |
| `EVENT_CD` 범위 | **1 ~ 431** ⇒ 🔴 **결번 55개** |
| 🔴 `EVENT_CD IN ('105','106')` | **0건** |

마스터 인접 키 실측 = `EVENT_100`·`101`·`102`·`103`·`104`·`107`·`108`·`109`·`110` **전부 실재**하고
**`105`·`106` 만 구멍**이다(이름·기간까지 정상 보유).

⇒ 🟢 **배선·조인 규칙·키 생성식(`'EVENT_'||EVENT_CD`)은 정상**이고
**원천 행사 마스터에 그 2행이 없다**(삭제분으로 보인다). `▣VVV3 C` 의 「미규명」은 해소됐고
`_crm_schema.yml:258` 의 *"마스터 미완전/키체계 미확정"* 중 **「키체계 미확정」은 기각**된다.

🔴 **남은 것은 사람 소관 1건**(문서20 질의 후보) =
「`EVENT_105`·`EVENT_106` 이 무엇이었나 · 왜 마스터에서 사라졌나」.
🟠 판단 단서 = ㉠ 참여기간이 **4년**(2022-10 ~ 2026-07)에 걸친다 ⇒ 단발 행사가 아니라 **상시 채널**로 보인다
㉡ 인접 키(`101`~`104`)는 2022년 가을 단발 이벤트다 ⇒ 성격이 다르다
㉢ 참여 148,446 + 41,738 명 = 전 참여의 **23.1%** ⇒ 🔴 **이름 없는 행사에 참여 4분의 1이 묶여 있다.**
🔴 **회신 전 `error` 승격 금지**(`BLOCKING-2` 유지) — 마스터 2행이 들어오면 23%가 한 번에 해소된다.

## 7. 🟢 부수 확보 — `BLOCKING-1` 고아 정체 (▣VVV3 B · 형태 축)

`▣VVV3 B` 가 물은 3지선다(㉠ 탈퇴·삭제분 ㉡ 타 원천 소속 ㉢ 형식 오류)에 대한 **형태 축 실측**.
대상 = `SILVER.CRM_SEND_MEMBER.MBER_NO` 중 `CRM_MEMBER.MEMBER_DK` 에 없는 것(WARN 31,486).

| 형태 | 행수 | 고유 키 | 해석 |
|---|---|---|---|
| `NNNNNNN`(7자리) | **31,089**(98.7%) | **7,431** | 🔴 **형식 정상** ⇒ ㉢ 아님 · ㉠(탈퇴·삭제분) 유력 |
| 6자리 | 97 | 63 | 🟠 형식 이상 |
| `SNNNNNNNN`(영문+8자리) | 81 | 52 | 🟠 타 체계 접두 ⇒ ㉡ 후보 |
| 1~2자리 | 59 | 13 | 🟠 형식 이상 |
| 8자리 | 13 | 9 | 🟠 형식 이상 |
| 🔴 **한글 인명**(`김근영`·`최혜원` 등) | **139**(고유 93 · §8-2 실측) | 93 | 🔴🔴 **원천 오염** — 회원번호 자리에 **이름**이 들어 있다(컬럼 밀림/오입력) |

⇒ 🟢 **답의 방향** = 「형식 오류」는 **1.3% 미만**이고 본체(98.7%)는 **형식 정상 7자리** ⇒
**탈퇴·삭제분 가설이 유력**하다. 🔴 **다만 확정에는 「탈퇴·삭제 회원 원천」과의 대조가 필요**하고
그 원천이 이 계정에 있는지 미확인이다 ⇒ **`error` 승격은 여전히 보류**한다(`▣VVV3 B` 순서 유지).
🔴 **신규 발견 = 한글 인명 오염**은 종전 문서에 없던 축이다 ⇒ 원천 정정 사안(문서20 질의 후보).

## 8. 🔴 [O116-B 자기검토] 첫 회 판정의 약점 3건과 그 시정

### 8-1 🔴 회차 순서 판정에 실측이 빠져 있었다

첫 회는 「파일 append 순서 = 시간 순서」를 **가정**하고, 선두 블록의 `12:45` 스탬프가 채택 회차보다
늦어 보이는 것을 **확인하지 않고 넘겼다**. O116-B 가 실측했다:

| 블록 | 시각 범위 | `Done.` |
|---|---|---|
| 선두(회전으로 잘림 · 줄 1~12,829) | **12:44:26 ~ 14:16:24** | `PASS=414 WARN=33 TOTAL=447` |
| 🟢 채택 회차(줄 28,999~57,198) | **03:54:26 ~ 03:59:59** | `PASS=425 WARN=36 TOTAL=461` |

⇒ 🔴🔴 **로그에 날짜가 없다(시:분:초뿐)** ⇒ **시각으로 회차 순서를 판정하면 틀린다.**
🟢 채택 회차 종료 `03:59:59` 가 O115-C 기재와 **정확히 일치** ⇒ 회차 귀속이 **독립 축으로 교차검증**됐다.
🟢 결론적으로 첫 회의 판정은 **옳았지만 근거가 미완이었다** — 「성공 신호도 의심하라」의 사례다.

### 8-2 🔴 「수십 행」은 추정이었다 — 실측으로 대체

`MEMBER_DK` 고아 31,486 의 형태 분해(합 정확 일치):

| 분류 | 행수 | 고유값 |
|---|---|---|
| 숫자만 | **31,262** | 7,519 |
| 🔴 한글 포함(오염) | **139** | 93 |
| 기타(영문·기호) | **85** | 56 |

⇒ 첫 회 인수인계 문안 「규모는 수십 행」을 **139행 · 고유 93종**으로 정정했다(`R3-1` — 세지 않은 수 금지).

### 8-3 🔴🔴 구조결함 — 근거철을 「정본」으로 선언했다

첫 회는 이 파일을 「목록의 정본」으로 선언했다. 이 파일은 **게이트 분모 밖**이므로
`doc_heading_gate`·`doc_line_length_gate`·`doc_census`·`doc_type_gate` 가 **아무것도 검사하지 않는다**
⇒ 다음 세션이 정본을 관리 밖에서 찾게 되고, 손상·stale 을 탐지할 장치가 없다.
🟢 시정 = **문서50 §O116** 으로 전수표·규명·처방을 이관(게이트 분모 자동 편입) · 이 파일은 부속 근거로 강등.

## 9. 🟢 [O116-B] 잔여 미규명 3건 규명 — 상세 관측

### 9-1 🔴🔴 `SPNSR_BSNS_ID` 18,091 — 다중값 컬럼 (이번 검토의 최대 발견)

| 축 | 값 |
|---|---|
| `CRM_CAMPAIGN` 총 행수 | **36,163** |
| `SPNSR_BSNS_ID` 보유 | **34,704**(고유 472) |
| WARN(고아) | **18,091** = 보유행의 **52.13%** |

**형태로 완전히 갈린다**:

| 형태 | 행수 | 고아 | 고아율 | 고유값 |
|---|---|---|---|---|
| `MULTI`(쉼표 포함 · 예 `4,43,50`) | 18,091 | **18,091** | **100.00%** | 445(전부 고아) |
| `SINGLE` | 16,613 | **0** | **0.00%** | 27(전부 매칭) |

**성분 분해 검증**(`SPLIT_TO_TABLE`):

| 축 | 값 |
|---|---|
| 성분 행수 | **76,761** |
| 성분 고유값 | **14** |
| 🟢 마스터 미매칭 성분 | **0** |
| `CRM_SPONSORSHIP` 마스터 행수 | **50** |

⇒ 🔴🔴 **원천에 결손이 없다.** 「후원사업 마스터 미완전(50행, 고아 18,091)」은 **오진**이고,
**모델이 다중값 문자열을 단일 FK 로 취급한 설계 결함**이다.
🔴 **「전량입고 후 error 복귀」는 영구히 충족되지 않는 처방**이었다 ⇒ 폐기하고 설계 결정으로 올렸다.
🟠 선택지 = ① 단일값 부분집합 한정(`where … NOT LIKE '%,%'`) ② 캠페인×후원사업 브릿지 정규화.
🔴 ② 는 소비 계약을 바꾸므로 사람 결정이다(문서30) · 🔴 결정 전 `where` 를 좁히면 관측이 사라진다.

### 9-2 🔴 `MK_CMPGN_NM` 7,052 — 「회귀 감지용」 테스트가 회귀를 잡았다

| 축 | 값 |
|---|---|
| 테스트 분모(`MKTG_CMPGN_NM` 보유) | **33,956** |
| WARN | **7,052** = **20.77%** |
| 🟢 고아 코드 종수 | **1종 = `395`** |

`_crm_schema.yml` 주석은 *"323종, 고아 0"* · *"실측 고아 0 — 회귀 감지용"* 이었다 ⇒ **stale**.
🟢 원인이 **코드 1종**이므로 라벨 체계 붕괴가 아니라 **사전 미등재 1건의 파급**이다
(`MKTG_UTM` 고아 `192` 와 같은 패턴 ⇒ 같은 현업 질의에 묶는다).

### 9-3 🟢 `SNDNG_KEY` 11,313 — 채널별로 성격이 갈린다

| 채널 | 행수 | 고아 | 고유 키 | 고유 고아 키 |
|---|---|---|---|---|
| `PSTMTR` | 1,798,680 | **8,232**(0.46%) | 11,005 | 🔴 **7,375(67%)** |
| `MSG_AT` | 20,561,448 | **3,081** | 1,110,206 | 83 |
| `SND` | 8,296,634 | **0** | 1,645 | 0 |
| `EMAIL` | 7,811,125 | **0** | 498,606 | 0 |

발송요청 마스터 = **1,614,397**행. 시간 축 = 고아 `2024-01-02~2026-06-30` ↔ 매칭 `2024-01-03~2026-07-03`
⇒ 🔴 **같은 기간에 산발한다 = 기간 부분적재가 아니다** ⇒ 「전량입고」로 해소된다는 보장이 없다.
🟢 `SND`·`EMAIL` 이 0 이라는 사실이 **채널별 원천 성숙도 차이**를 가리킨다(PSTMTR 이 문제 축이다).


