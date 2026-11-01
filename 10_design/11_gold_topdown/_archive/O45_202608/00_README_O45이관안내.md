# O45 임시 스크립트 이관 안내 (2026-08-06)

이 폴더의 `O45_ASSEMBLY_AXES.sql` · `O45_VERIFY.sql` 는 **역할을 마쳐 이관**되었다.

## 왜 이관했는가
두 파일은 **라이브 환경에 O45 조립축을 한 번 적용하기 위한 일회성 스크립트**였다.
적용·검증이 끝났고 구조는 정본(`03_top-down_gold/06_DDL.sql`)으로 옮겨졌으므로 실행 대상이 아니다.

## 🔴 이관 전에 반드시 했어야 했던 일 (하마터면 놓칠 뻔한 결함)
이관 직전 실측한 결과, `06_DDL.sql` 에는 O45 구조가 **주석으로만 등재**되어 있었고
실제 DDL 문장은 **0건**이었다. 종전 §O45 절은 *"실제 DDL 본문은 O45_ASSEMBLY_AXES.sql 이 정본"*
이라고 명시하고 있었다 — 즉 **이관하면 정본이 사라지는 구조**였다.

| 구조 | 이관 전 06_DDL | 조치 |
|---|---|---|
| `GOLD.DIM_MARKETING_CAMPAIGN` | CREATE 문 **0건** | ✅ DIM 17 로 본문 추가 |
| `GOLD.FACT_MEMBER_FEE` | CREATE 문 **0건** | ✅ FACT 14 로 본문 추가 |
| `FACT_MEMBER_COHORT.ACQ_ORG_SK`·`ACQ_SPONSORSHIP_SK` | 선언 **0건** | ✅ 감사컬럼 뒤에 추가 |
| `FACT_AD_PERFORMANCE.MKTG_CAMPAIGN_SK` | 선언 **0건** | ✅ 감사컬럼 뒤에 추가 |
| FK 8종 | 실제 문장 **0건**(주석 1건뿐) | ✅ [관계 제약] 절에 추가 |
| `DIM_CAMPAIGN.MKTG_CAMPAIGN_SK` | 선언 있음 **단 위치 오류** | ✅ 물리 ordinal 20 에 맞춰 감사컬럼 뒤로 이동 |

즉 **이관만 먼저 했다면 신규 환경 재구축 시 O45 가 전부 사라졌을 것**이고, dbt 가
타입·FK·COMMENT 없이 테이블을 만들어 **O30 재구축 드리프트가 재발**했을 것이다.

## 이관 후 재현 절차 (신규 환경)
1. `04_silver_design/08_SILVER_테이블DDL_20260714.sql` 실행 (SILVER 39테이블)
2. `03_top-down_gold/06_DDL.sql` 실행 (GOLD 31테이블 + FK 50)
3. `dbt build`

기계 대조 결과 이 3단계로 현재 구조가 재현된다:
선언 31테이블 = 라이브 31테이블 · **컬럼명·순서 불일치 0** · 선언 FK 50 = 라이브 50.

## 검증 관문은 어디로 갔는가
`O45_VERIFY.sql` 의 GATE-A~G 결과값(총계·팬아웃·개발단가 등)은
`20_issue/00_INDEX_이슈원장.md` §O45 사후검증 표에 **수치째로 보존**되어 있다.
회귀 검증이 다시 필요하면 이 폴더의 원본을 그대로 재실행하면 된다.
⬜ 잔여 권고: 이 관문들을 dbt `schema.yml` 테스트로 승격하면 매 build 마다 자동 검사된다(미착수).

## 관련 미결
- 🟠 **O45-B** `SETLE_CD` 미라벨 5종(225,855행) 코드군 현업 확인
- 🟠 **O45-C** FMF·FMM 의 불량 5행 취급 상이 → `PAID_FEE` 34,672,700원 차
- 🔴 `scripts/gen_metric_gold_mapping.py` 소스 유실 → `05_지표GOLD매핑` 재생성 불가

---
_Co-authored with CoCo_
