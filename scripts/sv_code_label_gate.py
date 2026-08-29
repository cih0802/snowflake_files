# -*- coding: utf-8 -*-
"""[2026-08-11 O59] Semantic View **코드값·라벨축 게이트** — DEC-35 R1~R5 상시 감시.

🔴 왜 필요한가(실측 경위 · 원장 §O58-C):
   SV COMMENT 가 **실재하지 않는 코드값을 열거**하고 있었다 — `SV_SERVICE.CHANNEL` 이 `CRM_UMS`/`ADMIN`
   「등」을 적었으나 실제값은 `MSG_AT`·`SND`·`EMAIL`·`PSTMTR`·`(미매핑)` 5종이었고,
   `MEMBER_STATUS_NAME` 은 라벨에 숫자 접두가 붙는다고 적었으나 접두가 없었다.
   SV COMMENT 는 **Cortex Analyst 의 프롬프트 context** 이므로 이런 문안은
   `WHERE dim = '없는값'` 을 생성시켜 **0행을 반환하는 무증상 오답**이 된다(AD-4/P19 유형).
   에러도 경고도 나지 않으므로 어떤 기존 게이트도 잡지 못했다.

🔴 그 4건은 **손으로** 찾았다. 기존 게이트의 한계:
   · `eval_expectation_gate.py` DIMNAME = **차원 이름의 실존**만 본다(코드값은 안 본다).
   · `sv_unit_gate.py` = 단위·GRANT·폐기식·COMMENT 수치를 본다(코드값은 안 본다).
   ⇒ 코드값 실존을 보는 게이트가 **없었다**. 미점검 SV 에 같은 유형이 남아 있다.

검사 3종 (DEC-35 §23-C R1~R5 / §23-D 4단계 종료 게이트)
  ① **코드값 실존** — COMMENT 가 열거한 값이 backing 컬럼의 실제 distinct 에 있는가.
       · 없으면 🔴 **위반**(0행 무증상 오답 경로).
       · COMMENT 가 「실제값 N종」을 선언했는데 실제 종수와 다르면 🔴 **위반**(열거 누락/과잉).
         ⚠️ 종수 선언이 없는 문안은 이 검사를 하지 않는다 — 안 적은 것을 결손으로 보면 오탐이다.
  ② **라벨축 노출**(R1) — 라벨 컬럼이 base 에 실재하는데 SV 가 **코드축만** 노출했는가.
       🔴 판정을 **정규식으로 하지 않는다.** 이 프로젝트의 라벨 네이밍은 최소 4패턴이고
       (`MBER_STAT_CD`→`MEMBER_STATUS_NAME` · `AREA_CD`→`REGION` · `ACQ_AGE_CD`→`ACQ_AGE_BAND` ·
        `JOIN_PATH_CD`→`ENROLL_PATH_NAME`) 정규식 대조는 오탐한다(원장 §O58-D 실측).
       ⇒ **명시 등재부 `LABEL_PAIRS`** 로만 판정한다. 미등재 코드컬럼은 위반이 아니라 **정보**로 보고한다.
  ③ **폐기 리터럴 노출**(R5 · P174) — 교정 문안에 폐기값을 다시 인용하면 새 부채가 된다.
       COMMENT 는 코드 주석과 달리 **LLM 입력**이므로 부정문이라도 그 문자열이 context 에 들어간다.

사용법
  python3 scripts/sv_code_label_gate.py              # 라이브 판정
  python3 scripts/sv_code_label_gate.py --self-check # 탐지력 자기검사(P106 · 라이브 미접속)
"""
import sys, re, os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

SCHEMA_DB, SCHEMA_SC = 'GN_DW', 'SERVING'

