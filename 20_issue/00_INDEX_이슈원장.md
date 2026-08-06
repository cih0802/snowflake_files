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
| 🔴 의미혼입(내부) | 2 → ✅ 코드해소 / **+1 신규** | **O16 [신규 2026-07-28]** REBRDC 개발실적이 `GA_CONV_MEMBERS`·`GA_CONV_CNT` 로 노출 — UNION 위치매핑 + `GA_` 개명. 실측 오염 **28.60% · 60.32%(과반)**. DEC-8 위성 분리로 해소 · **O24 [신규 2026-08-03]** FME 가 개발구분 5종(MM015)을 `EVENT_TYPE='DEV'` 한 값으로 뭉갬 → 상태축 소실 + **`DEV_CNT` 56.86% 과대계상**. ✅ 적재 해소 / 🟠 중단 중복 현업확인 1건 잔여 | 10 §8-I(8) · **03설계 §5 O24** |
| 🟠 설계결정 블로커 | ~~3+~~→ 감소 | ~~A-2/Q9~~ ✅해소(순9-C) · O2 APP분기 ✅데이터확정(PC/M·APP휴면) · AGENCY 6종 부분해소 | 30 |
| 🔄 우리끼리 잠정(게이트 有) | 6 | A-7/O5 · A-8 · O6 · #81 · O8 · O10 | 20 · 30 |
| 🔵 비블로커 | 10 → **12** | #80 · ID-활성 · Q1·Q2·Q3·Q8 · **SVL-1~4**(SV 코드→라벨 매핑 확인) · **AD-2**(CRM_DEV_CNT 소수값 어의) · **AD-4 잔여**(타 SV 코드차원 comment 전수점검) | 30 · 20 · 10 §9 |
| 🔴 **재구축 드리프트(내부)** | **1** | **[신규 2026-08-04] O30** 전체 환경 재구축이 정본 DDL 미동기화 구조 변경(O26 2컬럼·O27 7컬럼)을 되돌려 `dbt build` ERROR 3·SKIP 68. ✅ 구조 복구·정본 동기화 완료 / ⬜ 잔여 = `dbt build`·SERVING 복구(SV 6종 전멸) | 10 §19 |
| 🟢 **재구축 미완(내부)** | **1 → 해소 진행** | **[2026-08-05 O41]** 2차 전체 재구축. ✅ BRONZE 재적재 완료(CRM 43/112,512,201행 · AGENCY 4 · ERP 1 · GA4 3) · SILVER 38 적재 · **`dbt build` 완주 `PASS=370 WARN=27 ERROR=0 SKIP=0`**(O42 해소 후) · GOLD 팩트 12/13 적재(`FACT_TARGET_BIZ` 0 = E-6 정상) · WIDE 13 + `DIM_MEMBER_CURRENT` 생성 / ⬜ 잔여 = 런북 §11.2-C **⑤~⑧**(helper 뷰 → SV 6종 → Agent `09_1`→`09_2`). **SERVING 객체 0** | 00 §O41·§O42 |
| 🟢 **가드 역효과(내부)** | **1 해소** | **[2026-08-05 O42]** O40-B 가 넣은 `on_schema_change: fail` 이 타입 오탐으로 팩트 10종 ERROR·145 SKIP 유발(컬럼 불일치는 0건). ✅ `append_new_columns` 로 해소 — 타입 변경 미처리 + `source_columns` 반환으로 O40 차단 유지. ⚠️ 내부 매크로 오버라이드는 서버측 런타임에서 발화하지 않아 폐기(P84). 🟠 잔여 = **O42-B**(조용한 반올림 20컬럼 스케일 검토) · **O42-C**(자동 ALTER 드리프트 감시) | 00 §O42 |
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

