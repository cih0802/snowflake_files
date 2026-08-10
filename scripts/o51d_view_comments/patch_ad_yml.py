# -*- coding: utf-8 -*-
"""[2026-08-10 O51-F] 생성된 광고 계열 columns 블록 + 교정된 뷰 description 을 _wide_schema.yml 에 반영.

🔴 yaml 덤프를 쓰지 않는다 — 파일 전체가 재포맷되면 주석·`tests:` 구조가 소실된다(O51-D 선례).
   대상 모델 블록만 텍스트로 교체한다.
"""
import io, re, sys
sys.path.insert(0, '/workspace/scripts/o51d_view_comments')
import desc_ad as DA

WYML = '/workspace/10_dbt_pipeline/models/gold/wide/_wide_schema.yml'
OUT = '/tmp/o51f_out/%s.cols.yml'
NEW = ['WIDE_AD_BROADCAST', 'WIDE_AD_DIGITAL']
OVERLAY = ['WIDE_AD_PERFORMANCE', 'WIDE_GA_BEHAVIOR', 'WIDE_BUDGET',
           'WIDE_TARGET_DEV', 'WIDE_AD_BROADCAST_CASE', 'WIDE_TARGET_BIZ']
TARGETS = NEW + OVERLAY

def _note(lines):
    """🔴 NOTE 의 **모든 줄**에 `[O51-F]` 마커를 넣는다 — 멱등 제거가 첫 줄만 지우면 나머지가 쌓인다."""
    return "".join(f"    # [O51-F] {l}\n" for l in lines)


NOTE_NEW = _note([
"✅ [2026-08-10] 컬럼 문안 전량 등재 — 종전 「DROP 예정」 결정을 철회하고 이관했다.",
"  철회 근거(실측): 이 뷰는 dbt 모델이므로 물리 DROP 은 다음 build 가 되살린다 · 모델 헤더가",
"  이미 gn_view_commented 이관을 처방하고 있었다 · DEC-8/DEC-10 이 위성 단독 완결을 설계 의도로 명시한다.",
"  ⚠️ CREATE VIEW 컬럼목록은 SELECT 전 컬럼과 **개수·순서가 정확히 일치**해야 한다 —",
"     모델 SELECT 를 바꾸면 이 블록도 동시에 재생성할 것(scripts/o51d_view_comments/build_ad_yml.py).",
"  문안 출처 = 03_top-down_gold/10_ §7-A·§7-B 이관 + O51-F 실측 경고 오버레이.",
])

NOTE_OVL = _note([
"✅ [2026-08-10] 빈 축·희소축 경고 **오버레이 적용**(기존 문안 보존).",
"  🔴 경위: O51-D-C 의 빈 축 감사는 O51-D 대상 8객체만 스캔했고, O51-C 가 이미 물리에 배포한",
"     136컬럼은 감사되지 않았다 → 재스캔에서 **전건 센티넬이 침묵 중**임이 드러났다(O51-F-B).",
"     전건 '(미매핑)' 은 문자열이라 GROUP BY 가 단일 그룹을 반환한다 = 오답이 에러 없이 나온다.",
])


def load(t):
    return io.open(OUT % t, encoding='utf-8').read().rstrip('\n')


def split_models(txt):
    idx = [m.start() for m in re.finditer(r'(?m)^  - name: (\w+)\s*$', txt)]
    head = txt[:idx[0]]
    parts = []
    for i, s in enumerate(idx):
        e = idx[i + 1] if i + 1 < len(idx) else len(txt)
        blk = txt[s:e]
        parts.append([re.match(r'  - name: (\w+)', blk).group(1), blk])
    return head, parts


def drop_columns(blk):
    lines, out, i = blk.split('\n'), [], 0
    while i < len(lines):
        if re.match(r'^    columns:\s*$', lines[i]):
            i += 1
            while i < len(lines) and (lines[i].startswith('      ') or lines[i].strip() == ''):
                i += 1
            continue
        out.append(lines[i]); i += 1
    return '\n'.join(out)


