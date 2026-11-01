<!-- LLM-METADATA
doc_id: OUTPUT_SHARE_ARCHIVE_202607
doc_role: 30_output_share 구 판본 아카이브 안내 — 이관 사유·정본 위치·인용 금지 수치
project: GN_DW (굿네이버스)
archived: 2026-08-06
END-METADATA -->

# `30_output_share/_archive/202607/` — 구 판본 아카이브

> **2026-08-06 이관.** 이 폴더의 문서는 **더 이상 정본이 아닙니다.**
> 정본은 모두 상위 폴더 `30_output_share/` 에 같은 파일명으로 있습니다.

## 왜 이관했나

이관 대상 문서는 2026-07-15 ~ 2026-08-03 사이에 측정·작성된 것으로,
그 이후의 **O24 · O26 · O33 · O34 · O35 · O37 · O38 · O39 · O40 · O41 · O42** 교정이
하나도 반영되지 않았습니다. 구체적으로:

| 구 판본이 적고 있던 것 | 실제 (2026-08-06 실측) |
|---|---|
| GOLD "32객체" · FACT 9 · WIDE 9 · DIM 15 | GOLD **43객체**(테이블 29 = DIM 16 + FACT 13, 뷰 14) · WIDE **13** |
| Semantic View 미언급 | **SV 8종** + Cortex Agent 2종 배포 |
| `MEMBER_STATUS`·`MEMBER_TYPE`·`ENROLL_PATH`·`GENDER` | O26 개명 → `MBER_STAT_CD`·`MBER_DIV_CD`·`JOIN_PATH_CD`·`SEX` |
| `DEV_MEMBERS` = "개발(명)" | 🔴 **거짓** — `*_MEMBERS` 는 사건 플래그(0/1)이며 `SUM` 은 44.5% 과대(O39) |
| `MEMBER_REGION`·`MEMBER_AGE_BAND` = 현재 속성 | **약정 시점 스냅샷**이며 현재 값은 산출 불가(O34) |
| `WIDE_TARGET_DEV` → 목표 대비 달성률 "✅ 사용가능" | 🔴 **거짓** — 목표만 있고 실적이 없었다. 정본은 신설 `WIDE_DEV_ACHIEVEMENT` |
| `FACT_TARGET_BIZ` 원천 = "ERP" | **CRM** 확정(2026-07-20 정정) · SILVER 테이블도 `CRM_BIZ_TARGET` 로 리네임 |
| GA4 "1일 샤드" | **2일 샤드**(`events_20260501`·`events_20260719`) |
| `ERP_BIZ_TARGET` 객체 | 실재하지 않음 |
| 신설 객체 미수록 | `FACT_MEMBER_COHORT` · `FACT_AD_DIGITAL/BROADCAST/BROADCAST_CASE` · `DIM_SEND_TYPE` · `WIDE_AD_*` 3종 · `WIDE_DEV_ACHIEVEMENT` |

## 🔴 인용 금지 수치

구 판본의 아래 수치는 **재현되지 않거나 정의가 잘못된 것**이므로 인용하지 마십시오.

| 문서 | 인용 금지 | 사유 |
|---|---|---|
| `05_지표GOLD매핑.md` | 상태 **`OK 168 · PARTIAL 43 · WAIT 4`** | 상태를 원천 계통으로만 **추정**해서, 물리 컬럼이 전건 `0` 인 지표까지 `OK` 로 분류했다. 실측 재판정 = **OK 117 · PARTIAL 63 · WAIT 35** |
| `01_DW_현업활용가이드.md` | `개발(건)` = "SUM(개발금액)/10,000" · `개발(명)` = "COUNT" 서술 · `이탈(건) CHURN_CNT` · `활동회원 ACTIVE_MEMBERS` "사용가능" | `CHURN_CNT`·`ACTIVE_MEMBERS`·`UNPAID_CNT`·`DECREASE_CNT`·`INCREASE_*` 는 **전건 0**이다(미주입). 「사용가능」 표기가 거짓이었다 |
| `01_DW_현업활용가이드.md` | GOLD 규모 "FACT 3,700만~3,800만 행" · `WIDE_TARGET_BIZ` 포함 "WIDE 9개" | 재계수 필요 — 현행 수치는 신판 부록 A |
| `02_원천결손_Gap분석.md` | 결손 유형 건수(A 3 · B 2 · C 3 · D 2 · E 2 · F 3) | 컬럼 단위 실측이 아니라 **이슈 건수** 집계였다. 실측 재분류 = **A 18 · B 51 · C 11 · D 14 · E 4 · F 8 = 106 컬럼** |
| `02_원천결손_Gap분석.md` | E-6 원천 "ERP 사업목표" | 원천은 **CRM** 이다 |
| `07_코드체계_관문측정.md` | G3 "32/85(37.6%) → 조치 후 **85/85**" | `85/85` 는 재현되지 않는다. 실측 = **79/85(92.9%)** = 동명 74 + 개명 5, 미보존 6(`TM_RM_*` 계열은 SILVER 모델 자체가 없다) |
| `03_GN_DW_개념도.html` | "112 객체" | 실측 **143 객체** |
| 전 문서 | GOLD 미주입 "125/454(27.5%)" · "106/371(28.6%)" | 분모 구성이 다르다. 실측 = **106/386(27.5%)** — 감사컬럼 `DW_*` 제외 기준 |

