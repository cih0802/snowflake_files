import io


def rep(p, a, b):
    s = io.open(p, encoding='utf-8').read()
    assert s.count(a) == 1, (p, a)
    io.open(p, 'w', encoding='utf-8').write(s.replace(a, b))


rep('/workspace/문서실행순서.md',
    '15. /10_dbt_pipeline/02_dbt_parse_compile_build.sql — 전체(🔴 [O261] `build` 다음 **범위 지정 build 필수** · 정지점 = Step 3-3 [3-3-a] 원천·SILVER·GOLD 일자 수 일치 확인 후 16 진행)',
    '15. /10_dbt_pipeline/02_dbt_parse_compile_build.sql — 전체(🔴 범위 지정 build = 백필이라 **운영계는 건너뛴다**(`R2-9`) · 🔴 [O261] 정지점 = Step 3-3 [3-3-a] 원천·SILVER·GOLD 일자 수 일치 확인 후 16 진행 · 불일치면 멈추고 사용자에게 보고)')
rep('/workspace/10_dbt_pipeline/02_dbt_parse_compile_build.sql',
    '-- 🔴 [O261 · 필수] 신규 구축·재배포 직후 아래 **범위 지정 build 를 반드시** 이어서 돌린다',
    '-- 🔴 [O261 · 개발계·신규 구축 필수 · 운영계는 백필 제외 R2-9] 신규 구축·재배포 직후 아래 **범위 지정 build 를 반드시** 이어서 돌린다')
rep('/workspace/10_dbt_pipeline/02_dbt_parse_compile_build.sql',
    '--   🔴 정지점 = Step 3-3 [3-3-a] 원천·SILVER·GOLD 일자 수가 같아야 다음 단계(문서실행순서 20 이후)로 간다.',
    '--   🔴 정지점 = Step 3-3 [3-3-a] 원천·SILVER·GOLD 일자 수가 같아야 다음 단계(문서실행순서 개발계 20 · 운영계 16)로 간다 — 운영계에서 어긋나면 멈추고 사용자에게 보고.')
rep('/workspace/문서실행순서_llm실행.md',
    '· 🔴 [O261] 범위 build **필수**(사람 실행 시 빠뜨리면 GA4 하류 0행 · ERROR 0 무증상) · Step 3-3 일자 수 일치 = 다음 단계 정지점 |',
    '· 🔴 [O261] 개발계·신규 구축은 범위 build **필수**(사람 실행 시 빠뜨리면 GA4 하류 0행 · ERROR 0 무증상 · 운영계는 §1 `R2-9` 로 제외) · Step 3-3 일자 수 일치 = 다음 단계 정지점(양쪽 공통) |')
rep('/workspace/문서실행순서_보조주석.md',
    '🆕 🔴 [O261] **전체 `build` 다음 BigQuery 범위 build 필수**',
    '🆕 🔴 [O261] **개발계·신규 구축은 전체 `build` 다음 BigQuery 범위 build 필수**(운영계는 `R2-9` 백필 제외 · Step 3-3 정지점만 공통)')
rep('/workspace/문서실행순서_llm실행.md',
    '- 현업 회신이 오면 `37` [D5] 로 seed CSV 를 고친 뒤 30 → [D3] 3-2(MANUAL 부서 수 = seed 행수) 만 다시 한다.\n',
    '''- 현업 회신이 오면 `37` [D5] 로 seed CSV 를 고친 뒤 30 → [D3] 3-2(MANUAL 부서 수 = seed 행수) 만 다시 한다.

### 3.7 🆕 O261 증분(`문서실행순서.md` 「기존 환경 갱신」 37~38 · 개발계 UM80684 2026-10-24 실측)

| 순 | 실행 방식 | 실측 |
|---|---|---|
| 37 | dbt 재배포 + `build --select AGENCY_AD_PERFORMANCE+` | 🔴 사용자가 실행한다(에이전트 정지점) · 재방송 NAME 286 · UPPER_CODE 1,808 · NONE 96 |
| 38 | SV 파일 34개 각 전체(문장 단위) · 순서 = 05_01~05_30 → 22 → 23 → 24 → 25 → 34 → MSTR 05 · 실행기 예 = `python3 scripts/run_sql_file.py <파일…>` | 🔴 `35_`·`36_` 은 이력 파일이라 실행하지 않는다(같은 정의 = 05_27~05_30) · Agent 재버전 불요 |

- 🔴 신규 구축(위 개발계 1~59)도 SV 파일에 이번 문안이 이미 들어 있다 — 따로 실행할 것이 없다.
- 확인 = `scripts/sv_enum_newvalue_gate.py`(NEW 0 · STALE 0 · rc=0 · 대조 차원 0 이면 rc=2 미판정) · `scripts/sv_code_label_gate.py`(🔴 0) · `scripts/sv_no_rollup_gate.py`.
  - `sv_enum_newvalue_gate` 는 SV 44개 × 차원마다 DISTINCT 를 돌려 수 분 걸린다 ⇒ 백그라운드로 돌린다.
- 🔴 [O261] SV COMMENT 에 **종 수를 적지 않는다** — 값 목록은 「주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인): 'a'·'b'」 형식(이 접두를 `sv_code_label_gate` 가 열거로 읽는다).
- 🔴 [O261] 사람이 dbt 를 돌린 뒤 하류 행수를 확인하지 않고 다음 단계로 가지 마라 — 개발계 19 에서 범위 build 를 빠뜨려 GA4 하류가 ERROR 0 · 0행으로 남았다(Step 3-3 정지점).
''')
print('ok')
