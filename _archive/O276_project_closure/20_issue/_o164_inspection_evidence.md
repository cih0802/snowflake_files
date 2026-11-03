<!-- LLM-METADATA
doc_id: O164_INSPECTION_EVIDENCE
doc_role: O164 누적작업 비판적 검토(Inspection) 근거철 — 판정식·실측값·처방
project: GN_DW (굿네이버스)
created: 2026-09-15
created_by: O164
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

# _o164_inspection_evidence — O164 Inspection 근거철

> 🔴 이 파일은 **판정보다 먼저 쓴 근거**다(`R1-3-7-c`).
> 절차 정본 = `60_repeat_어카운트시작/11_O누적작업_점검_재현_절차.md`

---

## ▣ 0. 점검 메타

| 축 | 값 |
|---|---|
| 라벨 | `O164` (`id_collision_gate --next O` = 정의 163 · 참조 163 ⇒ 164) |
| 점검 구간 | **O156 ~ O163** (직전 Inspection = `O155`) |
| 결번 확인 | `O156`(이력-065:112 · 원장-002:5) · `O157`(rc=0 · 5건) 실재 ⇒ **결번 0건** |
| 계정 조건 | 🆕 **새 계정** · agent·cowork 가용 · paid 동급 |
| 라이브 상태 | `GN_DW` created **2026-09-15 00:11** · SV 17종 created **01:17~01:18** |

### 0-1. 라이브 분모 실측 (`SHOW DATABASES` · `INFORMATION_SCHEMA.TABLES`)

| 스키마 | 유형 | 개수 | 행수 |
|---|---|---|---|
| BRONZE_AGENCY | BASE TABLE | 4 | 248,214 |
| BRONZE_CRM | BASE TABLE | 50 | 122,474,251 |
| BRONZE_ERP | BASE TABLE | 2 | 160,587 |
| BRONZE_GA4 | BASE TABLE | 2 | 45,340 |
| BRONZE_GSC | BASE TABLE | 2 | 921,701 |
| GOLD | BASE TABLE | 37 | 149,106,156 |
| GOLD | VIEW | 14 | — |
| ML | BASE TABLE | 16 | 1,045,732 |
| OPS | BASE TABLE | 4 | 7 |
| SERVING | VIEW | 7 | — |
| SILVER | BASE TABLE | 48 | 132,813,020 |

- BRONZE 합 = **60** (문서 기재 「브론즈 60」과 일치)
- FK = **56** (O163 주장 「FK 56」과 일치)
- SILVER = **48** · SILVER CRM 접두 = **29**

🟢 **판정** = O163 이 주장한 「드리프트 0 · FK 56」은 **새 계정에서도 참**이다.
라이브는 문서작업 계정이 아니라 **전량 적재된 실계정**이다 ⇒ `R2-8-4-c`(판정 보류) 조항은
이 세션에 **적용되지 않는다**. 라이브 판정을 할 수 있다.

---

## ▣ 1. `D1` — SV view-level COMMENT 가 라이브에 없는 객체를 가리킨다 (🔴 O155 `D3` 재발)

| 축 | 값 |
|---|---|
| 판정식 | 절차서 §3 **#7**(라이브 메타데이터가 라이브에 없는 객체를 가리키나) + **#8**(파일↔라이브 일치를 「옳다」로 오독) |
| 도구 | `SHOW SEMANTIC VIEWS IN DATABASE GN_DW` + `GET_DDL('SEMANTIC_VIEW', …)` + `INFORMATION_SCHEMA.TABLES` 대조 |
| 실측 | `SV_EVENT_PARTICIPATION` view-level `comment` = **`base: GOLD.FACT_EVENT_PARTICIPATION`** |
| 라이브 실물 | `GOLD.FACT_EVENT_PARTICIPATION` = **부재**. 실물은 **`GOLD.FACT_EVENT_ATTENDANCE`** |
| 교차 증거 | 같은 DDL 의 **table 절**은 옳다 = `FEP as GN_DW.GOLD.FACT_EVENT_ATTENDANCE` |
| 교차 증거2 | 같은 DDL 의 **table-level comment** 도 옳다 = `(base: GOLD.FACT_EVENT_ATTENDANCE)` · `[원천: … → GOLD.FACT_EVENT_ATTENDANCE]` |