## 신판이 달라진 점 — 하드코딩 제거

구 판본의 근본 문제는 **사실을 문서·생성기에 손으로 적어 둔 것**이었습니다.
그래서 스키마가 바뀌어도 문서가 따라오지 않았습니다.

신판은 **인벤토리·계보·상태를 전부 측정해서 만듭니다.**

| 문서 | 구 판본 | 신판 |
|---|---|---|
| `04_컬럼계보매핑` | 계보 84행을 파이썬 리터럴로 하드코딩 | dbt WIDE/GOLD/SILVER 모델 **파싱** + 카탈로그 + census → **WIDE 13종 / 컬럼 463개** |
| `05_지표GOLD매핑` | 상태를 원천 계통으로 추정 · 계보를 04 생성기에서 `import` | 상태를 **census 직접 조회**로 판정(`실측:`/`추정:` 근거 병기) · 계보는 04 **산출물 CSV** 를 입력으로 받음 |
| `07_코드체계_관문측정` | 생성기 없음(수기) | 생성기 신설 — 정본 CSV 파싱 + BRONZE distinct 실값 + `CRM_CODE` 사전 대조 |
| `08_SILVER→GOLD_보존율` | 생성기 없음(수기) | 생성기 신설 — 사람 판정군은 키 단위 **승계**하고 기계 STATUS 가 뒤집힌 행만 표시 |
| `03_GN_DW_개념도.html` | 객체 목록·설명·행수 수기 | 카탈로그 + census + dbt 계보 → **143 객체 브라우저**. 설명은 배포 객체 COMMENT 원문 |
| `01`·`02` | 수기 | 수기이나 모든 수치가 실측이며 근거 쿼리를 문서에 명시 |

## 재생성 절차

```
1) python3 scripts/dump_schema.py            # → /tmp/schema.json  (카탈로그 스냅샷)
2) python3 scripts/census_columns.py         # → /tmp/census.json   (전 컬럼 COUNT/COUNT_IF · 수 분 소요)
3) python3 scripts/gen_column_mapping.py                 # 04
4) python3 scripts/gen_metric_gold_mapping.py            # 05 (3 의 CSV 를 입력으로 씀 → 순서 고정)
5) python3 scripts/run_bronze_audit_host.py              # 06
6) python3 scripts/gen_code_system_gates.py              # 07
7) python3 scripts/gen_silver_gold_retention.py          # 08 (이전 판본 CSV 에서 판정군 승계)
8) python3 scripts/gen_concept_diagram.py                # 03
```

- 환경변수: `GN_DW_OUT`(출력 폴더) · `GN_DW_MEASURED`(측정일) · `GN_DW_CENSUS` · `GN_DW_LINEAGE`
- `01`·`02` 는 수기 문서이므로 위 산출물을 읽고 갱신한다.
- ⚠️ `/tmp` 는 세션 중에도 초기화될 수 있으므로 ①② 는 언제든 다시 돌릴 수 있게 두었다.
- ⚠️ `/workspace` 마운트가 세션 중 죽을 수 있다 → 그때는 `cortex ws cp <파일> 'USER$.PUBLIC."snowflake_files":/<폴더>/'` 로 스테이지 경유.

---
_Co-authored with CoCo_
