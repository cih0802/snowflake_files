"""[2026-09-16 O166] 개명 잔여 일괄 정정기 (활성 생성기 코드 대상)

왜 필요한가
  `rename_stale_gate.SCAN_DIRS` 에 `scripts/` 가 없어 **생성기 코드의 개명 잔여가 검사 밖**이었다.
  실해 = `gen_section_assembly.SRC_SYS` 등 판정 등록부의 키가 개명 전 이름이라
  `SRC_SYS.get()` 이 `?` 를 돌리고 `09_보고서필드_조립가능성` 의 **타원천 18건이 전건 오판**이었다.

설계
  · 개명 대응 정본 = `rename_stale_gate.RENAMES` (하드코딩하지 않는다 · 같은 것을 다르게 재지 않는다)
  · 경계 정규식도 그 모듈의 `RX` 를 재사용한다.
  · 🔴 **서사 줄은 건드리지 않는다** — 개명 이력·병기 인용은 옛 이름이 정확한 기술이다.
    판정 = `rename_stale_gate.qualified()`(병기) OR 아래 `NARRATIVE` 마커.
  · dry-run 기본. `--apply` 로만 쓴다. 변경 줄은 전건 출력해 사람이 검토한다.

사용
  python3 scripts/_o166_rename_fix.py                 # dry-run
  python3 scripts/_o166_rename_fix.py --apply
"""
import argparse
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))
import rename_stale_gate as G  # noqa: E402

#: 대상 = **활성 생성기·게이트 체인**만. 일회성 패치·프로브 스크립트는 이력 성격이라 제외한다.
#: 🆕 [2026-09-16 O166 2차] 게이트·검증기까지 확장 — 1차(생성기 6종) 뒤 잔여 34건을 갈라 보니
#:   **실행 의미를 가진 등록부·경로**가 게이트 쪽에 남아 있었다(`sv_unit_gate` 앵커 사전 ·
#:   `sv_code_label_gate` base 테이블 · `ws_stage_verify` dbt 파일 경로 · `gen_pipeline_erd` 관계 튜플).
TARGETS = (
    'scripts/gen_section_assembly.py',
    'scripts/gen_column_inventory_20260811.py',
    'scripts/gen_column_mapping.py',
    'scripts/gen_metric_gold_mapping.py',
    'scripts/gen_bronze_exposure_audit.py',
    'scripts/field_mapping_override.py',
    'scripts/sv_unit_gate.py',
    'scripts/sv_code_label_gate.py',
    'scripts/ws_stage_verify.py',
    'scripts/gen_pipeline_erd.py',
    'scripts/rebuild_inventory.py',
    'scripts/agent_object_ref_gate.py',
    'scripts/run_bronze_audit_host.py',
)

#: 서사 마커 — 이 줄의 옛 이름은 **정확한 역사 기술**이므로 바꾸지 않는다.
#: 🆕 🔴🔴 [2026-09-16 O168 결함 정정] 종전 이 표에 **`'→ '` 가 들어 있었다** ⇒ 화살표가 있는 줄이면
#:   전부 「개명 서술」로 보고 건너뛰었다. 실해 = `--from-gate --apply` 뒤에도 축1 잔여 **90건**이
#:   남았고 그 90건은 **전건 흐름 화살표**였다(`CRM_BIZ_TARGET`→`FACT_TARGET_BIZ` 적재 흐름 ·
#:   `FACT_DEV_ACHIEVEMENT`→`DIM_BUDGET_ITEM` FK · `DIM_CAMPAIGN`→`FACT_..._SPONSOR_BIZ` 조인).
#:   🔴 이 문서군에서 `→` 는 **개명 기호가 아니라 흐름·매핑 기호**다.
#:   🔴 형태 = 게이트 자신이 O155 에서 겪은 결함과 같다 — *"줄 전체 키워드로 판정해 정상 병기를
#:   오탐했다"* 의 **거울상**(그쪽은 오탐, 이쪽은 누락). ⇒ 판정은 **매치의 이웃**을 봐야 한다.
#:   🟢 처방 = 화살표는 줄 마커에서 빼고 `arrow_rename()` 으로 **매치 단위**로 판정한다.
NARRATIVE = ('개명', '으로 전환', '종전', '오판 3건', 'RENAMES', 'rename_stale',
             '구 이름', '옛 이름', 'O53 이', 'O166')

