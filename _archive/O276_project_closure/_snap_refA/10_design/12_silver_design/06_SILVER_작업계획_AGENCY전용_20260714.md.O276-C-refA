<!-- LLM-METADATA
doc_id: SILVER_AGENCY_WORKPLAN
doc_role: silver_work_plan (AGENCY-only subset / 트랙 D)
project: GN_DW (굿네이버스)
created: 2026-07-14
scope: AGENCY(∪GADS∪ADMIN) 단독 — BRONZE_AGENCY 광고유형별 3테이블 → SILVER AGENCY 3객체
status: ✅ AGENCY SILVER 적재완료 — AD_PERFORMANCE 235,572(DGT∪REBRDC∪VIDEO) · AD_CREATIVE 8,473 · DQ 통과 · 통합검증(09 STEP 8) PK유일. AGENCY_COST는 리뷰 후 GOLD 이관(SILVER 미생성)
master_plan: 04_silver_design/02_SILVER_작업계획_BRONZE-GOLD연결 20260714.md  # 매핑 인덱스(정본)
relation: master §1 매핑의 AGENCY 행 + 트랙 D 상세 실행본
inputs(bronze): 99_provided_definition/12_bronze_agency_ddl.sql · BRONZE_AGENCY.{DGT_AD_CMPGN_DTLS, REBRDC_AD_CMPGN_DTLS, VIDEO_AD_CMPGN_DTLS}
END-METADATA -->

# SILVER 작업계획 — AGENCY 전용 (트랙 D) / GADS·ADMIN

> ⚠️ 본 문서는 **마스터 인덱스(`02_...20260714.md`)의 AGENCY 분리 실행본**이다.
> 공통 원칙·GOLD 커버리지 요약은 master 참조. 객체 명칭·정제 규칙 불일치 시 master 우선.
> **GADS·ADMIN은 AGENCY로 흡수**(별도 prefix 미생성).
>
> 🔄 **[2026-07-28 재설계]** §0~§5 는 초기 **3객체** 설계 기준 기술이다. 현행은 **8객체**(staging 3 + 코어 2 + 위성 3) — **§6-B 참조**.
> 🔄 **[2026-07-29]** `08_SILVER_테이블DDL_20260714.sql` 의 설계근거·실측이력 주석을 **§6 으로 이관**했다(08 = 구조 계약만).

---

## 0. 범위

- **만들 것**: `GN_DW.SILVER` 의 **AGENCY 3개 객체** (광고유형별 3테이블 → 정규화·UNION).
- **이로써 빌드되는 GOLD**: `DIM_AD_CREATIVE` · `FAD`(AD_PERFORMANCE) · `FBD`(모금성비용/광고비 보강분).
- **현 상태**: BRONZE_AGENCY 3테이블 적재 = DGT 197,686 / REBRDC 2,064 / VIDEO 35,822 (합 235,572). **실측 검토·정규화 전략 확정 후 SILVER 신설**.
- **범위 외**: CRM/GA4/ERP 객체(각 전용 문서). ADMIN 앱푸시(→FSE)·이벤트 조회수(→FEP) 보강은 목적지 미정(제외 확정).

---

## 1. 생성할 AGENCY 3개 객체

| # | SILVER 객체 | BRONZE 원천 | 그레인 | 충족 GOLD | 상태 |
|---|---|---|---|---|---|
| 1 | `AGENCY_AD_CREATIVE` | 3테이블 소재/매체 필드(산재·부분) | 매체·플랫폼·소재·CM위치·초수·RT유형 | `DIM_AD_CREATIVE` | ✅ **적재완료 8,473** |
| 2 | `AGENCY_AD_PERFORMANCE` | `DGT`·`REBRDC`·`VIDEO`_AD_CMPGN_DTLS (유형별 정제→UNION) | 일×캠페인×소재×기기 | `FAD` | ✅ **적재완료 235,572**(원천 1행 grain, 광고비 AD_COST+COST_TYPE 포함) |
| ~~3~~ | ~~`AGENCY_COST`~~ | — | — | `FBD` | ❌ **제거(리뷰)**: 월 롤업=GOLD 소관(§3)·AD_COST 중복·SILVER파생 위반 → GOLD FBD로 이관 |

---

## 2. 빌드되는 GOLD

