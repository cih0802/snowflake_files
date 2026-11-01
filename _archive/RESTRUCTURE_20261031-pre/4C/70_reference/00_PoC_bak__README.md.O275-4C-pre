# 00_PoC_bak — PoC 산출물 백업

> `00_PoC_bak/` 폴더의 **진입점(색인)** 문서. 각 파일의 역할·읽는 순서·현재 상태를 한곳에 정리한다.
> 프로젝트: 굿네이버스 GN_DW. 범위: PoC 당시 구축한 데이터 파이프라인·분석 객체·Cortex Agent의 DDL/해설 백업.
> 데이터 흐름: **Excel(원천) → RAW(적재) → ANALYTICS(분석 뷰/예측) → Semantic View → Cortex Agent**

---

## 파일 명세

### A. ETL 파이프라인 (노트북·해설)
| 파일 | 역할 |
|------|------|
| `Excel_to_Table.ipynb` | Excel 원천을 스테이지에서 받아 파싱·타입변환 후 `RAW` 테이블 적재 + `ANALYTICS` 뷰 생성. 초기 적재 + 3차례 재적재 이력 누적. DB/스키마/스테이지/테이블을 자체 생성. |
| `Excel_to_Table 개선.ipynb` | 위 노트북을 해설문서 기반으로 개선한 버전. |
| `Excel_to_Table 해설.md` | 노트북 셀별 역할, 재적재 이력(2026-04-08/15/21), 구조·품질·성능·거버넌스 비판적 리뷰 및 개선 방향(dbt·COPY INTO·Task/Stream·데이터 계약). |

### B. DDL 백업 스냅샷 (노트북 실행 결과 구조)
| 파일 | 역할 |
|------|------|
| `RAW_DDL.sql` | `RAW` 스키마 25개 테이블(DIM 5 + FACT 20, 한글 컬럼) DDL 스냅샷. 실제 생성 주체는 노트북, 본 문서는 참조용(실행 필수 아님). 쿼리별 한 줄 주석 포함. |
| `ANALYTICS_DDL.sql` | `ANALYTICS` 스키마 DDL 스냅샷(예측/학습 테이블 5, `V_*` 뷰 26, Streamlit 6). 참조용. 쿼리별 한 줄 주석 포함. |

### C. 분석 레이어 (Semantic View·Agent)
| 파일 | 역할 |
|------|------|
| `semantic_ddl.sql` | Cortex Analyst용 Semantic View(`SV_*`) 7종. `ANALYTICS.V_*` 뷰 및 `RAW` 팩트 참조. 뷰별 한 줄 주석 포함. |
| `create agent_GN_DW_AGENT.sql` | 정식 Cortex Agent(`GN_DW_AGENT`) 생성/정리 스크립트. RAW 테이블 inline 생성 → Semantic View → Agent 순. 위 DDL 문서와 객체·컬럼 일치하는 정합 버전. |

---

## 객체 상세

**RAW (25)** — DIM 5: `DIM_CAMPAIGN_CODE`(+백업), `DIM_MEMBER_ATTRIBUTE`, `DIM_ORG_CODE`, `DIM_TEMP_TO_REGULAR_MATCH` / FACT 20: 광고 실적(GA·구글·메타), 디지털 광고 상세·월별 개발, 중단 회원, DRTV 방송효과·월별 개발, GA 방문(피드백/앱/모바일/PC/전체), 마케팅 발송, 회원 개발, 회비 납입, 재송출 방송 전환·월별 개발, SMS/알림톡, 일시 후원.

**ANALYTICS** — 예측/학습 테이블 `FORECAST_*`·`TRAIN_*`, 분석 뷰 26개(`V_*`), Streamlit 6개.

**Semantic View 7종**

| Semantic View | 분석 영역 |
|---------------|-----------|
| `SV_PAYMENT_ANALYSIS` | 납입이력(납입/미납/평균회비 × 회원특성) |
| `SV_MEMBER_LIFECYCLE` | 중단회원 상세·미납이력·일시→정기 전환 |
| `SV_MEMBER_DEVELOPMENT` | 회원개발 실적·중단·기간별 유지율 |
| `SV_MARKETING_MESSAGING` | 알림톡/문자 발송·전환·증액 크로스분석 |
| `SV_AD_PLATFORM` | 디지털 광고(구글/메타/GA) 노출·클릭·비용·전환 |
| `SV_WEB_APP_ANALYTICS` | 디바이스별(PC/모바일/APP) 방문·세션·피드백 유입 |
| `SV_MEMBER_JOURNEY` | 회원 360도 여정(가입~매체~발송~증액~중단) |

**Cortex Agent** — `GN_DW_POC.ANALYTICS.GN_DW_AGENT`. 7개 SV를 분석가 툴(`cortex_analyst_text_to_sql`)로 연결, 도메인별 라우팅. 방송 매체효율용 `SV_MEDIA_EFFICIENCY`(DRTV/재송출 광고비·인입콜·시청률·CPC·ROI·목표대비실적·예산집행) + `media_efficiency_analyst` 툴 보강.

---

## 읽는 순서 (신규 진입자)
1. 본 문서 → 2. `Excel_to_Table 해설.md`(파이프라인 이해) → 3. `Excel_to_Table.ipynb` → 4. `RAW_DDL.sql`·`ANALYTICS_DDL.sql`(결과 구조 확인) → 5. `semantic_ddl.sql` → 6. `create agent_GN_DW_AGENT.sql`

## 실행 순서
1. `Excel_to_Table.ipynb` → DB/스키마/스테이지/`RAW` 테이블 생성 + 적재 (+ `ANALYTICS` 뷰). 별도 DDL 실행 불필요.
2. `RAW_DDL.sql` / `ANALYTICS_DDL.sql` = 결과 구조의 **백업 스냅샷**(재현·참조용).
3. `semantic_ddl.sql` → Semantic View 7종 생성.
4. `create agent_GN_DW_AGENT.sql` → 추가 SV(`SV_MEDIA_EFFICIENCY`) 및 Cortex Agent 생성.

## 현재 상태
- PoC **완료** 상태의 백업. 초기 적재 + 3차 재적재 반영 완료.
- Agent에 방송 매체효율 SV(`SV_MEDIA_EFFICIENCY`)/툴 **보강 완료**. 초기 목업 에이전트 스크립트(`create agent_GN_DW_POC_AGENT.sql`)는 정식 버전과 구조 불일치로 **제거됨**.
- 정식 운영 이관은 `01_project_sample` → `02_GN_DW_building`(SERVING 도입 재설계) 트랙에서 진행. 본 폴더는 **원천/참조용**.
