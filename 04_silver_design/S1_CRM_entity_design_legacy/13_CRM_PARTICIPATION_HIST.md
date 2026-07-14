# S-1 엔티티 설계서 ⑬ `CRM_PARTICIPATION_HIST`

> SILVER 정제 레이어 `GN_DW.SILVER.CRM_PARTICIPATION_HIST` 설계서.
> 입력: `BRONZE_CRM 테이블 정보.MD` / 상위: `SILVER_설계_작업 계획.md` §1-1(#13), §0 원칙 4·5·10·11.
> GOLD 수요처: `FSE`(서신참여 #139~140·선물금참여 #141~142·이벤트/캠페인 참여, +5일차 attribution).
> 원천(참여 grain): `TM_RM_RELATNSP_LETTER_INFO`(16, 서신) · `TM_RM_RELATNSP_GFTMNEY_INFO`(20, 선물금) · `TD_MS_EVENT_PRTCPNT_DTL`(17, 이벤트) · `TD_MS_CRMN_PRTCPNT`(21, 캠페인) — **전 컬럼 정의됨 ✅ (R11 해소, 2026-06-22 정의서 — 설계 컬럼과 일치)**.

---

## 1. 핵심 — 4종 참여 UNION ALL + 회원링크 이원 + 발송 attribution 미상

본 엔티티는 이질적인 **참여 4종을 UNION ALL**(PARTICIPATION_TYPE 판별자, 회원·납입과 동일 패턴). 세 가지 유의:

1. **회원 링크 이원화**: 이벤트/캠페인은 `MBER_NO` **직접 보유**; 서신/선물금은 `RELATNSP_KEY` 경유 → ⑮ `CRM_SPONSORSHIP_RELATION`에서 `MBER_NO` 해소(**간접**, OPEN-48).
2. **발송 attribution 미상**: FSE는 참여를 발송행(+5일차)에 귀속하나, 서신/선물금에 `SNDNG_KEY` 없음(`SNDNG_DE`만) → ⑩⑪ 발송과 매칭 규칙 불명(OPEN-49).
3. **✅ 4원천 컬럼 확정(R11 해소)**: 2026-06-22 정의서로 컬럼명·의미 검증됨(기존 설계 컬럼과 일치).

---

## 2. grain / PK

- **grain**: 1행 / 참여건.
- **PK**: `PARTICIPATION_KEY` = `PARTICIPATION_TYPE || '-' || {native 키}`.
  - LETTER: `RELATNSP_KEY`+`MNG_NO`+`SNDNG_DE` / GIFT: `RELATNSP_KEY`+`MNG_NO` / EVENT: `EVENT_CD`+`MBER_NO`+`PARTCPT_SEQ` / CAMPAIGN: `CRMN_CD`+`PRTCPNT_KEY`. 유일성 OPEN-50.
- **회원 FK**: `MEMBER_KEY` — EVENT/CAMPAIGN 직접(`MBER_NO`), LETTER/GIFT 간접(`RELATNSP_KEY`→⑮, OPEN-48).
- **결연 링크**: `RELATNSP_KEY`(LETTER/GIFT) → ⑮.

---

## 3. 컬럼 명세 (참여 UNION 표준)

> 정의서 확정 컬럼(R11 해소). 타입 캐스팅 잠정(OPEN-5).

| SILVER 컬럼 | 타입 | LETTER | GIFT | EVENT | CAMPAIGN | 정제 |
|---|---|---|---|---|---|---|
| `PARTICIPATION_KEY` (PK) | VARCHAR | 파생 | 파생 | 파생 | 파생 | `TYPE-native키` |
| `PARTICIPATION_TYPE` | VARCHAR | 'LETTER' | 'GIFT' | 'EVENT' | 'CAMPAIGN' | 판별자 |
| `MEMBER_KEY` (FK) | VARCHAR | RELATNSP→⑮ | RELATNSP→⑮ | `MBER_NO`(#2) | `MBER_NO`(#3) | 접두 OPEN-48 |
| `RELATNSP_KEY` | VARCHAR | `RELATNSP_KEY`(#1) | `RELATNSP_KEY`(#1) | NULL | NULL | 결연링크 |
| `PARTICIPATION_DE` | DATE | `SNDNG_DE`(#6) | `SNDNG_DE`(#12) | `PARTCPT_DT`(#9) | `PARTCPT_DATE`(#12) | 참여/발신일 |
| `PARTICIPATION_DIV_CD` | VARCHAR | `LETTER_DIV_CD`(#3) | `GFT_DIV_CD`(#9) | `EVENT_PARTCPT_DIV_CD`(#4) | NULL | 참여구분 |
| `PARTICIPATION_STAT_CD` | VARCHAR | `LETTER_STAT_CD`(#14) | NULL | `PARTCPT_STAT_CD`(#8) | `PARTCPT_STAT_CD`(#6) | 참여상태 |
| `GIFT_AMT` | NUMBER | NULL | `GFTMNEY`(#8) | NULL | NULL | 선물금(원단위) |
| `GIFT_DOLLAR_AMT` | NUMBER | NULL | `GFTMNEY_DOLLAR_AMT`(#14) | NULL | NULL | 선물금 달러 |
| `RECEIPT_AMT` | NUMBER | NULL | NULL | NULL | `RCPMNY_AMT`(#13) | 수납금액(캠페인) |
| `SOURCE_REF_CD` | VARCHAR | NULL | NULL | `EVENT_CD`(#1) | `CRMN_CD`(#1) | 이벤트/캠페인 코드 |

### 3-1. 표준 감사/메타 컬럼 (원칙 10)
`_SOURCE_SYSTEM`='CRM' · `_SOURCE_TABLE`(4원천 행별) · `_LOADED_AT` · `_BATCH_ID`

> **PII/제외**: GIFT `SETLE_NO_ENC`(#7 결제번호암호화)·결제정보(`SETLE_CD`·`SETLE_BANK_CD`) **SILVER 미적재**. 본문(`CTNT`·`KOREAN_RM_CTNT`·`RM`)은 비분석 제외. 이관(`TRNSFER_*`)은 보존 선택.

---

## 4. GOLD 정합 (`FSE`, +5일차 참여 attribution)

| FSE measure | # | 본 엔티티 PARTICIPATION_TYPE |
|---|---|---|
| 서신참여(명/건) | 139/140 | LETTER (COUNT / GIFT_AMT 아님) |
| 선물금참여(명/건) | 141/142 | GIFT (`GIFT_AMT` SUM/10000 = 건) |
| (이벤트/캠페인 참여) | — | EVENT/CAMPAIGN — 60 measure 직접 매핑 확인(OPEN-49) |

- **attribution(원칙)**: FSE는 참여를 발송행(발송일×회원, +5일차)에 귀속. 본 엔티티 참여를 발송(⑩⑪)과 매칭하는 키·기간 규칙 = **GOLD 적재 트랙 + OPEN-49**(서신/선물금 SNDNG_KEY 부재).
- **증액/중단 참여(#143~146)**: 본 엔티티 아님 — 증액은 ③(DVLP), 중단은 ②(STATUS)/③. FSE attribution 시 결합.
- **회원**: MEMBER_DK only(원칙 B). LETTER/GIFT는 ⑮ 경유 해소.

---

## 5. OPEN 이슈

| ID | 이슈 | 영향 | 조치 |
|---|---|---|---|
| **OPEN-48** | LETTER/GIFT 회원 링크 = `RELATNSP_KEY`→⑮ 간접 | MEMBER_KEY 해소·고아 | ⑮ 적재 후 조인 검증 |
| **OPEN-49** | 참여→발송 attribution — 서신/선물금 `SNDNG_KEY` 부재(SNDNG_DE만) + 이벤트/캠페인 참여의 60 measure 매핑 | FSE +5일차 귀속·measure 정합 | 매칭 규칙(회원+기간) 현업. GOLD 트랙 |
| **OPEN-50** | 4종 PK 유일성(특히 LETTER/GIFT 동일 RELATNSP+MNG 다건) | PK·중복 | BRONZE 실측 |
| ~~OPEN-37~~ | ~~4원천 LLM생성~~ | — | **✅ 해소(2026-06-22 정의서, 설계 컬럼과 일치)** |
| **OPEN-5(공통)** | 물리타입 미제공 | 캐스팅 잠정 | S-2 전 확인 |
| **OPEN-3(공통)** | 참여구분/상태 라벨 | 라벨 | `CRM_CODE_MASTER`(#14) 후 |

---

## 6. 다음

- **부분 설계 가능** — 4종 UNION 구조·컬럼 확정(R11 해소). 회원링크(OPEN-48, ⑮ 의존)·attribution(OPEN-49) 선결.
- **선결**: ⑮(결연) 적재 → LETTER/GIFT 회원 해소. OPEN-49(발송 attribution) 현업.
- **S-2**: 4종 UNION DDL(PARTICIPATION_TYPE 판별자). **S-3**: 원천별 표준컬럼 매핑(PII 제외 표기).