### 1-1. 원문 인용 (`GET_DDL` 출력 · 요약 아님)

- table 절 (옳음):
  `FEP as GN_DW.GOLD.FACT_EVENT_ATTENDANCE with synonyms=('행사 참여','이벤트 참여','행사 출석')`
- table-level comment (옳음):
  `comment='행사/이벤트 신청 및 참석 성과 분석 (base: GOLD.FACT_EVENT_ATTENDANCE). [Grain: 행사일 × 회원 × 행사].`
- 🔴 view-level comment (**틀림**):
  `comment='Phase-1 행사 참여 SV (base: GOLD.FACT_EVENT_PARTICIPATION, grain: 행사참여 1행).`

### 1-2. 왜 이것이 결함인가

- 🔴 **view-level COMMENT 는 AI 컨텍스트다** — Cortex Analyst·Agent 가 이 문장을 읽는다.
  ⇒ 「어느 테이블이 base 인가」를 사용자에게 **틀리게 답한다**.
- 🔴 **O155 `D3` 와 동일 유형이다.** O155 는 `SV_MEMBER_EVENT` 1건을 **손으로 고쳤고**
  같은 축을 보는 **게이트를 만들지 않았다** ⇒ 다른 SV 에 같은 결함이 살아남았다.
- 🔴 `comment_drift_gate` 의 판정식은 **SHA256(파일) == SHA256(라이브)** 다
  ⇒ 파일·라이브가 **같이 틀리면 🟢** 다(절차서 §4-3). 이 결함은 그 구조적 한계의 실물이다.
- 🟢 이 계정은 **오늘 재구축**됐고 SV 17종이 **오늘 01:17~01:18 에 생성**됐다
  ⇒ 이 오류는 계정 이전의 잔재가 아니라 **현재 라이브의 활성 결함**이다.

---

## ▣ 2. `D2` — 세션 종료 절차 미이행: 게이트 FAIL 2건을 남기고 닫았다

| 축 | 값 |
|---|---|
| 판정식 | 절차서 §2 Phase 5-1(게이트 전건 rc=0) 의 **역방향 점검** — 직전 세션이 그것을 했는가 |
| 도구 | `session_brief.py --write` §6 · `doc_type_gate.py`(rc=1) · `doc_heading_gate.py`(rc=1) |

### 2-1. `doc_heading_gate` rc=1 — 제목 유실 4건

원문 인용 (`/tmp/dh.out`):

```
🔴 99_NEXT_SESSION.md: 제목 유실 ▸ 2|0-JJJJ. 🔴🔴 [2026-09-16 O162 필독 — **여기서 시작한다.** §0-IIII 는 승계됐다]
🔴 99_NEXT_SESSION.md: 제목 유실 ▸ 3|▣ JJJJ1 🟢 O162 가 한 일 (색인 · 상세 = 이력 §O162 · 원장 §1 O162 행)
🔴 99_NEXT_SESSION.md: 제목 유실 ▸ 3|▣ JJJJ2 🔴 잔여 열린 작업
🔴 99_NEXT_SESSION.md: 제목 유실 ▸ 3|▣ JJJJ3 🔴 현행 열린 작업 — §0-IIII ▣IIII3 **그대로 승계**(압축 · 누락 아님)
```

🟢 **실유실 0** — 4건 전부 O163 이 `§0-JJJJ` 를 **승계 취소선 처리**한 결과다
(신설 7건에 `0-JJJJ. 🟢 [2026-09-16 O162 — ~~여기서 시작한다~~ · **§0-KKKK 로 승계됨**]` 이 있다).
⇒ `init_ihcho` 세션 종료 절차가 명시한 **정상 관례**이고, 처방은
`doc_heading_gate.py --update-golden --reason "<승계 표기>"` 다.
🔴 **O163 이 그 발행을 하지 않아 게이트가 FAIL 상태로 다음 세션에 인계됐다.**

### 2-2. `doc_type_gate` rc=1 — 상한 초과 1건

원문 인용 (`/tmp/dt.out`):

```
축2 상한 초과(바이트·문자 · 조각은 줄 수도): 1건
  🔴 99_NEXT_SESSION.md: 40982 B > 40KB
축3·4 여유 부족(경고): 3건
  🟠 00_INDEX_이슈원장.md: max 여유 4,966 B (< 20%)
  🟠 00_작업지침_세션운영규칙.md: max 여유 3,935 B (< 20%)
  🟠 99_NEXT_SESSION.md: max 여유 -22 B (< 20%)
```

