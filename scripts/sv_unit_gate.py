# -*- coding: utf-8 -*-
"""[2026-08-10 O52-A] Semantic View **비율 metric 단위 게이트** — percent 규약 상시 감시.

🔴 왜 필요한가(실측 경위): `SV_MEMBER_FEE.PAYMENT_RATE_FEE`·`UNPAID_RATIO` 와
   `SV_MEMBER_COHORT.CHURN_RATE_12M` 이 **분수(0~1)** 였고 동명·동의미 지표인
   `SV_MEMBER_MONTHLY` 쪽은 **percent** 였다 ⇒ 같은 이름의 값이 **100배** 어긋났다.
   Agent instruction 이 「비율=% 2자리」이고 orchestration 이 그 도구로 명시 라우팅하므로
   **에러 없이 "0.86%"(정답 86.19%) 라고 답하는 활성 경로**였다(AD-4/P19 무증상 오답).

🔴 사람 눈으로는 못 잡는다 — metric 이 9 SV 에 60여 개이고 새 SV 가 늘어난다.
   ⇒ 규약을 **게이트로 고정**한다(P120: 「무엇이 빠졌나」는 정본 기준으로 배포 전에 본다).

판정 규칙
  · 비율 metric = 식에 `/` 가 있고 **비율 의미**인 것. `×100` 이 없으면 위반.
  · 🔴 **P122**: 「나눗셈이 있다」는 「비율이다」가 아니다 — 단가·평균·배수도 나눗셈이다.
    의미 판정을 코드가 대신할 수 없으므로 **예외를 명시적 화이트리스트로 관리**한다.
    새 단가·평균 metric 을 만들면 아래 NOT_RATIO 에 등재할 것(등재하지 않으면 게이트가 잡는다 =
    의도된 동작이다. 침묵 통과보다 오탐이 안전하다 · P16).
  · 🔴 **P124**: 판정 상수 `<= 1.0` 이 남아 있으면 그 자체가 단위 분기의 흔적이다 —
    DDL 파일의 상한 판정도 함께 훑는다.
"""
import sys, re, io, os, glob

sys.path.insert(0, '/workspace/scripts')
from sfconn import conn, q

SCHEMA = 'GN_DW.SERVING'

# 비율이 아닌 metric(나눗셈이지만 단가·평균·기간 등) — 의미 기반 예외. 근거를 함께 적는다.
NOT_RATIO = {
    'DEV_UNIT_PRICE':        '개발단가(원/건) — 금액÷건수이므로 percent 가 아니다',
    'REBRDC_DEV_UNIT_PRICE': '재방송 개발단가(원/건)',
}

RATIO_HINT = re.compile(r'RATE|RATIO|_PCT|율$|률$')

# ── [2026-08-13 O68 신설] **필수 문안 존재** 축 (O67-B C1 = `P227` 재발 방지) ──────────
# 🔴🔴 왜 필요한가: 이 게이트의 문안 관련 축은 **금지만** 봤다(`NUM_BAN`·`RETIRED_EXPR`).
#   실측(O67-B): `REQUIRED`/`must_contain` 검색 **0건**. 그래서 O67 이 SV 5종에 발행한
#   판정 4종 문안이 **다음 재배포에서 조용히 사라져도 게이트가 통과**하는 상태였다.
#   ⇒ `P227`(「복구」와 「재발 방지」는 다른 작업이다)의 직접 적용: 발행물에는 그것을 지킬 축이 있어야 한다.
# 판정 = 해당 SV 의 라이브 **SV 레벨 COMMENT + AI_SQL_GENERATION** 에 토큰이 전부 있어야 한다.
#   ⚠️ 토큰은 **적재량과 무관한 규약어**만 쓴다 — 수치를 넣으면 규칙 7(`NUM_BAN`)과 정면 충돌한다.
#   ⚠️ 발행을 의도적으로 회수할 때는 여기서 지운다(지우지 않으면 게이트가 잡는다 = 의도된 동작).
REQUIRED_TEXT = {
    'SV_MEMBER_MONTHLY': ['집계필요', '배분규칙필요', '형제팩트중복', '앵커_경합', '이중계상'],
    'SV_MEMBER_EVENT':   ['집계필요', '배분규칙필요', '앵커_경합'],
    'SV_SERVICE':        ['배분규칙필요', '앵커_경합', 'WIDE_GA_BEHAVIOR'],
    'SV_DEV_ACHIEVEMENT': ['앵커_경합'],
    'SV_MEMBER_FEE':     ['배분규칙필요', '형제팩트중복', '앵커_경합', '이중계상'],
}


def scan_required(sv, text):
    """그 SV 에 등재된 필수 토큰 중 **없는 것**을 돌려준다."""
    want = REQUIRED_TEXT.get(sv, [])
    t = ' '.join(str(text or '').split())
    return [w for w in want if w not in t]