# ── 라벨 짝 등재부 ────────────────────────────────────────────────────────────
# 키 = base 코드 컬럼명 · 값 = 같은 base 테이블의 라벨 컬럼명.
# 🔴 정규식으로 유도하지 않는다(위 ② 참조). 새 코드축을 노출하면 여기 등재한다 —
#    등재하지 않으면 게이트가 「미등재」로 보고하므로 침묵하지 않는다(P16: 오탐이 미탐보다 안전).
LABEL_PAIRS = {
    'MBER_STAT_CD':    'MEMBER_STATUS_NAME',
    'MBER_DIV_CD':     'MEMBER_TYPE_NAME',
    'JOIN_PATH_CD':    'ENROLL_PATH_NAME',
    'AREA_CD':         'REGION',
    'AGE':             'AGE_BAND',
    'SEX':             'GENDER_NAME',
    'ACQ_AGE_CD':      'ACQ_AGE_BAND',
    'ACQ_AREA_CD':     'ACQ_REGION',
    'ACQ_SEX_CD':      'ACQ_GENDER',
    'ACQ_DVLP_DIV_CD': 'ACQ_DVLP_DIV_NM',
    'DVLP_DIV_CD':     'DVLP_DIV_NM',
    'EVENT_KIND':      'EVENT_KIND_NAME',
    'FEE_DIV_CD':      'FEE_DIV',
    'SETLE_CD':        'PAYMENT_METHOD',
    # 🟢🟢 [2026-08-11 O59-R] **DEC-35 1·2단계로 라벨 컬럼이 실재하게 됐다 — `None` 을 실명으로 교체한다.**
    #   🔴 왜 중요한가: 종전 `None` 은 「짝이 없음을 확인했다」는 **단정**이라 게이트가
    #      *"라벨 컬럼 부재 확인됨"* 이라는 **거짓 정보**를 출력하고 있었다(라이브에는 컬럼이 있었다).
    #      O59-N 이 GOLD 에 컬럼을 만들면서 이 등재부를 같은 커밋에서 갱신하지 않은 결과다 ⇒ **P149 재발**.
    #      등재부가 stale 이면 검사 ②(라벨축 미노출)가 **대상에서 빠져 침묵**한다 — 미탐이다.
    'SEND_STATUS':     'SEND_STATUS_NAME',
    'SEND_RESULT_CD':  'SEND_RESULT_NAME',
    'EVENT_CATEGORY':  'EVENT_CATEGORY_NAME',
    'PART_STATUS':     'PART_STATUS_NAME',
    'PART_PATH':       'PART_PATH_NAME',
    'PART_CHANNEL':    'PART_CHANNEL_NAME',
    # 🔴 `SUBTYPE` 만 `None` 을 유지한다 — 라벨을 **의도적으로 만들지 않았다**(등급 D).
    #   채널별 다체계라 코드군을 배타 특정할 수 없어 `CRM_CODE` 에서 가져올 라벨 문자열이 없다.
    #   추정 라벨을 붙이면 라벨 창작이다(DEC-17-B) ⇒ 현업 확인 대기(문서20 §M-2 · 등재부 §5).
    'SUBTYPE':         None,
}

# ── 폐기 리터럴 등재부 (R5 · P174) ───────────────────────────────────────────
# 🔴 폐기값을 새로 만들면 **그 세션에** 여기 등재한다. 등재하지 않으면 다음 세션이 정답으로 되살린다.
RETIRED_LITERALS = [
    ('CRM_UMS',   "SV_SERVICE.CHANNEL 의 폐기 열거값 — 실제값에 없다(O58-C)"),
    ('ADMIN',     "SV_SERVICE.CHANNEL 의 폐기 열거값 — 실제값에 없다(O58-C)"),
    ('1활동회원', "MEMBER_STATUS_NAME 의 폐기 표기 — 라벨에 숫자 접두가 없다(O58-C)"),
]

# 열거 구간 = 「실제값 … :」 뒤의 **연속 열거 블록만**. 🔴 문안 전체도, 문장 끝까지도 긁지 않는다.
#   · 1판: 문안 전체 인용부호 → **오탐 35건이 진짜 1건을 덮었다**(`SV_AD.DEVICE_TYPE` 이 묻혔다).
#   · 2판: 콜론 뒤 문장 끝까지 → 같은 줄에 이어지는 **라벨축 안내**(`라벨은 … 축('일반행사'·'캠페인행사')`)와
#          설명 인용(`'왜 10대 미만이 많은가'`)까지 삼켰다 ⇒ 오탐 21건.
#   · 3판(현행): 콜론 직후부터 `'값'` 이 구분자(`·`,`,`)로 **끊기지 않고 이어지는 동안만** 취한다.
#          열거가 끝나는 지점에서 멈추므로 뒤따르는 산문은 구조적으로 들어올 수 없다.
#   ⚠️ 대가 = 규약(`실제값 N종: 'a'·'b'…`)을 벗어난 문안은 검사 대상 밖(미탐)이다 → DEC-35 R3 로 덮는다.
# ⚠️ 규약 변형을 흡수한다 — 실측 문안에 `실제값:`·`실제값 N종:`·**`실제 코드값:`**·`실제값 계열:`·`실제값 예:`
#    가 모두 쓰인다. 3판 초판이 `실제값` 만 봐서 `SV_AD.DEVICE_TYPE`(`실제 코드값:`)을 **검사조차 하지 않았다**.
COLON = re.compile(r'실제\s*(?:코드\s*)?값[^:：]{0,20}[:：]')
# 연속 열거 1항: 앞선 구분자(선택) + 인용값 + 뒤따르는 `=라벨`(선택).
#   ⚠️ `=라벨` 소비는 **문장부호·이모지에서 멈춘다** — 안 멈추면 `'(unknown)'=매핑 실패 센티넬. ⚠필터 시 'MOBILE'`
#      에서 라벨을 삼키고 넘어가 `'MOBILE'` 을 열거로 오인한다(부정문을 위반으로 잡는 P114 유형).
ITEM = re.compile(r"\s*(?:[·,+]|및|또는)?\s*'([^']{1,40})'(?:\s*=\s*[^'·,\n.。⚠🔴🟢·]{0,40})?")
# 「실제값 N종」 종수 선언
CNT = re.compile(r'실제값\s*(\d+)\s*종')
# 범위 표기 `'1'~'12'`
RANGE = re.compile(r"\s*(?:[·,+]|및|또는)?\s*'(\d+)'\s*~\s*'(\d+)'")


