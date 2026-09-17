<!-- SPLIT-CHUNK 99_NEXT_SESSION.md | 006/035 | 허브 = 99_NEXT_SESSION.md | 원문 833~1022행 -->
<!-- 🔴 이 파일은 원문 무변경 조각이다. 편집은 허브 계약을 따른다 (scripts/split_doc.py --verify 로 바이트 동일성이 검사된다). -->
<!-- BODY-BEGIN (아래는 원문 무변경 · 편집 금지) -->
### ▣ VVV3 🔴 WARN 36건 — **전수 목록을 확보했다. 이것이 다음 세션의 주 작업이다**

🟢 `logs/dbt.log` 에서 추출한 **36건 전수**(보고된 WARN=36 과 일치 ⇒ 분모 확정).
🔴 **분류가 필요하다** — 「데이터 실상」인지 「테스트가 낡았는지」를 건별로 가려야 한다.

**A. 예산 그레인 3종 — `DEC-44` 소관 (정상 발화 · 진단이다)**

| 테스트 | WARN 행수 | O115 예측 대조 |
|---|---|---|
| `warn_erp_budget_yearly_grain` | **44** | 🟢 「44키 중복」과 일치 |
| `warn_erp_budget_procedure_merge` | **42** | 🟢 「42키가 차수 혼합」과 일치 |
| `warn_erp_budget_month_grain` | **528** | 🟠 O115 는 이 값을 예측하지 않았다 |

🔴 **지우거나 조건을 좁히지 마라**(`▣UUU6 ④`). `DEC-44` 종결 시 `error` 로 승격한다.

**B. 🔴🔴 `MEMBER_DK` 고아 계열 — `BLOCKING-1` 의 전제가 바뀌었다**

`_silver_bridge_schema.yml` 은 이 관계 테스트들을 *"회원 마스터 미완전 고아 정책 일관(warn) ·
**전량입고 후 제거→error 복귀**"* 로 두었다. 🔴 **그 전량입고가 이제 확인됐다**:

| 축 | 실측 |
|---|---|
| 브론즈 회원 합 | 정기 1,587,343 + 일시 175,722 = **1,763,065** |
| `SILVER.CRM_MEMBER` | **1,763,065** (= 브론즈 합 · `MEMBER_DK` **전건 유일**) |

⇒ 🔴🔴 **따라서 아래 고아는 「미입고」가 아니라 「실제 고아」다** — `BLOCKING-1` 의 warn 유지 근거가
**소멸했다.** 🔴 **error 로 승격할지, 아니면 고아의 정체를 먼저 규명할지 판단이 필요하다.**

| 테스트 | WARN 행수 |
|---|---|
| `relationships_CRM_SEND_MEMBER_MBER_NO → CRM_MEMBER` | **31,486** |
| `relationships_FACT_SERVICE_EVENT_MEMBER_DK → DIM_MEMBER` | **31,486** ← 같은 수 = 위 고아가 **하류로 전파** |
| `relationships_CRM_EVENT_PARTICIPATION_MBER_NO → CRM_MEMBER` | **9,480** |
| `relationships_FACT_EVENT_PARTICIPATION_MEMBER_DK → DIM_MEMBER` | **9,480** ← 같은 수 = 전파 |
| `relationships_CRM_PAYMENT_BILLING_MBER_NO → CRM_MEMBER` | **309** |
| `relationships_CRM_MEMBER_DEV_MBER_NO → CRM_MEMBER` | **270** |
| `relationships_FACT_MEMBER_EVENT_MEMBER_DK → DIM_MEMBER` | **271** |
| `relationships_FACT_MEMBER_MONTHLY_MEMBER_DK → DIM_MEMBER` | **199** |
| `relationships_GA4_IDENTITY_MBER_NO → CRM_MEMBER` | **153** |
| `relationships_CRM_MEMBER_STATUS_HIST_MBER_NO → CRM_MEMBER` | **85** |
| `relationships_CRM_PAYMENT_METHOD_MBER_NO → CRM_MEMBER` | **37** |
| `relationships_FACT_MEMBER_COHORT_MEMBER_DK → DIM_MEMBER` | **16** |
| `relationships_CRM_MEMBER_DISCONTINUE`·`_RESPONSOR` | 각 **1** |

🟢 **같은 수가 상·하류에 쌍으로 나타나는 것이 진단 단서다**(31,486 · 9,480) —
**SILVER 고아가 GOLD 로 그대로 전파**되며 **증폭되지 않는다** ⇒ 배선은 정상이고 **원천 문제**다.
🔴 **먼저 물을 것** = 그 회원번호가 ㉠ 탈퇴·삭제분인가 ㉡ 다른 원천 테이블 소속인가
㉢ 형식 오류인가. 🔴 **답 없이 error 로 올리면 build 가 멈춘다** — 순서를 지켜라.

