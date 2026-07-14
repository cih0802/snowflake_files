# GOLD 팩트 설계 (3단계 산출물)

> 입력: `GOLD_차원 설계.md`(12개 DIM·13절 참조 매트릭스) + `GOLD_지표 분류.md`(measure 60·degenerate/스냅샷 배속).
> 각 FACT: **grain(1행 정의) · 측정값(measure) 컬럼 · DIM FK · degenerate/스냅샷 속성 · 가산성(additivity)**.
> 명명: FK는 차원 대리키 `*_SK`, 회원 식별만 불변 `MEMBER_DK`(원칙 G·B). 측정값은 지표 #번호로 추적.
> 가산성 표기: **A**=완전가산(모든 차원 SUM 가능) · **S**=준가산(시점값, 시간축 SUM 불가·기말스냅샷) · **N**=비가산(distinct/평균, SUM 금지).

---

## 0. 설계 결정 (3단계 확정)

1. **지표 measure 60개 전수 배속 = FMM 28 · FSE 17 · FGA 7 · FTG-B 4 · FAD 4.** 1단계 measure 합계(60)와 정확히 일치 → 누락·중복 없음(0절 정합성 잠금). **(CRM 수령 정정)** 목표 팩트는 소스·grain이 다른 둘로 분리(결정 9): #152~155는 ERP 사업목표 **FTG-B**에 귀속(60 불변), CRM 회원개발목표 `GOAL_CNT`는 지표번호 없는 **base measure 1종**으로 **FTG-D**에 신설(파생 #1~3 목표대비개발율의 분모). → 물리 base measure = 60(지표) + 1(GOAL_CNT, 비번호) = **61**.
2. **유형 ≠ 배속(원칙 재적용).** dimension 유형이지만 팩트에 물리 저장되는 degenerate/스냅샷 17개(FMM 13·FSE 2·FGA 2)는 dimension 카운트(74)에 그대로 귀속. FACT 컬럼 수 ≠ measure 수.
3. **grain은 FK가 아니라 "1행이 무엇인가"로 정의.** 회원·월처럼 FK 다수라도 1:1 결정관계인 속성(가입캠페인·후원사업·납입방식)은 grain을 늘리지 않는 **결정 FK**. grain을 늘리는 FK만 grain 절에 명시.
4. **회원 식별은 전부 `MEMBER_DK`(불변).** SCD2 surrogate(MEMBER_SK)로 팩트 join 금지(원칙 B). 시점 속성 조회가 필요하면 (MEMBER_DK, 조회년월)→해당 버전 MEMBER_SK 해소.
5. **조직 귀속(원칙 G).** 실적계 팩트(FMM·FSE·FAD)는 ORG FK 없음 → `CAMPAIGN_SK→DIM_CAMPAIGN.ORG_SK` 경유. 목표(FTG)만 `ORG_SK` 직접 보유.
6. **(건) basis 보존.** 대부분 `SUM(후원금액)/10000`, 일부만 COUNT. measure 컬럼마다 basis 명시(4단계 분자/분모 매핑 입력).
7. **시간 grain 혼재 방어(신규).** DIM_DATE grain=1일이나 FMM·FTG는 **월** grain. 월 팩트는 DIM_DATE를 직접 참조하지 않고 **`MONTH_KEY NUMBER(6)`(YYYYMM) 자연키**를 보유 → 일/월 grain 혼선·잘못된 일자 조인 차단. 일 grain 팩트(FSE·FGA·FAD)만 `DATE_SK` 사용. (월 차원이 필요하면 DIM_DATE에서 월 롤업하거나 별도 DIM_MONTH 도출 — 5단계 결정.)
8. **measure로 분리된 범주는 차원 FK로 중복 부여하지 않음(신규).** 동일 분류축이 이미 measure 컬럼으로 펼쳐진 경우(예: 회비유형→정기/일시 컬럼 분리) 그 축을 차원 FK로 다시 grain에 넣으면 이중계산. → 해당 축은 컬럼 또는 FK 중 **한쪽만**.
9. **목표 팩트 2분할(CRM 수령 정정, 사용자 결정).** 목표는 grain·소스가 다른 두 개념 → **단일 FACT_TARGET 폐기, 둘로 분리**.
   - **FTG-D `FACT_TARGET_DEV`**: CRM 회원개발목표(`TM_CM_MBER_DVLP_GOAL`). grain=(월×조직×**개발구분**), measure=`GOAL_CNT`. ✅ 소스 확정·수령. 파생 #1~3(목표대비개발율) 분모.
   - **FTG-B `FACT_TARGET_BIZ`**: ERP/사업계획 사업목표. grain=(월×조직×**후원사업**[×캠페인]), measure=#152~155. ⚠️ 소스 미수령 → DDL 생성하되 적재 예약(BRONZE 컨트랙트).
   - 분할 근거: ① CRM goal 테이블에 후원사업·연사업/추경 축 부재, 대신 개발구분 보유 ② #1~3 분모는 "회원개발목표"=CRM, #152~155는 "후원사업별 연사업/추경"=ERP ③ 한 팩트에 섞으면 mixed-grain(개발구분 vs 후원사업) anti-pattern. 두 팩트는 **ORG·MONTH_KEY conformed**, 개발구분은 FMM #121(DEV_TYPE)과 conform.

