# S-1 엔티티 설계서 ⑪ `CRM_SEND_MEMBER`

> SILVER 정제 레이어 `GN_DW.SILVER.CRM_SEND_MEMBER` 설계서.
> 입력: `BRONZE_CRM 테이블 정보.MD` + **`컬럼정의서 20260622.csv`(권위 원천)** / 상위: `SILVER_설계_작업 계획.md` §1-1(#11), §0 원칙 4·5·10·11, **★R2**.
> GOLD 수요처: `FSE`(발송수(명) #85 — 발송일×회원×서비스×캠페인 grain의 회원 행).
> 원천(발송×회원 상세 grain): `TD_MS_EMAIL_SNDNG_DTLS`(12) · `TD_MS_MSG_AT_SNDNG_DTLS`(15) · `TD_MS_PSTMTR_SNDNG_DTL`(14) · `SND_MEMBER_LIST`(76, R2 후) — **전 컬럼 정의됨 ✅ (R11 해소)**.

---

## 1. 핵심 — 채널 UNION + R2 + (PII 우려 축소)

본 엔티티는 **1행/발송건×회원×채널** — FSE "발송수(명)" 소스. 채널 3종(이메일/알림톡/우편) TD_MS 상세를 **UNION ALL**(CHANNEL 판별자), `SND_MEMBER_LIST`(SND_ 계열)는 R2 후 합류.

- **R11 해소**: 정의서로 컬럼 확정. `TD_MS_MSG_AT_SNDNG_DTLS` 컬럼-설명 불일치(이전 인벤토리)도 정의서로 해소.
- **★R2(OPEN-36 상속)**: TD_MS_*(`SNDNG_KEY`) ↔ `SND_MEMBER_LIST`(`REQ_SEQ_NO`/`MSG_KEY`) 회원 행이 미러/disjoint인지 → ⑩과 동일. 확정 전 SND_MEMBER_LIST 보류.
- **✅ PII 우려 축소**: 정의서 확인 결과 **TD_MS 상세 3종에는 연락처 raw(이메일·휴대폰·성명·주소) 없음** — `MBER_NO` + 발송결과만. PII는 `SND_MEMBER_LIST`(아동사진 `NEW_CHILD_PIC`·성별·나이 등 denormalized)에 집중(OPEN-40).

---

## 2. grain / PK

- **grain**: 1행 / 발송건 × 회원 × 채널.
- **PK**: `SEND_MEMBER_KEY` = `CHANNEL || '-' || SNDNG_KEY || '-' || SNDNG_DTL_KEY || '-' || MBER_NO`.
  - `CHANNEL`: 'EMAIL'/'MSG_AT'/'PSTMTR'(+ 'SND' R2 후). 유일성 OPEN-41.
- **발송요청 FK**: `SEND_REQUEST_KEY` ← `SNDNG_KEY` → ⑩(R2 의존).
- **회원 FK**: `MEMBER_KEY` ← `MBER_NO`. 접두(FDRM/ONCE) OPEN-42.
- **결연 링크**(우편): `RELATNSP_KEY`(PSTMTR) → ⑮.

---

## 3. 컬럼 명세 (TD_MS 3채널 UNION)

> 정의서 확정. 타입 일부 미기재(OPEN-5).

| SILVER 컬럼 | EMAIL_DTLS(12) | MSG_AT_DTLS(15) | PSTMTR_DTL(14) | 정제 |
|---|---|---|---|---|
| `SEND_MEMBER_KEY` (PK) | 파생 | 파생 | 파생 | `CHANNEL-SNDNG_KEY-SNDNG_DTL_KEY-MBER_NO` |
| `CHANNEL` | 'EMAIL' | 'MSG_AT' | 'PSTMTR' | 판별자 |
| `SEND_REQUEST_KEY` (FK) | `SNDNG_KEY` | `SNDNG_KEY` | `SNDNG_KEY` | → ⑩ |
| `SEND_DTL_KEY` | `SNDNG_DTL_KEY` | `SNDNG_DTL_KEY` | `SNDNG_DTL_KEY` | 발신상세키 |
| `MEMBER_KEY` (FK) | `MBER_NO` | `MBER_NO` | `MBER_NO` | 접두 OPEN-42 |
| `SEND_DT` | `SNDNG_DE` | `SNDNG_DT` | `SNDNG_DE` | 발신일시 |
| `SEND_RESULT_CD` | `SNDNG_RST_CD` | `TRNSMS_STAT_CD`(MS282) | NULL | 0실패/1성공/4계정없음/5도메인오류(email) |
| `SEND_FAIL_CD` | NULL | `TRNSMS_FAILR_CD_ID` | NULL | 전송실패코드 |
| `ALT_MSG_YN` | NULL | `ALTRTV_MSG_SNDNG_YN` | NULL | 대체문자 발송여부 |
| `SEND_NO` | NULL | `SNDNG_NO` | NULL | 발신번호 |
| `RELATNSP_KEY` | NULL | NULL | `RELATNSP_KEY` | 결연키(우편) → ⑮ |

### 3-1. 표준 감사/메타 컬럼 (원칙 10)
`_SOURCE_SYSTEM`='CRM' · `_SOURCE_TABLE`(채널별 TD_MS_*) · `_LOADED_AT` · `_BATCH_ID`

> **첨부(`ATCHFL_ID`/`ATTACHED_FILE`)·우편 내부키(`DTL_KEY`/`BIZN_REQUST_KEY`)는 보존 선택**. TD_MS 상세는 연락처 PII 없음(§1).

---

## 4. GOLD 정합 (`FSE`)

- **발송수(명) #85** ← `COUNT`(회원 행, 중복 포함). FSE grain의 회원 축 제공.
- **서비스/캠페인 속성**: ⑩을 `SEND_REQUEST_KEY`로 조인 → DIM_SERVICE·DIM_CAMPAIGN(R2 의존).
- **발송 성공/실패**: `SEND_RESULT_CD` → FSE 발송상태(#138). 채널 집계 성과는 ⑫.
- **회원**: MEMBER_DK only(원칙 B).

---

## 5. OPEN 이슈

| ID | 이슈 | 영향 | 조치 |
|---|---|---|---|
| ~~OPEN-37~~ | ~~SND_MEMBER_LIST·MSG_AT_DTLS 컬럼 미검증~~ | — | **✅ 해소(2026-06-22 정의서)** |
| **★R2/OPEN-36(상속)** | TD_MS_*(SNDNG_KEY) ↔ SND_MEMBER_LIST(REQ_SEQ_NO/MSG_KEY) | UNION 정합·FSE 발송수 중복 | ⑩ OPEN-36(`MSG_KEY`↔`SNDNG_KEY` 실측) |
| **OPEN-40 (PII)** | `SND_MEMBER_LIST`의 아동사진(`NEW_CHILD_PIC`)·성별·나이·아동명 등 denormalized PII (TD_MS 상세는 없음) | 거버넌스 | SND_MEMBER_LIST 합류(R2 후) 시 PII 컬럼 미적재. `data-governance` 연계 |
| **OPEN-41** | 채널별 PK(SNDNG_KEY+DTL_KEY+MBER_NO) 유일성 | PK·dedup | BRONZE 실측 |
| **OPEN-42** | 발송 대상 회원범위(FDRM/ONCE) → MEMBER_KEY 접두 | FK 정합·고아키 | BRONZE 실측 |
| **OPEN-5(공통)** | 일부 타입 미기재 | 캐스팅 | S-2 전 확인 |
| **OPEN-3(공통)** | 전송상태 라벨(MS282) | 라벨 | ⑭ 후 |

---

## 6. 다음

- **TD_MS 3채널 즉시 UNION 가능**(R11 해소, PII 없음) — `SND_MEMBER_LIST`만 R2 후 합류.
- **S-2**: TD_MS 3채널 UNION DDL(CHANNEL 판별자).
- **S-3**: 채널별 → SILVER 표준컬럼 매핑.