def enumerated_values(comment, dim_col):
    """COMMENT 의 「실제값 …:」 **직후 연속 열거 블록**에서만 코드값을 뽑는다."""
    if not comment:
        return set(), None
    txt = str(comment)
    vals = set()
    for m0 in COLON.finditer(txt):
        pos = m0.end()
        while True:
            mr = RANGE.match(txt, pos)          # 범위 표기 우선(`'1'~'12'`)
            if mr:
                ia, ib = int(mr.group(1)), int(mr.group(2))
                if 0 <= ia <= ib <= 999:
                    vals |= {str(i) for i in range(ia, ib + 1)}
                pos = mr.end()
                continue
            mi = ITEM.match(txt, pos)
            if not mi:
                break                            # 🔴 열거가 끊기면 즉시 멈춘다(산문 유입 차단)
            vals.add(mi.group(1))
            pos = mi.end()
    m = CNT.search(txt)
    return vals, (int(m.group(1)) if m else None)


# ── ④ 열거 누락 검사 대상 판정 (§6.9-(5)) ────────────────────────────────────
# 🔴 §6.9-(5) 는 *"**저카디널리티** 코드 차원은 comment에 실제 코드값을 열거해야 한다"* 인데
#    「저카디널리티」의 임계가 문서에 없다. **추측하지 않고 분포를 실측해 정했다**
#    (`scripts/sv_dim_cardinality.py` · 2026-08-11 O59-B).
#
# 실측 근거:
#   · distinct ≤ 20 · **VARCHAR 한정** ⇒ 대상 45개(열거 없음). 임계를 50·111 로 올려도 추가분은
#     대부분 명칭·경로 축이고, 20 아래에 코드/라벨 축이 전부 들어온다.
#   · **BOOLEAN 제외** — `HAS_BILLING`·`UNPAID_FLAG`·`HAS_POSITIVE_GOAL` 등은 TRUE/FALSE 자명하다.
#   · **NUMBER 제외** — 실측상 저카디널리티 NUMBER 축은 `CAL_QUARTER`(4)·`CAL_MONTH`(12) = **시간축**뿐이고
#     자기설명적이다. 코드 성격 NUMBER 축이 새로 생기면 아래 `ENUM_FORCE` 에 등재한다.
#   · **DATE 제외** — 자명하며 카디널리티도 크다.
ENUM_CARD_MAX = 20
# 임계를 넘지만 코드 성격이라 반드시 열거해야 하는 축(수동 등재).
ENUM_FORCE = set()
# 임계 아래지만 열거가 무의미한 축(수동 등재 — 자기설명적이거나 자유 텍스트).
#   · `DEVICE_SCOPE_DESC` = **코드 차원이 아니라 설명문 차원**이다. 값 자체가
#     *"방송광고(TV·재방송) — 기기 개념 없음"* 같은 문장이고, 필터 대상 코드축은 짝인
#     `DEVICE_TYPE`(4종)이며 그쪽은 이미 열거를 갖고 있다. 서술문을 열거하면 context 만 먹는다.
#     (부수 근거: 값에 `·` 가 들어 있어 열거 구분자와 충돌한다.)
ENUM_SKIP = {'DEVICE_SCOPE_DESC'}


def is_enum_target(data_type, cardinality, base_col):
    """이 차원이 §6.9-(5)「실제 코드값 열거」 의무 대상인가."""
    if base_col in ENUM_SKIP:
        return False
    if base_col in ENUM_FORCE:
        return True
    if cardinality is None or cardinality <= 0:
        return False
    if not str(data_type).upper().startswith(('VARCHAR', 'CHAR', 'TEXT', 'STRING')):
        return False
    return cardinality <= ENUM_CARD_MAX


