# 04_silver_design — SILVER 정제 설계

> ⚠️ **본 README는 SILVER 스키마 작업 완료 후 일괄 업데이트 예정** — 현재 S-1 진행 중이라 일부 색인·상태가 최신이 아닐 수 있음.

> `04_silver_design/` 폴더의 **진입점(색인)** 문서. 각 파일의 역할·읽는 순서·현재 상태를 한곳에 정리한다.
> 프로젝트: 굿네이버스 GN_DW. 범위: GOLD star schema 요구와 BRONZE 적재 현황(진행 중)을 잇는 **SILVER 정제 레이어 설계**.
> **설계 기준(2축, top-down)**:
> 1. **GOLD가 요구하는 SILVER** — `03_top-down_gold/GOLD_SILVER 의존.md` (GOLD star schema 18테이블 → SILVER 소스·엔티티 **역산**)
> 2. **BRONZE에서 구성 가능한 SILVER** — `BRONZE_CRM 테이블 정보.MD` (CRM 40테이블/882컬럼, 전수 수령) + 향후 입고 소스
> 위치: `GN_DW.SILVER` 단일 스키마. 테이블명 소스 접두사(`CRM_*`·`GA4_*`·`ERP_*`·`AGENCY_*`)로 구분.
> 2026-06-24 갱신: 회의 정의서 반영 → 데이터 도메인에 **GADS·ADMIN** 추가. GADS→FAD(광고비·노출·클릭), ADMIN→FSE(앱푸시 발송/성공·이벤트 조회수)는 **GOLD 귀속 확정**. 단 **GADS·ADMIN은 AGENCY 또는 CRM으로 통합 예정(목적지 미정)** → 독립 `GADS_*`/`ADMIN_*` 접두사 **미확정**(통합 prefix에 흡수될 수 있음). 또한 **CRM은 현재 40테이블 기준이며 추후 확장 가능**. 변경분 정본은 `03_top-down_gold/GOLD_정의서_업데이트 20260624.md`. 관련 SILVER 테이블 수량·grain·접두사는 통합 결정 및 적재(S-6) 후 확정.

## 폴더 간 위상
- **이 폴더 = SILVER 설계** (GOLD 역산 + BRONZE 구성가능성 2축)
- `03_top-down_gold/` — **GOLD 정본**(입력: `GOLD_SILVER 의존.md`·`GOLD_ddl 초안.sql`)
- `02_GN_DW_building/02_DB_BRONZE_SILVER.md`의 PoC 기반 SILVER 23개·GOLD View 35개는 **본 설계의 입력이 아님**(제외)
- 워크스페이스 루트 `BRONZE_CRM 테이블 정보.MD` = CRM 원천 인벤토리(입력)

---

## 파일 명세

| 파일 | 역할 |
|------|------|
| `SILVER_설계_작업 계획.md` | SILVER 설계 정본. 설계원칙(0절)·테이블 전수목록 25개(1절)·BRONZE→SILVER 통합트리(2절)·개념↔물리명 매핑(2-1)·핵심결정 D1~D11(3절)·실행리스크 R1~R8(3-1)·▶BRONZE 컨트랙트 7건(3-3)·작업단계 S-1~S-7(4절)·정합성 기준(6절)·수치요약(7절). |
| `_archive/SILVER_검토결과_4차.md` | ✅ **종료·아카이브**. 작업계획에 대한 비판적 검토 결과. 정정 2건(레거시 View의 EXT_* 의존 → R8 / DIM_MEMBER_IDENTITY 커버리지 정정 → DIM 7+IDENTITY 부분)은 작업계획에 **반영 완료**. 검토 이력 보존용. |

---

## 설계 요약
- **SILVER 25테이블 예정** = CRM 15(✅즉시 설계 가능, 현재 기준·확장 가능) + GA4 5 + ERP 2 + AGENCY 3(⚠️데이터 입고 후) **+ GADS·ADMIN(데이터 도메인 추가, AGENCY/CRM 통합 예정·목적지 미정 → 별도 테이블 여부·수량 미정)**
- **CRM 15**: BRONZE CRM 40개 중 사용 37 + 미포함 3(사업장·아동·결연교체, GOLD 미참조)
- **정제 범위**: 타입 캐스팅·NULL 표준화·코드→라벨 병행보존·중복제거(PK)·동일 소스 내 JOIN. 집계(GROUP BY)는 GOLD에서.
- **계층 규칙(P2)**: `SERVING→GOLD→SILVER→BRONZE` 단방향. GOLD는 BRONZE 직접 참조 금지(외부 집계본도 `SILVER EXT_*` pass-through 경유).
- **GOLD 18(12 DIM+6 FACT) 커버**: CRM 15가 DIM 7 완전 + IDENTITY 부분(CRM측만) + FACT 3(FMM·FTG-D·FSE) 충족(즉시). 잔여는 GA4·ERP·AGENCY 입고로 충족(GADS·ADMIN은 FAD/FSE 보강분 — 통합 원천으로 흡수 예정).

## 핵심 차단/검증 항목 (S-1 착수 전)
- **R1**: FMM 시점지표가 `TH_MM_FDRM_MBER_STNG_DTLS` 컬럼 미정(D2)에 차단 — 입고팀 확인
- **R2**: 발송 키 체계 이원화(`SND_*` SEQ_NO vs `TM_MS_*` SNDNG_KEY) — 병렬/구신 시스템 확인
- **R3**: 회원 정기(41)·일시(32) UNION ALL 스키마 불일치 규칙 확정
- ~~**R4**~~: ✅ **해소** — `MEMNUM`(#111)은 별도 키가 아니라 `member id`(#112)와 동일한 `회원번호`(문자, URL 용어). `DIM_MEMBER_IDENTITY.MEMNUM`은 CRM 회원번호로 충족, 신원매핑 차단 아님
- **R7**: 약정 3중 grain(개발/사업/결연) 병합 검증
- **R8**: 레거시 View의 BRONZE/RAW 직참조 잔존(P2 위반) 검증

## 읽는 순서 (신규 진입자)
1. 본 문서 → 2. `03_top-down_gold/GOLD_SILVER 의존.md`(역산 입력) → 3. `SILVER_설계_작업 계획.md`(원칙·25테이블) → (참고) `_archive/SILVER_검토결과_4차.md`(반영 완료된 검토 이력)

## 현재 상태
- SILVER 설계 작업계획 **문서화 완료**. CRM 15개 = 즉시 설계 가능(S-1 착수 대상), GA4·ERP·AGENCY 10개 = **데이터 입고 후(S-6)**.
- BRONZE 적재 **진행 중** — CRM 40테이블만 수령, GA4 raw·ERP·AGENCY 미수령(의도된 대기).
- 다음 트랙: S-1 CRM_* 15개 엔티티 설계서(grain·PK·컬럼·정제규칙). 착수 전 R1·R2·R3·R7 선결 확인.
- SILVER→GOLD 적재 프로시저는 본 폴더 범위 밖(별도 트랙).
