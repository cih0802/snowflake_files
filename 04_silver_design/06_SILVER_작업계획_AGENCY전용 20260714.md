<!-- LLM-METADATA
doc_id: SILVER_AGENCY_WORKPLAN
doc_role: silver_work_plan (AGENCY-only subset / 트랙 D)
project: GN_DW (굿네이버스)
created: 2026-07-14
scope: AGENCY(∪GADS∪ADMIN) 단독 — BRONZE_AGENCY 광고유형별 3테이블 → SILVER AGENCY 3객체
status: 🟢 BRONZE 적재(DGT 197,686 / REBRDC 2,064 / VIDEO 35,822 = 235,572행)·SILVER 미생성 — 트랙 D 착수 전 실측 검토·정규화 전략 확정 대기
master_plan: 04_silver_design/02_SILVER_작업계획_BRONZE-GOLD연결 20260714.md  # 매핑 인덱스(정본)
relation: master §1 매핑의 AGENCY 행 + 트랙 D 상세 실행본
inputs(bronze): 99_provided_definition/12_bronze_agency_ddl.sql · BRONZE_AGENCY.{DGT_AD_CMPGN_DTLS, REBRDC_AD_CMPGN_DTLS, VIDEO_AD_CMPGN_DTLS}
END-METADATA -->

# SILVER 작업계획 — AGENCY 전용 (트랙 D) / GADS·ADMIN

> ⚠️ 본 문서는 **마스터 인덱스(`02_...20260714.md`)의 AGENCY 분리 실행본**이다.
> 공통 원칙·GOLD 커버리지 요약은 master 참조. 객체 명칭·정제 규칙 불일치 시 master 우선.
> **GADS·ADMIN은 AGENCY로 흡수**(별도 prefix 미생성).

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
| 1 | `AGENCY_AD_CREATIVE` | 3테이블 소재/매체 필드(산재·부분) | 매체·플랫폼·소재·CM위치·초수·RT유형 | `DIM_AD_CREATIVE` | ◐ 필드 산재 |
| 2 | `AGENCY_AD_PERFORMANCE` | `DGT`·`REBRDC`·`VIDEO`_AD_CMPGN_DTLS (유형별 정제→UNION) | 일×캠페인×소재×기기 | `FAD` | 🟢 실적재·불균일 |
| 3 | `AGENCY_COST` | 3테이블 광고비 컬럼(유형별 상이) | 월×조직×캠페인 광고비 | `FBD`(모금성비용/광고비) | ◐ ERP 보강 |

---

## 2. 빌드되는 GOLD

| GOLD | 충족 SILVER | 상태 | 비고 |
|---|---|---|---|
| `DIM_AD_CREATIVE` | `AGENCY_AD_CREATIVE` | ◐ | 매체·플랫폼·소재·CM위치·초수·RT유형 — 원천별 산재/부분 |
| `FAD` AD_PERFORMANCE | `AGENCY_AD_PERFORMANCE` + `GA4_EVENT`(전환) | 🟢실적재 | 광고비·노출·클릭·인입콜·전환수(명/건). grain=일×캠페인×소재×기기. 비용 base는 FBD 분리 |
| `FBD`(보강) | `AGENCY_COST` (+ ERP `ERP_BUDGET`) | ◐ | 모금성비용·광고비 → ERP 문서(05) FBD와 결합 |

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

- **완료 조건**: 정규화 전략·이름매칭·파생처리 확정 → AGENCY 3객체 SILVER 신설(S-6) → `DIM_AD_CREATIVE`·`FAD` 빌드 + `FBD` 비용 보강(ERP 결합).
- **다음(LLM)**: (a) 3테이블 컬럼 프로파일·공통/전용 measure 매핑 → (b) `_SOURCE_SYSTEM`·인입콜 캐스팅·이름매칭 규칙 확정 → (c) SILVER 신설·UNION 적재 → (d) `08_silver의존.md` AGENCY lineage로 `FAD`/`FBD` 적재. GA4 전환(FAD)은 GA4 문서(04), 비용(FBD)은 ERP 문서(05)와 연동.