🟢 **[2026-08-29 O116 부분 규명 — 형태 축]** 위 3지선다 중 **㉢ 이 먼저 배제된다.**
대상 = `CRM_SEND_MEMBER.MBER_NO` 고아 31,486(정본 = `_o116_warn_census.md §7`):
**7자리 정상 형태가 31,089행(98.7%) · 고유 7,431** ⇒ **형식 오류는 1.3% 미만**이고
본체는 **형식이 멀쩡한 회원번호**다 ⇒ 🟠 **㉠(탈퇴·삭제분) 가설이 유력**하다.
🔴 **확정에는 「탈퇴·삭제 회원 원천」과의 대조가 필요**하고 그 원천의 이 계정 실재가 미확인이다
⇒ **`error` 승격은 여전히 보류**한다(순서 유지).
🔴🔴 **신규 발견 = 원천 오염** — `MBER_NO` 자리에 **한글 인명**(`김근영`·`최혜원` 등)이 든 행이 있다.
종전 문서에 없던 축이고 **원천 정정 사안**이다(문서20 질의 후보).
🟢 **[O116-B 정정] 규모를 실측했다 = 139행 · 고유 93종**(첫 회 기재 「수십 행」은 추정이었다).
🟠 잔여 형태(합 31,486 정확) = 숫자만 **31,262**(그 중 7자리 31,089) · 한글 오염 **139** · 기타 영문·기호 **85**.
🔴 **정본은 문서50 §O116-3 ㉢ 이다**(근거철은 게이트 분모 밖이므로 수치 인용은 정본에서 하라).

**C. 🟠 채움률·라벨 계열 — 대부분 「미등재」이고 결손이 아니다**

| 테스트 | WARN 행수 | 메모 |
|---|---|---|
| `not_null_CRM_SEND_MEMBER_SEND_RESULT_NAME` | **1,401,419** | 🟢 **[O116 규명 완료]** 코드사전 미등재(분모 26,252,471 의 5.34%) · 정본 = **문서50 §O116-3 ㉠** |
| `relationships_CRM_EVENT_PARTICIPATION_EVENT_KEY → CRM_EVENT` | **263,611** | 🟢 **[O116 규명 완료]** 원천 마스터 결번(`EVENT_105`·`106` 이 99.5%) · 정본 = **문서50 §O116-3 ㉡** |
| `not_null_CRM_CAMPAIGN_MKTG_UTM_NM` | **21,682** | 🟢 **규명 완료** = 고아 UTM 코드 `192`(§N-8) ⇒ **미등재이고 결손 아님** |
| `relationships_CRM_CAMPAIGN_SPNSR_BSNS_ID → CRM_SPONSORSHIP` | **18,091** | 🔴🔴 **[O116-B 규명 완료 — 오진 정정]** 컬럼이 **쉼표 다중값**이라 관계 테스트가 성립하지 않는다(단일값 고아 0% / 다중값 고아 100%) · 정본 = **문서50 §O116-3 ㉣** |
| `relationships_CRM_SEND_MEMBER_SNDNG_KEY → CRM_SEND_REQUEST` | **11,313** | 🟢 **[O116-B 규명 완료]** `PSTMTR` 집중 8,232 + `MSG_AT` 3,081 · `SND`·`EMAIL` 0 · 정본 = **문서50 §O116-3 ㉥** |
| `not_null_CRM_CAMPAIGN_MK_CMPGN_NM` | **7,052** | 🔴 **[O116-B 규명 완료]** 「고아 0 · 회귀 감지용」 테스트의 **회귀 실측** · 고아 코드 **1종(`395`)** · 정본 = **문서50 §O116-3 ㉤** |
| `not_null_CRM_PAYMENT_BILLING_RQEST_RST_CD` | **1,096** | |
| `not_null_CRM_PAYMENT_BILLING_MBER_NO` | **5** | 🔴 **[O116 누락 보완]** 이 표에서 빠져 있었다(전수표가 35/36 이었다) · 같은 표의 관계 고아 309 와 **다른 축**이다 |
| `not_null_CRM_SEND_MEMBER_MBER_NO` | **745** | 🔴 `B` 의 31,486 과 **별개 축**(이쪽은 NULL) |
| `warn_fep_nonnumeric_member_dk` | **62** | |
| `relationships_CRM_MEMBER_DEV_CMPGN_CD`·`CRM_MEMBER_CMPGN_CD` | **18** · **4** | |
| `relationships_CRM_SEND_RESULT_SNDNG_KEY` | **9** | |
| `not_null_CRM_EVENT_PARTICIPATION_*` 3종 | 각 **2** | |
| `accepted_values_CRM_CAMPAIGN_CMPGN_TYPE1_NM` | **1** | 🟢 기지(`CMPGN_TYPE1_BSN=4` 고아코드) |
| `accepted_values_FACT_EVENT_PARTICIPATION_PART_STATUS` | **1** | |
| `relationships_CRM_PAYMENT_BILLING_SPNSR_BSNS_ID` | **1** | |

