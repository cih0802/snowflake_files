### ▣ O262-A-0 🔴 먼저 알아라

- `O262` = `O261-B` 계획 집행 단위(2026-10-25 · UM80684 · TRIALADMIN). 근거 전건 = `tmp/o261b/evidence.md` E0~E9.
- 확정위반 4 = R1-7-2 같은 파일 병렬 edit 3(유실 0) · 음성 테스트 중 정본 `05_MSTR_SV_DDL.sql` mv 1(즉시 복원 · SHA256 일치 · ws ls 확인).

### ▣ O262-A-1 결과 (UM80684)

| 작업 | 상태 | 근거 |
|---|---|---|
| ㉮ SILVER 코어 상위캠페인 코드·이름 2열 분리 | 🟢 👤 build 1차 후 [D2] 일치(CD 2,715 · NM 4,086 · FACT 경로 10행 불변) | E0·E6 |
| ㉮ GOLD 승격(N-29 ⑥ 보류 해제 · 사용자 지시) | 🟡 코드·DDL·ADD COLUMN 완료 · 👤 2차 build 대기 | E7 |
| ㉯ 80 운영도구 편입(소스·MANIFEST·README) | 🟡 80 재빌드 미실행 | `scripts/README_운영도구.md` |
| ㉰ SV 공통 블록 정본화 + `sv_common_block_gate` | 🟢 소스 51 · 라이브 44 · 위반 0 | E8 · `05_SV-Agent_ai/00_SV_공통지시문.md` |
| BRONZE 카테고리 GOLD 미반영 점검 | 🟢 점검 완료 · D 47건 👤 결정 | `tmp/o262_audit/O262_카테고리_GOLD미반영_점검.md` |

### ▣ O262-A-2 다음 세션 착수 순서

1. 👤 `10_dbt_pipeline/01_deploy_dbt_project.sql` 재배포 → `build --select AGENCY_AD_PERFORMANCE+`(FACT·WIDE 새 2열 · MKTG_MAP_METHOD UPPER_NAME 허용값).
2. `43_DEPLOY_AGENCY_UPPER_CMPGN_SPLIT.sql` [D2] ②(경로 행수 = E3 동일 기대) + FACT `UPPER_CAMPAIGN_CD` 2,715 · `UPPER_CAMPAIGN_NM` 4,086 확인.
3. 노출감사 생성기 계보 등록 — `scripts/run_bronze_audit_host.py`·`gen_bronze_exposure_audit.py` LINEAGE_MAP 에 (`VIDEO_AD_CMPGN_DTLS`,`UPPER_CMPGN_CD`) → `UPPER_CAMPAIGN_CD`/`UPPER_CAMPAIGN_NM` 추가 후 30_output_share 재생성.
4. 👤 카테고리 점검 D 47건 결정(승격 · 보류 사유 기록 · 제외) → C·A 표 재확인.
5. 80 재빌드(`build_handoff.py --apply`) → 80 전체 scrub_acct.ACC 0 · 80 사본 `--help` · `sv_common_block_gate --source-only`(80 SV 폴더).
6. 문서 = `20_issue/32_컬럼개명표.md`(FACT 2열 신규) · `문서실행순서_보조주석.md` 「O262 만 덧입힐 때」 · O15 행 갱신.

### ▣ O262-A-3 끝 조건

- 남은 일이 「운영계 반영」만 = 문서실행순서 「기존 환경 갱신」 33 → … → 40 을 운영계에 한 번에 집행(👤).
- 승계 = O261-A ⑤ · O259-A-3 ③④ · O256-B-2.