---

## 1. FACT_MEMBER_MONTHLY (FMM) — 핵심 팩트

- **grain**: **1행 = (조회년월 × 회원)**. 회원의 월별 상태·실적 스냅샷.
  - 결정 FK(grain 미증가): 가입캠페인·후원사업·납입방식은 회원당 월 1조합으로 가정. ⚠️ 한 회원이 동월 복수 캠페인/사업 보유 시 grain이 (월×회원×캠페인×사업)으로 확장 → 현업 확인 항목(아래 6절 Q1).
- **PK**: (MONTH_KEY, MEMBER_DK) + 확장 시 (CAMPAIGN_SK, SPONSORSHIP_SK). 시간키는 일자 아닌 **MONTH_KEY NUMBER(6)**(결정 7).
- **소스**: CRM 실적 + GA 채널. #4 CRM 개발 / #5 GA 개발은 **개발채널 분리 measure**(둘 다 값=후원금액/10000). 지표분류 소스태그상 #5=GA4(전환추적)·#4=CRM. ⚠️ #5가 GA4 직접 export인지 CRM 내 GA채널코드인지는 미확정이나, **어느 쪽이든 FMM grain(월×회원) 불변** — GA4 직접이면 SILVER에서 ga_member_id→MEMBER_DK 해소 후 적재(결정 8 채널 컬럼분리). 6절 Q7.

