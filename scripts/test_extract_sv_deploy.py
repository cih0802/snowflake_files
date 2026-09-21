#!/usr/bin/env python3
"""음성 테스트 — `scripts/extract_sv_deploy.py` (2026-09-21 O175 신설).

🔴 **왜 이 테스트가 필요한가**: O175 가 이 도구의 한계(파일당 첫 SV 만)에 걸려 임시 계측기를
만들었고, 그 계측기의 GRANT 필터가 **인덱스 하나 때문에 조용히 0건**을 냈다. 사람이 출력을
눈으로 보고 알아챘다 — 즉 **기계가 잡지 못하는 결함**이었다. 그래서 축에 넣는다.

축(각 단정이 스스로 센다 — 🔴 개수를 이 문서에 적지 않는다):
  · 축1 회귀   = `--name` 없이 부르면 **종전 동작(첫 SV)** 이 유지된다.
  · 축2 선택   = `--name` 으로 **2번째 이후 SV** 를 뽑을 수 있다(다중 SV 파일).
  · 축3 GRANT  = `--name` 지정 시 **그 SV 의 GRANT 만** 딸려 나온다(교차 혼입 0).
  · 축4 오염   = 분모를 일부러 깨서(`CREATE OR REPLACE` 주입) **P125 가드가 멈추는지** 본다.
  · 축5 오탐   = 없는 이름을 주면 **조용히 첫 SV 를 내지 않고 실패**한다
                 (이것이 가장 위험한 오탐이다 — 엉뚱한 SV 를 배포하게 된다).
  · 축6 인자   = `--name` 뒤에 값이 없으면 실패한다.
"""
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import extract_sv_deploy as M  # noqa: E402

FIXTURE = """-- 헤더 주석: `CREATE OR ALTER SEMANTIC VIEW` 로 재배포할 것(이 줄이 걸리면 안 된다)
CREATE OR ALTER SEMANTIC VIEW DB.SC.SV_FIRST
  TABLES ( a AS DB.SC.V_A )
  COMMENT = 'first sv with escaped '' quote'
  AI_SQL_GENERATION '규칙 A — 이스케이프 '' 포함';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW DB.SC.SV_FIRST TO ROLE R1;
GRANT REFERENCES, SELECT ON SEMANTIC VIEW DB.SC.SV_FIRST TO ROLE R2;

CREATE OR ALTER SEMANTIC VIEW DB.SC.SV_SECOND
  TABLES ( b AS DB.SC.V_B )
  AI_SQL_GENERATION '규칙 B';

GRANT REFERENCES, SELECT ON SEMANTIC VIEW DB.SC.SV_SECOND TO ROLE R3;

SELECT 'smoke' AS s FROM DB.SC.V_B;
"""

fails = []
asserts = 0


def check(cond, label):
    global asserts
    asserts += 1
    if not cond:
        fails.append(label)


def write(text):
    d = Path(tempfile.mkdtemp())
    p = d / 'fx.sql'
    p.write_text(text, encoding='utf-8')
    return p


def raises(fn):
    try:
        fn()
    except SystemExit:
        return True
    except Exception:
        return False
    return False


p = write(FIXTURE)

# 축1 회귀 — 인자 없이 = 첫 SV
body = M.extract(p)
check('SV_FIRST' in body, '축1: 첫 SV 미포함')
check('SV_SECOND' not in body.split('AI_SQL_GENERATION')[0], '축1: 첫 SV 추출에 2번째가 섞였다')
check("이스케이프 '' 포함" in body, '축1: 이스케이프 따옴표에서 조기 종료했다')
check("SELECT 'smoke'" not in body, '축1: 스모크 SELECT 가 배포문에 섞였다')

# 축2 선택 — 2번째 SV
body2 = M.extract(p, 'SV_SECOND')
check(body2.count('CREATE OR ALTER SEMANTIC VIEW') == 1, '축2: 문장이 1개가 아니다')
check('SV_SECOND' in body2, '축2: 지정 SV 미포함')
check('규칙 B' in body2, '축2: 지정 SV 의 AI_SQL_GENERATION 미포함')

# 축3 GRANT — 교차 혼입 0
check(body2.count('GRANT REFERENCES') == 1, '축3: GRANT 건수가 1이 아니다(0이면 필터 인덱스 결함)')
check('TO ROLE R3' in body2, '축3: 그 SV 의 GRANT 가 빠졌다')
check('TO ROLE R1' not in body2, '축3: 다른 SV 의 GRANT 가 혼입했다')
body1 = M.extract(p, 'SV_FIRST')
check(body1.count('GRANT REFERENCES') == 2, '축3: 첫 SV GRANT 2건이 아니다')

# 축4 오염 — P125 가드
bad = write(FIXTURE.replace('CREATE OR ALTER SEMANTIC VIEW DB.SC.SV_SECOND',
                            'CREATE OR REPLACE SEMANTIC VIEW DB.SC.SV_SECOND'))
check(raises(lambda: M.extract(bad, 'SV_SECOND')), '축4: CREATE OR REPLACE 를 잡지 못했다')
#   역방향 = 오염이 없으면 통과해야 한다(가드가 항상 멈추면 무용지물이다)
check(not raises(lambda: M.extract(p, 'SV_SECOND')), '축4 역: 정상 입력을 막았다')

# 축5 오탐 — 없는 이름
check(raises(lambda: M.extract(p, 'SV_NOPE')), '축5: 없는 SV 이름에 실패하지 않았다(엉뚱한 배포 위험)')

# 축6 인자 — AI_SQL_GENERATION 절 부재
noai = write("CREATE OR ALTER SEMANTIC VIEW DB.SC.SV_X\n  TABLES ( a AS DB.SC.V_A );\n")
check(raises(lambda: M.extract(noai, 'SV_X')), '축6: AI_SQL_GENERATION 부재를 잡지 못했다')

if fails:
    print(f'🔴 FAIL — {len(fails)}건 / 단정 {asserts}건')
    for f in fails:
        print('   ·', f)
    sys.exit(1)
print(f'🟢 PASS — extract_sv_deploy 음성 테스트 · 단정 {asserts}건')