🔴 O163 이 `§0-KKKK` 절을 써서 `99_NEXT_SESSION` 조각이 **40,982 B(상한 초과 -22 B)** 가 됐다.
`init_ihcho` 세션 종료 절차는 이 경우 **「압축 또는 재균형」**을 지시하고
재균형은 `R4-4-3` **승인 대상**이다 ⇒ O163 은 둘 중 어느 것도 하지 않았다.

### 2-3. 이것이 왜 「점검」의 대상인가

- 🔴 **게이트 FAIL 은 다음 세션의 브리핑 첫 줄에 뜬다** ⇒ 다음 세션은 착수 즉시
  「내가 깼나」를 조사하게 된다(`OPS-3` 낡은 뷰 오판 경로).
- 🔴 절차서 §0-1 의 제1 원리는 「게이트 전수 PASS 가 무결의 증거가 아니다」인데,
  이번 구간은 그 **앞단계**에서 이미 깨져 있었다 = **게이트가 FAIL 인 채로 세션이 닫혔다**.
  ⇒ 🟢 이것은 **새 판정식**이다(§3 신설 후보).

---

## ▣ 3. `D3` — 세션 날짜가 「오늘」보다 미래다

| 축 | 값 |
|---|---|
| 판정식 | 신설 — 세션 라벨의 기재 날짜가 **실제 오늘**을 넘지 않는가 |
| 실측 | 환경 오늘 = **2026-09-15** |
| 원장 §1 | `O161` = 2026-09-15 · `O162` = **2026-09-16** · `O163` = **2026-09-17** |
| 좌표 | `00_INDEX_이슈원장_조각/00_INDEX_이슈원장-001.md:150`(O163) · `:151`(O162) |

- 🔴 O162 는 **+1일**, O163 은 **+2일** 미래로 기재돼 있다.
- 🔴 이것이 왜 문제인가 = `session_brief.py` 의 인수인계 현행 절 판정식은
  **「날짜가 최신인 절」**이다(`init_ihcho` Step 2) ⇒ **미래 날짜는 그 판정을 영구히 선점**한다.
  이후 세션이 취소선을 빼먹으면 **O163 절이 계속 현행으로 뽑힌다**.
- ⚠️ **대안 가설** = 환경 날짜가 틀렸을 수 있다. 이 축은 **관측**으로 적고
  판정은 사용자에게 넘긴다(절차서 §4-4 「매치의 이웃을 보라」).

---

## ▣ 4. `D4` — 🔴🔴 기준선이 「라이브 AI 컨텍스트 결함」을 백로그로 흡수했다

| 축 | 값 |
|---|---|
| 판정식 | 신설 — **기준선이 있는 게이트의 잔여 안에 「라이브가 읽는 표면」이 섞여 있지 않은가** |
| 실측 | `rename_stale_gate` 는 `FACT_EVENT_PARTICIPATION`·`FACT_TARGET_DEV` 를 **이미 대응표에 갖고 있었다**(`scripts/rename_stale_gate.py:57`·`:59`) |
| 그런데 | 축1 잔여 **409건**의 일부로 세고 **「기준선 증감 +0 ⇒ 🟡 통과」**로 닫았다 |
| 좌표 증거 | `--list` 출력에 `05_SV-Agent_ai/05_5_SV_DDL_EVENT_PARTICIPATION.sql (2건)` · `05_2_SV_DDL_MEMBER_EVENT.sql (2건)` 가 **축1 로 열거**된다 |
| 그 파일의 정체 | 🔴 **라이브 SV COMMENT 의 소스**다 — `05_5:88` · `05_2:82` 가 그대로 라이브에 배포돼 있다 |

### 4-1. 왜 이것이 「게이트가 보지 않는 축」인가

- 🟢 `rename_stale_gate` 의 버킷은 **① 살아있는 정본(blocking) ② 자동 생성물(경고) ③ 이력(관측)** 이다
  (절차서 §5-2 규약). 이 세 버킷은 **「문서를 사람이 읽는다」**를 전제한다.
- 🔴 그런데 SV DDL 파일은 **문서가 아니라 라이브 AI 컨텍스트의 소스**다.
  ⇒ 그 잔여는 「나중에 고칠 문서 표기」가 아니라 **지금 사용자에게 틀린 답을 내는 활성 결함**이다.
