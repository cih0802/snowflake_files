# GOLD 차원 설계 (2단계 산출물) — v2 (검토 반영·원천방어)

> `GOLD_지표 분류.md`의 dimension 74개를 conformed dimension으로 통합·설계.
> 각 DIM: **grain · 대리키(SK) · durable/비즈니스키 · 컬럼 · SCD · 소스(#)**.
> 명명규칙: 대리키 `*_SK`(NUMBER IDENTITY, 버전 단위), durable key `*_DK`(버전 불변), 비즈니스키 `*_BK`(소스 원본키).
> SCD: **1**=덮어쓰기, **2**=이력보존, **정적**=불변.

## 0. 원천방어 설계 원칙 (검토 A~J 반영, 어느 쪽 답이든 안전)
1. **시변·단조증가 속성은 차원에 두지 않는다.** (A) 후원기간(개월/년)·납입개월수·후원금액대·후원기간대는 매월 변동 → **FMM(회원·월 팩트)** 에서 스냅샷/계산. DIM_MEMBER엔 느리게 변하는 범주형만.
2. **durable key와 SCD2 surrogate를 분리한다.** (B) DIM_MEMBER는 `MEMBER_SK`(버전별 PK) + `MEMBER_DK`(불변). **신원 매핑·팩트의 회원 식별은 `MEMBER_DK`** 로, 시점 속성 조회만 `MEMBER_SK`로. surrogate에 매핑 걸지 않음.
3. **캠페인과 후원사업은 별개 차원으로 분리한다.** (C) 둘의 관계가 1:1인지 1:N인지 불확실 → **DIM_CAMPAIGN / DIM_SPONSORSHIP 분리**, 팩트가 두 SK를 각각 보유. 답이 1:1이면 단순조인, N:M이면 그대로 정상 → 원천방어.
4. **이벤트 사유는 회원 차원이 아니라 DIM_REASON.** (D·E) 미납사유·중단사유, 개발구분은 회원 단일속성이 아니라 건/이벤트 단위 → DIM_REASON + FMM degenerate.
5. **소스 이질 차원은 분리한다.** (F) AGENCY 광고 메타 ↔ GA 세션 소스를 한 테이블에 섞지 않음 → **DIM_AD_CREATIVE / DIM_GA_SOURCE 분리**(sparse junk 방지).
6. **조직 귀속은 경로를 명시한다.** (G) 실적(FMM)의 조직은 **캠페인 경유**(FMM→DIM_CAMPAIGN→ORG), 목표(FTG)만 **ORG 직접 참조**. 회원→ORG 직접 FK 금지.
7. **혼합 차원은 subtype 컬럼으로 방어한다.** (H) DIM_SERVICE는 발송/참여를 `SERVICE_TYPE`로 구분, 발송 전용 컬럼은 참여행에서 NULL 허용.

총 DIM: **12개** — DATE · MEMBER · MEMBER_IDENTITY · CAMPAIGN · SPONSORSHIP · ORG · AD_CREATIVE · GA_SOURCE · SERVICE · PAYMENT · GA_EVENT · REASON

---

## 1. DIM_DATE
- **grain**: 1행 = 1일. 모든 팩트 시간축 공통.
- **SK**: `DATE_SK`(NUMBER, YYYYMMDD) / **SCD**: 정적

| 컬럼 | 타입 | 설명 | 소스# |
|---|---|---|---|
| DATE_SK | NUMBER(8) | YYYYMMDD | — |
| FULL_DATE | DATE | 일자 | — |
| YEAR / QUARTER / MONTH | NUMBER | 연/분기/월 | — |
| YEAR_MONTH | NUMBER(6) | 조회년월 YYYYMM | 공통 |
| WEEK_OF_YEAR | NUMBER(2) | 주차(#58) | — |
| DAY / DAY_OF_WEEK | NUMBER/VARCHAR | 일/요일 | — |
| IS_MONTH_END / IS_YEAR_END | BOOLEAN | 월말/연말(#52·50) | — |

---

## 2. DIM_MEMBER (SCD2, 느린 범주형만)
- **grain**: 1행 = 1회원의 상태 버전.
- **SK**: `MEMBER_SK`(버전 PK) / **DK**: `MEMBER_DK`(불변, 회원번호 기반 해시) / **BK**: 회원번호(#110)
- **SCD**: 2

| 컬럼 | 타입 | 설명 | 소스# | SCD |
|---|---|---|---|---|
| MEMBER_SK | NUMBER | 버전 대리키 | — | — |
| MEMBER_DK | NUMBER | 불변 durable key | — | — |
| MEMBER_BK | VARCHAR | 회원번호 | #110 | — |
| 성별 | VARCHAR | | #130 | 1 |
| 지역 | VARCHAR | | #131 | 2 |
| 회원상태 | VARCHAR | 활동/중단/미납 | #132 | 2 |
| 신규기존구분 | VARCHAR | | #113 | 2 |
| 최초가입일 | DATE | 회원번호 생성일 | #28 | 1 |
| 최초캠페인_SK | NUMBER | → DIM_CAMPAIGN FK (정규화) | #29 | 1 |
| 최종중단일 | DATE | | #30 | 2 |
| 최종캠페인_SK | NUMBER | → DIM_CAMPAIGN FK | #31 | 2 |
| EFF_FROM / EFF_TO / IS_CURRENT | DATE/BOOLEAN | SCD2 유효기간 | — | — |

> **이관(A)**: 후원기간_개월/년(#127·128)·납입개월수(#129)·후원금액대1·2(#72·73)·후원기간대1·2(#74·75) → **FMM에서 월 스냅샷**. DIM_MEMBER에서 제외.
> **제외(E)**: 개발구분(#121·32~34) → 회원속성 아님 → FMM degenerate.
> 회원분류 상태값(#39~44·48·51)은 `회원상태` 또는 팩트 세그먼트로 표현, 중복 컬럼 없음.

---

## 3. DIM_MEMBER_IDENTITY (매핑 브리지) ⚠️핵심
- **grain**: 1행 = (MEMBER_DK × ga_member_id) 1쌍. **회원당 GA id 다수 허용**(기기·브라우저).
- **SK**: `IDENTITY_SK` / 키: `MEMBER_DK`(불변) ↔ ga_member_id
- **SCD**: 1

| 컬럼 | 타입 | 설명 | 소스# |
|---|---|---|---|
| IDENTITY_SK | NUMBER | 대리키 | — |
| MEMBER_DK | NUMBER | DIM_MEMBER durable key(불변) | #110 기반 |
| 회원번호 | VARCHAR | CRM 키 | #110 |
| memnum | VARCHAR | 링크 키 | #111 |
| ga_member_id | VARCHAR | GA4 member id | #112 |
| 결연아동코드 | VARCHAR | URL 파싱값 | #122 |
| 아동번호 | VARCHAR | 결연 아동번호(CRM, 발송 서비스) | 회원§3-1(2026-06-24) |
| MATCH_METHOD | VARCHAR | 직접/추정 | — |
| MATCH_CONFIDENCE | VARCHAR | 신뢰도 | — |

> **방어(B)**: SCD2 surrogate(MEMBER_SK) 아닌 **불변 MEMBER_DK** 에 매핑. 회원 버전이 늘어도 매핑 안정.
> **방어(grain)**: 회원:GA = 1:N 가능하므로 쌍 단위 행. FGA는 ga_member_id로 join → MEMBER_DK 해소.
> #81·신규#32·33 산출이 이 브리지에 의존.

---

## 4. DIM_CAMPAIGN
- **grain**: 1행 = 1캠페인.
- **SK**: `CAMPAIGN_SK` / **BK**: 캠페인(#120) / **SCD**: 1
- **ORG 경로(G)**: 캠페인을 운영한 조직을 `ORG_SK`로 보유 → 실적 조직귀속은 이 경로로.

| 컬럼 | 타입 | 설명 | 소스# |
|---|---|---|---|
| CAMPAIGN_SK | NUMBER | 대리키 | — |
| CAMPAIGN_BK | VARCHAR | 캠페인 코드 | #120 |
| 캠페인명 | VARCHAR | | #18 |
| 캠페인유형 | VARCHAR | | #17 |
| 국내해외구분 | VARCHAR | | #15 |
| 사업사례구분 | VARCHAR | | #16 |
| 캠페인오픈일자 | DATE | | #19 |
| 공통캠페인 | VARCHAR | | #147 |
| 공통상위캠페인 | VARCHAR | | #119 |
| 공통브랜드 | VARCHAR | | #117 |
| 홍보방법 | VARCHAR | | #118 |
| ORG_SK | NUMBER | 운영 조직 → DIM_ORG FK (G) | #114~116 |

> 계층(잠정): 공통브랜드 > 공통상위캠페인 > 공통캠페인 > 캠페인. ⚠️ 정확 순서 현업 확인(단, 분리설계라 순서 오답이어도 컬럼 손상 없음).
> #102 세션캠페인(GA)은 이 DIM에 매핑(정합 스테이징 필요).

---

## 5. DIM_SPONSORSHIP (후원사업) — 캠페인과 분리 (C)
- **grain**: 1행 = 1후원사업.
- **SK**: `SPONSORSHIP_SK` / **BK**: 후원사업(#123) / **SCD**: 1

| 컬럼 | 타입 | 설명 | 소스# |
|---|---|---|---|
| SPONSORSHIP_SK | NUMBER | 대리키 | — |
| SPONSORSHIP_BK | VARCHAR | 후원사업 코드 | #123 |
| 후원사업명 | VARCHAR | | #123 |
| 후원사업_약칭 | VARCHAR | | #124 |

> **방어(C)**: 캠페인:후원사업 관계 불확실 → 별도 차원. 팩트(FMM·FSE·**FTG-B**)가 `CAMPAIGN_SK`·`SPONSORSHIP_SK`를 보유(FMM·FSE는 둘 다, FTG-B는 ORG+SPONSORSHIP[+CAMPAIGN]). **FTG-D(CRM 회원개발목표)는 후원사업 grain이 아니므로 SPONSORSHIP_SK 미보유**(개발구분 degenerate). 1:1이면 조인 단순, N:M이면 그대로 정상.

---

## 6. DIM_ORG
- **grain**: 1행 = 1 조직노드(소스 DEPT_ID). 소스 `TM_CM_DEPT_INFO` **전 노드 적재** → 어느 레벨 DEPT_ID든 조인 해소. 목표(FTG) 직접 참조 + 캠페인 경유 실적.
- **SK**: `ORG_SK` / **BK**: `ORG_BK`=부서코드 DEPT_ID(#116, 조인 해소키) / **SCD**: 2

| 컬럼 | 타입 | 설명 | 소스# |
|---|---|---|---|
| ORG_SK | NUMBER | 대리키 | — |
| ORG_BK | VARCHAR | 부서 업무키=DEPT_ID (FTG·캠페인 ORG_SK 조인키) | #116 |
| ORG_LEVEL | VARCHAR | 통계부서레벨(STATS_DEPT_LVL) — 노드 계층레벨 식별 | ⚠확인 |
| 법인 | VARCHAR | | #114 |
| 본부_지부 | VARCHAR | | #115 |
| 부서 | VARCHAR | | #116 |
| 팀 | VARCHAR | 최하위(문서 미열거) | ⚠️확인 |

> 계층: 법인 > 본부/지부 > 부서 > 팀. 팀 미존재 시 NULL 허용(원천방어).
> **F2(⚠️확인필요·보수적 방어, 결정 보류)**: 목표 `DEPT_ID`가 최하위 부서가 아닌 본부/지부 레벨일 수 있음(소스 `STATS_DEPT_LVL`·`UPPER_DEPT_ID` 자기참조 계층). **레벨 정책은 미확정** — DIM_ORG에 전 노드 적재 + `ORG_BK`(DEPT_ID) 조인으로 레벨 무관하게 방어하고, `ORG_LEVEL`에 레벨만 기록. 최하위 전용 여부·계층 롤업 규칙은 SILVER 매핑 시 실데이터로 확정(그 전까지 grain 모델 commit 회피). 상위 노드는 하위 비정규화 컬럼(부서 등)이 NULL일 수 있음(ragged).
> 소스: CRM `TM_CM_DEPT_INFO`(DEPT_ID/DEPT_NM/UPPER_DEPT_ID/STATS_DEPT_LVL/ACMSLT_DEPT_YN).

---

## 7. DIM_AD_CREATIVE (AGENCY 광고) — 매체차원 분리 (F)
- **grain**: 1행 = 1광고 소재/매체 단위. FAD 참조.
- **SK**: `AD_CREATIVE_SK` / **SCD**: 1

| 컬럼 | 타입 | 설명 | 소스# |
|---|---|---|---|
| AD_CREATIVE_SK | NUMBER | 대리키 | — |
| 매체명 | VARCHAR | 공동브랜드 | #11 |
| 플랫폼 / 플랫폼유형 | VARCHAR | | #12·13 |
| 기기 | VARCHAR | | #14 |
| 소재 | VARCHAR | | #20 |
| CM위치 | VARCHAR | | #21 |
| 초수 | NUMBER(6,0) | 광고 길이(초) | #22 |
| 타겟그룹 | VARCHAR | 잠재고객 이름(Google Ads audience 개념, 원천표기 GA) | 마케팅§3(2026-06-24) |

> **🆕 2026-06-24 정의서 반영** — 정본 `GOLD_정의서_업데이트 20260624.md`.
> - **타겟그룹(M5)**: 마케팅§3 `잠재고객 이름(=타겟그룹)` → 위 컬럼 신설. **원천표기는 GA(GA4)** (Google Ads audience 개념이나 인벤토리 source-of-record는 GA).
> - **광고 시간속성(M4)**: `요일·주차·시간대·광고시작시간·RT유형`은 소재 단위가 아닌 **일자×송출 단위** → DIM_AD_CREATIVE가 아니라 **FAD degenerate / DIM_DATE**에 귀속(팩트설계 §5 델타). **송출일≠실적일** 분리 검토.
> - **법인명 다중원천(M5)**: `법인`(#114, DIM_ORG)이 AGENCY 일별레포트에도 존재 → 동일 개념 다중원천, DIM_ORG 정본 유지·`_SOURCE_SYSTEM`으로 출처 보존.

---

## 8. DIM_GA_SOURCE (GA 세션 소스) — 매체차원 분리 (F)
- **grain**: 1행 = 1 GA 트래픽 소스 조합. FGA 참조.
- **SK**: `GA_SOURCE_SK` / **SCD**: 1

| 컬럼 | 타입 | 설명 | 소스# |
|---|---|---|---|
| GA_SOURCE_SK | NUMBER | 대리키 | — |
| 세션_소스매체 | VARCHAR | utm source/medium | #109 |
| 세션_수동광고콘텐츠 | VARCHAR | utm_content | #103 |
| 세션_수동검색어 | VARCHAR | utm_term | #104 |

> **방어(F)**: AGENCY/GA 매체를 분리해 sparse NULL·정합 충돌 제거. 통합 분석 필요 시 매핑 테이블 별도(1단계 D#6).

---

## 9. DIM_SERVICE (구 DIM_SEND_TYPE 통합, subtype 방어)
- **grain**: 1행 = 1서비스. 발송구분 대/중/소 계층.
- **SK**: `SERVICE_SK` / **BK**: 발송구분(소)+서비스명 / **SCD**: 1

| 컬럼 | 타입 | 설명 | 소스# |
|---|---|---|---|
| SERVICE_SK | NUMBER | 대리키 | — |
| SERVICE_TYPE | VARCHAR | 발송서비스/참여서비스 (H) | ⚠️원천확인 |
| 발송구분_대/중/소 | VARCHAR | 발송 전용, 참여행 NULL | #133·134·135 |
| 서비스명 | VARCHAR | 이메일/알림톡/문자/이벤트 | ⚠️원천확인 |
| PARTICIPATION_DEF | VARCHAR | 참여 정의(서비스별 상이) | 신규#36 비고 |

> **방어(H)**: `SERVICE_TYPE`로 발송/참여 구분, 발송 전용 컬럼 NULL 허용. 참여 정의 차이는 `PARTICIPATION_DEF` 메타로 흡수.
> 제목(#136)·발송상태(#138)는 DIM 아님 → FSE degenerate.

---

## 10. DIM_PAYMENT
- **grain**: 1행 = 납입방식 × 회비유형. / **SK**: `PAYMENT_SK` / **SCD**: 1

| 컬럼 | 타입 | 설명 | 소스# |
|---|---|---|---|
| PAYMENT_SK | NUMBER | 대리키 | — |
| 납입방식 | VARCHAR | CMS/카드/지로 등 | #125 |
| 회비유형 | VARCHAR | 정기/일시 | ⚠️#66~68 역추론, 원천확인(J) |

> #126 캠페인별 납입방식 구분 미지정 → 캠페인×납입방식 적용 가능 여부 현업 확인.
> ⚠️ **정합성(팩트설계 결정8)**: FMM은 DIM_PAYMENT를 **납입방식 grain으로만** 참조(회비유형 차원값 미사용). 회비유형(정기/일시) 축이 여기(차원 컬럼)와 #66~68(measure 컬럼)에 **이중 표현** → 5단계에서 단일 표현으로 확정. 그때까지 DIM_PAYMENT.회비유형은 "보류 컬럼"으로 둠(FMM FK 해소는 납입방식만으로).

---

## 11. DIM_GA_EVENT
- **grain**: 1행 = GA 이벤트 분류 조합. / **SK**: `GA_EVENT_SK` / **SCD**: 1

| 컬럼 | 타입 | 설명 | 소스# |
|---|---|---|---|
| GA_EVENT_SK | NUMBER | 대리키 | — |
| EVENT_CATEGORY / LABEL / ACTION | VARCHAR | | #99·100·101 |

---

## 12. DIM_REASON (사유 차원) — 신설 (D)
- **grain**: 1행 = 1사유코드(유형별). FMM가 중단/미납 이벤트에서 참조.
- **SK**: `REASON_SK` / **SCD**: 1

| 컬럼 | 타입 | 설명 | 소스# |
|---|---|---|---|
| REASON_SK | NUMBER | 대리키 | — |
| REASON_TYPE | VARCHAR | 중단/미납 | — |
| REASON_CODE | VARCHAR | 사유코드 | #82·162 |
| REASON_DESC | VARCHAR | 사유설명 | #82·162 |

> **복구(D)**: 1단계의 미납사유(#82)·중단사유(#162)가 stage2 누락됐던 것을 차원으로 복구. 회원속성 아닌 이벤트 사유.

---

## 13. 팩트별 DIM 참조 매트릭스 (3단계 입력)

| FACT | DATE | MEMBER(DK) | IDENTITY | CAMPAIGN | SPONSOR | ORG | AD_CRT | GA_SRC | SERVICE | PAYMENT | GA_EVT | REASON |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| FMM (회원·월) | ✓ | ✓ | | ✓ | ✓ | (via CAMPAIGN) | | | | ✓ | | ✓ |
| FTG-D (CRM 회원개발목표) | ✓(MONTH_KEY) | | | | | ✓(직접) | | | | | | |
| FTG-B (ERP 사업목표) | ✓(MONTH_KEY) | | | △(선택) | ✓ | ✓(직접) | | | | | | |
| FSE (서비스이벤트) | ✓ | ✓ | | ✓ | ✓ | (via CAMPAIGN) | | | ✓ | | | |
| FGA (GA행동) | ✓ | via IDENTITY | ✓ | ✓ | | | | ✓ | | | ✓ | |
| FAD (광고성과) | ✓ | | | ✓ | | (via CAMPAIGN) | ✓ | | | | | |

> 회원 식별은 모두 **MEMBER_DK**(불변)로. ORG는 FTG-D·FTG-B만 직접, 나머지는 캠페인 경유(G). FTG-D는 `DEV_TYPE`(개발구분, MM015) degenerate 보유.
> **⚠️ FTG 2분할 확정 (팩트설계 결정9 / BRONZE 컨트랙트 §4-1 반영)**: 단일 FACT_TARGET이 grain·소스가 다른 두 목표를 혼합 → **2팩트 분리**. ① **FTG-D**(`FACT_TARGET_DEV`): 소스 CRM `TM_CM_MBER_DVLP_GOAL`(확정), grain=(MONTH_KEY×ORG×개발구분), measure=GOAL_CNT, 캠페인·후원사업 차원 **없음**(개발구분 degenerate). ② **FTG-B**(`FACT_TARGET_BIZ`): 소스 ERP 사업목표(미수령·적재예약), grain=(MONTH_KEY×ORG×후원사업[×캠페인]), measure=#152~155. FMM↔FTG-D 비교는 ORG+개발구분+월, FMM↔FTG-B 비교는 ORG+후원사업+월로 조인.

---

## 14. 미해결 / 현업 확인 (설계는 방어 완료, 값만 확인)
> 아래는 **설계가 어느 답이든 안전**하도록 방어됨. 확인은 라벨/계층 채움용이지 구조 변경 아님.
1. DIM_CAMPAIGN 계층 순서 — 분리설계라 오답이어도 컬럼 무손상.
2. DIM_ORG '팀' 존재 — NULL 허용으로 방어.
3. 캠페인↔후원사업 카디널리티 — 분리차원+양 SK로 방어(C).
4. DIM_SERVICE `SERVICE_TYPE`·`서비스명`·`PARTICIPATION_DEF` 원천 — subtype/메타로 방어(H).
5. DIM_PAYMENT `회비유형` 원천 코드 유무(J). + **회비유형 이중표현(차원 컬럼 vs #66~68 measure) 단일화 — 5단계(팩트설계 결정8 연계).**
6. DIM_MEMBER_IDENTITY 매핑 알고리즘·신뢰도 — SILVER 단계 설계, 쌍단위 grain으로 방어(B).
7. SCD2 적용 범위(회원상태·조직) 이력 요구 — 현업 합의.
