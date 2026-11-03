<!-- LLM-METADATA
doc_id: HANDOFF_O0191_F
doc_role: 인수인계 — 세션 `O191-F` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-09-30
created_by: O191-F
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0191-F -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값** ⇒ `O191-E` 는 이 파일로 승계됐다.
### ▣ O191-F-0 🔴 먼저 알아라 (2026-09-30 · bt97381)

- 사용자 보고: 전체 `dbt build` PASS=577 WARN=21 ERROR=0(O191-E 1묶음 반영 완료).
- ⏸ **dbt build 1회 필요** — SILVER 9종 모델 변경(2차-B 2단 2묶음) · DDL·ADMIN ALTER 78/78 선행 · LIMIT 0 컴파일 9/9 · 라이브 ordinal 일치 9/9.
- 🔴 사용자 순서 지시: ① 잔여 테이블 수정 → ② SV 전부 → ③ 스모크 → ④ 작업 중 신규 발견 작업 → ⑤ 산출물(프롬프트 입력으로).

### ▣ O191-F-1 🟢 이 단위가 끝낸 것

- 2차-B 2단 2묶음 = UNION·다원천 SILVER 9종 **78컬럼**(비해당 원천 분기 = 형 맞춘 `CAST(NULL AS …)`)
  · EVENT 10 · EVENT_PARTICIPATION 8 · MEMBER 3 · PAYMENT_BILLING 7 · RELATION_ACTIVITY 12 · SEND_REQUEST 16 · SEND_RESULT 7(집계) · SEND_MEMBER 8 · CAMPAIGN 7.
  · 명세 정본 = `scripts/_scratch_o191f_gen.py` SPEC · 후보 실측 = `tmp/o191f_cand.txt`(채움률).
- 원천 26 중 후보 0 = `SND_MEMBER_OPEN_LOG` · `TC_MKTNG_DTL_CD` · `TD_MS_EMAIL_SNDNG_DTLS` · 템플릿 2종 ⇒ 2차-B **SILVER 단계 종결**.
- 🔴 제외 = 개인정보·발신번호·메일주소 · 처리자ID · 템플릿/설문 링크 · 채움≈0 · 동기화 기술컬럼 · SND_MEMBER_LIST 회원 속성 복제(성별·연령·캠페인 등 — 회원 마스터 중복).
- 타입 보정: PRCS_DE DATE/TIMESTAMP 혼재 → TIMESTAMP_NTZ · TMPLAT_ID/ALTRTV_MSG_SNDNG_YN 은 SND_REQ_MST `TMPL_CODE`·`ALT_SMS_YN` 과 같은 의미로 합류.

### ▣ O191-F-2 🟠 남은 작업

| 순 | 작업 | 남은 이유 | 다음 행동 |
|---|---|---|---|
| 1 | dbt build(SILVER 9종+) | 사용자 실행(`R4-1`) | ▣3 명령 |
| 2 | GOLD·SV 전파(2차-B 99컬럼) | grain 판단(문서32 §3 원칙) · 지시 순서 ② | 컬럼별 채택/보류 표 → GOLD DDL·모델 → SV |
| 3 | 스모크 재측정 | 과금 · ② 이후 | 기준선 2 대비 |
| 4 | `rename_stale_gate` 축1 +1 | 사용자 신규 파일 `02_GN_DW_building/20_일배치테스트용.sql`(9/29 · 395KB) — 에이전트 미수정 | 사용자 확인 후 개명 반영 또는 `--baseline --reason` |
| 5 | 산출물 03~09 + 골든 | 지시 순서 ⑤ | 프롬프트 입력 시 |

㉡ 워크스페이스 백로그 = ML 일시전환 실행순번(ML 담당) · 44 오픈 정의 ML 공유.

### ▣ O191-F-3 ⏸ dbt 정지점 (`R4-1`)

```sql
USE ROLE GN_DW_DBT;
ALTER DBT PROJECT GN_DW.OPS.DW_PIPELINE DEPLOY FROM 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/10_dbt_pipeline/';
EXECUTE DBT PROJECT GN_DW.OPS.DW_PIPELINE ARGS='build --select CRM_EVENT+ CRM_EVENT_PARTICIPATION+ CRM_MEMBER+ CRM_PAYMENT_BILLING+ CRM_RELATION_ACTIVITY+ CRM_SEND_REQUEST+ CRM_SEND_RESULT+ CRM_SEND_MEMBER+ CRM_CAMPAIGN+';
```

_Co-authored with CoCo_
