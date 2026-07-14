# 01_project_sample — GN_DW 1차 구축안 (GOLD 통합)

> `01_project_sample/` 폴더의 **진입점(색인)** 문서. 각 파일의 역할·읽는 순서·현재 상태를 한곳에 정리한다.
> 프로젝트: 굿네이버스 GN_DW. 범위: PoC(`GN_DW_POC`)를 운영 DW(`GN_DW`)로 재설계·구축하는 1차 작업안.
> 아키텍처: **BRONZE → SILVER → GOLD** 메달리온. 환경/권한부터 테이블·뷰·SV·Agent·Streamlit + 프로시저·태스크·테스트·보안·모니터링까지 전체 단계.

---

## 파일 명세

### A. 작업계획서 (기준 문서)
| 파일 | 역할 |
|------|------|
| `00_GN_DW_PROJECT.md` | GN_DW 구축 작업문서(사람용). 8단계(환경/Role/오브젝트·권한/프로시저/태스크/테스트/보안/모니터링) 목차·설명·SQL 링크. |
| `00_GN_DW_PROJECT_LLM.md` | 위 문서의 LLM 파싱용 재구성판. 상단 YAML 메타(타깃 DB·스키마·레이어 흐름·SQL 인덱스) + YAML 객체 정의. |

### B. 실행 SQL 스크립트 (단계 순)
| 단계 | 파일 | 역할 |
|---|------|------|
| 1 | `01_환경세팅.sql` | Timezone(`Asia/Seoul`), Warehouse 3종(ETL/분석/개발). |
| 2 | `02_유저_Role_세팅.sql` | Role 6종(ADMIN/ENGINEER/ANALYST/VIEWER/LOADER/SERVICE) + 계층·WH 권한 + 유저 템플릿. |
| 3.1~3.2 | `03_01_DB_스키마_생성.sql` | `GN_DW` DB 생성·OWNERSHIP 이관, BRONZE/SILVER/GOLD 스키마. |
| 3.3 | `03_02_BRONZE_테이블_생성.sql` | PoC `RAW` → `GN_DW.BRONZE` 매핑 적재 테이블. |
| 3.5 | `03_03_GOLD_View_생성.sql` | GOLD 분석 View(SILVER/GOLD만 참조, BRONZE 직접참조 제거). 정형화 View 9 + 예측 테이블 DDL. |
| 3.6 | `03_04_Semantic_View_생성.sql` | Semantic View 7종(GOLD View만 참조 재설계, VQR 경로 GOLD 치환). |
| 3.7 | `03_05_Agent_생성.sql` | Cortex Agent(`GN_DW.GOLD.GN_DW_AGENT`). 7 SV → 분석가 툴(payment/lifecycle/member_dev/messaging/ad_platform/web_app/journey). |
| 3.8 | `03_06_권한_부여.sql` | 스키마·오브젝트 GRANT + Future Grants. |
| 3.9 | `03_07_Streamlit_배포.sql` | PoC Streamlit 6 중 운영 5종을 GOLD로 이관. GOLD View만 참조. |
| 4 | `04_프로시저_생성.sql` | BRONZE→SILVER 정제, SILVER→GOLD 집계, 유틸 프로시저. |
| 5 | `05_태스크_생성.sql` | 파이프라인 스케줄링 태스크 + 의존성(DAG). |
| 6 | `06_테스트.sql` | 권한·E2E·정합성 검증. Role↔WH 매핑 가이드. |
| 7 | `07_보안_세팅.sql` | 네트워크 룰/IP, 마스킹, MFA. |
| 8 | `08_모니터링_세팅.sql` | Resource Monitor, Alert, 비용 추적. |

---

## 아키텍처 요약
- **레이어**: `BRONZE`(원천 적재) → `SILVER`(정제) → `GOLD`(분석 View·SV·Agent·예측·Streamlit)
- **Role 계층**: `GN_DW_ADMIN` ← ENGINEER/ANALYST/LOADER/SERVICE, `GN_DW_ANALYST` ← `GN_DW_VIEWER`
- **Warehouse**: ETL(SMALL)·분석(MEDIUM)·개발(XSMALL) 용도 분리
- **분석 진입점**: GOLD 7개 Semantic View → `GN_DW_AGENT` + Streamlit

## 읽는 순서 (신규 진입자)
1. 본 문서 → 2. `00_GN_DW_PROJECT.md`(사람용) 또는 `00_GN_DW_PROJECT_LLM.md`(LLM용) → 3. 실행 SQL 1~8단계 순

## 실행 순서
`01` → `02` → `03_01` → `03_02` → `03_03` → `03_04` → `03_05` → `03_06` → `03_07` → `04` → `05` → `06` → `07` → `08`

## 현재 상태
- GN_DW **1차 구축안(GOLD 통합) 문서화 완료**. PoC 백업(`00_PoC_bak/`)을 BRONZE로 매핑하는 연결고리(`03_02`) 포함.
- 이후 `02_GN_DW_building`에서 **SERVING 레이어 도입 등 재설계**가 진행되어, 본 폴더는 **참고용(레거시)** 성격.
- GOLD 상세 star schema 정본은 `03_top-down_gold/`.