# ── COMMENT 수치 금지 토큰 검출 (05_0 COMMENT 작성 규약 (1) · 04 §6.9-(8) · 작업규칙 7) ──
# 🔴 [2026-08-11 O59-D] main() 안에 있던 판정식을 모듈 수준으로 올렸다 — `--self-check` 로
#   패턴 자체를 대조하려면 DB 접속 없이 호출 가능해야 한다(P106: 게이트는 대상이 있는 상태에서 돌린다).
NUM_BAN = re.compile(
    r'\d{1,3}(?:,\d{3})+'          # 천단위 구분 실측치 (행수·금액)
    # 🔴 [2026-08-11 O59-E] **`%p` 를 `%` 보다 먼저** 둔다. 반대 순서면 `2.3%p` 가 `%` 분기에서
    #   `'2.3%'` 로 먼저 소비돼 **`%p` 분기가 영원히 도달 불가**(dead code)였다. 실측으로 확인했다.
    r'|\d+\.\d+\s*%p'              # 퍼센트포인트 차이
    r'|(?<!10)\d+\.\d+\s*%'        # 소수점 백분율 (커버리지·비율 실측치 · 100% 임계는 제외)
    r'|\b\d+\.\d{4,}\b'            # 고정밀 실측치 (13.747454 등)
    r'|\b\d+(?:\.\d+)?\s*배\b'     # 배수
    # 🔴 [2026-08-11 O59-D 신설] **소규모 실측치**(천단위 구분이 없어 위 패턴을 빠져나간다).
    #   경위: O59-B 에서 내가 `CM_POSITION` COMMENT 에 *"백틱 1문자 **1행**"* 을 넣었고
    #   게이트는 「신규 유입 0」으로 **통과시켰다**. 「1행」은 쉼표가 없어 첫 패턴에 걸리지 않는다.
    #   🔴 정본은 이미 이것을 이름으로 금지하고 있었다 — `05_0` COMMENT 작성 규약 (1) ·
    #     `04_SV_설계.md` §6.9-(8) = *"행수·합계·커버리지%·건수·금액·적재기간"*. 규모와 무관하다.
    # 🔴 **선행 문자 차단 `(?<![\d,§#])` 필수**
    #   · `\d`·`,` — `1,010,680건` 이 `680건` 으로 쪼개지는 것을 막는다(패턴 단독 사용 시 방어).
    #   · `§`·`#` — **절 참조·지표번호 뒤에 단위어가 오면 붙어 잡힌다.** 실측 오탐:
    #     `'미납중단(명) — 05 2-2 원천 확인(정본 §3 건·명)'` 이 `§3` + `건` = **`'3 건'`** 으로 검출됐다(O59-E).
    r'|(?<![\d,§#])\d+\s*행\b'     # 행수 (1행·53건 유형)
    r'|(?<![\d,§#])\d+\s*건\b'     # 건수
    r'|(?<![\d,§#])\d+\s*명\b'     # 인원
    r'|(?<![\d,§#])\d+\s*원\b'     # 금액
)
# ⚠️ **「N종」은 금지하지 않는다** — 코드 도메인의 크기이고 §6.9-(5) 가 열거와 함께 요구하는 값이다.
#   적재량이 아니라 **코드체계**에 종속되며, stale 이 되면 `sv_code_label_gate` ①(종수 선언 정합)이
#   **즉시 실패**시킨다. 즉 게이트로 보호되는 유일한 수치이므로 예외로 둔다(근거 = 04 §6.9-(5)).