| GOLD | 충족 SILVER | 상태 | 비고 |
|---|---|---|---|
| `DIM_AD_CREATIVE` | `AGENCY_AD_CREATIVE` | ◐ | 매체·플랫폼·소재·CM위치·초수·RT유형 — 원천별 산재/부분 |
| `FAD` AD_PERFORMANCE | `AGENCY_AD_PERFORMANCE` + `GA4_EVENT`(전환) | 🟢실적재 | 광고비·노출·클릭·인입콜·전환수(명/건). grain=일×캠페인×소재×기기. 비용 base는 FBD 분리 |
| `FBD`(보강) | `AGENCY_AD_PERFORMANCE`(AD_COST/COST_TYPE) (+ ERP `ERP_BUDGET`) | ◐ | 모금성비용·광고비. **월 롤업·ERP 결합은 GOLD**(AGENCY_COST SILVER 롤업은 리뷰 후 제거 — §3). ERP 문서(05) FBD와 결합 |

---

## 3. 트랙 D 선결·실측 검토 (S-6 착수 전 게이트)

> **[실측 2026-07-13]** AGENCY는 단일 테이블이 아니라 **광고유형별 3테이블이 스키마 상이**: `DGT_AD_CMPGN_DTLS`(디지털 197,686)·`REBRDC_AD_CMPGN_DTLS`(재송출 2,064)·`VIDEO_AD_CMPGN_DTLS`(영상 35,822).

- **결론1·2 — 명/건·CVR**: 전환수 `GA_CONV_MBER_CNT`(명, Σ122,551) > `CONV_VU_CNT`(Σ63,372.9, **소수=비건수**) → VU '건' 단정 금지. **`CVR=전환명/클릭` 확정**(오차 1.7e-6, O5).
- **결론4 — 인입콜 타입 불일치**: 재송출(REBRDC).`INBOUND_CALL_CNT`=**TEXT** vs 영상(VIDEO)=**NUMBER** → 통합 전 `TRY_TO_NUMBER` 캐스팅 필수. 영상 `CONV_CALL_CNT`(전환콜)은 인입콜과 별개 measure.
- **결론5 — `_SOURCE_SYSTEM` 부재(A-2)**: 3테이블에 행 단위 출처 플래그 없음. `GA_`/`CRM_` 접두는 지표별 귀속시스템(GA집계 vs CRM집계)이지 광고 출처(대행사 vs Google Ads) 아님. 3테이블 분리도 광고**유형**(디지털/재송출/영상)이지 출처 아님 → **SILVER에서 테이블 기반 명시 `_SOURCE_SYSTEM` 부여**.
- **measure 불균일**: 노출·클릭=DGT만 / 인입콜=REBRDC·VIDEO+CONV_CALL_CNT / GA전환=DGT만 / 광고비=DGT `GA_AD_COST`·REBRDC `BRDC_SCHDL_COST`(편성)·VIDEO `ACTL_PUR_AD_COST_KRW`(집행)로 **컬럼·의미 상이**.
- **DGT 파생 사전계산**(CPA·CTR·CVR·CPC·CPM·VTR·DEV_UNIT_PRICE) → P2(derived는 SV) 충돌: **원천값 신뢰 vs 재계산 결정** 필요. → REBRDC/VIDEO는 노출·클릭 부재 → CTR/CVR 재계산 불가(DGT만 GOLD/SV 재계산, 타 유형은 원천값 의존 명시).
- **Q9 — 노출·클릭 GA vs AGENCY 출처구분(O5)**: 위 `_SOURCE_SYSTEM` 부여로 해소 방향.
- **캠페인 이름 매칭**: 캠페인=이름(`CMPGN_NM`/`MKT_CMPGN_NM`, 코드X) → `DIM_CAMPAIGN` **이름 매칭 크로스워크** 필요(오류 취약 → 커버리지 측정+미매칭 플래그 필수).

> **→ 트랙 D는 위 정규화 전략·이름매칭·파생처리·`_SOURCE_SYSTEM` 부여를 확정한 뒤 SILVER 신설.**

---

## 4. AGENCY 정제 규칙

- **공통 규칙**: master §3 (타입·NULL·코드→라벨·메타 4컬럼·금액 원단위) 준수.
- **AGENCY 특수**:
  1. **유형별 정제 → UNION**: 3테이블 공통 measure 정렬 + 전용 measure NULL 패딩.
  2. **`_SOURCE_SYSTEM` = 테이블 기반 부여**(디지털/재송출/영상), 광고 출처(대행사/GoogleAds)는 별도 규칙.
  3. **인입콜 `TRY_TO_NUMBER`** 캐스팅(REBRDC TEXT → NUMBER).
  4. 파생지표(CPA·CTR·CVR 등)는 **SILVER 미계산**(원천값 보존/플래그) — 재계산은 GOLD/SV.
  5. 캠페인 이름 매칭은 크로스워크 테이블 + 미매칭 플래그.