#: 🆕 [2026-09-16 O168] 「`구이름` → `새이름`」(또는 역순) 인접 = **개명 서술**이므로 보존한다.
#:   그 외의 화살표는 흐름·매핑이므로 치환 대상이다. 창 = 화살표 양옆 12자(백틱·공백·굵게 마크업 여유).
ARROW = r'(?:→|⇒|->)'


def arrow_rename(line, old):
    """이 줄에서 `old` 가 **자신의 새 이름과 화살표로 직접 이어져** 있는가."""
    new = G.RENAMES[old]
    a = r'%s.{0,12}?%s.{0,12}?%s' % (old, ARROW, new)
    b = r'%s.{0,12}?%s.{0,12}?%s' % (new, ARROW, old)
    return bool(re.search(a, line) or re.search(b, line))


#: 🔴🔴 자동 치환 제외 — **기계 치환이 틀리는 이름**은 손으로 고친다.
#:   `DIM_MEMBER_CURRENT` → `DIM_MEMBER` 는 두 가지 이유로 자동화가 위험하다:
#:   ㉠ **중복 키** = `gen_column_inventory` 에 `"DIM_MEMBER"` 항목이 이미 있어(:35·:296)
#:      치환하면 dict 키가 겹쳐 **조용히 덮어쓴다**(설명문이 뒤바뀐다).
#:   ㉡ **자기모순 문안** = 종전 문안이 *"`DIM_MEMBER` 는 SCD2 라 팬아웃한다 ⇒ `DIM_MEMBER_CURRENT` 를
#:      쓰라"* 이므로 기계 치환하면 *"`DIM_MEMBER` 를 쓰라"* 가 되어 처방이 무의미해진다.
#:   ⇒ 이 이름은 「개명」이 아니라 **객체 소멸**이다.
#:   🆕 🔴🔴 [2026-09-16 O167 정정] 종전 이 주석은 *"현재행은 `IS_CURRENT = TRUE` 필터로 얻는다"* 라고
#:      적었는데 **그 컬럼은 없다** — 라이브 `GOLD.DIM_MEMBER` 24컬럼에 `IS_CURRENT` **부재**(실측).
#:      🟢 실제는 `DIM_MEMBER` 자체가 **1행/회원**(`MEMBER_DK` 유일 1,785,299)이라 필터가 **불필요**하고,
#:      상태 이력이 필요하면 `DIM_MEMBER_STATUS_HISTORY`(8,069,279행 = 4.52행/회원)를 쓴다.
#:      🔴 같은 문안이 SV DDL 4종·라이브 SV 4종에도 있었고 O167 이 함께 정정했다(`R3-9 ㉥` 축).
MANUAL_ONLY = ('DIM_MEMBER_CURRENT',)


def fix_line(line, only=()):
    """한 줄을 정정한다. 반환 = (새 줄, 치환 건수).

    `only` 가 비어 있지 않으면 **그 구 이름들만** 치환한다(어의 변경 개명 배제용).
    """
    if any(k in line for k in NARRATIVE):
        return line, 0
    out, n, pos = [], 0, 0
    for m in G.RX.finditer(line):
        if G.qualified(line, m.start(), m.group(1)):
            continue
        if m.group(1) in MANUAL_ONLY:
            continue
        if arrow_rename(line, m.group(1)):   # 🆕 [O168] 「구 → 신」 인접 = 개명 서술이므로 보존
            continue
        if only and m.group(1) not in only:
            continue
        out.append(line[pos:m.start()])
        out.append(G.RENAMES[m.group(1)])
        pos = m.end()
        n += 1
    if not n:
        return line, 0
    out.append(line[pos:])
    return ''.join(out), n