- 🔴 기준선의 계약은 **「증가 차단」**이므로(§5-3) 이 결함은 기준선 안에서 **영구히 조용하다.**
  O155 가 남긴 인수인계 문구 *「개명 축1 잔여 536건(기준선이 증가만 막는다)」*이
  **정확히 이 상태를 예고했지만 버킷을 나누지는 않았다.**
- 🟢 **처방** = 절차서 §5-2 의 버킷 규약을 확장한다 —
  **④ 라이브가 읽는 표면(SV·Agent COMMENT 소스)은 기준선 대상이 아니다.**
  집행 도구 = `scripts/sv_comment_object_gate.py`(기준선 **없음** · 해소를 요구한다).

---

## ▣ 5. `D5` — `rename_stale_gate` 분모 누락: `DEC-50` GOLD 개명 4종

| 축 | 값 |
|---|---|
| 판정식 | 절차서 §3 **#6**(개명·폐기된 이름) 의 **분모 축** + `R3-9 ㉡`(같은 것을 다르게 재는 지점) |
| 실측 | `RENAMES` 는 **8종**이었고 `DEC-50`(2026-09-04 O139) 의 GOLD 개명 **4종이 전부 없었다** |
| 누락 4종 | `DIM_GA_EVENT`→`DIM_BIGQUERY_EVENT` · `DIM_GA_SOURCE`→`DIM_BIGQUERY_SOURCE` · `FACT_GA_BEHAVIOR`→`FACT_BIGQUERY_BEHAVIOR` · `WIDE_GA_BEHAVIOR`→`WIDE_BIGQUERY_BEHAVIOR` |
| 결정 정본 | `20_issue/30_설계_의사결정_조각/30_설계_의사결정-016.md:83` (§36-A 3항) |
| 집행 확인 | 라이브 GOLD 에 `DIM_BIGQUERY_EVENT`·`DIM_BIGQUERY_SOURCE`·`FACT_BIGQUERY_BEHAVIOR`·`WIDE_BIGQUERY_BEHAVIOR` **전건 실재** · 구 이름 4종 **0건** |
| 🔴 확장 후 실측 | 축1 **409건 → 533건**(**+124건** / 신규 파일 **18개**) ⇒ **124건이 검사 밖에 있었다** |
| 기준선 | `--baseline --reason` 으로 533 재발행 (🔴 **해소가 아니라 증가 차단 재설정** · 124건은 미해소 백로그) |

### 5-1. 🟢 상충 문안의 해소 (판정식 #15 — 매치의 이웃을 보라)

같은 문서에 두 문장이 있어 오판할 수 있었다:

- `30_설계_의사결정-016.md:39` = *"GOLD `DIM_GA_EVENT`·…·`WIDE_GA_BEHAVIOR`: **불변**"*
- `30_설계_의사결정-016.md:83` = *"**GOLD WIDE**: `WIDE_GA_BEHAVIOR` → `WIDE_BIGQUERY_BEHAVIOR`"*

🟢 **모순이 아니다** — 39행은 **`DEC-48` §34-D**(선행 결정)이고 83행은 그것을
**승계한 `DEC-50` §36-A**(2026-09-04 O139)다. 라이브가 `WIDE_BIGQUERY_BEHAVIOR` 이므로
**`DEC-50` 이 집행됐다**는 것이 판정 근거다(`R2-8-4` — 근거는 조회 결과다).

### 5-2. ⚠️ 일부러 넣지 않은 것

`DEC-51`(`GA_CONV_MEMBERS`→`AGENCY_CONV_MEMBERS` 등)은 **분모에 넣지 않았다** —
인수인계 `§0-KKKK ▣KKKK4` 가 *「GA 접두 유지 판정 · 재검 대상」*으로 **열어 둔** 항목이다.
🔴 **결정 대기 중인 것을 배선하지 않는다**(절차서 Phase 3-3 「0 센티넬 가드」와 같은 축).

---

## ▣ 6. `D6` — 🔴🔴 O164 자기시정: 내 판정식이 오탐 3건을 냈다 (절차서 §4-4 재현)