🔴 **분모를 먼저 적어라** — 「1,401,419건 NULL」은 `CRM_SEND_MEMBER` 총 행수를 함께 밝히지 않으면
과장으로도 축소로도 읽힌다(`R2-6` 축).
🔴🔴 **[O116 정정] 위 재현법은 그대로는 `0건` 을 낸다** — 이 로그에 ANSI 제어문자가 있어
BusyBox `grep` 이 **binary 로 판정**하고 `-o` 출력을 버린다. ⇒ **`-a` 가 필수다.**
🟢 **교정된 재현법**(회차 분리 포함 · 정본 = `_o116_warn_census.md §1`):
`grep -anE "Running with dbt=" 10_dbt_pipeline/logs/dbt.log` (회차 경계) →
`grep -aoE "[0-9]+ of [0-9]+ WARN [0-9]+ [A-Za-z0-9_]+" 10_dbt_pipeline/logs/dbt.log`
🔴 **`logs/dbt.log` 는 회전된다**(`.1`~`.5` 실재) ⇒ 🟢 **[O116] 정본화 완료 =
`_o116_warn_census.md §2` 에 36건 전수를 회차 귀속(`줄 28,999~57,198` ·
`Done. PASS=425 WARN=36 ERROR=0 SKIP=0 TOTAL=461`)과 함께 옮겼다.**
🔴 **한 파일에 여러 회차가 섞여 있다** — `dbt.log` 안에 `WARN=33 TOTAL=447` 등 다른 회차가 있으므로
회차를 분리하지 않고 세면 분모가 뒤섞인다.
🔴 **분류 수를 인용할 때 주의** — 위 A/B/C 표의 「3 / 13 / 20」은 **표 행 수**이고
**테스트 수는 A 3 / B 14 / C 19**(합 36)이다 — 한 행에 2~3종을 묶은 행이 3개 있고
C 는 O116 이 누락 1건을 보완했다(정본 = `_o116_warn_census.md §3`·`§4`).

### ▣ VVV4 🟢 이제 실행 가능해진 것 — `A.7 REMOVE`(스테이지 정리)

🟢 **전제 2건이 모두 충족됐다** = `▣UUU3 ⑦` 검증 통과(O115) + **`dbt build` 성공**(O115-C).
🔴 O115-B 가 보류한 이유가 *"build 미실행 · 유일한 복구 경로"* 였고 **그 전제가 해소됐다.**

| 축 | 실측 |
|---|---|
| 대상 | `SANDBOX.TOOLS.MIG_LOAD_STAGE` **2,643 파일 / 39.01 GB** |
| 내역 | `SILVER` 35.95 · `BRONZE_CRM` 3.03 · `ML` 0.03 · `AGENCY`·`ERP` ≈0 |
| 되돌림 | 🔴 **불가** — 비우면 로컬 업로드부터 다시 해야 한다 |

🔴 **여전히 `R4-4-3` 승인 대상이다.** 🟢 판단 재료 = ㉠ 브론즈·ML·SILVER 원본은 **테이블에 있다**
㉡ 스테이지는 **`04_..BRONZE_DDL` 재실행 사고**(2026-08-18 실현)의 복구 경로다
㉢ 그 DDL 을 **재실행하지 않는다는 규율**(`DDL-ORDER-1`)이 지켜지면 스테이지는 불요하다.
⇒ 🟠 **권고 = GOLD 소비 검증(SV·Agent 스모크)까지 마친 뒤 비운다.** 절차 = `07번 A.7`.

### ▣ VVV5 🟠 승계 미결 — 성격별로 갈라 둔다

