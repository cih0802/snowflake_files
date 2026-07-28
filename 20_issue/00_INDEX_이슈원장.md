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
| 🔴 값미주입(내부) | 76 → **67**(AGENCY 9 해소) | **[신규 2026-07-28]** GOLD 하드코딩 `0`/`CAST(NULL)` — 설계O·값 미주입. AGENCY 9건은 BRONZE 실존 확인 → ✅ **배선 완료(2026-07-28)**: DEVICE_SK 실배선 + 방송 degen 위성 이관. 잔여 67건은 CRM·기타 모델 | 10 §8-I |
| 🔴 의미혼입(내부) | 2 → ✅ 코드해소 | **O16 [신규 2026-07-28]** REBRDC 개발실적이 `GA_CONV_MEMBERS`·`GA_CONV_CNT` 로 노출 — UNION 위치매핑 + `GA_` 개명. 실측 오염 **28.60% · 60.32%(과반)**. DEC-8 위성 분리로 해소 | 10 §8-I(8) |
| 🟠 설계결정 블로커 | ~~3+~~→ 감소 | ~~A-2/Q9~~ ✅해소(순9-C) · O2 APP분기 ✅데이터확정(PC/M·APP휴면) · AGENCY 6종 부분해소 | 30 |
| 🔄 우리끼리 잠정(게이트 有) | 6 | A-7/O5 · A-8 · O6 · #81 · O8 · O10 | 20 · 30 |
| 🔵 비블로커 | 10 | #80 · ID-활성 · Q1·Q2·Q3·Q8 · **SVL-1~4**(SV 코드→라벨 매핑 확인) | 30 · 20 |
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
> **▶ BRONZE 전 원천 노출감사 + AGENCY 광고 팩트군 재설계 [순서9-I 2026-07-28]**: 요구("보여줄 수 있는 BRONZE 데이터는 다 보여준다 + 출처 명시")에 대해 **BRONZE 1,121컬럼 전면 감사** 실시 — `30_output_share/06_BRONZE노출감사.{md,csv,xlsx}`(생성기 `scripts/gen_bronze_exposure_audit.py` + 러너 `scripts/run_bronze_audit_host.py`). 판정: **노출 18 · 대체노출(파생) 14 · ⚠️설계O·값미주입 9 · SILVER까지 356 · 판정보류 9 · 미노출 664 · 제외 51**. 🔴 **신규 결함군 "GOLD 설계O·값 미주입" 76건**(모델×컬럼) 발견 — DDL·문서엔 컬럼이 있으나 SQL이 `0 as X_SK`/`CAST(NULL)` 하드코딩 → **커버리지 점검을 통과하면서 전건 NULL**. 해소 난이도 최저(DDL 무변경·SELECT 배선만) → **최우선 조치군**. AGENCY 9건은 전량 BRONZE 실존 확인 → dbt 주석 "원천 부재"는 오류(**P14 위반 4~10번째 사례**, 8-H의 "3번째"는 과소평가였음). 🔴→🟢 **감사 도구 자체 오탐 교정**: 전역 이름매칭이 `AGENCY.DEVICE`(실제 하드코딩)를 '노출됨'으로, `GA4.device`(실제 정상)를 '하드코딩'으로 오판 → 계보 매핑을 **(원천테이블×컬럼)→(GOLD컬럼×모델)** 로 양측 스코프 축소 + 일반명 `판정보류(동명이의)` 격리. 노출됨 153→**18**. 신규 교훈 **P15**("설계 완료 ≠ 값 존재"·하드코딩 정적스캔 정례화)·**P16**(감사 오탐은 미탐보다 위험 — 결손 은폐). 설계 확정 **DEC-8~11**: 위성 팩트 3종(FAD_B·FAD_D·FAD_BC) · 대행사 파생 `_SRC` 8종 전량 보존 · `DIM_DEVICE` `(해당없음)` 멤버 · `AD_PERF_DK` 행식별자. 상세 = 문서10 §8-I · `03_테이블 설계.md §3-A`. ✅ **dbt 모델 구현·build 완료(2026-07-28)** — `PASS=258 WARN=21 ERROR=0`(WARN 21은 전부 기존 CRM 고아관계, 신설분 0). 산출 20종(SILVER 모델 7·GOLD 팩트/차원 5·**GOLD WIDE 4**·schema.yml 3·DDL 2). 실측: 코어 235,572행 `AD_PERF_DK` 전건 유일 · 위성 197,686/37,886/5,327 · **`DEVICE_SK` unknown 0건(지표 공14 해소)** · **O16 해소 확정**(코어 GA_CONV_MEMBERS 122,551·GA_CONV_CNT 63,372.9 = 디지털 전용 / FAD_B DVLP 49,093·96,321). 추가 정리: `AD_TYPE`→**`AD_SOURCE_TYPE`** 개명(`DIM_AD_CREATIVE.AD_TYPE` 충돌 해소) · `DVLP_MEMBER_CNT` 정밀도 교정. 🔴 **본 세션 자체 결함 2건**(컬럼 이관 시 WIDE 참조처 누락 · 개명 일괄치환이 동명 타컬럼 오염) → 신규 교훈 **P17**. 상세 문서10 §8-I(10)(11). 🔴 **추가 발견 O16(의미혼입)**: SILVER UNION 이 REBRDC `DVLP_MBER_CNT`·`DVLP_CNT` 를 DIGITAL 의 GA 지표 자리에 위치매핑하고 GOLD 가 `GA_CONV_MEMBERS`·`GA_CONV_CNT` 로 개명 노출 → **재방송 개발실적이 'GA 전환'으로 혼입**. 실측(2026-07-28): `GA_CONV_MEMBERS` 의 **28.60%**(49,093/171,645) · `GA_CONV_CNT` 의 **60.32%**(96,321/159,693.9, **과반**)가 REBRDC. 계보 추적은 개명을 정확히 잡았으나 **개명의 타당성은 판정 범위 밖** → 위성 분리(FAD_B 별도 컬럼)로 해소. 상세 문서10 §8-I(8). 🛠️ **감사 러너 결함 4종 교정**(세션캐시 의존 제거→INFORMATION_SCHEMA 직접조회로 **재현성 확보** · alias 정규식 미탐/오탐 · P15 자기모순 신뢰도) → 재실행 결과 **판정·건수 전건 동일**(비고 문구 5건만 정밀화). 별건으로 **문서 전사 오류 6곳 교정**(AGENCY `노출 4·SILVER 24·미노출 57` → 실측 **`11·15·52`** · CRM `SILVER 154`→**275**). 상세 문서10 §8-I(9).

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

> **별계열 주의**: `P1~P9`=설계 원칙(이슈 아님, 문서10) · `S*`=프로파일링 태스크 · `_archive` 구 Q1~Q9는 현 스킴 흡수·은퇴(⚠️`_archive` Q1 ≠ 현행 G-1/Q1 identity, 동명이의).

---

## 원본 아카이브
본 원장은 아래 7개 원본을 병합. 원본은 각 폴더 `_archive/`로 이관됨:
`03_top-down_gold/_archive/`(30·33·34) · `04_silver_design/_archive/`(10_SILVER_이슈해결·11_SILVER_블로커) · `10_dbt_pipeline/_archive/`(_OPEN_ITEMS·_현업검토요청).

---
_Co-authored with CoCo_
