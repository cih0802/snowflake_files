# -*- coding: utf-8 -*-
"""[2026-08-11 O59-B] §6.9-(5) 열거 누락 41건 **기계 교정** — `05_*_SV_DDL_*.sql` 패치.

🔴 왜 기계 생성인가: 대상이 41개 차원 × 9파일이고 값의 정본은 **라이브 실측**이다.
   손으로 옮기면 ① 오타가 그대로 0행 오답이 되고 ② 다음 적재에서 재현이 불가능하다.
   O51-F 선례와 동일 원칙 — *"손 이관 금지. 순서·값 정본은 실측이며 전량 기계 생성이다."*

동작
  ① 라이브에서 (SV, 차원, base 컬럼, 실제 distinct 전량, NULL 유무)를 읽는다.
  ② 게이트의 `is_enum_target`·`enumerated_values` 로 **열거 누락 대상만** 고른다(판정 로직 1벌).
  ③ 해당 SV 파일에서 `lt.<DIM> AS ` 로 시작하는 선언 라인을 찾아 **말미 COMMENT 문자열 끝**에
     ` 실제값 N종: ''a''·''b''…` 를 삽입한다(NULL 이 있으면 ` + NULL` 을 덧붙인다).
  ④ 값에 `'` 나 `·` 가 있으면 **패치하지 않고 보고**한다 — 열거 파서·SQL 리터럴을 깨뜨리므로 사람이 본다.

사용: python3 scripts/patch_sv_enum_comments.py [--apply]   (기본은 dry-run)
"""
import sys, os, re, io

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sv_code_label_gate import load_live, is_enum_target, enumerated_values

ROOT = '/workspace/05_SV-Agent_ai'
SV_FILE = {
    'SV_MEMBER_MONTHLY':      '05_1_SV_DDL_MEMBER_MONTHLY.sql',
    'SV_MEMBER_EVENT':        '05_2_SV_DDL_MEMBER_EVENT.sql',
    'SV_MEMBER_COHORT':       '05_3_SV_DDL_MEMBER_COHORT.sql',
    'SV_SERVICE':             '05_4_SV_DDL_SERVICE.sql',
    'SV_EVENT_PARTICIPATION': '05_5_SV_DDL_EVENT_PARTICIPATION.sql',
    'SV_BUDGET':              '05_6_SV_DDL_BUDGET.sql',
    'SV_AD':                  '05_7_SV_DDL_AD.sql',
    'SV_DEV_ACHIEVEMENT':     '05_8_SV_DDL_DEV_ACHIEVEMENT.sql',
    'SV_MEMBER_FEE':          '05_9_SV_DDL_MEMBER_FEE.sql',
}


def enum_clause(vals, has_null):
    """` 실제값 N종: ''a''·''b''` (+ NULL) — SQL 리터럴용으로 홑따옴표를 이중화한다."""
    ordered = sorted(vals, key=lambda v: (len(v), v))
    body = '·'.join(f"''{v}''" for v in ordered)
    tail = ' + NULL' if has_null else ''
    return f" 실제값 {len(ordered)}종: {body}{tail}"


def patch_line(line, clause):
    """말미 `COMMENT = '...'` 의 닫는 홑따옴표 **앞**에 clause 를 삽입한다."""
    stripped = line.rstrip('\n')
    trail = ''
    while stripped and stripped[-1] in ' ,':
        trail = stripped[-1] + trail
        stripped = stripped[:-1]
    if not stripped.endswith("'") or "COMMENT = '" not in stripped:
        return None
    return stripped[:-1] + clause + "'" + trail + '\n'


def main():
    apply = '--apply' in sys.argv
    dims, dmap, bcols, exposed, card, dtype = load_live()

    targets = []
    for sv, lt, dim, bt, bc, cmt in dims:
        vals, declared = enumerated_values(cmt, bc)
        if vals or declared is not None:
            continue
        if not is_enum_target(dtype.get((bt, bc), ''), card.get((bt, bc)), bc):
            continue
        actual = dmap.get((bt, bc))
        if actual is None:
            print(f"  ⚪ 실측 없음 — 건너뜀: {sv}.{dim}")
            continue
        nn = {v for v in actual if v != ''}
        bad = [v for v in nn if "'" in v or '·' in v]
        if bad:
            print(f"  🔴 값에 따옴표·중점 포함 — **수동 처리 필요**: {sv}.{dim} {bad}")
            continue
        targets.append((sv, dim, bc, nn, '' in actual))

    print(f"[§6.9-(5) 열거 누락 패치] 대상 {len(targets)}건 · {'적용' if apply else 'DRY-RUN'}")
    by_sv = {}
    for t in targets:
        by_sv.setdefault(t[0], []).append(t)

    done, miss = 0, []
    for sv, items in sorted(by_sv.items()):
        path = os.path.join(ROOT, SV_FILE[sv])
        src = io.open(path, encoding='utf-8').read().split('\n')
        changed = 0
        for _, dim, bc, nn, has_null in items:
            # 선언 라인 = `<lt>.<DIM> AS ` (dimension 이름이 AS 앞 토큰의 뒤쪽)
            pat = re.compile(r'^\s*[A-Za-z_][A-Za-z0-9_]*\.' + re.escape(dim) + r'\s+AS\s')
            hit = [i for i, L in enumerate(src) if pat.match(L)]
            if len(hit) != 1:
                miss.append(f"{sv}.{dim}: 선언 라인 {len(hit)}개(1개여야 한다)")
                continue
            i = hit[0]
            # 🔴 파일마다 선언 형식이 다르다 — 1줄형(`… AS … WITH SYNONYMS (…) COMMENT = '…',`)과
            #    **3줄형**(`… AS …` / `WITH SYNONYMS (…)` / `COMMENT = '…',`)이 공존한다.
            #    초판이 선언 라인에서만 COMMENT 를 찾아 `SV_DEV_ACHIEVEMENT` 2건을 놓쳤다(3줄형).
            #    ⇒ 선언 라인부터 아래 4줄 안에서 COMMENT 를 담은 라인을 찾는다.
            ci = next((j for j in range(i, min(i + 5, len(src)))
                       if "COMMENT = '" in src[j]), None)
            if ci is None:
                miss.append(f"{sv}.{dim}: COMMENT 라인 미발견 (line {i+1})")
                continue
            new = patch_line(src[ci], enum_clause(nn, has_null))
            if new is None:
                miss.append(f"{sv}.{dim}: COMMENT 종단 패턴 불일치 (line {ci+1})")
                continue
            src[ci] = new.rstrip('\n')
            changed += 1
            done += 1
        if changed and apply:
            io.open(path, 'w', encoding='utf-8').write('\n'.join(src))
        print(f"  {'✅' if changed == len(items) else '🟠'} {sv}: {changed}/{len(items)} 패치"
              f"{' (기록됨)' if apply and changed else ''}")

    for m in miss:
        print(f"  🔴 미처리: {m}")
    print(f"  ⇒ 패치 {done}/{len(targets)} · 미처리 {len(miss)}")
    return 1 if miss else 0


if __name__ == '__main__':
    sys.exit(main())
