### ▣ O225-A-0 🔴 먼저 알아라

- O224-B 착수표 ①~④ 를 집행했다(사용자 「승인 필요 작업 전부 승인」 · ㉡ 적용 · 확정위반 0건).
- 🔴 **dbt build 대기**(`R4-1`) — 아래 명령은 사용자가 실행한다. build 전 라이브 팩트는 **구 로직 그대로**다.
  · `dbt build --select FACT_AD_PERFORMANCE assert_fap_ad_cost_preserved warn_fap_mktg_unmapped_ratio --project-dir 10_dbt_pipeline`
- 라이브 DDL(xh20001) = `GN_DW.GOLD.FACT_AD_PERFORMANCE` 에 `MKTG_MAP_METHOD`(33)·`MKTG_MAP_CAND_CNT`(34) ADD 완료(INFORMATION_SCHEMA 확인).

### ▣ O225-A-1 이번 단위 결과

| 순 | 결과 |
|---|---|
| ① | 경로 확정 = `FACT_AD_PERFORMANCE.sql` 이름매칭(O45) 단일 경로 · `DIGITAL_MAP`/`HAVING = 1` 은 워크스페이스·라이브 부재(O224 판정 유지) · 그 계정 코드 위치는 👤 미회신 |
| ② | 재실측 = DIGITAL 미매핑 11,379,933,112원 · 33.69% · 1위 `유어턴링(2기)` 4,895,482,455원 · VIDEO 95.85% · REBROADCAST 100%(캠페인명 결손 · 별도 과제) |
| ③ | 규칙 확정 = 이름매칭 우선 → UTM as-of(시작일 ≤ 광고일) → **매핑 행수 최다** → 시작일 최근 → 이름 → 코드 · 🔴 §15-9 초안(시작일 최근 우선)은 turn24b 전액을 협업 캠페인(6행)에 붙여 **교정** |
| ④ | 모델 = `utm_pick` CTE · 테스트 2종 = `assert_fap_ad_cost_preserved`(행수·광고비·DK 유일) · `warn_fap_mktg_unmapped_ratio`(15% · 경로 정합) |

- dry-run(라이브 SQL) = DIGITAL 232,412행 · 광고비 보존 · fan-out 0 · 미매핑 2,693,839,977원(7.98%) · UTM 귀속 53,054행 8,686,093,136원(1:N 32,146행).
- 이름매칭 ↔ UTM 1:1 일치 91.9%(광고비) ⇒ 이름매칭 우선 유지.

### ▣ O225-A-2 다음 세션 작업

- ① 👤 build 결과 확인 → `MKTG_MAP_METHOD` 분포가 dry-run(NAME 155,183 · UTM 53,054 · NONE 24,175 · DIGITAL)과 같은지.
- ② 착수표 ⑤ 1:N 안전장치 전수(`tmp/o224/onen_inventory.txt` 41곳) · ⑥ SV_AD 등 스모크(귀속 변경으로 캠페인별 광고비가 바뀐다).
- ③ `12_agent개선과제/00_작업계획.md` §15-9 대안 규칙 순서를 이 결과로 갱신(미반영).

_Co-authored with CoCo_
