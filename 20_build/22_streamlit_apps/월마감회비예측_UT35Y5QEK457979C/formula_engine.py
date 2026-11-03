"""엑셀 계산식 엔진 (통합문서 단위).

지원: 사칙연산, 괄호, 단항 +/-, $절대참조, 시트참조('시트명'!A1, '시트명'!A1:B2),
      SUM(범위/식, ...), ROUND(x, n), 비교연산(=, <>, <, >, <=, >=) → TRUE/FALSE.
eval 을 쓰지 않고 토큰화 → 재귀하강 파서로 클로저를 만들어 계산한다.
빈 셀/텍스트 셀 참조는 엑셀처럼 0, 0으로 나누면 #DIV/0! 오류값을 전파한다.
"""
from __future__ import annotations

import math
import re
import sys
from functools import lru_cache

sys.setrecursionlimit(50000)


class XlError:
    __slots__ = ("code",)

    def __init__(self, code: str):
        self.code = code

    def __repr__(self) -> str:
        return self.code


DIV0 = XlError("#DIV/0!")
VALUE = XlError("#VALUE!")

_CELL = r"\$?[A-Z]{1,3}\$?\d+"
_SHEET = r"(?:'(?P<qs>(?:[^']|'')+)'|(?P<us>[A-Za-z0-9_.]+))!"
_TOKEN = re.compile(
    r"\s*(?:"
    rf"(?:{_SHEET})?(?P<range>{_CELL}:{_CELL})|"
    rf"(?:{_SHEET.replace('qs', 'qs2').replace('us', 'us2')})?(?P<ref>{_CELL})|"
    r"(?P<func>[A-Z]+)\(|"
    r"(?P<num>\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|"
    r"(?P<cmp><>|<=|>=|=|<|>)|"
    r"(?P<op>[-+*/(),])"
    r")"
)


def col_to_num(col: str) -> int:
    n = 0
    for ch in col:
        n = n * 26 + (ord(ch) - 64)
    return n


def num_to_col(n: int) -> str:
    s = ""
    while n:
        n, r = divmod(n - 1, 26)
        s = chr(65 + r) + s
    return s


def split_ref(ref: str) -> tuple[str, int]:
    m = re.fullmatch(r"\$?([A-Z]{1,3})\$?(\d+)", ref)
    return m.group(1), int(m.group(2))


def expand_range(rng: str) -> list[str]:
    a, b = rng.replace("$", "").split(":")
    ca, ra = split_ref(a)
    cb, rb = split_ref(b)
    c1, c2 = sorted((col_to_num(ca), col_to_num(cb)))
    r1, r2 = sorted((ra, rb))
    return [f"{num_to_col(c)}{r}" for r in range(r1, r2 + 1) for c in range(c1, c2 + 1)]


def tokenize(src: str) -> list[tuple]:
    """토큰 = (종류, 값, 시트명|None)."""
    pos, out = 0, []
    src = src.strip()
    while pos < len(src):
        m = _TOKEN.match(src, pos)
        if not m or m.end() == pos:
            raise ValueError(f"지원하지 않는 계산식: {src!r} (위치 {pos})")
        gd = m.groupdict()
        if gd["range"]:
            sh = gd["qs"] or gd["us"]
            out.append(("range", gd["range"], sh.replace("''", "'") if sh else None))
        elif gd["ref"]:
            sh = gd["qs2"] or gd["us2"]
            out.append(("ref", gd["ref"], sh.replace("''", "'") if sh else None))
        else:
            kind = next(k for k in ("func", "num", "cmp", "op") if gd[k] is not None)
            out.append((kind, gd[kind], None))
        pos = m.end()
    return out


def _num(x):
    return float(x) if isinstance(x, bool) else x


def _arith(op, a, b):
    if isinstance(a, XlError):
        return a
    if isinstance(b, XlError):
        return b
    a, b = _num(a), _num(b)
    if op in ("+", "-"):
        r = a + b if op == "+" else a - b
        # 엑셀처럼 거의 같은 두 수의 덧셈/뺄셈 결과(15자리 밖 오차)는 0 으로 처리
        if r != 0 and abs(r) <= max(abs(a), abs(b)) * 1e-15:
            return 0.0
        return r
    if op == "*":
        return a * b
    if b == 0:
        return DIV0
    return a / b


def _compare(op, a, b):
    if isinstance(a, XlError):
        return a
    if isinstance(b, XlError):
        return b
    a, b = _num(a), _num(b)
    # 엑셀은 15자리 유효숫자로 비교 → 부동소수 오차 허용
    eq = math.isclose(a, b, rel_tol=1e-12, abs_tol=1e-9)
    return {"=": eq, "<>": not eq, "<": a < b and not eq, ">": a > b and not eq,
            "<=": a < b or eq, ">=": a > b or eq}[op]


def _round(x, n):
    """엑셀 ROUND: 0.5 는 0에서 먼 쪽으로."""
    n = int(n)
    f = 10.0 ** n
    return math.copysign(math.floor(abs(x) * f + 0.5) / f, x)


