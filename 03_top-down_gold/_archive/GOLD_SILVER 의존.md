# GOLD ↔ SILVER 의존 메모 (7단계 산출물)

> 입력: `GOLD_ddl 초안.sql`(18테이블 컬럼: DIM 12 + FACT 6) + `GOLD_차원 설계.md`(DIM 소스#) + `GOLD_팩트 설계.md`(FACT measure 배속) + `GOLD_지표 분류.md`(소스 태그) + `GOLD_메타제약 확인.md`(BRONZE 컨트랙트).
> **목적**: GOLD 각 컬럼이 요구하는 **SILVER 소스(역산 BRONZE)** 를 명시 → 다음 트랙 **SILVER 정제 역산 → BRONZE 컨트랙트(타팀 전달)** 의 입력.
> **원칙**:
> - **소스 1:1은 BRONZE 한정. SILVER는 통합·정제(consolidation). GOLD FACT는 소스 횡단 통합** → 본 메모는 GOLD 컬럼이 *어느 SILVER 소스의 어느 개념 엔티티*를 요구하는지까지만 명시한다.
> - SILVER 물리 스키마는 아직 미설계 → **SILVER 컬럼명은 추정하지 않고 "소스.개념엔티티" 수준**으로 표기(예: `SILVER_CRM.납입이력`). 정확한 SILVER 컬럼은 다음 트랙에서 확정.
> - 측정값 #는 GOLD DDL COMMENT 기준. 산출불가(raw 부재) 항목은 **▶BRONZE** 로 표시(4절).

---

## 0. 소스 레이어 맵 (BRONZE = 소스 1:1, SILVER = 통합·정제)

| SILVER 소스 | BRONZE 원천 | 담는 개념 엔티티(역산 대상) |
|---|---|---|
| `SILVER_CRM` | CRM (**40개 원천 테이블/882컬럼**) | 회원마스터, 회원상태이력, 후원약정(후원사업별 금액), 납입이력, 청구이력, 캠페인마스터, 후원사업마스터, 조직마스터, 발송이력, 참여매칭이력, 납입방식, 사유코드, **회원개발목표(TM_CM_MBER_DVLP_GOAL→FTG-D)** |
| `SILVER_GA4` | GA4 | 세션, 이벤트, 사용자(member id), 트래픽소스(utm), 광고(노출/클릭/전환/광고비), 페이지/스크롤, **잠재고객(타겟그룹)**(2026-06-24, 원천표기 GA) |
| `SILVER_ERP` | ERP | **사업목표(연사업·추경 #152~155, 후원사업별→FTG-B, ⚠️미수령)**, 모금성비용(세세목), **편성예산·집행예산(ERP 마감값)**(2026-06-24) |
| `SILVER_AGENCY` | AGENCY(대행사) | 광고소재마스터(매체·플랫폼·기기·소재·CM위치·초수), 편성비, 매체별 노출/클릭/인입콜, **집행예산 추정치**, **GA전환수(명·건)**(2026-06-24) |
| `SILVER_GADS` | GADS(Google Ads) | 광고비·노출·클릭(AGENCY와 복수원천) — **신규원천 2026-06-24, 미수령** |
| `SILVER_ADMIN` | ADMIN(어드민) | 앱 푸시 발송/성공(모바일앱>푸시발송목록), 이벤트목록 조회수 — **신규원천 2026-06-24, 미수령** |

> **통합 지점은 GOLD에서만 발생**(3절). SILVER에서는 위 6소스가 각자 1:1로 정제된다.
>
> **🆕 2026-06-24 정의서 반영** — 정본 `GOLD_정의서_업데이트 20260624.md`. 4소스(CRM·GA4·ERP·AGENCY) → **6소스(+GADS·ADMIN)**. 변경 lineage: 광고비/노출/클릭 = AGENCY∪GADS(FAD `_SOURCE_SYSTEM` 구분), GA전환수 명/건 = AGENCY∪GA4, 집행예산 = ERP(확정)∪AGENCY(추정), 앱푸시/이벤트조회 = ADMIN. 인바운드콜·TS콜 = CRM(FMM), 아동번호 = CRM. ERP `SILVER_ERP`는 집행예산(확정·마감값)·편성예산 추가. ⚠️ 단 **GADS·ADMIN은 AGENCY 또는 CRM으로 통합 예정(목적지 미정, delta §5)** → 독립 6소스·lineage 구분은 **잠정**(통합 결정 시 4~5소스로 축소 가능).

---

## 1. DIM 의존 (12)

| GOLD 테이블.컬럼 | 소스# | 요구 SILVER 소스.엔티티 | 비고 |
|---|---|---|---|
| **DIM_DATE**.* | — | (없음) | ETL 생성 캘린더. 팩트 일자 범위로 채움. 소스 무관 |
| **DIM_MEMBER**.MEMBER_BK | #110 | `SILVER_CRM.회원마스터`(회원번호) | DK는 회원번호 기반 해시(SILVER 생성) |
| DIM_MEMBER.GENDER/REGION | #130·131 | `SILVER_CRM.회원마스터` | |
| DIM_MEMBER.MEMBER_STATUS | #132 | `SILVER_CRM.회원상태이력` | SCD2 → 상태 변경 이력 필요 |
| DIM_MEMBER.NEW_EXIST_FLAG | #113 | `SILVER_CRM.회원마스터` | |
| DIM_MEMBER.FIRST_JOIN_DATE | #28 | `SILVER_CRM.회원마스터`(회원번호 생성일) | |
| DIM_MEMBER.FIRST_CAMPAIGN_SK | #29 | `SILVER_CRM.후원약정`(최초 가입 캠페인) | DIM_CAMPAIGN 조인키로 해소 |
| DIM_MEMBER.LAST_STOP_DATE | #30 | `SILVER_CRM.회원상태이력`(최종 중단일) | |
| DIM_MEMBER.LAST_CAMPAIGN_SK | #31 | `SILVER_CRM.후원약정`(최종 캠페인) | |
| **DIM_MEMBER_IDENTITY**.MEMBER_NO | #110 | `SILVER_CRM.회원마스터` | |
| DIM_MEMBER_IDENTITY.MEMNUM | #111 | `SILVER_CRM.회원마스터`(링크키 memnum) | |
| DIM_MEMBER_IDENTITY.GA_MEMBER_ID | #112 | `SILVER_GA4.사용자`(member id) | **cross-source 매핑 입력** |
| DIM_MEMBER_IDENTITY.SPONSORED_CHILD_CODE | #122 | `SILVER_GA4.트래픽소스/페이지`(URL 파싱) | URL→결연아동코드 파싱 규칙 SILVER 설계 |
| DIM_MEMBER_IDENTITY.MATCH_METHOD/CONFIDENCE | — | (SILVER 매핑 알고리즘 산출) | 1:N 매핑 알고리즘은 SILVER 트랙 |
| **DIM_CAMPAIGN**.CAMPAIGN_BK/명/유형 | #120·18·17 | `SILVER_CRM.캠페인마스터` | |
| DIM_CAMPAIGN.국내해외/사업사례/오픈일자 | #15·16·19 | `SILVER_CRM.캠페인마스터` | |
| DIM_CAMPAIGN.공통캠페인/상위/브랜드/홍보방법 | #147·119·117·118 | `SILVER_CRM.캠페인마스터` | #102 세션캠페인(GA)은 정합 스테이징 후 매핑 |
| DIM_CAMPAIGN.ORG_SK | #114~116 | ✅ `SILVER_CRM.조직마스터`(TM_CM_DEPT_INFO) | 운영조직 경로(G). CRM 부서마스터 확정 |
| **DIM_SPONSORSHIP**.BK/명/약칭 | #123·124 | `SILVER_CRM.후원사업마스터` | |
| **DIM_ORG**.법인/본부지부/부서 + **ORG_BK**(=DEPT_ID)·ORG_LEVEL(=STATS_DEPT_LVL) | #114·115·116 | ✅ `SILVER_CRM.조직마스터`(TM_CM_DEPT_INFO: DEPT_ID/DEPT_NM/UPPER_DEPT_ID/STATS_DEPT_LVL) | CRM 부서마스터 확정. ORG_BK=DEPT_ID가 FTG-D/FTG-B/CAMPAIGN ORG_SK 조인 해소키(F1). 전 노드 적재로 레벨 무관 조인 방어(F2, 레벨/롤업 정책 보류) |
| DIM_ORG.TEAM | ⚠️ | (원천 미확인) | '팀' 존재 시 채움, NULL 허용 |
| **DIM_AD_CREATIVE**.MEDIA~DURATION_SEC | #11·12·13·14·20·21·22 | `SILVER_AGENCY.광고소재마스터` | |
| **DIM_GA_SOURCE**.UTM_SOURCE_MEDIUM/CONTENT/KEYWORD | #109·103·104 | `SILVER_GA4.트래픽소스`(utm) | |
| **DIM_SERVICE**.발송구분_대/중/소 | #133·134·135 | `SILVER_CRM.발송이력` | |
| DIM_SERVICE.SERVICE_TYPE/NAME | ⚠️ | `SILVER_CRM.발송이력`(원천 확인) | 발송/참여 subtype 원천 ⚠️확인 |
| DIM_SERVICE.PARTICIPATION_DEF | 신36 비고 | (메타·합의) | 참여 정의 서비스별 상이 |
| **DIM_PAYMENT**.납입방식 | #125 | `SILVER_CRM.납입방식` | |
| DIM_PAYMENT.회비유형 | #66~68 역추론 | `SILVER_CRM.납입이력`(정기/일시) | ⚠️ 이중표현 보류 컬럼(결정8) |
| **DIM_GA_EVENT**.CATEGORY/LABEL/ACTION | #99·100·101 | `SILVER_GA4.이벤트` | |
| **DIM_REASON**.REASON_CODE/DESC | #82·162 | `SILVER_CRM.사유코드`(미납/중단) | 사유코드 체계 ⚠️확인 |

---

## 2. FACT 의존 (6) — measure별 소스

| GOLD 팩트 | 측정값 # | 요구 SILVER 소스.엔티티 | 비고 |
|---|---|---|---|
| **FMM**(회원·월) | 개발(건) #4 | `SILVER_CRM.후원약정`(SUM 약정금액/10000) | basis: 금액/10000 |
| FMM | GA개발(건) #5 | `SILVER_GA4.광고` 또는 `SILVER_CRM.채널코드` | ⚠️ **출처 미확정(GA4 직접 vs CRM 채널코드)**. 회원귀속 시 IDENTITY 필요 → 3절 |
| FMM | 중단/미납/활동/감액 #35·36·37·38 | `SILVER_CRM.회원상태이력`+`후원약정` | 상태별 약정금액/10000 |
| FMM | 연도초/말·월말·전월말 활동(건) #49·50·52·53 | `SILVER_CRM.회원상태이력` | 시점 스냅샷(비가산 N), #51 tie-break 규칙 보존 |
| FMM | 회비(원) #66·67·68·69·70·71 | `SILVER_CRM.납입이력`·`청구이력` | #69≈70 중복(단일화), #71 청구 |
| FMM | 캠페인/상태별 미납(건) #83·84 | `SILVER_CRM.회원상태이력`+`후원약정` | 분류축 measure 분리(결정8) |
| FMM | 개발/증액/활동 명·건 #148·149·150·151·156·157·158·159 | `SILVER_CRM.회원마스터`·`후원약정` | 명=회원번호 distinct(COUNT), 건=금액/10000. **#152~155는 FTG 소유**(혼입 금지) |
| FMM | 개발캠페인별 납입회비 신1 | `SILVER_CRM.납입이력`+`후원약정` | |
| FMM | 이탈(건) 신20 | `SILVER_CRM.후원약정`(취소+감액 금액/10000) | ⚠️ 이탈 정의 확정(신6과 불일치) |
| FMM degenerate | 개발구분#121·신규/증액/재후원#32~34·가입일#27·중단일#26·금액대#72·73·기간대#74·75·기간#127·128·납입개월#129 | `SILVER_CRM.회원마스터`·`후원약정`·`납입이력` | 월 스냅샷(시변), 13개 |
| **FTG-D**(CRM 회원개발목표) | GOAL_CNT(개발구분·부서) | ✅ `SILVER_CRM.TM_CM_MBER_DVLP_GOAL` | STDYY+STDR_MT→MONTH_KEY, DEPT_ID→ORG, MBER_DVLP_DIV_CD(MM015)→DEV_TYPE. **#1~3 목표대비개발율 분모**. 소스 확정 |
| **FTG-B**(ERP 사업목표) | 연사업/추경/누계 목표(건) #152~155 | `SILVER_ERP.목표` 또는 사업계획시트 | ⚠️ **미수령**(ERP vs 시트). 후원사업×조직 grain, 적재예약 |
| **FSE**(서비스이벤트) | 발송/성공/실패/서신/선물금참여 명·건 #85~91 | `SILVER_CRM.발송이력`·`참여매칭이력` | 명=회원번호 distinct(중복포함) |
| FSE | +5일차 참여/증액/중단 매칭 명·건 #139~146 | `SILVER_CRM.발송이력`×`참여매칭이력` | 발송일+5일 윈도우 매칭 |
| FSE | 서비스 클릭/발송 관련 #160·161 | `SILVER_CRM.발송이력` | |
| FSE degenerate | 제목#136·발송상태#138 | `SILVER_CRM.발송이력` | |
| **FGA**(GA행동) | 방문/세션/활성사용자/이벤트수 #92~97 | `SILVER_GA4.세션`·`이벤트`·`사용자` | distinct는 비/준가산 |
| FGA | 스크롤깊이 #107 | `SILVER_GA4.이벤트/페이지` | ⚠️ 단위 확인(Q4) |
| FGA degenerate | page_path_query#105·page_location#106 | `SILVER_GA4.페이지` | |
| **FAD**(광고성과) | GA 광고비 #6 | `SILVER_GA4.광고` | |
| FAD | 노출수/클릭수 #23·24 | `SILVER_AGENCY`(매체별 노출/클릭) | 디지털·영상광고(YTTV) |
| FAD | 인입콜 #25 | `SILVER_AGENCY` | ⚠️ 단위 확인 |
| FAD reserved | 편성비 | `SILVER_AGENCY.편성비` | ▶BRONZE(raw 부재) |
| FAD reserved | 모금성비용 | `SILVER_ERP.모금성비용` | ▶BRONZE(세세목 부재) |

---

## 3. Cross-source 통합 지점 (GOLD FACT에서만 발생 — SILVER는 1:1 유지)

| GOLD 위치 | 통합되는 SILVER 소스 | 통합 키 | 산출 의존 |
|---|---|---|---|
| FMM.GA개발(건) #5 회원귀속 | `SILVER_GA4`(또는 CRM 채널코드) | **MEMBER_DK** ← IDENTITY | ⚠️ #5 출처 미확정. GA4 직접이면 cross-source |
| FGA → 회원 귀속 | `SILVER_GA4`(member id) → CRM 회원 | `DIM_MEMBER_IDENTITY`(ga_member_id↔MEMBER_DK, 1:N) | 공81·신33 |
| FSE × FGA 클릭(신32) | `SILVER_CRM.발송` + `SILVER_GA4`(클릭) | IDENTITY 브리지 | ⚠️ 신32 클릭명 출처 확정 후 cross 여부 결정 |
| FMM × FSE(신33) | `SILVER_CRM.회원` + `SILVER_CRM.발송` | MEMBER_DK | 신33(FMM×FSE) |
| FAD = 광고비(GA4) + 노출/클릭/인입콜(AGENCY) + 비용(ERP) | `SILVER_GA4`+`SILVER_AGENCY`+`SILVER_ERP` | CAMPAIGN_SK · AD_CREATIVE_SK · `SOURCE_SYSTEM` | 개발단가·ROI(▶BRONZE) |

> **핵심**: 모든 회원 cross-source 통합은 `DIM_MEMBER_IDENTITY`(MEMBER_DK ↔ ga_member_id, 1:N)에 의존. 이 브리지의 SILVER 매핑 알고리즘이 cross-source 지표(공81·신33·신32)의 선결 조건.

---

## 4. ▶BRONZE 컨트랙트 요청 (SILVER 역산 시 raw 부재 — 타팀 전달 7건)

| 지표 | GOLD 위치 | 부재 raw → 요청 BRONZE | 소스 |
|---|---|---|---|
| 공7 CRM 개발단가 | (SV, FMM÷FAD) | 광고비 raw(캠페인 귀속) | AGENCY/ERP |
| 공10 GA CVR | (SV, FGA) | **전환수** raw | GA4 |
| 공98 평균세션시간 | (SV, FGA) | 세션 engagement_time raw | GA4 |
| 공108 이탈율(GA) | (SV, FGA) | bounce/engaged_session raw | GA4 |
| 신9 캠페인별 개발단가 | FAD.편성비 | 편성비 raw | AGENCY |
| 신10 매체별 개발단가 | FAD.모금성비용 | 모금성비용 세세목 | ERP |
| 신11 캠페인별 ROI | (SV, FAD) | 비용 raw + **캠페인별 ERP 작성 기준 합의** | ERP/복합 |

> 이 7건은 GOLD 구조상 **자리(예약 컬럼/SV metric 정의)는 확보**돼 있고, SILVER 역산 시 BRONZE에 위 raw가 입고돼야 값이 채워진다. 구조 변경 불필요. (신8 LTV는 회비 21년~ 확보로 해소되어 7건에서 제외)

---

## 5. SILVER 정제 역산 요약 (소스별 필요 BRONZE 엔티티)

> 다음 트랙의 BRONZE 컨트랙트 골격. 각 SILVER 소스가 GOLD를 채우기 위해 BRONZE에 요구하는 최소 엔티티.

- **SILVER_CRM ▶ BRONZE_CRM**: 회원마스터(회원번호·성별·지역·신규기존), 회원상태이력(활동/미납1~5/중단 + 변경일시), 후원약정(후원사업별 약정금액·가입/중단일·캠페인), 납입이력(정기/일시·납입방식·납입월·**평균회비 이력(24년 이전 포함 ▶)**), 청구이력, 캠페인마스터, 후원사업마스터, 조직마스터(법인/본부지부/부서/**팀?**), **회원개발목표(TM_CM_MBER_DVLP_GOAL: 기준연·월·개발구분(MM015)·부서·GOAL_CNT → FTG-D, ✅수령)**, 발송이력(발송구분 대중소·제목·발송상태·발송일시), 참여매칭이력(서신/선물금/증액/중단 + 회원·발송 매칭), 사유코드(미납/중단), memnum 링크키.
- **SILVER_GA4 ▶ BRONZE_GA4**: 세션, 이벤트(category/label/action), 사용자(member id), 트래픽소스(utm source/medium/content/term), 광고(노출/클릭/**전환▶**/광고비), 페이지(path/location/스크롤·**engagement_time▶**·**bounce▶**), URL(결연아동코드 파싱원본).
- **SILVER_ERP ▶ BRONZE_ERP**: **사업목표(연사업·추경·누계 #152~155, 조직×후원사업 grain → FTG-B, ⚠️미수령▶)**, 모금성비용(**세세목▶**).
- **SILVER_AGENCY ▶ BRONZE_AGENCY**: 광고소재마스터(매체·플랫폼·플랫폼유형·기기·소재·CM위치·초수), 매체별 노출/클릭/인입콜, **편성비▶**.

> ▶ = 4절 BRONZE 컨트랙트(현재 부재/미합의)와 직접 연결되는 항목.

---

## 6. 정합성 점검

- **GOLD 18테이블 전수 커버**: DIM 12(1절) + FACT 6(2절, 목표 CRM/ERP 2분할) 모든 컬럼군이 SILVER 소스에 매핑됨 ✓
- **소스 1:1 원칙 유지**: 통합은 3절(GOLD FACT)에서만, SILVER는 CRM/GA4/ERP/AGENCY/GADS/ADMIN **6소스** 1:1 ✓ (2026-06-24 +GADS·ADMIN, §0) — GADS·ADMIN 통합 결정 시 4~5소스로 축소 가능(잠정)
- **회원 식별 일관**: 모든 cross-source는 MEMBER_DK(불변) 경유 — 차원설계 §13 매트릭스와 일치 ✓
- **BRONZE 7건 일치**: 4절 = `GOLD_메타제약 확인.md` 4.4 = `파생매핑.md` §8 (공7·10·98·108 + 신9·10·11) ✓ (신8 해소 제외)
- **미확정 표기 일관**: 조직 원천(CRM 확정)·FTG-B(ERP 미수령)·DIM_PAYMENT 회비유형·DIM_SERVICE subtype·신32 클릭명 = 메타제약 4.2와 동일. **FTG-D 소스는 CRM 확정으로 해소** ✓
- **추정 배제**: SILVER 물리 컬럼명을 만들지 않고 "소스.개념엔티티"로만 표기 → 다음 트랙에서 확정 ✓

## 7. 작업계획 정합 확인

| 작업계획 7단계 요구 | 본 문서 반영 |
|---|---|
| 각 FACT/DIM 컬럼이 요구하는 SILVER 컬럼 표시 | 1절(DIM)·2절(FACT) 컬럼→SILVER 소스.엔티티 |
| SILVER 정제 역산 → BRONZE 컨트랙트 입력 | 5절 소스별 BRONZE 엔티티 + 4절 ▶BRONZE 7건 |
| 다음 트랙(SILVER 정제→BRONZE 컨트랙트) 연결 | 3절 cross-source + 5절 = 다음 트랙 골격 |

**완료**: 작업계획 7단계 전부 충족. 이로써 Top-down 설계 1~7단계 산출물 완결(5단계 라이브 compile만 인증 안정화 시 선택 마무리).
