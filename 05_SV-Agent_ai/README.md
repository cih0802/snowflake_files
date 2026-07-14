# 05_SV-Agent_ai — Semantic View · Cortex Agent 설계

> `05_SV-Agent_ai/` 폴더의 **진입점(색인)** 문서. 각 파일의 역할·읽는 순서·현재 상태를 한곳에 정리한다.
> 프로젝트: 굿네이버스 GN_DW. 범위: GOLD 설계 위에 올리는 **Semantic View(SV) + Cortex Agent 설계 작업계획서**.
> **범위 경계**: 설계 문서 + SV YAML 초안 + VQR/평가셋 + Agent spec **산출까지**. 실제 `CREATE SEMANTIC VIEW`/`CREATE AGENT` **배포는 별도 트랙**(데이터 검증 후).
> 입력: `03_top-down_gold/` GOLD 산출물 — `GOLD_파생지표 매핑.md`(derived 81 metric SSOT)·`GOLD_팩트 설계.md`(FACT 6·measure 61)·`GOLD_차원 설계.md`(DIM 12)·`GOLD_메타제약 확인.md`(시간가용성·미해결)·`GOLD_ddl 초안.sql`(실제 컬럼명).

## 폴더 간 위상
- **이 폴더 = SERVING 계층(SV·Agent) 설계** — GOLD 의미계층
- `03_top-down_gold/` — GOLD 정본(입력, 읽기 전용)
- 객체 배치 스키마(확정): **`GN_DW.SERVING`**(신규 소비 계층). GOLD는 데이터 프로덕트 계층으로 분리 유지(PoC `ANALYTICS`와 혼동 방지로 `SERVING` 명명).

---

## 파일 명세

| 파일 | 역할 |
|------|------|
| `00_SV-Agent 작업계획.md` | SV/Agent 설계 정본. 설계원칙 9개(0절)·의사결정 기록(0.1)·리스크(1절)·**구조 4 SV/3 Agent**(2절)·작업단계 1~7(3절)·진행상태표·changelog(v3.1)·입력문서(부록 B)·Best practice 출처(부록 C). |
| `1_SV_metric 배속.md` | 1단계 산출물. derived **81개**(공통30+신규51)를 4 SV에 전수 배속(MEMBER 48·SERVICE 24·AD 4·GA 2·보류 3). 각 행에 SV·base FACT·활성여부·가산성·시간가용성 태그. |

---

## 구조 요약 (4 SV / 3 Agent)
- **SV는 FACT grain 경계로 4개 분리**(text-to-SQL 정확도 레버), **Agent는 3개**(마케팅 Agent만 다중 SV 라우팅).

| Agent | 라우팅 SV | base FACT | 도메인 |
|-------|-----------|-----------|--------|
| 1. 회원실적 | `SV_MEMBER` | FMM | 목표대비·활동율·중단율·미납율·캠페인·유지율·LTV |
| 2. 서비스 | `SV_SERVICE` | FSE | 발송율·수신율·참여율·증액율·서비스별 유지/중단 |
| 3. 마케팅 | `SV_AD` + `SV_GA` ✅ | FAD / FGA | 광고 CTR·개발단가(AD) / 세션·이탈율·스크롤(GA) |

- **정확도 메커니즘**: synonyms(한글)·VQR(`AI_VERIFIED_QUERIES`)·custom instruction(시간가용성·NULL)·평가셋 → 피드백→optimization 폐루프.
- **placeholder 8건**: 데이터 미입고 derived(공7·10·98·108·신8·9·10·11)는 정의만 두고 비활성. 추정 금지.
 - **2026-06-24 정의서 반영**: GADS → `SV_AD`(광고비·노출·클릭·전환수 명/건·집행예산 2종). ~~ADMIN → `SV_SERVICE`(앱푸시 발송/성공·이벤트 조회수)~~ → **ADMIN ❌제외 확정(2026-07-09)**: 어드민 원천 미채택으로 앱푸시·이벤트조회수 measure는 GOLD 컬럼 삭제(FSE `APP_PUSH_*`·FEP `VIEW_CNT`). 내년 어드민 구현 시 재추가. GADS 원천은 AGENCY 통합 예정(목적지 미정)이라 SILVER 소스 경로·접두사는 추후 확정. 물리 적재는 원천 입고(S-6) 후.

## 작업 단계
`1 metric배속 → 2 SV구조(relationship/synonyms) → 3 metric expr+YAML초안 → 4 VQR+평가셋 → 5 Agent설계 → 6 거버넌스/루프 → 7 색인`
(deploy·optimization 실행은 범위 밖 — 데이터 검증 후 별도 트랙)

## 읽는 순서 (신규 진입자)
1. 본 문서 → 2. `00_SV-Agent 작업계획.md`(원칙·구조·실행가이드) → 3. `1_SV_metric 배속.md`(81 배속) → 4. (대기) 2~7단계 산출물

## 현재 상태
- 0단계 작업계획 ✅ 완료, **1단계 metric 배속 ✅ 완료**(81 전수 배속). 2~7단계 ⬜ 대기.
- **데이터 입고 후 보류**: 신9·10·11(개발단가·ROI, AGENCY/ERP 입고)·공98·108·10(GA4 raw)·신8 LTV(24년 이전) — grain 확정 후 SV 배속·활성.
- 다음 트랙: 2단계 SV 구조 정의(`2_SV_*_설계.md`×4) → 3단계 metric expression + `SV_*.yaml` 초안.
