# S-1 엔티티 설계서 ⑫ `CRM_SEND_RESULT`

> SILVER 정제 레이어 `GN_DW.SILVER.CRM_SEND_RESULT` 설계서.
> 입력: `BRONZE_CRM 테이블 정보.MD` / 상위: `SILVER_설계_작업 계획.md` §1-1(#12), §0 원칙 3·4·5·10, **★R2**.
> GOLD 수요처: `FSE`(발송 성과 보조) + SV(발송 성공률·클릭·URL공개율 등 채널 KPI).
> 원천(발송×채널 성과집계 grain): `TD_MS_EMAIL_LQY_SNDNG`(26) · `TD_MS_MSG_AT_LQY_SNDNG`(20) · `TD_MS_PSTMTR_LQY_SNDNG`(11) — **전 컬럼 정의됨 ✅ (R11 해소, 2026-06-22 정의서)**.

---

## 1. 핵심 — 채널 성과 "집계" 소스 (원칙4 grain 쟁점) + R2

본 엔티티의 원천 `*_LQY_SNDNG`은 **이미 집계된 채널 성과**(발신건수·성공·실패·클릭·URL공개) — 회원 grain이 아닌 **1행/(발송 × 채널)** 요약이다. 두 가지 유의:

1. **원칙4 grain 쟁점**: SILVER는 원칙상 raw grain 보존이나, **원천 자체가 발송단위 집계**다(회원별 원자 행은 ⑪에 있음). FSE의 회원 grain measure(발송수(명) #85)는 **⑪에서** 채우고, 본 엔티티는 **발송단위 채널 KPI**(성공률·클릭·URL공개)를 별도 제공 → ⑪과 grain 분리(중복 집계 금지).
2. **★R2(OPEN-36 상속)**: `SNDNG_KEY` 기반(TM_MS_ 계열). SND_ 계열 성과 대응표 없음 → ⑩⑪과 동일 키 차단.

> ⚠️ `*_CTNT`(내용) 접미 컬럼 다수(`URL_OTHBC_CNT_CTNT`·`SESION_VU_CTNT`·`DVLP_ACMSLT_CNT_CTNT` 등)는 텍스트 덤프성 → 수치화 가능 여부 불확실(OPEN-43). `CLOS_YN`(email#20)은 5행만 존재(저신뢰).

---

## 2. grain / PK

- **grain**: 1행 / 발송(`SNDNG_KEY`) × 채널 [× 차수/분할]. 채널 성과 요약.
- **PK**: `SEND_RESULT_KEY` = `CHANNEL || '-' || SNDNG_KEY [|| '-' || DIVS_DTL_KEY | SNDNG_SQNC]`.
  - email: `SNDNG_KEY`(+`MSG_ID`) / msg_at: `SNDNG_KEY`+`DIVS_DTL_KEY`(분할상세) / pstmtr: `SNDNG_KEY`+`SNDNG_SQNC`(발신차수). 분할/차수 grain 확정 OPEN-44.
- **발송요청 FK**: `SEND_REQUEST_KEY` ← `SNDNG_KEY` → ⑩(R2 의존).

---

## 3. 컬럼 명세 (채널 UNION 표준 — 성과 measure)

> ⚠️ 타입 캐스팅 잠정(OPEN-5). 금액·건수 NUMBER 원단위(원칙11). `*_CTNT` 텍스트는 수치 추출 후 적재(OPEN-43).

| SILVER 컬럼 | 타입 | EMAIL_LQY(24) | MSG_AT_LQY(18) | PSTMTR_LQY(9) | 의미 |
|---|---|---|---|---|---|
| `SEND_RESULT_KEY` (PK) | VARCHAR | 파생 | 파생 | 파생 | `CHANNEL-SNDNG_KEY-…` |
| `CHANNEL` | VARCHAR | 'EMAIL' | 'MSG_AT' | 'PSTMTR' | 판별자 |
| `SEND_REQUEST_KEY` (FK) | VARCHAR | `SNDNG_KEY` | `SNDNG_KEY` | `SNDNG_KEY` | → ⑩ |
| `SEND_CNT` | NUMBER | `SNDNG_CNT`(#4) | `SNDNG_CNT`(#3) | `SNDNG_CNT`(#2) | 발신건수 |
| `SUCCESS_CNT` | NUMBER | `SUCCES_CNT`(#5) | `SUCCES_CNT`(#4) | NULL | 성공건수 |
| `FAIL_CNT` | NUMBER | `FAILR_CNT`(#6) | `AT_FAILR_CNT`(#6) | NULL | 실패건수 |
| `RECEIVE_CNT` | NUMBER | `RECPTN_CNT`(#7) | NULL | NULL | 수신건수(email) |
| `ALT_SEND_CNT` | NUMBER | NULL | `AT_ALTRTV_SNDNG_CNT`(#5) | NULL | 알림톡 대체발송 |
| `TOTAL_CLICK_CNT` | NUMBER | NULL | `TOT_CLICK_CNT_CTNT`(#9) | NULL | 총클릭(텍스트→수치 OPEN-43) |
| `SEND_START_DT` | TIMESTAMP_NTZ | `SNDNG_STRT_DT`(#8) | NULL | NULL | 발신시작 |
| `SEND_END_DT` | TIMESTAMP_NTZ | `SNDNG_END_DT`(#9) | NULL | NULL | 발신종료 |
| `SEND_SQNC` | NUMBER | NULL | NULL | `SNDNG_SQNC`(#3) | 발신차수(우편) |

> **보존 선택/제외**: email의 `URL_OTHBC_*`·`SESION_*`·`DVLP_ACMSLT_CNT_CTNT`(#15~19), msg_at `CLICK_CNT_CTNT1~4`(#10~13)는 텍스트 KPI → 수치 파싱 가능 시 SV용 보존(OPEN-43). 제목/메모(`SNDNG_TIT`·`SNDNG_MEMO_CTNT`)는 비분석.

### 3-1. 표준 감사/메타 컬럼 (원칙 10)
`_SOURCE_SYSTEM`='CRM' · `_SOURCE_TABLE`(채널별 *_LQY_SNDNG) · `_LOADED_AT` · `_BATCH_ID`

---

## 4. GOLD 정합

- **FSE 발송수(명) #85는 본 엔티티 아님** — 회원 grain은 ⑪. 본 엔티티는 **발송단위 채널 KPI**(성공률=SUCCESS_CNT/SEND_CNT, 클릭, URL공개율) 제공 → 주로 **SV metric**(60 measure 인벤토리 외) 또는 FSE 발송상태 보조.
- **중복 집계 금지(원칙3/4)**: ⑪(회원 COUNT)과 ⑫(발송단위 집계)를 GOLD에서 **혼합 SUM 금지** — grain 분리 유지. FSE는 ⑪ 기준, ⑫는 채널 KPI 별도 노출.
- **R2 의존**: `SNDNG_KEY` → ⑩ 조인. SND_ 계열 성과 부재.

---

## 5. OPEN 이슈

| ID | 이슈 | 영향 | 조치 |
|---|---|---|---|
| **★R2/OPEN-36(상속)** | `SNDNG_KEY`(TM_MS_) 단독 — SND_ 성과 대응 없음 | ⑩ 조인·통합 | ⑩ OPEN-36 |
| **OPEN-43** | `*_CTNT` 텍스트 KPI(클릭·URL공개·세션·개발실적) 수치 추출 가능 여부 | SV metric 가용성 | BRONZE 실데이터 형식 확인(숫자/텍스트) |
| **OPEN-44** | 채널별 PK grain — email(MSG_ID)/msg_at(분할 DIVS_DTL_KEY)/pstmtr(차수 SNDNG_SQNC) | PK·집계 단위 | BRONZE 실측 |
| **OPEN-45** | ⑪(회원 grain) ↔ ⑫(발송 집계) 합산 경계 — FSE 중복 방지 | measure 정합 | GOLD 적재 시 grain 분리 규칙 명시 |
| **OPEN-5(공통)** | 물리타입 미제공 | 캐스팅 잠정 | S-2 전 확인 |

---

## 6. 다음

- **R2 해소 전 TM_MS LQY 3채널만 UNION 가능**. 채널 KPI는 ⑪과 grain 분리 유지(원칙4).
- **S-2**: 3채널 LQY UNION DDL(CHANNEL 판별자). `*_CTNT` 수치 파싱은 OPEN-43 후.
- **S-3**: 채널별 → 성과 표준컬럼 매핑. ⑪⑫ grain 경계(OPEN-45) GOLD 트랙 전달.