> **▶ 🔴 거버넌스 변경 — 정본 컬럼정의서의 코드 관련 위상을 참고본으로 강등 [2026-08-03 O24→O25→O26 아크 결론]**
> **이 항목은 이후 모든 세션의 작업 방식을 바꾸므로 먼저 읽어야 한다.** 결정 정본 = **30 DEC-26**(DEC-16 위상표 개정 포함) · 진단 정본 = **10 §13-E**.
> **(1) 왜 강등했는가** — 정본 컬럼정의서가 **불완전할 뿐 아니라 틀렸다**는 것이 실측으로 확정됐다: **누락**(CM017 이 실제 성별 라벨축인데 지정 0건) · **오지정**(`RQEST_RST_CD`→PM021 은 사전 코드 1개 vs 원천 101종 · `IRSD.AREA_CD`→CM011 은 지표 공#131 약칭 정의와 불일치) · **이중지정**(`CARD_DIV_CD`→PM044/PM052). 결정적으로 **현업에 갱신 의지가 없다**(2026-08-03 확인) → **기다려서 해소되지 않는다**.
> **(2) 무엇이 강등되고 무엇이 남는가** — 강등: **코드그룹ID · 코드값 정의 · 라벨 정의**. 정본 유지: **컬럼 존재 여부** · **비고·특이사항·경고문** · 지표 정의(지표사전 공#). 🟢 **비고를 남긴 이유는 그 축이 두 번 옳았기 때문**이다 — O24 `RDCAMT_YN`("안 바뀌는 경우도 있음")·O26 `SEX`("성별만으로는 사용하지는 않음") **둘 다 비고가 경고했고 우리가 무시한 것이 결함의 직접 원인**이었다(신규 **P30**).
> **(3) 앞으로 어떻게 확정하는가 (P29 3단계)** — ① 원천 코드사전(`CRM_CODE`) × **실적재 `distinct`** × 지표사전 값정의 **3원 대조** ② **판정 근거를 COMMENT 에 명시**(무엇과 대조해 무엇으로 정했는지) ③ `accepted_values` 가드로 도메인 고정. ⚠️ **`USE_YN='Y'` 를 필터로 쓰지 말 것** — 폐지코드가 실적재에 남아 있어(`STOP_REASON` 20종 중 6종) 필터를 걸면 라벨이 조용히 사라진다. **최초 적용례 = CM017 채택**(근거는 '정본 지정'이 아니라 '공#130 값정의 5종 일치'), 현업 확인은 **차단이 아니라 병렬**로 돌린다(20 §H).
> **(4) 파생 — 대조 스캔이 필수가 됐다**: 문서10 **§12-H #8**(P27 정례화 = 전 코드성 컬럼 ↔ `CRM_CODE` 도메인 대조)이 **선택 과제에서 필수로 승격**. 컬럼정의서가 코드 정본이 아닌 이상 **대조 스캔 외에 코드 정본을 확정할 수단이 없다**. 종전 "현업 회신 대기"였던 **SVL-1·SVL-2 도 대조 확정 후보**로 재분류(10 §13-I #6).
> **(5) 신규 교훈 P29~P33** = 문서10 §13-G. **P29**(정본이 stale 하면 대조가 정본을 만든다 — 단 강등은 **틀린 축에 한정**) · **P30**(문서의 경고문 무시가 결함의 직접 원인 — 2회 반복) · **P31**(하드코딩 라벨은 사전과 조용히 갈라지고 `ELSE` 가 도메인 확장을 은폐) · **P32**(동명이의 해법은 개명 vs 값복원 2가지이며 기준은 **원천 충실도** — 개명으로 파괴를 덮으면 영구화된다) · **P33**(개명은 COMMENT 를 데려오지 않는다 — `RENAME COLUMN` 이 구 COMMENT 를 승계하고 DDL 정본 수정은 물리에 전파되지 않는다).
> **(6) 문서 위생 2건 정리**: ⚠️ 실존하지 않는 참조 `30 §07_코드체계_관문측정`(O25·O26 관련문서 열이 지목) → **관문측정 G1~G5 원자료를 10 §13-A 에 정본으로 신설**하고 참조를 교정 · ⚠️ **`P24` 번호 충돌**(문서30 DEC-17-A ↔ 문서10 §11-G) → `P24`=§11-G 확정, DEC-17-A 분은 **`P24-B`** 재부여(10 §13-H).
> **(7) 🔴 본 검토에서 신규 결함 발견·교정 — 물리 16컬럼** = 문서10 **§13-F-2**. O26 "완료" 보고 후 물리 객체를 대조하니 **개명 8건이 구 COMMENT 를 그대로 물고 있었다**(`RENAME COLUMN` 이 COMMENT 를 승계 + `CREATE OR REPLACE` 금지라 DDL 정본 수정이 물리에 전파 안 됨) — `GOLD.DIM_MEMBER.GENDER_NAME` 이 여전히 *"F→여성·M→남성·그외→미상"*(O26 이 폐기한 바로 그 체계), WIDE 3뷰가 **존재하지 않는 컬럼**(`DIM_MEMBER.GENDER`·`MEMBER_STATUS`)을 참조, SILVER 2건은 **동명이의 해소 후에도 "직접 비교·UNION 금지" 경고가 남아** 정상 조인을 막는 상태. COMMENT 는 SV `description` 으로 소비되므로 **0행 무증상 오답 경로**(AD-4·P19 유형)였다. ✅ 물리 16컬럼 `ALTER … COMMENT` + WIDE 모델 3개 `post_hook`(물리만 고치면 다음 빌드가 되돌린다) + 정본 `08_SILVER_테이블DDL` 3행 교정 후 **`INFORMATION_SCHEMA` 전수 스캔으로 잔여 0 확인**. 파생 = **§13-F-3 MM015(개발구분)↔MM010(회원상태) 혼동 경고 신설 4컬럼** — 두 그룹이 `'후원중단'` 을 공유하는데 값이 다르다(1,010,680건 vs 958,668행).
> **(8) ⚠️ 자기검토 결과 — 본 거버넌스 변경 문서화 자체의 오류 3건 정정(2026-08-03)**: ① `05_SV_DDL.sql` **"15~16행이 GRANT 파괴를 경고"는 행 지목 오류** — 15~16행은 *소유권·역할* 경고이고 GRANT 경고는 8~9행·519~520행이다(30 DEC-25 §15-D 정정) ② COMMENT 교정 **"13건"은 집계 오류, 실제 16컬럼**(결함표 행번호를 조치 건수로 오전사·SILVER `SEX` 2컬럼 누락 · 10 §13-F-2 정정) ③ **§13-I #4 "21건(53−조치 32)" 의 괄호 산식은 날조** — 21 은 O25 자기집계 인용값이고 32 는 *보존* 건수이므로 그 산식은 성립하지 않는다(산식 삭제·재계수 필요 명시). 🔴 **가장 중요**: **§13-A 관문측정 G1~G5 는 본 세션이 재측정한 것이 아니라 선행 세션 결과의 2차 인용**이다 — "정본"은 *위치*의 정본이지 재검증 결과가 아니며, 인용 시 해당 항목만 재측정하고 측정일을 병기해야 한다(§13-A 서두에 명시). WARN 25 "전부 기존" 판정도 **개수 일치 근거뿐이고 집합 대조는 하지 않았다**(§13-F 단서 추가) — 단 "O26 유래 0" 은 신설 `accepted_values` 가드 전건 pass 로 확증됨.

> **▶ 🟢 최신 상태 [2026-08-04 O36 — 재현 순서 정본 감사·교정]** — 정본 = 문서10 **§20-G**
> 트리거: 사용자 질의 *"BRONZE 만 있는 새 계정에서 이 순서로 실행하면 되나?"* → **답은 아니다**였고
> 확인 과정에서 **정본 3곳의 오류**가 드러났다. 순서 문서는 지금까지 **누구도 실행 가능성을 검증하지 않았다.**
> 🔴 **① 런북 §11.2-B 5단계가 폐기 파일을 지시**: `13_SV_AD_배포_추가작업.sql` = `[DEPRECATED 2026-07-31]` ·
>   **주석 아닌 라인 0개**(`grep -vc` 실측). 파괴는 없지만 **「했다」는 착각**을 만든다.
> 🔴 **② 같은 목록에 `09_2` 가 아예 없었다** — 이것이 O35 에서 실측된 「Agent 스펙 = 도구 0개·instruction 0개」의
>   **직접 원인**이다. `09_1` 은 설계상 껍데기만 만든다.
> 🔴 **③ `deploy_dbt_project.sql` Step 5 가 틀린 파일을 지목**: SERVING helper 뷰를 `02_SERVING_setup.sql` /
>   `07 §E+§G` 에서 만들라고 했으나 전자는 스텁이고 **`07` 에는 `DIM_MONTH`·`DIM_MEMBER_CURRENT` 가 한 줄도 없다**.
>   실제 정본은 `08_After_Deploy_DBT.sql` §G — **런북 §11.3-B 가 이미 자기교정한 내용인데 전파되지 않았다**(P62-B).
> ✅ **조치**: 런북 §11.2-B 교정(13 삭제 · `09_1`/`09_2` 분리 · 미실행 증상 · 역할 경고) · **런북 §11.2-C 신설**
>   (신규 계정 0~⑧ 표 · 실행 역할·산출물) · 의존관계 표 3행 추가 · `deploy_dbt_project.sql` Step 5 전면 교정 ·
>   문서10 §19-I 에 교정 경고 삽입.
> 🟢 **사용자 제시 순서의 결함 3건 규명**: 0단계(`07_ENVIRONMENT_RBAC_setup.sql`) 누락 → `06_DDL.sql` **41~42행**
>   (`USE ROLE GN_DW_ADMIN`·`USE WAREHOUSE GN_DW_DEV_WH`)에서 즉사 · `dbt build` 누락 · **`09_2` 누락**.
>   GOLD↔SILVER DDL 순서는 상호 의존이 없어 무해.
> ✅ **P62-B 자기적용 — 인용처 전수 회수**: `grep -rn` 으로 폐기 파일 3개(`13_SV_AD`·`09_AGENT_spec_구현`·
>   `02_SERVING_setup`)의 인용처를 훑어 **7개 문서의 실행 지시를 교정**했다(이력 기록은 보존).
>   `02/00_INDEX.md` · `07_ENVIRONMENT_RBAC_setup.sql` · `08_After_Deploy_DBT.sql` · `05_SV_DDL.sql` ·
>   `05_SV-Agent_ai/00_README.md`(주의사항 7·8 및 비활성 표의 「캠페인·지역·연령대 미적재」 = P61 계열도 함께 회수) ·
>   `10_SI연결_검증.md` · `12_paid_테스트_실행가이드.md`.
>   🔴 **회수 규모가 결함의 성격을 보여준다** — 파일 2개 폐기로 **7개 문서가 동시에 거짓**이 됐고
>   3개월 가까이 아무도 밟지 않아 발견되지 않았다. 실제로 재구축해 본 뒤에야 드러났다.
> 🟢 **신규 교훈 P62·P62-B**(문서10 §20-G): 순서 문서는 **파일이 실행 가능한지까지** 검증해야 정본이다
>   (`grep -vc "^--\|^$"` 로 실행 라인 수를 센다) · **자기교정은 전파되지 않는다**(인용처를 `grep` 으로 찾아 함께 고친다).
>
> **▶ 🔴 최신 상태 [2026-08-05 O41 — D/O 스크립트 stale 판정 + 2차 재구축 미완 실측]**
> 트리거: 사용자 질의 *"`03_top-down_gold/` 의 `D`·`O` 접두 문서 6종이 이미 적용돼 stale 한가?"*
> **답 = 6종 전부 구조·COMMENT 기준 stale 이다.** 근거는 문서가 아니라 **물리 실측**이다(P33).
>
> 🟢 **판정 (2026-08-05 `INFORMATION_SCHEMA` 전수 대조)** — 6종의 산출물이 전부 정본에 접혀 있고,
>   금일 재구축이 **정본 DDL 만 실행한 상태에서 물리에 그대로 재현**됐다 = 스크립트 없이도 복원된다.
>   · `DEC30_STRUCTURE_ALTER.sql` → `06_DDL.sql` 236·259·287·301~323·386·603·776·797·798·993~995 접힘.
>     물리 확인: `DIM_SEND_TYPE` 12컬럼 · `FSE.SEND_TYPE_SK` · `DIM_EVENT.RECRUIT_HEADCOUNT` ·
>     `FEP.PARTCPT_SEQ` · `DIM_GA_SOURCE.DEFAULT_CHANNEL_GROUP` 존재 / DROP 5컬럼 전건 소멸
>   · `O27_DIM_MEMBER_ALTER.sql` → `06_DDL.sql` 100~120 접힘. 물리 `DIM_MEMBER` **30컬럼**(ADD 4·DROP 3 반영)
>   · `O28_O29_COMMENT_GUARD.sql` → FACT·테이블 COMMENT 는 `06_DDL.sql` 777~803·694 접힘 ·
>     WIDE 분은 모델 `post_hook` 이 소유(`WIDE_EVENT_PARTICIPATION.sql`·`WIDE_AD_BROADCAST.sql` 실측 확인)
>   · `O30_REBUILD_DRIFT_REPAIR.sql` → 고치려던 드리프트가 소멸. SILVER 개명 2건이
>     `08_SILVER_테이블DDL_20260714.sql` 240·374 에 접혀 물리에 재현됨(`MBRFEE_`·`PSTMTR_` 확인)
>   · `O39_COMMENT_GUARD.sql` → `06_DDL.sql` 491·493·578 접힘 · WIDE 2뷰는 모델 `post_hook` 보유
>   · `O40_PAYMENT_SCOPE_FIX.sql` §1 → `06_DDL.sql` 442·443·468 접힘(`PAID_FEE_BILLABLE`·`UNPAID_BILLED_AMT`)
>
> 🔴 **그러나 「stale = 무해」가 아니다 — 재실행이 정본을 되돌리는 것 2건**
>   ① `DEC30 §1` 의 `SEND_TYPE_L` COMMENT 는 **정본보다 구버전**이다. 정본(`06_DDL.sql:314`)은
>      *"🔴정본 #133 과 불일치 — #133 6종 vs 실측 9종"* 경고를 담았는데 스크립트는 종전
>      *"정본 값정의: 결연/회비/…"* 뿐이다 → 재실행하면 **경고가 지워진다**(P33 역방향).
>   ② `O40 §1-B` 의 「**적재 대기**」 문구는 build 완료로 사문화됐고 정본에서 제거됐다 →
>      재실행하면 정상 지표에 "대기 중" 이 되살아난다(O28·O29 에서 겪은 사문화 주석 유형).
>   ③ `O30 §1` 의 `RENAME COLUMN` 은 **멱등이 아니다**(헤더는 멱등이라 적었다 — 구 이름이 없어 ERROR).
>   ⇒ 조치 후보 = 6종 `_archive/` 이관 또는 헤더에 `[APPLIED · 재실행 금지]` 명시.
>      **검증쿼리 절(§3~§6)은 살아 있는 자산**이므로 통째 폐기하지 말 것.
>
>   ⇒ ✅ **조치 완료(2026-08-05, 사용자 결정) — 6종 `03_top-down_gold/_archive/` 이관**.
>      각 파일 선두에 `[APPLIED 2026-08-05 · 재실행 금지]` 배너 + **정본 위치·물리 실측 근거·
>      살아 있는 자산(검증쿼리 절)·재실행 시 부작용**을 명시했다. 검증쿼리는 폐기하지 않았다.
>      🟢 **P62-B 인용처 회수 6곳**(실행 지시·경로 지목만 교정 · 이력 기록은 보존):
>      `30_설계_의사결정.md:925`(DEC-30 실행 순서 지시 → 취소선+APPLIED) ·
>      `02_GN_DW_building/06_RUNBOOK.md:595`(재현 순서 목록의 「선택」 → 「실행 대상 아님」) ·
>      `06_DDL.sql:100·792` · `03_테이블 설계.md:459·503` ·
>      `10_dbt_pipeline/models/gold/fact/FACT_EVENT_PARTICIPATION.sql:11` ·
>      `_archive/O28_O29_사문화_COMMENT_2건_20260804.sql:10·18`.
>      ⚠️ `10_dbt_pipeline/logs/`·`target/` 의 인용은 build 산출물이라 교정 대상이 아니다.
>
> 🔴 **부수 발견 — 정본 문서 1건이 아직 거짓을 말한다**: `10_WIDE VIEW 코멘트.sql:507`
>   `EVENT_KIND COMMENT 'DIM_EVENT.EVENT_KIND — 온라인/오프라인'`. 이 문구는 O28 이 실측으로
>   **거짓 판정**(실제 도메인 `EVENT`/`CRMN`)해 회수한 것이고 dbt 모델은 회수본을 갖고 있으나,
>   **WIDE COMMENT 정본 파일만 미반영**이다 → 이 파일로 재생성하면 `=''온라인''` 0행 오답이 부활한다.
>   `O28_O29_COMMENT_GUARD.sql §3-3`(기대 0행) 이 잡도록 설계된 바로 그 경로다.
>
> 🔴 **더 큰 발견 — 환경이 지금 「2차 재구축 미완」 상태다(O30 재발 유형이나 원인은 다르다)**
>   실측 2026-08-05: 전 스키마 **01:43 재생성** · GOLD 29테이블 01:45 · BRONZE_CRM 01:48~49 ·
>   `DIM_MEMBER_CURRENT` 뷰만 02:08(`GN_DW_ENGINEER`=dbt) 생성.
>   · **데이터 0** — BRONZE_CRM `TM_MM_FDRM_MBER_INFO`·`TM_MM_FDRM_MBER_DVLP_AMT`·`TC_CMMN_DTL_CD`
>     직접 `COUNT(*)` **전부 0** · SILVER 38테이블 0행 · GOLD 29테이블 0행
>   · **BRONZE 미완** — `BRONZE_CRM` **24테이블뿐**이고 `BRONZE_ERP`·`BRONZE_AGENCY`·`BRONZE_GA4` 는
>     스키마만 있고 **테이블 0개**
>   · **GOLD 뷰 전멸** — WIDE 10종·`DIM_MEMBER_CURRENT` 중 뷰는 **1개뿐**(build 가 조기 실패한 형태)
>   · **SERVING 객체 0** — SV 7종·Agent 2종 부재(O30 때와 동일)
>   ⚠️ **작업조건 #3 를 이번엔 만족시킬 수 없었다** — BRONZE 가 비어 있어 스크립트에 적힌 실측치
>     (`2,291,878`·`38,470,780`·`21.58%` 등)를 **재검증할 수단이 없다**. 따라서 위 판정은
>     **구조·COMMENT 계층에 한정**이며 값 계층은 미검증이다. 재적재 후 재측정 필요(PROC-3 (c)).
>   ⏸ **정지 지점**: 재적재·`dbt build` 는 **작업조건 #5** 에 따라 사용자 입력 대기.
>
> 🟢 **O41 재적재 가능성 실측 — 원천은 살아 있다(2026-08-05)**
>   계정 자체가 **신규 트라이얼 `kd96599`**(SNOWFLAKE DB 01:37 프로비저닝 = 이전 `kd03246` 아님)이고
>   `SHOW SHARES` 에 GN_DW 관련 inbound 0 · `SHOW STAGES IN DATABASE GN_DW` **0건** 이라
>   한때 "재적재 원천 없음"으로 보였다. 🔴 **그 판단은 틀렸다** — 스테이지는 `GN_DW` 가 아니라
>   **`SANDBOX.TOOLS.MIG_LOAD_STAGE`**(마이그레이션 정본 경로)에 있다:
>   · `LIST` 실측 **300파일 · 3.14GB** = BRONZE_CRM **43테이블 277파일 2.97GB** ·
>     AGENCY 4/6 · ERP 1/1 · GA4 2/16(0.17GB). 업로드 08:42~08:56 UTC(=01:42~01:56 -0700)
>   · 기대 51 중 **`BRONZE_GA4.SYNC_ERR_INFO` 만 파일 없음** — 원본이 빈 테이블이라 언로드 산출물이
>     없는 것이며 결손이 아니다(문서 §6.1 이 이 2개를 예외로 명시)
>   ⇒ **A→B→로컬 재수행 불요.** `05_데이터마이그 C_CONSUMER.sql` 부터 재개 가능하다.
>
> 🔴 **재구축이 어디서 멈췄는지 특정** — `50_handoff/04_..BRONZE_DDL_20260730.sql` 이 **24번째에서 중단**됐다.
>   생성된 24개가 파일 내 `create or replace TABLE` 순서의 **정확한 프리픽스**(끝 = `TM_MM_FDRM_MBER_IRSD`
>   = 파일 679행 · 다음은 698행 `TM_MM_FDRM_MBER_RE_SPNSR`)다. AGENCY·ERP·GA4 는 스키마만 존재.
>   ⚠️ 업로드(01:56 종료)와 DDL(01:48~49)이 **겹쳐 실행**됐다 — 인과는 미규명.
>
> 🔴 **여기에 무증상 함정이 있다(신규)**: `05` §A.3 프로시저 `LOAD_BRONZE_SCHEMA` 는
>   `INFORMATION_SCHEMA.TABLES` 를 **순회**해 `COPY INTO` 한다 → **테이블이 없으면 그 테이블을 조용히
>   건너뛴다.** 지금 상태에서 §A.4 를 그대로 실행하면 CRM 24개만 적재되고
>   `'schema BRONZE_CRM loaded tables: 24'` 를 **성공처럼 반환**하며, ERP·AGENCY 는 `loaded tables: 0`
>   이 되는데 **ERROR 가 아니다.** ⇒ **DDL 51 완성이 COPY 의 선행 조건**이며, 완료 판정은
>   반환 메시지가 아니라 `43/4/1/3` 테이블 수 대조로 해야 한다.
>
> 🟢 **확인된 재개 순서**(정본 = `50_handoff/01_데이터마이그레이션 20260730.md §10` · 런북 §11.2-C)
>   ① `50_handoff/04_..BRONZE_DDL_20260730.sql` **전체 재실행** — 전 구문이 `create or replace TABLE`
>      이고 현재 데이터가 0행이라 재실행이 안전하다(기대: CRM 43·AGENCY 4·ERP 1·GA4 3 = **51**)
>   ② `05_데이터마이그 C_CONSUMER.sql` §A.1 스테이지 검증(**기대 0행** — 헤더 혼재·중복 파일) →
>      §A.2 `FF_CSV_LOAD` → §A.4 `ERP→AGENCY→CRM` → §A.5 **GA4 는 프로시저 금지·개별 COPY**
>      (VARIANT 11컬럼 `TRY_PARSE_JSON`. 프로시저로 넣으면 JSON 이 문자열이 되어 `col:key` 탐색 불가)
>   ③ §A.6 검증 = 스키마별 행수 · 빈 테이블 0 · GA4 `event_params` `TYPEOF`=ARRAY
>      ⚠️ **B 계정이 없으므로 §6.1 의 「B↔C 대조」는 불가**하다 → 기준은 §6.2 이력
>      (CRM 112,512,161 · GA4 287,025 · AGENCY 235,572 · ERP 2,041)이며 이는 **48테이블 시점**
>      측정치다. 어긋나면 원인 규명 전 인용 금지(PROC-3 c)
>   ④ 런북 §11.2-C **①② 는 이미 완료**(GOLD 29·SILVER 38 생성 + O27/DEC-30/O39/O40 구조 반영 확인) →
>      ③ `10_dbt_pipeline/deploy_dbt_project.sql`(신규 계정은 Step 1-1→2→3) → ⏸ **④ `dbt build`
>      = 작업조건 #5 정지선** → ⑤ `08_After_Deploy_DBT.sql`(§G helper 뷰) → ⑥ `05_1`~`05_7` SV →
>   ⑦ `09_1` → ⑧ `09_2`(🔴 이 단계 누락이 O35 「Agent 껍데기」의 직접 원인)
>
> 🟢 **O41 재적재 실행됨 — BRONZE·SILVER 정상 · GOLD 는 DIM 만 (실측 2026-08-05 17:50)**
>   · **BRONZE 전량 적재** — CRM 43테이블 **112,512,201행** · AGENCY 4/243,550 · ERP 1/6,336 ·
>     GA4 3/576,441. 빈 테이블 = `BRONZE_GA4.SYNC_ERR_INFO` **1건뿐**(원본 빈 테이블 = 기대된 예외)
>     ⚠️ 문서 §6.2 이력(CRM 112,512,161)과 **+40행** 차 · ERP 2,041→6,336 · AGENCY 235,572→243,550.
>        이력은 **48테이블 시점**이고 ERP 는 컬럼 62→64 변경본이라 단순 비교 대상이 아니다 → 미대조 잔여
>   · **SILVER 38테이블 112,108,325행** · 빈 테이블 = `CRM_BIZ_TARGET` **1건뿐** = **E-6 하드블로커**
>     0행 스켈레톤이라 정상 상태다
>   · 🟢 **BRONZE→SILVER 손실 0 검증(개발 체인 표본)** — `TM_MM_FDRM_MBER_DVLP_AMT` ↔ `CRM_MEMBER_DEV`:
>     행수 **3,594,843 = 3,594,843** · 고유회원 **1,585,949 = 1,585,949** ·
>     `SUM(SPNSR_AMT)` **15,712,188,652 = 15,712,188,652** · `DVLP_DIV_CD` 5종 = 5종 · 전 항목 동일
>   · 🟢 **SILVER→GOLD DIM 검증(`DIM_MEMBER`)** — 정본 기대값과 전항 일치:
>     SCD2 버전 **7,925,716** · 회원 **1,763,065**(= SILVER `CRM_MEMBER` 1,763,065 · 손실 0) ·
>     **현재행 1,763,065 = 고유회원 1,763,065**(D2 가드레일 통과·중복 현재행 0) ·
>     `SEX` **8종**(O26 CM013 복구) · `GENDER_NAME` **5종**(공#130) ·
>     `AREA_CD` **19종**(CM018 18 + 센티넬 0 = O27 판정과 일치) ·
>     `REGION` 채움 **96.91%** · `AGE_BAND` **97.63%** — **O27 기록치와 소수점까지 동일**
>     ⚠️ `PREV_MBER_STAT_CD` 93.71% 는 정본에 대응 기대값이 없어(O27 기록은 원천 측 100%/7,501,761) 미대조
>
> 🔴 **그러나 GOLD FACT 12개 전건 0행** — DIM 17개는 전부 채워졌는데 FACT 는 하나도 없다
>   (`FACT_MEMBER_MONTHLY`·`FACT_MEMBER_EVENT`·`FSE`·`FEP`·`FGA`·`FAD_*`·`FACT_BUDGET`·
>   `FACT_TARGET_*`·`FACT_MEMBER_COHORT` 직접 `COUNT(*)` = 0). WIDE 뷰도 여전히 **0개**
>   (GOLD 뷰 = `DIM_MEMBER_CURRENT` 1개뿐).
>   ⚠️ **DIM/FACT 경계에서 정확히 갈린 형태**이므로 원인은 셋 중 하나다 — ① build 선택자가 DIM 만 포함
>   ② 첫 FACT 에서 ERROR 후 나머지 SKIP ③ FACT 단계 미실행. **원인 미규명 상태로 진행 금지**
>   (FACT 는 `incremental+append+pre-hook TRUNCATE` 라 부분 적재가 조용히 남을 수 있다).
>   ⚠️ `INFORMATION_SCHEMA.TABLES.LAST_ALTERED`·`ROW_COUNT` 가 **신뢰 불가**였다 — DIM 이 채워졌는데도
>   `LAST_ALTERED` 는 적재 이전 시각(02:08)을 가리켰다. 판정은 직접 `COUNT(*)` 로만 할 것(신규 P79 후보).
>   ⏸ `dbt build` 재실행은 **작업조건 #5** 정지선 — 사용자 입력 대기.

>
> **▶ 🔴 최신 상태 [2026-08-05 O42 — `on_schema_change: fail` 가드가 팩트 13종 중 10종을 죽였다]**
> 🔴 **트리거**: 사용자 질의 *"build 하다가 에러가 났는데 이게 뭐때문인지 모르겠다"* → GOLD FACT 전건 0행의 원인.
> 🟢 **로그 확보 경로(신규 지식 P80)**: 워크스페이스 `10_dbt_pipeline/logs/dbt.log` 는 **01:11~01:16 것뿐**이라
>   쓸 수 없었다. 실행은 배포 객체 `GN_DW.OPS.DW_PIPELINE` 의 `EXECUTE DBT PROJECT` 였고 로그는
>   **Snowflake 안**에 있다 → `SNOWFLAKE.INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY()` +
>   **`SYSTEM$GET_DBT_LOG(query_id, 1000000)`**. 파일 로그만 보고 "로그가 없다"고 판단하면 안 된다.
>
> 🔴 **실행 이력 3건 전수**(2026-08-05, 이 프로젝트의 **유일한** 실행들):
>   `parse` 02:05:48 SUCCESS · `compile` 02:06:06 SUCCESS · **`build` 02:06:28~02:08:50 `HANDLED_ERROR`**
>   에러코드 210012 · 결과 **`PASS=221 WARN=21 ERROR=10 SKIP=145 TOTAL=397`**
>
> 🔴 **단일 원인 — 10건 전부 동일 에러**: `Compilation Error … The source and target schemas on this
>   incremental model are out of sync!` (macro `process_schema_changes`)
>   실패 10 = `FACT_BUDGET`·`FACT_SERVICE_EVENT`·`FACT_AD_BROADCAST`·`FACT_EVENT_PARTICIPATION`·
>   `FACT_AD_DIGITAL`·`FACT_MEMBER_EVENT`·`FACT_TARGET_DEV`·`FACT_AD_PERFORMANCE`·`FACT_TARGET_BIZ`·
>   `FACT_GA_BEHAVIOR`. 🟢 통과 = `FACT_AD_BROADCAST_CASE`(5,340행).
>   `FACT_MEMBER_MONTHLY`·`FACT_MEMBER_COHORT` 는 ERROR 가 아니라 **SKIP**(상류 FME 실패의 하류)
>   → **10 ERROR + 2 SKIP = 빈 팩트 12개**로 실측과 정확히 일치. DIM 17종은 `gold.fact` 설정 밖이라
>   `on_schema_change` 기본값 `ignore` 로 정상 적재됐다 — **DIM/FACT 경계에서 갈린 이유가 이것**이다.
>
> 🔴 **결정적 사실 — 막으려던 결함은 하나도 없었다**: 10개 모델 전부
>   `Source columns not in target: []` · `Target columns not in source: []` = **컬럼 집합 완전 일치**.
>   발화 원인은 **`New column types` 뿐**이고 총 **101컬럼**이며 전부 정상 표현식 타입이다:
>   · 센티넬 리터럴 `0`/`1` → `NUMBER(1,0)` (DDL `NUMBER(38,0)`) — FSE 22·FEP 16 의 대부분
>   · `HASH()` → `NUMBER(19,0)` · `TRY_TO_NUMBER()` → `NUMBER(38,0)`(DDL `MONTH_KEY NUMBER(6,0)`)
>   · 비율·나눗셈 → `FLOAT`·`NUMBER(24,6)`·`NUMBER(38,12)` · `SUM(NUMBER(18,2))` → `NUMBER(38,4)`
>   ⇒ **정본 DDL 이 넓은 타입을 선언하고 모델은 센티넬·해시·나눗셈을 낸다** = 이 파이프라인의 **정상 상태**다.
>   `append` 는 삽입 시 캐스팅하므로 실제 무해했고, 종전 build 들이 통과해 온 이유도 이것이다.
>
> 🔴 **자기결함 — 가드 도입 검증이 반쪽이었다**: `dbt_project.yml:78` `+on_schema_change: fail` 은
>   **2026-08-05 O40-B 에서 처음 도입**됐고(P82 · O40 신규 컬럼 무증상 폐기 차단 목적) **도입 후 첫 build 가
>   바로 이 build 다** — 회귀가 아니라 **신규 도입 결함**이다.
>   같은 줄 주석은 *"적용 전 13개 팩트 전량 컴파일 대조로 드리프트 0 확인(2026-08-05)"* 이라고 적었는데
>   그 대조는 **컬럼만** 봤다. dbt 의 `fail` 은 **컬럼 + 타입**을 함께 diff 하고 하나라도 있으면 던진다.
>   → 주석이 **거짓 안전 신호**를 준 사례. 교정 대상(P33 ③).
>   🟢 **신규 교훈 P83 후보**: 가드를 도입할 때는 *가드가 무엇을 diff 하는지*를 구현 수준에서 확인하고
>   **일부러 발화시켜 실효성을 확인**해야 한다(P26 의 역방향 — 통과도 실증해야 한다).
>
> 🔴 **비판적 재검토(사용자 지시) — 내 종전 진술 1건이 과했다**
>   종전에 *"타입 차이는 무해하다"* 고 단정했으나 **101컬럼 전수 대조(로그 추론타입 ↔ `INFORMATION_SCHEMA`
>   선언타입)** 결과 그렇지 않았다:
>   · **안전 58**(DDL 이 같거나 더 넓음 — 센티넬 `NUMBER(1,0)`→`NUMBER(38,0)` 등)
>   · **정수부 축소 24**(초과 시 **INSERT 실패** = 큰 소리. `DATE_SK 38,0→8,0`·`MONTH_KEY 38,0→6,0`·
>     `AGE_AT_EVENT 10,0→2,0` 등. YYYYMMDD·YYYYMM·나이는 실제로는 자릿수에 들어가고,
>     벗어나면 실패하는 편이 **바람직한 가드**다)
>   · 🔴 **조용한 반올림 20** = FLOAT→정수 3(`AD_CNT`·`READ_CNT`·`MEDIA_POTENTIAL_CUST_CNT`) ·
>     FLOAT→스케일 13(`CTR_SRC`·`CPC_SRC` 등 비율류) · 소수부 축소 4(`IMPRESSIONS`·`CLICKS`·
>     `INBOUND_CALL`·`GA_CONV_MEMBERS` `38,4→38,0`)
>   ⇒ **"무해"는 틀렸다.** 정확한 진술은 *"`on_schema_change` 값과 무관하게 동일하게 발생한다"* 다 —
>   INSERT 는 어차피 대상 컬럼 타입으로 캐스팅하므로 `fail` 을 켜 둔다고 반올림이 막히지 않았다
>   (오히려 build 가 죽어 데이터가 0행이었을 뿐이다). 스케일 적정성은 **타입 가드 사안이 아니라
>   DDL 설계 검토 사안** → 🟠 **O42-B 로 분리 등재**(조용한 반올림 20컬럼 스케일 적정성 검토).
>
> 🟢 **그럼에도 B안이 성립한다 — 근거는 어댑터 원본 확인(추론 아님)**
>   `dbt-snowflake 1.9.2` 의 `snowflake__diff_column_data_types` 는
>   `sc.data_type != tc.data_type and not sc.can_expand_to(other_column=tc)` 로 판정하고
>   `can_expand_to` 는 **문자열 전용**이다 → **숫자 컬럼의 어떤 폭 차이도 예외 없이 플래그**된다.
>   그리고 `fail` 이 제시하는 해법 3개가 이 프로젝트에서 전부 금지다:
>   ① 자동 ALTER(정본 거버넌스 위반·기존 기각) ② `full_refresh`(CTAS 가 DDL·제약·주석·FK 파괴 →
>   `+full_refresh: false` 가 걸린 이유) ③ 수동 스키마 변경(정본 DDL 을 표현식 추론 타입에 맞춰
>   넓히라는 뜻 = 거꾸로). ⇒ **해소 경로 없는 영구 교착**이므로 좁히는 것이 옳다.
>
> 🔴 **다만 B안 원안(singular test)은 구현 불가였다 — 설계 수정**
>   singular test 는 모델이 **build 된 뒤** 실행되고, `ignore` 로 되돌리면 버려진 컬럼이 **흔적을
>   남기지 않는다**(테이블 = 모델 산출물 그 자체). 즉 test 로는 O40 실패양상(모델에만 있는 컬럼)을
>   **원리적으로 탐지할 수 없다.**
>   🟢 결정적 발견: `default__process_schema_changes` 는 non-ignore 일 때 **`source_columns`(모델 컬럼)**
>   를 반환하고 materialization 이 그것을 `dest_columns` 로 쓴다. `ignore` 면 `{}` 를 반환해
>   **대상 테이블 컬럼으로 fallback** — 이 fallback 이 O40 무증상 폐기의 실체다.
>   ⇒ **`ignore` 복귀 자체가 O40 을 재도입한다.** 원안을 그대로 실행했다면 결함을 되살렸을 것이다.
>
> ✅ **조치 완료 — `fail` 유지 + 전역 매크로 프로젝트 오버라이드로 「컬럼 집합 전용 가드」로 축소**
>   · 신설 `10_dbt_pipeline/macros/gn_on_schema_change.sql` = `snowflake__process_schema_changes`
>     오버라이드. 컬럼 추가·삭제 → **즉시 실패**(조치 절차를 에러 메시지에 명시) /
>     타입 차이 → **로그만 남기고 통과** / 반환 계약 `source_columns` **보존**(O40 차단 유지) /
>     `append_new_columns`·`sync_all_columns` 는 dbt 기본 동작에 위임.
>     🔴 `default__` 는 정의하지 않았다 — 정의하면 위임 호출이 무한 재귀한다.
>   · `dbt_project.yml:67~92` 교정 — 종전 *"13개 팩트 전량 컴파일 대조로 드리프트 0 확인"* 은
>     **거짓 안전 신호**였음을 명기(그 대조는 컬럼만 봤다). 값은 `fail` 유지.
>   · 🟢 검증: `dbt parse --project-dir /10_dbt_pipeline` **통과**(dbt=1.9.4 · snowflake=1.9.2 =
>     배포 객체와 동일 버전) · 매크로명 충돌 없음 · Jinja 오류 없음.
>   · ⚠️ 유지보수 부채 등재: dbt 내부 매크로 오버라이드다 → dbt-core/dbt-snowflake 업그레이드 시
>     `default__process_schema_changes` 원본과 **반환값 계약(source_columns)** 대조 필수.
>   ⏸ **잔여 = 배포 + build**: 워크스페이스 파일 변경은 `ALTER DBT PROJECT … ADD VERSION` 으로
>     새 버전을 올려야 `EXECUTE DBT PROJECT` 에 반영된다(현재 `VERSION$1`). 그 다음 `build`.
>     **작업조건 #5 정지선 — 사용자 입력 대기.**
>     build 후 검증 3관문: ① ERROR=0 · SKIP 대폭 감소 ② 팩트 13종 전부 비0행(직접 `COUNT(*)`)
>     ③ WIDE 뷰 10종 생성 확인.
>
> 🔴 **[2026-08-05 18:14 재시도 실패 — 오버라이드가 발화하지 않았다]**
>   사용자가 `EXECUTE DBT PROJECT FROM WORKSPACE … project_root='/10_dbt_pipeline' args='build --target dev'`
>   실행 → **동일 결과**(10 실패 · 91.99s). 🔴 에러 문구가 **dbt 원본 영문 그대로**이고 스택도
>   `macros/materializations/models/incremental/on_schema_change.sql` 이다 → 내 매크로가 아니라
>   `default__process_schema_changes` 가 실행됐다.
>
>   🟢 **배제된 원인 2개(실측)**
>   · 파일 미배포 아님 — `LIST 'snow://workspace/…/versions/live/10_dbt_pipeline/macros/'` 에
>     `gn_on_schema_change.sql` **8,080바이트 · 06 Aug 01:08:09 GMT** 존재. build 는 01:14:55 GMT 로 **이후**다
>     (`head` 도 동일 내용 — 개인 워크스페이스라 commit 이슈 아님)
>   · 등록 누락 아님 — build 가 갱신한 `target/manifest.json` 에
>     **`macro.gn_dw_silver.snowflake__process_schema_changes` 존재**
>
>   🟢 **dispatch 탐색 순서는 오히려 우리 편이었다(프로브 실측)** — 임시 매크로로
>     `adapter.dispatch('…','dbt')` 를 호출해 실패 메시지에서 탐색 순서를 그대로 받아냈다:
>     `'gn_dw_silver.snowflake__…', 'gn_dw_silver.default__…', 'dbt.snowflake__…', 'dbt.default__…'`
>     → **루트 프로젝트 + 어댑터 접두가 최우선**이다. 즉 오버라이드 기법 자체는 옳다.
>
>   🔴 **진짜 용의자 = 서버측 프로젝트 스냅샷/파스 캐시 stale**
>     프로브 매크로를 **내용만 바꿔 덮어쓰자** 직전 실행에서 정상 호출됐던 같은 이름을
>     *"could not find a macro with the name … in any package"* 로 반환했다.
>     워크스페이스 `target/partial_parse.msgpack` 삭제 후에도 동일 → 캐시는 워크스페이스가 아니라
>     **서버측 실행 샌드박스(`/tmp/dbt`)** 에 있다고 보는 것이 정합적이다.
>     ⇒ `EXECUTE … FROM WORKSPACE` 는 **파일 갱신 반영 시점이 불확정**이다. 18:14 build 가
>     내 매크로 없는 스냅샷을 실행했다는 설명과 일치한다.
>   ⚠️ 부수 확인: **로컬 샌드박스 dbt 런타임 ≠ 서버측 런타임**. 로컬에는 `snowflake__diff_column_data_types`
>     가 있으나 서버측에는 **없다**(프로브 탐색 실패로 확인) → §O42 의 "어댑터 원본" 인용은
>     **로컬 기준**이었다. 결론(숫자 타입 차이는 전부 플래그)은 `default__diff_column_data_types` 에서도
>     동일하나, **런타임 대조 없이 로컬 소스를 정본처럼 인용한 것은 절차 결함**이다(P33 계열).
>
> 🔴 **[2026-08-05 18:37 (가)안도 실패 — 오버라이드 기법 자체를 폐기]**
>   배포 경로를 갖췄다: `ALTER DBT PROJECT` → **`VERSION$2`**(alias `PIPE_TEST_RULE_20260806`, 18:33:26) ·
>   `parse` 18:33:41 SUCCESS · `compile` 18:33:59 SUCCESS. 🟢 배포 스냅샷에 매크로 실재 확인 —
>   `LIST 'snow://dbt/GN_DW.OPS.DW_PIPELINE/versions/version$2/macros/'` → `gn_on_schema_change.sql` 8,080B.
>   🔴 그런데 build(85.88s)가 **또 dbt 원본 영문 문구**로 실패했다(10 실패 · 동일 타입 목록).
>   ⇒ 워크스페이스 실행·배포객체 **양쪽 모두** 오버라이드가 발화하지 않는다.
>   ⚠️ **스냅샷 캐시 가설도 기각**: 직후 `dbt parse` 가 *"Unable to do partial parsing because a project
>      config has changed"* 를 냈다 = 워크스페이스 파일 변경은 **서버측에 정상 도달**한다.
>      즉 원인은 배포·캐시가 아니라 **Snowflake 서버측 dbt 런타임의 dispatch 가 루트 프로젝트의
>      `snowflake__process_schema_changes` 를 채택하지 않는다**는 것이다(로컬 소스 기준 탐색 순서와
>      불일치 — 런타임 구현 차이. 원인 미규명·재현 가능).
>   ✅ **발화하지 않는 가드는 거짓 안전 신호**이므로 `macros/gn_on_schema_change.sql` **삭제**했다.
>      (판정·근거는 본 절에 보존 — 파일만 제거)
>   🟢 **신규 교훈 P84 후보**: 관리형 런타임(Snowflake dbt)에서 **내부 매크로 오버라이드에 의존하지 말 것.**
>      로컬 dbt 소스로 검증한 dispatch 동작이 서버측에서 재현되지 않는다. 문서화된 **config 값**으로
>      해결 가능한 길이 있으면 그것을 택한다.
>
> ✅ **[2026-08-05 18:41 최종 조치 — `+on_schema_change: append_new_columns`]**
>   dbt 원본 동작으로 필요 요건이 전부 충족된다(내부 매크로 의존 0):
>   · `sync_column_schemas('append_new_columns', …)` 는 **타입 변경을 처리하지 않고**
>     `source_not_in_target` 만 ALTER → 현재 그 집합이 **공집합**이므로 **완전 no-op** = 타입 오탐 소멸
>   · `'ignore'` 가 아니므로 `process_schema_changes` 반환이 **`source_columns`(모델 컬럼)** 이고
>     그것이 INSERT 의 `dest_columns` 가 된다 → **O40 무증상 폐기 차단 유지**
>     (⇒ 애초에 `ignore` 복귀는 답이 아니었다는 §O42 판단은 유효)
>   · `dbt parse --project-dir /10_dbt_pipeline --target dev` **통과**
>   🟠 **O42-C 신규 등재(감시)**: 훗날 모델에만 있는 신규 컬럼이 생기면 dbt 가 **자동 ALTER** 하므로
>     물리가 `06_DDL.sql` 보다 앞서 나갈 수 있다(O30 유형 드리프트). 컬럼 추가 절차 ①~⑥ 준수 필수 ·
>     정기적으로 물리 컬럼 ↔ `06_DDL.sql` 대조.
>   ⏸ **build 는 작업조건 #5 정지선** — 재배포(`ADD VERSION`) 또는 워크스페이스 실행 후
>     검증 3관문: ① ERROR=0 ② 팩트 13종 전부 비0행(직접 `COUNT(*)`) ③ WIDE 뷰 10종 생성.
>
> 🟢🟢 **[2026-08-05 18:51 해소 확인 — O42 종결 · O41 파이프라인 완주]**
>   사용자 build 결과 **`Done. PASS=370 WARN=27 ERROR=0 SKIP=0 TOTAL=397`**
>   (`Found 81 models, 316 data tests, 40 sources, 483 macros` · full parse). 종전 `ERROR=10 SKIP=145` 소멸.
>   ⇒ **`append_new_columns` 조치가 실효**했음을 *변화로* 확인했다(P26).
>
>   ✅ **관문 ① ERROR=0 · SKIP=0** — 통과
>   ✅ **관문 ② 팩트 13종 직접 `COUNT(*)`** — 12종 적재 · 1종만 0행이고 그것은 **기대된 0**이다
>     `FMM` **40,054,883** · `FSE` **38,470,780** · `FME` **4,633,105** · `FMC` **1,585,949** ·
>     `FEP` **1,134,126** · `FAD_PERF` 243,545 · `FAD_DIGITAL` 205,059 · `FACT_BUDGET` 75,996 ·
>     `FGA` 68,836 · `FAB` 38,486 · `FTG_DEV` **25,344** · `FAB_CASE` 5,340 ·
>     🟡 `FACT_TARGET_BIZ` **0 = E-6 하드블로커**(CRM 사업목표 원천 미입고 · `SILVER.CRM_BIZ_TARGET` 도 0행)
>     → 결함이 아니라 스켈레톤 정상 상태
>   ✅ **관문 ③ GOLD 뷰 14종** — `DIM_MEMBER_CURRENT` + **WIDE 13종**
>     (`WIDE_MEMBER_MONTHLY`·`_MEMBER_EVENT`·`_SERVICE_EVENT`·`_EVENT_PARTICIPATION`·`_GA_BEHAVIOR`·
>      `_BUDGET`·`_TARGET_DEV`·`_TARGET_BIZ`·`_DEV_ACHIEVEMENT`·`_AD_PERFORMANCE`·`_AD_BROADCAST`·
>      `_AD_BROADCAST_CASE`·`_AD_DIGITAL`)
>
>   🟢 **O42-C(자동 ALTER 드리프트) 첫 점검 — 깨끗하다**: GOLD **기본 테이블 컬럼 502개**로
>     build 전과 **동일**(종전 측정 522 는 `DIM_MEMBER_CURRENT` 뷰 20컬럼 포함값) →
>     `append_new_columns` 가 **아무것도 ALTER 하지 않았다** = 예측대로 완전 no-op.
>     이 점검(물리 컬럼수 ↔ `06_DDL.sql`)을 build 마다 반복하는 것이 O42-C 방어선이다.
>
>   🟢 **부수 확인 — O38 교정이 실제로 살아났다**: `FACT_TARGET_DEV` **25,344행**
>     (종전 7,272 = 3.49배 병합 결함) · `MONTH_KEY` **201201~202612** · YYYYMMM 규약 위반 **0건** ·
>     `SUM(GOAL_CNT)` **4,622,103** = 원천과 정확히 일치. O38 W1(`STDYY||LPAD`)과 singular test 가 동작한다.
>
>   ⬜ **잔여**: ① **WARN 27건** 내역 미확인(종전 21 → 27 로 증가 · 기존 고아키 계열로 추정되나 **미검증**)
>
> 🟢🟢🟢 **[2026-08-05 19:02 O41 종결 — 런북 §11.2-C ⑤~⑧ 완료(사용자 실행)·전 계층 실측 검증]**
>   · ⑤ **SERVING helper 뷰 2종** `DIM_MONTH`(18:59:39) · `DIM_MEMBER_CURRENT`(18:59:40) ✅
>   · ⑥ **Semantic View 8종** 18:59:56~19:01:54 ✅ + `SERVING.FACT_AD_COMBINED`(19:01:26) =
>     `SV_MEMBER_MONTHLY`·`SV_MEMBER_EVENT`·`SV_MEMBER_COHORT`·`SV_SERVICE`·`SV_EVENT_PARTICIPATION`·
>     `SV_BUDGET`·`SV_AD`·**`SV_DEV_ACHIEVEMENT`**(O38 신설)
>   · ⑦⑧ **Agent 2종** `AGENT_MEMBER`·`AGENT_OVERALL`(19:02:26·19:02:29) ✅
>     🟢 **O35 「껍데기 Agent」 재발 없음 — `DESCRIBE AGENT` 로 스펙 본문 실측 확인**:
>     `AGENT_MEMBER` = tools **6종**(analyst_member_monthly·_member_event·_service·_member_cohort·
>     _event_participation·**_dev_achievement**) + instructions(system/orchestration/response) +
>     `tool_resources` 6종 SV 매핑 + `sample_questions` 19문 · default **VERSION$3** ·
>     `AGENT_OVERALL` = tools **4종**(analyst_budget·_ad·_member_monthly·_service) · default **VERSION$3**.
>     ⇒ `{"models":{"orchestration":"auto"}}` 만 있는 껍데기 상태가 **아니다** = `09_2` 정상 적용.
>   🟢 **O38 배선이 소비계층까지 관통했다**: `SV_DEV_ACHIEVEMENT` 실재 + `AGENT_MEMBER` 에
>     `analyst_dev_achievement` 도구로 등재 + orchestration 에 *"목표·달성율 질문은 반드시
>     analyst_dev_achievement"* 라우팅 명문화. 마케팅 장표 「1. 개발현황(목표,실적)」 경로 완성.
>   🔴 **문서 stale 1건 교정**: 런북 §11.2-B 4) · §11.2-C ⑥ 이 *"SV 6종"* 이라고 적고 있었다 —
>     실측 **8종**(O37 분할 이후 `SV_MEMBER_COHORT`·`SV_DEV_ACHIEVEMENT` 추가분 미반영).
>     양쪽 다 8종으로 교정하고 목록을 명기했다(P33 ③).
>
>   ⬜ **최종 잔여 2건**
>     ① **WARN 27건 내역 미확인**(종전 21 → 27) — 기존 고아키 계열 추정이나 **미검증**. 확인 필요.
>     ② **paid 게이트** — Agent NL 스모크(`DATA_AGENT_RUN`)는 트라이얼에서 차단(문서40 §paid 게이트).
>        SV 데이터층 ground-truth 검증은 트라이얼에서도 가능하므로 정확성은 확인할 수 있다.
>
> ✅ **[2026-08-05 19:2x O41 잔여 2건 종결 — WARN 전수 분류 + SV ground-truth]**
>
> 🟢 **잔여① WARN 27건 전수 분류 — 회귀가 아니다(증가분의 정체 규명)**
>   🔴 **"21 → 27 로 6건 늘었다"는 비교 자체가 성립하지 않았다.** 실패 build(01c62ee2) 로그를 다시
>   훑으니 그 21건은 **전부 SILVER** 였다(GOLD yml 출처 0건). GOLD 팩트 테스트는 모델이 ERROR/SKIP 이라
>   **실행조차 못 했다**. 성공 build = SILVER 21 + **GOLD 6** = 27. ⇒ 27 이 **첫 완전 측정치**다.
>   추가된 GOLD 6 = `FACT_SERVICE_EVENT`·`FEP`·`FME`·`FMM`·`FMC` 의 `MEMBER_DK`→`DIM_MEMBER`
>   relationships 5건 + `FEP.PART_STATUS` accepted_values 1건.
>   🟢 **SILVER 21건은 yml 주석의 기지값과 건수까지 일치**(회귀 0) — `CRM_SEND_MEMBER.SNDNG_KEY` 11,313 ·
>   `MBER_NO` NULL 745 · `CRM_PAYMENT_BILLING.RQEST_RST_CD` 1,096 · `CMPGN_TYPE1_NM` 740 ·
>   `CMPGN_CTGR_NM` 23 · `SPNSR_BSNS_ID` 1 등 전부 기록치와 동일.
>   ⚠️ **내가 중간에 한 번 틀렸다**: `CMPGN_TYPE1_NM` 740건을 *"코드는 있는데 라벨이 없다 = 코드사전
>   매핑 실패 = 신규 결함"* 으로 판정했는데, yml 이 `where: CMPGN_TYPE1_BSN IS NOT NULL` 로 **바로 그
>   경우만 세도록 설계**돼 있고 주석에 *"기지 고아: CMPGN_TYPE1_BSN=4, 740행"* 으로 이미 적혀 있었다.
>   테스트 정의를 먼저 읽지 않고 값만 보고 판정한 절차 결함이다(신규 **P85** 후보: 테스트 WARN 을
>   해석하려면 그 테스트의 `where` 필터를 먼저 읽어야 한다 — 분모를 모르면 값의 의미를 모른다. P21 계열).
>   🟢 **고아 회원키 = 단일 원인·외부 의존 확정(실측)**: 4개 SILVER 테이블의 고아를 합집합하면
>   **고유 회원 9,247명**(문서50 BLOCKING-1 기록 9,248 과 사실상 동일). 이들을 BRONZE 회원 마스터
>   (`TM_MM_FDRM_MBER_INFO` ∪ `TM_MM_ONCE_MBER_INFO`)와 대조 → **존재 0명 · 부재 9,247명**.
>   동시에 BRONZE 마스터 키 **1,763,065 = SILVER `CRM_MEMBER` 1,763,065** 로 완전 일치.
>   ⇒ SILVER 로직 결함이 **아니라** 원천 입고 누락이다. **BLOCKING-1(회원 마스터 전량입고) 대기**이며
>   전량 입고 시 warn→error 복귀 대상. GOLD 5건은 이 9,247명의 하류 전파일 뿐이다.
>   🟡 **잔존 실결함 1건**: `FEP.PART_STATUS` 오염값 **`)` 2행**(테스트는 distinct 값 1로 보고).
>   O28 이 기록한 *"오염값 `)` 2행"* 과 동일 — 재구축 후에도 그대로 남았다. O28 잔여로 유지.
>
> 🟢 **잔여② SV ground-truth 검증 — 통과(paid 불요 구간)**
>   `SV_DEV_ACHIEVEMENT` × 직접 SQL 대조(2022~2026 연도별): `TOTAL_GOAL_CNT`·
>   `TOTAL_ACTUAL_CNT_ON_GOAL`·`ACHIEVEMENT_RATE` **5개 연도 전부 MATCH**(소수 6자리까지).
>   🟢 **4계층 무손실 실증**: `SUM(GOAL_CNT)` = BRONZE **4,622,103** = SILVER = GOLD = WIDE = **SV** 동일.
>   🟢 **정본 스코프 재현**: 미스코프 **49.59%** · 정본 `GOAL_CNT>0` **34.60%** ·
>   실적 총계 **2,291,878** · `WIDE_DEV_ACHIEVEMENT` **37,522행** — P63 기록치와 전부 일치.
>   ⇒ SV metric 식에 `GOAL_CNT>0` 을 못박은 조치가 **배포 후에도 유효**함을 확인.
>   🟢 **O40 납부율도 3수치 완전 일치**(2025): `PAID_FEE_BILLABLE` **175,381,890,496** ·
>   `UNPAID_BILLED_AMT` **29,251,314,636** · 납부율 **85.65%** = O40 기대값과 동일.
>   ⚠️ `ORG_DEPARTMENT='(미매핑)'` 3행·실적 6건(무시 가능 규모) — O38 기록 "미매칭 8행"과 동계열.
>   ⏸ **여기서 멈추는 구간**: Agent 자연어 응답 품질·응답시간·비용은 `DATA_AGENT_RUN` 차단으로
>     **paid 계정 이관 후 측정**(문서40 §paid 게이트 · 절차 = `05_SV-Agent_ai/12_paid_테스트_실행가이드.md`).


>

> **▶ 🟡 최신 상태 [2026-08-05 O38 — 개발목표 연도 소실 교정 · 부서별 실적 배선 · 목표 대비 실적 소비뷰]** — 정본 = 문서10 **§22**
> 🔴 **트리거**: 사용자 질의 *"마케팅 장표 「1. 개발현황(목표,실적)」 13항목이 지금 GOLD 에 있는가?"* →
>   답은 **온전히 답하는 것 1개(예산구분)뿐**이었고, 확인 과정에서 **미등록 결함 2건**이 드러났다.
>
> 🔴 **① O38 `FACT_TARGET_DEV.MONTH_KEY` 연도 소실 (신규 · 무증상)**
>   모델이 `TRY_TO_NUMBER(t.STDR_MT)` 로 **기준월만** 쓰고 `STDYY`(기준연)를 버렸다.
>   정본 DDL 은 `MONTH_KEY NUMBER(6,0) '목표월 YYYYMM'` 을 명시하므로 **정본 규약 위반**이다.
>   · 실측: BRONZE `TM_CM_MBER_DVLP_GOAL` **25,344행 · STDYY 15개 연도(2012~2026) · grain 유일**
>     → GOLD **7,272행** = **3.49배 병합**. `SUM(GOAL_CNT)` 4,622,103 은 원천과 **정확히 일치**했다.
>   · 그래서 *"2026년 1월 목표"* 를 물으면 **2012~2026년 1월 목표의 합**이 조용히 반환됐다.
>   🔴 **무증상 이유가 핵심**: 행수·SUM·참조무결성이 전부 정상이고 `MONTH_KEY` 에는
>     **dbt 테스트가 한 건도 없었다**(yml 에 `ORG_SK` 만). 값 검사로는 잡히지 않는 **규약 결함**이다.
>   ⚠️ **기존 이슈 A(`MONTH_KEY` 비-YYYYMM)와 별건** — A 는 `FACT_MEMBER_MONTHLY` 소관이다.
>   ⚠️ `WIDE_TARGET_DEV.CAL_YEAR` 전건 0 의 원인은 **DIM_DATE 조인 실패·센티넬이 아니다** —
>     이 뷰는 DIM_DATE 를 조인하지 않고 `FLOOR(MONTH_KEY/100)` 산술을 쓴다(자릿수 부족).
>
> 🔴 **② `FACT_MEMBER_EVENT.ORG_SK` 전건 센티넬 → 부서별 실적 산출 불가 (O10/Q7 실체)**
>   실측 **4,633,105/4,633,105 전건 0** · `FACT_MEMBER_MONTHLY` 에는 컬럼 자체가 없다
>   → **GOLD 전체에 부서별 회원실적 축이 없었다**. measure(`DEV_CNT`)만 보면 "있다"로 오판하기 쉽다.
>   🟢 **이미 등재돼 있었다** — 문서20:314 가 기획실 요건을 *"부서별 × **일자별** 개발 건"* 으로
>     정확히 이 장표로 기재하고 있었다. 🔴 그런데 **P2(외부/현업 의존)로 분류돼 있었고 그것이 stale** 이다:
>     결정(O10 = 실적부서 `ACMSLT_DEPT_CD`)·원천·매칭률이 전부 준비돼 있었다.
>   · 실측: `ACMSLT_DEPT_CD` DIM_ORG 매칭 **3,594,835/3,594,843 = 99.9998%**(미매칭 8행) · distinct 349
>   · 목표↔실적 conform 확인: `DEV_TYPE` 목표 도메인 **{1,2,4} = 정본 공#121 개발 정의와 정확히 일치** ·
>     목표 조직 **234 ⊆ 실적 349** · 목표에만 있는 조직 **0**
>
> ✅ **조치 (dbt build 앞에서 정지 · 작업조건 5)**
>   · **W1** 모델 `FACT_TARGET_DEV` → `STDYY || LPAD(STDR_MT,2,'0')` + `month_key_clamp`.
>     신규 가드 = yml `MONTH_KEY` not_null · `DEV_TYPE` `accepted_values {1,2,4}` ·
>     **singular test `assert_ftg_dev_month_key_yyyymm`**(YYYYMM 규약. ⚠️`dbt_utils` 미설치라 schema 테스트 불가)
>   · **W2** 모델 `FACT_MEMBER_EVENT` dev 브랜치 `ORG_SK` 배선(`DIM_ORG.ORG_DK` 조인 = FTG_D 와 동일 경로).
>     🔴 STOP 브랜치는 0 유지 — **축 부재가 아니라 역할 불일치**다(중단원천은 `REGIST_DEPT_CD`
>     **등록부서** 보유: 채움 925,948/1,038,262=89.2% · distinct **54** · 매칭 100%). 개발측은 실적부서
>     **349종** — 6배 차이를 한 컬럼에 섞으면 O24·O28 의미혼입 → **O38-B 결정 대기**
>   · **W3** **`WIDE_DEV_ACHIEVEMENT` 신설**(WIDE 10번째) = FTG_D × FME **FULL OUTER** 월 conform.
>     장표 정본이며 정본 지표 **공#1·#2·#3** 산출 base
>   · 정본 동기화(P57·P59): `06_DDL.sql`(FTG_D 4컬럼·FME `ORG_SK`) + **물리 `ALTER COLUMN COMMENT` 5컬럼** +
>     `09_빅테이블 VIEW.md §3-A` · `10_WIDE VIEW 코멘트.sql §3-A` · `05_필드 인벤토리.md` ·
>     `02/03_GOLD_SERVING.md` · `WIDE_MEMBER_EVENT` post_hook(`ORG_DEPARTMENT` DEV 전용 경고)
>
> 🟢 **build 전 검증 전항 통과(실측 시뮬레이션)**
>   · W1: grain **25,344 유일** · `SUM(GOAL_CNT)` **4,622,103 불변** · 201201~202612 · 센티넬 0 · 변환실패 0
>   · W2: **fan-out 0**(3,594,843 불변) · `DEV_CNT` **2,291,878 불변** · 센티넬 8
>   · W3: 연도별 grain 유일 · ~~완결연도 달성율 **2022 58.3% · 2023 59.3% · 2024 53.8% · 2025 54.4%**~~
>     🔴 **[2026-08-05 19:2x 정정 — 이 수치는 미스코프 값이었다]** 같은 절이 P18·P63 으로 *"미스코프
>     (전체 실적÷전체 목표)는 틀린 값"* 이라고 선언했는데, 정작 이 W3 수치가 **그 미스코프로 산출**됐다.
>     build 후 실측 재현 = 미스코프 **2022 58.8 · 2023 59.4 · 2024 54.0 · 2025 54.5**(기록치와 동일 계열)
>     vs **정본 스코프(`GOAL_CNT>0`) 2022 52.5% · 2023 44.3% · 2024 40.0% · 2025 39.8%**.
>     ⇒ 2023 은 **15.1%p** 차이다. 인용 시 반드시 정본 스코프 값을 쓸 것.
>   · **신규 가드 실효성 실증(P26)**: singular test 를 현 데이터에 돌려 **위반 12키·7,272행 검출** 확인.
>     build 후 0 이 되어야 한다 — 가드가 실제 상태를 반영함을 *변화로* 확인했다
>
> 🔴 **달성율 스코프 = `GOAL_CNT > 0` 로 확정 (P18·P63) — 중간에 내가 한 번 틀렸다**
>   ① 미스코프(전체 실적÷전체 목표) **49.59%** ② `HAS_GOAL`(목표 행 존재) 스코프 **41.16%**
>   ③ 정본 `GOAL_CNT>0` 스코프 **34.60%**. **②도 틀린 값**이다.
>   🔴 원인: CRM 은 **목표를 `0` 으로 등록한 행**을 다수 보유한다 — 목표 행 **25,344 중 14,667행(57.9%)**.
>   이 행들은 `HAS_GOAL=TRUE` 라 실적 **303,235건**이 분자에 들어가는데 분모 기여는 0 이다.
>   SV 최초 배포에서 이 조건을 써서 **증액 537.1% · 재후원 1700.9%** 가 나왔다.
>   교정 후 전 구분 100% 이하: **신규 34.3% · 증액 65.9% · 재후원 74.3%**.
>   → 뷰에 **비율 컬럼을 두지 않고**(행 단위 비율의 평균은 항상 틀린다) `SUM/SUM` 재계산을 강제하고,
>   SV metric 식에 `GOAL_CNT>0` 을 **못박아** Analyst 가 틀릴 수 없게 했다.
>   선례 = `WIDE_BUDGET` 이 집행율을 두지 않고 `SV_BUDGET` 이 산출.
>
> 🔴 **본 세션 자기결함 6건** (전수 기록 — 상세 = 문서10 §22-F)
>   ① yml 에 `FACT_MEMBER_EVENT.ORG_SK` 테스트를 **중복 추가** → `dbt compile` 이 잡았다.
>      원인 = `grep -A20` 결과만 보고 "가드 없음"으로 단정(관측 범위 부족 · P14 유형).
>      🟢 부수 발견: 기존 `ORG_SK` relationships 가드는 `where ORG_SK != 0` 이라 전건 0 상태에서
>      **항상 0행을 검사하는 무력 가드**였다(P26 유형 — 정상처럼 보였다) → **P69**.
>   ② `dbt_utils.expression_is_true` 사용 시도 → **패키지 미설치**(trial EAI 불가로 자작 매크로 대체).
>      `dbt compile` 로 확인 후 singular test 로 전환. **P64 재확인**.
>   ③ 🔴 **singular test 의 Jinja 공백제거 마커가 `select` 를 주석 처리 → `dbt build` ERROR 1**.
>      마커가 **앞뒤 개행을 함께 삭제**해 `select` 가 직전 `--` 주석 줄에 흡수됐다
>      (`syntax error unexpected 'MONTH_KEY'`). **compile 을 실제로 돌렸는데** 여러 노드 중
>      `WIDE_DEV_ACHIEVEMENT` 출력만 읽고 **테스트 산출물을 확인하지 않아** 놓쳤다 → **P70**.
>      교정 중 2차 결함: 재발방지 주석에 마커 문법을 예시로 적었더니 Jinja 가 `--` 주석 안에서도
>      파싱해 `tag name expected` 로 깨졌다 → **P71**(Jinja 는 SQL 주석을 주석으로 보지 않는다).
>      🔴 **파급이 크다**: 테스트 ERROR 가 하위를 SKIP 시켜 **`WIDE_DEV_ACHIEVEMENT`(주 산출물·신설)
>      가 아예 생성되지 않았다** → **P72**(신설 객체의 SKIP = 아예 없음. ERROR 와 SKIP 을 함께 읽는다).
>   ④ 🔴 **SV 달성율 분자를 `HAS_GOAL` 로 스코프해 증액 537% · 재후원 1700% 를 배포**했다.
>      「목표 행 존재」와 「목표 편성」을 같은 것으로 취급한 것이 원인이다(목표 0 행 57.9%).
>      O37 에서 **185% 를 겪고 12개월 고정률로 해결한 적이 있는데도** 조건을 잘못 골라 재발시켰다
>      → **P73**(비율 스코프는 행 존재가 아니라 분모 값의 유효성 · 비율 metric 은 100% 초과를 필수 스모크).
>   ⑤ 🔴 **SV 를 `ACCOUNTADMIN` 으로 만들어 소유권이 어긋났다** — 다른 7종은 `GN_DW_ADMIN` 이고,
>      **내가 같은 파일 헤더에 그 경고를 적어놓고 위반**했다. `COPY CURRENT GRANTS` 로 교정.
>      → **P74**(세션 역할은 파일이 요구하는 역할과 다를 수 있다. `USE ROLE` 을 실제로 실행하거나
>      생성 직후 owner 를 실측한다 — "헤더에 적었다"는 준수의 근거가 아니다).
>   ⑥ 🔴 **SV COMMENT 에 "조직 축이 활성화됐다"고 적었으나 차원 선언이 없었다** — 검증 없이 서술했다.
>      O37 자기결함 ③과 **동일 유형의 재발**이다 → **P75**(축 활성화 주장은 COMMENT 가 아니라
>      **차원 선언 + 실제 분해 쿼리**로 증명한다. "활성" 문구를 쓰기 전에 그 축으로 group by 해 본다).
>
> 🟢 **build 실행 결과 [2026-08-05, 사용자 실행]** — `PASS=366 WARN=27 ERROR=1 SKIP=2 TOTAL=396`
>   · **W1 적재 검증 전항 통과(실측)**: `FACT_TARGET_DEV` **25,344행** · grain `(MONTH_KEY,ORG_SK,DEV_TYPE)`
>     **25,344 유일** · **201201~202612** · 월키 **180종**(15년×12) · 센티넬 0 ·
>     `SUM(GOAL_CNT)` **4,622,103 불변** · `DEV_TYPE` 3종
>   · **W2 적재 검증 전항 통과(실측)**: FME **4,633,105 불변(fan-out 0)** · `DEV_CNT` **2,291,878 불변** ·
>     `ORG_SK` 센티넬 **1,038,270 = STOP 1,038,262 + DEV 미매칭 8**(예측치 정확) ·
>     **STOP 행 조직 누출 0** · 조직 350종(349 + 센티넬)
>   · `WIDE_TARGET_DEV.CAL_YEAR` **0건 → 15개 연도**(전건 0 이었던 것이 살아났다) ·
>     `WIDE_MEMBER_EVENT` 개발 사건 **부서 280종 조회 가능**(종전 전건 (미매핑))
>   · **신규 singular test 재실행 결과 0행** — build 전 12키/7,272행 검출 → 교정 후 위반 0(P26 완결)
>   🔴 **ERROR 1 = 내 결함 ③** (데이터·모델 문제 아님). SKIP 2 = `WIDE_TARGET_DEV`·`WIDE_DEV_ACHIEVEMENT`.
>   ✅ 테스트 교정 후 컴파일 산출물 **직접 확인** 완료.
>
> ✅ **대상 한정 재실행 완료** — `PASS=3 WARN=0 ERROR=0 SKIP=0`. 팩트 재적재 없이 뷰 2개 + 테스트만 갱신.
>   · `WIDE_DEV_ACHIEVEMENT` **37,522행 · grain 유일** · `SUM(GOAL_CNT)` 4,622,103 = FTG_D 총계 ·
>     `SUM(ACTUAL_CNT)` 2,291,878 = FME `DEV_CNT` 총계(양쪽 **손실 0**) · `DEV_TYPE_NAME` 라벨 NULL **0**
>   · 누계·연 파생 검증: 12월 `GOAL_CNT_YTD` == `GOAL_CNT_YEAR` 일치 확인(월 누적 정상)
>
> ✅ **소비 계층 전량 완료 (2026-08-05 라이브)**
>   · **`SV_DEV_ACHIEVEMENT` 신설·배포**(SV **8종**) — 장표 정본. 정본 `05_8_SV_DDL_DEV_ACHIEVEMENT.sql` 신설.
>     단일 논리테이블(조인 0 → fan-out 위험 0) · PK `(MONTH_KEY,ORG_SK,DEV_TYPE)` 유일 실측.
>     스모크 전항 통과: SV 총계 == base 총계 · **100% 초과 0행** · 부서/구분/연도 축 전부 답을 냄.
>     🟢 **누계·연 전용 metric 을 만들지 않았다** — 목표·실적이 가산이므로 기간 필터만 바꾸면
>     월(단월)·누계(1월~기준월)·연(연 전체)이 모두 나온다. 공#1·#2·#3 이 **한 식**으로 답된다.
>   · 🔴 **소유권 사고 자체교정**: 세션 역할이 `ACCOUNTADMIN` 이라 SV 소유주가 어긋났다
>     (다른 7종은 `GN_DW_ADMIN`). **내가 같은 파일 헤더에 적어둔 경고를 내가 위반했다.**
>     `GRANT OWNERSHIP ... COPY CURRENT GRANTS` 로 교정 → SV 8종 소유주 통일 실측.
>   · **`SV_MEMBER_EVENT` 조직 축 활성화 + P61 회수** — COMMENT 의 *"비활성(적재 대기): **조직**"* 이
>     거짓이 됐다. 🔴 **그런데 회수만 하고 끝낼 수 없었다**: COMMENT 에 "활성화됐다"고 적었는데
>     **SV 에 차원 선언이 없었다**(O37 자기결함 ③과 동일 유형). `DIM_ORG` 논리테이블 + relationship +
>     `ORG_DEPARTMENT` 차원을 실제로 추가하고 재배포·GRANT 3역할 재실행.
>     검증: `TOTAL_DEV_CNT` **2,291,878 불변**(조인 추가 후 fan-out 0) · 부서 축 분해 확인 ·
>     🟢 **기획실 요건 「부서별 × 일자별 개발 건」이 단일 SV 로 답을 낸다**(실측 확인).
>   · **Agent**: `analyst_dev_achievement` 도구 신설(도구 **6개**) + 라우팅·부서 분기 규칙 +
>     `analyst_member_event` description 에 부서 축 추가 + 샘플질문 4건 → **`VERSION$5` is_default** ·
>     GRANT 4종(OWNERSHIP + USAGE 3역할) 보존 실측.
>     🔴 **system instruction P61 회수**: *"미적재분(**조직**/…, **목표대비**, …)은 창작 금지"* 가
>     두 축 모두 활성이 되어 거짓이었다 — 지우지 않으면 Agent 가 "아직 없습니다"로 답한다.
>     동시에 **여전히 불가한 것**(상위 조직·매체별 목표·일별 목표)은 창작 금지로 명시 유지.
>
> ✅ **부수 — Agent 스펙 정본 이중화 해소 (사용자 지시 2026-08-05)**
>   🔴 **정본이 두 경로로 선언돼 서로 모순이었다**: `05_SV-Agent_ai/08_AGENT_spec.md` 와
>   `99_next_prompt.md §33` 은 루트 `cortex_project/AGENT_*.agent.yaml` 을 정본이라 했고,
>   `09_1`·`09_2`·`06_RUNBOOK`·`99_next_prompt §141/151/153` 은 `agents/<AGENT>/agent_spec.yaml` 을
>   정본이라 했다. **판정 기준은 「배포되는 파일이 정본」** — `09_2` 의
>   `ADD VERSION FROM <디렉터리>` 가 후자를 읽으므로 **후자가 정본**이다.
>   · 실측 대조: 루트 `AGENT_MEMBER.agent.yaml` = 도구 **4개**·샘플 **8개**·O33/O35/O38 흔적 **0**
>     (정본은 도구 6개·샘플 19개) → **O33 이전 판본**. 그 파일로 재배포하면 O33~O38 규칙 전량 소실.
>   · 루트 `AGENT_OVERALL.agent.yaml` = 정본과 **byte-identical 중복**(내용 손실 없음).
>   ✅ `cortex_project/_archive/` 신설·이관(사유·판정근거 `00_README.md` 병기 — 복원 방지)
>   ✅ `cortex-project.yaml` 교정: 이관 경로 2건 → 정본 경로 · **dangling 항목 1건 제거**
>     (`agents/AGENT_MEMBER.agent.yaml` — **내가 이번 세션 `cortex_agent_write` 로 자동 등록시킨 뒤
>     그 파일을 삭제해 매니페스트만 남긴 것**이다. 자기결함 ⑦). 전 경로 실존 검증 + workspace 읽기 재확인.
>   ✅ **인용처 전수 회수(P62-B)** 4문서: `02/03_GOLD_SERVING.md` · `05/08_AGENT_spec.md` ·
>     `05/99_next_prompt.md` · `05/01_작업계획.md`. `20_issue/*`·`05/_archive/*` 는 **이력이므로 원문 보존**.
>   ✅ `08_AGENT_spec.md §배포절차` 교정: `cortex_agent_save/deploy` 는 **live 버전**을 만들어
>     `ADD VERSION FROM` 을 **거부**시킨다 → `09_2` 경로로 일원화 명시.
>   🟢 **`AGENT_OVERALL` 부정형 서술은 「문자 그대로는 사실」임을 실측 확인**(추측 아님): *"조직별 예산"* 은
>     `FACT_BUDGET.ORG_SK` **75,996/75,996 전건 센티넬**로 사실이고, *"사업목표 대비"* 는
>     `FACT_TARGET_BIZ` **0행**(E-6 입고 대기)으로 사실이다 — 개발목표(FTG_D)와 **별개 팩트**다.
>   🔴 **그런데 「사실」인 것만으로는 부족했다 — 잠재 오답 경로가 남아 있었다(사용자 지적).**
>     `AGENT_OVERALL` 은 `analyst_member_monthly`(개발 **실적** 보유)를 갖고 있어서, 사용자가 대상을
>     안 밝히고 *"목표 달성율 보여줘"* 라고 물으면 미적재 목록의 *"사업목표 대비"* 를 근거로
>     **"목표는 아직 없습니다"** 라고 답할 수 있다 — **회원개발 목표는 이제 산출 가능한데도**.
>     🟢 **P61 의 일반화**: 부정형 서술이 *개별적으로 사실*이어도 **다른 축의 활성화로 인해 질문 단위에서
>     거짓이 될 수 있다.** 회수 판정은 「이 문장이 사실인가」가 아니라 **「이 문장으로 답하면 사용자가
>     옳은 답을 얻는가」**로 해야 한다.
>   ✅ **조치·배포 완료 (2026-08-05)** — 도구 추가 없이 **라우팅 명확화만**(예산·광고 도메인이라 개발목표
>     도구를 붙일 대상이 아니다):
>     · `system`: **"목표는 두 가지"** 절 신설 — 사업목표(FTG_B 미입고 → 산출 불가) vs 회원개발 목표
>       (산출 가능 · `AGENT_MEMBER` 소관). *"뭉뚱그려 없다고 답하지 말 것"* · 두 목표 합산·비교 금지
>     · `orchestration`: 목표·달성율 질문은 이 Agent 도구로 답할 수 없음 + `AGENT_MEMBER` 안내 규칙 ·
>       🔴 `analyst_member_monthly` 로 달성율을 만들지 말 것(**분모가 없다**)
>     · `analyst_member_monthly` description 에 「목표 없음」 명시
>     · **sample_question 에 `"개발 목표 달성율을 보여줘"` 추가** — 오답 경로를 재현하는 질문을 스펙에
>       넣어 **회귀 감시**로 쓴다(다음 NL 스모크 항목이 된다)
>     · `09_2` 경로 배포 → **`VERSION$4` is_default** · GRANT 4종 보존 실측 · live 스펙 반영 내용 직접 확인
>     ⚠️ **관찰**: 이번엔 `is_default` 가 **자동 승격**됐다(`AGENT_MEMBER` VERSION$5 때는 `false` 여서
>     명시 지정이 필요했다). 원인은 단정하지 않는다 — 그래서 **P66(발행 후 `is_default` 실측)** 이 유효하다.
>   🔴 **P76 을 사람이 읽는 문서에 적용하니 더 심각한 거짓이 나왔다** — `30_output_share/01_DW_현업활용가이드.md`
>     가 *"조직·부서별 회원개발 목표 대비 달성률 → `WIDE_TARGET_DEV` → **✅ 사용가능**"* 이라고
>     **현업에 안내**하고 있었다. **O38 이전부터 3중으로 거짓**이었다:
>     ① `WIDE_TARGET_DEV` 에는 **목표만 있고 실적이 없다** → 달성률 구조적 산출 불가
>     ② 목표 월키에 **연도가 없었다**(1~12) → "2026년 1월 목표" = 15년치 합계
>     ③ 실적 팩트의 **부서 축이 전건 미매핑**이었다
>     🟢 즉 **Agent 뿐 아니라 현업 문서도 「가능하다」고 잘못 말하고 있었다** — 이번 O38 이 세 건을 모두
>     해소했으므로 이제는 가능해졌지만, **대상 객체가 다르다**(`WIDE_DEV_ACHIEVEMENT`).
>     ✅ 가이드 교정: 대상 객체 교체 · 상태 **✅ → ◐ 부분**(상위 조직 불가·증액/재후원 목표 미편성 명시) ·
>     **정정 사유를 표 아래에 명시**(사람이 읽는 문서를 조용히 바꾸지 않는다) ·
>     「부서별 **일자별** 개발 실적」 행 신설(기획실 요건) · 로드맵 표에 **사업목표 ≠ 회원개발 목표** 경고.
>     ⚠️ `08_AGENT_spec.md` 의 OVERALL 사본에도 stale 경고 주석 삽입(P62-B).
>
> ✅ **잔여 ① 완료 — `HAS_GOAL` 개명 + `HAS_POSITIVE_GOAL` 병설 (2026-08-05, 정본 = 문서10 §22-H)**
>   🔴 **COMMENT 교정으로 끝내지 않고 개명했다.** 결함(§F-2 ④)은 COMMENT 를 잘못 읽어서 난 게 아니라
>   *"목표 편성 여부"* 라는 **서술이 컬럼명과 함께 오해를 확정**시킨 것이었다. 이름을 남기고 설명만
>   바꾸면 다음 세션이 같은 실수를 반복한다 — **서술은 구조를 이기지 못한다**(P61·P75 계열).
>   · `HAS_GOAL` → **`HAS_GOAL_ROW`**(목표 **행** 존재 · 값 0·NULL 이어도 TRUE)
>   · **`HAS_POSITIVE_GOAL` 신설**(`GOAL_CNT > 0`) = **달성율 스코프 정본**
>   🔴 **BRONZE 재스캔이 종전 O38-D 기재를 반증했다**(작업조건 3 준수 — COMMENT 를 근거로 삼지 않았다):
>   · `GOAL_CNT` **0 이 14,660행 · NULL 이 7행**(2015·2017) · 양수 10,677행
>   · 원인은 결측이 아니라 **원천의 행 생성 방식**이다 — **2020년부터** CRM 이 `부서×월×개발구분 3코드`
>     조합을 **전량 행 생성하고 미편성분을 0 으로 채운다**(2019년 1,008행 → 2020년 2,844행. 2021년만 축소)
>   · 🔴 **종전 기재 정정**: *"증액·재후원 목표가 2023년부터 0(2022년까지는 편성)"* 은 **2022년만 보고
>     일반화한 오류**였다. 실제로는 **거의 편성된 적이 없다** — 증액 **4개 연도**(2014·2019·2021·2022) ·
>     재후원 **1개 연도(2022)뿐**. **개발목표는 사실상 「신규」에만 편성된다.**
>   ✅ **신설 가드** `assert_wide_dev_achv_goal_rows_preserved` — 팩트 행수·목표합계 == 뷰의
>     `HAS_GOAL_ROW=TRUE` 행수·목표합계. FULL OUTER 가 목표 행을 흘리면 **분모가 작아져 달성율이
>     과대**해지는데 행수는 줄어 "정상"처럼 보이므로 총계 대조로는 안 잡힌다.
>     ⚠️ P64/P70 준수: 파일에 넣기 전 **live 실행**(PASS) + `dbt compile` **렌더 산출물 직접 확인**.
>   ⚠️ **세 번째 컬럼(NULL 구분)은 만들지 않았다** — 7행(0.028%)이고 달성율 산술이 동일하며
>     구분 경로가 이미 있다(`FACT_TARGET_DEV.GOAL_CNT IS NULL` — 팩트는 NULL 보존). 창작 금지(P21).
>   ⚠️ 이 객체는 **뷰**라 런북 §3.3(`ALTER TABLE`+`06_DDL.sql` 동기화)은 **해당 없다** — 절차를
>     기계적으로 적용하지 않고 대상 성격을 확인했다.
>   ✅ 정본 동기화 7곳 + 🔴 **`05_8` 스모크 D-3c 는 실행 SQL 이라 개명 시 깨진다** → `grep` 회수(P62-B).
>   ✅ **build 완료·후속 3건 전량 완료 (2026-08-05)** — 사용자 build `PASS=370 WARN=27 ERROR=0 SKIP=0 TOTAL=397`
>     · **적재 검증 9항 전항 일치**: 뷰 **37,522행**(grain 유일) · `HAS_GOAL_ROW` **25,344**(=FTG_D 행수) ·
>       `HAS_POSITIVE_GOAL` **10,677** · 미편성 **14,667** · 모순 **0** · 목표합 **4,622,103** ·
>       실적합 **2,291,878** · 달성율 **34.60%**. 교차: FTG_D 25,344·201201~202612·규약 위반 **0행** ·
>       FME 4,633,105·`ORG_SK` 센티넬 1,038,270(예측치 일치)
>     · **`HAS_POSITIVE_GOAL` 차원 = 물리 컬럼 참조로 전환 완료** — 배포본 `GET_DDL` 되읽어 확인 ·
>       전환 전후 축 분해 **완전 동일**(값 영향 0). 🟢 metric 식의 `GOAL_CNT>0` 은 **의도적 잔존**
>       (분모와 분자 스코프가 같은 컬럼에서 나와야 어긋날 수 없다 — 차원은 사용자 필터, metric 은 구조 가드)
>     · **`05_8` 스모크 D-1~D-6 전항 통과** — 🔴 **D-3b(100% 초과) 0행 유지** · D-3 `34.60 == 34.60 < 49.59` ·
>       D-5 신규 34.3%·증액 65.9%·재후원 74.3% · D-2 완결연도 2022 52.5%~2025 39.8%
>     · owner **`GN_DW_ADMIN`** · GRANT **7건 보존** 실측(`USE ROLE` 을 실제 실행 후 DDL — P74 준수)
>     ⚠️ 문서10 **§22-D 의 완결연도 달성율은 미스코프(naive) 값**이다 — D-2 의 스코프 적용값과 나란히
>       인용하면 「값이 떨어졌다」로 오독된다(산식이 다르다)
>
> 🔴 **신규 O38-E — 부서 달성율 순위가 소표본에 지배된다 (D-4 재실행에서 발견)** — 정본 = 문서10 **§22-J**
>   목표가 월 5건뿐인 소규모 센터가 **171.7% 로 1위**가 됐다. 🟢 **P73 재발이 아니다** — base 36행을 직접
>   열어 확인한 결과 분자 103 이 전부 `GOAL_CNT>0` 행에서 나왔다(증액·재후원 목표 0 은 정확히 제외) =
>   **진짜 초과 달성**이다. 실측: 목표 보유 부서 **203 중 초과 1건** · 그 부서 목표는 전체의 **0.0013%** ·
>   월×부서×구분 행 중 실적>목표 **1,198/10,677(11.2%)**.
>   🔴 그런데 **값이 맞다는 것으로 끝나지 않았다** — NL 스모크 **#4**(소표본 1위)와 동일 유형이고
>   SV 에 규모 하한 서술이 **하나도 없었다**(P76: 사실이어도 사용자가 틀린 결론을 얻는다).
>   ✅ **조치(사용자 결정)**: `ORG_DEPARTMENT` COMMENT + `AI_SQL_GENERATION` 에 **규모 동반 제시·극소 규모
>   단독 1위 금지·하한 되묻기** 가드 추가 + `05_8` D-4 판정 주석에 「이 grain 의 초과는 정상」 명시.
>   값·구조 변경 0 · 재배포 후 전항 재검증 · 라이브 DDL 로 문구 실재 확인.
>   🆕 **P77**(비율 상한 불변식은 grain 종속 · 상한 검사와 규모 하한이 **둘 다** 필요) = 문서10 §22-J
>
> ⏸ **잔여**: ① **O38-D 현업 확인**(개발목표가 신규에만 편성되는 것이 방침인가 · `GOAL_CNT=0` 행이
>   「미편성」인가 「0건 목표」인가 · 조직 개편 시 과거 목표 귀속 규칙)
>   ② NL 스모크(PRV-3, 트라이얼 계정 차단으로 사람이 UI 확인) — 권장 질문 = Agent 샘플질문 4건
>   🔴 **③ 신규 = O38-E 파생 NL 스모크**: *"달성율이 가장 높은 부서"* → 목표 규모를 함께 제시하지 않고
>     소규모 센터를 「최우수」로 결론하면 **실패**(가드가 실제로 준수되는지 확인하는 항목이다)

### ✅ O40 — 납부율·미납금액 모집단 불일치 (2026-08-05 · **종결**) — 정본 = 문서10 **§24**

> 🔴 **무증상이 아니라 이미 사고가 났다.** Agent 가 2025 납부율 **93.98%** · 총미납 **123억** 을 답했고
> GOLD 가 그 값을 정확히 재현했다 — **정의 자체가 틀려 있었다.**
>
> **원인(구조로 증명)**: `PAID_FEE = SUM(PAY_AMT)` 는 **회비∪기부금**, `BILLED_AMT = SUM(RQEST_AMT)` 는
> **회비뿐**. 기부금 원천(`TM_PM_DNTN_DTLS`)에는 **청구 컬럼이 아예 없다**(SILVER 실측 1,130,252행
> 전건 `RQEST_AMT` NULL) → 분모에 구조적으로 들어갈 수 없는 금액이 분자에만 더해진다(**P63**).
>
> | 지표 | 현행 | 정본 | 오차 |
> |---|---|---|---|
> | 2025 납부율 | 93.98% | **85.65%** | **+8.32%p 과대** |
> | 2025 미납금액 | 12,335,580,090 | **29,251,314,636** | **2.37배 과소**(169억 누락) |
> | **전 기간 납부율** | **100.36%** | — | 🔴 **100% 초과** |
> | **전 기간 미납금액** | **−3,218,518,220** | — | 🔴 **음수** |
>
> 🔴 이 SV 에는 **`>100%` 상한 스모크가 없었다** — P73 검사가 개발 달성율에만 걸려 있었다(🆕 **P80**).
> 2025 만 보면 그럴싸해서 검출이 늦었다.
>
> 🔴 **세 번째 결함**: `HAS_BILLING` 은 「회비 스코프」가 **아니다**(기저 CTE 가 회비∪기부금).
> COMMENT 가 `'TRUE=회비(billing) 원천'` 이라 회비 기준으로 믿게 만든다 — 2025 TRUE 행 안에
> 기부금 170억이 **전액** 들어 있고 청구 0/NULL 행이 **28,521건**이다. 🆕 **P81**.
>
> 🟠 **「이미 마감된 실측치」도 사실이 아니다** — 2025년분 회비가 **2026-07-01 까지** 납입됐고
> (2,454건 46,485,890원) 회비월은 **202911** 까지 존재. 연도 실적은 **적재 시점 스냅샷**이다.
>
> ✅ **① 배포 완료(build 불요)**: `SV_MEMBER_MONTHLY` 결함 metric 4종 COMMENT 에 「단독 인용 금지」+
> 실측 오차 명시 · `HAS_BILLING` 에 「회비 스코프 아님」 명시 · `AI_SQL_GENERATION` 에 납부율·미납
> 단독 제시 금지 + **「마감·확정」 단정 금지** 추가 · `'납부율'`·`'총미납금액'` **synonym 회수**.
> 값 불변 · owner·GRANT 7건 보존.
>
> 🔴 **[2026-08-05 추가] build 를 돌렸으나 신규 컬럼이 조용히 버려졌다** — `ERROR=0` 이었는데도
> `INSERT` 가 **대상 테이블의 56컬럼만** 썼다(`on_schema_change` 미설정 → dbt 기본 `ignore`).
> **"에러 없음"은 성공 신호가 아니었다.** ✅ §1 **ALTER 실행 완료**(56→58컬럼 · COMMENT 3건 ·
> 기존 값 불변) → **build 재실행하면 적재된다.** 🆕 **P82** · 🟠 잔여 결정 **O40-B** = `gold.fact`
> 9개 팩트 공통 설정이라 `on_schema_change='fail'` 도입 여부 결정 필요.
> ✅ **[종결] O40-B 적용 완료(2026-08-05)** — `dbt_project.yml` `gold.fact` 에 `on_schema_change: fail`.
> 적용 전 `dbt compile` 로 **13개 팩트의 모델 컬럼 vs 테이블 컬럼 전량 대조 → 드리프트 0** 확인,
> `dbt list --output json` 으로 유효 config 반영 확인. `append_new_columns` 미채택 이유 = GOLD DDL
> 정본이 `06_DDL.sql` 이고 자동 ALTER 는 정본과 조용히 어긋나므로 **수동 거버넌스 유지 + 불일치만 노출**.
>
> ✅ **② 재 build 성공 · 검증 8관문 전항 통과** — 신규 컬럼 비NULL 37,021,518 / 3,302,535 ·
> 2025 `PAID_FEE_BILLABLE` **175,381,890,496** · `UNPAID_BILLED_AMT` **29,251,314,636**(시뮬레이션
> 기대값·BRONZE 독립대조 **모두 정확 일치**) · 납부율 **85.65%** · 미납비중 **14.29%** ·
> 상한(>100%) 0 · 음수 0 · 미납>청구 0.
> ✅ **③ SV 정본 metric 4종 배포 완료** — `PAYMENT_RATE_FEE`·`TOTAL_PAID_FEE_BILLABLE`·
> `TOTAL_UNPAID_AMT_DEC3`·`UNPAID_RATIO_DEC3`. `'납부율'`·`'총미납금액'` 등 synonym **정본으로 이전**
> (결함 metric 에서 회수 · P79) · `AI_SQL_GENERATION` 「적재 대기」 문구 **전량 제거**.
> 🟢 **전 기간 100.36%/−32억 → 86.1923%/1,226억** 으로 정상화. 납입회비 합계가 SILVER 회비 집계와
> **정확 일치**(독립 대조).
>
> 📎 **참고 자료(구 ②)** — `03_top-down_gold/O40_PAYMENT_SCOPE_FIX.sql`
> FMM 신규 컬럼 2종: `PAID_FEE_BILLABLE`(=`PAYMENT_TYPE='회비'` 납입액 · 2025 **175,381,890,496**) ·
> `UNPAID_BILLED_AMT`(=**DEC-3** `PAY_STAT_CD IN('F',NULL)` 청구액 · 2025 **29,251,314,636** =
> BRONZE 직접 집계와 정확 일치). 🟢 **저작 전 시뮬레이션으로 검증**(모델 MONTH_KEY 재현 → 기존
> `PAID_FEE`·`BILLED_AMT` 를 GOLD 실측과 완전 일치 재현 · P70).
> 실행순서 = §1 ALTER → **§2 build(사용자)** → §3 검증(상한·음수 스모크 포함) → §4 SV metric.
>
> ⏸ **③ build 후**: 정본 metric 4종 신설 + synonym 이전 + 🔴 `AI_SQL_GENERATION` 의 **「적재 대기」
> 문구 제거**(안 지우면 정상 지표를 두고 "대기 중"이라 답한다 — 사문화 주석 유형)

---

### 🆕 O39 — `*_MEMBERS` 컬럼이 「명」이 아니다 (2026-08-05 · 조치완료) — 정본 = 문서10 **§23**

> 🔴 **결함**: `*_MEMBERS` 가 이름·COMMENT 모두 「명」이라 말하지만 실측은 **0/1 플래그**이고 `SUM` 은
> **건수**다. 에러·경고 없이 과대값이 나온다(P18 무증상).
>
> | 객체·컬럼 | `SUM` | 실제 고유회원 | 과대 |
> |---|---|---|---|
> | `FACT_MEMBER_EVENT.DEV_MEMBERS` | 2,291,878 | 1,585,923 | **44.5%** |
> | `FACT_MEMBER_EVENT.STOP_MEMBERS` | 1,038,262 | 903,064 | **15.0%** |
> | `FACT_SERVICE_EVENT.SEND_MEMBERS` | 38,470,780 | 1,031,971 | **37.3배** |
>
> 🟢 **`%MEMBERS%` 43컬럼 전수 시험 결과 패턴이 균일하지 않아 교정 대상은 3종뿐이다.**
> `FACT_MEMBER_MONTHLY.DEV_MEMBERS`(**466개월 전부** `SUM==COUNT(DISTINCT)` · 편차 0)와
> `FACT_MEMBER_COHORT.ACQ_MEMBERS`(1행=1회원)는 **옳아서 건드리지 않았다.** grain 이 다르면 같은
> 이름도 옳다 — 이름 기반 일괄 교정은 **옳은 것을 틀리게 만든다**(🆕 **P78**).
>
> 🔴 **라이브 Agent 오답 경로 1건 실재**: `SV_SERVICE` 는 옳은 `DISTINCT_SEND_MEMBERS`
> (`COUNT(DISTINCT MEMBER_DK)`)를 **이미 갖고 있었는데** synonym `'발송 회원수'` 가 건수 metric
> `TOTAL_SEND_MEMBERS` 에 붙어 있었다 → 「발송 회원수」에 **37.3배** 값을 답할 수 있었다. 결함은
> 정의가 아니라 **라우팅**이었다(🆕 **P79**). ✅ synonym 이전·배포·검증 완료(값 불변).
> 🟢 `SV_MEMBER_EVENT` 는 애초에 `COUNT(DISTINCT)` 만 노출해 결함 없음.
>
> ✅ **조치**: `03_top-down_gold/O39_COMMENT_GUARD.sql` 신설(**dbt build 불요** — FACT 은 COMMENT
> post_hook 이 없어 `COMMENT ON COLUMN` 이 영구) + WIDE 3컬럼 `ALTER VIEW` **및 모델 post_hook
> 동시 수정**(P33) + 정본 `06_DDL.sql` 교정 + `05_4_SV_DDL_SERVICE.sql` 교정.
> **검증 3관문 통과**: ①대상 6컬럼 경고 실림 ②**제외 3컬럼 미훼손** ③값 불변.
>
> ⚠️ **부수 발견(구성관리)**: GOLD **FACT 컬럼 COMMENT 는 dbt 소관이 아니다**(정본=`06_DDL.sql`,
> 모델에 post_hook 없음). build 없이 고칠 수 있는 반면 **full-refresh 로 재생성되면 `06_DDL.sql` 을
> 다시 돌려야** 복원된다.
>
> ⏸ **잔여**: ① **O39-B 전건 0 컬럼군** — `FMM` `ACTIVE_CNT`·`ACTIVE_MEMBERS`·`INCREASE_*`·
> `ACTIVE_CUM_*` **6종 40,054,883행 전건 0**(NULL 아님) · `FME` `UNPAID_STOP_*` · `FSE`
> `SUCCESS/FAIL/OPEN_MEMBERS` 등. ⚠️`ACTIVE_CNT` 는 활동회원 지표의 **분모** 축 → 영향범위 조사
> 선결 · 기존 C-9-R·B1 과 중복 가능하니 **대조 후 병합**(신규 남발 금지)
> ② **O39-C 개명 여부**(`*_MEMBERS`→`*_FLAG`) — 하류(WIDE·SV·문서·저장쿼리) 파괴 위험 →
> 영향범위 조사 후 사용자 결정
>
> ⚠️ **[2026-08-05 정정 — 문서10 §25-D]** 아래 문장은 **자기모순**이었다(다음 줄이 「예산구분 × 부서
> 교차 불가」). 정정: **불가한 것이 예산구분 1개**이고 **9개는 즉시 가능**하다. 또 매체 축 「도달 불가」는
> AGENCY(`DIM_AD_CREATIVE.MEDIA_NAME`) 경로 한정 판정이었고 **CRM `DIM_CAMPAIGN.BRAND` 경로가
> 별도로 존재하며 실적측 100%** 다. 정본 = `03_top-down_gold/05_필드 인벤토리.md`.
> 🔴 **장표 13항목 재판정(실측)** — ~~온전히 답하는 것은 **1개(예산구분)**뿐이다.~~
>   목표 계열 3종(#1·#2·#3)은 W1+W2 로 열린다 · **매체명(브랜드2)** 는 목표 원천에 축이 없고
>   (정본 마케팅 인벤토리 §1 명시) 실적측 `DIM_AD_CREATIVE.MEDIA_NAME`(106종)은 실재하나
>   `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 전건 센티넬로 **도달 불가**(P52) ·
>   **기준일시(일별)** 는 목표가 월 grain 이라 구조적으로 대응 불가(월 목표의 일자 반복은 이중계상).
>   ⚠️ 부수: `FACT_AD_PERFORMANCE` 실측 **243,545행** vs 문서 기재 **235,572** — PROC-3(c) 대상.
>   ⚠️ 부수: `FACT_BUDGET.ORG_SK` 도 전건 센티넬(75,996/75,996) → 예산구분 × 부서 교차 불가.

> **▶ 🟢 최신 상태 [2026-08-05 O37 — 캠페인별 중단률 산출 가능화 · SV 파일 분할]** — 정본 = 문서10 **§21**(신설 예정)
> 🔴 **트리거**: Agent 가 *"캠페인 축은 개발 사건에만 배선돼 있고 중단 사건에는 캠페인 정보가 원천에 없다 —
>   따라서 캠페인별 중단률은 구조적으로 산출 불가"* 라고 답했다. **이 판정은 틀렸다.**
> 🔴 **BRONZE 재스캔 결과**: 중단원천 `TM_MM_FDRM_MBER_SPNSR_DSCNTC` 에는 확실히 캠페인 컬럼이 없다(전 9컬럼).
>   그러나 **개발원천 `TM_MM_FDRM_MBER_DVLP_AMT` 의 `DVLP_DIV_CD='5'`(MM015 후원중단) 행이 `CMPGN_CD` 를
>   전건 보유**하고, 그 축은 이미 `GOLD.FACT_MEMBER_EVENT.CAMPAIGN_SK` 로 배선·적재까지 끝나 있었다 —
>   **축은 있었고 measure 만 없었다.** Agent 가 그렇게 답한 직접 원인은 SV COMMENT 의
>   *"캠페인별 중단건은 답이 나오지 않는다"* 였다 → **P61 재발**(축이 활성인데 부정형 서술 미회수).
> 🔴 **그런데 「노출하면 끝」이 아니었다** — 실측으로 두 함정을 확인했고 구조로 막았다:
>   ① 코드5 의 캠페인은 **중단 시점** 캠페인이라 신규 건수로 나누면 모집단이 달라 비율이 **100% 초과**
>      (기존회원 대상 캠페인에서 실증) → 분모를 **획득 코호트**로 잡아야 비율이 성립한다.
>   ② **누적 이탈률은 관측 기간에 지배된다** — 획득연도만으로 단조 감소하는 것을 실측
>      (오래된 코호트일수록 높다). 캠페인은 실행 연도가 달라 누적률로 비교하면 **오래된 캠페인이
>      자동으로 「중단률 높음」**이 된다. 값·매핑·채움률이 전부 정상이라 어떤 품질 테스트로도 잡히지
>      않는 **의미 결함**(P60 계열) → **12개월 고정 이탈률**을 정본으로 삼고 분자를 관측 가능 코호트로 제한.
> ✅ **GOLD 신설·확장** (물리 ALTER + 정본 `06_DDL.sql` **같은 세션 동기화**, P57):
>   · **`FACT_MEMBER_COHORT` 신설**(회원 grain 1행=1회원 · PK · FK 3 · COMMENT 누락 0) — FACT 13번째
>   · `FACT_MEMBER_EVENT` +3(`SEX_AT_EVENT`·`GENDER_AT_EVENT`·`CAMPAIGN_STOP_CNT`)
>   · `DIM_CAMPAIGN` +2(`PARENT_CAMPAIGN_NAME` 자기조인 라벨 · `PROMO_METHOD_NAME` CM008 라벨)
>   · `CREATE OR REPLACE` 미사용(FK·GRANT 보존) · FK 총계 39→42
> ✅ **dbt**: 모델 3건(`FACT_MEMBER_COHORT` 신설 · `FACT_MEMBER_EVENT`·`DIM_CAMPAIGN` 수정) +
>   yml 가드 다수 + **singular test 2건**(분자⊆분모 불변식 · 캠페인/중단 measure 상호배타).
>   `dbt build` = **PASS=364 WARN=27 ERROR=1**. ERROR 는 내 결함 1건(`IIF`=T-SQL → `IFF`) 수정·검증 완료.
>   🔴 **자기지적**: 모델은 `EXPLAIN` 으로 사전 검증했으나 **singular test 는 하지 않았다**.
>   `dbt compile` 은 Jinja 렌더만 하고 SQL 유효성을 DB 에 묻지 않는다 → **P64**.
> ✅ **실측 검증 전항 통과**: FME **4,633,105 불변**(fan-out 0) · FMC **1,585,949 = distinct 회원**(grain 유일) ·
>   `DIM_CAMPAIGN` 36,144 불변 · `SEX`/`GENDER` 차이 9 = 센티넬 `'0'` 라벨 부재(창작 안 함) ·
>   12개월 분모 1,465,547 / 분자 293,818.
> ✅ **`SV_MEMBER_COHORT` 신설·배포**(SV 7종) — 캠페인별 중단률 정본. 스모크 전항 통과:
>   fan-out 0 · **`max_rate = 0.7395 ≤ 1.0`**(사건 기준 산식이 185% 를 냈던 그 불변식) ·
>   캠페인 카테고리 26종 **4.05% ~ 73.95%**. 🟢 **Agent 의 원 질문이 단일 SV 로 답을 낸다.**
>   🔴 순위가 누적 기준과 크게 다르다 — `기존회원캠페인 및 기타` 누적 65.50% → 12개월 **4.05%** ·
>   `가두캠페인` 30.15% → **46.87%**. 관측창 교란 제거가 결론을 바꾼다는 실증이다.
> ⚠️ **`PROMO_METHOD` 는 라벨이 아니라 숫자코드였다**(95종). 이대로 SV 에 노출하면 Analyst 가 코드를
>   추측해 **0행 무증상 오답**(§6.9-(5)·AD-4 유형). 코드사전 탐색으로 **CM008 이 도메인 전량(94/94) 커버**를
>   확인해 `PROMO_METHOD_NAME` 을 배선했다. 🔴 **적재 대기** — dbt build 후 SV 에 축 추가(현재 미노출:
>   프로젝트 규약 = 미적재분은 SV 에서 아예 제외).
> ⚠️ **거짓 주석 회수**: `INFLOW_PATH` 를 *현업 "주요캠페인" 분류축*이라 적은 표기는 **거짓**이었다 —
>   실제값이 디지털·방송·지역개발·대면모금 등 **모집 채널**이다. "주요캠페인(캠페인카테고리)" =
>   `CAMPAIGN_TYPE`(MM294). `06_DDL.sql`·모델·SV COMMENT 3곳 교정.
> ✅ **SV DDL 파일 분할**(사용자 요청): 단일 `05_SV_DDL.sql` 708행·85KB → **SV 단위 7파일 + 인덱스**.
>   각 파일이 `USE`·SV 정의·자기 GRANT·자기 스모크를 포함해 **완전 독립 실행**(파일 간 순서 의존 0 →
>   순서 문서가 stale 되는 P62 경로 원천 제거). 분할 검증 = `GET_DDL` 전후 대조 **6종 byte-identical** ·
>   owner·GRANT 보존. 원본은 `_archive/05_SV_DDL_ORIGINAL_BACKUP_20260805.sql`.
>   `05_0_SV_DDL.sql` = 인덱스·공통규약·**전체 배포 검증**(실행 라인 보유 — 폐기 스텁이 아니다).
> 🔴 **인용처 회수 2라운드**(P62-B): 분할로 25파일·93회가 대상이 됐고, 사용자가 인덱스를 `05_0` 으로
>   리네임하자 **내가 직전에 쓴 교정이 즉시 stale** 이 됐다 — **리네임은 그 자체가 P62-B 사건이다**.
>   성격별 회수(인덱스→`05_0` / SV 정의→`05_1`~`05_7` / 이력→구명 + 아카이브 경로 병기) 총 19파일.
> ✅ **후속작업 전량 완료(2026-08-05 라이브)**:
>   · `dbt build` 완료(사용자) — 동일 batch 로 3테이블 갱신 실측 · `PROMO_METHOD_NAME` **34,686 채움·94종** ·
>     FME 4,633,105 / FMC 1,585,949 불변 · **singular test 2건 위반 0**(직접 실행 확인)
>   · `SV_MEMBER_COHORT` 에 홍보방법 축 추가 · `SV_MEMBER_EVENT` 확장(캠페인 축 4종 + 사건시점 성별 +
>     **`TOTAL_CAMPAIGN_STOP_CNT`**) · `SV_MEMBER_MONTHLY`·`SV_MEMBER_EVENT` **거짓가드 회수**(P61)
>   · Agent: `analyst_member_cohort` 도구 신설 + 라우팅·부정형 서술 회수 → **`VERSION$4` is_default** ·
>     GRANT 4종 보존 실측. `AGENT_OVERALL` 은 캠페인 중단률 관련 낡은 서술 없음(수정 불요)
>   · 신규 축 실측 확인: 홍보방법별 12개월 이탈률 13종 · 상위캠페인별 35종 · 캠페인 카테고리별 귀속 중단건 55종 ·
>     사건시점 성별 9종 · 홍보방법별 개발건 93종 — 전부 답을 낸다
> 🔴 **작업 중 내 결함 5건 전수 기록**(상세 = `99_NEXT_SESSION.md` §4): ① `IIF`(T-SQL) → build ERROR 1
>   ② SV metric 명이 컬럼명을 가려 컴파일 실패 ③ SV 에 **캠페인 차원 선언 누락**(이 SV 의 목적 자체였다)
>   ④ Agent FQN 을 `SNOWFLAKE_INTELLIGENCE` 로 가정(실제 `GN_DW.SERVING`) ⑤ "Agent 도구 0개" 오판정
>   (`DESCRIBE AGENT` 는 live 를 반환 — 이 프로젝트는 명명 버전 방식이라 live 는 원래 비어 있다).
>   → 신규 교훈 **P63**(비율은 분자·분모 모집단 + 고정 관측창) · **P64**(`dbt compile` 은 SQL 유효성 미검증) ·
>   **P65**(metric 명 ≠ 컬럼명) · **P66**(Agent 스펙 판정은 default 버전).
> 🟢 **추론 의심 2건 재검증 완료**: 코호트 grain 의 ''10대 미만'' 상위 10 캠페인 **전부 편지쓰기대회 계열**(O34-B 전용이 아닌 실측) ·
>   `DIM_MEMBER` 성별 라벨 = **CM017 확정**(5개 라벨 전량 유일 커버 · CM013 은 3/5).
> ⏸ **잔여 = NL 스모크 1건**(PRV-3 · 트라이얼 계정 차단으로 사람이 UI 확인). 질문 7건·실패 판정 기준 =
>   `99_NEXT_SESSION.md` §1. ⚠️ 사용자 최종 build 의 PASS/WARN/ERROR 카운트는 내가 보지 못했다 —
>   불변식·적재는 직접 SQL 로 검증했으나 dbt 리포트 재확인을 권한다(§4 한계 절).

> **▶ 🟢 최신 상태 [2026-08-04 O35 완료 — 사건시점 축 전파 · SV 확장 배포]** — 정본 = 문서10 **§20**
> ✅ **`dbt build` GREEN**: PASS=333 · WARN=26(전부 기존 관측용) · **ERROR=0** · SKIP=0 · **신규 `accepted_values` 4건 전건 PASS**
> ✅ **실측 검증 전항 통과**: FME **4,633,105 불변**(fan-out 0) · `AGE_AT_EVENT`/`AGE_BAND_AT_EVENT` DEV 전건 100% ·
>   `REGION_AT_EVENT` 미채움 20,624 = 센티넬 `'0'`(사전 라벨 부재, 창작 안 함) · **STOP 행 누출 0**
> 🔴 **전파의 가치가 수치로 확인됐다**: `_AT_PLEDGE` 스냅샷과 **연령대 283,067행(7.95%) · 지역 141,279행(3.99%) 불일치** —
>   스냅샷 축만 있었다면 개발 사건 28만 건의 연령대가 틀린 답이 됐다(P60 결함의 크기).
> 🟢 **본래 목표 달성**: `SEMANTIC_VIEW()` 스모크에서 편지쓰기대회 계열 ''10대 미만'' **50.79%** vs 그 외 **4.25%**(약 12배) ·
>   ''10대 미만'' 개발건 **상위 10 캠페인 전부 이 계열**. Agent 가 자기 설명의 근거를 스스로 산출할 수 있다.
> ✅ **SV 확장 배포**: `SV_MEMBER_EVENT` 차원 4개(`AGE_BAND_AT_EVENT`·`AGE_CD_AT_EVENT`·`REGION_AT_EVENT`·`AREA_CD_AT_EVENT`)
>   + SV COMMENT · `AI_SQL_GENERATION` 규칙(7). 정본 `05_SV_DDL.sql` 선수정 후 해당 블록만 실행 · **GRANT 3줄 재실행 완료**.
> 🔴 **파생 발견(P61 신규) — 조치가 소비 끝단에서 무력화될 상태였다**: 정본 Agent 스펙이 *"미적재분(**캠페인**/…/**사유별**/
>   **지역·연령대**)은 창작 금지 → Phase-2 안내"* 라고 지시하고 있었다. 이 4축은 O33·O35 로 **전부 활성**이다 —
>   데이터·SV 가 맞아도 Agent 가 "아직 없습니다"라고 답하는 경로이며 품질 테스트로 안 잡힌다. `analyst_member_event`
>   **도구 description 도 O24 이전 상태**(차원이 "전이유형" 뿐 → 캠페인·연령대·증액/감액 축 누락 = 도구 미선택으로 무증상 비활성).
>   ✅ 정본 yaml 6개 항목 교정 완료(활성목록·약정시점 명시·교차 실행 지시·도구 description 전면갱신·라우팅 규칙·샘플질문).
> ✅ **재구축 순서 ⑥ Agent 배포 완료(사용자 승인)**: `09_2` 경로로 두 Agent **`VERSION$3` · is_default** 발행 ·
>   `AGENT_MEMBER` 도구 4개 + 교정 instruction 반영 확인 · **USAGE GRANT 3종 보존 실측**(이 경로는 파괴하지 않는다) ·
>   껍데기는 `VERSION$2` 로 보존(롤백 가능). ⚠️ `Version nullsuccessfully created` 메시지는 표시 버그다(정본 09_2 기경고).
>   착수 시점 실측: 라이브 스펙이 `{"models":{"orchestration":"auto"}}` — **도구·instruction 이 0개인 껍데기**였다(재구축 후 ⑥ 미실행).
> ⏸ **잔여 = NL 스모크 1건**: `DATA_AGENT_RUN` 이 **트라이얼 계정에서 차단**(`Access denied for trial accounts`)되어
>   자연어 경로를 프로그램으로 못 돌렸다 → **Snowsight UI·CoWork 에서 사람이 확인**해야 한다(PRV-3).
>   SQL 계층은 검증 완료이므로 남은 위험은 **Agent 의 도구 선택·instruction 준수**뿐이다.
>   권장 질문: *"10대 미만 개발건이 왜 많아? 전체 기간 캠페인별로 보여줘"* · *"지역별 개발건수 상위 5곳"* ·
>   *"현재 연령대별 개발건"*(→ 산출 불가 + 약정시점 전제 안내가 나와야 정상).
>
> **▶ 🟡 [2026-08-04 O35 착수 시점 기록]** — 정본 = 문서10 **§20**
> ✅ **①~④ 실행 완료**(작업조건 #5 에 따라 `dbt build` 앞에서 멈춤):
> · 물리 `GOLD.FACT_MEMBER_EVENT` **ADD COLUMN 4 + COMMENT 4** (`AGE_AT_EVENT`·`AGE_BAND_AT_EVENT`·
>   `AREA_CD_AT_EVENT`·`REGION_AT_EVENT`) — `CREATE OR REPLACE` 미사용(FK·GRANT 보존)
> · 🔴 **정본 `06_DDL.sql` 동기화 완료** — 같은 세션에 처리(P57. O30 사고의 직접 원인이 이 단계 누락이었다)
> · 모델 `FACT_MEMBER_EVENT.sql`(dev 전파 + CM014 라벨 CTE · stop 은 `CAST(NULL)`) · 소비뷰
>   `WIDE_MEMBER_EVENT.sql`(4컬럼 + COMMENT, **기존 스냅샷 축 COMMENT 에 「사건시점 값 아님」 경고 추가** = P59)
> · `_gold_ready_schema.yml` **`accepted_values` 4건**(코드=error·라벨=warn) · `05_필드 인벤토리.md` 4행
> 🟢 **라벨 병설 채택** — 선행 세션이 「조인 비용 보고 판단」으로 남긴 건. 비용 실측 결과 지역 라벨은
>   SILVER `CRM_MEMBER_DEV.AREA_NM` 로 **추가 조인 0**, 연령대는 CM014 **12행** 조인이고 **fan-out 0** 사전 검증.
> 🟢 **전파의 정당화 근거를 실측으로 확보** — 복수 개발사건 회원 1,040,895명 중 **`AGE` 변동 102,685 ·
>   `AREA_CD` 변동 50,039**. 회원당 불변이었다면 이 작업은 중복 축 신설이었을 것이다(반대로 나왔다).
> ✅ 검증(build 전 가능분): **정본 DDL ↔ 물리 31 == 31 · 양방향 차집합 0**(P57 ②) · 라벨 조인 fan-out 0 ·
>   신규 산출식 컴파일 통과. ⚠️ 운영 스키마에 임시 테이블을 만들지 않았다(§19-E ⑥ 자기지적 반영).
> ⏸ **잔여 = 사용자 실행 `dbt build`** → 이후 ① 연령대 × 캠페인 교차가 편지쓰기대회 편중을 재현하는가
>   ② `_AT_EVENT` ↔ `_AT_PLEDGE` 값 차이 실측 ③ FME 행수 4,633,105 불변 ④ `SV_MEMBER_EVENT` 차원 확장
>   (`05_SV_DDL.sql` 정본 동기화 후 배포).
> 🔴 **`_AT_PLEDGE` 축은 제거하지 않는다** — 성격이 다르므로 이름으로 구분해 공존(`_AT_EVENT` 사건시점·정확).
> 🟢 **부수 — 문서 공백 1건 보정**: 이슈원장이 지목하던 **문서10 §19-J(P60)가 실재하지 않았다**(O33~O35
>   진단이 이슈원장에만 기록). 회수 신설 완료. 상호참조는 **참조 대상의 실존 확인**이 필요하다(§19-H 계열).
>
> **▶ 🟢 최신 상태 [2026-08-04 최종 — O34 설명 확립 · O35 신규]**
> ✅ **사용자 판단 채택 + 실증 완료**: *"이벤트로 인한 스냅샷이니 캠페인(개발) 시점의 나이로 보면 된다.
> 데이터 오류가 없으니 특수 이벤트가 있었다는 답으로 커버할 수 있다"* — **맞다. 그리고 수치로 확인됐다.**
> 사건시점 `AGE`(= `SILVER.CRM_MEMBER_DEV.AGE`, 채움 100%)로 측정하니
> **편지쓰기대회 계열**(희망편지·가족그림편지·세계시민교육편지) 캠페인의 `AGE=1` 비중이
> 그 외 캠페인의 **약 5배**였고, `AGE=1` 개발사건 상위 10개 캠페인이 **전부 이 계열**이었다.
> → 원인은 **학교·부모 DB 기반으로 아동 본인 명의 약정을 맺는 모집 이벤트**다.
> ✅ 조치: SV 차원·SV 레벨 COMMENT 에 *"오류가 아니며 편지쓰기대회 계열 캠페인 때문이고 약정 당시 연령
> 기준이다 — 결측·오류로 설명하지 말 것"* 을 명시 배포. 이제 Agent 가 **이유를 진술**할 수 있다.
>
> 🔴 **O35 신규 — 연령대 × 캠페인 교차가 불가하다 (Agent 가 스스로 검증할 수 없다)**
> 위 설명을 COMMENT 로 넣었지만, **Agent 가 그 근거를 계산해 보여줄 수는 없다**:
> `SV_MEMBER_MONTHLY` = 연령대 **있음** · 캠페인 **없음**(FMM.CAMPAIGN_SK 단일값) /
> `SV_MEMBER_EVENT` = 캠페인 **있음** · 연령대 **없음**. 두 축이 서로 다른 SV 에 갈라져 있다.
> 🟢 **해법이 이미 원천에 있다**: `SILVER.CRM_MEMBER_DEV` 는 **사건행별 `AGE`·`AREA_CD` 를 100% 보유**한다.
> 그런데 `GOLD.FACT_MEMBER_EVENT` 는 이 둘을 **전파하지 않았다**(해당 컬럼 0개).
> → 제안: **FME 에 사건시점 `AGE`·`AREA_CD` 전파**. 두 가지 이득이 동시에 생긴다 —
> ① `DIM_MEMBER_CURRENT` 경유 스냅샷과 달리 **의미가 정확한 「사건 시점 연령」**이 된다(P60 정면 해소)
> ② 같은 SV 안에서 **연령대 × 캠페인 교차**가 되어 Agent 가 위 설명을 스스로 산출한다.
> ✅ **방향 확정(사용자 승인 2026-08-04)** — 대안 3안을 비교해 **A(전파)** 채택. 재론 불요:
> · **A 전파** ✅ 속성이 **측정된 grain 에 놓인다**(개발약정 이벤트에서 관측된 값 = 사건 팩트의 속성).
>   시점 왜곡이 원천 소멸하고 연령대 × 캠페인 교차가 성립한다.
> · **B multi-fact SV**(FMM+FME conformed dim 공유) ❌ 문법상 가능하나 연령이 여전히
>   `DIM_MEMBER_CURRENT` 스냅샷이라 **의미 결함이 남고**, 상이 grain 두 팩트를 `MEMBER` 로 묶으면
>   **fan trap** 위험. 기계적 해결이지 의미적 해결이 아니다.
> · **C Agent 가 SV 끼리 join** ❌ **불가** — `SEMANTIC_VIEW()` 는 단일 뷰 대상 테이블 함수이고
>   Agent 는 각 SV 를 따로 호출해 **문장으로 합칠 뿐 행 단위 조인을 못 한다.** 게다가
>   **`FMM.CAMPAIGN_SK` 는 센티넬 단일값**이라 조인해도 캠페인 축이 없다(실측).
> ⬜ 남은 것 = 실행뿐: FME `ALTER ADD COLUMN` 2개 → **정본 `06_DDL.sql` 동기화(P57)** → 모델 수정 →
> ⏸ `dbt build`(규칙 5 대기) → `SV_MEMBER_EVENT` 차원 추가. 순서·주의 = `99_NEXT_SESSION.md` §3-A-1.
> ⚠️ FMM 의 `_AT_PLEDGE` 축은 성격이 달라 **제거하지 않고 이름으로 구분해 공존**시킨다
> (`_AT_EVENT` 사건시점·정확 vs `_AT_PLEDGE` 최근 약정 스냅샷).
> ⚠️ 주의: FMM 쪽 `_AT_PLEDGE` 축은 성격이 다르다(월 팩트 × 현재행 스냅샷) — 함께 두되 이름으로 구분한다.
>
> **▶ 🟢 최신 상태 [2026-08-04 종반 — O34 확정 · SV 사유축 완료]**
> ✅ **O33 완결** — 사용자 결정대로 ①④ 사유별 **노출**, ⑤ 모집인원 **보류**.
> · `SV_MEMBER_MONTHLY` +미납사유(`DIM_REASON` 조인) 🔴**`UNPAID_REASON_TYPE` 동반 노출 필수** —
>   이 SK 가 코드그룹 **5종**(PM002·PM018·PM032·PM033·PM019)에 걸쳐 있다. 스모크에서 위험이 실증됐다:
>   `예금부족`(PM002)과 `잔액 또는 지불가능 잔액 부족`(PM032)은 **같은 개념의 다른 코드체계**다 →
>   그룹 미분리 합산은 조용히 틀린다(O28 유형).
> · `SV_MEMBER_EVENT` +중단사유·중단경로 — FME 는 라벨 컬럼을 직접 보유하고 **단일 코드그룹(MM005)**
>   이라 조인 불요·혼입 없음. 스모크 6/6 통과.
>
> 🔴 **O34 확정 — 그리고 내 최초 가설이 틀렸다**
> 나는 *"원천 기본값이 첫 코드(1)로 유입된 패턴 의심"* 이라고 적었다. **틀렸다.**
> BRONZE 부터 다시 올라가 검증한 결과 **`AGE`·`AREA_CD` 는 「약정(개발) 시점 스냅샷」**이며
> 값·매핑 모두 **정상**이다. 문제는 그것을 **「현재 속성」으로 표기**한 것이었다.
>
> | 검증 | 결과 |
> |---|---|
> | 라벨 매핑 | 코드사전 **CM014 와 완전 일치**(우리 결함 아님) |
> | 독립 원천 대조 | `SND_MEMBER_LIST.AGE`(라벨 보유)와 회원 단위 대조 — 불일치가 **98.4% 노화 방향**(동일+늙음), 역방향 1.6% |
> | 약정연도 상관 | 2026년 평균차 0.00 → 2024년 0.12 → 2020년 0.85 → 2001~2013년 약 1.3 (**단조 증가**) |
> | ''10대 미만'' 최다 원인 | **실제다** — 상위 캠페인이 학교 기반 아동 모집(희망편지쓰기대회 계열)이고 20세 미만 비중이 절반을 넘는다 |
> | 현재 연령 산출 | 🔴 **불가** — BRONZE 전체에 생년월일 컬럼이 **없다**(전수 스캔) |
>
> ✅ 조치: 차원명을 **`MEMBER_AGE_BAND_AT_PLEDGE`·`MEMBER_REGION_AT_PLEDGE`** 로 개명하고
> *"약정 시점 스냅샷 · 현재 값 아님 · 현재 연령/주소는 산출 불가"* 를 COMMENT 에 명시.
> 종전 *"값 신뢰 보류"* 가드는 **철회**(값은 정상이다 — 의미 표기가 문제였다).
> ⬜ 잔여: 현재 연령·현주소가 필요하면 **원천 입고 요청**(생년월일·주소) — 현업 사안.
>
> 🆕 **P60 (시점 스냅샷을 「현재 속성」으로 노출하면 값이 맞아도 답이 틀린다)**: `AGE`·`AREA_CD` 는
> 약정 시점에 굳는 값인데 `DIM_MEMBER_CURRENT` 를 거쳐 SV 에 올라가면서 **현재 속성처럼** 보였다.
> 값·매핑·채움률은 전부 정상이라 어떤 품질 테스트로도 잡히지 않는다 — **의미(semantics) 결함**이다.
> 내 최초 진단이 *"기본값 오염"* 이었던 것도 분포만 보고 **시점 축을 의심하지 않았기** 때문이다.
> → ① 시점 종속 속성은 **차원명에 시점을 박는다**(`_AT_PLEDGE`) ② *"이 값은 언제 굳는가"* 를
> 배선 시 반드시 묻는다 ③ 분포가 이상할 때 **값 오류를 먼저 의심하지 말고 시점 정의를 먼저 확인**한다
> ④ 검증은 **독립 원천과의 방향성 대조**(노화처럼 단조성이 있는 축은 이것으로 확정된다).
>
> **▶ 🟢 최신 상태 [2026-08-04 재구축 완료 + SV 확장] — 정본 = `02_GN_DW_building/06_RUNBOOK.md` §11**
> ✅ **재구축 전 단계 완료**(사용자 실행): BRONZE 51테이블 · SILVER 38 · GOLD 28테이블+**뷰 13** ·
> SERVING **뷰 3**(helper 2 + `FACT_AD_COMBINED`) · **SV 6종** · **Agent 2종**.
> 빈 테이블은 예상된 3건뿐(`CRM_BIZ_TARGET`·`FACT_TARGET_BIZ` = E-6 미입고 · `BRONZE_GA4.SYNC_ERR_INFO`).
> `08` §G.2 O27 수정이 통해 helper 뷰가 생성됐고 SV 가 그 위에 올라갔다.
>
> ✅ **O33 — SV 「비활성」 선언 전수조사 + 확장**
> 소비 질문("BRONZE 코드로 GOLD 를 끌어낼 수 있나")을 검증하다 **SV 가 GOLD 보다 좁다**는 격차를 찾았다.
> **비활성 선언 5건이 stale**(배선은 끝났는데 "적재 대기"로 남아 Agent 가 "불가"로 답하던 상태):
> ① FMM 사유별(센티넬 92.1%) · ② FMM 지역/연령대(**3.7%**) · ③ FME 캠페인별(22.4%·고아 0%) ·
> ④ FME 사유별(77.6%) · ⑤ FEP 모집인원(**고아 86.6%**).
> 나머지 비활성 선언(캠페인/후원사업/조직별·수신·성공·실패·오픈·+5일 코호트·연 편성예산·신규기존·
> 활동/누계 카운트)은 **전부 정확**했다(해당 컬럼 distinct=1 또는 fill=0 실측).
> ✅ **확장 배포**: `SV_MEMBER_MONTHLY` +지역·연령대 / `SV_MEMBER_EVENT` +캠페인 5축
> (`DIM_CAMPAIGN` PK 유일 → fan-out 0 확인 후 논리테이블 신설). SV COMMENT 의 거짓 비활성 문구 정정.
> 스모크 6/6 통과 — 지역별·연령대별 납입회비, 캠페인·브랜드별 개발건이 실제로 답을 낸다.
> 🔴 **개발/중단 비대칭을 COMMENT 에 명시**: 캠페인은 **개발(DEV) 전용**이다 — 중단(STOP)행은
> 센티넬 **100%**(개발행은 0.0%)라 "캠페인별 중단건"은 `(미매핑)` 한 덩어리로 나온다(스모크로 실증).
> ⬜ **잔여 결정 2건**: ①④ 사유별 노출 여부(센티넬 92.1%/77.6% — 미납/중단 행 한정 노출이 맞는가) ·
> ⑤ 모집인원(고아 86.6% → 보류 권고).
>
> 🔴 **O34 신규 — `DIM_MEMBER.AGE`(연령대) 값 신뢰 보류 (현업 확인 필요)**
> SV 에 연령대를 노출하고 스모크를 돌리다 발견했다. 라벨 매핑은 **코드사전 CM014 와 정확히 일치**
> (우리 쪽 버그 아님)하나, **최다 구간이 ''10대 미만''**이고 ''10대''까지 합치면 회원의 상당 비중이다.
> 회비 납입 주체의 연령분포로는 비정상이며 **원천 기본값이 첫 코드(1)로 유입된 패턴**이 의심된다.
> ⚠️ `AGE=10`→단체 · `AGE=11`→기업 이 성별(`SEX`)과 일치하므로 **회원 속성인 것은 맞다**(결연아동 연령 가설은 기각).
> ✅ 조치: SV dimension COMMENT 에 *"연령대별 순위·최대 연령층 결론 금지 — 확인 전까지 분포 관찰 전용"*
> 가드 배포. 🔴 이 가드 없이는 Agent 가 *"10대 미만이 최대 후원 연령층"* 이라고 확신하며 답한다.
>
> ✅ **소비 가능성 검증 결론** — `DIM_CODE` 신설 **불요**(권고 철회).
> GOLD 코드축 41곳을 전수 대조하니 **라벨 페어링 결함 0**(`JOIN_PATH_CD`→`MEMBER_ENROLL_PATH_NAME` 포함).
> 코드사전이 없어도 라벨로 조회된다. SILVER 에만 있는 코드축 56종은 GOLD 에 컬럼 자체가 없어 사전이 있어도 못 뽑는다.
> ⚠️ 단 역할 차이는 남는다: `GN_DW_ANALYST`=GOLD·SERVING·**SILVER** / `GN_DW_VIEWER`=GOLD·SERVING 만.
>
> **▶ 🔴🔴 최신 상태 [2026-08-04 재구축 준비] — 정본 = `02_GN_DW_building/06_RUNBOOK.md` §11**
> 사용자 결정: **전수 재구축(①→④) 전제** → 물리 ALTER 는 생략하고 **정본 문서만** 정비한다.
> ✅ **완료** ⓵ `O28_O29_COMMENT_GUARD.sql` **사문화 2건 분리** → `03_top-down_gold/_archive/O28_O29_사문화_COMMENT_2건_20260804.sql`
> (`FEP.RECRUIT_CNT`·`DIM_AD_CREATIVE.DURATION_SEC` = DEC-30 이 DROP 한 컬럼. 남겨두면 `COMMENT ON COLUMN`
> 실패로 스크립트 전체가 재실행 불가였다. 뷰측 파생 1건도 절 단위 제거 — `ALTER VIEW` 16→15절, 구문 검증 완료)
> ⓶ **런북 §11 「전체 재구축 순서」 신설** + **§3.3 위험 지시 교정**.
> 🔴 §3.3 은 종전 *"06_DDL.sql 재실행 후 dbt build"* 라고만 적혀 **파괴 경고가 없었다** —
> **런북이 O30 사고를 지시한 문서**였다. 평상시 절차(ALTER + 정본 동기화 + 모델 정합 + build)로 교체했다.
>
> ✅ **O31 해소 + 🔴 내 오판정 정정 (런북 §11.3-B)**
> 나는 O31 을 *"SERVING helper 뷰 2종의 실행 정본 유실(BLOCKER)"* 로 등재했으나 **틀렸다.**
> 정본은 **`02_GN_DW_building/08_After_Deploy_DBT.sql` §G** 에 있었다. 오판 경로 =
> `02_SERVING_setup.sql` 스텁이 *"07_ENVIRONMENT_RBAC_setup.sql 로 이관"* 이라고 적어서
> **07 과 `_archive` 만 확인하고 단정**했다 — 스텁의 이관 안내가 **틀린 파일을 가리키고 있었고
> 나는 그것을 검증 없이 따라갔다**(사용자가 08 을 지목해 바로잡혔다).
> 🔴 **실제 결함은 다른 것이었다**: `08` §G.2 의 `SERVING.DIM_MEMBER_CURRENT` 생성문이
> O27 이 DROP 한 `NEW_EXISTING_FLAG`·`LAST_CAMPAIGN`·`CURRENT_SPONSORSHIP` 을 SELECT 해
> **`invalid identifier` 로 실패**한다(동일 SELECT 컴파일로 실증). → ✅ 3컬럼 제거·컴파일 검증 통과.
> SV 는 이 3컬럼을 참조하지 않아(`05_SV_DDL.sql` 실측 0건) 소비 영향 0.
> 📌 **O27 이 번진 산출물은 4개였다** — `06_DDL.sql`·물리 `GOLD.DIM_MEMBER`·dbt 모델 ·
> **`08_After_Deploy_DBT.sql`(SERVING 소비 뷰)**. 구조 변경은 **소비 뷰까지 역추적**해야 한다 → **P59**.
> ⬜ 잔여(BLOCKER 아님): `DIM_MEMBER_CURRENT` 가 **SERVING(SV 전용 19컬럼) / GOLD(분석가용 20컬럼)**
> 2판 공존 — 소비자가 달라 의도적 분리로 설명되나 미문서였다(양쪽에 역할 명기 완료).
> `DIM_MEMBER_CURRENT.sql` 헤더의 *"전건 NULL 7컬럼 미노출"* 은 **이제 없는 3컬럼을 열거**한다(P33 ③ 회수 대상).
>
> ✅ **재구축 순서 확정 (런북 §11.2·§11.2-B)** — 🔴 **①②(`06_DDL`·`08_SILVER`) 재실행 불요**:
> **정본 DDL ↔ 물리 66테이블 전수 대조 불일치 0**(2026-08-04). 재실행하면 데이터만 날아간다.
> 최소 경로 = **1) `deploy_dbt_project.sql`**(🔴 `SHOW DBT PROJECTS` = **0행** — 재구축이 DBT PROJECT 를
> 삭제했다. `08` 5~7행 GRANT 의 전제조건) → **2) dbt build** → **3) `08_After_Deploy_DBT.sql`** →
> **4) `05_SV_DDL.sql`** → 5) `13_SV_AD` → 6) `09_1_AGENT`.
>
> 🆕 **P59 (구조 변경은 소비 계층까지 역추적해야 완결된다)**: O27 은 정본 DDL·물리·dbt 모델 3곳을
> 맞추고 "완료"로 봤지만, **소비측 뷰(`08_After_Deploy_DBT.sql` §G.2)** 가 DROP 된 컬럼을 계속
> SELECT 하고 있었다. 이 결함은 **dbt build 로는 절대 드러나지 않는다**(그 파일은 dbt 밖이다) —
> SV 배포 단계에서야 터진다. → 컬럼 DROP·개명 시 **`grep -r <컬럼명>` 을 워크스페이스 전역**에
> 돌려 dbt 밖 산출물(setup SQL·SV DDL·Agent spec)까지 회수 목록에 넣는다.
>
> ⬜ **미결 O32 — COMMENT 실측수치 제거 96건 수동 대기**
> 사용자 규칙: *"COMMENT 에서 실측 수치는 코드값 외엔 삭제"*(데이터 계속 입고 → 수치는 반드시 낡는다).
> 실측 대상 = COMMENT **1,686개 중 132개**가 수치 보유(06_DDL 67 · 08_SILVER 30 · dbt models 35).
> 그중 **자동 처리 가능 5건 · 수동 재작성 96건**.
> 🔴 **자동 정규식 방식은 2회 시도 후 폐기했다** — 절 내부 수치만 빼면 한국어 문장과 **코드값이 깨진다**
> (실증: `MM018 1개인·2기업·3단체` → `인·2기업·3단체` · `정본 5종을 3종으로 축약` → `정본 을 으로 축약`).
> 좁은 토큰 삭제도 잔해가 남았다(`(69부서/·131부서/=)` · `값..`). → **96건은 손으로 써야 한다**(P58).
> ⚠️ 그중 **10건은 내가 만든 것**이다 — O27 §4 를 verbatim 적용하면서 `DIM_MEMBER` 에 `7,925,716`·
> `96.91%` 등을 주입했다(§19-E ⑤).
>
> 🆕 **P58 (COMMENT 의 실측 수치는 자동으로 지울 수 없다 — 애초에 넣지 마라)**: 한국어 COMMENT 에서
> 수치만 정규식으로 제거하면 **코드값(`1개인`)과 문장 구조가 함께 깨진다**. 수치는 절(clause)과 엉켜
> 있어 절 단위 삭제도 가드를 함께 날린다. → ① COMMENT 에는 **코드값·가드·정소재지만** 쓰고
> 실측치는 **문서(문서10)에만** 둔다 ② 이미 들어간 것은 **수동 재작성만이 안전**하다
> ③ `ALTER … COMMENT` 를 verbatim 재사용할 때 **수치 포함 여부를 먼저 확인**한다.
>
> **▶ 🔴🔴 최신 상태 [2026-08-04 재구축 드리프트] — 정본 = 문서10 §19 · 복구 스크립트 = `03_top-down_gold/O30_REBUILD_DRIFT_REPAIR.sql`**
> **O30 = 전체 환경 재구축이 「정본 DDL 에 접히지 않은 구조 변경」을 되돌렸다.** 실측 타임라인: 2026-08-03 **20:55** DB·스키마 재생성 → **20:59~21:00** BRONZE 51테이블 `CREATE OR REPLACE`+재적재 (112,512,201행) → **21:36~21:37** SILVER 38 재생성(`08_SILVER_테이블DDL`) → **21:37~21:38** GOLD 28 재생성(`06_DDL.sql`) → **21:40~21:41** `dbt build` **ERROR 3 · SKIP 68**.
> 🔴 **소실 = 정확히 2개 변경집합**(전수 대조·추론 0): **O26 SILVER 개명 2컬럼**(`PRCS_STAT_CD` 부활) · **O27 `DIM_MEMBER` 4추가/3삭제+COMMENT 8**. 🟢 **무사** = DEC-30 구조변경 · O25 SILVER 38컬럼 · O28/O29 COMMENT 가드 21컬럼 — 전부 정본 DDL 에 접혀 있었다. **COMMENT 손실 0**(SILVER 696/696 · GOLD 670/670).
> 🔴 **`O27_DIM_MEMBER_ALTER.sql` §5 가 "정본 DDL 도 같은 세션에 고쳐라"라고 이미 경고**했고 그 단계가 실행되지 않았다 → **P30 3번째 사례**.
> 🔴 **파급이 ERROR 3 보다 22배 넓다**: SKIP 68(모델 9+테스트 59) · **빈 테이블 9종** · **GOLD 뷰 5종 미존재**(`DIM_MEMBER_CURRENT`+WIDE 4 — 뷰는 dbt 소유라 모델 SKIP 시 생성 안 됨) · 🔴 **SERVING 스키마 객체 0건**(SV 6종·`FACT_AD_COMBINED`·`DIM_MONTH` 전멸) = 소비 계층 전체 중단.
> 🔴 **무증상 폐기 1건 발견** — `DIM_AD_CREATIVE.DURATION_SEC`: DEC-30 이 DDL 에서 제거했는데 모델이 계속 산출해 **2회 빌드 동안 에러 없이 버려졌다**. dbt incremental 은 *대상 테이블에 없는 산출 컬럼을 조용히 폐기*한다 → **P57**(드리프트 방향이 증상을 결정한다: 물리에만 있으면 에러, 모델에만 있으면 무증상).
> ✅ **복구 완료(2026-08-04)**: 물리 ALTER(SILVER 개명 2+COMMENT · `DIM_MEMBER` ADD 4/DROP 3/COMMENT 8) + **정본 DDL 동기화**(`06_DDL.sql` DIM_MEMBER 블록 30컬럼 · `08_SILVER_테이블DDL` 2행) + `DIM_AD_CREATIVE` 모델 `DURATION_SEC` 산출 제거. 검증 = 모델산출↔물리 컬럼 **양방향 차집합 0** · 정본 DDL 로 임시테이블 생성 대조 **30==30**.
> ⬜ **잔여(사용자 실행)**: ① `dbt build` ② O27 §6 검증 재실행(⚠️기대값은 재구축 이전 측정치라 재측정 필요) ③ `05_SV_DDL.sql` 전체 실행(SERVING 복구).
>
> **▶ 🔴 최신 상태 [2026-08-04 종반] — 정본 = 문서10 §18 · 문서30 DEC-31**: 2차 `dbt build` 완료(`PASS=329 WARN=26 ERROR=0 TOTAL=355`·기대치 전항목 일치). **센티넬 전수감사** = 100% 센티넬 FK **13건/7팩트** · **도달 불가 차원 2건**(`DIM_PAYMENT` 7행 · `DIM_AD_CREATIVE` 8,716행) → **P52**. **GOLD 미주입 재계수 = 106/371(28.6%)**(ALL_NULL 44+ALL_ZERO 62) · 0행 테이블 `FACT_TARGET_BIZ` 8건 분리 시 **98/363(27.0%)** → **P53**. ⚠️ **종전 `125/454` 는 분모 구성 불명으로 인용 금지**. **GA 데이터검토 종결**(사용자 결정: GA 는 검토만·설계/구현 phase-2) = 가산 3종 배수 **정확히 1.0000** · `SESSION_CNT` **3.1508** · `ENGAGED_SESSIONS` **4.2959** · `PAGE_PATH` 정본 **#105 미충족**(쿼리문자열 제거 → #122 결연아동코드 파생 불가) → **P54** · `PAGE_LOCATION` `MAX()` 대표로 URL **88.9% 소실** → **P55** · `FACT_GA_BEHAVIOR.CAMPAIGN_SK` **상수 0** 이라 WIDE 캠페인 3컬럼 전건 `(미매핑)` · **URL `memnum` identity 결선 여력 +77.1%**(충돌 4). **COMMENT 가드 21컬럼 배포**(산식·구조 변경 0 · 검증 21/21). **귀속처 14건 = 11 귀속확정 + 3 잔여**(잔여 3건은 원인이 하나 — GA 원자 grain 팩트 부재). 🔴 **최종검토에서 내 오판정 1건 자체정정** — `PAGE_REFERRER` 를 「`DIM_GA_PAGE` 역할수행」→ **`DIM_GA_REFERRER` 신설**로 철회(host 206종 중 자사 11종·path 일치 51.1%·외부 25.3%) → **P56**. 자가검토 결함 **10건** 전수 기록(§18-G).
>
> **▶ SILVER→GOLD 컬럼 보존율 최초 측정 [O27 2026-08-03]**: 보존율 **54.7%**(199/364, 본 세션 실측). 탈락 165 = A **12** · B 재설계대기 **6** · C 1 · D **12** · **E 미판정 134** (⚠️초판 15/6/1/13/130 → 자기검토 판정오류 6건 정정, 10 §14-G). ~~GOLD 물리 미주입 **125/454(27.5%)**~~ → **2026-08-04 재계수 106/371(28.6%)** 로 대체·종전 수치 인용 금지(§18-C). 🔴 **DEC-27 §17-C `AGE_BAND` 판정 정정** — `AGE` 는 raw 나이가 아니라 **CM014 12종 코드**여서 구간 창작이 불요하다(독립 교차검증 `AGE=10↔SEX=6`·`AGE=11↔SEX=7` 각 100%). 🔴 `DIM_SERVICE.SEND_TYPE_L/M/S` 는 **정본 지표 #133~135** 이라 DROP 불가하나 현 grain(10→74)이 담을 수 없다 → **차원 재설계 결정 대기**(초판 DROP 판정 자기검토로 철회). 신규 교훈 **P34~P40** = 문서10 §14-E. 정본 = **10 §14** · **30 DEC-28** · 판정표 `30_output_share/08_SILVER→GOLD_보존율.csv`.

---

## 2. 전체 이슈 크로스워크 (마스터 인덱스)
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
| O10 | Q7 | 조직 역할 FMM·FME 반영 | 🟡 **부분해소 2026-08-05 O38** — `FME.ORG_SK` 실적부서(`ACMSLT_DEPT_CD`) 배선(매칭 99.9998%·미매칭 8행). ⚠️ **종전 P2(외부/현업 의존) 분류는 stale 이었다** — 결정·원천·매칭률이 모두 준비돼 있었고 배선만 빠져 있었다. 🔴 잔여 = **O38-B**(중단측 등록부서 축) · FMM 월롤업 대표조직 규칙 | 30 · 10 §22 |
| 🔴 **O38** | — | **[신규 2026-08-05] `FACT_TARGET_DEV.MONTH_KEY` 연도 소실 — 정본 YYYYMM 규약 위반 · 무증상 목표 팽창** — 모델이 `TRY_TO_NUMBER(STDR_MT)` 로 기준월만 쓰고 `STDYY` 를 버려 실적재가 **1~12 월 번호**였다. 실측 BRONZE 25,344행·15개 연도(2012~2026) → GOLD 7,272행 = **3.49배 병합**. `SUM(GOAL_CNT)` 4,622,103 이 원천과 정확히 일치해 **행수·SUM·참조무결성을 전부 통과**했고 `MONTH_KEY` 테스트가 0건이라 어떤 게이트도 못 잡았다. 결과: *"2026년 1월 목표"* → 15년치 합. ⚠️ 기존 이슈 **A** 와 별건(A=FMM 소관) · `WIDE_TARGET_DEV.CAL_YEAR` 전건 0 은 센티넬이 아니라 `FLOOR(MONTH_KEY/100)` 자릿수 부족 | ✅ **교정·검증 완료(build 대기)**: 모델 `STDYY\|\|LPAD(STDR_MT,2,'0')` + `month_key_clamp` · yml `not_null`+`accepted_values{1,2,4}` · **singular test 신설**(`dbt_utils` 미설치) · 물리 COMMENT+정본 DDL 동기화. 사전 시뮬 = grain **25,344 유일** · SUM **불변** · 201201~202612 · 가드가 현 결함 **12키/7,272행 검출** 확인(P26) | 10 §22 · 03설계 |
| 🟠 **O38-B** | O38 파생 | **[신규 2026-08-05] 중단측 조직축 = 등록부서(`REGIST_DEPT_CD`) 배속 미결** — 중단원천이 등록부서를 보유한다(채움 925,948/1,038,262 = **89.2%** · distinct **54** · DIM_ORG 매칭 **100%**). 그러나 개발측 축은 **실적부서 349종**으로 카디널리티가 6배 다르다 → 한 `ORG_SK` 컬럼에 섞으면 "부서별 중단건"이 조용히 틀린다(**O24·O28 의미혼입 유형**) | 🟠 **결정 대기**: (a) 별도 컬럼(`REGIST_ORG_SK`) 신설 (b) 중단 조직축 미노출 유지 (c) 현업에 역할 정의 확인. 현재는 **0 센티넬 유지 + COMMENT 로 사유 명시**(추론으로 채우지 않음, P21) | 10 §22 · 30 |
| 🟠 **O38-D** | O38 파생 | **[신규 2026-08-05 · 현업 확인 필요] CRM 개발목표에 `GOAL_CNT=0` 등록 행이 과반 — 그리고 증액·재후원 목표가 최근 연도에 사라졌다** — 실측: 목표 행 **25,344 중 14,667행(57.9%)이 0**. 🔴 **2026-08-05 BRONZE 재스캔으로 정정**: 종전 *"증액·재후원 목표가 2023년부터 전건 0"* 기재는 **2022년만 보고 일반화한 오류**였다 — 실제로는 **거의 편성된 적이 없다**(증액 4개 연도 2014·2019·2021·2022 · 재후원 **1개 연도 2022뿐**). **개발목표는 사실상 「신규」에만 편성된다.** 0 행이 과반인 원인도 결측이 아니라 **2020년부터 원천이 부서×월×개발구분 3코드 조합을 전량 행 생성하고 미편성분을 0 으로 채우는 방식**이다(2019년 1,008행 → 2020년 2,844행). `GOAL_CNT` **NULL 7행**도 별도 실재(2015·2017). 신규는 계속 편성된다(2025년 350,000). 이 때문에 증액·재후원의 최근 연도 달성율이 **산출되지 않는다**. ⚠️ 또한 목표만 있고 실적이 0 인 부서가 있다(예: `마케팅전략팀` 2020년 목표 384,031 · 실적 0) — 조직 개편으로 실적이 다른 부서로 귀속된 것으로 보이나 미확인. | 🟠 **현업 확인**: ① 증액·재후원 목표를 2023년부터 편성하지 않는 것이 업무 방침인가, 아니면 입력 누락인가? ② `GOAL_CNT=0` 행은 「목표 미편성」인가 「목표 0 건」인가(전자면 행 자체가 불필요하다)? ③ 조직 개편 시 과거 목표의 귀속 부서를 이관하는 규칙이 있는가? 현재 처리 = **`HAS_POSITIVE_GOAL`(=`GOAL_CNT>0`) 만 달성율 스코프로 사용**(0 은 「목표 미편성」으로 표기 · 창작 금지). 소비뷰 플래그를 `HAS_GOAL_ROW`/`HAS_POSITIVE_GOAL` 로 분리해 오용을 구조에서 차단했다(10 §22-H) | 20 · 10 §22·§22-H |
| ⚠️ **O38-C** | O38 파생 | **[신규 2026-08-05] 매체명(브랜드2) 축 — 「원천 부재」가 아니라 「도달 불가 + 목표측 축 부재」** 로 정정. 실적측은 `GOLD.DIM_AD_CREATIVE.MEDIA_NAME` 이 **실재**한다(채움 8,715/8,716 · distinct **106**)고 `WIDE_AD_*` 3뷰에 `AD_MEDIA_NAME` 으로 노출까지 돼 있으나, `FACT_AD_PERFORMANCE.AD_CREATIVE_SK` 가 **전건 센티넬**(243,545/243,545)이라 도달 불가(**P52** 기지). 목표측은 정본 마케팅 인벤토리 §1 이 *"현재 CRM상에 부서별 목표만 존재하며 매체별 목표는 확인 불가"* 로 이미 명시 | 🔴 **2원인 분리**: (1) 소재 연결키 = **Q10** 소관 (2) 매체별 목표 = **현업 입고**(정본이 부재를 명시) | 10 §22 · 20 |
| DEC-1 | — | 감사컬럼 4종 표준화 | ✅ | 90 |
| DEC-2 | — | DIM_ORG=SCD1 | ✅ | 90 |
| **DEC-19** | 구 DEC-15 | `PREV_MONTH_END_ACTIVE_CNT` 전월 산출 | ✅ **확정 2026-07-31**: **(d) 원천 as-of 재평가** · 활동 = `MBER_STAT_CD` **1~11**(정본 준수, 중단12만 제외) · FDRM 한정. ⚠️ CONF-3 해소 전 구현 불가 | 30 §3-B·§13-A |
| **DEC-20** | 구 DEC-16 | `YEAR_START/END_ACTIVE_CNT` 적재 규약 | ✅ **확정 2026-07-31**: (a) 12개월 반복+SUM금지 명시 · DDL 무변경 | 30 §3-B |
| **DEC-21** | 구 DEC-17 | SILVER 결제결과코드 추가 | ✅ **확정+실행완료 2026-07-31(W1)**: 2컬럼 추가 · DEC-3 판정 유지 · 사유축 전용 · 라벨 커버리지 **100.00%** | 30 §3-B·§11 |
| **DEC-22** | 구 DEC-18 | ML 요건1·3 컬럼 배속 | ✅ **확정 2026-07-31**: 요건1=(a) FMM 스냅샷 / 요건3="그 달 납입 사업 수"(회비 기준) · ⚠️`CRM_MEMBER_SPONSOR_BIZ` 시작일 부재로 (a) 불가 | 30 §3-B |
| 🔴 **DOC-1** | — | **`30_설계_의사결정.md` DEC 번호 중복** — `DEC-15·16·17`이 §3-B와 §9/§10에서 서로 다른 결정을 지칭 | ✅ **해결 2026-07-31**: §3-B를 DEC-19~22로 재번호. 재발방지 = DEC 발급 전 `grep -n "DEC-"` 최대값 확인 | 30 §3-B |
| ✅ **O20** | — | **`CRM_SPONSOR_RELATION.RELATNSP_DSCNTC_YN` COMMENT 불일치** — 주석 "(Y/N)"이나 실제값은 `1`(667,278)/`0`(195,332), `'Y'` **0건** | ✅ **해결 2026-07-31**. 현업 정의서에 **`0=후원중;1=후원중단`** 명시 확인(`컬럼정의서:466`·`BRONZE_CRM 테이블 정보:689`) → 원천·SILVER 승계 모두 정상, **우리 COMMENT만 오기**였다. DDL 파일 + `ALTER COLUMN COMMENT` 양쪽 교정 완료.<br>🟢 **`_YN` 전수 스캔(7종) 결과 이 1건만 예외** — "다른 테이블에도 있을 가능성이 크다"던 추측은 **실측으로 반증**(나머지 6종 전부 Y/N 정상) | 30·04 |
| ✅ **O21** | — | **`GOLD.DIM_REASON.REASON_TYPE` COMMENT 불일치** — 주석 "중단 / 미납 구분" vs 실제값 **코드그룹 ID 336종**, `'중단'`/`'미납'` 리터럴 **0건**(5,839행) | ✅ **주석 교정 2026-07-31**(`06_DDL.sql` + `ALTER COLUMN COMMENT`). ⚠️ **잔여 미결**: 중단/미납 구분 필터가 필요하면 **별도 분류 컬럼 신설** 필요 — SV/Agent가 "중단사유만" 조회하는 시나리오에서 필터 불가 상태는 그대로다 | 30 §11-C |
| 🔴 **O22** | — | **[신규 2026-07-31] BRONZE 회비원천 논리적 중복 → `PAID_FEE`·`BILLED_AMT` 과대계상** — 물리 PK(`MBRFEE_KEY`)는 유일하나 **업무 속성 전건 동일 행이 연속 키로 중복 발행**됨 | **실측 확정**: `TM_PM_MBRFEE_ACMSLT` 46,391,620행에서 (회원·사업·회비월·차수·청구액·청구일·납입액·납입일·상태) 전건 동일 중복 **1,831,286행(3.947%)**. → `PAID_FEE` **768,800,286,349 → 734,855,893,986** = **과대 33,944,392,363원(4.415%)** · `BILLED_AMT` 과대 **39,100,344,913원**. 업무키 grain 초과 2,575,331행·**최대 400행/업무키**(예: `MBRFEE_184973586~597` 전 속성 동일).<br>🔴 **DEC-23/정본 #64·#65와 별개 사안** — 정본이 허용한 것은 *차수별 재청구를 각각 세는 것*이고, *동일 차수의 완전 동일 행 중복*은 아니다.<br>🟢 **W3 `REASON_SK` 영향 없음**(`ROW_NUMBER`로 대표 1행만 선택) · `UNPAID_FLAG_EOM` 영향 없음(`BOOLOR_AGG`) · 🔴 **`SUM` 계열 measure만 영향**.<br>⚠️ 중복은 **BRONZE에 이미 존재** — SILVER 적재 기인 아님. ✅ **BRONZE 직접 정밀 재측정(2026-07-31, `ROW_NUMBER` 방식)이 SILVER 수치와 완전 일치**(46,391,620 → 44,560,334 · 1,831,286 · 339억/391억) → SILVER는 BRONZE를 1:1 정확 매핑. (초기 `CONCAT_WS` 기반 측정치 8,270,695는 NULL 결합 왜곡으로 **오측정 — 폐기**) | 🟠 **현업 확인 필요**: 원천 시스템의 정상 발행인가(실제 복수 청구) 아니면 중복 발행 결함인가. 확인 전 dedup 적용 금지 | 04 · 30 §3-B |
| 🟠 **O23** | 구 "FDRM 15명 불일치" | **[신규 2026-07-31] `FMM.MEMBER_DK` 고아 161명 — 회원마스터 미존재** · ⚠️ **기존 "15명 불일치" 기재는 stale·재현 불가** | **실측 재규명 2026-07-31 (BRONZE 원천 직접 검증)**: 문서 기재(FMM FDRM 1,587,358 vs `CRM_MEMBER` 1,587,343 = 15명)는 **재현되지 않는다**. 실제 = 양방향 2건.<br>🟢 **키 체계 확인**: `S`접두 9자리 = **일시회원(ONCE)** · 7자리 숫자 = **정기회원(FDRM)**. BRONZE 정합 — `TM_MM_ONCE_MBER_INFO` **175,722** = `CRM_MEMBER` ONCE 175,722 / `TM_MM_FDRM_MBER_INFO` **1,587,343** = FDRM 1,587,343 (양쪽 정확 일치).<br>🔴 **① 고아 161명 = 3원인**(161/1,760,506 = 0.009%):<br>&nbsp;&nbsp;· **정규화 결함 1명** — 소문자 `s` 1건. `UPPER()` 정규화하면 BRONZE 일시회원 마스터에 **존재** → SILVER 적재에 대문자 정규화 추가로 해소 가능.<br>&nbsp;&nbsp;· **마스터 스냅샷 누락 159명** — 대문자 `S` **142명**(billing 기원·BRONZE `TM_MM_ONCE_MBER_INFO` 부재) + 7자리 **17명**(FME 기원·BRONZE 정기·일시 마스터 **양쪽 부재**). `20_현업확인_요청.md:59`의 "실회원인데 마스터 스냅샷 누락 8,803건"과 **동일 유형**.<br>&nbsp;&nbsp;· **더미 1명** — `999999999`(BRONZE 양쪽 부재).<br>🟢 **② FDRM 4명 팩트 미출현 = 정상**(결함 아님) — `1015200`·`1015195`·`1014891`(후원중단12·2018-05-11 가입) + `0000001`(전 컬럼 NULL 더미). 4명 전부 **billing 0행·FME 0행**이라 팩트에 나올 근거가 없다.<br>⚠️ **자체 오판 기록**: 최초 기술은 "`S`접두 = 별개 키체계 + 대소문자 혼재 정규화 누락"이었으나 **추론이었고 오류**. `S`접두는 정상 일시회원 체계이며, 정규화 문제는 143명 중 **1명**뿐이다. 원인 = 키 패턴을 BRONZE 마스터와 대조하지 않고 형태만으로 판단. | 🟠 **조치 분리**: (a) 소문자 1건 → `UPPER()` 정규화(즉시 가능) (b) 159명 → 마스터 스냅샷 추출범위 현업 확인 (c) 더미 1건 → 제외 규칙. ②는 종결 | 04 · 20 §5 |
| 🔴 **W3-제약** | DEC-21 파생 | **`REASON_SK` 배선은 미납(`PAY_STAT_CD='F'`) 행에 한정** — 성공(S) 행에 코드그룹 매핑을 적용하면 라벨이 의미상 반대로 붙는다(`SETLE_CD=8` 1,374행: 성공인데 "예금부족"·"무거래"·"자동납부해지") | ✅ **W3 구현 시 준수 완료 2026-07-31** — `reason_rep` CTE에 `WHERE PAY_STAT_CD='F'` 적용. F 한정 시 모순 0 검증됨 | 30 §11-C |
| **DEC-23** | — | **`MBRFEE_SQNC`(회비차수)의 업무 의미** — 재청구/재시도인가 분할 납입 의무인가 | ✅ **확정 2026-07-31: 재청구/재시도(A)**. 근거 = **현업 정본 + 데이터**. 정본 `02_지표사전 공통.md:89-90` 공64·65 비고에 **"청구회비금액: 재청구 중복 포함"** 명시 / 데이터: 완납 그룹 차수가 예외 없이 1, 미납만 2.2, 청구월 1.00 | 30 §12 |
| 🟠 **OPEN-19**<br>**[부활·재정의]** | DEC-23 선행 | **청구↔납입 카디널리티 — 차수로 행 증식** | 🟠 **2026-07-31 부활 후 재정의**. legacy 폴더 단독 존재로 추적 소실됐던 항목. 요구했던 "BRONZE 실측"을 수행 → DEC-23 확정. **실질 미결 = "재청구 중복 특성을 소비 계층에 고지하는 규약 부재"**(결함 아님 — 아래 참조) | 30 §12-C·12-D |
| ❌ **#71-결함**<br>**[철회]** | — | ~~`FMM.BILLED_AMT`(#71) 재청구 중복 합산 결함~~ | ❌ **2026-07-31 당일 철회**. 현업 정본 `02_지표사전 공통.md:89-90`이 **"청구회비금액: 재청구 중복 포함"을 명시**하고, #71 청구 정의가 "결제 요청 프로세스"다 → **정본 준수이며 결함 아님**. 팽창 실측치(전부미납 2.401×)는 유효한 사실이나 **고지 대상 특성**으로 재분류. 원인 = 현업 정본 미대조 | 30 §12-C |
| ✅ **CONF-1** | DEC-19 파생 | **활동회원 범위 충돌** — 현업 정본은 활동 = 활동+미납1~5(코드 1~11, 727,958명), 최초 확정은 코드 1만(683,095명) | ✅ **해결 2026-07-31**: 사용자 재확인 → **정본을 따른다**(코드 1~11). DEC-19 교정 완료.<br>⚠️ **파생 주의**: 미납회원이 활동회원의 **부분집합**이 되므로 `ACTIVE_*`와 `UNPAID_*`는 배타 아님 → "활동+미납=전체" 합산 시 **이중계상**. SV/DDL 주석 명시 필요 | 30 §13-A |
| **DEC-24** | W3 규칙 | **월×회원 대표 미납사유 선정 기준** | ✅ **확정 2026-07-31: 최종 차수(`MBRFEE_SQNC` 최대)의 사유**. 근거 = DEC-23(차수=재시도) 정합 + 실측(최신 청구일 기준과 **99.87% 동일**).<br>🟢 **영향 미미**: 미납 월×회원 3,164,757 중 **98.55%는 사유 1개로 규칙 무관**. 갈리는 것은 45,973건(1.45%, FMM 전체 0.11%) | 30 §14 |
| 🔴 **CONF-2** | — | **`(건)` 지표의 의미 오전제** — `ACTIVE_CNT`·`UNPAID_CNT` 등 `(건)`은 건수가 아니라 **약정금액 ÷ 10,000** (정본 #36·37·52·84·157) | 🔴 **신규 등재 2026-07-31**. W6에서 `UNPAID_CNT`(#36) 재사용 시 정본 정의 파괴 → **신규 컬럼 사용 필수** | 30 §13-B |
| 🟠 **CONF-3** | — | **정본 #51 월말활동회원 판정 조건 내부 모순** — "마지막 중단일이 마지막 재후원일보다 커야함"(중단 우세) vs "재후원 넘버링이 중단 넘버링보다 크다는 조건 필요"(재후원 우세) — **방향 상반** | 🟠 **현업 확인 필요 2026-07-31**. 확인 전 DEC-19 (d) 구현 불가 | 30 §13-D |
| 🔴 **CONF-4** | O16·DEC-5 | **[신규 2026-07-31] D6 조직 4단 설계(`법인>본부/지부>부서>팀`)가 정본과 부분 불일치** — 정본 대조(PROC-2) 결과 4축 중 **2축만 정본 정합** | **정본 대조 실측**:<br>&nbsp;&nbsp;✅ **`CORP`(법인) 정합** — 정본 #114 "사단법인, 사회복지법인" **2종** · `CPR_DIV_CD`(CM019) **"I=사단, S=사복, A=통합"** 명시(`컬럼정의서:172·214`). 데이터 일치 — 회원 보유 법인 정확히 2개(사단 **1,528,654** / 사복 **30,350**), 부서트리 LVL1의 **재단법인 2개는 회원 0명**. ⚠️ 단 **원천은 부서트리 LVL1이 아니라 `CPR_DIV_CD`** 여야 한다(LVL1엔 `ZA` 구조노드 4개 + 직위 `B000007` 이사장 + 회원0 재단법인 2개 혼재).<br>&nbsp;&nbsp;✅ **`DEPARTMENT`(부서) 정합** — 용어사전 121·390·391 · 회원보고서 **4개** · 마케팅보고서 **2개**("현재 CRM상에 **부서별 목표만 존재**" `04:83`). 현행 `DIM_ORG.DEPARTMENT`(695종) 유지 타당.<br>&nbsp;&nbsp;🟠 **`DIVISION`(본부/지부) 불일치** — 정본 지표 #115 "본부/지부"는 존재하나 **실제 보고서는 단독 사용 0건**. 오직 **"실적지부(본부/지부)"**(회원보고서 `05:275`) · **"실적지부"**(`05:311`) 형태로만 쓰인다. 용어사전 **430 "실적지부=실적 지부 명" · 431 "실적지부(본부/지부)=실적 지부 구분"**. → `DIVISION`은 조직 트리(`UPPER_DEPT_ID`)가 아니라 **실적 트리(`ACMSLT_UPPER_DEPT_ID`)** 기반이어야 한다. D6가 조직 계층 2단에 배치한 것이 원천 오해로 보인다.<br>&nbsp;&nbsp;🔴 **`TEAM`(팀) 근거 빈약** — 용어사전 **0건** · 회원보고서 **0건** · 마케팅보고서 **0건**. 유일 근거 = 지표 **#152~155**(연사업/추경 목표) *"본부/지부별, **각 팀별**, 후원사업별"*. → **목표 지표 전용 축**이며, 그 원천(`CRM_BIZ_TARGET`)은 **미입고(E-6)** → 지금 채워도 소비처가 없다.<br>🟠 **DEC-5 명칭 불일치**: "5th 레벨 = 실적부서(**실적 팀**)"의 **레벨 지정은 유효**(실적 트리 LVL5에 실적부서 446/455=98%)하나, 정본은 그 계통을 **"실적지부"**라 부르고 **"실적 팀"이라는 용어는 정본에 없다**. | 🟠 **현업 확인 필요(1건으로 축소)**: **"실적지부" 산출규칙만** — 명칭기반 최근접 본부/지부 도달 418/455=91.9%·미도달 37이고 명칭 판정은 범주오류 위험(O16 오판 이력) → 규칙 확정 필요.<br>✅ **2026-07-31 조치 완료**: ① `DIVISION` **실적지부 재정의**(DDL COMMENT + `ALTER COLUMN COMMENT` + 모델 주석 · 산출규칙 미확정이라 값 NULL 유지) ② `TEAM` **보류 명시**(E-6 입고 시 재개) ③ `CORP` **부서차원 산출불가 명시** + 법인 정본원천(`CPR_DIV_CD`)을 COMMENT에 기록 · `DIM_MEMBER`/팩트 degen 배속은 별도 판단 ④ 🟢 **원천 계통 3컬럼 노출**(`ACMSLT_UPPER_DEPT_ID`·`ACMSLT_DEPT_YN`·`USE_YN`) `ALTER ADD COLUMN` 실행 + 모델·DDL 동기화 — 추론 0, 후속 규칙 확정 시 즉시 활용 | **03설계 O16**·D6 · 30 §6-1 |
| 🟢 **W3-근거** | — | **미납사유 현업 근거 확보** — 정본 #82 "매월 정기회원의 회비미납 시 사유" · 원천 CRM 미납내역 | 🟢 **2026-07-31 확보**. ⚠️ 동시에 정본이 **"캠페인별 미납사유는 볼 수 없음"** 명시 → **SV에서 캠페인×미납사유 교차 노출 금지** | 30 §13-C |
| 🟠 **PROC-1** | — | **legacy·`_archive` 이동 시 미결항목 승계 누락** — OPEN-19가 승계 없이 legacy로 밀려 추적 소실 | 🟠 **재발방지 규칙 등재 2026-07-31**: 문서를 legacy/`_archive`로 옮길 때 미결(OPEN-*/O*/DEC-*)이 있으면 **이슈원장 승계 후** 이동. 승계 없는 이동 금지 | 30 §12-D |
| 🔴 **PROC-2** | — | **결정 확정 시 `99_provided_definition/` 미대조** — DEC-19·#71-결함·W6 `UNPAID_CNT` 재사용 3건이 이 누락에서 발생 | 🔴 **재발방지 규칙 등재 2026-07-31**: 지표·측정 의미가 걸린 결정은 **`02_지표사전 공통.md`·`03_지표사전 신규.md` 대조를 선행**한다. 내부 문서·데이터만으로 확정 금지 | 30 §13 |
| 🔴 **PROC-3** | — | **[신규 2026-07-31] 검증 계층 위반 — "BRONZE 원천 확인" 지시를 하류(SILVER/GOLD)로 대체하거나 추론으로 갈음** | 🔴 **재발방지 규칙 등재**. 동일 세션에서 **4건 발생**:<br>&nbsp;&nbsp;① **C-9-R**: BRONZE 테이블명 조회 실패(`TM_CM_SNDNG_DTLS` 부재) 후 **정확한 테이블을 찾지 않고 포기**, `GOLD.FACT_SERVICE_EVENT`로 우회 검증. 실제 원천은 `TD_MS_EMAIL_LQY_SNDNG`(497,777행·`URL_OTHBC` 2컬럼 전건 NULL) + `TD_MS_MSG_AT_LQY_SNDNG`(1,113,284행·`CLICK` 5컬럼 전건 NULL).<br>&nbsp;&nbsp;② **E-6**: `SILVER`·`GOLD` 0행만 확인하고 **BRONZE 입고 여부를 조회하지 않음**. 지시가 명시한 "bronze에 데이터가 입고된 경우"를 검사하지 않은 정면 위반. 재조회 결과 BRONZE_CRM **43개 테이블 전수·빈 테이블 0** 중 사업목표(#152~155) 테이블 미입고 확정(단 `TM_CM_MBER_DVLP_GOAL` 25,344행 = 개발목표·`CRM_DEV_TARGET` 원천으로 **별개**).<br>&nbsp;&nbsp;③ **O23**: `S`접두 키를 **형태만 보고** "별개 키체계·정규화 누락"이라 결론. BRONZE 마스터 미대조 = **추론 금지 위반**. 실제는 정상 일시회원 체계이며 정규화 문제는 143명 중 1명뿐.<br>&nbsp;&nbsp;④ **O22**: BRONZE 측정에 `CONCAT_WS`+`NULLIF` 사용 → 8,270,695(오측정). SILVER 값 1,831,286과 **4.5배 괴리를 규명하지 않고** "SILVER가 더 정확"으로 넘김. `ROW_NUMBER` 재측정 시 BRONZE=SILVER 완전 일치.<br>**규칙**: (a) "BRONZE 확인" 지시는 하류 테이블로 **대체 불가** — 테이블명을 못 찾으면 `INFORMATION_SCHEMA.COLUMNS` 컬럼명 검색으로 특정한다. (b) 키·코드 **형태**로 의미를 추정하지 않고 마스터/코드사전과 대조한다. (c) 동일 대상의 두 측정치가 어긋나면 **원인 규명 전 어느 쪽도 채택하지 않는다**. (d) 중복·유일성 측정은 문자열 결합이 아니라 `ROW_NUMBER() OVER (PARTITION BY 컬럼목록)` 을 쓴다(NULL 결합 왜곡 회피). | 04 · 30 |
| 🟠 **W6-설계** | DEC-23 파생 | **[승계 2026-07-31] 납입 이행 카테고리 신규 measure 5종 설계안** — `99_NEXT_SESSION.md` 재작성 시 유실 위험이 있어 이슈원장으로 승계(PROC-1) | **제안 컬럼**(전부 FMM 신규 · `HAS_BILLING=FALSE`·기부금 전용 월은 **NULL** — 0이나 '완납'으로 채우면 완납률 부풀림):<br>&nbsp;&nbsp;· `PAYMENT_FULFILLMENT` — 완납/일부미납/전부미납 (degen dim)<br>&nbsp;&nbsp;· `BILLED_OBLIGATION_CNT` — 의무 건수 = `COUNT(DISTINCT SPNSR_BSNS_ID)`. 🔴 청구행수·차수 금지<br>&nbsp;&nbsp;· `FULFILLED_OBLIGATION_CNT` — 이행 건수<br>&nbsp;&nbsp;· `UNFULFILLED_OBLIGATION_CNT` — 미이행 건수. 🔴 **`UNPAID_CNT` 재사용 금지**(CONF-2: 정본 `(건)`=금액÷10,000)<br>&nbsp;&nbsp;· `BILLING_ATTEMPT_CNT` — 청구 시도 행수(재청구 포함), 재시도 강도 ML feature<br>**실측 분포**(월×회원 37,148,615): 완납 33,846,080(91.11%) / 전부미납 1,694,801(4.56%) / 일부미납 1,607,734(4.33%). 🟢 `1,694,801+1,607,734 = 3,302,535` = 현행 `UNPAID_FLAG_EOM`=TRUE **정확 일치**(기존 boolean의 정확한 2분할) · 현행 boolean은 TRUE 안에서 전부/일부가 51.3%/48.7%로 **심각도 정보가 사실상 없다** · 일부미납의 98.63%(1,585,668)는 진짜 부분미납, 재시도후완납 오분류 22,066(1.37%).<br>🔴 **O22 미해소로 위 분포는 중복 미제거 기준 → 재산출 필요.** "재시도후완납 오분류 22,066"은 중복 행과 구별해 재검증할 것.<br>❌ `BILLED_AMT` 교정은 **철회**됨(정본 준수) — 기존 #71·#36은 건드리지 않는다. | 🔴 **차단**: 정본 215지표 외 신규 → 현업 제안 필요 + O22 해소 선행 | 30 §12-C |
| 🟠 **O24** | 구 O6 부분 | **[신규 2026-08-03] FME 개발구분 도메인 부분적재 → 상태축 소실 + `DEV_CNT` 56.86% 과대계상** | **트리거(현업 항의)**: *"회원 상태가 개발·중단·미납·활동·증액·감액 등 다양한데 GOLD 엔 `dev`·`stop` 둘만 있다."*<br>**판정 — 항의는 옳으나 원인이 '미적재'가 아니라 의미혼입**(O16 계열). 열거된 6개는 **서로 다른 3축**이다: 사건축(개발·증액·감액=FME) · 상태축(활동·미납=`DIM_MEMBER.MEMBER_STATUS_NAME` MM010, **이미 한글 라벨 완비** — 활동회원 682,897·후원중단 859,387·미납 10종 45,058) · 중단(양쪽 존재). 현업이 `EVENT_TYPE` 한 컬럼만 보고 판단.<br>🔴 **실제 결함**: SILVER `CRM_MEMBER_DEV` 는 `DVLP_DIV_CD`(정본 MM015)를 **정상 보존**하는데 `FACT_MEMBER_EVENT.sql:21·30` 이 **무시하고 전건 `'DEV'`·`DEV_CNT=1` 하드코딩** → 5종(1신규 1,788,612·2증액 367,295·3감액 292,285·4재후원 135,971·5후원중단 1,010,680)이 한 값으로 뭉개졌다.<br>🔴 **부수 발견이 원 항의보다 심각 — `DEV_CNT` 56.86% 과대계상**: 3,594,843 vs 정본 공#121(개발=신규·증액·재후원) **2,291,878**. 감액(금액 **−124.4억**)·후원중단(**−215.2억**) 이 "개발실적"으로 계상됐다. 독립 확증 = `FACT_TARGET_DEV.DEV_TYPE` 실측이 `1`·`2`·`4` 3종뿐.<br>❌ **IRSD 미채택**: 정본 `테이블정의 20260629.csv:36` 이 `RDCAMT_YN` 을 *"안 바뀌는 경우도 있음"* 으로 **현업이 직접 불신 명시** + 실측 확증(오분류 **752키**·판정불가 **50,295키=16.5%**) + IRSD 키의 **99.62%가 `DVLP_AMT` 코드 2·3의 부분집합**. | ✅ **적재 완료 2026-08-03**: `DVLP_DIV_CD`·`DVLP_DIV_NM`·`SPNSR_AMT` 신설(SILVER·GOLD·WIDE) + `DEV_CNT`/`DEV_MEMBERS` 코드 1·2·4 한정 교정 + MM015 `accepted_values` 가드 신설. **컬럼명=BRONZE 원천명 그대로**(정본 컬럼정의서 504행 현업 용어쌍) — 현업이 BRONZE 를 보고 있어 신개념 도입 금지. `build ERROR=0·PASS=31·WARN=4`(전부 기존 고아), **행수 전부 불변**(3,594,843/4,633,105/40,054,883)=fan-out 0, FMM 롤업 정확 전파.<br>🟠 **잔여 1 — 후원중단 원천 중복 현업확인**: 코드5 924,044키 중 **923,931(99.99%)이 중단원천에 동일 회원·일자로 존재**. measure 는 코드5=0 처리로 이중계상 없으나 `DVLP_DIV_NM='후원중단'` 행수는 STOP 과 중복 → **합산 금지**(DDL·WIDE COMMENT 명시).<br>🔴 **파생 — `FMM.AMT_INCREASE_CUM_CNT`·`AMT_DECREASE_CUM_CNT` 가 불신 컬럼 기반**(`FACT_MEMBER_MONTHLY.sql:101`, W4/DEC-22) → 권위 원천 `DVLP_DIV_CD` 재산출 검토. 별도 트랙<br>🔴 **[2026-08-03 서술 정정] "증액·감액 GOLD 미적재" → "정본 지표 슬롯 공백"**(P15/BLOCKING-5). FMM 에 슬롯이 **이미 존재하되 전건 0/NULL** 실측(40,054,883행): `INCREASE_CNT`(공#151)·`INCREASE_MEMBERS`(공#150)·`DECREASE_CNT`(공#38)·`CHURN_CNT`(신#20) **합계 0·비영 0행**, `INCREASE_FLAG`(공#33) **전건 NULL**. 반면 정본 아닌 `AMT_*_CUM_CNT` 는 **적재됨**(6,128,968/2,518,575) — COMMENT 가 "정본 #151/#38과 다름·혼용 금지" 명시. **유사명 대체 사용 금지**. 채우는 기준(사건 vs 월말스냅샷)은 현업확인 대기 | **03설계 §5 O24**(정본) · 03설계 FME절 · 20 |
| 🟢 **O25** | G3/G5 파생 | **[신규 2026-08-03] BRONZE 코드체계 → SILVER 보존율 37.6% + `FME.STOP_REASON` 계보계약 위반** | **측정(정본 컬럼정의서 정식 CSV 파싱 + INFORMATION_SCHEMA + dbt 모델 계보 파싱)**: 표준 코드그룹 컬럼 **85건**(BRONZE 실존) 중 SILVER 보존은 **32건(37.6%)** 뿐. 내역 = 라벨쌍 완비 13 · 코드만 19 · **SILVER 모델 자체 부재 9** · **모델O·SELECT 탈락 44**. P27 그대로 이 결손은 행수·not_null·참조무결성 어느 테스트에도 걸리지 않는다.<br>🔴 **계보 계약 위반**: `04_컬럼계보매핑.md:105` 가 `FME.STOP_REASON`(정본 공#162)의 변환규칙을 *"사유코드→라벨"* 로 명시했으나 실적재는 **raw 코드**(1·14·16…)였다. SILVER `CRM_MEMBER_DISCONTINUE.DSCNTC_RSN_NM` 라벨은 **채움률 100%(1,038,262/1,038,262)** 로 이미 존재 — GOLD 가 전파만 안 한 O24 동일 유형.<br>🟢 **G5 통과 확인**: `STOP_REASON` distinct 20 = MM005 사전 적중 **20/20**·사전부재 0. 단 **6종(366행·0.035%)이 폐지코드**라 `USE_YN='Y'` 필터를 걸면 라벨이 조용히 사라진다(현행 모델은 무필터라 안전).<br>⚠️ **오탐 정정 3건** — COMMENT 정규식 스캔(`(CM|MM|MS|PM|RM)[0-9]{3}`)이 **설명문 속 예시**를 도메인 자기선언으로 오독했다: `DIM_REASON.REASON_TYPE`(PM019 — 실측 336/336 전건 `CRM_CODE.CD_ID` 매칭, COMMENT 이미 O21로 정확) · `FMM.REASON_SK`(PM002 — 복합 매핑규칙 서술) · `DIM_ORG.CORP`(CM019 — 원천 지시). 18컬럼 중 **진짜 자기선언 15 / 설명문 3**.<br>⚠️ **감사 정본(06) 낡음** — 감사일 2026-07-28 이후 배선된 `FMM.REASON_SK`(비영 3,164,724)·`FME.STOP_REASON`·`FME.STOP_CHANNEL` 이 하드코딩 목록에 잔존. 인용 전 실측 대조 필수.<br>🔴 **코드그룹 오지정 1건** — `IRSD.AREA_CD` 정본 CM011 vs 모델 CM018. 실측상 코드→지역 대응 동일·**라벨 형식만 다름**(정식명 vs 약칭)이라 값 오류는 아니나 정본 이탈. | ✅ **조치 완료 2026-08-03 (dbt build 대기)**: ① **SILVER 신설 38컬럼** — `ALTER TABLE ADD COLUMN` + 모델 9개 SELECT 전파 + DDL 정본(`08_SILVER_테이블DDL`) 동기화. `CREATE OR REPLACE` 미사용(FK·GRANT 보존). 대상 = 44건 중 **41건**(3건 제외: `TRNSMS_STAT_CD`→`SNDNG_RST_CD`, `EMAIL_RECPTN_CD`→`EMAIL_RECPTN`, `PSTMTR_RECPTN_CD`→`PSTMTR_RECPTN` 은 **이미 변환 형태로 노출** — 중복 신설 안 함) → UNION 중복 제거 후 물리 **37 + `DSCNTC_PATH_NM` 1 = 38**.<br>② **GOLD `FME.STOP_REASON_NM`·`STOP_CHANNEL_NM` 신설** + `WIDE_MEMBER_EVENT` 노출 + `06_DDL.sql` 동기화.<br>③ **`FME.REASON_SK` 배선** — 종전 전건 0 → `DIM_REASON`(MM005) 실조인. **사전 검증: 20/20 SK 일치·고아 0**. NULL 사유는 0(Unknown 멤버) 라우팅.<br>④ `WIDE_MEMBER_EVENT.REASON_TYPE` COMMENT 를 O21 교정 반영으로 갱신.<br>🟢 **검증 완료(build 전)**: SILVER 9모델 **컴파일 전수 OK** · 모델 출력 컬럼수 = 물리 컬럼수 **9/9 정확 일치** · `REASON_SK` 해시 정합 확인.<br>✅ **빌드 완료 검증 2026-08-03**(전체 빌드 `PASS=268 WARN=25 ERROR=0 TOTAL=293`): ① **컬럼 정렬 무결** — 신설 25컬럼 distinct 집합이 BRONZE 와 **완전 일치(누락0·초과0)**, `STOP_REASON`↔`STOP_REASON_NM` 짝 정합, 인접컬럼 오염 0 → **dbt append 는 이름 기반**임이 실측 확증됨(최고위험 해소). ② **행수 9/9 전부 불변**(fan-out 0) · `DEV_CNT` 2,291,878 불변(O24 회귀 없음). ③ **UNION NULL 패딩 설계대로**(회비전용/ONCE전용/채널전용 각각 타 브랜치 0). ④ `FME.REASON_SK` 비영 1,038,262·distinct 20·**고아 0** · `STOP_REASON_NM` 결손 0 · `WIDE` 47→**49컬럼**·COMMENT 누락 0.<br>⚠️ **1차 빌드는 실패했었다** — `--select FACT_MEMBER_EVENT` 만 전달돼 `TOTAL=15`, SILVER·WIDE 미실행. **`ERROR=0` 은 의도한 대상이 실행됐음을 뜻하지 않는다**(교훈: 선택 빌드 후 대상 객체 실값 확인 필수).<br>✅ **회귀 가드 42건 신설** — 초판이 P27 을 명시하고도 테스트를 0개 넣지 않은 것을 자기검토로 적발. `_crm_schema.yml` 38 + `_gold_ready_schema.yml` 4 (`accepted_values`, 실측 distinct 전량, 폐지코드 포함, 코드=error·라벨=warn).<br>✅ **DDL 정본 구문검증** 10블록 전수 통과 + 컬럼수 실테이블 일치. ✅ **계약문서 동기화** — 계보표에 코드/라벨 4행 분리 + "상태=OK 자기인증" 경고, 인벤토리 FME 반영.<br>🔴 **자기검토 신규 발견**: (a) **정본 `코드그룹ID` 오지정 확정 1건** — `RQEST_RST_CD`→PM021 사전은 코드 **1개**뿐인데 원천 101종(PM018 이 41 적중). 85 모집단·G2·G3 기반이 흔들린다 (b) **"사전부재 29"의 실체는 sentinel `'0'`** — `AREA_CD` 20,624행·`REL_CD` 7,506행 등. 사전 보완 요청이 아니라 **미지정 관례 확정 + Unknown 라우팅**이 정답 (c) `CARD_DIV_CD` 도 정본이 PM044/PM052 이중지정 (d) **G2 초판 수치 오류** — "폐지 5"는 중복집계, 파티션은 53·29·3=85 (e) 감사정본(06) CRM 행은 이름매칭 한계로 신뢰 곤란(대체노출 0 실현 불가).<br>🔴 **잔여 미결**: ✅ (a) **동명이의 2건 해소 완료 [2026-08-03 O26]** — `PRCS_STAT_CD`=**개명**(회비/발송 변별 토큰) · `SEX`=**값 복원**(축약이 원천 파괴였으므로 개명 아님). 선택 기준 = "양쪽이 다 원천 충실한가"(**P32**), 결정 정본 30 DEC-25 §15-C, 완료 등재 90 §3 (b) SILVER 미참조 3테이블(9컬럼) 수요 확인 (c) 라벨 미배선 잔여 **21건**은 **그룹 개별 실측 후** 배선(정본 신뢰불가 → **DEC-26 P29 3단계 적용**) ✅ (d) `IRSD.AREA_CD` CM011/CM018 → **CM018 확정·현업 회신 불요**(공#131 약칭 근거, 90 §3) | **10 §13**(진단 정본 — 관문측정 G1~G5 원자료 포함) · **30 DEC-26** · 03설계 §5 O24 · 11 |
| 🟢 **O26** | O25 파생 | **[신규 2026-08-03] 명명 규칙 전환(코드=BRONZE 원천명·라벨=분석용어) + 성별축 정본 위반 교정** | 🔴 **정본 위반 발견**: `DIM_MEMBER.GENDER_NAME` 이 하드코딩 `CASE`로 **여성/남성/미상 3종**을 만들었으나 정본 지표 **공#130 성별 정의는 "남 / 여 / 기업 / 단체 / 기타" 5종**이다. 정본에 없는 '미상'을 창작하고 **법인·단체를 '미상'으로 오라벨**했다(실측: `SEX='U'` 115,358명 = 개인 60,366 + **기업 40,003 + 단체 14,989 = 54,992명(47.7%)**). P21(개념 부재를 결측으로 오판) 유형.<br>🔴 **원천 파괴**: SILVER `CRM_MEMBER.SEX` 가 CM013 **8종을 M/F/U 3종으로 축약** — 값 충실도 검사 24건 중 **유일한 불일치**(SILVER만 3·BRONZE만 8). 국내/외국인 축 완전 소실. **정본 컬럼정의서 비고가 이미 경고**했다: *"특이사항, 6=단체, 7=기업, 8=기타 값을 보면. 컬럼설명은 성별이나 **성별만으로는 사용하지는 않음**"* — O24 `RDCAMT_YN` 과 동일한 '정본 비고 무시' 패턴.<br>🟢 **해결의 열쇠는 코드사전에 이미 있었다** — **CM017**(1,3→남자·2,4→여자·5,8→기타·6→단체·7→기업)이 **동일 코드값의 성별 축 투영**이며 라벨 5종이 **정본 공#130 과 정확히 일치**한다. ⚠️CM017 은 정본 컬럼정의서가 어떤 컬럼에도 지정하지 않은 그룹(0건) — 사용 근거는 '정본 지정'이 아니라 '공#130 값정의 일치'(현업 확인 대상).<br>🟢 **명명 규칙 근거**: BRONZE 가 **이미 수식어 접두 관례**를 쓴다(`ACT_`/`ACMSLT_`/`REGIST_DEPT_CD` · `EMAIL_`/`MOBLPHON_`/`ETC_CTTPC_STAT_CD` · `TSTM_`/`ETC_TSTM_DIV_CD`) → 신개념 도입이 아니라 원천 관례의 일관 적용. 동명이의 실측 확정 = **정확히 2건**(`SEX` M,F,U vs 0~8 · `PRCS_STAT_CD` R,F,S vs 0,1). `CPR_DIV_CD`·`SETLE_CD`·`MBER_DIV_CD`·`AREA_CD` 등은 **conformed**(제 자기검토의 `SETLE_CD` 의심은 오판 — 4테이블 전부 PM040 내 100%).<br>🟢 **부수 해소**: 정본 공#131 지역 정의가 "서울/인천/경기/강원"(**약칭**)이라 미결 질문8(CM011 정식명 vs CM018 약칭)이 **CM018 정답으로 해소**. 정본 컬럼정의서의 `IRSD.AREA_CD`→CM011 지정이 지표 정의와 불일치. | ✅ **조치·검증 완료 2026-08-03**: ① **물리 8건**(`ALTER RENAME`/`ADD`, `CREATE OR REPLACE` 미사용 → FK·GRANT 보존) — GOLD `GENDER→SEX`·`MEMBER_STATUS→MBER_STAT_CD`·`MEMBER_TYPE→MBER_DIV_CD`·`ENROLL_PATH→JOIN_PATH_CD`, `SEX_NM` 신설(GOLD·SILVER), SILVER `PRCS_STAT_CD→MBRFEE_PRCS_STAT_CD`(회비)·`→PSTMTR_PRCS_STAT_CD`(발송).<br>② **하드코딩 라벨 폐기** — `CASE '여성'/'남성'/'미상'` → `CRM_CODE` CM017 조인. 라벨은 사전이 정본이며 사전 변경이 자동 반영된다.<br>③ **SILVER `SEX` = CM013 raw 무변환** + `SEX_NM`(CM013 라벨) 신설 → 국내/외국인 축 복구.<br>④ **WIDE 4개 재구성** — 종전 코드만 노출(`MEMBER_GENDER`=M/F/U)하던 것을 **코드+라벨 병기**로(`SEX`·`SEX_NM`·`MEMBER_GENDER_NAME`·`MBER_STAT_CD`·`MEMBER_STATUS_NAME`·`MBER_DIV_CD`·`MEMBER_TYPE_NAME`·`JOIN_PATH_CD`·`MEMBER_ENROLL_PATH_NAME`).<br>⑤ **SV 6개 재배포 완료**(정본 `05_SV-Agent_ai/05_SV_DDL.sql` 수정 후 `GN_DW_ADMIN` 역할 실행) — 4 SV 의 성별/상태/구분 차원을 **코드→라벨**로 교체 + 원천코드 차원 병설, 스모크(8-3) 갱신. **검증: 소유자 6/6 `GN_DW_ADMIN` 유지 · GRANT 18건 재부여 확인(SV당 OWNERSHIP+REFERENCES/SELECT×3롤)**.<br>⑥ `DIM_MEMBER_CURRENT` 뷰 재생성 + GRANT 3건 복구 · 정본 `08_After_Deploy_DBT.sql` 동기화.<br>⑦ **DDL 정본 2 · 가드 · 계약문서 3 동기화** — `06_DDL.sql`·`08_SILVER_테이블DDL` · `_crm_schema.yml`(개명 2 + `SEX` CM013 가드 신설) · `04_컬럼계보매핑`·`05_지표GOLD매핑`(12행)·`05_필드 인벤토리`.<br>🟢 **빌드 검증 완료 2026-08-03** (`PASS=311 WARN=25 ERROR=0 SKIP=0 TOTAL=336` — O26 가드 43건 반영으로 293→336): `DIM_MEMBER` **7,925,716행 불변**(fan-out 0) · `SEX` **CM013 8종 + NULL 421** · `SEX_NM` **8종**(국내/외국인 축 복구) · `GENDER_NAME` **정본 공#130 5종 실현**(여자 4,331,147·남자 2,985,428·기타 415,365·기업 145,124·단체 48,231) · **WIDE 12개 전량 재생성** · O26 가드 전건 pass(`SEX`×3테이블·`MBER_DIV_CD`×3·`MBRFEE_PRCS_STAT_CD`·`PSTMTR_PRCS_STAT_CD`) · **WARN 25 는 전부 기존 고아키·not_null**(2-E 계열, O26 유래 0).<br>🔴 **잔여**: (a) **CM017 정본 미지정 현업 확인**(문서20 §H — 회신 없이 적용·배포 완료, DEC-26 규약에 따라 병렬 진행) (b) ⚠️ **`'미상'` 이 완전 소멸하지 않았다** — `COALESCE(...,'미상')` 로 **`SEX IS NULL` 421행(0.005%)** 잔존. 종전 위반(값이 있는 55,096명 법인·단체를 오라벨)과는 성질이 다르나 정본 5종에 없는 라벨이므로 센티넬 `(미매핑)` 과 통일할지 **판단 대기** (c) ⚠️ **초판 수치 정정** — 초판 "기업 40,003·단체 14,989" → 빌드 후 SILVER 실측 **기업 40,010·단체 15,086**(합 55,096 = 회원 1,763,065 의 3.13%). 인용 시 후자 (d) `REGION`·`AGE_BAND`·`NEW_EXISTING_FLAG` 미주입 유지 — 채울 때 코드컬럼 `AREA_CD`/`AGE`/`RELATNSP_DIV_CD` 병설 규칙을 COMMENT 에 기록해 둠 | **10 §13**(진단 정본) · **30 DEC-25·DEC-26** · 20 §H · 90 §3 · 05_SV_DDL · 06_DDL · 08_After_Deploy |
| 🟠 **O27** | O25 파생 | **[신규 2026-08-03] SILVER→GOLD 컬럼 보존율 최초 측정 — 54.7%** | 선행 세션이 `MEMBER_TYPE`(SILVER 실재·GOLD CTE 열거 탈락)을 발견했으나 **같은 유형을 아무도 세어보지 않았다**. O25 는 **BRONZE→SILVER**(37.6%)만 측정했다. **측정(2026-08-03 전 항목 본 세션 실측 · 4원 대조 = `INFORMATION_SCHEMA` × dbt 78모델 `ref()` 계보 × 모델 본문 토큰 스캔 × GOLD 물리 `COUNT`/`COUNT_IF`)**: SILVER DATA 컬럼 **519**(696−`DW_*` 177) 중 GOLD 직접소비 테이블 컬럼 **364** → 보존 **199(54.7%)** · 탈락 **165(45.3%)**. 부수: SILVER 내부 체인만 소비 127(5테이블) · **소비처 0 = 28컬럼/4테이블**. GOLD 물리 미주입 **125/454(27.5%)** = ALL_NULL 59 + ALL_ZERO 66 (FMM 37·FSE 21·FEP 14·FTB 12).<br>🔴 **탈락 165 판정(자기검토 재계수)** — **A 조용한탈락 ~~15~~→12** · **B 차원재설계대기 6** · C 원천값없음 1 · D 문서화 ~~13~~→**12** · **E 미판정 ~~130~~→134**. 재계수 사유 = **판정 오류 6건**(10 §14-G): A→D 2(`ERP_BUDGET` 추경·조정은 `FACT_BUDGET.sql:6·23` 에 **이미 TODO 명시** — 조용하지 않았다) · A→E 1(`CANCL_RDCAMT_RSN_CD` *"FME 사유축 부재"* 는 **거짓** — 31종 전부 `DIM_REASON` 실재·`STOP_REASON` 20종 포함) · D→E 3(`CRM_CODE.UPPER_CD_ID`·`SORT_ORDR`·`USE_YN` 은 어떤 모델도 언급 없어 D군 정의 불충족 · 게다가 `UPPER_CD_ID` 는 §14-B 가 직접 발송구분 계층 원천이라 적은 컬럼 = 자기모순) · 대응처 오귀속 1(`PARTCPT_SEQ`→카운트 아님, **FEP 행식별자 부재**가 진짜 결손) · 분모 오용 1(`AD_SEC_NM` *"14.0%"*→**VIDEO 95.2%**) · BRONZE 미확인 1(작업조건#3 위반, 결론만 운 좋게 맞음). 🔴 **공통 원인 = 짝짓기를 이름·의미 유사성으로 했다** — 같은 절에 `P36` 을 적으며 그 교훈을 위반. 신규 교훈 **P38~P40**.<br>🔴 **A군**(SILVER 실값 有 + GOLD 대응 컬럼 미주입): `CRM_MEMBER_DEV.AGE`(100%·CM014 12/12)→`DIM_MEMBER.AGE_BAND` · `.AREA_CD`/`AREA_NM`(99.4%·CM018 18/18)→`REGION` · `.SPNSR_BSNS_ID`(100%·29종)→`FIRST_SPONSORSHIP`·`FME`/`FMM.SPONSORSHIP_SK` · `.CANCL_RDCAMT_RSN_CD`(36.4%·31종) · `CRM_MEMBER_STATUS_HIST.BF_STAT_CD`/`BF_STAT_NM`/`CHN_STAT_NM`(**100%·7,501,761·12종=MM010**)→**GOLD 상태전이 축 전무** · `CRM_PAYMENT_BILLING.MBRFEE_DIV_CD`(97.6%·4종)→`FMM.REGULAR_FEE` 등 3 ALL_ZERO·`DIM_PAYMENT.FEE_TYPE` · `CRM_EVENT.RCRIT_PSNNL_CO`(88.8%·74종)→`FEP.RECRUIT_CNT` · `CRM_EVENT_PARTICIPATION.PARTCPT_SEQ`(100%) · `ERP_BUDGET.CHN_BUDGET_AMT`/`ADJ_BUDGET_AMT`(99.3%)→추경·조정 슬롯 · `CRM_ORG.UPPER_DEPT_ID`(100%·321종) · `AGENCY_AD_CREATIVE.AD_SEC_NM`(14.0%·8종)→`DIM_AD_CREATIVE.DURATION_SEC`.<br>⚠️ **P14 위반 재발** — `DIM_AD_CREATIVE.DURATION_SEC` 주석 *"원천 부재(초수)"* 는 오류다(`AD_SEC_NM` 1,217행 실재).<br>🔴 **파생 — DEC-27 §17-C `AGE_BAND` 판정의 전제가 틀렸다**: `AGE` 는 raw 나이가 아니라 **CM014 12종 코드**(1=10대미만…9=70대이상·10=단체·11=기업·12=기타). 실적재 distinct 12종·채움 100% = **12/12 완전 일치** · 지표용어사전:441 *"연령대/연령대/문자"* 와 모순 없음. 🟢 **독립 교차검증(P21)**: `AGE=10`(단체) 21,920행 **전건 `SEX=6`(단체)** · `AGE=11`(기업) 64,581행 **전건 `SEX=7`(기업)** — 둘 다 100%. → **구간 창작 불요**(원천이 이미 구간화). 생년월일 입고는 `AGE_BAND` 선행조건이 **아니고 시점정확 연령**의 선행조건이다.<br>⚠️ `BRONZE_CRM.TM_MM_FDRM_MBER_DVLP_AMT.AGE` COMMENT *"연령"*(NUMBER)도 오류 — 실제 연령대 코드(DEC-26 사례 추가).<br>🔴 **B군 판정 2회 수정(자기검토)** — 초판 "DROP" 은 **오답**이었다: `SEND_TYPE_L/M/S` 는 **정본 지표 #133~135(발송구분 대/중/소)** 이고 WIDE_SERVICE_EVENT 가 이미 노출한다 → DROP 하면 지표 3개 소멸. 실측: `SEND_GBN_TOP` 값은 코드가 아니라 **`CRM_CODE.CD_ID` 자체**(MS046결연·MS047회원·MS048회비·MS049서비스·MS050사업보고 … 12종) · MID 16종 · BOT 42종 · 조합 65. 지표 #134 값열거가 MS046 라벨과 일치(교차확인). **그러나 채움도 오답** — grain 10→74 함수종속 불성립·커버리지 0.106%. ⚠️부수: `SNDNG_TY_CD` 도메인이 0/1/2/3 4종뿐이라 **P29 3원 대조가 판별력을 갖지 못하는 최초 사례**(227그룹 spurious 매칭·SVL-1 동근). → **차원 재설계 결정 대기**(①grain확장 ②DIM_SEND_TYPE 분리, 둘 다 `SERVICE_SK` 파괴적 변경 · 잠정권고 ②).<br>🟢 **부수 재측정**: GOLD `'미상'` 잔존은 **`DIM_EVENT.EVENT_KIND_NAME` 1행뿐**(SK=0 센티넬 행이 타 컬럼은 `(미매핑)`인데 이 컬럼만 `'미상'`). `DIM_MEMBER` 성별·상태 `'미상'` **0 재확인**. | ⬜ **미착수(사용자 build 대기)** — 결정 정본 **30 DEC-28**: ① A군 15 배선(DEC-27 §17-C 와 통합) ② 🟠 B군 = `DIM_SERVICE` 차원 재설계 **결정 대기**(DROP 금지) ③ `AGE_BAND` **채움**으로 전환 ④ `DURATION_SEC` 배선(커버리지 14.0% 병기) ⑤ `DIM_EVENT` 센티넬 통일 ⑥ **E군 134 개별 수요 판정** + A군 12건도 §14-G 3단 확인으로 재검증 ⑦ 소비처 0 테이블 **4종**(§13-I #5 의 "3테이블"은 재계수 결과 4테이블) | **10 §14**(진단 정본 · P34~P40) · **30 DEC-28** · 30 DEC-27 §17-C·§17-D · 50 BLOCKING-5 |
| 🟡 **O28** | O27 §14-G #1 파생 | **[신규 2026-08-03] `PARTCPT_STAT_CD` — 한 컬럼에 두 코드체계가 혼입** | `CRM_EVENT_PARTICIPATION.PARTCPT_STAT_CD`(1,134,126행)가 `EVENT_SOURCE` 별로 **완전히 다른 코드체계**다(2026-08-03 실측): **`CRMN`(캠페인행사) = 소정수 `1~6` 152,046(99.98%)** vs **`EVENT`(일반행사) = MS304 영문 퍼널 `Success`·`1_step_right`~`5_step_right`·`1_step_fail`~`5_step_fail`(값 100~220) 707,476(99.998%)**. + 🔴 **오염값 `)` 2행** · NULL 11,240 · 고아 EVENT_KEY 263,611(기지 O-E).<br>🔴 **[2026-08-04 BRONZE 재실측 정정 4건 — 정본 10 §15-B]** ① MS304 는 **12종**이며 초판이 **`120=Fail` 을 누락**했다(BRONZE 실적재 38행 존재) → 12/12 완전 일치 ② *"값 100~220"* 은 부정확 — 실측 범위는 **110~220**(사전에 100 없음) ③ 🔴 조치안 ②의 판별자 지정이 **실행 불가**였다 — `EVENT_SOURCE` 는 참여 테이블에 없고(`CRM_EVENT` 마스터 소속) 마스터 조인은 **고아 23.2% 에서 실패**한다. **정답 = `EVENT_KEY` 접두**(`EVENT_`/`CRMN_`, 조인 불요·전건 판별·교차오염 0) ④ 🔴 오염값 `)` 은 **BRONZE 에 이미 존재**(길이 1·인접 컬럼 정상 → 필드 밀림 아님) → *"SILVER 정제 파싱 결함"* 가설 **폐기**, **원천 입력 오류로 재분류**.<br>🔴 **G5 가 놓친 이유가 핵심** — G5 는 *같은 컬럼명·다른 테이블* 패턴만 스캔했다. 이 건은 **같은 테이블·같은 컬럼 내부**가 갈린 형태이고 **동명이의보다 나쁘다**: 개명으로 해소 불가 · `accepted_values` 는 합집합을 통과시킨다.<br>🔴 **무증상 오답 경로 2개** ① `FEP.PART_STATUS` 가 그대로 노출 → `WHERE PART_STATUS='참여'` 가 **0행 반환** ② 두 체계 합산·GROUP BY 시 **집계가 조용히 틀린다**.<br>🔴 **`FEP` 상태별 카운트 5종 전건 0 의 진짜 원인이 이것**이다 — 컬럼 탈락이 아니라 **코드체계 미확정**(O27 초판이 `PARTCPT_SEQ` 탈락으로 오진).<br>⚠️ **소정수 1~6 은 대조로 확정 불가 — 판별력 0 을 수치로 확정(2026-08-04)**: `CRM_CODE` 336그룹 중 **1~6 을 전부 포함 118그룹** · **도메인이 정확히 1~6 인 것 14그룹**(`MS006` 유력하나 13개 후보와 구별 불가). `SNDNG_TY_CD`(30 §18-C)와 동일한 P29 한계 · 2번째 사례. | 🟡 **부분해소 2026-08-04 — COMMENT 가드 배포 완료**(정본 = `03_top-down_gold/O28_O29_COMMENT_GUARD.sql` · 10 §15-E). ✅ ① `FEP` 컬럼 **17종 + 테이블** COMMENT(두 체계 경고 + 미주입 14컬럼 *"0 을 실측값으로 읽지 말 것"*) — gold.fact 는 post_hook 미사용이라 **영구 지속** ✅ ② 🆕 **`WIDE_EVENT_PARTICIPATION` 16컬럼 동시 반영**(선행 지목이 WIDE 를 누락했다 — 분석가·SV 가 보는 계층) + **모델 `post_hook` 수정**(뷰 COMMENT 소유주라 물리만 고치면 빌드가 되돌린다) ✅ ③ 정본 `06_DDL.sql` FEP 블록 동기화 ✅ ④ 거짓 주석 회수 — 모델 헤더 *"Bronze 입고 후"·"상태별 집계는 입고 후"* 는 **원인 오진**(입고는 완료됐고 막는 것은 코드체계) ✅ ⑤ 🆕 `WIDE.EVENT_KIND` COMMENT *"온라인/오프라인"* **거짓 교정**(실측 EVENT/CRMN — 하필 O28 판별자 축) · 검증 = `INFORMATION_SCHEMA` 17/17·16/16.<br>🔴 **잔여 = 소정수 1~6 의미 현업 회신**(문서20 §I) → 회신 후에야 카운트 5종 배선 가능. 🟢 단 `PARTICIPATION_TIMES`·`CUM_APPLY_TIMES` 는 `PARTCPT_SEQ`(100%) 기반이라 **O28 무관하게 배선 가능**. 🟠 오염값 `)` = 원천 정정 vs 센티넬 라우팅 결정. | **10 §14-H**(진단 정본) · **10 §15-B·15-E**(정정·조치 정본) · 20 §I · 10 §13-A(G5 한계) |
| 🟡 **O29** | O27 §14-G #2 파생 | **[신규 2026-08-03] `DURATION_SEC` — 96.6% 무성 소실 + 단위 오류 라이브 적재** | `BRONZE_AGENCY.VIDEO_AD_CMPGN_DTLS.AD_SEC`(TEXT) 33,890/36,416 채움에 **두 표기 혼재** — HH:MM:SS **32,739(96.6%)** vs 숫자 **1,151(3.4%)**. SILVER `AGENCY_AD_BROADCAST.DURATION_SEC`(NUMBER)가 TEXT→NUMBER 캐스팅으로 **HH:MM:SS 32,739행을 무성 소실**시켰다(`TRY_TO_NUMBER` 는 에러 없이 NULL — 어떤 테스트도 안 걸린다, P27 전형).<br>🔴 **더 심각한 것 — 살아남은 값이 틀렸다**: `GOLD.FACT_AD_BROADCAST.DURATION_SEC` 에 **30,000,000~90,000,000 이 적재**돼 있다. 컬럼명은 "초"인데 분석가·Analyst 는 *"3천만 초"* 로 읽는다(µs 해석이면 30초). **이미 소비 가능한 라이브 무증상 오답**(AD-4·P19).<br>🟢 **복구 가능** — 두 표기가 같은 초수 집합을 가리킨다: HH:MM:SS {30,60,90,120}초 · 숫자 {30,60,90}(×10⁶). 파싱하면 **33,890행(93.1%) 전량 확보**. ⚠️단 µs 해석은 추론이므로 HH:MM:SS(무추론)만 즉시 적용, 숫자 3종은 현업 확인 후.<br>🔴 **O27 판정 오류 동반** — 초판이 `DIM_AD_CREATIVE.DURATION_SEC` 를 "채움 대상"(A군)으로 봤으나 §18-D ① 확인 시 `FACT_AD_BROADCAST` 에 **같은 축이 이미 있다** → 채움이 아니라 **중복 축 정리**가 정답.<br>🟢 **[2026-08-04 `TRY_TO_*` 전수 스캔 완료 — 조치 ⑤ 종결]** 모델 **14파일 14용례** 전건 실측: 무성 소실은 **`AD_SEC` 1건뿐**이다. `CPC`→`CPC_SRC` 482건은 전부 `#DIV/0!`(엑셀 오류 문자열)이라 **NULL 화가 정상 동작**(양성) · `ERP YEAR`·`CRM_EVENT.STRT_DE/END_DE`·`OCCRRNC_DE`·`SPNSR_DSCNTC_DE`·`MBRFEE_MT`·`STDR_MT` **전건 소실 0**. → *"동일 유형이 더 있을 것"* 우려를 **실측으로 반증**(O20 `_YN` 스캔과 같은 결말). 🟢 부수: 대행사 원천이 **엑셀 산출물**임이 드러남(오류문자열 재유입 관측 축).<br>⚠️ **행수 인용 정정**: `FACT_AD_BROADCAST` 실측 **38,486행** vs 문서 기재 **37,886**(2026-07-28 측정치) — 600행 차 **원인 미규명** → PROC-3 (c) 에 따라 어느 쪽도 인용 금지. | 🟡 **부분해소 2026-08-04 — COMMENT 가드 배포 완료**(정본 = `O28_O29_COMMENT_GUARD.sql` · 10 §15-C·15-E). ✅ ① `FACT_AD_BROADCAST.DURATION_SEC` **단위 경고 + 96.6% 소실 + 커버리지(분모=VIDEO 36,416 → 현 3.2%·파싱 시 93.1%)** 명시 ✅ ② `DIM_AD_CREATIVE.DURATION_SEC` **중복축·조회 금지** 명시 ✅ ③ 🆕 **`WIDE_AD_BROADCAST.DURATION_SEC` 동시 반영**(선행 지목 누락) + 모델 `post_hook` 수정 ✅ ④ 정본 `06_DDL.sql` 2건 동기화 ✅ ⑤ 거짓 주석 회수 — `DIM_AD_CREATIVE.sql` *"원천 부재(초수)"* 는 **거짓**(원천 실재) · `AGENCY_AD_BROADCAST.sql` 25행에 **결함 지점·복구 방법** 명시 ✅ ⑥ `WIDE_AD_BROADCAST` 뷰 COMMENT 의 **행수 하드코딩 제거**(드리프트 재발 방지) ✅ ⑦ **`TRY_TO_*` 전수 스캔 종결**.<br>✅ **[2026-08-04 후반 DEC-30] SILVER HH:MM:SS 파싱 배선 완료** — `LIKE %:%` 로 표기를 가른 뒤 `SPLIT_PART` 초 환산. 커버리지 3.2%→**93.1% 예상**(적재는 build 대기). ⚠️`TRY_TO_TIME` 은 `30000000` 을 `05:20:00`(19,200초)로 **실패 없이** 바꿔 동일 무성 오답을 재도입하므로 금지(**P48**). ✅ `DIM_AD_CREATIVE.DURATION_SEC` **DROP 완료** — 초수는 소재에 함수종속하지 않는다(소재 41종 중 19종 복수 초수·함수종속 53.7%) ⇒ 방송 속성이며 소재차원은 오배치였다.<br>⬜ **잔여**: ① ~~SILVER 파싱~~ ✅완료 ② 숫자 3종 µs 단위 **현업 확인**(확인 전 NULL 유지가 안전) ③ `DIM_AD_CREATIVE` 중복축 **DROP vs 통합 사용자 결정** ④ `SERVING.FACT_AD_COMBINED.DURATION_SEC` COMMENT **공백**(SV helper — 사용자 실행 범위) | **10 §14-I**(진단 정본) · **10 §15-C·15-E**(스캔·조치 정본) · 10 §14-G #2 · 10 §14-B A군 |
| 🟡 **O35** | O34 파생 | **[신규 2026-08-04] 연령대 × 캠페인 교차 불가 → FME 에 사건시점 연령대·지역 전파** | **원인**: 연령대는 `SV_MEMBER_MONTHLY`(FMM×`DIM_MEMBER_CURRENT`), 캠페인은 `SV_MEMBER_EVENT`(FME)에 갈라져 있고 `SEMANTIC_VIEW()` 는 단일 뷰 대상이라 Agent 가 행 단위 조인을 못 한다. `FMM.CAMPAIGN_SK` 는 센티넬 단일값이라 조인해도 캠페인 축이 없다.<br>✅ **대안 A(사건시점 속성 전파) 채택**(사용자 승인 2026-08-04) — B multi-fact SV 는 연령이 여전히 스냅샷이라 의미 결함이 남고 fan trap 위험, C Agent 조인은 불가. 재론 불요.<br>🟢 **정당화 근거 실측**: 복수 개발사건 회원 1,040,895 중 `AGE` 변동 **102,685** · `AREA_CD` 변동 **50,039** → 사건행별 값 ≠ 최근 약정 스냅샷.<br>✅ **실행 완료(2026-08-04)**: 물리 ADD COLUMN 4(`AGE_AT_EVENT`·`AGE_BAND_AT_EVENT`·`AREA_CD_AT_EVENT`·`REGION_AT_EVENT`)+COMMENT · **정본 `06_DDL.sql` 동기화(P57)** · 모델 FME · 소비뷰 `WIDE_MEMBER_EVENT`(P59) · `accepted_values` 4 · 필드 인벤토리. 검증 = 정본↔물리 **31==31 차집합 0** · 라벨 조인 fan-out 0.<br>⏸ **잔여**: 사용자 `dbt build` → 교차 재현 검증 → `SV_MEMBER_EVENT` 차원 확장.<br>🔴 `_AT_PLEDGE` 축은 제거하지 않고 이름으로 구분해 공존 | **10 §20** · 03설계 |

