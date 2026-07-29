<!-- LLM-METADATA
doc_id: ISSUE_INDEX
doc_role: 이슈 원장 허브 (접수·분류) — 문서맵 + 전체 크로스워크 + 상태 대시보드
project: GN_DW (굿네이버스)
created: 2026-07-15
supersedes: 20_issue/00_통합이슈_레지스트리_20260715.md (단일문서 → 업무단계별 분할)
END-METADATA -->

# GN_DW 이슈 원장 — INDEX (접수·분류 허브)

> 파이프라인 오류·의심 원인 이슈를 **업무프로세스 단계별 문서**로 분할 관리합니다.
> 본 문서는 **진입점**입니다: 모든 이슈 ID를 여기서 찾고, "현 단계" 열을 따라 상세 문서로 이동하세요.

> 🔄 **[2026-07-20 최신 정정]** **E-6 / FTG-B(사업목표) 원천 = CRM 확정** (기존 "ERP" 표기 폐기). 근거: 정본 인벤토리(마케팅 §1 "CRM에 부서별 목표만 존재")·현업 확언. 단위 = **건(#152~155, 지표사전 기준)** 확정. 예산·집행(FBD)·모금성비용·연결키 관련 ERP 표기는 그대로 유효(사업목표만 CRM). ✅ **파일명·SILVER 테이블·dbt 모델 모두 `CRM_BIZ_TARGET`로 리네임 완료**(`models/silver/crm/CRM_BIZ_TARGET.sql`·`SILVER.CRM_BIZ_TARGET` 0행 실재).

## 이슈해결 업무프로세스 & 문서맵
```
[접수·분류] → [진단] → ┬ [현업확인] ┐
   00          10       ├ [설계결정]  ┼→ [실행] → [완료]
                        └ [입고대기]  ┘    50        90
                          20 / 30 / 40
```
| # | 문서 | 업무단계 | 다루는 것 |
|---|---|---|---|
| **00** | `00_INDEX_이슈원장.md` (본 문서) | 접수·분류 | 문서맵·전체 크로스워크·상태 대시보드 |
| 10 | `10_진단_원인분석.md` | 진단 | SILVER 진단패턴·핵심교훈·설계노트·트랙 착수게이트 |
| 20 | `20_현업확인_요청.md` | 현업 확인 | GOLD 지표정의 잔여 + dbt 의심데이터 A~E 판정요청 |
| 30 | `30_설계_의사결정.md` | 내부 의사결정 | D1~D3·#80·우리끼리 잠정확정·결정대기 GOLD 6 |
| 40 | `40_입고대기_원천의존.md` | 입고 대기 | 외부원천 하드블로커·데이터 기간요건 |
| 41 | `41_입고요청서_CRM_BIZ_TARGET.md` (+`_BRONZE_DDL.sql`) | 입고 대기 | E-6 **CRM** 사업목표 정식 입고요청서·BRONZE DDL 제안 (원천 CRM 정정 2026-07-20·리네임 완료) |
| 50 | `50_dbt_파이프라인_미결조치.md` | 실행 | BLOCKING-1/2/3/4·순서9-C severity정책·DONE 로그 |
| 90 | `90_해소완료_로그.md` | 완료 | 닫힌 항목·해소 Q이슈 |

### 상태 범례
🟢 해소완료 · 🔵 비블로커 · 🟠 설계결정 블로커 · 🔴 하드블로커(외부) · 🔄 우리끼리 잠정(현업위임·게이트) · 🛠️ 설계흡수 · ❌ 제외 · ⚠️ 재검토 예정

---

## 1. 상태 대시보드 (한눈에)
| 현황 | 건수 | 대표 항목 | 관할 문서 |
|---|---|---|---|
| 🔴 하드블로커(외부) | 4 | **G-5** GA4 전기간 입고 · **E-6** FTG-B 원천(CRM) · **E-1** 모금성비용 원천 · **Q10** 캠페인 연결키 | 40 · 20 |
| 🔴 적재 블로커(내부) | 1 | **BLOCKING-5** GOLD 팩트 measure·차원FK 대규모 미적재(2026-07-21 SV착수 실측) — 🟡 **A1(FMM DEV/STOP+HAS_BILLING)·A3(FSE SERVICE_SK) 부분해소 진행중** | 50 |
| 🔴 값미주입(내부) | 76 → **71**(AGENCY 5건 제거) | **[신규 2026-07-28]** GOLD 하드코딩 `0`/`CAST(NULL)` — 설계O·값 미주입. AGENCY 배선 완료(2026-07-28): DEVICE_SK 실배선 + 방송 degen 위성 이관. 잔여 71건은 CRM·기타 모델(FACT_MEMBER_MONTHLY 38 등). **[순서9-II 보정]** BRONZE 감사 ⚠️ 9→1건(8건 판정 성공 · 잔여 1건=DGT.DEVICE→DEVICE_SK **감사도구 오탐** — COALESCE fallback 오감지, 실결함 아님). ⚠️ 종전 "76→67" 기술은 76−9 단순감산 오류 — 위성 이관분은 컬럼 소멸이라 하드코딩 카운트에서 잡히지 않음 | 10 §8-I |
| 🔴 의미혼입(내부) | 2 → ✅ 코드해소 | **O16 [신규 2026-07-28]** REBRDC 개발실적이 `GA_CONV_MEMBERS`·`GA_CONV_CNT` 로 노출 — UNION 위치매핑 + `GA_` 개명. 실측 오염 **28.60% · 60.32%(과반)**. DEC-8 위성 분리로 해소 | 10 §8-I(8) |
| 🟠 설계결정 블로커 | ~~3+~~→ 감소 | ~~A-2/Q9~~ ✅해소(순9-C) · O2 APP분기 ✅데이터확정(PC/M·APP휴면) · AGENCY 6종 부분해소 | 30 |
| 🔄 우리끼리 잠정(게이트 有) | 6 | A-7/O5 · A-8 · O6 · #81 · O8 · O10 | 20 · 30 |
| 🔵 비블로커 | 10 → **12** | #80 · ID-활성 · Q1·Q2·Q3·Q8 · **SVL-1~4**(SV 코드→라벨 매핑 확인) · **AD-2**(CRM_DEV_CNT 소수값 어의) · **AD-4 잔여**(타 SV 코드차원 comment 전수점검) | 30 · 20 · 10 §9 |
| 🔴 워크스페이스 운영 | **1** | **[신규 2026-07-29]** **OPS-1** 루트 `SECURITY.sql` 에 GitHub PAT 평문 기록됨(현재 플레이스홀더 교체·버전이력 잔존 가능) → **토큰 revoke + 재발급 필요**. 부수 **OPS-2**(`USER$<user>` DB SECRET 은 역할로 ALTER 불가 → UI 또는 일반 DB SECRET 사용) | 00 §순서9-L 부수 |
| 🟠 소비계층 미결(내부) | **3** | **[신규 2026-07-29]** ① **PRV-1** provenance 평가 공백 — 원천 질문은 SQL 미생성이라 gold-SQL 채점 불가 → `07` 가드레일 ⓖ 신규 클래스 필요 · ② **PRV-2** 컬럼단위 출처 요청 대응 — `04_컬럼계보매핑.md` Cortex Search 색인 → Agent tool(현업 반복질문 시 착수, 🔜 트리거 대기) · ③ **PRV-3 [순서9-L]** 기간 기본창 규칙이 실제 생성 SQL에 반영되는지 **NL 스모크 미검증**(트라이얼 `DATA_AGENT_RUN` 차단 → paid 게이트) | 10 §10-B·§10-E·§11-H |
| 🛠️ 설계흡수 | 1 | SF-biz(익명 미귀속) | 30 |
| ❌ 제외 | 3 | A-5·A-6·A-10(어드민분) | 90 |
| 🟢 해소완료 | 다수 | D1·D3·DEC-* · 지표정의 다수 · Q4~Q7·Q11~Q16 · 닫힌항목 7 | 90 |

> **핵심**: 외부 의존 하드블로커는 **GA4 전기간 입고 · CRM FTG-B 사업목표 원천 · ERP 모금성비용 원천 · (ERP/AGENCY) 연결키·이름 현업확인** 4건뿐. 그 외 잔여는 내부 설계·실행으로 해소 가능.
> **dbt 배포 상태 [2026-07-15 배포 · 2026-07-16 갱신 · 2026-07-20 실측 · 2026-07-21 계정이전·A1/A3]**: ~~구 계정: `GN_DW.OPS.DW_PIPELINE`(VERSION$6 default)~~ → **신 계정(cs94293): `GN_DW.OPS.DW_PIPELINE`으로 최초 재생성 필요** (정본 위치=OPS 운영스키마, `10_dbt_pipeline/deploy_dbt_project.sql` 참조). 워크스페이스 dbt build는 정상 확인(SILVER 32 + GOLD 33 = 65 models green). **[2026-07-20 실측] `GN_DW.GOLD` 24테이블 + WIDE VIEW 9개·`GN_DW.SILVER` 32테이블 배포·적재 완료**(FACT_TARGET_BIZ만 0행). 순서9-C 코드버그 8 수정 + 참조무결성 9 `severity:warn` 강등(메달리온 BP). ⚠️ **[2026-07-21 A1] FMM에 `HAS_BILLING` 컬럼 추가·행수 37.79M→40.05M** → build 전 `03_top-down_gold/06_DDL.sql` 재실행 필요. 상세 §50.
> **잔여 배포 이슈**: BLOCKING-3(해소) · **BLOCKING-4 🟢 9/9 배포완료**(WIDE view 9종 dbt view·[2026-07-16] WIDE_TARGET_BIZ + FACT_TARGET_BIZ 스켈레톤 저작·build green PASS=2) · GOLD DDL 24 전량 dbt 모델화(FACT_TARGET_BIZ 는 E-6 CRM 원천 미입고로 0행 스켈레톤). · **🔴→🟡 BLOCKING-5 [2026-07-21 신규·부분해소중]** GOLD 팩트 measure·차원FK 대규모 미적재(FMM 카운트·FK 전건0·FSE SUCCESS/D5 전건0 등) — SV/Agent 착수 실측 발견. 🟡 **A1(FMM DEV/STOP+HAS_BILLING)·A3(FSE SERVICE_SK+SEND_TITLE) 구현·시뮬검증 완료**(build 대기), 잔여 B계열(코드매핑·O8 규칙)·외부입고 원인규명 필요(§50).
> **▶ 진행 현황 [순서9-D]**: WIDE VIEW 9종 dbt view화·배포(BLOCKING-4 해소) + `AGENCY_AD_PERFORMANCE.AD_DATE` not_null warn→error 승격(실측 널 0). **[2026-07-16] FACT_TARGET_BIZ+WIDE_TARGET_BIZ 스켈레톤 저작**(0행 통과) — 단, 비판적 검토서 **단위충돌(SILVER 금액 TARGET_AMT vs GOLD 건 #152~155)·조인키 교정(이름기반)** 발견·처리(측정치 NULL·이름조인). **내부(bronze·설계로직) 가능작업 소진.** 잔여 = 외부의존(E-1/E-4/E-6/G-5/BLOCKING-1) · 현업(Q10/O5) · 설계결정(FACT_BUDGET 추경/조정 슬롯=문서30 §7, **FACT_TARGET_BIZ 단위=건 확정(2026-07-20 정정) → 현업이 건 목표 원천 제공 시 채움; Bronze DDL 단위 건 정합 필요**). **총괄표**: `10_dbt_pipeline/00_배포운영_통합_20260715.md` §7 · 착수 프롬프트: `10_dbt_pipeline/90_NEXT_SESSION_순서9-D_20260715.md`.
> **▶ SERVING(SV/Agent) [순서9-E 2026-07-22]**: `GN_DW.SERVING`에 **Semantic View 5 배포·검증**(SV=FACT 일치·fan-out 0) + **Cortex Agent 2 배포·CoWork 연결**(AGENT_MEMBER·AGENT_OVERALL, owner=GN_DW_ADMIN, SI object ADD AGENT·소비 3역할 USAGE). 신규 진단·교훈 = **문서10 §6**: (6-A) FME/FSE/FEP grain 비유일→PK 미선언 · (6-B) 납부율 무필터 100.36% 왜곡→기간스코프 강제(신규 P10) · (6-C) 🔴 **트라이얼 DATA_AGENT_RUN 차단→NL 스모크 paid 게이트** · (6-D) cortex_agent_save 소유권 보정 · (6-E) BLOCKING-5 활성/비활성 경계 확정. 정본 = `05_SV-Agent_ai/`(00 README·08 spec·09 구현·10 검증·11 거버넌스).
> **▶ SV 코드→라벨화 [순서9-F 2026-07-23]**: 회원 SV 4종·행사 SV의 코드성 차원을 한글 라벨로 비정규화(GOLD `DIM_MEMBER`.MEMBER_TYPE_NAME/STATUS_NAME/STATUS_GROUP/GENDER_NAME/ENROLL_PATH_NAME · `DIM_EVENT`.EVENT_KIND_NAME → SERVING `DIM_MEMBER_CURRENT` → SV `*_NAME` 차원·Agent 2종 지침 VERSION$3). 원천=SILVER `CRM_CODE`(MM018/MM010/MM014) 빌드시점 조인·복제 없음. 코드그룹 불명확분 = **SVL-1~4**(문서20 §D) 현업 회신 대기.
> **▶ SV/Agent 고도화 [순서9-G 2026-07-23]**: (1) 🟢 기본 기간스코프를 **SV `AI_SQL_GENERATION`**으로 이전 — Agent 프롬프트 규칙이 생성 SQL에 미반영되던 문제(기간 미지정 시 전기간 스캔) 해소. **AI/DB 전문가 검토 반영 최종안(VERSION$7)**: 기간·그룹 **모두** 없을 때만 발동 → **`GROUP BY ROLLUP((연,월))`로 총계+최근12개월 월별 동시 반환**(비율도 총계 정확), Agent는 총계요약→월별→되묻기, **"합계만" 요청 시 단일값**, 기준월은 **데이터 MAX(연월)**(CURRENT_DATE 아님 — FMM 2029·FBD 2026-12 미래데이터 누락 방지). `cortex analyst query` CLI로 생성SQL 검증. (2) PoC 지표 이식 **미납비중·총미납금액·평균납입회비**. (3) Agent 답변 **한글 명칭 표기**. (4) 재배포 ops: SV=`CREATE OR ALTER`(GRANT 보존)·Agent=`ADD LIVE VERSION FROM LAST`→MODIFY→COMMIT(**VERSION$7**). 신규 교훈 **P11(생성SQL 제어는 SV 계층)** = 문서10 §7(§7-F=Data Mart Phase-2 백로그·VQR 결정론 관찰, **§7-G=Agent instruction 55% 컴팩트·VERSION$8** — SQL메커니즘은 SV 소유라 Agent 프롬프트서 삭제, 라우팅·구성·가드레일만 잔류). 정본=`05_SV-Agent_ai/05_SV_DDL.sql·09_AGENT_spec_구현.sql`.
> **▶ BRONZE 전 원천 노출감사 + AGENCY 광고 팩트군 재설계 [순서9-I 2026-07-28]**: 요구("보여줄 수 있는 BRONZE 데이터는 다 보여준다 + 출처 명시")에 대해 **BRONZE 1,121컬럼 전면 감사** 실시 — `30_output_share/06_BRONZE노출감사.{md,csv,xlsx}`(생성기 `scripts/gen_bronze_exposure_audit.py` + 러너 `scripts/run_bronze_audit_host.py`). 판정(순서9-II 보정 후 확정): **노출됨(GOLD) 70 · 대체노출(파생) 14 · ⚠️설계O·값미주입 1 · SILVER까지만 359 · 판정보류 14 · 미노출 612 · 제외 51**. 🔴 **신규 결함군 "GOLD 설계O·값 미주입" 76건**(모델×컬럼) 발견 — DDL·문서엔 컬럼이 있으나 SQL이 `0 as X_SK`/`CAST(NULL)` 하드코딩 → **커버리지 점검을 통과하면서 전건 NULL**. 해소 난이도 최저(DDL 무변경·SELECT 배선만) → **최우선 조치군**. AGENCY 9건은 전량 BRONZE 실존 확인 → dbt 주석 "원천 부재"는 오류(**P14 위반 4~10번째 사례**, 8-H의 "3번째"는 과소평가였음). 🔴→🟢 **감사 도구 자체 오탐 교정**: 전역 이름매칭이 `AGENCY.DEVICE`(실제 하드코딩)를 '노출됨'으로, `GA4.device`(실제 정상)를 '하드코딩'으로 오판 → 계보 매핑을 **(원천테이블×컬럼)→(GOLD컬럼×모델)** 로 양측 스코프 축소 + 일반명 `판정보류(동명이의)` 격리. 노출됨 153→**18**. 신규 교훈 **P15**("설계 완료 ≠ 값 존재"·하드코딩 정적스캔 정례화)·**P16**(감사 오탐은 미탐보다 위험 — 결손 은폐). 설계 확정 **DEC-8~11**: 위성 팩트 3종(FAD_B·FAD_D·FAD_BC) · 대행사 파생 `_SRC` 8종 전량 보존 · `DIM_DEVICE` `(해당없음)` 멤버 · `AD_PERF_DK` 행식별자. 상세 = 문서10 §8-I · `03_테이블 설계.md §3-A`. ✅ **dbt 모델 구현·build 완료(2026-07-28)** — `PASS=258 WARN=21 ERROR=0`(WARN 21은 전부 기존 CRM 고아관계, 신설분 0). 산출 20종(SILVER 모델 7·GOLD 팩트/차원 5·**GOLD WIDE 4**·schema.yml 3·DDL 2). 실측: 코어 235,572행 `AD_PERF_DK` 전건 유일 · 위성 197,686/37,886/5,327 · **`DEVICE_SK` unknown 0건(지표 공14 해소)** · **O16 해소 확정**(코어 GA_CONV_MEMBERS 122,551·GA_CONV_CNT 63,372.9 = 디지털 전용 / FAD_B DVLP 49,093·96,321). 추가 정리: `AD_TYPE`→**`AD_SOURCE_TYPE`** 개명(`DIM_AD_CREATIVE.AD_TYPE` 충돌 해소) · `DVLP_MEMBER_CNT` 정밀도 교정. 🔴 **본 세션 자체 결함 2건**(컬럼 이관 시 WIDE 참조처 누락 · 개명 일괄치환이 동명 타컬럼 오염) → 신규 교훈 **P17**. 상세 문서10 §8-I(10)(11). 🔴 **추가 발견 O16(의미혼입)**: SILVER UNION 이 REBRDC `DVLP_MBER_CNT`·`DVLP_CNT` 를 DIGITAL 의 GA 지표 자리에 위치매핑하고 GOLD 가 `GA_CONV_MEMBERS`·`GA_CONV_CNT` 로 개명 노출 → **재방송 개발실적이 'GA 전환'으로 혼입**. 실측(2026-07-28): `GA_CONV_MEMBERS` 의 **28.60%**(49,093/171,645) · `GA_CONV_CNT` 의 **60.32%**(96,321/159,693.9, **과반**)가 REBRDC. 계보 추적은 개명을 정확히 잡았으나 **개명의 타당성은 판정 범위 밖** → 위성 분리(FAD_B 별도 컬럼)로 해소. 상세 문서10 §8-I(8). 🛠️ **감사 러너 결함 4종 교정**(세션캐시 의존 제거→INFORMATION_SCHEMA 직접조회로 **재현성 확보** · alias 정규식 미탐/오탐 · P15 자기모순 신뢰도) → 재실행 결과 **판정·건수 전건 동일**(비고 문구 5건만 정밀화). 별건으로 **문서 전사 오류 6곳 교정**(AGENCY `노출 4·SILVER 24·미노출 57` → 실측 **`11·15·52`** · CRM `SILVER 154`→**275**). 상세 문서10 §8-I(9).

> **▶ AGENCY 팩트군 후속 정비 [순서9-II 2026-07-28]**: (1) GOLD 스키마 COMMENT 갱신(GOLD VIEW 12·TABLE 27, SILVER 38), (2) WIDE VIEW 12종 411컬럼 COMMENT 100% 커버 + fan-out 0 검증 통과, (3) `05_필드 인벤토리.md` FAD 위성 4종 추가·AD_SOURCE_TYPE 표기 전수 반영, (4) **BRONZE 감사 러너 LINEAGE_MAP 키 9건 보정**(VIDEO 5·REBRDC 1·DGT 3 — BRONZE 실측 대조 확정) → 재실행 결과 판정분포 대폭 개선(노출됨 18→**70**, ⚠️9→**1**, 미노출 664→**612**), (5) SV/Agent 영향 점검 → 연결 없음 확정. `30_output_share/06_BRONZE노출감사.{md,csv,xlsx}` 재생성 완료. 정본 = `10_WIDE VIEW 코멘트.sql`·`scripts/run_bronze_audit_host.py`.
> ⚠️ **[순서9-J 정정]** 위 (5) "SV/Agent 영향 = 연결 없음"은 **오판**이었다 — 광고 measure·축이 실적재되어 SV_AD Phase-1 승격이 가능했다. 아래 순서9-J 참조.

> **▶ SV_AD 신설 · 광고 SV/Agent 확장 [순서9-J 2026-07-28]**: 순서9-I/II 광고 팩트군 적재를 SV 계층에 반영. **`SV_AD` 신설 배포**(`GN_DW.SERVING`, dim 20·metric 15) + `AGENT_OVERALL` 에 `analyst_ad` 편입.
> **(1) 구조 — helper 뷰 채택**: 광고 팩트는 코어 `FACT_AD_PERFORMANCE`(235,572) + 위성 `FACT_AD_DIGITAL`(197,686)·`FACT_AD_BROADCAST`(37,886) **수직분할**(197,686+37,886=235,572 = 전건 완전분할, `AD_PERF_DK` 1:1). 그런데 **Snowflake SV 의 metric 식은 자기 logical table 컬럼만 참조 가능**(실측: cross-table 참조 시 `invalid identifier` 컴파일 실패) → 개발단가처럼 팩트 경계를 넘는 비율은 star 직접조인으로 **구현 불가** → `SERVING.FACT_AD_COMBINED` pre-join helper 뷰 신설(`DIM_MONTH`·`DIM_MEMBER_CURRENT` 패턴 계열). **fan-out 0 검증 PASS**(광고비 SV=FACT 51,439,193,917.80 일치).
> **(2) Phase 승격**: 공7(개발단가)·공9(CTR)·공10(CVR) **P2→P1**. 근거 = 개발단가 분모가 FMM 이 아니라 **광고 팩트 내부에 동반 적재**(`CRM_DEV_CNT` 249,390) → 크로스팩트 conform **불요**(문서 `04_SV파생 매핑.md §2` 전제 정정) · `GA_CONV_MEMBERS` 122,551 실적재로 공10 placeholder 해제. 실측 CTR 2024 0.199%→2025 0.286%→2026 0.345% · 개발단가 131,367→110,335→103,066원. 배속표 집계 갱신: P1 69→**72** · P2 12→**9** / 활성 58→**59** · placeholder 4→**2** · 보류 3→**4**.
> **(3) 🔴 본 세션 자체 결함 3건 — 전부 최초 배포를 통과, 재검토에서만 발견**: ①②**비율 metric 분모 커버리지 불일치**(신규 결함군) — 분모가 부분적재·분자가 전건이면 **컴파일·fan-out·행수 검증을 모두 통과하면서 조용히 과대계상**. 디지털 개발단가 +4.4%(분자 `CASE WHEN` 정합 후 노출) / **방송 개발단가 +41%**(분모 커버리지 5.2% → **metric 제거**, 선례 `AVG_RETENTION_MONTHS`). ③**코드 차원 comment 실제값 불일치** — `DEVICE_TYPE` comment 를 관행적으로 `'PC/MOBILE/TABLET'` 기재했으나 실제는 `M`/`PC`/`(해당없음)`/`(unknown)` → Analyst 가 `='MOBILE'` 생성 시 **0행 = 무증상 오답**(에러·경고 없음). 신규 이슈 **AD-1~AD-4**.
> **(4) 원천 포맷 변경 오진 정정**: `CRM_DEV_CNT` 2026-06 전건 NULL 을 "적재 지연"으로 기록했으나 실측 결과 **원천 포맷 변경**(2026-06부터 개발건수 중단·단가 `DEV_UNIT_PRICE_SRC` 8,401건 직접 제공, **완전 상호배타**) → 개발단가는 **2026-05까지만 산출 가능**. 파생 오류로 "대행사값 교차검증 가능"도 **불가**(같은 행에 공존 안 함 = 검증 관계가 아니라 **기간 보완 관계**) → **AD-3**.
> **(5) 신규 교훈 P18~P20** = 문서10 §9-F. **P18**(비율 metric 은 분모 커버리지 선측정 + 분자 정합, **DoD 에 커버리지 항목 신설 필요**) · **P19**(코드차원 comment 는 실제 코드값 전수 열거 — 관행 표기 금지) · **P20**(시간축 NULL 은 지연/포맷변경/해당없음 3분류 실측 판정). **§9-G = "빈 틀 스캐폴드" 판정**: GOLD 컬럼 스캐폴드는 순서9-I "설계O·값미주입 76건"으로 이미 사고화(P15), **SV metric/Agent 도구 스캐폴드는 금지**(소비 계층은 노출 자체가 계약) · **DDL 주석·문서에 비활성+활성트리거 기재는 권장**.
> **(6) 잔여 사용자 실행** = `05_SV-Agent_ai/13_SV_AD_배포_추가작업.sql`(신규): §1 소유권 이전(SV_AD·FACT_AD_COMBINED 가 ACCOUNTADMIN 소유로 생성됨 → GN_DW_ADMIN) · §2 **AGENT_OVERALL 비파괴 갱신 권고**(`CREATE OR REPLACE AGENT` 는 USAGE grant 3건 + **CoWork SI 등록까지 파괴** → `ALTER AGENT ... MODIFY LIVE VERSION` 우선) · §4 검증 · §5 스모크 7종 · §6 현업확인 쿼리 5종 · §7 구조적 제약 5건. ⚠ **배포된 AGENT_OVERALL 이 문서보다 구버전**(response instruction 3규칙·sample_questions 미반영) 실측 → 재배포로 동기화 필요.
> **(7) 성능·NL 스모크 = paid 게이트**(트라이얼 `DATA_AGENT_RUN` 차단, 순서9-E 6-C 유지). 정본 = `05_SV-Agent_ai/` 05·09·13 + 04·03·08·01 정합 완료.

> **▶ 워크스페이스 운영 — Git 자격증명·문서 위생 [순서9-L 부수 2026-07-29]**
> **(1) 🔴 OPS-1 GitHub PAT 평문 노출 → 로테이션 필요(미조치)**: 루트 `SECURITY.sql` 에 만료 PAT 가 **평문**으로 기록돼 있었다(`ghp_…` 39자). 현재 파일은 플레이스홀더로 교체했으나 **워크스페이스 버전 이력·git push 이력에 잔존 가능** → **해당 토큰은 GitHub 에서 폐기(revoke)하고 신규 발급**해야 한다. 이후 PAT 는 파일에 쓰지 말고 Snowflake SECRET 또는 UI 입력만 사용.
> **(2) ⚠ OPS-2 `USER$<user>` DB 의 SECRET 은 역할로 ALTER 불가**: `USER$TRIALADMIN.PUBLIC.git_sec`(`owner_role_type=USER`)은 `ACCOUNTADMIN` 으로도 `ALTER SECRET`·`DESCRIBE SECRET` 이 **"does not exist or not authorized"** 로 실패한다(실측). `SHOW SECRETS` 로는 보인다. → 워크스페이스 Git 자격증명 갱신은 **Snowsight 워크스페이스 Git 메뉴(UI)** 로 처리하거나, 접근 가능한 일반 DB 에 새 SECRET 을 만들어 참조한다. ⚠ `SECURITY.sql` 의 "방법 1(`ALTER STREAMLIT … PUSH`)·방법 2(`ALTER API INTEGRATION … ALLOWED_AUTHENTICATION_SECRETS`)"는 **문서 검색 기반 미검증 초안**이므로 실행 전 검증 필요.
> **(3) 🟢 문서 위생**: `09_AGENT_spec_구현.sql` 주석 **229→139줄(-39%)** 정리(총 687→597). 설계 근거·폐기 초안·실측 서술을 `08 §4.1`·`10 §11` 참조로 대체하고, 실행에 필요한 함정(YAML 콜론+공백 · live 선복구 · COMMENT/PROFILE)만 잔존. `[4-B]` 는 산문 대신 5단계 순서 다이어그램으로 재구성. SQL/YAML 본문 413줄은 불변.
> **(4) 🟢 `99_next_prompt.md` 현행화**: 2026-07-22 스냅샷이 **계정번호(cs94293→kd03246)·SV 5→6종·`SV_AD` 미배포→배포·`AGENT_OVERALL` 3→4도구·VERSION$1→$2** 에서 모두 낡아 다음 세션 오판 위험이 있었다 → 대조표·P24~P26·배포경로 경고 삽입, §1·§2·§3.1·§4·§5 교정. 마케팅 Agent 잔여 트리거는 **`SV_GA`(G-5)뿐**임을 명시.

> **▶ Agent 기간 기본창 + 배포 경로 규명 [순서9-L 2026-07-29]**: 트리거 = CoWork 실사용 질의 **"예산구분별 편성·집행·집행율을 보여줘"**(기간 미지정) → Agent가 **전체 기간 집계**로 응답(사용자 기대 = 최근 1년 월별). 🟢 **배포·발행 완료**(두 Agent VERSION$2 = default).
> **(1) 🔴 원인 = 순서9-G 발동조건의 사각(신규 결함 유형)**: 9-G에서 기간 스코프를 SV `AI_SQL_GENERATION`으로 이전할 때 ROLLUP 발동 조건을 **"기간·그룹이 *모두* 없을 때"** 로 좁혔다. 이번 질문은 **그룹(예산구분)이 지정**되어 조건을 벗어났고, 그 경우의 기간 기본값 규칙이 **SV·Agent 어디에도 없었다** → 무증상 전기간 스캔. 즉 9-G는 "그룹 없는 러프 질문"만 덮었고 **"그룹만 있는 질문"이 미커버**였다.
> **(2) 🟢 조치 — instruction 2줄 *제자리 교체*(신규 블록 추가 아님)**: `orchestration` "…SQL 스코프는 SV 담당이므로 여기서 반복하지 않**음**" → "…반복하지 않**되, 기간 미지정 시 기본 창을 질의에 명시해 전달**"(`"전체·전기간"` 시 미적용) / `response` "총계 먼저+**월별** 추이" → "**기본 창** 총계 먼저+**기간별** 추이"+되묻기에 **'전체 기간'** 추가. **OVERALL=SV 그레인 기준**(월 12개월·일 7일) / **MEMBER=도구명 직접 명시**(`analyst_member_monthly`=12개월 월별, 그 외 3종=7일 일별 — 월1+일3 혼재로 그레인 추론 오류 위험이 커 결정론 고정).
> **(3) ⚠ 설계 판단(자기검토로 초안 폐기 3건)**: ① **별도 기간규칙 블록 추가는 자기모순** — orchestration에 이미 "여기서 반복하지 않음"이 있어 병렬 규칙을 덧붙이면 LLM이 둘 중 하나를 무작위 무시 → 기존 줄 자체를 개정하는 방식으로 전환. ② **"적용 기간 응답에 명시"는 `response` 1행 "조회 기간·필터를 명시"와 완전 중복** → 삭제(토큰 순증 ≈ 0). ③ **"결과 행 수 7~12개 목표"는 오설계** — 예산구분(2)×12개월=**24행**이라 LLM이 기간을 임의 절단. 기준은 **시간 버킷 수**여야 함. "연도별 최근 3개년"도 근거 없어 폐기. → 신규 교훈 **P24**(instruction 개정은 *추가*보다 *제자리 교체* — 위임 규칙과 병렬 규칙이 공존하면 비결정적으로 무시된다).
> **(4) 🔴 배포 경로 4종의 버전 의미 차이 — 실측 규명(중대)**: `SHOW VERSIONS` 의 `is_default=true` 가 실서비스 버전이고 `live` 는 편집 버전이다. ① **`CREATE OR REPLACE AGENT`**(=`09` [1-ALT]) → 즉시 발행(COMMIT 불요)이지만 **버전 이력이 VERSION$1 하나로 초기화 = 롤백 대상 소멸**(임시 agent `ZZ_TMP_VERTEST` v1→v2 REPLACE 실측: VERSION$2 미생성, VERSION$1 내용만 교체) + USAGE grant 3건·CoWork SI 등록 파괴(9-J §2) → **최초 생성 전용**. ② **`cortex_agent_save` 단독** → **live만 갱신, default는 구 VERSION$N 유지** = **저장 성공 메시지가 나오지만 미발행**(본 세션 초반 실제로 이 상태로 "배포됨"으로 오인 보고). ③ **`cortex_agent_deploy`(save+publish)** → VERSION$N+1 생성+default 승격+**이력 보존**. ③′ **순수 SQL = `09` [4-B]** — `ALTER AGENT … MODIFY LIVE VERSION SET SPECIFICATION`(⚠전체 교체) → `… COMMIT`(발행) → `… ADD LIVE VERSION FROM LAST`(⚠COMMIT이 live 소진 → 생략 시 편집 불가). 임시 agent `ZZ_TMP_SQLPUB` 로 **③과 결과 동일함을 실측**(VERSION$2 is_default=true·VERSION$1 보존·live 복구 3행) → **CoCo/semantic_studio 의존 없이 SQL만으로 운영 계정 갱신 가능**하며 grant·SI 등록도 보존되어 [2]·[3]·[4] 재실행 불요. `09` [4-B]는 종전 전체 주석 템플릿이었으나 **양 Agent YAML 전문을 담은 실행 가능한 완전 SQL로 교체**. → 신규 교훈 **P25**(최초 생성만 ①, 기존 갱신은 ③/③′. ②로 끝내지 말 것).
> **(5) 🟢 CoWork `ADD AGENT` 멱등화 + 문서 오류 정정**: `ADD AGENT` 재실행 시 에러 → `IF NOT EXISTS` **미지원**(syntax error 실측). 제거 구문은 `REMOVE AGENT` 가 **아니라 `DROP AGENT`**(docs 정본 확인 — 세션 중간에 "제거 미지원"으로 **잘못 기록했다가 정정**). 해법 = `SHOW AGENTS IN SNOWFLAKE INTELLIGENCE` 사전 확인 후 조건 분기(`09` [4], 재실행 시 `skipped` 검증). ⚠ **가드 전제의 함정**: 이 SHOW 결과가 `SHOW AGENTS IN ACCOUNT` 와 **우연히 동일**했다(본 계정 2건 일치) → "계정 전체"인지 "SI 멤버십"인지 미분간 상태로는 **가드가 항상 skip 하는 무력 상태**일 수 있었다. `DROP AGENT` 직후 0 → 재-`ADD` 후 1 을 확인해 **멤버십 반영임을 실측 검증**. → 신규 교훈 **P26**(가드의 관측 대상이 실제로 대상 상태를 반영하는지 *변화를 일으켜* 검증할 것 — 두 목록이 우연히 같으면 무력한 가드가 정상처럼 보인다). 부수: Snowflake Scripting `FOR rec IN (…) DO` 커서 변수는 스크립팅 표현식에서 참조 불가(`invalid identifier`) → 루프 대신 명시 분기.
> **(6) 🔴 YAML gotcha**: agent spec `description` 을 plain scalar로 두면 본문의 `지표: `·`차원: `(**콜론+공백**)을 YAML이 매핑 구분자로 파싱 → `agent spec is invalid`(원인 미표시). 블록 스칼라(`|-`) 또는 인용 필수. 본 세션 첫 save 실패의 실제 원인이었다.
> **(7) 🟢 정본 동기화 + ⚠ 잔여 부채**: `cortex_project/AGENT_MEMBER.agent.yaml`·`AGENT_OVERALL.agent.yaml` 2종 갱신 후 ③으로 배포. `08 §3.2`(OVERALL 사본) 2줄 동기화. ⚠ **`08 §3.1`(MEMBER 사본)은 순서9-F/9-G 이전 구버전**임을 발견 — 라벨화·원천·기본창 모두 미반영. **이번 세션 변경분이 아닌 누적 부채**이며 사본을 근거로 재배포하면 규칙이 소실되므로 전면 교체는 별도 작업으로 분리, 08에 🔴 경고 블록 명시(당분간 근거는 정본 yaml 직독). **동일 유형(정본↔사본 drift) 4회째 재발** → P23의 실효성 부족 시사.
> **(8) ⚠ 수용한 트레이드오프**: 기본 창은 **암묵적 필터링**이므로 "왜 2022년이 없지?" 혼란 가능 → ① 적용 기간 응답 명시(기존 규칙 재사용) ② 되묻기에 '전체 기간' 노출 ③ `"전체"` 키워드로 규칙 무시 — 3중 완화. **미검증 잔여**: 규칙이 실제 생성 SQL에 반영되는지의 **NL 스모크는 트라이얼 `DATA_AGENT_RUN` 차단으로 미실시**(순서9-E 6-C 유지, paid 게이트) → **PRV-3**.
> 정본 = `cortex_project/*.agent.yaml` · `05_SV-Agent_ai/08_AGENT_spec.md`(§3.2·§4.1·§4.4) · `09_AGENT_spec_구현.sql`(헤더·[4]·[4-B]).

> **▶ BRONZE 원천(provenance) 노출 · 공8 오진 철회 [순서9-K 2026-07-29]**: 트리거 = (1) "Agent가 여러 SV 결과를 스스로 조합할 수 있나 / 왜 표를 분리하나" 질의, (2) **사용자가 `13_SV_AD_배포_추가작업.sql` 진단쿼리를 직접 실행** → 순서9-J 의 AD-1 판정이 오진임이 드러남. ~~미배포 상태~~ → 🟢 **배포 확인(2026-07-29, 순서9-L 실측)**: `SHOW SEMANTIC VIEWS` 6종 + `DESCRIBE SEMANTIC VIEW SV_AD` 에 `REBRDC_DEV_UNIT_PRICE`(157,969원·커버리지 96.03%) metric 및 개정 COMMENT·`AI_SQL_GENERATION`(1)(6) 반영 확인 → 05·13 실행 완료.
> **(1) 🔴 AD-1 오진 철회 — 범주 오류**: 순서9-J 는 공8(방송 개발단가)을 "분모 커버리지 5.2% → 41% 과대계상"으로 제거했으나, 실측 결과 **`DVLP_CNT` 는 `BRONZE_AGENCY.REBRDC_AD_CMPGN_DTLS` 전용이고 `VIDEO_AD_CMPGN_DTLS` 에는 개발 컬럼이 아예 없다**(비디오 리포트는 개발 대신 `CONV_CALL_CNT` 보고) → VIDEO 의 공백은 **미적재 결손이 아니라 구조적 부재**인데 이를 분모 모집단(37,886행)에 포함시킨 것이 오진의 원인. **REBROADCAST 단독: 커버리지 96.03%**(1,982/2,064) · 정합 왜곡 **0.61%**(158,933→**157,969원**). 종전 주석 "정합해도 방송 광고비의 29%만 반영"도 **수치가 뒤집힌 오기**(정합 분자 ₩15.22B/방송합계 ₩21.52B = **70.7% 포함**, 29%는 제외되는 VIDEO 몫). → **`REBRDC_DEV_UNIT_PRICE` 로 복원**(공8 P2→**P1**, 배속표 P1 72→**73**·P2 9→**8**·보류 4→**3**·활성 59→**60**). 명명 `BRDC_`→**`REBRDC_`** — VIDEO 에 개발 개념이 없으므로 "방송"은 여전히 스코프 오인 유발. 종전의 *문제의식*("이름이 커버리지를 오인시킨다")은 타당했고 **틀린 것은 해법**이었다(제거 ≠ 정확한 명명). 신규 **AD-5**(VIDEO 개발실적 원천 부재 — 대행사에 항목 신설 요청 필요, 방송 광고비 29%=₩6.2B 구간 효율 측정 불가).
> **(2) 🟢 BRONZE 원천을 SV 메타데이터로 노출 (신규 설계 규약 = 작업계획 원칙13 · `04_SV_설계.md §0.7`)**: **실측으로 전제 검증** — `semantic_view_read`(SV_BUDGET 배포본) 역직렬화 결과 SV DDL 의 COMMENT 가 semantic model YAML 의 **`description` 필드로 1:1 매핑**됨(테이블 COMMENT→`tables[].description`, SV COMMENT→최상위 `description`)을 확인. `description` 은 Cortex Analyst 가 **프롬프트 context 로 소비**하는 필드 → 원천을 COMMENT 에 적으면 **별도 tool·Cortex Search 없이** provenance 질문("이 숫자 어디서 왔어?")에 창작 없이 답한다. SV 6종 전체에 `[원천]`/`[원천 요약]` 절 기입(형식: `시스템=<원천> · BRONZE=<DB.스키마.테이블(핵심컬럼)> · SILVER=<정제테이블>`). BRONZE 스키마 4종↔SV 매핑: `BRONZE_CRM`→회원 4 SV · `BRONZE_ERP`→SV_BUDGET · `BRONZE_AGENCY`+`BRONZE_GA4`→SV_AD. **입도 = 테이블 수준만** — 컬럼 단위는 `30_output_share/04_컬럼계보매핑.md`(자동생성 정본)로 위임(상시 토큰 소모 + 정본 이중화 drift 회피). 에스컬레이션 경로(🔜): 현업이 컬럼 단위 출처를 반복 질문하면 계보 문서를 **Cortex Search 색인 → Agent `cortex_search` tool** 추가. ⚠️ **원칙11(SV dimension 백킹)과 부착 지점·목적이 다름 — 혼동 금지**. **가드레일 신설**: SV COMMENT 는 소비 3역할(ANALYST/VIEWER/SERVICE) 전원이 읽으므로 **PII 컬럼명 기입 금지**(`11_BRONZE적재 컬럼대조.md §2` = 금지 목록) · 원천 **시스템명을 항상 앞세움**(VIEWER 는 BRONZE SELECT 없을 수 있음). **부수 효과**: 원천이 다른 SV 를 한 답변에 낼 때 Agent 가 **표 분리 근거를 갖는다**(예산=ERP ↔ 광고=AGENCY, E-4 로 예산 원장에 광고비 컬럼 부재) — 종전엔 tool 결과가 물리적으로 분리돼 분리했을 뿐 이유를 설명하지 못했다.
> **(3) 🔴 정본 위상 위배 + 기존 부채 발견**: 최초 시도에서 Agent instruction 을 **실행 로그**(`09_AGENT_spec_구현.sql`)에만 반영 — 그런데 `08_AGENT_spec.md §3` 은 **정본 = `cortex_project/*.agent.yaml`**, 08=사본, 09=로그로 규정. 로그에 스펙을 쓰는 것은 **카테고리 오류**이며 정본이 뒤처진다. 자기검토 중 **기존 부채도 발견**: `AGENT_OVERALL.agent.yaml` 에 **`analyst_ad`/SV_AD 가 아예 없었다**(순서9-J 산출물 미전파) → **동일 유형 3회째 재발**(08 §3 말미에 이미 "배포본이 문서보다 구버전" 기록 존재). 조치: yaml 2종 정본 갱신(원천+SV_AD+공8) · 09 헤더에 위상 경고·4단계 반영 순서 기재. **(4) 🟢 SV 정본 이중화 제거**: `cortex-project.yaml` 에 SV yaml 4종이 등록돼 있었고(`SV_BUDGET`·`SV_AD` 누락·`[원천]` 절 없음) — 그 yaml 로 `semantic_view_deploy` 실행 시 **COMMENT 작업 소실 + SV 2종 누락** 위험. SV yaml 은 **툴 요구사항이 아님**(Agent yaml 이 SV 를 FQN 문자열로 참조) 확인 후 **4종 삭제 + manifest 정리**(Agent 2종만 유지 — 이쪽은 경로 해석에 실제 사용). **SV 정본 = `05_SV_DDL.sql`**(원칙12) 확립.
> **(5) ⬜ 평가셋 공백(미착수)**: provenance 질문은 **SQL 을 생성하지 않으므로**(도구 미호출 규칙) `07_평가셋_eval.md` 의 gold-SQL 대조로 채점 불가. `06_검증쿼리_VQR.md` 등록도 부적합(VQR=SQL 정본). → **가드레일(ⓖ) 신규 클래스**("텍스트 답변·도구 미호출 기대") 신설 필요 — 기존 ⓖ 는 "SQL 생성 거부"라 판정 축이 다름.
> **(6) 신규 교훈 P21~P23** = 문서10 §10-F. **P21**(결함 판정의 **모집단 검증** — 커버리지로 지표를 제거하기 전에 분모의 유효 모집단을 확정하고, 원천에 컬럼이 **존재하는지**를 `INFORMATION_SCHEMA` 로 확인. *해당 개념이 없는 세그먼트*를 분모에 넣으면 정상 지표가 결함으로 오판됨. **P18 의 전제 조건** — P18 만 적용하면 이번 오진이 난다) · **P22**(provenance 는 **소비 계층 신뢰의 일부**. 출처를 못 대는 숫자는 채택되지 않음. 테이블 수준 기입 + 컬럼 단위는 정본 위임 + **읽는 주체의 권한 범위** 전제로 PII 배제) · **P23**(**정본 위상 준수** — 정본/사본/실행로그 위상 구분. 로그에 스펙을 쓰면 정본이 조용히 뒤처진다. 자동 전파 없는 구조에서 **순서 문서화가 유일한 방어**).
> **(7) 잔여 사용자 실행**: ① `05_SV_DDL.sql` 전체(SV 6종 재배포 — **§7 GRANT 재실행 필수**, `CREATE OR REPLACE` 가 GRANT 파괴) → ② `13_SV_AD_배포_추가작업.sql`(순서9-J 미완분) → ③ Agent 2종 재배포(`09` [1-ALT] 또는 `cortex_agent_deploy`, **정본=yaml 경로 권장**) → ④ CoWork 검증("재방송 개발단가는?"·"예산과 광고비 원천은 각각 어디야?"). 정본 = `05_SV-Agent_ai/` 01·03·04·05·09 + `cortex_project/*.agent.yaml`.

> **▶ 지표→GOLD 추적 장표 [순서9-H 2026-07-27]**: 현업용 **지표번호·보고서필드 ↔ GOLD 추적 장표** 신규 생성 — `30_output_share/05_지표GOLD매핑.{md,csv,xlsx}`(생성기 `scripts/gen_metric_gold_mapping.py`). ① 215지표(공162+신53)→배속(FACT/DIM/SV)·물리컬럼/SV base·SILVER·BRONZE·계산식·상태, ② **04·05 보고서필드→GOLD** 매핑. `04_컬럼계보매핑`에도 **지표# 열** 추가(`scripts/gen_column_mapping.py`). **정본 근거=`03_top-down_gold/05_필드 인벤토리.md`**(보고서필드→GOLD 물리컬럼; 지표번호 없는 '215밖' 필드도 컬럼 배속 — 신규 **P12**, 문서10 §8). **커버리지 실측: 마케팅 73/73(100%)·회원 432/434(99%)** — 미매칭 2건뿐(**A-5** 앱푸시 발송·성공건수 ❌제외). ⚠️ **[정정 2026-07-27]** 초기 '납입(명) base 부재'는 오해 — **납입 데이터는 존재·적재됨**(BRONZE_CRM.TM_PM_MBRFEE_ACMSLT 46.4M·납입성공 회원 1.13M 실측). 물리 컬럼만 없을 뿐 SV로 산출 가능(장표=SV파생). ⚠️ **LTV(신8) 시간범위 정정**: "24년 이전 회비 부재"→**회비 2022-01~ 전량 실측** → 22년~ (문서10 §8-C, 설계문서 6건 교정). ⚠️ **정밀도 결함 해소**: 부분일치가 SV파생을 선점해 비율필드를 물리컬럼으로 오확정한 **오매핑 8건** → `DERIVED_MARK` 게이트로 0건화, 장표에 **근거별 신뢰도표**(부분일치 100건=검증필요) 명시. 신규 교훈 **P13**(커버리지≠정확도·근거별 신뢰도 병기)·**P14**("부재" 판정은 실측+측정일 필수). **후속 착수 전 필독 = 문서10 §8-E 체크리스트 8항**(부분일치 검증·METRIC_NO 하드코딩 부채·원천 버전 미고정·grep `--include` 함정 등).

---

## 2. 전체 이슈 크로스워크 (마스터 인덱스)
> 같은 이슈가 문서마다 다른 번호로 불림. 대표 ID·별칭·상태·**현 단계 문서**를 통합. 상세는 "문서" 열 참조.
> ⚠️ 클라이언트 지표사전 번호 `[공통/신규 #n]`은 외부 정본(인용 전용·재번호 금지).

### 2-A. 입고 필요 (원천 데이터)
| 대표 ID | 별칭 | 계층 | 이슈 | 상태 | 문서 |
|---|---|---|---|---|---|
| A-2 | Q9 | AGENCY | 광고 `_SOURCE_SYSTEM` 출처구분 | ✅ 해소(순9-C 데이터확정: `DW_SOURCE_SYSTEM='AGENCY'` 상수·매체구분 속성) | 30 |
| A-5 | — | AGENCY | 앱푸시 발송·성공(어드민) | ❌ 제외 | 90 |
| A-6 | — | AGENCY | 이벤트 조회수(어드민) | ❌ 제외 | 90 |
| A-10 | — | CRM/어드민 | 행사기간·참여경로·채널 | ✅ CRM-backed·어드민분만 제외 | 90 |
| E-1·E-4 | O3 | ERP | 캠페인/매체 연결키 | 🔴 부분·국내/해외 보류 | 40 |
| E-5·A-9 | — | ERP/AGENCY/GA4 | 적재 시작시점/범위 | 🟡 실적재 후 확정 | 40 |
| E-6 | — | **CRM** | 사업목표(FTG-B) 원천 | 🔴 **원천=CRM 확정(2026-07-20 정정)**·신규 목표 테이블 입고 대기·**입고요청서(41) 발행·회신대기** · 단위=건 확정(#152~155) · [2026-07-16] FACT/WIDE_TARGET_BIZ 스켈레톤 저작(0행) | 40·41 |
| C-8 | DEC-7 | 현업 | 인바운드콜·TS콜 수치 | ✅ 결정→입고(값 대기) | 40 |
| G-5 | — | GA4 | GA4 전체기간 shards | 🔴 1일 샤드만 | 40 |

### 2-B. 의사결정 (설계/IT)
| 대표 ID | 별칭 | 이슈 | 상태 | 문서 |
|---|---|---|---|---|
| D1 | — | 스캐폴드 팩트 `unique_key`<grain | ✅ 해결(append+TRUNCATE)·🔴 FROZEN 대량시 merge 재평가 | 30·10 |
| D2 | — | DIM_MEMBER SCD2 | ✅ 완료: append+TRUNCATE(구조복원 코멘트22/22·PK·현재행 회원당1·손실0·7.93M) | 30·90 |
| D3 | — | DIM_ORG 가짜update | ✅ 해결(SCD1) | 90 |
| #80 | DEC-4 | UNPAID_MEMBERS 신설 | 🔵 구현 대기 | 30 |
| 납입(명) | #80류 | 납입 회원수(명) — **원천 존재·적재확인**(BRONZE_CRM.TM_PM_MBRFEE_ACMSLT 46.4M, 납입성공 회원 1,126,391명 실측 2026-07-27) | 🟢 **데이터 있음**·SV distinct-member 산출 가능(장표=SV파생·문서10 §8-B) | 10 |
| ID-활성 | — | GA4_IDENTITY/DIM_MEMBER_IDENTITY 활성 | 🟢 활성·배선완료(2026-07-15)·⚠️G-5 재검증 | 30·50 |
| SF | — | session-fill 채택 | ✅ 채택 | 90 |
| O8 | — | FSE·FEP 캠페인·후원사업 귀속 | 🔄 잠정(직접FK) | 30 |
| O10 | Q7 | 조직 역할 FMM·FME 반영 | 🔄 잠정(실적부서) | 30 |
| DEC-1 | — | 감사컬럼 4종 표준화 | ✅ | 90 |
| DEC-2 | — | DIM_ORG=SCD1 | ✅ | 90 |

### 2-C. 현업 확인
| 대표 ID | 별칭 | 이슈 | 상태 | 문서 |
|---|---|---|---|---|
| C-9 | — | '오픈(명)' 정의 | ✅ 확정·⚠️2026-09 재검토 | 90 |
| C-Q1 | — | '클릭' 정본 | ✅ 확정·⚠️2026-09 재검토 | 90 |
| C-Q2 | — | GA 개발실적 귀속 | ✅ 확정(병존·합산금지) | 90 |
| C-Q3 | O4 | 참여 인정기준 | ✅ 확정·잔여 코드매핑 | 20 |
| C-Q4 | — | '이탈' 범위 | ✅ 확정(취소+감액) | 90 |
| G-2 | O1 | 이탈율·세션시간 규칙 | ✅ 승인 | 90 |
| 이용시간 | =G-2 | engaged vs wall-clock | ✅ 승인(engaged) | 90 |
| G-4 | — | GA4 확정데이터 기준일 | ✅ 확정(컷오프 불요) | 90 |
| A-7 | O5 | 인입콜·전환수 단위 | 🔄 잠정·잔여 VU어의 | 20 |
| **AD-1** | 공8 | ~~방송 개발단가 — 분모 `DVLP_CNT` 커버리지 5.2%(1,982/37,886)로 41% 과대계상~~ → 🔴 **오진 철회(2026-07-29)**: VIDEO 원천(`VIDEO_AD_CMPGN_DTLS`)에 개발 컬럼이 **구조적으로 부재**한데 이를 분모 모집단에 포함시킨 **범주 오류**. **REBROADCAST 단독 커버리지 96.03%**(1,982/2,064) · 왜곡 **0.61%**(158,933→157,969원). "29%만 반영"도 뒤집힌 오기(실제 70.7% 포함) | 🟢 **해소** — `REBRDC_DEV_UNIT_PRICE` 로 복원·노출(공8 P2→**P1**). 명명은 `BRDC_`→`REBRDC_`(재방송 한정 명시) | 10 §10-A · 90 |
| **AD-5** | — | **[신규 2026-07-29]** **VIDEO 개발실적 원천 부재** — 대행사 비디오 리포트가 개발건수를 보고하지 않는다(개발 대신 `CONV_CALL_CNT`). 미적재가 아니라 **항목 자체가 없음** → 방송 광고비의 **29%(₩6.2B)** 구간은 개발 효율 측정 불가 | 🔴 **현업·대행사 협의** — 비디오 리포트에 개발건수 항목 신설 요청 필요 | 20 §E · 40 · 10 §10-G |
| **AD-2** | 공7 | **`CRM_DEV_CNT` 소수값** 24,614/189,252행(13.0%, min 0.0·max 322.0) — 기여도 배분값 여부 어의 미확정 | 🔵 **현업 확인 대기**·"건수" 단정 금지 가드 배포됨 | 20 §E · 10 §9-B |
| **AD-3** | 공7 | **2026-06 원천 포맷 변경** — 원천이 개발건수 중단·단가(`DEV_UNIT_PRICE_SRC`) 직접 제공. `CRM_DEV_CNT`와 완전 상호배타 → 개발단가 2026-05까지만 산출 | 🔴 **원천/현업 결정 대기**(건수 재요청 vs 대행사 단가 채택) | 20 §E · 40 · 10 §9-D |
| **AD-4** | — | **코드 차원 comment 실제값 불일치** — `DEVICE_TYPE` comment `'PC/MOBILE/TABLET'` vs 실제 `M`/`PC`/`(해당없음)`/`(unknown)` → Analyst 가 `='MOBILE'` 생성 시 **0행 무증상 오답** | 🟢 **SV_AD 해소**(2026-07-28) / ⚠️ **타 SV 코드차원 전수 점검 미실시** | 10 §9-C |
| A-8 | — | 송출일≠실적일 | 🔄 잠정(단일날짜 근사) | 20 |
| A-11 | O11 | '이벤트 관리' 정의 | ✅ 확정(총참여수) | 90 |
| O2 | — | DIM_DEVICE PC/M/APP | ✅ 확정·잔여 APP분기 | 30 |
| O6 | Q8 | EVENT_TYPE 코드체계 | 🔄 잠정·게이트 라벨 | 20 |
| SF-biz | — | 익명 미귀속 | 🛠️ 설계흡수 | 30 |
| #81 | — | 미납클릭·납입전환 판정 | 🔄 잠정·게이트 identity | 20 |
| SVL-1 | — | 발송소분류(`SNDNG_TY_CD`) 라벨 | 🔵 라벨 대기(SV_SERVICE) | 20 |
| SVL-2 | — | 발송상태(`SNDNG_RST_CD`) 라벨 | 🔵 라벨 대기(SV_SERVICE) | 20 |
| SVL-3 | — | 발송채널(`SEND_CHANNEL`) 라벨 | 🔵 라벨 대기(SV_SERVICE) | 20 |
| SVL-4 | O6/Q8 | 행사구분(`EVENT_DIV_CD`/`CRMN_DIV_CD`) 라벨 | 🔵 라벨 대기(SV_EVENT_PARTICIPATION) | 20 |

### 2-D. SILVER Q-이슈 (Q1~Q16)
| Q | 이슈 | 상태 | 문서 |
|---|---|---|---|
| Q1 | GA↔CRM 식별자(=G-1) | 🔵 확정·채움률 4.22% | 20 |
| Q2 | 캠페인 코드↔코드그룹 | 🔵 라벨 대기 | 20 |
| Q3 | #17 최종확인 | 🔵 현업 | 20 |
| Q4 | 회원상태 코드그룹 MM010 | 🟢 | 90 |
| Q5 | 발송키 이원화 | 🟢 적재완료 | 90 |
| Q6 | 정기/일시 UNION | 🟢 적재완료 | 90 |
| Q7 | 조직 역할 3종(=O10) | 🟢 | 90 |
| Q8 | EVENT_TYPE·활동전환(=O6) | 🔵 라벨 대기 | 20 |
| Q9 | 노출·클릭 출처(=A-2) | ✅ 해소(순9-C, =A-2) | 30 |
| Q10 | 세세목↔캠페인 | 🔴 부분·연결키 현업 | 40 |
| Q11 | EHGT(=C-10) | 🟢 제외 | 90 |
| Q12 | CSV↔DDL 대조 | 🟢 ◐잔여 입고팀 | 90 |
| Q13 | 약정 3중 grain | 🟢 | 90 |
| Q14 | 납입+청구 SUM 중복 | 🟢 | 90 |
| Q15 | 후원사업 키 NO vs ID | 🟢 | 90 |
| Q16 | 캠페인↔마케팅캠페인 조인키 | 🟢 무효화 | 90 |

### 2-E. dbt 의심데이터 (현업 판정 대기 A~E)
| # | 항목 | 규모 | 상태 | 문서 |
|---|---|---|---|---|
| A | `MONTH_KEY` 비-YYYYMM | ~2,043행 | 무효→0 라우팅 | 20·50 |
| B | 회원번호 마스터 부재 | 9,248명+NULL 750 | warn·보존 | 20·50 |
| C | 캘린더 범위밖 날짜 | ~140행 | DATE_SK=0 | 20·50 |
| D | 원천 값 전무 컬럼 | 5종 | NULL | 20·50 |
| E | `EVENT_KEY→CRM_EVENT` 고아(참여 23%) | 263,611 | **warn 관측(순서9-C)**·GOLD SK=0 라우팅 | 20·50 |

> **센티넬 규약(정본, 2026-07-16 확정)**: 미매칭·범위밖·NULL 차원키는 **Unknown 멤버 `SK=0`**으로 라우팅(13개 GOLD DIM 전량 `union all select 0 '(미매핑)'` 시드 + `gold_helpers` `COALESCE(...,0)`). ⚠️ SILVER 설계초안(02·15·00_README)의 `-1 UNKNOWN` 표기는 **구현 단계에서 `0`으로 통일·폐기**됨(해당 문서 2026-07-16 정정 반영). `-1`은 이 프로젝트 어디에도 없음.

### 2-F. 닫힌 항목 (재론 불요)
| 대표 ID | 별칭 | 이슈 | 문서 |
|---|---|---|---|
| C-3 | DEC-3 | 미납정의=`PAY_STAT_CD IN('F',NULL)` | 90 |
| C-7 | DEC-5 | 팀=`UPPER_DEPT_ID` 5th | 90 |
| C-10 | DEC-6·Q11 | EHGT 미연동 | 90 |
| G-1 | Q1 | user_id=회원번호 | 90 |
| O7 | — | 215지표 커버리지 | 90 |
| O12 | AC-1 | `MEMBER_DK`=VARCHAR(10) | 90 |
| O13 | S13 | DIM_SPONSORSHIP 카디널리티(50) | 90 |

> **별계열 주의**: `P1~P26`=설계 원칙(이슈 아님, 문서10 — **P21~P23**은 §10-F · 최신 **P24~P26**은 §10-L) · `S*`=프로파일링 태스크 · `AD-*`=광고 SV 이슈(§9~10) · `PRV-*`=소비계층 미결(§10, PRV-3=Agent 기간규칙 NL 스모크) · `_archive` 구 Q1~Q9는 현 스킴 흡수·은퇴(⚠️`_archive` Q1 ≠ 현행 G-1/Q1 identity, 동명이의).

---

## 원본 아카이브
본 원장은 아래 7개 원본을 병합. 원본은 각 폴더 `_archive/`로 이관됨:
`03_top-down_gold/_archive/`(30·33·34) · `04_silver_design/_archive/`(10_SILVER_이슈해결·11_SILVER_블로커) · `10_dbt_pipeline/_archive/`(_OPEN_ITEMS·_현업검토요청).

---
_Co-authored with CoCo_