# 🔴 [2026-08-11 O59-D] **의미 예외 — 문맥으로 판정한다**(NOT_RATIO 와 같은 사상 · P122).
#   규칙 7 이 금지하는 것은 **적재량에 따라 변하는 실측치**다. 아래는 형태만 수치이고 적재량과 무관하다.
#   ⇒ 예외를 두지 않으면 오탐 15건이 진짜 2건을 덮는다(**P177**: 오탐이 진짜를 덮으면 P103-⑤ 로 뒤집힌다).
#   판정은 **토큰이 예외 패턴의 매치 구간에 포함될 때만** 면제한다(값 전체를 면제하지 않는다).
#   ⚠️ 문안에 마크다운 강조(`**`)가 섞이므로 인접 판정에 `[*\s]*` 를 넣는다 — 없으면
#     *"회원×월 정확히 1행** grain"* 처럼 강조가 끼인 grain 서술을 놓쳐 오탐이 된다(실측 1건).
NUM_EXEMPT = [
    (re.compile(r'\d+\s*행[*\s]*=[^,·.]{0,12}'),   'grain 정의(1행=1회원) — 구조이고 적재량과 무관'),
    (re.compile(r'\d+\s*행[*\s]*grain', re.I),     'grain 정의'),
    (re.compile(r'\d+\s*행[*\s]*vs'),              'grain 대비 서술'),
    (re.compile(r'0\s*행'),                        '논리 공집합 서술(그 조건은 구조적으로 항상 0행) — 실측치가 아니다'),
    (re.compile(r'규칙\s*\d+\s*건'),               '업무 규칙 개수 — 적재량과 무관'),
    # 🔴🔴 [2026-08-11 O59-E] **규약 상수는 실측치가 아니라 정의다.** `audit_ddl_rule7.py` 의 `WHITE` 가
    #   이미 `÷[0-9,]+` 를 예외로 두고 있었는데 **이 게이트에 전파되지 않았다**(P62-B).
    #   그 결과 `CMT_BASELINE` 이 `'10,000'` 3건을 「기지 부채」로 등재했고, §O56-D 정리 계획대로
    #   지웠다면 **정본 `(건)` = 금액÷10,000(CONF-2) 규약 자체를 COMMENT 에서 파괴**했을 것이다.
    (re.compile(r'÷\s*[\d,]+'),                    '규약 상수(정본 `(건)` = 금액÷10,000 · CONF-2) — 적재량과 무관한 정의'),
    (re.compile(r'[\d,]+\s*(?:원|건)\s*단위'),      '단위 규약 표기 — 정의'),
    # 🔴 [2026-08-11 O59-L] `÷` 뿐 아니라 **슬래시 표기**도 규약 상수다 — `06_DDL` 실측:
    #   *"정본 감액(건)(=감액금액/10,000)과 다름"*. `÷\s*[\d,]+` 만으로는 못 잡았다.
    #   ⚠️ `/[\d,]+` 로 넓히면 **분수 실측치**(`218,402/243,545 = 89.7%`)의 분모까지 면제된다 ⇒ 상수 `10,000` 만 지정한다.
    (re.compile(r'[÷/]\s*10,000\b'),               '규약 상수 CONF-2(정본 `(건)` = 금액/10,000)'),
    # 🔴 [O59-L] 「0건」은 「0행」과 같은 **논리적 부재 서술**이다 — `06_DDL` 실측:
    #   *"''중단''/''미납'' 리터럴 0건"* = 그 값이 존재하지 않는다는 구조 서술이다.
    (re.compile(r'0\s*건'),                         '논리 부재 서술(그 값이 존재하지 않는다) — 실측 규모가 아니다'),
    # 🔴 [2026-08-11 O59-M] dbt yml `columns[]`(= GOLD **뷰** 라이브 COMMENT 원천)을 같은 판정식으로 재면서
    #   드러난 오탐 2유형이다(56건 전량 · 진짜 위반 0). 두 문안 모두 **적재량과 무관한 구조·논리 서술**이다.
    #   ⚠️ 이 표면은 종전에 어느 게이트도 검사하지 않았다 — `audit_ddl_rule7` 은 `06_DDL` 만,
    #      `sv_unit_gate` 는 SV·라이브 COMMENT 만 봤다(P194 계열: 같은 규칙의 형제 표면).
    (re.compile(r'IS_CURRENT\s*1\s*건'),            'grain 서술(회원당 현재버전은 1건) — 구조이고 적재량과 무관'),
    (re.compile(r'총계\s*1\s*행'),                   '논리 서술(분해축이 없으면 결과가 총계 1행) — 실측 규모가 아니다'),
    # 🔴 [2026-08-11 O59-P] **grain 정의의 역순 표기**가 빠져 있었다. 첫 항목은 `\d+행 = …`(행이 앞)만 잡는데
    #   `06_DDL` 실측 문안은 *"회원 1명 = 1행"*(명이 앞)이라 면제를 빠져나가 `소규모:1명` 으로 잡혔다.
    #   같은 grain 정의를 **어순 때문에 다르게 판정**하던 것이므로 대칭형을 추가한다(P182 계열).
    (re.compile(r'\d+\s*명[*\s]*=\s*\d+\s*행'),      'grain 정의 역순 표기(회원 1명 = 1행) — 구조이고 적재량과 무관'),
    # 🔴🔴 [2026-08-11 O59-R] **`10,000` 유형이 2건 더 남아 있었다**(O59-E 가 4개 객체를 회수했으나 전수는 아니었다).
    #   §O56-D 정리 계획대로 아래 2건을 지웠다면 **지침·단위 규약 자체를 COMMENT 에서 파괴**했을 것이다.
    #   ⇒ 부채 대장을 비우기 전에 **토큰별로 「실측치인가 정의인가」를 판정한다**(P208).
    #   ① 임계 제안: `SV_MEMBER_COHORT` AI_SQL 의 *"하한(예: 관측 가능 회원 1,000명 이상)"* 은
    #      **소표본 1위 방지 지침의 임계 예시**이고(P76·P77 계열) 적재량이 바뀌어도 거짓이 되지 않는다.
    (re.compile(r'하한\s*\(예[^)]{0,60}\)'),          '지침 임계 예시(소표본 1위 방지 하한) — 적재량과 무관한 규약'),
    #   ② 단위 배수: `100배` 는 **퍼센트↔분수 환산 계수**다(`×100` 규약의 역방향 서술).
    #      🔴 `37.3배` 같은 실측 배수는 면제하지 않는다 — 상수 `100` 만 지정한다(O59-L 의 `/10,000` 판단과 같은 사상).
    (re.compile(r'\b100\s*배'),                       '단위 규약 배수(퍼센트↔분수 환산 ×100) — 실측 배수가 아니다'),
    # 🔴🔴 [2026-08-29 O119-B 신설 · 게이트 간 판정 불일치 7건의 정체] **같은 규칙을 두 게이트가 다르게 쟀다.**
    #   경위: `sv_unit_gate` 는 COMMENT 수치 **0건**, `sv_rule7_scan` 은 **라이브 도달 위반 7건**을 냈다.
    #     원인 = 백분율 패턴이 두 벌이다 — 이 파일의 `NUM_BAN` 은 `(?<!10)\d+\.\d+\s*%`(**소수 필수**)이고
    #     `audit_ddl_rule7.NUM` 의 「백분율」은 `[0-9]+(?:\.[0-9]+)?%`(**정수 허용** · `100%` 만 제외)다
    #     ⇒ `95%`·`0%` 가 한쪽에만 잡혔다. 🔴 **어느 쪽이 맞나가 아니라 「형태만 수치인 것」이 공유 예외에
    #     없었다**가 정답이었다(실측 7건 전부 오탐).
    #   🟢 **여기에 넣는 이유** = `sv_rule7_scan` 이 이 `NUM_EXEMPT` 를 **import 해 공유**하므로
    #     한 곳에 넣으면 두 게이트가 같은 답을 낸다. 패턴을 복제하면 다시 어긋난다(`R3-9 ㉡`).
    #   ① 신뢰구간 수준: 실측 문안 = *"95% 신뢰구간 하한 합계(만원)"*(ML 예측 SV 3종 × 상·하한 = 6건).
    #      **모델이 고정한 통계 관례**이며 적재량이 바뀌어도 95 는 95 다. 🔴 `\d+\s*%` 를 통째로 면제하지
    #      않고 **`신뢰구간` 문구와 인접할 때만** 면제한다 — 안 그러면 진짜 실측 백분율까지 무력화된다.
    (re.compile(r'\d+(?:\.\d+)?\s*%\s*신뢰구간'),      '통계 관례(신뢰구간 수준 · 모델 고정값) — 적재량과 무관'),
    #   ② `0%`: 실측 문안 = *"달성율 0% 나 무한대로 표기하지 않는다"* — **표기 규약·논리 부재 서술**이다.
    #      기존 `0행`·`0건` 면제와 **같은 사상**이고(그 둘은 이미 있었다) 백분율만 빠져 있었다.
    #      🔴 `0.5%` 같은 실측치는 면제되지 않는다 — 정수 `0` 뒤에 소수점이 오지 않는 경우만 잡는다.
    (re.compile(r'(?<![\d.])0\s*%(?!\d)'),            '논리 부재·표기 규약 서술(0%) — 실측 규모가 아니다(0행·0건과 동일 사상)'),
    # 🔴🔴 [2026-08-29 O119-B 신설 · **Agent 스펙 표면**을 분모에 넣으면서 드러난 3종] 형제 표면을 재니
    #   8건이 나왔고 **1건만 진짜**(`+18.5%` 과대율)였다. 나머지 7건은 아래 두 유형의 미면제였다.
    #   🔴 왜 지금까지 안 보였나 = 이 규칙을 **SV DDL 과 GOLD/SILVER DDL 에만** 걸어 왔고
    #     **Agent 스펙 description(= Analyst 가 읽는 또 하나의 표면)은 어느 게이트 분모에도 없었다**
    #     ⇒ `P194` 형제 표면 계열. 분모를 넓히면 예외도 함께 넓혀야 한다.
    #   ① **grain 정의의 어순 2종이 더 있었다.** 기존 면제는 `N행 = …`·`N행 grain`·`N행 vs` 뿐이라
    #      `grain=**회원 1행**`·`grain=… · 계열당 1행`(grain 이 앞) 과 `회원 1행, … grain 이다`(행이 앞,
    #      쉼표 대비)를 놓쳤다. 🔴 **`\d{1,2}` 로 자릿수를 묶는다** — 그러지 않으면
    #      *"grain 기준 적재 2,170,572행"* 같은 실측치까지 면제돼 규칙이 무력화된다(음성 테스트 축2가 이것을 지킨다).
    (re.compile(r'grain[^.。]{0,30}?(?<![\d,])\d{1,2}\s*행'),
     'grain 정의(grain 이 앞 · 계열당 1행 포함) — 구조이고 적재량과 무관'),
    (re.compile(r'(?<![\d,])\d{1,2}\s*행[^.。]{0,40}?grain'),
     'grain 대비 서술(행이 앞 · 쉼표 대비 포함) — 구조이고 적재량과 무관'),
    #   ② **단위 환산 배수 `10,000배`.** 기존 면제는 `100배`(퍼센트↔분수) 뿐이었다. 만원↔원 환산은
    #      `CONF-2` 규약 상수와 **같은 값**이며(`÷10,000` 은 이미 면제돼 있었다) 배수 표기만 빠져 있었다.
    #      🔴 실측 배수(`1.56배`·`37.3배`)는 여전히 잡힌다 — 상수 `10,000` 만 지정한다.
    (re.compile(r'\b10,000\s*배'),                     '단위 규약 배수(만원↔원 환산 · CONF-2 상수) — 실측 배수가 아니다'),
]