절차서 §4-4 는 *「판정식은 매치의 「이웃」을 봐야 한다 · 패턴 건수를 근거로 쓰기 전에
매칭된 실물을 열어라」*고 적는다. **이 세션이 그 함정에 그대로 빠졌다.**

| 회차 | 내 초판 판정식 | 오판 | 실체 (실물 확인 후) |
|---|---|---|---|
| 1 | `SCHEMA.OBJECT` 정규식 | `SILVER.AGENCY_AD_` 라이브 부재 | 원문은 **`SILVER.AGENCY_AD_*`**(접두 와일드카드) · 라이브 접두 적중 **8건** |
| 2 | 형제는 **스키마**를 물려받는다 | `SILVER.REQUEST` 라이브 부재 | 원문 `SILVER.CRM_SEND_MEMBER/REQUEST` = **`SILVER.CRM_SEND_REQUEST`**(실재) — 형제는 **이름 어간**을 물려받는다 |
| 3 | 같음 | `SILVER.DISCONTINUE` 라이브 부재 | 원문 `∪ CRM_MEMBER_DEV/DISCONTINUE` = **`SILVER.CRM_MEMBER_DISCONTINUE`**(실재) |
| 4 | 형제 체인의 어간 출처 = **최초 객체** | 음성 테스트 축4 FAIL | 어간 출처는 **직전 형제**다(`CRM_PAYMENT_BILLING` 이 아니라 `CRM_MEMBER_DEV`) |

🔴 **그리고 판정 방향까지 틀렸다** — 나는 ①② 를 blocking, ③(무스키마 토큰)을 advisory 로 설계했다.
실측은 **정반대**였다:

| 축 | 내 초판 등급 | 라이브 실측 결과 |
|---|---|---|
| ①② (스키마 정규화·형제) | 🔴 blocking | **낸 3건이 전부 내 오탐** (진짜 결함 1건은 ① 이 잡았다) |
| ③ (무스키마 객체형 토큰) | 🟠 advisory | **낸 4건이 전부 진짜 결함** (오탐 0 · 정밀도 **4/4**) |

🟢 **처방** = ③ 을 **blocking 으로 승격**하고 ①② 의 판정식을 **이웃 인식**으로 고쳤다
(와일드카드 · 어간 체인 승계). 음성 테스트 **12축**이 두 시정을 각각 단정한다
(축3·4 = 오탐 0 단정 · 축5 = 검사를 끄지 않았다는 단정 · 축6·7 = 와일드카드 양방향 ·
축8·9·10 = ③ blocking 승격 · 축11 = 경계 · 축12 = 분모 0 노출).

> 🟢 **이 세션이 남기는 규칙** = **판정식의 「blocking / advisory」 배분도 실측으로 정하라.**
> 절차서 §4-4 는 「매치의 이웃을 보라」까지 갔지만, **어느 축을 blocking 으로 둘지**는
> 설계 직관에 맡겨져 있었다. 직관은 이번에 **완전히 반대**였다.

---

## ▣ 7. 미확정 · 승인 대기

| # | 축 | 상태 |
|---|---|---|
| A | 🔴 라이브 SV COMMENT 시정 4건 (`SV_EVENT_PARTICIPATION`·`SV_SERVICE`·`SV_MEMBER_EVENT`·`SV_BUDGET`) | 🟠 **`R4-4-3` 승인 대기** — `CREATE OR REPLACE SEMANTIC VIEW` 는 라이브 REPLACE 다 |
| B | 파일 정본 4곳 동시 시정 (`05_5:88`·`05_4:36`·`05_4:86`·`05_6:60`·`05_2:82`) | 🟠 A 와 **한 쌍이다** — 한쪽만 고치면 `comment_drift_gate` 가 FAIL 한다 |
| C | `SV_BUDGET_YEARLY` 의 처방 | 🔴 **개명이 아니다** — 실재하지 않는 SV 로 AI 를 유도한다. 라이브에 `GOLD.FACT_BUDGET_YEARLY`(테이블)는 있으나 SV 는 없다 ⇒ 문안 재작성이 필요하고 **사람 판단 소관** |
| D | 개명 축1 잔여 **533건 / 124파일** | 🔴 미해소 백로그(기준선은 증가만 막는다) |
| E | O162 「SILVER 44테이블」 ↔ 라이브 48 | 🟠 미조사 — 다음 점검 대상 |

---
_Co-authored with CoCo_