---

## 5. 완료 정의 & 다음

> **🥉 착수 순서 = 3차** (master §7). 확정해야 할 설계 결정이 가장 많아(정규화·이름매칭·`_SOURCE_SYSTEM`·파생처리) 후순위. `FAD` 전환분은 GA4(1차) 완료 후 결합, `FBD` 비용은 ERP(2차)와 결합 → **선행 트랙 완료 후 착수가 효율적**.
> **블로커 事前 triage(master 원칙 B)** — DDL 작성 前 확정: 아래는 모두 **설계 결정 블로커**(실행 아님)이므로 §3 게이트에서 먼저 확정한 뒤 08/09 append.
> - `_SOURCE_SYSTEM` 부여 규칙(테이블 기반) · 인입콜 `TRY_TO_NUMBER` 캐스팅 · 3테이블 measure 불균일 UNION 패딩 · 캠페인 이름매칭 크로스워크(미매칭 플래그) · DGT 파생 원천값 신뢰 vs 재계산.

- **완료 현황(2026-07-14, 아키텍처 리뷰 반영)**: ✅ **AGENCY 2객체 적재완료** — `AGENCY_AD_PERFORMANCE`(235,572=3소스 UNION 원천1행) · `AGENCY_AD_CREATIVE`(8,473 distinct). 설계결정 6종 데이터 확정.
  - **리뷰 정정 2건**: ① **연·월 = DATE 파생**으로 변경 — 텍스트 `YEAR`/`MONTH`가 `'2025년'`·`'03월'` 형식이라 `TRY_TO_NUMBER` 96% NULL이던 결함 해소(AD_YEAR/AD_MONTH NULL 0). ② **`AGENCY_COST` 제거** — 월 롤업은 master §3상 GOLD 소관, `AD_COST`+`COST_TYPE` 중복, SILVER→SILVER 파생(단방향 위반). 비용은 성과팩트에 원천 grain 보존, 롤업·ERP결합은 GOLD FBD.
  - **DQ 통과**: 소스별 행수 정확 일치(197,686/2,064/35,822)·연월 NULL 0·연 2023~2026·CREATIVE PK 0중복·인입콜 TRY_TO_NUMBER(비수치 2건). DDL=`08` STEP5 · 적재=`09` STEP5.
  - **🔎 아키텍처 리뷰 이력(2026-07-14)**: 비판적 점검에서 **결함 2건 발견·수정** — ① 연·월 텍스트 파싱 96% NULL → DATE 파생 재적재(NULL 0) · ② `AGENCY_COST` 월 롤업(§3 위반·중복·SILVER파생) → **제거→GOLD 이관**. 잔여 관찰: `AGENCY_AD_PERFORMANCE`는 이벤트 grain 팩트로 자연 PK 없음(무결성 게이트=소스 행수 대사 235,572) · `AD_COST`는 GA/편성/집행 혼재이므로 `COST_TYPE` 분리 집계 필수(단순 SUM 금지).
- **완료 조건**: 정규화 전략·이름매칭·파생처리 확정 → AGENCY SILVER 신설(S-6) → `DIM_AD_CREATIVE`·`FAD` 빌드 + `FBD` 비용 보강(ERP 결합, GOLD).
- **다음(LLM)**: (a) 3테이블 컬럼 프로파일·공통/전용 measure 매핑 → (b) `_SOURCE_SYSTEM`·인입콜 캐스팅·이름매칭 규칙 확정 → (c) SILVER 신설·UNION 적재 → (d) `08_silver의존.md` AGENCY lineage로 `FAD`/`FBD` 적재. GA4 전환(FAD)은 GA4 문서(04), 비용(FBD)은 ERP 문서(05)와 연동.

---

## 6. DDL 설계근거 (08 DDL 에서 이관 · 2026-07-29)

> `08_SILVER_테이블DDL_20260714.sql` 은 구조 계약(타입·PK·COMMENT)만 담도록 정리했다.
> AGENCY 관련 설계근거·실측수치·리뷰이력은 아래로 이관했다. **08 은 본 절을 참조한다.**