def scan_numbers(text):
    """COMMENT 문안에서 금지 수치 토큰을 찾아 (위반, 면제) 로 분리한다.

    면제 판정은 토큰 위치가 `NUM_EXEMPT` 매치 구간과 겹치는지로 한다 —
    같은 COMMENT 안에 grain 서술과 실측치가 함께 있어도 실측치만 남는다.
    """
    t = ' '.join(str(text).split())
    spans = [(m.start(), m.end(), why) for pat, why in NUM_EXEMPT for m in pat.finditer(t)]
    bad, exempt = set(), set()
    for m in NUM_BAN.finditer(t):
        why = next((w for a, b, w in spans if a <= m.start() and m.end() <= b), None)
        (exempt if why else bad).add(m.group(0))
    return bad, exempt


def main():
    cn = conn()
    _, svs = q(f"show semantic views in schema {SCHEMA}", cn)
    names = [r[1] for r in svs]
    viol, exempt, checked = [], [], 0
    for s in names:
        _, rows = q(f'desc semantic view {SCHEMA}.{s}', cn)
        for kind, name, parent, prop, val in rows:
            if kind != 'METRIC' or prop != 'EXPRESSION':
                continue
            if '/' not in val:
                continue
            checked += 1
            if name in NOT_RATIO:
                exempt.append(f"{s}.{name} ({NOT_RATIO[name]})")
                continue
            if not re.search(r'\*\s*100', val):
                # 이름에 비율 힌트가 없으면 「미등재 예외 후보」로 구분해 보고한다.
                hint = '비율 명명' if RATIO_HINT.search(name) else '⚠️명명상 비율 아님 — 예외 등재 검토'
                viol.append((s, name, hint, ' '.join(val.split())[:90]))
    cn.close()

    print(f"[SV 단위 게이트] SV {len(names)}종 · 나눗셈 metric {checked}개 검사")
    for e in exempt:
        print(f"  ⚪ 예외: {e}")
    for s, n, h, e in viol:
        print(f"  🔴 위반: {s}.{n}  [{h}]  {e}")
    print(f"  ⇒ 위반 {len(viol)}건 · 예외 {len(exempt)}건")

    # ── P124: DDL 파일의 상한 판정 상수 훑기 ──────────────────────────────────
    # 🔴 P114 재적용: 「판정」이라는 낱말이 들어간 **설명 문장**을 잡으면 오탐이다(최초 판이 이 파일의
    #   O52-A 경위 주석을 위반으로 잡았다). ⇒ 실제 판정 지시문 형식(`--  판정: … <= 1.0`)만 본다.
    bad_bound = []
    JUDGE = re.compile(r'(?m)^\s*--\s*판정\s*:\s*[^\n]*<=\s*1\.0')
    for f in sorted(glob.glob('/workspace/05_SV-Agent_ai/05_*_SV_DDL*.sql')):
        t = io.open(f, encoding='utf-8').read()
        for m in JUDGE.finditer(t):
            bad_bound.append(f"{os.path.basename(f)}: {m.group(0).strip()[:90]}")
    for b in bad_bound:
        print(f"  🔴 상한 판정이 1.0 (P124 — 단위 분기 흔적): {b}")

    # ── P125/P126: SV GRANT 잔존 검사 ─────────────────────────────────────────
    # 🔴🔴 실측 사고(2026-08-10 O52-B): `CREATE OR REPLACE SEMANTIC VIEW` 로 SV 2종을 재배포하고
    #   **GRANT 를 재실행하지 않아** 소비 역할이 그 SV 를 못 읽는 상태가 됐다. 문서가 3곳에서 경고하고
    #   있었고(`10_진단_원인분석.md` §129 는 **`CREATE OR ALTER` 가 GRANT 를 보존**한다는 처방까지 적어 뒀다)
    #   나는 스모크·단위·불변식만 보고 *"회귀 검증 전항 통과"* 로 보고했다.
    #   🔴 `ACCOUNTADMIN` 세션에서는 전부 성공한다 ⇒ **소유자 세션의 성공은 소비 가능성의 증거가 아니다**(P126).
    #   ⇒ 권한을 게이트 항목으로 고정한다. 판정 = 비소유 GRANT 6건(REFERENCES·SELECT × 3역할).
    ROLES = {'GN_DW_ANALYST', 'GN_DW_VIEWER', 'GN_DW_SERVICE'}
    PRIVS = {'REFERENCES', 'SELECT'}
    cn2 = conn()
    grant_bad = []
    for s in names:
        c, r = q(f"show grants on semantic view {SCHEMA}.{s}", cn2)
        ci = {x.lower(): i for i, x in enumerate(c)}
        got = {(str(row[ci['privilege']]).upper(), str(row[ci['grantee_name']]).upper())
               for row in r if str(row[ci['privilege']]).upper() != 'OWNERSHIP'}
        want = {(p, ro) for p in PRIVS for ro in ROLES}
        miss = want - got
        if miss:
            grant_bad.append((s, sorted(f"{p}→{ro}" for p, ro in miss)))
    cn2.close()
    for s, miss in grant_bad:
        print(f"  🔴 GRANT 누락: {s}  ({len(miss)}건) {'; '.join(miss)}")
    print(f"  ⇒ GRANT 검사: SV {len(names)}종 · 누락 객체 {len(grant_bad)}건")

    # ── EXPO-1: 폐기 판정된 정의식이 SV 에 노출되지 않는지 ─────────────────────
    # 🔴🔴 실측 사고(O40~O56): `SV_MEMBER_MONTHLY` 에 미납 **차감식**(`청구 − 납입`)과 DEC-3 **정본**이
    #   공존했고, 폐기된 쪽이 **접미사 없는 짧은 이름**(`UNPAID_RATIO`)을 차지하고 있었다. COMMENT 에
    #   「단독 인용 금지」를 적어 뒀지만 **경고문은 게이트가 아니다**(P105) — Agent 가 자연어 「미납비중」에
    #   짧은 이름을 골라 **−0.36% 를 사실로 답할 경로**였고, 사람도 실제로 그 이름에 속았다(P123).
    #   ⇒ 2026-08-10 O56 EXPO-1 로 제거했고, **재발을 문안이 아니라 이 게이트로 막는다.**
    #   판정 = 등재된 폐기식 패턴이 metric EXPRESSION 에 **1건도 없어야 한다**.
    #   ⚠️ 새 폐기식이 생기면 여기 등재한다(등재하지 않으면 이 게이트는 그것을 잡지 못한다).
    RETIRED_EXPR = [
        # (SV, 패턴 정규식, 왜 폐기인가 · 실측)
        ('SV_MEMBER_MONTHLY',
         re.compile(r'SUM\(\s*fmm\.BILLED_AMT\s*\)\s*-\s*SUM\(\s*fmm\.PAID_FEE\s*\)', re.I),
         '미납 차감식(청구−납입) — 분자에 섞인 기부금이 미납을 상쇄한다. 실측 전 기간 '
         '−3,218,518,220 / −0.360837% vs DEC-3 정본 122,621,758,323 / 13.747454% (O40·O56 EXPO-1 제거)'),
        # 🔴 [2026-08-10 O56-C EXPO-2] 납부율 모집단 불일치식.
        #   ⚠️ 오탐 주의: 이 패턴은 **나눗셈까지** 포함해야 한다. `SUM(fmm.PAID_FEE)` 만 보면
        #     정상 지표 `TOTAL_PAID_ALL`(= 총수납액 · 결함 아님)을 잡는다. 또 `fmm.PAID_FEE_BILLABLE` 은
        #     `PAID_FEE` 뒤에 닫는 괄호가 없어 `PAID_FEE\s*\)` 에 걸리지 않는다(정본 `PAYMENT_RATE_FEE` 보호).
        ('SV_MEMBER_MONTHLY',
         re.compile(r'SUM\(\s*fmm\.PAID_FEE\s*\)\s*/\s*NULLIF\(\s*SUM\(\s*fmm\.BILLED_AMT\s*\)', re.I),
         '납부율 모집단 불일치식 — 분자는 회비+기부금이고 분모는 회비 청구뿐이다. BRONZE 실측: 기부 원천 '
         '`TM_PM_DNTN_DTLS` 에 청구 컬럼(`RQEST_AMT`)이 **아예 없어** 분모에 들어갈 수 없다 ⇒ 비율이 '
         '구조적으로 100% 를 넘는다(전 기간 100.36% vs 회비 기준 정본 86.192258%). 정본 = `PAYMENT_RATE_FEE` '
         '(O40·O56-C EXPO-2 제거)'),
    ]
    retired_hit = []
    cn3 = conn()
    for s in names:
        _, rows3 = q(f'desc semantic view {SCHEMA}.{s}', cn3)
        for kind, name, parent, prop, val in rows3:
            if kind != 'METRIC' or prop != 'EXPRESSION':
                continue
            for sv_name, pat, why in RETIRED_EXPR:
                if sv_name == s and pat.search(val or ''):
                    retired_hit.append((s, name, why, ' '.join((val or '').split())[:80]))
    cn3.close()
    for s, n, why, e in retired_hit:
        print(f"  🔴 폐기식 노출: {s}.{n}  {e}  ▸ {why}")
    print(f"  ⇒ 폐기식 검사: 등재 패턴 {len(RETIRED_EXPR)}종 · 노출 {len(retired_hit)}건")

    # ── COMMENT 수치 금지 게이트 (05_0 COMMENT 작성 규약 (1) · 04 §6.9-(8) · 작업규칙 7) ──
    # 🔴🔴 왜 게이트인가: 이 규약은 **문안으로만 존재해서 이미 두 번 위반됐다.**
    #   ① O51-D 에서 뷰 컬럼 COMMENT 109/355 가 수치를 담아 위반(사용자 판정으로 「규칙 7 엄수」 확정 · P111)
    #   ② 2026-08-10 O56 에서 **내가 SV metric COMMENT·AI_SQL_GENERATION 에 다시 수치를 주입**했다(재발).
    #   ⇒ 경고문은 게이트가 아니다(P105) — 규약을 실행 가능한 검사로 고정한다.
    # 금지 사유(규약 원문): Agent 가 COMMENT 를 **답변 근거로 인용**하므로, 박아둔 수치는 적재량이 바뀌는
    #   순간 Agent 가 **틀린 값을 사실로 말한다**(계정 재현 시 전 수치 불일치 실측 · 04 §6.9-(8)).
    # 판정 대상 = 라이브 SV 의 COMMENT·AI_SQL_GENERATION 문안.
    # ⚠️ 보존해야 하는 것(규약 (3) 등)은 잡지 않는다 — 코드값·지표번호·절 참조·불변식 임계(100%).
    # 판정식·의미 예외는 모듈 수준 `NUM_BAN`·`NUM_EXEMPT`·`scan_numbers()` 에 있다(O59-D).
    cmt_bad = []
    # 🔴 기지 잔존 baseline (2026-08-10 O56-D 실측 · **선행 세션 유래 · 이번 세션 추가분 아님**)
    #   O51-D-D 는 *"SV COMMENT 에 박혀 있던 절대값을 05 DDL 에서 전부 제거"* 를 ✅해소로 기록했으나
    #   라이브 실측 결과 **14건이 살아 있다** — 그 완료 보고가 사실과 다르다(P137 계열: 완료 보고도 검증 대상).
    #   ⚠️ 이 baseline 은 **면제가 아니라 기지 부채 목록**이다. 정리 계획은 이슈원장 §O56-D 에 등재했다.
    #   ⇒ 게이트는 **신규 유입만 실패**시킨다(항상 빨간 게이트는 무시되어 결국 무력화된다).
    #   baseline 에 없는 조합이 나오거나 기지 조합에 **새 토큰이 추가되면** 실패한다.
    # 🔴🔴 [2026-08-11 O59-E] **부채 목록에서 오탐 4개 객체를 회수했다.** `'10,000'` 은 실측치가 아니라
    #   정본 `(건)` = 금액÷10,000(CONF-2) **규약 상수**다(라이브 5곳 전부 `÷10,000` 문맥으로 실측 확인).
    #   회수 대상 = `SV_MEMBER_EVENT` AI_SQL · 동 `DECREASE_EVENT_AMT` · `SV_MEMBER_FEE` AI_SQL · 동 `TOTAL_BILLING_ROWS`.
    #   ⇒ 토큰만 남은 2개 객체는 **키 자체를 삭제**했다(검출 0 이므로 부채가 아니다) · 기지 부채 14 → 12.
    #   🔴 이것을 못 잡으면 §O56-D 정리 작업이 **지표 정의를 지우는** 작업이 된다.
    CMT_BASELINE = {
        # 🟢🟢 [2026-08-11 O59-R] **기지 부채 12건을 전량 해소했다 — 대장을 비운다.**
        #   §O56-D 가 남긴 정리 계획을 집행했다. 처리는 토큰별로 갈렸다(P208):
        #   · **실측치 10건 = §참조로 치환**(05_1 4곳 · 05_2 3곳 · 05_9 3곳) — 값의 소재지는 이슈원장이다.
        #     대상 토큰: `8.32%p`·`14.29%`·`85.65%`·`18.5%`(4곳)·`891,959,790,888`(2곳)·
        #     `1,056,821,121,099`(2곳)·`99.99%`·`1,010,680`·`1,038,262`·`56.86%`·`2,291,878`·
        #     `3,594,843`·`13.747454%`.
        #   · **규약상수 2건 = 문안 유지 + `NUM_EXEMPT` 등재**(위 O59-R 항목) — `1,000`(하한 임계 예시)과
        #     `100배`(퍼센트↔분수 환산 계수)는 실측치가 아니다. 지웠다면 지침·단위 규약이 파괴됐다.
        #   🔴 **대장을 비우는 것이 정리의 마지막 단계다** — 항목을 남기면 「신규 유입만 실패」 규칙 때문에
        #      그 조합의 수치가 영구 면제되어 부채가 고착된다(인수인계 §미결 지시).
        #   ⇒ 이후로는 **모든 검출이 실패**다. 새 부채를 여기 등재하지 말고 문안을 고친다.
    }
    # 🟢 [2026-08-12 O62 자기검토] `cmt_known` 카운터를 제거했다 — **도달 불가 분기였다.**
    #   O59-R 이 CMT_BASELINE 을 비운 뒤로는 `base` 가 항상 공집합이라 `new = found` 가 되고,
    #   `found` 가 비면 위에서 `continue` 하므로 else 분기에 들어갈 경로가 **없다**.
    #   그런데 출력은 「기지 부채 0건(정리 계획 = 원장 §O56-D)」로 **종결된 계획을 진행 중처럼** 알렸다.
    #   ⇒ 죽은 카운터가 만든 거짓 안내다(P105 계열: 문구는 게이트가 아니고, 여기선 문구가 사실도 아니었다).
    cmt_exempt = 0
    cn4 = conn()
    for s in names:
        _, rows4 = q(f'desc semantic view {SCHEMA}.{s}', cn4)
        for kind, name, parent, prop, val in rows4:
            if prop not in ('COMMENT', 'AI_SQL_GENERATION') or not val:
                continue
            found, ex = scan_numbers(val)
            cmt_exempt += len(ex)
            if not found:
                continue
            key = (s, str(kind), str(name), prop)
            base = CMT_BASELINE.get(key, set())
            new = found - base
            if new:
                cmt_bad.append((s, f'{kind}.{name}', prop, sorted(new)))
    cn4.close()
    for s, obj, prop, found in cmt_bad:
        print(f"  🔴 COMMENT 수치 **신규 유입**: {s}.{obj} [{prop}] {', '.join(found)}")
    print(f"  ⇒ COMMENT 수치 금지 검사: SV {len(names)}종 · **검출 {len(cmt_bad)}건** · "
          f"의미 예외 {cmt_exempt}토큰 (baseline 비움 = 모든 검출이 실패 · O59-R 정리 종결)")

    # ── [2026-08-13 O68 신설] 필수 문안 존재 검사 (O67-B C1 · P227) ──────────────
    # 🔴 이 축이 없던 동안 게이트는 **금지만** 봤다 ⇒ 발행 문안이 사라져도 통과했다.
    #   판정 대상 = SV 레벨 COMMENT(`object_kind IS NULL`) + `CUSTOM_INSTRUCTION` AI_SQL.
    #   ⚠️ 라이브 형상은 실측으로 확인했다 — `SEMANTIC_VIEW` 로 거르면 **공집합**이 되어
    #      「전건 누락」이라는 반대 방향 오판이 난다(O68 착수 중 자기적발).
    req_bad = []
    cn5 = conn()
    for s in names:
        _, rows5 = q(f'desc semantic view {SCHEMA}.{s}', cn5)
        blob = ' '.join(
            str(v) for k, n, par, p, v in rows5
            if v and ((k is None and p == 'COMMENT') or (k == 'CUSTOM_INSTRUCTION' and p == 'AI_SQL_GENERATION'))
        )
        miss = scan_required(s, blob)
        if miss:
            req_bad.append((s, miss))
    cn5.close()
    for s, miss in req_bad:
        print(f"  🔴 필수 문안 소실: {s}  ({len(miss)}건) {', '.join(miss)}")
    print(f"  ⇒ 필수 문안 검사: 등재 SV {len(REQUIRED_TEXT)}종 · 토큰 "
          f"{sum(len(v) for v in REQUIRED_TEXT.values())}개 · 소실 {len(req_bad)}건")

    fail = len(viol) + len(bad_bound) + len(grant_bad) + len(retired_hit) + len(cmt_bad) + len(req_bad)
    print("\n" + ("🔴 게이트 실패" if fail else
                  "✅ 게이트 통과 — 비율 metric 전량 percent · GRANT 전량 정상 · 폐기식 노출 0 · "
                  "COMMENT 수치 0 · 필수 문안 전량 존재"))
    return 1 if fail else 0


