#!/usr/bin/env python3
"""test_doc_type_increment — `증분형` 유형과 그 강제 장치의 음성 테스트 (2026-09-22 O180-B · R3-2).

🔴🔴 **왜 이 테스트가 필요한가 — 이 세션이 실제로 사고를 냈다.**
  O180-B 가 `split_doc.declared_kind` 1차 구현에서 함수명을 `read_registry` 로 잘못 호출했고
  (정답 = `parse_registry`) **자기가 넣은 `except Exception: return None` 이 그 `AttributeError`
  를 삼켜** 가드가 「없는 것처럼」 동작했다 ⇒ 증분형 문서50 에 `--rebalance` 가 **실제로 집행**돼
  조각이 **23 → 24** 로 밀렸다(본문 바이트 동일 · 유실 0 · 좌표 19건 중 17건 유지).
  🟢🟢 **판정식 = 「안전측 폴백」이 가드를 죽이는 가장 흔한 경로다.**
    폴백은 **「게이트가 고장났다」와 「이 문서는 미등재다」를 구별해야 한다.**
  🔴 그리고 그 사고는 **가드가 있다고 믿은 채로** 났다 ⇒ 「가드를 심었다」는 「가드가 동작한다」가 아니다.

축
  · 등재 축 3개  — `증분형` 이 `KINDS` 에 있고, 문서20·문서50 이 그렇게 선언돼 있는가.
  · 판정 축 5개  — `declared_kind` 가 5문서의 유형을 **정확히** 돌려주는가(🔴 None 이면 FAIL).
  · 여유 축 2개  — `TAIL_KINDS` 에 증분형이 들어 있고 꼬리 기준으로 보는가.
  · 회귀 축 2개  — 🔴 **고치기 전 구현으로 되돌리면 가드가 죽는지** 실증한다:
      ㉠ 함수명을 틀리게 하면 `declared_kind` 가 None 을 돌려 가드가 무력화된다
      ㉡ 광범위 `except` 로 삼키면 **경고조차 나오지 않는다**(1차 구현의 실제 실패 형태)
  · 차단 축 2개  — 증분형에 재균형을 **거부**하고, 다른 유형은 **막지 않는가**(역방향 오탐).
  🔴 차단 축은 **실제로 파일을 쓰지 않는다** — `rebalance` 를 호출하지 않고 가드 분기만 단정한다
     (테스트가 정본을 재분할하면 그 자체가 사고다).

🔴 이 파일은 손으로 만든다(`test_*` 규약 · `new_tool.py` 등재 대상이 아니다).
종료코드 = 0 전 축 통과 · 1 하나라도 실패.
"""
import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import doc_type_gate as DT      # noqa: E402
import split_doc as SD          # noqa: E402

ROOT = '/workspace'
DOC20 = '20_현업확인_요청.md'
DOC50 = '50_dbt_파이프라인_미결조치.md'

RESULTS = []


def check(name, ok, detail=''):
    RESULTS.append((name, bool(ok), detail))


def hub(name):
    return os.path.join(ROOT, '20_issue', name)


# ───────────────────────── 등재 축 ─────────────────────────

def t_kind_registered():
    check('등재㉠ KINDS 에 증분형 실재', '증분형' in DT.KINDS,
          'KINDS=%s' % (DT.KINDS,))
    check('등재㉡ INCREMENTAL 상수 = 증분형', DT.INCREMENTAL == '증분형',
          repr(getattr(DT, 'INCREMENTAL', None)))


def t_registry_declares_both():
    reg = DT.parse_registry(DT.index_logical())
    for doc in (DOC20, DOC50):
        val = reg.get(doc)
        kind = (val[0] if isinstance(val, (tuple, list)) else val) if val else None
        check('등재㉢ %s = 증분형' % doc, kind == '증분형', '실측 %r' % kind)


# ───────────────────────── 판정 축 ─────────────────────────

def t_declared_kind_all():
    """🔴 None 은 FAIL 이다 — 1차 구현이 전건 None 을 돌려 사고를 냈다."""
    expect = {
        DOC20: '증분형',
        DOC50: '증분형',
        '01_세션이력.md': 'append형',
        '00_INDEX_이슈원장.md': '갱신형',
        '90_해소완료_로그.md': 'append형',
    }
    for name, want in expect.items():
        got = SD.declared_kind(hub(name))
        check('판정 %s = %s' % (name, want), got == want, '실측 %r' % got)