### 1.1 DIM FK
| FK | → DIM | 필수 | 비고 |
|---|---|---|---|
| MONTH_KEY | (DIM_DATE 월롤업) | ✓ | 조회년월 YYYYMM. **DATE_SK 미사용**(결정 7) |
| MEMBER_DK | DIM_MEMBER(불변키) | ✓ | 시점버전은 (DK,월)로 MEMBER_SK 해소 |
| CAMPAIGN_SK | DIM_CAMPAIGN | ✓ | 가입(개발)캠페인. ORG는 이 경유(G) |
| SPONSORSHIP_SK | DIM_SPONSORSHIP | ✓ | 캠페인과 분리(C) |
| PAYMENT_SK | DIM_PAYMENT | ✓ | **납입방식만**(회비유형은 #66~68 컬럼으로 분리됨, 결정 8). DIM_PAYMENT.회비유형 미사용 |
| REASON_SK | DIM_REASON | NULL허용 | 단일 이벤트사유만. ⚠️ 동월 미납+중단 동시 발생 시 단일 FK 불가 → 6절 Q8(사유는 이벤트 팩트 후보) |

### 1.2 측정값 (28)
| 컬럼(지표) | # | basis | 단위 | 가산성 |
|---|---|---|---|---|
| CRM 개발(건) | 4 | SUM(금액)/10000 | 건 | A |
| GA 개발(건) | 5 | SUM(금액)/10000 | 건 | A |
| 중단(건) | 35 | SUM(금액)/10000 | 건 | A |
| 미납(건) | 36 | SUM(금액)/10000 | 건 | A |
| 활동(건) | 37 | SUM(금액)/10000 | 건 | S |
| 감액(건) | 38 | SUM(감액금액)/10000 | 건 | A |
| 연도초 활동회원(건) | 49 | SUM(금액)/10000 | 건 | S |
| 연도말 활동회원(건) | 50 | SUM(금액)/10000 | 건 | S |
| 월말활동회원(건) | 52 | SUM(금액)/10000 | 건 | S |
| 전월말 활동회원(건) | 53 | SUM(금액)/10000 | 건 | S |
| 정기회비 | 66 | SUM | 원 | A |
| 정기회원 일시회비 | 67 | SUM | 원 | A |
| 일시회원 일시회비 | 68 | SUM | 원 | A |
| 납입회비 | 69 | SUM | 원 | A |
| 납입 | 70 | SUM | 원 | A | 
| 청구 | 71 | SUM | 원 | A |
| 캠페인별 미납(건) | 83 | SUM(미납회비)/10000 | 건 | A |
| 회원상태별 미납(건) | 84 | SUM(금액)/10000 | 건 | A |
| 개발(명) | 148 | COUNT | 명 | A |
| 개발(건) | 149 | SUM(금액)/10000 | 건 | A |
| 증액(명) | 150 | COUNT | 명 | A |
| 증액(건) | 151 | SUM(증가분)/10000 | 건 | A |
| 활동(명) | 156 | COUNT | 명 | S |
| 활동(건) | 157 | SUM(금액)/10000 | 건 | S |
| 활동누계(명) | 158 | COUNT(누계) | 명 | N |
| 활동누계(건) | 159 | SUM(금액)/10000 누계 | 건 | N |
| 개발캠페인별 납입회비(원) | 신규1 | SUM | 원 | A |
| 캠페인별 이탈(건) | 신규20 | SUM(취소+감액)/10000 | 건 | A |

> ⚠️ **#69 납입 ≈ #70 납입(원) 중복 정의 의심** → 5단계 단일화(1단계 D#2). 현 단계는 둘 다 보존.
> ⚠️ **#66~68 회비** = 회비유형(정기/일시)이 **이미 컬럼으로 분리**됨 → 결정 8에 따라 PAYMENT_SK는 회비유형을 다시 갖지 않음(이중계산 방지). 5단계에서 `회비금액 × 회비유형` long 모델로 재정규화할지 검토.
> ⚠️ **#37 활동(건) ↔ #157 활동(건) / #156 활동(명) 중복 의심**, 그리고 #49·50·52·53 활동회원(건)과의 관계(연도초/말·월말 시점) 불명 → 동일 개념 중복 적재 위험. 4단계에서 단일 정의로 수렴, 현재는 원문 보존.
> ⚠️ **신규20 이탈(건)** ↔ #35 중단 + #38 감액 개념 중복 가능 → 4단계 분자 정의 충돌 점검(D#7).
> **준가산(S)**: 활동회원류는 기말 시점값 → 월간 SUM 금지, 기간 종료 시점값 사용. **비가산(N)**: 누계는 SUM 절대 금지.

### 1.3 degenerate / 스냅샷 속성 (13, dimension 유형·FMM 물리저장)
| 컬럼(지표) | # | 종류 | 비고 |
|---|---|---|---|
| 개발구분 | 121 | degenerate | 신규/증액/재후원 상위 구분 |
| 신규 | 32 | degenerate | 개발구분값 |
| 증액 | 33 | degenerate | 개발구분값 |
| 재후원 | 34 | degenerate | 개발구분값 |
| 캠페인 가입일 | 27 | degenerate(일자) | |
| 가입캠페인 중단일 | 26 | degenerate(일자) | |
| 후원금액대1 | 72 | 스냅샷(밴드5만) | 매월 변동→월 계산(A) |
| 후원금액대2 | 73 | 스냅샷(밴드1만) | |
| 후원기간대1 | 74 | 스냅샷(밴드5년) | |
| 후원기간대2 | 75 | 스냅샷(밴드1년) | |
| 후원기간(개월) | 127 | 스냅샷(날짜차) | 단조증가→월 스냅샷(A) |
| 후원기간(년) | 128 | 스냅샷(날짜차) | |
| 납입개월수 | 129 | 스냅샷(COUNT개월) | |

> #32~34는 #121 개발구분의 분해값 — 단일 `개발구분` 코드 + 표현용으로 둘지 5단계 검토(중복 가능).

> **🆕 2026-06-24 정의서 반영 (FMM)** — 정본 `GOLD_정의서_업데이트 20260624.md`. measure 28 인벤토리 불변, 아래는 보조 measure/입도 검토.
> - **콜 measure(M2)**: `인바운드콜수`·`TS콜수`(회원§1-3 월간, **CRM**) 신규 보조 measure 후보(FMM 월×회원 grain). 인입콜(#25)은 AGENCY→FAD 유지.
> - **measure 입도(L3)**: 용어사전이 `청구`를 건/명/금액 3종으로, 회원분류(개발·활동·중단·미납)를 명/건 쌍으로 일관 제공 → #71 청구·#83/84 미납 입도 점검(현 표 유지, 5단계 단일화 시 반영).


---

## 2. 목표 팩트 (FTG) — 2분할 (회원 grain 아님)

> **CRM 수령 정정(결정 9).** 단일 FACT_TARGET 폐기 → 소스·grain이 다른 **FTG-D(CRM 회원개발목표) / FTG-B(ERP 사업목표)** 로 분리. 두 목표 모두 ORG·MONTH_KEY conformed, FMM과 직접 합산 금지(공통 차원 정렬만).
>
> **왜 분할했나 (분할 근거)** — CRM 원천(`TM_CM_MBER_DVLP_GOAL`) 수령 후, 단일 목표 팩트로 묶을 수 없는 4가지 차이가 확인됨:
> 1. **grain 상이**: FTG-D=(월×조직×**개발구분**), FTG-B=(월×조직×**후원사업**). 한 테이블이면 한쪽 축이 상시 NULL이 되어 grain·PK가 불명확해지고 가산성 혼선.
> 2. **measure·비교축(conform) 상이**: FTG-D=GOAL_CNT(파생 #1~3 분모, **DEV_TYPE** conform), FTG-B=#152~155(연사업/추경, **SPONSORSHIP** conform). 목표대비 비율의 conformed 차원이 달라 분리해야 잘못된 조인 방지.
> 3. **소스·가용성 상이**: FTG-D는 CRM **수령·확정**, FTG-B는 ERP/사업계획 시트 **미수령**. 한 테이블이면 확정분 적재가 미수령분에 묶여 지연.
> 4. **적재 수명주기 독립**: 분리 시 확정된 FTG-D는 즉시 적재·검증, FTG-B는 ERP 입고 후 독립 적재(예약) 가능.

### 2-D. FACT_TARGET_DEV (FTG-D) — CRM 회원개발목표 ✅수령·확정

- **grain**: **1행 = (조회년월 × 조직 × 개발구분)**. CRM `TM_CM_MBER_DVLP_GOAL` 1행과 1:1.
- **PK**: (MONTH_KEY, ORG_SK, DEV_TYPE). 월 grain → **MONTH_KEY**(결정 7).
- **소스**: ✅ CRM `TM_CM_MBER_DVLP_GOAL`(STDYY+STDR_MT→MONTH_KEY, DEPT_ID→ORG, MBER_DVLP_DIV_CD[MM015]→DEV_TYPE, GOAL_CNT→measure).

#### 2-D.1 DIM FK / degenerate
| FK/속성 | → DIM | 필수 | 비고 |
|---|---|---|---|
| MONTH_KEY | (DIM_DATE 월롤업) | ✓ | YYYYMM(STDYY·STDR_MT). DATE_SK 미사용(결정 7) |
| ORG_SK | DIM_ORG | ✓ | **직접 참조**(목표, 원칙 G). 소스 DEPT_ID→DIM_ORG.ORG_BK(#116)로 해소(레벨 무관) |
| DEV_TYPE | (degenerate) | ✓ | 개발구분(MM015). **FMM #121 DEV_TYPE과 conform** → #1~3 목표대비개발율 비교축 |

#### 2-D.2 측정값 (1, 비지표번호 base)
| 컬럼(지표) | # | basis | 단위 | 가산성 |
|---|---|---|---|---|
| 회원개발목표수 GOAL_CNT | (없음, #1~3 분모) | 직접입력 | 건 | A |

> `GOAL_CNT`는 60 지표 인벤토리에 없는 base measure(파생 #1~3 분모). 월 grain → 월·조직·개발구분 SUM 가능, 연 누계는 월 SUM(가산 A). #1~3은 4단계에서 FMM 개발건 ÷ FTG-D `GOAL_CNT`를 (MONTH_KEY·ORG·DEV_TYPE) conformed 조인으로 SV metric화.

### 2-B. FACT_TARGET_BIZ (FTG-B) — ERP/사업계획 사업목표 ⚠️미수령·적재예약

- **grain**: **1행 = (조회년월 × 조직 × 후원사업)**. ⚠️ 캠페인 단위 목표 존재 시 (×캠페인)으로 확장 — 6절 Q2.
- **PK**: (MONTH_KEY, ORG_SK, SPONSORSHIP_SK) [+CAMPAIGN_SK]. 월 grain → **MONTH_KEY**(결정 7).
- **소스**: ⚠️ 미수령(ERP vs 사업계획 시트) — 6절 Q5. CRM goal 테이블엔 후원사업·연사업/추경 축 없음 → 이 팩트는 ERP 입고 후 적재.

#### 2-B.1 DIM FK
| FK | → DIM | 필수 | 비고 |
|---|---|---|---|
| MONTH_KEY | (DIM_DATE 월롤업) | ✓ | YYYYMM. DATE_SK 미사용(결정 7) |
| ORG_SK | DIM_ORG | ✓ | **직접 참조**(목표만, 원칙 G) |
| SPONSORSHIP_SK | DIM_SPONSORSHIP | ✓ | |
| CAMPAIGN_SK | DIM_CAMPAIGN | NULL허용(?) | 캠페인별 목표 수립 시(Q2) |

#### 2-B.2 측정값 (4)
| 컬럼(지표) | # | basis | 단위 | 가산성 |
|---|---|---|---|---|
| 연사업목표(건) | 152 | 직접입력 | 건 | A |
| 추경목표(건) | 153 | 직접입력 | 건 | A |
| 연사업누계목표(건) | 154 | 직접입력(누계) | 건 | N |
| 추경누계목표(건) | 155 | 직접입력(누계) | 건 | N |

> 목표 vs 실적(FMM) 비교는 4단계 SV metric화: #1~3(목표대비개발율)=FMM×**FTG-D**(MONTH_KEY·ORG·DEV_TYPE conform). #152~155 연사업/추경 목표대비는 ERP 수령 후 FMM×**FTG-B**(MONTH_KEY·ORG·SPONSORSHIP conform). **두 목표 팩트 모두 회원 grain 아님 → FMM과 직접 합산 금지**, 공통 차원에서만 정렬.

> **🆕 2026-06-24 정의서 반영 (FTG)** — 정본 `GOLD_정의서_업데이트 20260624.md`.
> - **집행예산 2종(H4)**: 마케팅§2에서 편성예산(월/연/누계)=ERP, 집행예산은 `ERP 마감값`(확정) vs `대행사 추정치` 2종 → FTG-B 또는 FAD reserved에 `집행예산_확정(ERP)`·`집행예산_추정(AGENCY)` 분리.
> - **목표 grain(M1)**: 마케팅§1 "부서별 목표만 존재, 매체별 목표 부재" → FTG-D/FTG-B grain=조직(부서) 확정. **매체별 효율은 부서목표 배분 불가**. `부서명` 원천 `(미정)`(CRM 추정), 목표 입력원=별도 시트(ERP/RPA, 미확정) → Q5와 함께 확인.


---

## 3. FACT_SERVICE_EVENT (FSE) — 발송/참여 이벤트

- **grain**: **1행 = (발송일 × 회원 × 서비스 × 캠페인)** 발송 이벤트 1건. +5일차 참여/중단은 같은 발송행에 귀속(attribution).
- **PK**: 대리 이벤트키(EVENT_ID) 또는 (DATE_SK[일], MEMBER_DK, SERVICE_SK, CAMPAIGN_SK).
- **소스**: CRM 발송/참여.

### 3.1 DIM FK
| FK | → DIM | 필수 | 비고 |
|---|---|---|---|
| DATE_SK | DIM_DATE(일) | ✓ | 발송일(#137) |
| MEMBER_DK | DIM_MEMBER | ✓ | |
| SERVICE_SK | DIM_SERVICE | ✓ | 발송/참여 subtype(H) |
| CAMPAIGN_SK | DIM_CAMPAIGN | ✓ | ORG 경유 |
| SPONSORSHIP_SK | DIM_SPONSORSHIP | NULL허용 | |

### 3.2 측정값 (17)
| 컬럼(지표) | # | basis | 단위 | 가산성 |
|---|---|---|---|---|
| 발송수(명) | 85 | COUNT(중복포함) | 명 | A |
| 성공수(명) | 86 | COUNT(중복포함) | 명 | A |
| 실패수(명) | 87 | COUNT(중복포함) | 명 | A |
| 서신참여(명) | 88 | COUNT(중복포함) | 명 | A |
| 서신참여(건) | 89 | SUM/10000 | 건 | A |
| 선물금참여(명) | 90 | COUNT(중복포함) | 명 | A |
| 선물금참여(원) | 91 | SUM | 원 | A |
| 발송(+5일차) 서신참여(명) | 139 | COUNT(중복포함) | 명 | A |
| 발송(+5일차) 서신참여(건) | 140 | SUM/10000 | 건 | A |
| 발송(+5일차) 선물금참여(명) | 141 | COUNT(중복포함) | 명 | A |
| 발송(+5일차) 선물금참여(건) | 142 | SUM/10000 | 건 | A |
| 발송(+5일차) 증액참여(명) | 143 | COUNT(중복포함) | 명 | A |
| 발송(+5일차) 증액참여(건) | 144 | SUM/10000 | 건 | A |
| 발송(+5일차) 중단(명) | 145 | COUNT(중복포함) | 명 | A |
| 발송(+5일차) 중단(건) | 146 | SUM/10000 | 건 | A |
| 서비스(명) | 160 | COUNT | 명 | A |
| 서비스(건) | 161 | SUM(금액)/10000 | 건 | A |

> **(중복포함) COUNT 주의**: 회원 distinct 아님 → distinct 회원수가 필요한 율(신규#36 참여회원유지율 등)은 4단계에서 COUNT(DISTINCT MEMBER_DK) 별도 정의.

### 3.3 degenerate 속성 (2)
| 컬럼(지표) | # | 비고 |
|---|---|---|
| 제목(발송) | 136 | 자유텍스트, 차원화 가치 낮음 |
| 발송상태 | 138 | 발송/성공/실패 상태 코드 |

> **🆕 2026-06-24 정의서 반영 (FSE)** — 정본 `GOLD_정의서_업데이트 20260624.md`. measure 17 인벤토리 불변, 아래는 소스/grain 확장 검토.
> - **ADMIN 신규원천(H2)**: 앱 푸시 `발송건수·성공건수`(어드민>모바일앱>푸시발송), 이벤트목록 `조회수`(어드민) → FSE에 `SEND_CHANNEL='APP_PUSH'`/`_SOURCE_SYSTEM='ADMIN'` 채널 편입. CRM(UMS) 발송과 채널 구분.
> - **문화이벤트(오프라인) 참여(M3)**: 행사 모집/신청확정/참여/불참/대기/취소 인원·당첨여부(회원§3-6)는 현 발송·온라인참여 grain 밖 → FSE 참여 grain 확장 또는 `CRM_PARTICIPATION_HIST` 행사유형 추가. 신36·38·40·42 "참여 정의 서비스별 상이"(4.1 합의)와 연계.
> - 적재: ADMIN 미수령 → S-6. CRM 오프라인 행사분은 SILVER `13_CRM_PARTICIPATION_HIST` 범위.


---

## 4. FACT_GA_BEHAVIOR (FGA) — GA4 행동

- **grain**: **1행 = (일자 × ga_member_id × GA이벤트 × 세션소스 × 페이지)** GA 행동 집계.
- **PK**: (DATE_SK[일], IDENTITY_SK, GA_EVENT_SK, GA_SOURCE_SK, 페이지경로).
- **소스**: GA4. 회원 해소는 IDENTITY_SK→MEMBER_DK(브리지, 1:N).
- ⚠️ **grain 충돌 경고**: #93·94(고유 사용자수)·#97(세션수)는 **GA4가 상위 범위에서 사전집계한 distinct 값**이라 이 세밀 grain에서 재계산·재합산 불가(N). 두 가지 방어 중 택1 — (a) FGA를 이벤트 grain으로 두고 사용자/세션 distinct는 **별도 coarse 팩트/뷰**로 분리, (b) FGA grain을 GA4 export grain에 일치시키고 세밀속성은 NULL 허용. 5단계에서 GA4 export 스키마 확인 후 확정(6절 Q9).

### 4.1 DIM FK
| FK | → DIM | 필수 | 비고 |
|---|---|---|---|
| DATE_SK | DIM_DATE(일) | ✓ | |
| IDENTITY_SK | DIM_MEMBER_IDENTITY | ✓ | ga_member_id→MEMBER_DK 해소 |
| GA_EVENT_SK | DIM_GA_EVENT | ✓ | category/label/action |
| GA_SOURCE_SK | DIM_GA_SOURCE | ✓ | utm 소스/콘텐츠/검색어 |
| CAMPAIGN_SK | DIM_CAMPAIGN | NULL허용 | 세션캠페인(#102) 정합 매핑 필요 |

### 4.2 측정값 (7)
| 컬럼(지표) | # | basis | 단위 | 가산성 |
|---|---|---|---|---|
| 방문수(명) | 92 | SUM | 명 | A |
| 활성사용자수(명) | 93 | SUM(고유) | 명 | N |
| 총사용자(명) | 94 | SUM(고유) | 명 | N |
| 이벤트수(명) | 95 | SUM | 명 | A |
| 조회수(명) | 96 | SUM | 명 | A |
| 세션수(명) | 97 | SUM | 명 | A |
| 스크롤깊이 | 107 | AVG | 횟수 | N |

> ⚠️ **사용자수(93·94)는 GA4 고유사용자 추정치** → 차원 across SUM 시 중복합산 오류(N). 사전집계 grain 외 재집계 금지.
> ⚠️ #107 스크롤깊이 단위/집계(평균 %인지 횟수인지) 미확정 — D#1·6절 Q4.

### 4.3 degenerate 속성 (2)
| 컬럼(지표) | # | 비고 |
|---|---|---|
| 페이지경로+쿼리문자열 | 105 | 고카디널리티 → 차원화 대신 팩트 attr |
| 페이지위치 | 106 | URL, 결연아동코드(#122) 파싱 원천 |

---

## 5. FACT_AD_PERFORMANCE (FAD) — 광고 성과

- **grain**: **1행 = (일자 × 캠페인 × 광고소재/매체)**.
- **PK**: (DATE_SK[일], CAMPAIGN_SK, AD_CREATIVE_SK).
- **소스**: GA 광고(#6) + AGENCY(#23~25) + **GADS(Google Ads)**(2026-06-24: 광고비·노출·클릭 복수원천).

### 5.1 DIM FK
| FK | → DIM | 필수 | 비고 |
|---|---|---|---|
| DATE_SK | DIM_DATE(일/월) | ✓ | |
| CAMPAIGN_SK | DIM_CAMPAIGN | ✓ | ORG 경유 |
| AD_CREATIVE_SK | DIM_AD_CREATIVE | **NULL허용** | AGENCY 행만 소재 보유. ⚠️ #6 GA광고비는 소재 단위 없음(캠페인 grain) → 강제 시 행 손실, NULL 허용으로 방어 |
| SOURCE_SYSTEM | (degenerate) | ✓ | GA/AGENCY/**GADS** 출처 구분(D#6, 2026-06-24 GADS 추가). 소스 혼합 grain 방어 |

### 5.2 측정값 (4)
| 컬럼(지표) | # | basis | 단위 | 가산성 |
|---|---|---|---|---|
| GA 광고비 | 6 | SUM | 원 | A |
| 노출수 | 23 | SUM | 횟수 | A |
| 클릭수 | 24 | SUM | 횟수 | A |
| 인입콜 | 25 | SUM | 횟수 | A |

> 🚫 **부재 raw measure**: ERP 모금성비용·AGENCY 편성비가 지표문서에 없음 → 개발단가(신규#9·10)·ROI(신규#11) 산출 불가. FAD에 `편성비(원)`·`모금성비용(원)` 컬럼을 **예약(미적재)** 으로 두고 BRONZE 컨트랙트 요청(D#3).
> ⚠️ 노출·클릭 GA(#9·10 산출) vs AGENCY(#23·24) 이원화 — 출처 구분 컬럼(SOURCE_SYSTEM) 필요(D#6).

> **🆕 2026-06-24 정의서 반영 (FAD)** — 정본 `GOLD_정의서_업데이트 20260624.md`. measure 60 인벤토리는 불변, 아래는 예약/degenerate 확장.
> - **GADS(H1)**: 광고비·노출·클릭이 AGENCY+GADS 복수원천 → SOURCE_SYSTEM enum에 `GADS` 포함, 행별 출처 구분 UNION.
> - **GA 전환수 명/건(H3)**: `전환_명`·`전환_건` 2종 예약(원천 AGENCY+GA4). 공10 GA CVR 분자 = 전환수(단위는 분모 클릭과 합의 — OPEN).
> - **집행예산 2종(H4)**: `집행예산_확정(ERP마감)`·`집행예산_추정(AGENCY)` + 편성예산(월/연/누계) 예약. (FTG-B와 역할 분담: 목표=FTG-B, 비용/집행=FAD reserved.)
> - **광고 시간차원(M4)**: degenerate `요일·주차·시간대·광고시작시간·CM위치·RT유형` 추가 후보. **송출일(BROADCAST_DATE)≠실적일(PERF_DATE)** 2일자 분리 검토(DRTV 심야/주말/휴일).
> - **인입콜 외 콜(M2)**: 인입콜(#25, AGENCY)은 본 표 유지. **인바운드콜수·TS콜수는 CRM** → FMM 보조 measure(아래 1절 델타).
> - 전부 미수령(AGENCY/GADS/GA4) → 적재는 S-6, 현재는 예약 컬럼만.


---

## 6. 미해결 / 현업 확인 (grain 영향 항목)

> 아래는 **grain 확장 여부**에 직접 영향. 현재는 가장 보수적(좁은) grain + 확장키 NULL허용으로 방어, 답이 확장이면 PK에 키 추가만으로 무손상.

| Q | 항목 | 현재 방어 | 확장 시 영향 |
|---|---|---|---|
| Q1 | FMM: 동월 회원당 복수 캠페인/사업 가능? | grain=(월×회원), 캠페인/사업=결정FK | (월×회원×캠페인×사업)으로 PK 확장 |
| Q2 | FTG-B: 캠페인 단위 목표 수립? | CAMPAIGN_SK NULL허용 | grain에 CAMPAIGN 추가 (ERP 수령 후) |
| Q3 | FSE: 발송 grain이 회원당 1행 vs 사전집계? | (발송일×회원×서비스×캠페인) | 사전집계면 명 measure가 1 아닌 N |
| Q4 | #107 스크롤깊이 단위(%/횟수)·집계(AVG) | 비가산 N로 표시 | 단위 확정 시 basis 갱신 |
| Q5 | FTG-B 소스(ERP vs 사업계획 시트) | ⚠️ 미수령·적재예약 | ERP 입고 후 SILVER 매핑·#152~155 활성 (FTG-D는 CRM 확정·해소) |
| Q6 | FAD 비용 raw(편성비·모금성비용) | 컬럼 예약(미적재) | BRONZE 입고 후 단가/ROI 활성 |
| Q7 | FMM #5 GA개발의 출처 경로(GA4 직접 vs CRM 채널코드) | CRM 실적·채널 컬럼분리로 가정, MEMBER_DK 보유 | GA4 직접이면 SILVER에서 identity 브리지로 회원 해소 |
| Q8 | FMM 동월 미납·중단 사유 동시 발생? | REASON_SK 단일·NULL허용 | 동시 발생이면 사유는 이벤트 팩트로 분리 |
| Q9 | FGA 사용자/세션 distinct의 저장 grain | 이벤트 grain + distinct 분리/뷰 | GA4 export grain 확인 후 (a)/(b) 확정 |

---

## 7. 정합성 점검 (3단계 자체검증)

| 검증 | 결과 |
|---|---|
| 지표 measure 60 전수 배속(중복0·누락0) | FMM28+FSE17+FGA7+FTG-B4+FAD4 = **60** ✓ (+ FTG-D GOAL_CNT 1 비번호 base = 물리 61) |
| degenerate/스냅샷(dim 유형·팩트 저장) | FMM13+FSE2+FGA2 = 17 → dimension(74) 불변 ✓ (FTG-D DEV_TYPE은 FMM #121 conform degenerate, 신규 dim 아님) |
| 회원식별 = MEMBER_DK only(원칙 B) | FMM·FSE=MEMBER_DK, FGA=IDENTITY_SK 경유 ✓ |
| ORG 귀속(원칙 G) | FTG-D·FTG-B만 직접, FMM·FSE·FAD는 CAMPAIGN 경유 ✓ |
| 13절 매트릭스 대조 | FMM/FTG-D/FTG-B/FSE/FGA/FAD FK 일치 ✓ |
| 가산성 분류(누계·시점값·고유수) | N/S 표기로 SV 재집계 오류 예방 ✓ |
| 시간 grain 분리(결정 7) | 월 팩트(FMM·FTG-D·FTG-B)=MONTH_KEY, 일 팩트=DATE_SK → 혼재 차단 ✓ |
| 분류축 이중계산 방지(결정 8) | FMM 회비유형=컬럼, PAYMENT_SK=납입방식 only ✓ |
| 소스 혼합 grain 방어 | FMM #4/#5 채널 컬럼분리(둘 다 MEMBER_DK), FAD AD_CREATIVE_SK NULL허용+SOURCE_SYSTEM, **목표 CRM/ERP 2팩트 분리(결정 9)** ✓ |

---

## 8. 다음 단계 입력

- **4단계(파생→base 매핑)**: 본 문서 measure 60 + 가산성 표기를 분자/분모 후보로 사용. 충돌 점검 대상 = #69↔70, 신규20↔#35+38, COUNT(중복) vs DISTINCT.
- **5단계(DDL 초안)**: 본 문서 7개 표(FK·measure·degenerate)를 컬럼·타입·PK/FK로 직역. FAD 비용 컬럼은 예약(주석).