def self_check():
    """DB 접속 없이 `scan_numbers()` 를 양성·음성 대조군으로 검사한다.

    🔴 **P177**: 오탐 대조군(음성)을 양성 이상으로 둔다 — O59-D 착수 시 신규 유입 17건 중
       **진짜는 2건**이고 15건이 오탐이었다(grain 정의 6 · 논리 공집합 8 · 업무 규칙 개수 1).
       오탐이 진짜를 덮으면 게이트는 「빨간 채로 무시」되어 무력화되고, 나아가 **baseline 객체에
       오탐 토큰이 붙어 기지 부채 대장까지 흐린다**(집계가 14 → 11 로 줄었다).
    문안은 **라이브 SV COMMENT 실측 발췌**를 쓴다(가공 예제가 아니라 실제로 게이트가 만난 문안).
    🔴 [2026-08-11 O59-E] **판정을 부분문자열 → 정확 집합 일치로 바꿨다.** 종전 판정은
       `'1행' in ' '.join(검출토큰)` 이었는데 **`'1행'` 은 `'421행'` 의 부분문자열**이므로
       엉뚱한 토큰만 잡혀도 통과했다 — 자기검사가 **거짓 통과**할 수 있었다(P106 계열).
    """
    POS = [  # (문안, 검출 토큰이 **정확히** 이 집합이어야 한다)
        ("실제값 16종: '`'(🔴 오염값 — 백틱 1문자 1행 · 정상 CM 위치가 아니다)", {'1행'}),
        ("실제값 8종 (+미기재 NULL 421행)", {'421행'}),
        ("sentinel '0'은 개발·증감 원천(CRM_MEMBER_DEV 9행·CRM_MEMBER_AMT_CHANGE 1행)에만 있다", {'9행', '1행'}),
        ("전 기간 미납 122,621,758,323 / 13.747454%", {'122,621,758,323', '13.747454%'}),
        ("직접 조인하면 4.49배 팬아웃한다", {'4.49배'}),
        ("커버리지 96.79% 이며 격차는 2.3%p 다", {'96.79%', '2.3%p'}),   # 🔴 `%p` 도달성 회귀 고정
        ("회비 단가는 15000원 이고 대상은 53건 · 12명 이다", {'15000원', '53건', '12명'}),
        ("실적재 20종 중 6종(366행)이 폐지코드다", {'366행'}),            # 🔴 `06_DDL` 실측 위반 문안(O59-E)
    ]
    NEG = [  # 하나라도 잡으면 오탐 — 적재량과 무관한 문안
        "회원 획득 코호트 SV(base FMC, 회원 grain 1행=1회원)",
        "회원 상태전이 사건 팩트. 1행=1개발/중단 사건.",
        "이 SV 는 회원×월 1행 grain 이라 그 축들이 없다",
        "이 팩트(FMM)는 **회원×월 정확히 1행** grain 이라 후원사업을 붙이면 grain 이 깨진다",  # 마크다운 강조 끼임
        "grain 이 회원 1행 vs 회비 상세 행이다",
        "상태 코드번호를 라벨 앞에 붙인 형태로 필터하면 0행 무증상 오답이다",
        "sentinel '0'은 개발·증감 원천에만 존재하므로 '0' 조건은 0행",
        "해소 경로는 원천 입고가 아니라 현업 배분 규칙 1건 이다",
        "미납중단(명) — 05 2-2 원천 확인(정본 §3 건·명)",                  # 🔴 절 참조 `§3`+`건` 오탐(O59-E)
        "감액(건) = 금액 ÷ 10,000 으로 산출한다 · 공#38 건 기준",           # 🔴 지표번호 `#38`+`건` 오탐
        "불변식: 납부율은 100% 를 넘지 않는다",                             # 100% 임계는 보존
        "개발구분(정본 MM015). 실제값 5종: '신규'·'증액'·'감액'·'재후원'·'후원중단'",   # 코드값·N종은 보존
        "성별 원천코드(CM013) · 지표번호 공64·#69·70 · 경위는 원장 §O59-C",  # 코드·지표번호·절 참조
    ]
    # 🔴 **천단위 분할 금지 대조군** — 수치 자체는 잡아야 하지만(기지 부채) **쪼갠 토큰은 안 된다.**
    #   쪼개면 baseline 키와 어긋나 기지 부채가 「신규 유입」으로 되살아난다(O59-D 오탐 3건의 정체).
    NOSPLIT = [
        ("'후원중단'(1,010,680건)은 EVENT_TYPE='STOP'(1,038,262건)과 동일 사건이다",
         {'680건', '262건'}, {'1,010,680', '1,038,262'}),
        ("관측 가능 회원 1,000명 이상을 적용했음을 밝힌다", {'000명'}, {'1,000'}),
    ]
    fails = []
    for text, want in POS:
        bad, _ = scan_numbers(text)
        if bad != want:
            fails.append(f"  🔴 양성 불일치: want {sorted(want)} · got {sorted(bad)} ▸ {text[:60]}")
    for text in NEG:
        bad, _ = scan_numbers(text)
        if bad:
            fails.append(f"  🔴 오탐: {sorted(bad)} ▸ {text[:60]}")
    for text, forbid, want in NOSPLIT:
        bad, _ = scan_numbers(text)
        if bad & forbid:
            fails.append(f"  🔴 천단위 분할 오탐: {sorted(bad & forbid)} ▸ {text[:60]}")
        if not want <= bad:
            fails.append(f"  🔴 원 수치 미검출: want {sorted(want)} · got {sorted(bad)} ▸ {text[:60]}")

    # ── [2026-08-13 O68 신설] 필수 문안 축 자기검사 (P106 — 음성 샘플을 먼저 통과시킨다) ──
    sv0 = 'SV_MEMBER_MONTHLY'
    full = ' '.join(REQUIRED_TEXT[sv0]) + ' 그 밖의 문안'
    req_cases = [
        ('ⓞ 전량 존재하면 통과(음성 샘플)', scan_required(sv0, full) == []),
        ('ⓐ 토큰 1개 소실 검출', scan_required(sv0, full.replace('앵커_경합', '')) == ['앵커_경합']),
        ('ⓑ 문안 전체 소실 검출(전건 보고)', scan_required(sv0, '') == REQUIRED_TEXT[sv0]),
        ('ⓒ 미등재 SV 는 검사 대상이 아니다(오탐 0)', scan_required('SV_BUDGET', '') == []),
        # 🔴 공백·개행 정규화 회귀 고정 — 이번 접기로 라이브 값에 **개행이 들어간다**.
        #   정규화하지 않으면 토큰이 개행에 걸쳐 있을 때 조용히 「소실」로 보고된다.
        ('ⓓ 개행이 섞여도 검출된다(접기 회귀 고정)',
         scan_required(sv0, '\n'.join(REQUIRED_TEXT[sv0])) == []),
    ]
    for n, ok in req_cases:
        if not ok:
            fails.append(f'  🔴 필수 문안 축 자기검사 실패: {n}')

    print(f"[sv_unit_gate 자기검사] 양성 {len(POS)} · 음성 {len(NEG)} · 분할금지 {len(NOSPLIT)} · "
          f"필수문안 {len(req_cases)} "
          f"(오탐 대조군 {len(NEG) + len(NOSPLIT)} ≥ 양성 {len(POS)} · P177)")
    for f in fails:
        print(f)
    print("\n" + ("🔴 자기검사 실패" if fails else
                  f"✅ 자기검사 통과 — 양성 {len(POS)}/{len(POS)} 검출 · "
                  f"음성 {len(NEG)}/{len(NEG)} 오탐 0 · 분할금지 {len(NOSPLIT)}/{len(NOSPLIT)} · "
                  f"필수문안 {len(req_cases)}/{len(req_cases)}"))
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(self_check() if '--self-check' in sys.argv else main())