def judge(dims, distinct_map, base_cols, exposed, card=None, dtype=None):
    """순수 판정 함수 — 라이브·fixture 양쪽에서 같은 코드로 돈다(자기검사 가능성의 전제).

    dims        : [(sv, lt, dim, base_table, base_col, comment)]
    distinct_map: {(base_table, base_col): set(실제 distinct 문자열)}  · None = 미조회
    base_cols   : {base_table: set(컬럼명)}
    exposed     : {(sv, base_table): set(그 SV 가 노출한 base 컬럼명)}
    card/dtype  : {(base_table, base_col): distinct 종수 / DATA_TYPE} — ④ 검사용(없으면 ④ 건너뜀)
    """
    card = card or {}
    dtype = dtype or {}
    v_ghost, v_count, v_label, v_retired, v_enum, info = [], [], [], [], [], []
    for sv, lt, dim, bt, bc, cmt in dims:
        actual = distinct_map.get((bt, bc))
        vals, declared = enumerated_values(cmt, bc)

        # ① 코드값 실존
        #   🔴 NULL(빈 문자열로 표현) 은 **종수에서 제외**한다 — 문안의 「실제값 N종」은 NULL 제외 종수다.
        #   최초 판이 NULL 을 포함해 세서 **28건 전부 +1 오차**로 오탐했다(내 버그 · 즉시 교정).
        #   NULL 자체의 고지 여부는 이 검사의 축이 아니다(문안 규약 R3 소관).
        actual_nn = None if actual is None else {v for v in actual if v != ''}
        if actual_nn is not None and vals:
            ghost = sorted(v for v in vals if v not in actual_nn)
            if ghost:
                v_ghost.append((sv, dim, ghost, sorted(actual_nn)[:8]))
        if actual_nn is not None and declared is not None and declared != len(actual_nn):
            v_count.append((sv, dim, declared, len(actual_nn)))

        # ④ 열거 누락 (§6.9-(5)) — 저카디널리티 코드 차원인데 열거가 **아예 없다**
        #   🔴 ① 과 다른 결함이다. ① 은 「적힌 값이 틀렸다」, ④ 는 「안 적혀서 Analyst 가 값을 추측한다」.
        #      추측 결과도 결국 `WHERE dim='없는값'` = 0행 무증상 오답이다(§6.9-(5) 의 원래 사고 원인).
        if (card or dtype) and not vals and declared is None:
            if is_enum_target(dtype.get((bt, bc), ''), card.get((bt, bc)), bc):
                v_enum.append((sv, dim, bc, card.get((bt, bc)),
                               sorted(actual_nn)[:6] if actual_nn else []))

        # ② 라벨축 노출 (R1)
        if bc in LABEL_PAIRS:
            lab = LABEL_PAIRS[bc]
            if lab:
                if lab in base_cols.get(bt, set()) and lab not in exposed.get((sv, bt), set()):
                    v_label.append((sv, dim, bc, lab))
            else:
                info.append(f"{sv}.{dim}: 라벨 컬럼 부재 확인됨({bc}) — DEC-35 1~2단계 대상")
        elif bc.endswith('_CD') or bc in ('SEX', 'AGE'):
            info.append(f"{sv}.{dim}: 코드축인데 LABEL_PAIRS 미등재({bc}) — 등재 필요")

        # ③ 폐기 리터럴 (R5)
        if cmt:
            for lit, why in RETIRED_LITERALS:
                if lit in str(cmt):
                    v_retired.append((sv, dim, lit, why))
    return v_ghost, v_count, v_label, v_retired, v_enum, info