### 2-C. 현업 확인
| 대표 ID | 별칭 | 이슈 | 상태 | 문서 |
|---|---|---|---|---|
| C-9 | — | '오픈(명)' 정의 | ✅ 확정(URL_OTHBC 폐기)·⚠️2026-09 재검토 → 🔴 **[2026-07-30] ML 요건과 충돌 확인, 재제기됨** = **C-9-R**(문서40)·문서20 §F-3. 정본이 오픈율을 증액·충성·중단 예측의 **Feature**로 명시 → 2026-09 대기 부적절 | 90 · **40 · 20 §F-3** |
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
| O6 | Q8 | EVENT_TYPE 코드체계 | 🟢 **[2026-08-03] 코드체계 부분해소 → O24** — 개발측 상태축 MM015 확정·적재 완료. 잔여 = **'활동전환' 사건화 여부**(활동은 상태이며 MM010 소관) | 20 · **03설계 §5 O24** |
| SF-biz | — | 익명 미귀속 | 🛠️ 설계흡수 | 30 |
| #81 | — | 미납클릭·납입전환 판정 | 🔄 잠정·게이트 identity | 20 |
| SVL-1 | — | 발송소분류(`SNDNG_TY_CD`) 라벨 | 🔵 라벨 대기(SV_SERVICE) | 20 |
| SVL-2 | — | 발송상태(`SNDNG_RST_CD`) 라벨 | 🔵 라벨 대기(SV_SERVICE) | 20 |
| SVL-3 | — | 발송채널(`SEND_CHANNEL`) 라벨 | 🔵 라벨 대기(SV_SERVICE) | 20 |
| SVL-4 | O6/Q8 | 행사구분(`EVENT_DIV_CD`/`CRMN_DIV_CD`) 라벨 | 🔵 라벨 대기(SV_EVENT_PARTICIPATION) | 20 |

