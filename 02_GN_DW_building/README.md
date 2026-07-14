# 02_GN_DW_building — GN_DW 설계 정본

> `02_GN_DW_building/` 폴더의 **진입점(색인)** 문서. 각 파일의 역할·읽는 순서·현재 상태를 한곳에 정리한다.
> 프로젝트: 굿네이버스 GN_DW. 범위: PoC(`GN_DW_POC`)를 운영 등급 DW(`GN_DW`)로 이관하는 **설계 작업계획서(정본)**.
> 아키텍처: **BRONZE → SILVER → GOLD → SERVING** 4계층 재설계.

## 폴더 간 위상
- **이 폴더 = 설계 정본** (SERVING 스키마 도입 재설계안)
- `01_project_sample/` — GOLD 통합 **레거시**(참고용)
- `03_top-down_gold/` — **GOLD 정본**(15 DIM + 9 FACT star schema). 본 폴더 GOLD 기술은 요약, 상세는 이 폴더 참조
- `00_PoC_bak/` — 이관 원천이 된 PoC 백업

---

## 파일 명세

| 파일 | 역할 |
|------|------|
| `00_INDEX.md` | 작업계획 인덱스(개요·산출물·실행순서 14단계·원칙·위험·챕터맵). **모든 상세 메타의 출처**. |
| `01_환경_Role.md` | Timezone, Warehouse 3종, Role 계층 6종, 유저 프로비저닝. |
| `02_DB_BRONZE_SILVER.md` | DB/스키마 6종, BRONZE 54테이블(원천 1:1), SILVER 23테이블(정제), 통합·정제 프로시저. |
| `03_GOLD_SERVING.md` | GOLD star schema 18(정본 → `03_top-down_gold/`) + 레거시 View 35 병존, Semantic View 7, Agent 1, 권한, Streamlit 6. |
| `04_운영.md` | 태스크 DAG, 테스트, 보안(네트워크/마스킹/MFA), 모니터링. |
| `05_ARCHITECTURE.md` | 전체 아키텍처 다이어그램 + SERVING 조감도. |
| `06_RUNBOOK.md` | 운영 매뉴얼 — 일상점검/장애대응/수동실행/보안사고. |

---

## 읽는 순서 (신규 진입자)
1. 본 문서 → 2. `00_INDEX.md`(개요·실행순서·원칙·위험) → 3. `05_ARCHITECTURE.md`(아키텍처 조감) → 4. 챕터 `01`~`04` 순 → 5. `06_RUNBOOK.md`(운영)

> 상세 메타데이터·실행순서·설계원칙은 모두 `00_INDEX.md`에 있다. 본 README는 진입용 안내이며 INDEX를 대체하지 않는다.

## 현재 상태
- BRONZE→SILVER→GOLD→**SERVING** 4계층 재설계 **설계 문서화 단계**(챕터 1~6 작성). 라이브 실행 전.
- GOLD 상세 설계(star schema)는 `03_top-down_gold/`가 **정본**이며, 본 폴더 `03_GOLD_SERVING.md`는 요약 + 레거시 View 병존 전략을 다룸.
- `01_project_sample`(GOLD 통합) 대비 **SERVING 분리**가 핵심 변경점.