def load_live():
    from sfconn import conn, q
    cn = conn()
    _, tabs = q(f"""select SEMANTIC_VIEW_NAME, NAME, BASE_TABLE_SCHEMA, BASE_TABLE_NAME
                    from {SCHEMA_DB}.INFORMATION_SCHEMA.SEMANTIC_TABLES
                    where SEMANTIC_VIEW_SCHEMA='{SCHEMA_SC}'""", cn)
    base_of = {(r[0], r[1]): f"{r[2]}.{r[3]}" for r in tabs}
    _, drows = q(f"""select SEMANTIC_VIEW_NAME, TABLE_NAME, NAME, EXPRESSION, COMMENT, DATA_TYPE
                     from {SCHEMA_DB}.INFORMATION_SCHEMA.SEMANTIC_DIMENSIONS
                     where SEMANTIC_VIEW_SCHEMA='{SCHEMA_SC}'""", cn)
    dims, exposed, dtype = [], {}, {}
    for sv, lt, dim, expr, cmt, dt in drows:
        bt = base_of.get((sv, lt))
        if not bt:
            continue
        # EXPRESSION = `alias.COLUMN` (별칭 = 논리테이블명 소문자). 식(함수·연산)이면 컬럼 특정 불가.
        m = re.fullmatch(r'\s*([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\s*', str(expr or ''))
        if not m:
            continue
        bc = m.group(2).upper()
        dims.append((sv, lt, dim, bt, bc, cmt))
        dtype[(bt, bc)] = str(dt or '')
        exposed.setdefault((sv, bt), set()).add(bc)

    base_cols = {}
    for bt in sorted({d[3] for d in dims}):
        sc, tb = bt.split('.', 1)
        _, cols = q(f"""select COLUMN_NAME from {SCHEMA_DB}.INFORMATION_SCHEMA.COLUMNS
                        where TABLE_SCHEMA='{sc}' and TABLE_NAME='{tb}'""", cn)
        base_cols[bt] = {r[0].upper() for r in cols}

    # ── 카디널리티 1패스 측정 ──────────────────────────────────────────────
    # 🔴 컬럼당 쿼리(160회) 대신 **테이블당 1회**로 전 컬럼 distinct 를 구한다.
    #    ④ 열거 누락 검사의 대상 판정(저카디널리티 여부)에 카디널리티가 필요하다.
    card = {}
    by_table = {}
    for bt, bc in sorted({(d[3], d[4]) for d in dims}):
        by_table.setdefault(bt, []).append(bc)
    for bt, cols in sorted(by_table.items()):
        sel = ', '.join(f'count(distinct "{c}") as "{c}"' for c in cols)
        try:
            cout, rws = q(f'select {sel} from {SCHEMA_DB}.{bt}', cn)
        except Exception as e:
            print(f"  ⚪ 카디널리티 측정 불가 {bt}: {str(e)[:60]}")
            continue
        for name, val in zip(cout, rws[0]):
            card[(bt, name.upper())] = int(val)

    # distinct 값 집합은 **필요한 것만** 조회한다.
    #   ㉮ COMMENT 가 값을 열거·선언한 축(① 검사용)
    #   ㉯ 열거 누락 검사 대상 축(④ 검사용 — 실제값을 알아야 위반 내역에 실측을 붙일 수 있다)
    distinct_map = {}
    need = set()
    for sv, lt, dim, bt, bc, cmt in dims:
        vals, declared = enumerated_values(cmt, bc)
        if vals or declared is not None:
            need.add((bt, bc))
        elif is_enum_target(dtype.get((bt, bc), ''), card.get((bt, bc)), bc):
            need.add((bt, bc))
    for bt, bc in sorted(need):
        try:
            _, r = q(f'select distinct "{bc}" from {SCHEMA_DB}.{bt} limit 500', cn)
        except Exception as e:                      # 컬럼 부재·권한 등은 판정 대상이 아니다
            print(f"  ⚪ distinct 조회 불가 {bt}.{bc}: {str(e)[:60]}")
            continue
        distinct_map[(bt, bc)] = {('' if x[0] is None else str(x[0])) for x in r}
    cn.close()
    return dims, distinct_map, base_cols, exposed, card, dtype