### 2-C-2. 🆕 ML 요건 정본 대조 신규 (2026-07-30)
> 정본 `99_provided_definition/데이터플랫폼 ML 예측관련_취합_20260730.xlsx`(4시트 = 예측프롬프트·기획실·회원실·나마본)를 **최초로 전수 대조**해 도출. 종전에는 이 원본을 대조한 적이 없어 드러나지 않았다.

#### 🔷 Phase 배정 (2026-07-30 확정)

**판정 기준 = "현재 BRONZE에 데이터가 있는가"** — Phase-1은 현 BRONZE 데이터로 만들 수 있는 범위, 그 밖은 전부 Phase-2.

| Phase | 항목 | 근거 |
|---|---|---|
| **P1** | **DEC-17** 미납사유 SILVER 전파 | 🟢 BRONZE `RQEST_RST_CD` **99.67%·101종** + `DIM_REASON` `PM019` 950종 라벨 완비 |
| **P1** | **DEC-15·DEC-16** §5 활동 스냅샷 로직 | 🟢 원천 `CRM_MEMBER_STATUS_HIST` 7,501,761행 SCD2 완비. 결정만 하면 구현 가능 |
| **P1** | **DEC-18(신설)** ML 요건1·3 컬럼 | 🟢 원천 `CRM_MEMBER_AMT_CHANGE` 324,947 · `CRM_SPONSOR_RELATION` 862,610 · `CRM_MEMBER_SPONSOR_BIZ` 2,170,572 + 브리지 1:1 확인 |
| **P1** | **O16** `DIM_ORG` 계층 **구조** 전개 | 🟢 원천 `UPPER_DEPT_ID` 1,314행/321종. 재귀 6단 검증 완료 |
| **P2** | **O16** 본부/지부 **구별축** | 🔴 D6이 동일 레벨로 묶음 + 명칭이 5개 레벨 분산 → 현업 F-1 |
| **P2** | **SPB-G** 후원사업 그룹 **라벨** | 🔴 코드(`1`~`6`)는 있으나 코드사전 미특정 → 현업 F-2. (코드 자체 노출은 P1 가능) |
| **P2** | **C-9-R** 오픈 | 🔴 BRONZE `URL_OTHBC_*` **전건 NULL** = 원천에 값 없음 |
| **P2** | **HOL-1** 공휴일 | 🔴 전 스키마에 원천 **부재** |
| **P2** | **O8** → `FMM.CAMPAIGN_SK`·`SPONSORSHIP_SK`·`PAYMENT_SK` | 🔴 회비 원천에 캠페인 컬럼 **없음** + 다중캠페인 7.98% grain 규칙 현업 대기 |
| **P2** | **G-5** GA4 · 나마본 21문항 | 🔴 1일 샤드만 입고 |
| **P2** | 등급 산출식(위험/충성/장기) | 🔴 정본 자체가 미확정 → 현업 F-4 |
| **P2** | ~~O10 → `FME.ORG_SK`~~(🟡 **2026-08-05 O38 로 부분해소·이 분류는 stale 이었다** — 결정·원천·매칭률 99.9998% 가 모두 준비돼 있었고 배선만 빠져 있었다. 잔여는 O38-B) · AD-3·AD-5 · E-1·E-4·E-6 · Q10 · C-8 · SVL-1~4 | 🔴 기존 외부/현업 의존 항목 (변동 없음) |