### 6-A. 설계결정 6종 (실측 2026-07-14 · 종전 08 STEP 5 헤더 ①~⑥)

| # | 결정 | 근거 |
|---|---|---|
| ① | `SOURCE_SYSTEM` = **테이블 기반** 부여(DIGITAL/REBROADCAST/VIDEO) | 3테이블에 행단위 출처 플래그 없음(A-2/Q9) |
| ② | 인입콜 `TRY_TO_NUMBER` 캐스팅 | REBRDC `INBOUND_CALL_CNT`=TEXT(비수치 2/2,064) vs VIDEO=NUMBER |
| ③ | 전환 명/건 컬럼 분리 | DGT `GA_CONV_MBER_CNT`(명)/`CONV_VU_CNT`(VU) · REBRDC `DVLP_MBER_CNT`/`DVLP_CNT` · VIDEO `CONV_CALL_CNT` |
| ④ | measure 불균일 → **NULL 패딩** | 노출·클릭=DGT만 / 광고비=`GA_AD_COST`·`BRDC_SCHDL_COST`(편성)·`ACTL_PUR_AD_COST_KRW`(집행) |
| ⑤ | 캠페인명 소스별 상이 | DGT `CMPGN_NM`(100%) · VIDEO `MKT_CMPGN_NM`(98.4%) · REBRDC 컬럼부재(방송명 `BRDC_NM` 대체) |
| ⑥ | 파생(CPA/CTR/CVR/CPC/CPM/VTR) **SILVER 미계산** | 원천 base 만 보존, 재계산은 GOLD/SV(P2) |

- 그레인: `AGENCY_AD_PERFORMANCE` = 원천 1행(3소스 UNION 235,572) · `AGENCY_AD_CREATIVE`/위성 = 파생 정제.
- **`AGENCY_COST` 제거(2026-07-14 아키텍처 리뷰)**: 월 롤업은 master §3상 GOLD 소관 · `AD_PERFORMANCE.AD_COST`+`COST_TYPE` 와 중복 · SILVER→SILVER 파생(단방향 위반). 비용은 성과팩트에서 원천 grain 보존, 롤업·ERP 결합은 GOLD `FACT_BUDGET`.

### 6-B. 광고 팩트군 재설계 — 8객체 (2026-07-28 순서9-I · DEC-8~11)

> 근거: `03_top-down_gold/03_테이블 설계.md §3-A` · `20_issue/10_진단_원인분석.md §8-I` · `20_issue/30_설계_의사결정.md §1-A`
> ⚠️ §0~§5 의 "AGENCY 3객체" 기술은 이 재설계 **이전** 상태다. 현행 = **8객체**.

구성: **staging 3**(무손실 전컬럼 보존 + `AD_PERF_DK` 발급) → **코어 2** → **위성 3**

| SILVER 객체 | 역할 | 실측 행수 | GOLD |
|---|---|---:|---|
| `AGENCY_AD_ROW_DGT` | DGT 36컬럼 무손실 staging | 197,686 | — |
| `AGENCY_AD_ROW_VIDEO` | VIDEO 32컬럼 무손실 staging | 35,822 | — |
| `AGENCY_AD_ROW_REBRDC` | REBRDC 34컬럼 무손실 staging(CASE 반복군 포함) | 2,064 | — |
| `AGENCY_AD_PERFORMANCE` | 코어 — 3소스 공통 measure UNION | 235,572 | `FACT_AD_PERFORMANCE` |
| `AGENCY_AD_CREATIVE` | 코어 — 소재/매체 차원 | 8,473 | `DIM_AD_CREATIVE` |
| `AGENCY_AD_DIGITAL` | 위성 — 디지털 고유속성 + `_SRC` 7종 | 197,686 | `FACT_AD_DIGITAL` |
| `AGENCY_AD_BROADCAST` | 위성 — 방송(VIDEO∪REBRDC) 고유속성 | 37,886 | `FACT_AD_BROADCAST` |
| `AGENCY_AD_BROADCAST_CASE` | 위성 — REBRDC 사례 5속성×3반복 언피벗 | 5,327 | `FACT_AD_BROADCAST_CASE` |