def gate_axis1_files():
    """🆕 [O167] 대상 파일을 **게이트 축1 판정에서 받아온다.**

    🔴 왜 바꿨나 = 종전 `TARGETS` 는 O166 이 손으로 나열한 13개였고 **그때 소진됐다**.
    그 뒤 `--apply` 를 돌리면 **치환 0건**이 나오는데, 게이트는 여전히 **530건**을 보고한다
    ⇒ 🔴 **도구의 분모와 게이트의 분모가 달랐다**(O165 `D5` 와 같은 형태).

    🔴🔴 **초판(O167 1차)은 `SCAN_DIRS` 를 전량 훑어 1,048건을 냈다 — 그것은 축1 이 아니다.**
    게이트는 같은 스캔을 `bucket()` 으로 **축1(살아있는 정본) / 축2(생성 산출물) /
    축3(이력·근거철)** 으로 가른다. `_archive/`·이력·근거철은 **옛 이름이 정확한 기록**이라
    고치면 경위가 사라진다 ⇒ 🟢 **`bucket(rel)` 이 축1 로 판정한 파일만** 대상이다.
    """
    out = []
    for d in G.SCAN_DIRS:
        base = os.path.join(ROOT, d)
        if not os.path.isdir(base):
            continue
        for cur, subs, fs in os.walk(base):
            subs[:] = [x for x in subs if x not in G.SKIP_DIR]   # 게이트와 같은 제외 규칙
            for f in fs:
                if not f.endswith(G.EXT):                        # 게이트와 같은 확장자 분모
                    continue
                rel = os.path.relpath(os.path.join(cur, f), ROOT)
                if G.bucket(rel) == 'LIVE':                      # 축1 = 살아있는 정본
                    out.append(rel)
    return sorted(out)


def main():
    ap = argparse.ArgumentParser(prog='_o166_rename_fix.py')
    ap.add_argument('--apply', action='store_true', help='실제로 파일을 고친다(기본 dry-run)')
    ap.add_argument('--only', default='',
                    help='쉼표로 구분한 **구 이름 목록**만 치환한다(예: FACT_GA_BEHAVIOR,DIM_GA_EVENT). '
                         '🔴 어의가 바뀐 개명은 여기 넣지 마라 — 이름은 맞고 뜻이 틀린 문안이 남는다.')
    ap.add_argument('--from-gate', action='store_true',
                    help='대상 파일을 게이트 축1 분모(SCAN_DIRS 전량)에서 받는다')
    a = ap.parse_args()

    only = tuple(x.strip() for x in a.only.split(',') if x.strip())
    if only:
        unknown = [x for x in only if x not in G.RENAMES]
        if unknown:
            print('🔴 개명 대응표에 없는 이름: %s' % unknown)
            return 2
    targets = gate_axis1_files() if a.from_gate else TARGETS

    total, touched = 0, 0
    for rel in targets:
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            print('  ⚠️ 없음 %s' % rel)
            continue
        text = io.open(path, encoding='utf-8').read()
        lines = text.split('\n')
        new, cnt = [], 0
        for i, line in enumerate(lines, 1):
            nl, k = fix_line(line, only)
            if k:
                cnt += k
                print('  %s:%d' % (rel, i))
                print('    - %s' % line.strip()[:150])
                print('    + %s' % nl.strip()[:150])
            new.append(nl)
        if cnt:
            touched += 1
            total += cnt
            if a.apply:
                io.open(path, 'w', encoding='utf-8').write('\n'.join(new))
    print('')
    print('[개명 정정] 치환 %d건 · 파일 %d개 · 한정 %s · %s'
          % (total, touched, (','.join(only) or '전체'), 'APPLIED' if a.apply else 'DRY-RUN'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
