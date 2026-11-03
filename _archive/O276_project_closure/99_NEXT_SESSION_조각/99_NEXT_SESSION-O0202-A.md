<!-- LLM-METADATA
doc_id: HANDOFF_O0202_A
doc_role: 인수인계 — 세션 `O202-A` 가 다음 세션에 넘기는 것(라벨 파일 · O172 규격)
project: GN_DW (굿네이버스)
created: 2026-10-06
created_by: O202-A
parent: 99_NEXT_SESSION.md
index: 20_issue/00_INDEX_이슈원장.md
END-METADATA -->

<!-- HANDOFF-LABEL O0202-A -->

> 🔴🔴 **이 파일은 인수인계 라벨 파일이다 — 조각이 아니다.**
> 허브 목차·`--verify` concat·`발행 SHA256` 과 **무관**하다(`O172` 규격).
> 🟢 **현행 판정식 = 라벨 최대값**(O번호 → 접미 길이 → 접미) ⇒ 취소선 승계 표기가 필요 없다.
> 🔴 다음 세션은 **이 파일 1개만** 읽으면 된다. 조각에 남은 옛 절은 승계된 것이다.
### ▣ O202-A-0 🔴 먼저 알아라 (2026-10-06 · JU93656 · ㉡ 적용 · 확정위반 1)

- 정본 = `17_MSTR통한 메달리온 보완/00_작업계획.md` · 규칙 카드 = `03_규칙카드_A1.md`(R01~R04 · 사용자 결정 §0).
- 🟢 사용자 결정 3건 = 법인 축 MSTR 기준(후원사업 법인 · CM019 A 통합/I 사단/S 사복) · DEV_CNT MSTR 정의로 교체 · GN_DW↔MSTR 합산 금지 유지 — 모순 0 판정.
- 🟢 사전 검증 = SILVER 재현 ↔ `GN_DW.MSTR.F_MM_SPNSR_DVLP_SUM` 2026-01~10 10개월 전건 일치(회원·건·행) · 매체운영팀×사단 7월 5,989명/11,956.2055건.
- 🟠 파일만 바뀌었다(라이브 미반영) — dbt 5 모델(DIM_SPONSORSHIP · FACT_MEMBER_EVENT · FACT_MEMBER_MONTHLY · WIDE_MEMBER_EVENT · WIDE_MEMBER_MONTHLY_KPI) · SV 2(05_2 · 05_14).
- 🔴 확정위반 1 = 같은 파일(`05_2_SV_DDL_MEMBER_EVENT.sql`)에 `edit` 병렬 4건(`R1-7-2`) — 해시 2회 동일·반영 4/4 실측으로 유실 0 확인.
- 🟢 D6 게이트 `scripts/live_change_gate.py` 시행 = 2026-10-06 — 🔴 SV·Agent 를 재배포하는 세션은 **원장 §1 행에 객체명 + 배포 날짜**를 적어야 PASS 한다.

### ▣ O202-A-1 🟠 남은 작업

| 순 | 작업 | 다음 행동 |
|---|---|---|
| 1 | ㉠ 👤 dbt build (O202 반영) | `dbt build --project-dir 10_dbt_pipeline --select DIM_SPONSORSHIP+ FACT_MEMBER_EVENT+` (사람 실행 · FMM·KPI·WIDE·ACHIEVEMENT 하류 포함) |
| 2 | ㉠ SV 재배포 + 검증 | dbt 후 `05_2`·`05_14` 배포 → VQR(매체운영팀×사단 7월) = 5,989/11,956.2055 확인 → 원장 §1 에 SV_MEMBER_EVENT·SV_MEMBER_MONTHLY_KPI 배포 행(D6) |
| 3 | ㉠ A0 매핑표 · A2 차원 대조 | `02_MSTR_GOLD_매핑표.md` 신설 → 계획 §3-1 |
| 4 | ㉠ FN B3 라이브 교체 | `03_function_script.sql:184` 해소키 → 🔴 라이브 함수 교체·SUM 재적재 승인(R4-4-3) · 원 MSTR 대조(IT) |
| 5 | ㉡ MSTR 3종 Agent 반영 | 사용자 결정(요청서 41 요청 1 · A/B/C) — 정의가 같아져 A안 근거 강화 |
| 6 | ㉡ MSTR 월 정기 Task | `06_MSTR_적재_실행.sql` [4] → 생성 여부 사용자 결정 |
| 7 | ㉡ ML 질문 개선 후보 | MKT LTV·일시전환 도구 · 기획실 A/B안 VQR · GA 행동 SV — Agent 버전업(라이브) 설계·승인 필요 |
| 8 | ㉡ FMM 미래월 처리 방침 | 선납 회비월 행(202611~202911) 유지/절단 사용자 결정 · 210103 = 원천 납입일 오타 3건(일시회원 S00009035·S00009077·S00009183) 정정 요청 |
| 9 | ㉡ 👤 운영계 이관 | 00~04 배포 → 06 [0]~[3] → `mstr_verify --ym 202601`(운영계 계정 · 사람) |
| 10 | ㉡ 👤 CoWork 스모크 | 새 COMMENT·별칭·비율 5종 + O202 법인 축 질의 |
| 11 | ㉡ 👤 현업 | 공46 방향 · 공54 정의 · 문서20 N-26(①②) · 기획실 후원사업그룹 축 · 문서50 BLOCKING-2 · O59-P-1 |

### ▣ O202-A-2 ⚪ 결정 완료(재론 금지)

- 법인 = 후원사업 법인(MSTR 기준) · 「법인·사단법인·사단·사복」 동의어는 SPONSORSHIP_CPR_DIV_NM 소관 · 세부캠페인 법인은 명시 시만.
- 개발(건) = MSTR 인정금액 ÷ 10,000 · 개발(명) = 인정 행 보유 distinct(종전 사건 수 정의 폐기).
- GN_DW ↔ GN_DW.MSTR 수치 한 표 합산 금지 유지.

_Co-authored with CoCo_