> **Phase-2 이월 원칙**: 원천 데이터가 없거나 현업 회신 없이는 **의미가 틀린 결과**가 나오는 항목은 Phase-1에서 손대지 않는다(§9-G 빈 틀 스캐폴드 금지 · P18 무증상 오답 방지).

> 함께 확인된 구조적 사실: **BLOCKING-5 진단표는 FACT 5종만 대상이었고 DIM 계열은 그 표의 범위가 아니었다.**
> ⚠️ **[정정]** 최초 기술한 "DIM 계열은 어느 문서에도 없었다"는 **과장이었다.** 3건 모두 **설계 문서에는 기재돼 있었다**(`DIM_ORG` 계층전개=**DEC-5**에 반영위치까지 명시 / `IS_HOLIDAY`=**D1** 컬럼 / `SPONSORSHIP_ABBR`=**D5** 컬럼) + dbt 모델 주석에도 자기문서화. 정확한 문제는 **"설계에는 있으나 값 미주입 상태가 dbt 추적표에 오르지 않고, 설계 문서에도 구현현황이 역기록되지 않았다"** 는 것이다. → 설계 소관은 `03_테이블 설계.md` §5 **O16~O19** 로 정본화.

| ID | 이슈 | 실측 근거 (2026-07-30) | 상태 | 문서 |
|---|---|---|---|---|
| **C-9-R** | **오픈 원천 재제기** — C-9에서 URL_OTHBC를 폐기 확정했으나 ML 정본이 오픈율을 증액·충성·중단 예측의 **Feature**로 명시 | `FSE.OPEN_MEMBERS` 전건 0(38,470,780행) · BRONZE `URL_OTHBC_CNT_CTNT`/`_RT_CTNT` 497,777행 **전건 NULL** · `TOT_CLICK_CNT`도 100% NULL(이슈 D) | 🔴 **현업 재질의** — 2026-09 재검토 대기 부적절 | 40 · 20 §F-3 |
| **HOL-1** | **공휴일 캘린더 원천 부재** — 기획실 개발예측 A안 3종이 "주말(휴일) 제외 개발가능일수" 요구 | `DIM_DATE.IS_HOLIDAY` 16,437행 **전건 FALSE**(모델이 `FALSE` 하드코딩·주석에 "휴일 원천 없음" 기재) · 전 스키마에 공휴일 원천 0 · 주말은 `DAY_OF_WEEK`로 가능 | 🔴 **외부 입고**(특일정보 API 또는 사내 캘린더) | 40 · 20 §F-5 · **03설계 O18** |
| **ORG-H** | **`DIM_ORG` 계층 3/4단 전건 NULL** — DEC-5(C-7) 반영 대기. ML 요건 "신규본부/신규지부" 차단 | `CORP`·`DIVISION`·`TEAM` 전건 NULL(`DEPARTMENT`만 1,315/695종) · 원천 `CRM_ORG.UPPER_DEPT_ID` **1,314/321종 → 내부 구현 가능** · 재귀 트리 **6단**(9/38/351/672/238/6 = 1,314 = 원천 정확 일치) · 🔴 미결 = ①6레벨→4컬럼 매핑(DEC-5는 `TEAM`=5th만 확정) ②**D6이 본부/지부를 동일 레벨로 묶어 구별축 없음** ③DEC-5 부기 "5th=실적부서" 실측 불일치(LVL5의 49.6%만 실적부서) | 🟠 **현업 회신 대기** | **03설계 O16**(정본) · 50 · 20 §F-1 |
| **SPB-G** | **`DIM_SPONSORSHIP.SPONSORSHIP_ABBR` 라벨 부재 · "약칭"인지 분류코드인지 불명** | `ABBR` 값 `1`~`6` 6종 실측(사업수 17/1/6/3/21/2 + NULL 1). ⚠️ **그룹 의미는 사업명 기반 추정이며 코드사전 미특정** → 단정 금지. 정본 4그룹·"총 11개"와의 대응 전부 미확정 | 🟡 **라벨 회신 대기** → 회신 후 라벨 컬럼 신설 + 주석 정정 | **03설계 O19** · 50 · 20 §F-2 |
| **DEC-15** | **`PREV_MONTH_END_ACTIVE_CNT` 전월 산출 방식** — DEC-4 `UNPAID_FLAG_BOM`의 LAG 근사 상속 여부 | `UNPAID_FLAG_BOM` 실측: 직전행 38,294,238 중 **gap>1개월 1,508,626(3.94%)** · **gap>12개월 980,037** · 최대 **370개월(30.8년)**. DEC-4는 "✅완료"만 기록. ⚠️대안 간 성능 비교는 미실측 | 🟠 **결정 대기** — §5 선결 | 30 §3-B · 50 |
| **DEC-16** | **`YEAR_START/END_ACTIVE_CNT` 적재 규약** — 연도 grain 상수를 월×회원 팩트에 보관 | 현재 전건 0(무증상). 채우면 12개월 반복→연 SUM **12배 과대계상** / 1월만→월 필터 **분모 0**. 공45·47·54·신12~19의 **분모** | 🟠 **결정 대기** — §5 선결 | 30 §3-B |
| **DEC-17** | **`SILVER.CRM_PAYMENT_BILLING`에 결제결과 코드 추가** — 미납사유 확보. ⚠️ **신규 설계 추가가 아니라 설계(D12 "미납사유") 대비 구현 누락 복구** | 원천 실측: `RQEST_RST_CD` **46,239,125/46,391,620 = 99.67% · 101종** · `PRCS_RST_CD` 99.31%·7종 vs 현 모델은 `PAY_STAT_CD`(**2종**)만 SELECT. 하류 `DIM_REASON`에 `PM019` **950종 라벨 완비**. ⚠️기부금 branch엔 두 컬럼 없음→`NULL` 고정. ⚠️DEC-3(미납 판정)과의 관계 미확정 | ✅ **W1 완료(2026-07-31) + W3 완료(2026-07-31)** | **03설계 O17** · 30 §3-B |
| **O8**(기존) | 회원 다중후원 캠페인 귀속 규칙 — **이번에 차단 범위 확정** | `FME` DEV 기준 캠페인 붙는 회원-월 2,970,417 중 **다중캠페인 237,131(7.98%)** · 단일 회원-월 최대 **60개**. 규칙 없이 조인하면 최소 237,131행 fan-out → 기준선 40,054,883 붕괴 | 🔴 **현업 미회신** — `FMM.CAMPAIGN_SK`/`SPONSORSHIP_SK`/`PAYMENT_SK`를 직접 차단 | 20 §G · 50 B2·B3 |

