### ▣ O265-A-0 🔴 먼저 알아라

- `O265-A` = 현업 문의 대응(회원서비스기획팀 김나경 · 회원참여팀 강지영) · 2026-10-28 · TRIALADMIN(UM80684) · ㉡ · dbt 미실행(R4-1 준수).
- 🔴 원인 확정 = SILVER `CRM_SEND_REQUEST` 가 EMAIL·MSG_AT 대중소를 **NULL 로 고정**했다(원천에는 `SNDNG_CD_ID`=대 · `SNDNG_DTL_CD_ID`=소 · 중=소 앞 2자리).
  - 근거 = SND 2,329행 전건 LEFT(BOT,2)=MID · SND 74경로 공통코드 라벨 대·중·소 100% 일치.
- 🔴 문자 시스템(SND)도 알림톡을 보낸다 = MSG_TYPE '1' 1,560/2,329(템플릿 AT 코드 전건) · 2025-09-17 「행운의 카드」(AT006040 · 8,647명) 포함.
- 확정위반 1 = R1-7-8(원장 edit 앵커가 O264 행 머리를 삼킴 · 즉시 복원 · 행키 게이트 PASS) · read 미반환 0.

### ▣ O265-A-1 결과 (코드 · 개발계 미build)

| 영역 | 결과 | 정본 좌표 |
|---|---|---|
| ① 대중소 | EMAIL·MSG_AT 분기 채움(라벨 = CRM_CODE_GROUP·CRM_CODE) · 행수 불변 · 대분류 채움 0→100% | `10_dbt_pipeline/models/silver/crm/CRM_SEND_REQUEST.sql` |
| #160·#161 | 사용자 결정 = 전 채널 확대(이메일 MS054 요청 541,106 유입 ⇒ 값 증가 · 현업 공지 대상) | `FACT_MESSAGE_DISPATCH.sql` #160 블록 |
| 메시지 형식 | `DIM_SEND_REQUEST.SEND_FORMAT_NAME` 신설(센티넬 50열) | `DIM_SEND_REQUEST.sql` · `06_DDL.sql` |
| ② 알림톡 열람 | `GA_CLICK_MEMBERS`·`GA_CLICK_TS` 신설 · memnum+카카오 경로 · 직전 5일 최근접 알림톡 1건 귀속 · 시뮬 = 행 44,626,415 불변 · 클릭 MSG_AT 8,524 · SND 7,610 | `FACT_MESSAGE_DISPATCH.sql` ga_* CTE |
| SV | 대중소 COMMENT「문자 전용」 제거 · 신규값 `데이터` · 차원 2 · 지표 2 · 규칙 [O265] (가)~(마) | `05_SV-Agent_ai/05_04_SV_DDL_SERVICE.sql` |
| 배포 | [D0]~[D3] 대사 기대값 포함 | `05_SV-Agent_ai/45_DEPLOY_SEND_GBN_AT_OPEN.sql` |

### ▣ O265-A-2 ㉠ 이 작업의 잔여

| 순 | 작업 | 판정 |
|---|---|---|
| ① | 👤 45 [D0]·[D1] → 재배포 → `build --select CRM_SEND_REQUEST+` → [D2] → 05_04 재배포 → [D3] | 개발계 |
| ② | 회원참여팀 코호트 대중소 — SV 관계는 불가(양쪽 비유일 grain) ⇒ 방식 재결정 필요 | 사용자 결정 대기 |
| ③ | 현업 회신문(김나경·강지영) · #160 값 증가 공지 | ① 대사 후 |
| ④ | 운영계 반영(45 · 기존 환경 갱신 #43) | ① 후 |

- 🟠 참고: 현업이 받은 예시(35,669명 · 클릭 273명)는 재현 불가 — 최광의(모든 memnum · SND 포함)로도 27,881명 · 80명.
- 🟠 kakao utm 유입에는 카카오 채널 게시물 유입도 섞인다(잠정 정의 · SV COMMENT 에 명시).

_Co-authored with CoCo_
