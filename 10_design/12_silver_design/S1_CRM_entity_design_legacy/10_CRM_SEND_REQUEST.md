# S-1 엔티티 설계서 ⑩ `CRM_SEND_REQUEST`

> SILVER 정제 레이어 `GN_DW.SILVER.CRM_SEND_REQUEST` 설계서.
> 입력: `BRONZE_CRM 테이블 정보.MD` + **`컬럼정의서 20260622.csv`(권위 원천)** / 상위: `SILVER_설계_작업 계획.md` §1-1(#10), §0 원칙 4·5·10·11, **★R2**.
> GOLD 수요처: `FSE`(발송 마스터 속성: 제목#136·발송상태#138), `DIM_SERVICE`(발송구분 대/중/소 #133~135).
> 원천: `SND_REQ_MST`(54) · `TM_MS_EMAIL_SNDNG`(16) · `TM_MS_MSG_AT_SNDNG`(21) · `TM_MS_PSTMTR_SNDNG`(16) · `TM_MS_CRMN`(35) · `TM_MS_EVENT`(13) — **전 컬럼 정의됨 ✅ (R11/OPEN-37 해소)**.

---

## 1. 핵심 — ★R2 키 이원화 (R11 해소, 관계만 미상)

**R11/OPEN-37 해소**: 2026-06-22 정의서로 `SND_REQ_MST`·`TM_MS_CRMN`·`TM_MS_EVENT` 컬럼이 확정됨(기존 추론명과 거의 일치) → 더는 LLM생성 미검증 아님. **남은 차단은 R2(두 키 체계의 관계)뿐**.

| 시스템 | 대표 테이블 | 키 | 성격 |
|---|---|---|---|
| **SND_ 계열** | `SND_REQ_MST`(54) → `SND_MEMBER_LIST`(76) | `SEQ_NO` ← `REQ_SEQ_NO` | 발송요청 마스터(발송구분 대중소·제목·발송일시·상태·건수) |
| **TM_MS_ 계열** | `TM_MS_EMAIL/MSG_AT/PSTMTR_SNDNG` | `SNDNG_KEY` | 채널별 발신 헤더(이메일/알림톡/우편) |

> 맥락 마스터: `TM_MS_CRMN`(35, `CRMN_CD`)·`TM_MS_EVENT`(13, `EVENT_CD`).

**★R2(OPEN-36) — 두 키 체계 관계 미상**: `SEQ_NO`(SND_) ↔ `SNDNG_KEY`(TM_MS_)가 (a)미러(중복)/(b)채널분리 별개/(c)구·신 마이그레이션 중 무엇인지 → UNION이 정합/중복으로 갈림. **확인 전 통합 금지**.

> 🔎 **R2 해소 단서(신규)**: `SND_MEMBER_LIST`(76)에 `REQ_SEQ_NO`(→SND_REQ_MST.SEQ_NO)와 **`MSG_KEY`** 컬럼이 공존 → `MSG_KEY`가 TM_MS_ 계열 `SNDNG_KEY`와 연결되는 **브릿지**일 가능성. BRONZE 실측 시 `MSG_KEY`↔`SNDNG_KEY` 우선 확인 권고.

---

## 2. grain / PK

- **grain**: 1행 / 발송요청건(마스터). FSE 발송 마스터 속성 소스.
- **PK**: `SEND_REQUEST_KEY` = `SEND_SYSTEM || '-' || {SEQ_NO | SNDNG_KEY}`.
  - `SEND_SYSTEM`: 'SND' | 'EMAIL' | 'MSG_AT' | 'PSTMTR'(타입접두 패턴).
  - ⚠️ R2 미확정 시 UNION 중복 위험(미러면 제거 필요, OPEN-36).
- **회원 FK 없음**(마스터). 회원별 발송은 ⑪.
- **채널/캠페인 링크**: `CRMN_CD`·`EVENT_CD` 보존.

---

## 3. 컬럼 명세 (구조 — SEND_SYSTEM UNION)

> 정의서 확정 컬럼. 타입 일부 미기재(OPEN-5).

### 3-1. 공통 표준 (UNION 정합)

| SILVER 컬럼 | SND_REQ_MST | TM_MS_*_SNDNG | 정제 |
|---|---|---|---|
| `SEND_REQUEST_KEY` (PK) | 파생 | 파생 | `SEND_SYSTEM-키` |
| `SEND_SYSTEM` | 'SND' | 'EMAIL'/'MSG_AT'/'PSTMTR' | 판별자 |
| `SOURCE_KEY` | `SEQ_NO` | `SNDNG_KEY` | native 키 |
| `SEND_DT` | `SEND_DATE`(+`SEND_TIME`/`SEND_MIN`) | `SNDNG_STDR_DE` | 발송/발신 기준일시 |
| `SEND_TYPE_CD` | `MSG_TYPE` | `SNDNG_TY_CD`(MS281/CM015) | 발신유형 |
| `SEND_STATUS_CD` | `SEND_STATUS`·`APPR_STATUS` | `PRCS_YN`/`PRCS_STAT_CD`(MS061) | 발송/처리상태 → FSE #138 |
| `SEND_TITLE` | `SEND_TITLE` | `TIT` | 제목 → FSE #136 |
| `TARGET_CNT`/`SEND_CNT`/`FAIL_CNT` | #동일 | — | SND_ 전용 건수 |

### 3-2. 발송구분 (→ DIM_SERVICE) — SND_ 전용

| SILVER 컬럼 | 원천 | → GOLD |
|---|---|---|
| `SEND_GBN_TOP_CD`/`_NM` | `SEND_GBN_TOP`/`_NM` | DIM_SERVICE 발송구분_대 #133 |
| `SEND_GBN_MID_CD`/`_NM` | `SEND_GBN_MID`/`_NM` | 발송구분_중 #134 |
| `SEND_GBN_BOT_CD`/`_NM` | `SEND_GBN_BOT`/`_NM` | 발송구분_소 #135 |

> 발송구분 대중소는 **SND_ 전용**. TM_MS_는 채널코드(`SNDNG_CD_ID`/`SNDNG_DTL_CD_ID`)로 서비스 식별 → DIM_SERVICE 매핑 차이(OPEN-38).

### 3-3. 표준 감사/메타 컬럼 (원칙 10)
`_SOURCE_SYSTEM`='CRM' · `_SOURCE_TABLE`(SND_REQ_MST/TM_MS_* 행별) · `_LOADED_AT` · `_BATCH_ID`

> **제외/보존선택**: 본문(`MAIL_CONT`/`ALIM_TALK_CONT`/`SMS_TALK_CONT`)·주기/분할(`PERIODIC*`·`DIVIDE*`)·발신자·`RCPT_LIST`·`BTN_LIST`·`EXTRA`는 비분석 → 보존 선택.

---

## 4. GOLD 정합

- **DIM_SERVICE**(발송구분 #133~135): §3-2가 직접 소스(SND_). `SERVICE_TYPE`='발송서비스'(H). TM_MS_ 채널코드 매핑 OPEN-38.
- **FSE 발송 마스터 속성**: 제목(#136)·발송상태(#138). 회원별 행은 ⑪이 제공, 본 엔티티는 마스터 속성 조인 공급.
- **캠페인**: `CRMN_CD`(TM_MS_CRMN) → DIM_CAMPAIGN 정합 여부 OPEN-39.

---

## 5. OPEN 이슈

| ID | 이슈 | 영향 | 조치 |
|---|---|---|---|
| ~~OPEN-37~~ | ~~SND_/CRMN/EVENT LLM생성~~ | — | **✅ 해소(2026-06-22 정의서, 컬럼 확정)** |
| **★R2/OPEN-36** | `SEQ_NO`(SND_) ↔ `SNDNG_KEY`(TM_MS_) 관계 — 미러/disjoint/마이그레이션 | UNION 정합 vs 중복(FSE 발송수 왜곡) | **착수 전 최우선** — `SND_MEMBER_LIST.MSG_KEY`↔`SNDNG_KEY` 우선 실측(§1 단서) |
| **OPEN-38** | 발송구분 대중소(SND_) vs 채널코드(`SNDNG_CD_ID`, TM_MS_) → DIM_SERVICE 매핑 | DIM_SERVICE BK 정합 | 두 체계 매핑표 합의 |
| **OPEN-39** | `TM_MS_CRMN.CRMN_CD` ↔ ⑥ `CMPGN_CD` 동일/별개 캠페인 | DIM_CAMPAIGN 조인 | BRONZE 실측 |
| **OPEN-5(공통)** | 일부 타입 미기재 | 캐스팅 | S-2 전 확인 |
| **OPEN-3(공통)** | 코드 라벨(MS281·MS267·MS010·MS061·CM015) | 라벨 | ⑭ 후 |

---

## 6. 다음

- **R2 해소 전 구조만 확정** — R11 해소로 컬럼은 신뢰 가능. UNION 여부만 OPEN-36 후.
- **선결 최우선**: ★R2(OPEN-36 — `MSG_KEY`↔`SNDNG_KEY` 실측) > OPEN-38(DIM_SERVICE 매핑).
- **S-2**: R2 확정 후 UNION DDL(또는 시스템 분리). **⑪⑫ 공통 선결**.