def drop_o51f_notes(blk):
    """🔴 멱등화: 직전 실행이 삽입한 O51-F NOTE 주석 블록을 제거한다.

    실측 사고: `drop_columns` 는 `columns:` 서브블록만 지우고 **그 앞의 NOTE 주석은 남긴다** ⇒ 재실행마다
    NOTE 가 쌓여 파일이 커졌다(168,846B → 173,288B). 컬럼 문안은 정상인데 주석만 중복되는 조용한 증식이다.
    ⚠️ O51-C·O51-D 등 **다른 세션의 주석은 건드리지 않는다** — 내 마커(`O51-F`)를 가진 줄만 지운다.
    """
    keep = []
    for ln in blk.split('\n'):
        if re.match(r'^    #', ln) and 'O51-F' in ln:
            continue
        keep.append(ln)
    return '\n'.join(keep)


def replace_desc(blk, name):
    """모델 레벨 description 을 교정본으로 교체(단일 인용 스칼라 1줄 가정)."""
    if name not in DA.AD_VIEW_DESC:
        return blk, False
    d = DA.AD_VIEW_DESC[name].replace('\\', '\\\\').replace('"', '\\"')
    new = f'    description: "{d}"'
    if re.search(r'(?m)^    description: ', blk):
        blk = re.sub(r'(?m)^    description: .*$', new, blk, count=1)
        return blk, True
    # description 이 없으면 - name: 다음 줄에 삽입
    lines = blk.split('\n')
    lines.insert(1, new)
    return '\n'.join(lines), True


txt = io.open(WYML, encoding='utf-8').read()
head, parts = split_models(txt)
found, desc_n = [], 0
new_parts = [head]
for name, blk in parts:
    if name in TARGETS:
        blk = drop_columns(blk)
        blk = drop_o51f_notes(blk)          # 멱등화 — 직전 NOTE 제거
        blk, ok = replace_desc(blk, name)
        desc_n += 1 if ok else 0
        blk = blk.rstrip('\n') + '\n'
        blk += (NOTE_NEW if name in NEW else NOTE_OVL)
        blk += load(name) + '\n'
        found.append(name)
    new_parts.append(blk)

missing = [t for t in TARGETS if t not in found]
if missing:
    sys.exit("🔴 모델 블록 미발견: " + ", ".join(missing))

res = ''.join(new_parts)

# ── 쓰기 전 검증 ─────────────────────────────────────────────────────────────
# 🔴 실측 사고(2026-08-10): 검증 없이 쓴 결과가 **깨진 yaml**(미종료 인용 스칼라)이었고,
#   다음 실행의 `yaml.safe_load` 가 죽어 **stale 산출물로 재패치**되며 파일이 조용히 축소됐다.
#   ⇒ 파싱·컬럼수·모델수를 확인한 뒤에만 커밋한다(P118 확장).
import yaml as _y
try:
    _doc = _y.safe_load(res)
except Exception as e:
    ln = getattr(getattr(e, 'problem_mark', None), 'line', None)
    if ln is not None:
        for i in range(max(0, ln - 2), min(len(res.split('\n')), ln + 3)):
            print(f"  {i+1}: {res.split(chr(10))[i][:200]}")
    sys.exit(f"🔴 생성 결과가 유효한 yaml 이 아니다 — 쓰지 않고 중단: {e}")

_before = _y.safe_load(txt)
_nb = sum(len(m.get('columns') or []) for m in _before['models'])
_na = sum(len(m.get('columns') or []) for m in _doc['models'])
if len(_doc['models']) != len(_before['models']):
    sys.exit(f"🔴 모델 수 변동 {len(_before['models'])} → {len(_doc['models'])} — 중단")
print(f"검증 통과 — 모델 {len(_doc['models'])} · 컬럼 {_nb} → {_na}")

io.open(WYML, 'w', encoding='utf-8').write(res)
print(f"✅ 반영 {len(found)}모델 · 뷰 description 교체 {desc_n} · 파일 {len(res.encode('utf-8')):,}B")