def fixtures():
    """탐지력 자기검사용 합성 입력 — 양성 4 · 음성 3(오탐 대조군)."""
    bt = 'GOLD.FACT_SERVICE_EVENT'
    bt2 = 'GOLD.DIM_MEMBER_CURRENT'
    bt3 = 'GOLD.DIM_DEVICE'
    bt4 = 'GOLD.DIM_DATE'
    base_cols = {bt: {'SEND_STATUS', 'SEND_TYPE', 'HAS_BILLING'},
                 bt2: {'MBER_STAT_CD', 'MEMBER_STATUS_NAME'},
                 bt3: {'DEVICE_TYPE'},
                 bt4: {'QUARTER'}}
    distinct_map = {(bt, 'SEND_STATUS'): {'0', '1', '2', '3', '4', 'Y', 'N', ''},
                    (bt2, 'MBER_STAT_CD'): {str(i) for i in range(1, 13)} | {''},
                    (bt3, 'DEVICE_TYPE'): {'M', 'PC', '(해당없음)', '(unknown)'},
                    (bt, 'SEND_TYPE'): {'EMAIL', 'MSG_AT', 'PSTMTR', 'SND'},
                    (bt, 'HAS_BILLING'): {'True', 'False'},
                    (bt4, 'QUARTER'): {'1', '2', '3', '4'}}
    card = {(bt, 'SEND_STATUS'): 7, (bt2, 'MBER_STAT_CD'): 12,
            (bt3, 'DEVICE_TYPE'): 4, (bt, 'SEND_TYPE'): 4,
            (bt, 'HAS_BILLING'): 2, (bt4, 'QUARTER'): 4}
    dtype = {(bt, 'SEND_STATUS'): 'VARCHAR(16777216)', (bt2, 'MBER_STAT_CD'): 'VARCHAR(16777216)',
             (bt3, 'DEVICE_TYPE'): 'VARCHAR(16777216)', (bt, 'SEND_TYPE'): 'VARCHAR(16777216)',
             (bt, 'HAS_BILLING'): 'BOOLEAN', (bt4, 'QUARTER'): 'NUMBER(1,0)'}
    dims = [
        # 양성① 없는 코드값 열거
        ('ZZ_POS1', 'FSE', 'SEND_STATUS', bt, 'SEND_STATUS',
         "발송 상태. 실제값: '0'·'1'·'9'"),
        # 양성② 종수 선언 불일치 (선언 3 vs 실제 9)
        ('ZZ_POS2', 'FSE', 'SEND_STATUS', bt, 'SEND_STATUS',
         "발송 상태. 실제값 3종: '0'·'1'·'2'"),
        # 양성③ 라벨 컬럼이 있는데 코드축만 노출
        ('ZZ_POS3', 'MEMBER', 'MBER_STAT_CD', bt2, 'MBER_STAT_CD', "회원상태 원천코드"),
        # 양성④ 폐기 리터럴 인용
        ('ZZ_POS4', 'FSE', 'SEND_STATUS', bt, 'SEND_STATUS',
         "종전에 'CRM_UMS' 라고 적혀 있었다"),
        # 음성① 정확한 열거 + 정확한 종수 (NULL 은 종수에서 제외되므로 7종)
        ('ZZ_NEG1', 'FSE', 'SEND_STATUS', bt, 'SEND_STATUS',
         "발송 상태. 실제값 7종: '0'·'1'·'2'·'3'·'4'·'Y'·'N'"),
        # 음성② 🔴 **최초 판이 실제로 오탐한 케이스** — 산문 속 인용은 열거가 아니다.
        #   `'왜 10대 미만이 많은가'`·`'현재 연령별'` 류가 전부 「없는 코드값」으로 잡혀
        #   오탐 35건이 진짜 1건(`SV_AD.DEVICE_TYPE`)을 덮었다. 그 회귀를 여기 고정한다.
        ('ZZ_NEG2', 'FSE', 'SEND_STATUS', bt, 'SEND_STATUS',
         "발송 상태. 현업이 '왜 실패가 많은가' 를 물으면 '현재 채널별' 로 답하지 말 것. "
         "SEND_TYPE='EMAIL' 인 행만 값을 갖는다. 실제값 7종: '0'·'1'·'2'·'3'·'4'·'Y'·'N'"),
        # 음성③ 라벨축을 함께 노출한 SV
        ('ZZ_NEG3', 'MEMBER', 'MBER_STAT_CD', bt2, 'MBER_STAT_CD', "회원상태 원천코드"),
        # 음성④ 🔴 **최초 판 오탐 2** — 라벨축을 안내하는 문장의 라벨값을 코드축 열거로 잡았다
        #   (`EVENT_KIND` COMMENT 가 *"라벨은 EVENT_KIND_NAME 축('일반행사'·'캠페인행사')"* 라고 안내).
        ('ZZ_NEG4', 'FSE', 'SEND_STATUS', bt, 'SEND_STATUS',
         "발송 상태 코드. 사람이 읽는 라벨은 SEND_STATUS_NAME 축을 쓴다('발송완료'·'에러'·'예약취소')"),
        # 음성⑤ NULL 이 있어도 종수 선언은 NULL 제외 기준이다(내 +1 버그 회귀 고정)
        ('ZZ_NEG5', 'MEMBER', 'MBER_STAT_CD', bt2, 'MBER_STAT_CD',
         "회원상태 원천코드. 실제값 12종: '1'~'12' + NULL(일시회원)"),
        # 음성⑥ 🔴 **2판 오탐의 정확한 형태** — 열거 **뒤에** 라벨축 안내·설명 인용이 이어진다.
        #   2판은 콜론 뒤 문장 끝까지 긁어 '발송완료'·'왜 실패가 많은가' 까지 코드값으로 삼았다.
        #   3판은 열거가 끊기는 지점(`. `)에서 멈춘다 — 이 케이스가 그 회귀를 고정한다.
        ('ZZ_NEG6', 'FSE', 'SEND_STATUS', bt, 'SEND_STATUS',
         "발송 상태. 실제값 7종: '0'·'1'·'2'·'3'·'4'·'Y'·'N'. 사람이 읽는 라벨은 "
         "SEND_STATUS_NAME 축('발송완료'·'에러'·'예약취소')을 쓴다. 현업이 '왜 실패가 많은가' 를 "
         "물으면 채널을 함께 제시한다"),
        # 음성⑦ 🔴 **`'값'=라벨` 형식 + 부정문 경고**(= `SV_AD.DEVICE_TYPE` 실제 문안 형태).
        #   1판은 부정문의 'MOBILE'/'TABLET' 을 위반으로 오탐했고(P114 유형),
        #   3판 초판은 `실제 코드값:` 을 못 읽어 **검사조차 하지 않았다**(미탐).
        #   현행은 열거 4종을 정확히 읽고 부정문은 삼키지 않는다 — 양쪽 회귀를 이 케이스가 고정한다.
        ('ZZ_NEG7', 'DEV', 'DEVICE_TYPE', bt3, 'DEVICE_TYPE',
         "기기 유형. 실제 코드값: 'M'=모바일(GA4 mobile/tablet 통합) · 'PC'=데스크톱 · "
         "'(해당없음)'=방송광고(기기 개념 없음) · '(unknown)'=매핑 실패 센티넬. "
         "⚠필터 시 'MOBILE'/'TABLET' 아님 — 모바일은 'M'."),
        # 양성⑤ §6.9-(5) 열거 누락 — 저카디널리티 VARCHAR 코드축인데 COMMENT 에 열거가 **아예 없다**
        ('ZZ_POS5', 'FSE', 'SEND_TYPE', bt, 'SEND_TYPE', "발송 채널"),
        # 음성⑧ 🔴 **BOOLEAN 은 ④ 대상이 아니다** — TRUE/FALSE 는 자명하다(오탐 대조).
        ('ZZ_NEG8', 'FSE', 'HAS_BILLING', bt, 'HAS_BILLING', "청구 존재 여부"),
        # 음성⑨ 🔴 **NUMBER 시간축은 ④ 대상이 아니다** — `CAL_QUARTER` 는 자기설명적이다(오탐 대조).
        ('ZZ_NEG9', 'DATE', 'CAL_QUARTER', bt4, 'QUARTER', "분기"),
    ]
    exposed = {('ZZ_POS3', bt2): {'MBER_STAT_CD'},
               ('ZZ_NEG3', bt2): {'MBER_STAT_CD', 'MEMBER_STATUS_NAME'},
               ('ZZ_NEG5', bt2): {'MBER_STAT_CD', 'MEMBER_STATUS_NAME'},
               ('ZZ_NEG7', bt3): {'DEVICE_TYPE'},
               ('ZZ_NEG9', bt4): {'QUARTER'}}
    for sv in ('ZZ_POS1', 'ZZ_POS2', 'ZZ_POS4', 'ZZ_POS5',
               'ZZ_NEG1', 'ZZ_NEG2', 'ZZ_NEG4', 'ZZ_NEG6', 'ZZ_NEG8'):
        exposed[(sv, bt)] = {'SEND_STATUS', 'SEND_TYPE', 'HAS_BILLING'}
    return dims, distinct_map, base_cols, exposed, card, dtype