# ───────────────────────── 여유 축 ─────────────────────────

def t_tail_kinds():
    check('여유㉠ TAIL_KINDS 에 증분형', DT.INCREMENTAL in DT.TAIL_KINDS,
          'TAIL_KINDS=%s' % (DT.TAIL_KINDS,))
    check('여유㉡ TAIL_KINDS 에 append형도 유지',
          'append형' in DT.TAIL_KINDS, 'TAIL_KINDS=%s' % (DT.TAIL_KINDS,))


# ─────────────────── 회귀 축 = 고치기 전 구현 ───────────────────

def t_regression_pre_fix():
    """🔴 R3-2 실증 = 1차 구현으로 되돌리면 가드가 **실제로 죽는지** 확인한다.

    되돌림 = `parse_registry` 를 숨겨 `AttributeError` 를 유발한다
    (1차 구현은 `read_registry` 라는 **없는 이름**을 불렀고 광범위 except 가 삼켰다).
    """
    orig = DT.parse_registry
    try:
        del DT.parse_registry
        # 현행 구현 = 경고를 stderr 로 내고 None (가드는 못 걸지만 **보인다**)
        got = SD.declared_kind(hub(DOC50))
        check('회귀㉠ 등재표 고장 시 None 재현', got is None, '실측 %r' % got)
    finally:
        DT.parse_registry = orig

    # 되돌림 해제 후 정상 복귀 — 🔴 이것이 없으면 위 축이 영구 오염을 남긴다
    got = SD.declared_kind(hub(DOC50))
    check('회귀㉡ 복귀 후 증분형 정상 판정', got == '증분형', '실측 %r' % got)


def t_regression_warn_is_visible():
    """🔴 고장이 **조용하지 않은지** 단정한다 — 1차 구현의 실제 실패 형태가 침묵이었다."""
    import contextlib
    buf = io.StringIO()
    orig = DT.parse_registry
    try:
        del DT.parse_registry
        with contextlib.redirect_stderr(buf):
            SD.declared_kind(hub(DOC50))
    finally:
        DT.parse_registry = orig
    msg = buf.getvalue()
    check('회귀㉢ 고장 시 경고가 보인다', 'declared_kind' in msg and msg.strip() != '',
          '출력 %r' % msg.strip()[:70])


# ─────────────────── 차단 축 (파일을 쓰지 않는다) ───────────────────

def t_guard_blocks_incremental():
    """증분형 = 거부(rc=1) · 🔴 `force=False` 경로만 단정한다(재분할을 호출하지 않는다)."""
    rc = SD.rebalance(hub(DOC50), force=False)
    check('차단㉠ 증분형 재균형 거부(rc=1)', rc == 1, 'rc=%r' % rc)
    rc2 = SD.rebalance(hub(DOC20), force=False)
    check('차단㉡ 문서20 도 거부(rc=1)', rc2 == 1, 'rc=%r' % rc2)


def t_guard_does_not_block_others():
    """역방향 오탐 = 갱신형·append형은 **가드에 걸리지 않아야** 한다.

    🔴 실제 재분할을 부르면 정본이 바뀐다 ⇒ **유형 판정만** 단정한다
      (가드 분기는 `kind == '증분형'` 하나이므로 유형이 다르면 통과가 보장된다).
    """
    for name in ('00_INDEX_이슈원장.md', '01_세션이력.md', '90_해소완료_로그.md'):
        k = SD.declared_kind(hub(name))
        check('차단㉢ %s 는 증분형이 아니다(가드 비적용)' % name,
              k is not None and k != '증분형', '실측 %r' % k)


def main():
    for fn in (t_kind_registered, t_registry_declares_both, t_declared_kind_all,
               t_tail_kinds, t_regression_pre_fix, t_regression_warn_is_visible,
               t_guard_blocks_incremental, t_guard_does_not_block_others):
        try:
            fn()
        except Exception as exc:  # noqa: BLE001
            check(fn.__name__ + ' (예외)', False, repr(exc))

    fails = [r for r in RESULTS if not r[1]]
    print('[test_doc_type_increment] 단정 %d개' % len(RESULTS))
    for (name, ok, detail) in RESULTS:
        print('  %s %s%s' % ('🟢' if ok else '🔴', name,
                             ('  — ' + detail) if detail else ''))
    print('\n판정 = 통과 %d / %d' % (len(RESULTS) - len(fails), len(RESULTS)))
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