- **DEC-11 `AD_PERF_DK` = `MD5(AD_SOURCE_TYPE|ROW_HASH|DUP_SEQ)`** — 발급 단일지점은 staging 3종. 코어·위성·GOLD 는 승계만(재계산 금지). `ROW_HASH`=`MD5(TO_JSON(OBJECT_CONSTRUCT(*)))`, `DUP_SEQ`=전컬럼 중복 그룹 내 순번(DGT 35그룹·최대2 / VIDEO 30그룹·최대3 / REBRDC 0그룹).
- **DEC-8 `AD_SOURCE_TYPE`** 출처 명시축 신설 → GOLD FAD degenerate 승격. 종전 `AD_TYPE` 은 `DIM_AD_CREATIVE.AD_TYPE` 과 충돌해 개명.
- **DEC-9 `_SRC` 8종 전량 보존 · 전량 비가산(N)** — 대행사 산정값이므로 SUM 금지.
- **DEC-10 `DIM_DEVICE` 실배선** — DGT `DEVICE`(실측 `PC`/`M`) 조인, `(해당없음)` 멤버 추가.
- **O16 의미혼입 해소**: 종전 SILVER UNION 이 REBRDC `DVLP_MBER_CNT`·`DVLP_CNT`(재방송 개발실적)를 DIGITAL 의 GA 전환 자리에 **위치매핑**해 GOLD `GA_CONV_MEMBERS`(오염 28.60%)·`GA_CONV_CNT`(60.32%)로 노출했다. → 개발실적을 `AGENCY_AD_BROADCAST.DVLP_MEMBER_CNT`/`DVLP_CNT` 로 이관, 코어 `CONV_MEMBER_CNT`/`CONV_UNIT_CNT` 는 **DIGITAL 전용**으로 확정.
- **staging 규약**: BRONZE 컬럼명·타입 그대로 보존(개명·형변환 금지). `YEAR`·`MONTH`·`WEEK`·`DOW`·`BRDC_MT` 는 `'2025년'`·`'03월'` 형태 텍스트 — 숫자 파싱 시 96% NULL(2026-07-14 실측 결함), 시간축은 `DATE` 컬럼에서 파생.
- **미노출 컬럼**: `CASEn_CHILD_NM`·`CELEB_NM` = PII 판정 대기(**O14**, 현 설계 미적재) · 기타 52컬럼 = 지표 수요 미확인(**O15**, staging 에 무손실 보존).
- **dbt build 결과(2026-07-28)**: `PASS=258 WARN=21 ERROR=0`(WARN 21 전부 기존 CRM 고아관계, 신설분 0). `AD_PERF_DK` 235,572건 전건 유일 · `DEVICE_SK` unknown 0건.

### 6-C. 컬럼 어의 미결·주의 (08 컬럼 COMMENT 에 요약 반영)

| 컬럼 | 실측 | 상태 |
|---|---|---|
| `AGENCY_AD_DIGITAL.CRM_DEV_CNT` | 값 있는 189,252행 중 **24,614행(13.0%) 비정수**(min 0.0·max 322.0·합 249,390.45) | **AD-2** 기여도 배분값 여부 현업 확인 대기 — "건수" 단정 금지 |
| `CRM_DEV_CNT` ↔ `DEV_UNIT_PRICE_SRC` | 2026-01~05 = 건수 전건 / **2026-06 = 단가 8,401행 전건**. 동일 행 공존 **0건** | **AD-3** 원천 포맷 변경. 검증관계 아닌 **기간보완** 관계 → 개발단가는 2026-05까지만 산출 |
| `AGENCY_AD_BROADCAST.DVLP_CNT`·`DVLP_MEMBER_CNT` | REBRDC 전용. VIDEO 원천에 개발 항목이 **구조적으로 부재**(전환콜로 대체 보고) | **AD-5** 비율 분모는 REBRDC 2,064행 단독으로 한정(96.03%). 방송 전체 37,886행을 분모로 잡으면 +41% 과대계상(순서9-J 오진 → 9-K 철회, **P21**) |
| `AGENCY_AD_PERFORMANCE.SOURCE_SYSTEM` | `AD_SOURCE_TYPE` 와 **전건 동일값**(불일치 0건, 2026-07-29 실측) | 중복 컬럼. 신규 소비는 `AD_SOURCE_TYPE` 사용 |
| `AGENCY_AD_PERFORMANCE.AD_COST` | `COST_TYPE` 실측값 = `GA`/`편성`/`집행` 혼재 | **단순 SUM 금지** — `COST_TYPE` 분리 집계 |
| `AGENCY_AD_PERFORMANCE` | 이벤트 grain 팩트로 자연 PK 없음 | 무결성 게이트 = 소스 행수 대사(235,572) |