**사람·현업 소관(에이전트가 못 끝낸다)**
| # | 항목 | 정본 |
|---|---|---|
| ㉠ | 🔴🔴 **`DEC-44` 회신**(추가경정 = 증분 / 재작성) | `30_설계-012 §30-B`·`§30-F` |
| ㉡ | `DIRECT_MNYRS_YN_1/2` 가 삭제된 `MNYRS_COST_DIV_YN` 의 대체인가 | `§30-B` |
| ㉢ | `EXPENSE_RESOLUTION` ↔ 예산 원장 관계(조인 근거 0.02%) | `▣UUU7` |
| ㉣ | SILVER 컬럼 COMMENT 공백 **9건**(`STSLC_` 계열) — 🔴 문안 창작 금지 | `▣UUU4 ㉠` |
| ㉤ | 신규 CRM 컬럼 3종 한글 COMMENT | `▣UUU4 ㉣` |
| ㉥ | UTM 고아 코드 `192`(21,682행) — 센티넬인가 등재 누락인가 | `20_현업확인 §N-8` |
| ㉦ | NL 스모크(CoWork UI) | 착수표 ② |

**계정·접근 소관**
| # | 항목 |
|---|---|
| ㉧ | `02_1_A DB정보.sql` 재추출 — 🔴 **A 원천 DB 가 이 계정에 없다**(`▣UUU4 ㉡`) · 그때 04번 병합 규칙 우선순위를 **함께** 되돌린다 |
| ㉨ | `SERVING`·`ML` 스키마 `USAGE` 미부여 — 🟢 dbt 무영향(실측) · 🔴 **SV·Agent 배포 시 필요** |

**에이전트가 진행 가능**
| # | 항목 |
|---|---|
| ㉩ | 🔴 **WARN 36건 분류**(위 `▣VVV3`) — 최대 작업 |
| ㉪ | 🟠 착수표 열린 10건 중 ⑫(활동 스냅샷 as-of)·⑭(`SPONSORSHIP_SK` 동시중단) = **🔴 정의 확정 전 배선 금지** |
| ㉫ | 🟠 문서50 열린 17절 · 미봉합 인용처 **19건**(`decision_closure_gate`) |
| ㉬ | 🟠 `_o114b_silver_gold_impact.md` 전량 대조 미실시(`merge_check` 포함율 5.9%) ⇒ 이관 후 삭제 |
| ㉭ | 🟠 착수표 ④⑤⑦⑨⑪⑰⑱ (B1 소관 정의 · C4 발행 표면 · C3 신선도 링크 · B3 표 열수 20건 등) |

### ▣ VVV6 🔴 O115 계열이 남긴 판정식 3조 — **읽고 시작하라**

㉠ **권한 검증**(`▣UUU9 A-1`) = `COUNT(*)` 금지 · `USE SECONDARY ROLES NONE` 필수 ·
   `USE ROLE` 과 쿼리를 **한 호출에** · **양성 대조** 포함 · 끝나면 복구.
   🔴 O115-B 가 이것을 몰라 **옳은 결론을 두 번 스스로 뒤집었다.**
㉡ **컴퓨트 생존**(`▣UUU8 ㉡`·O115 ①) = `SUM(<실컬럼>)` 으로 스캔을 강제한다.
   🔴 `COUNT(*)`·`CURRENT_TIMESTAMP()`·**`SUM(1)`** 은 메타데이터로 답한다.
㉢ **차원 행수 판정**(위 `▣VVV1`) = 원천 행수와 비교하기 전에 **SCD2 인지 모델 헤더를 읽어라.**
🟢 공통 교훈 = **「성공 신호」와 「실패 신호」 둘 다 판정식을 의심해야 한다.**
🔴 **검증 실패는 판정 실패보다 위험하다** — 판정은 「미확인」으로 남지만 무효한 검증은 **거짓 신뢰**를 만든다.

---

## ~~0-UUU~~. 🔴🔴 [2026-08-29 O114 필독 — ~~**여기서 시작한다.**~~ **§0-VVV 로 승계됐다**]

✅ **[O170] 은퇴 이관 → `90_해소완료_로그.md` §🟢 [O170 은퇴] 99_NEXT 승계 인수인계 절 — 99_NEXT_SESSION-006** — 이 절 본문을 그 문서로 **무변경 이동**했다(`R2-8` 토큰 대조 통과 · 본문 SHA256 `af3367edfc42e992`). 🔴 **절 삭제가 아니다**: 제목 줄과 `§` 인용 좌표는 그대로다(`R1-7-4` 축).

### ▣ UUU1 🔴🔴 먼저 알아라 — 이 세션은 **라이브가 있는 계정**이었고 DDL 은 이미 만들어져 있다
### ▣ UUU2 🟢 O114 가 닫은 것 — 승계 미결 6건 중 1.5건