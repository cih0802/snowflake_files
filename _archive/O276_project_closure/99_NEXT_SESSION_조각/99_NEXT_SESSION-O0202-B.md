<!-- LLM-METADATA
doc_id: HANDOFF_O0202_B
doc_role: 인수인계 — 세션 `O202-B` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-06
created_by: O202-B
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0202-B -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O202-B-0 🔴 먼저 알아라 (2026-10-06 · JU93656 · ㉡ 적용 · 확정위반 0)

- 🔴 사고 = 2026-10-05 19:49 PDT `03_top-down_gold/06_DDL.sql` 전체 재실행(GN_DW_ADMIN) → GOLD 41테이블 0행 → FK 테스트 11 FAIL. 사용자 GOLD 전량 build 로 복구(PASS=596).
- 🔴 잔존 = `GOLD.FACT_BIGQUERY_BEHAVIOR` 0행(롤링 창 밖) → `dbt_project.yml` 백필 슬롯 **개방 중**(build 1회 후 반드시 재주석).
- 🟢 라이브 검증 = GOLD 2026-01~10 MSTR SUM 전건 일치 · SV_MEMBER_EVENT 매체운영팀 사단 5,989/11,956.2055 · 사복 126/442.
- 🟢 배포 = SV_MEMBER_EVENT · SV_MEMBER_MONTHLY_KPI(공46 교정 · 202512 80.35%). SV_MEMBER_MONTHLY(공54 신설·공55~57 분자 교정)는 build 후.

### ▣ O202-B-1 🟠 남은 작업

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | ㉠ 👤 build | `--select CRM_PAYMENT_BILLING+ FACT_BIGQUERY_BEHAVIOR+` → 끝나면 `bigquery_dt_ranges` 재주석 |
| 2 | ㉠ SV_MEMBER_MONTHLY 배포 | build 후 `05_1` 배포 · STOP_AMT_CNT 비NULL 건수 · 공54~57 값 확인 · 원장 §1 기록(D6) |
| 3 | ㉠ 검증 | FMM·FEE MONTH_KEY>210000 = 0 · FACT_BIGQUERY_BEHAVIOR 행수 복구 |
| 4 | ㉡ 👤 ML 회원예측 중복 | 원천에 인입순서 근거 없음(컬럼·병렬 unload 파일) ⇒ 사용자 입력 대기 · 현 처리(평균·MAX) 유지 |
| 5 | ㉡ 👤 기획실 4그룹 | MSTR 근거 없음(약칭 CM003·후원사업2만 존재) ⇒ 사용자 입력 대기 |
| 6 | ㉡ 👤 FN B3 동점 | 사용자 결정(해소키 라이브 반영 여부) |
| 7 | ㉡ 👤 BLOCKING-2 E · SEND_STATUS2 | 미해결 실측(E 고아 279,904/1,274,437 · EVENT_105·106 · SEND_STATUS2 0/43,440,831) |
| 8 | ㉡ 06_DDL 전체실행 방지 | 헤더 경고 문구 · on_schema_change 유지 결정 |

### ▣ O202-B-2 ⚪ 결정 완료(재론 금지)

- 공46 = 활동 ÷ 누계개발(사전 오타) · 공54 = 사전 정의(그 달 개발(건)) · 미래 납입일 = SILVER 필터.
- N-26 ① = CMPGN_SPNSR_AMT_LTV 는 캠페인코드 · MKTG_CHANNEL_MBER_AVG_LTV 는 C002 채널코드(코드정의 범위 대조).

_Co-authored with CoCo_