@lru_cache(maxsize=None)
def compile_formula(formula: str, sheet: str):
    """'=A1+B2' → fn(get).  get(sheet, coord) 는 셀 값을 돌려준다."""
    toks = tokenize(formula[1:] if formula.startswith("=") else formula)
    i = 0

    def peek():
        return toks[i] if i < len(toks) else (None, None, None)

    def take():
        nonlocal i
        t = toks[i]
        i += 1
        return t

    def comparison():
        left = expr()
        while peek()[0] == "cmp":
            op = take()[1]
            right = expr()
            left = (lambda l, r, o: lambda g: _compare(o, l(g), r(g)))(left, right, op)
        return left

    def expr():
        left = term()
        while peek()[1] in ("+", "-") and peek()[0] == "op":
            op = take()[1]
            right = term()
            left = (lambda l, r, o: lambda g: _arith(o, l(g), r(g)))(left, right, op)
        return left

    def term():
        left = unary()
        while peek()[1] in ("*", "/") and peek()[0] == "op":
            op = take()[1]
            right = unary()
            left = (lambda l, r, o: lambda g: _arith(o, l(g), r(g)))(left, right, op)
        return left

    def unary():
        if peek()[0] == "op" and peek()[1] in ("+", "-"):
            op = take()[1]
            inner = unary()
            if op == "-":
                def neg(g, inner=inner):
                    x = inner(g)
                    return x if isinstance(x, XlError) else -_num(x)
                return neg
            return inner
        return atom()

    def args():
        parts = []
        while True:
            k, v, sh = peek()
            if k == "range":
                take()
                parts.append(("cells", sh or sheet, expand_range(v)))
            else:
                parts.append(("expr", None, comparison()))
            if peek()[1] == ",":
                take()
                continue
            break
        if take()[1] != ")":
            raise ValueError("함수 괄호 오류")
        return parts

    def values_of(parts, g):
        for typ, sh, p in parts:
            if typ == "cells":
                for c in p:
                    yield g(sh, c)
            else:
                yield p(g)

    def atom():
        kind, val, sh = take()
        if kind == "num":
            n = float(val)
            return lambda g: n
        if kind == "ref":
            coord, target = val.replace("$", ""), sh or sheet
            return lambda g: g(target, coord)
        if kind == "func":
            parts = args()
            if val == "SUM":
                def fsum(g, parts=parts):
                    total = 0.0
                    for x in values_of(parts, g):
                        if isinstance(x, XlError):
                            return x
                        total += _num(x)
                    return total
                return fsum
            if val == "ROUND":
                if len(parts) != 2:
                    raise ValueError("ROUND 인자 오류")

                def fround(g, parts=parts):
                    x, n = list(values_of(parts, g))
                    for y in (x, n):
                        if isinstance(y, XlError):
                            return y
                    return _round(_num(x), _num(n))
                return fround
            raise ValueError(f"지원하지 않는 함수: {val}")
        if val == "(":
            inner = comparison()
            if take()[1] != ")":
                raise ValueError("괄호 오류")
            return inner
        raise ValueError(f"예상치 못한 토큰: {val}")

    fn = comparison()
    if i != len(toks):
        raise ValueError(f"계산식 해석 실패: {formula}")
    return fn


class WorkbookCalc:
    """여러 시트의 셀(값/계산식)을 받아 시트간 참조까지 계산.

    sheets:    {시트명: {좌표: {"v"|"f"|"t": ...}}}
    overrides: {시트명: {좌표: 값}}  — 입력값 수정분
    div0_as_zero: True 면 0으로 나누기(#DIV/0!) 결과 셀을 0 으로 처리 (실적 0 인 달 대응)
    """

    def __init__(self, sheets: dict, overrides: dict | None = None, div0_as_zero: bool = False):
        self.sheets = sheets
        self.overrides = overrides or {}
        self.div0_as_zero = div0_as_zero
        self.values: dict = {name: {} for name in sheets}

    def get(self, sheet: str, coord: str):
        vals = self.values.setdefault(sheet, {})
        if coord in vals:
            return vals[coord]
        ov = self.overrides.get(sheet, {})
        if coord in ov:
            v = ov[coord]
        else:
            cell = self.sheets.get(sheet, {}).get(coord)
            if cell is None or "t" in cell:
                v = 0.0  # 빈 셀 / 텍스트 → 0 (엑셀 산술 기준)
            elif "f" in cell:
                vals[coord] = VALUE  # 순환참조 방지
                v = compile_formula(cell["f"], sheet)(self.get)
                if v is DIV0 and self.div0_as_zero:
                    v = 0.0
            else:
                v = float(cell["v"])
        if v is None:
            v = 0.0
        vals[coord] = v
        return v

    def compute_all(self) -> dict:
        for name, cells in self.sheets.items():
            for coord, cell in cells.items():
                if "t" not in cell:
                    self.get(name, coord)
        return self.values