def report(v_ghost, v_count, v_label, v_retired, v_enum, info, n_sv, n_dim):
    print(f"[SV 코드값·라벨축 게이트] SV {n_sv}종 · 컬럼 배킹 차원 {n_dim}개 검사")
    for sv, dim, ghost, sample in v_ghost:
        print(f"  🔴 코드값 부재(0행 오답 경로): {sv}.{dim} 열거 {ghost} · 실제 예 {sample}")
    for sv, dim, dec, act in v_count:
        print(f"  🔴 종수 선언 불일치: {sv}.{dim} COMMENT '실제값 {dec}종' vs 실제 {act}종")
    for sv, dim, bc, n, sample in v_enum:
        print(f"  🟠 열거 누락(§6.9-(5)): {sv}.{dim} ▸ {bc} distinct {n}종 · 실제 예 {sample}")
    for sv, dim, bc, lab in v_label:
        print(f"  🔴 라벨축 미노출(DEC-35 R1): {sv}.{dim} — base 에 {lab} 가 있는데 코드축 {bc} 만 노출")
    for sv, dim, lit, why in v_retired:
        print(f"  🔴 폐기 리터럴 노출(R5·P174): {sv}.{dim} '{lit}' ▸ {why}")
    for i in info:
        print(f"  ⚪ {i}")
    fail = len(v_ghost) + len(v_count) + len(v_label) + len(v_retired) + len(v_enum)
    print(f"  ⇒ 위반 {fail}건 (코드값부재 {len(v_ghost)} · 종수 {len(v_count)} · "
          f"열거누락 {len(v_enum)} · 라벨축 {len(v_label)} · 폐기리터럴 {len(v_retired)}) · 정보 {len(info)}건")
    return fail