### 2-D. SILVER Q-이슈 (Q1~Q16)
| Q | 이슈 | 상태 | 문서 |
|---|---|---|---|
| Q1 | GA↔CRM 식별자(=G-1) | 🔵 확정·채움률 4.22% | 20 |
| Q2 | 캠페인 코드↔코드그룹 | ✅ **해소(2026-07-16 재입고)** — MM294/293/295/296 확정·라벨화 | 30 §10 |
| Q3 | #17 최종확인 | ✅ **해소(2026-07-16)** — #17=캠페인 카테고리(MM294 56종) 라벨 확정 | 30 §10 |
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
| Q16 | 캠페인↔마케팅캠페인 조인키 | ✅ **무효화 철회→해소(2026-07-16)** — 원천 재입고로 33,915행 연결·고아 0 | 30 §10 |

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

> **별계열 주의**: `P1~P76`=설계 원칙(이슈 아님, 문서10 — **P21~P23**은 §10-F · **P24~P26**은 §11-G · **P27~P28**은 §12-G · **P29~P33**은 **§13-G** · **P34~P40**은 **§14-E** · **P41~P44**은 **§15-F** · **P45~P46**은 **§15-J** · **P47~P48**은 **§16-F** · **P49~P51**은 **§17-D** · **P52~P55**는 **§18-I** · **P56**은 **§18-H** · **P57**은 **§19-F** · **P58**은 **§19-G** · **P59**은 **§19-H** · **P60**은 **§19-J** · **P61**은 **§20-F** · **P62·P62-B**는 **§20-G** · **P63~P66**은 **§21** · **P67~P75**는 **§22-G** · **P76**은 **§22-I** · **P77**은 **§22-J** · **P78·P79**는 **§23** · **P80·P81·P82**는 **§24** · **P83**은 **§25**) · ⚠️ **`P24` 번호 충돌 정리(2026-08-03)**: `P24`=문서10 §11-G(instruction 제자리 교체)로 **확정**하고, 문서30 DEC-17-A 가 쓰던 동명 교훈(전건 NULL 컬럼의 매핑은 미검증 매핑)은 **`P24-B`** 로 재부여했다(문서10 §13-H) · `S*`=프로파일링 태스크 · `AD-*`=광고 SV 이슈(§9~10) · `PRV-*`=소비계층 미결(§10, PRV-3=Agent 기간규칙 NL 스모크) · `G1~G5`=코드체계 관문측정(문서10 §13-A) · `_archive` 구 Q1~Q9는 현 스킴 흡수·은퇴(⚠️`_archive` Q1 ≠ 현행 G-1/Q1 identity, 동명이의).

---

## 원본 아카이브
본 원장은 아래 7개 원본을 병합. 원본은 각 폴더 `_archive/`로 이관됨:
`03_top-down_gold/_archive/`(30·33·34) · `04_silver_design/_archive/`(10_SILVER_이슈해결·11_SILVER_블로커) · `10_dbt_pipeline/_archive/`(_OPEN_ITEMS·_현업검토요청).

---
_Co-authored with CoCo_