def main():
    if '--self-check' in sys.argv:
        dims, dmap, bcols, exp, card, dtype = fixtures()
        g, c, l, r, e, _ = judge(dims, dmap, bcols, exp, card, dtype)
        # 🔴 판정은 **검사축별**로 한다. 초판이 전 검사 hits 를 한 집합으로 합쳤다가
        #    ①②③ 용 음성 대조(`ZZ_NEG3`·`ZZ_NEG4`)를 ④ 가 정당하게 잡은 것을 「오탐 2건」으로 오판했다.
        #    ⇒ 음성 대조군은 **그 검사에 대해서만** 음성이다. 축을 섞으면 자기검사가 거짓 실패한다.
        hits_a = ({s for s, *_ in g} | {s for s, *_ in c}       # ① 코드값·종수
                  | {s for s, *_ in l} | {s for s, *_ in r})     # ② 라벨축 · ③ 폐기 리터럴
        hits_e = {s for s, *_ in e}                              # ④ 열거 누락
        cases = [
            ('①②③ 코드값·라벨축·폐기리터럴', hits_a,
             {'ZZ_POS1', 'ZZ_POS2', 'ZZ_POS3', 'ZZ_POS4'},
             {'ZZ_NEG1', 'ZZ_NEG2', 'ZZ_NEG3', 'ZZ_NEG4', 'ZZ_NEG5',
              'ZZ_NEG6', 'ZZ_NEG7', 'ZZ_NEG8', 'ZZ_NEG9'}),
            ('④ 열거 누락(§6.9-(5))', hits_e,
             {'ZZ_POS5'},
             {'ZZ_NEG8', 'ZZ_NEG9', 'ZZ_NEG1', 'ZZ_NEG6', 'ZZ_NEG7'}),
        ]
        print("[자기검사] 합성 입력으로 탐지력을 확인한다(P106 — 위반 0 상태의 통과는 공집합 통과와 구별되지 않는다)")
        ok = True
        for name, hits, wp, wn in cases:
            print(f"  · {name}")
            for s in sorted(wp):
                print(f"      {'🟢 검출' if s in hits else '🔴 미검출'} 양성 {s}")
            for s in sorted(wn):
                print(f"      {'🔴 오탐' if s in hits else '🟢 정상'} 음성 {s}")
            print(f"      ⇒ 양성 {len(wp & hits)}/{len(wp)} · 오탐 {len(wn & hits)}건")
            ok = ok and (wp <= hits) and not (wn & hits)
        print("\n" + ("✅ 자기검사 통과 — 게이트가 살아 있다" if ok else "🔴 자기검사 실패"))
        return 0 if ok else 1

    dims, dmap, bcols, exp, card, dtype = load_live()
    g, c, l, r, e, info = judge(dims, dmap, bcols, exp, card, dtype)
    report(g, c, l, r, e, info, len({d[0] for d in dims}), len(dims))

    # 🔴🔴 [2026-08-29 O119-B 신설 · 사용자 승인] **severity 와 종료코드를 일치시켰다.**
    #   결함: `report()` 가 🔴 축과 🟠 축을 한 수(`fail`)로 합쳐 종료코드로 썼다 ⇒ **🟠 로 표시한
    #   「열거 누락」이 blocking** 이었다. 그래서 O119 종료 시점에 이 게이트는 **영구 빨강**이었다.
    #   🔴 왜 문제인가 = 형제 게이트의 명시적 설계 원칙과 어긋난다:
    #     · `sv_unit_gate` = *"항상 빨간 게이트는 무시되어 결국 무력화된다"* (그래서 신규 유입만 실패)
    #     · `sv_rule7_scan`(O119-B) = 라이브 도달만 blocking · 문서 주석은 경고
    #     · `agent_tool_claim_gate` = ① 모순만 blocking · ② 문안 이격은 advisory
    #     ⇒ **같은 축(SV 품질)의 네 게이트 중 이것만 severity 표시와 차단 강도가 어긋났다**(`R3-9 ㉡`).
    #   🟢 판정 = **blocking = 🔴 4축**(코드값 부재 · 종수 불일치 · 라벨축 · 폐기 리터럴) ·
    #     **advisory = 🟠 열거 누락**. 🔴 근거: 🔴 4축은 **0행 오답·거짓 주장**을 만들지만(Agent 가
    #     없는 코드값으로 필터하거나 틀린 종수를 사실로 말한다), 🟠 열거 누락은 **문안이 불완전한 것**이고
    #     기지 부채(ML 계열 다수)라 0 을 요구하면 매 세션 실패한다.
    #   🔴 **열거 누락을 무시하라는 뜻이 아니다** — 경고로 남고 건수가 출력되며 인수인계에 승계된다.
    blocking = len(g) + len(c) + len(l) + len(r)
    advisory = len(e)
    print(f"\n  ⇒ 판정 분리: blocking(🔴 코드값·종수·라벨축·폐기리터럴) {blocking}건 · "
          f"advisory(🟠 열거누락) {advisory}건")
    if blocking:
        print("🔴 게이트 실패 — 🔴 축은 blocking 이다(0행 오답·거짓 주장 경로).")
        return 1
    if advisory:
        print("✅ 게이트 통과 — 🔴 축 0건 (열거 코드값 전량 실재 · 종수 일치 · 라벨축 정상 · 폐기 리터럴 0)")
        print(f"🟠 잔여 경고 {advisory}건 = 저카디널리티 코드축 열거 누락(§6.9-(5)) — blocking 아님.")
        print("   🔴 무시하라는 뜻이 아니다: 열거가 없으면 Agent 가 실재하는 코드값을 누락한 답을 낸다.")
        return 0
    print("✅ 게이트 통과 — 열거 코드값 전량 실재 · 저카디널리티 코드축 전량 열거 · "
          "라벨축 노출 정상 · 폐기 리터럴 0")
    return 0


if __name__ == '__main__':
    sys.exit(main())
