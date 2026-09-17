#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""rename_stale_gate.py — **개명된 객체의 옛 이름이 살아있는 정본에 남아 있는가**를 판정한다.

[2026-09-10 O155 신설 · 11번 문서 §1-2 Phase 2 「도구가 보지 않는 축」의 집행 장치]

🔴 왜 이 게이트가 필요한가 — 게이트 11종이 전부 🟢 인데 531건이 남아 있었다
--------------------------------------------------------------------------
`03_top-down_gold/12_gold 테이블명 변경작업 근거` 가 GOLD 팩트·차원 **8종 개명**을 확정했다.
그런데 그 개명을 **감시하는 축이 어느 게이트에도 없었다**:

* `comment_drift_gate` = **파일 ↔ 라이브 해시 일치**만 본다 ⇒ 둘이 **똑같이 틀리면 🟢**.
  실물 = `SV_MEMBER_EVENT` COMMENT 가 파일·라이브 양쪽에서 `base: GOLD.FACT_MEMBER_EVENT`
  (라이브에 실재하지 않는 이름)를 가리켰고 드리프트 게이트는 0 을 냈다(O155 적발).
  🔴 SV COMMENT 는 **Cortex Analyst·Agent 의 컨텍스트**다 ⇒ 잘못된 표명이 AI 응답에 들어간다.
* `table_ddl_column_gate` = DDL ↔ dbt 모델의 **컬럼 집합·순서**만 본다(문서 문안은 분모 밖).
* `doc_coord_gate` = **파일 경로**의 실재만 본다(문서 안의 **객체 이름**은 보지 않는다).

⇒ 그래서 O154-B 가 문서 17·18 을 고치고 「무자격 잔여 0건」을 보고했는데, 그 판정의
   **분모는 5개 파일**이었다. 전 워크스페이스로 넓히면 **113파일 531건**이었다(O155 실측).
   🔴 이것이 `R3-9 ㉡`(같은 것을 다르게 재는 지점) + `O111 ㉠`(0건은 분모를 의심하라)의 결합 실물이다.

판정 축
--------------------------------------------------------------------------
* **축1 살아있는 정본(blocking)** — 수기 문서·코드·yml 에 옛 이름이 **병기 없이** 남았다.
* **축2 자동 생성 산출물(경고)** — 생성기 재실행으로 해소된다. 손으로 고치지 않는다.
* **축3 이력·승계 절(관측)** — `R1-3-6` 축. **소급 수정 대상이 아니다.**
* **축4 라이브 실재(blocking)** — 옛 이름 객체가 라이브에 남아 있는가(0 이어야 한다).
  🔴 이 축은 DB 접속이 필요하므로 `--live` 로만 돈다(기본은 파일 축만).

🟢 병기 판정 = **매치 지점 직전 문맥**을 본다(줄 전체 키워드가 아니다).
   경위 = O155 가 줄 전체 키워드로 판정해 `(구 FACT_SERVICE_EVENT)` 형태의 정상 병기를
   **dbt 코드 4건에서 오탐**했다 ⇒ `O111 ㉢` 의 실물. **판정식은 매치의 이웃을 봐야 한다.**

사용
--------------------------------------------------------------------------
    python3 scripts/rename_stale_gate.py              # 파일 축(축1~3)
    python3 scripts/rename_stale_gate.py --list       # 축1 위반 좌표 전건 열거
    python3 scripts/rename_stale_gate.py --baseline   # 현재 축1 건수를 기준선으로 발행

🔴 종료코드를 파이프 뒤에서 읽지 마라(`R0-8-2`) — `>/tmp/x.out 2>&1` 후 `rc=$?`.
"""
import argparse
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASELINE = os.path.join(ROOT, 'scripts', 'golden', 'rename_stale_baseline.json')

#: 개명 대응 — 정본 = `03_top-down_gold/12_gold 테이블명 변경작업 근거`
#: 🆕 🔴🔴 [2026-09-15 O164 분모 확장] `DEC-50`(O139 · 가공계층 GA→BIGQUERY 전면 전환)의
#:    **GOLD 개명 4종이 이 표에 없었다** ⇒ 그 개명 잔여는 이 게이트의 **검사 밖**이었다.
#:    실해 = `SV_SERVICE` 의 **라이브 COMMENT** 가 `WIDE_GA_BEHAVIOR` 를 가리키고 있었는데
#:    (라이브 실물 = `WIDE_BIGQUERY_BEHAVIOR`) 이 게이트가 **볼 축 자체를 갖지 않았다**.
#:    ⇒ `R3-9 ㉡`(같은 것을 다르게 재는 지점)의 실물이고, 적발한 것은
#:    `scripts/sv_comment_object_gate.py`(라이브 축)다.
#: ⚠️ `DEC-51`(GA_CONV_* → AGENCY_CONV_*)은 **여기 넣지 않았다** — 인수인계 §0-KKKK ▣KKKK4 가
#:    「GA 접두 유지 판정 · 재검 대상」으로 **열어 둔** 항목이다(결정 대기 중 배선 금지).
RENAMES = {
    # 🆕 🔴 [2026-09-16 O166-B] 이 항목은 **개명이 아니라 객체 소멸**이다 — 검출용 좌변은 유효하지만
    #   우변을 **치환 제안으로 읽으면 안 된다**(실측: `DIM_MEMBER` 는 1,785,299행 = 1행/회원이고
    #   상태버전 이력은 `DIM_MEMBER_STATUS_HISTORY` 8,069,279행 = 회원당 4.52행으로 **분리**됐다).
    #   ⇒ 문맥이 「현재행」이면 `DIM_MEMBER`, 「이력」이면 `DIM_MEMBER_STATUS_HISTORY` 로 **사람이 가른다.**
    #   🔴 기계 치환기(`_o166_rename_fix.py`)는 이 이름을 `MANUAL_ONLY` 로 제외한다(중복 키·자기모순 방지).
    'DIM_MEMBER_CURRENT': 'DIM_MEMBER',
    'FACT_MEMBER_LIFECYCLE': 'FACT_MEMBER_EVENT',
    'FACT_EVENT_PARTICIPATION': 'FACT_EVENT_ATTENDANCE',
    'FACT_SERVICE_EVENT': 'FACT_MESSAGE_DISPATCH',
    'FACT_TARGET_DEV': 'FACT_TARGET_MEMBER_DEV',
    'FACT_TARGET_BIZ': 'FACT_TARGET_PROJECT',
    'FACT_DEV_ACHIEVEMENT': 'FACT_MEMBER_DEV_ACHIEVEMENT',
    'FACT_MEMBER_SPONSOR_BIZ': 'FACT_MEMBER_SPONSORSHIP_SPAN',
    # 🆕 DEC-50 (2026-09-04 O139) — 라이브 실측으로 집행 확인(구 이름 4종 라이브 0건)
    'DIM_GA_EVENT': 'DIM_BIGQUERY_EVENT',
    'DIM_GA_SOURCE': 'DIM_BIGQUERY_SOURCE',
    'FACT_GA_BEHAVIOR': 'FACT_BIGQUERY_BEHAVIOR',
    'WIDE_GA_BEHAVIOR': 'WIDE_BIGQUERY_BEHAVIOR',
}
#: 🔴 경계 필수 — `FACT_TARGET_MEMBER_DEV` 안의 `FACT_TARGET_DEV` 오탐을 막는다.
RX = re.compile(r'(?<![0-9A-Za-z_])(%s)(?![0-9A-Za-z_])' % '|'.join(RENAMES))

#: 매치 직전 문맥에 있으면 「병기」 = 자격 있는 인용.
NEAR = ('구 ', '구(', '구:', '구·', '개명 전', '개명전', '옛 이름', '옛이름', '구 이름', '종전',
        '이전 이름', '레거시', 'legacy', '폐기', '기각', '(구', '·구')
#: 줄 자체가 대응표·개명 설명이면 병기로 인정한다.
#: 🆕 [2026-09-16 O166] 마커 5종 추가 — `scripts/` 편입으로 드러난 **정당한 인용 형태**다.
#:   ㉠ `개명 전 이름`·`개명·전환` = 병기 문구가 **매치 뒤쪽**에 오는 형태(`NEAR` 는 앞 24자만 본다)
#:   ㉡ `라이브 부재`·`라이브에 없다`·`객체 소멸` = **부재를 명시적으로 선언**하는 문장
#:      (게이트·근거 주석이 「이 이름은 이제 없다」를 말하려면 그 이름을 써야 한다)
LINE_OK = ('대응표', '변경작업 근거', '개명 사유', '개명 8종', '개명됐', '개명 반영',
           'RENAMES', 'rename_stale',
           '개명 전 이름', '개명·전환', '라이브 부재', '라이브에 없다', '객체 소멸')

EXT = ('.md', '.sql', '.yml', '.yaml', '.py', '.json', '.csv', '.txt')
SKIP_DIR = ('_archive', '__pycache__', '.git', '.snowflake', 'logs', 'target',
            'dbt_packages', 'erd', 'S1_CRM_entity_design_legacy')

#: 축3 = append형 이력·승계 절(소급 수정 대상 아님).
#: 🆕 [2026-09-16 O166] `scripts/` 편입에 맞춰 **일회성 세션 스크립트**를 여기 넣는다 —
#:   특정 세션의 패치·프로브·감사 실행기는 **그 시점의 기술**이고 소급 개명 대상이 아니다
#:   (`_o###_*` 는 아래 `EVIDENCE` 정규식이 이미 잡는다).
HIST = ('20_issue/01_세션이력', '99_NEXT_SESSION_조각', '20_issue/90_해소완료_로그',
        '20_issue/91_사고사례집', '60_repeat_어카운트시작',
        'scripts/o51d_view_comments/', 'scripts/o54_', 'scripts/o59l_', 'scripts/o125_',
        'scripts/patch_', 'scripts/run_o53_', 'scripts/gen_o53_')
#: 축2 = 자동 생성 산출물(재생성으로 해소).
#: 🆕 🔴🔴 [2026-09-16 O169 분류 정정] **골든·측정 스냅샷 json 을 여기서 뺐다**(아래 `SNAPSHOT` 로 이관).
#:   🔎 왜 = 이 버킷의 계약은 **「재생성으로 해소된다」**인데 그 json 들에는 **참이 아니었다**.
#:   실측 2건:
#:   ㉠ `golden/doc_headings.json` 의 옛 이름 7건 중 **6건이 골든 자신의 `_updates` 감사 이력**이다
#:      (*"[2026-09-16 O168] … 대응: FACT_TARGET_DEV→FA…"* = **개명을 기록한 문장**) ⇒ append-only 라
#:      재생성해도 남는다. 🔴 **개명을 기록한 문장이 개명 감시 게이트에 걸린다**(자기참조 계측).
#:   ㉡ `outputs.json` 의 옛 이름 77건 중 **62건이 `metrics/inv.entry_keys`** 이고 그 원천은
#:      **수기 문서** `03_top-down_gold/05_필드 인벤토리.md` 다(`test_generators.DOC_INV`) ⇒
#:      json 은 **정본에서 병기된 문장의 토큰만 복사**한다. 재생성은 그 복사를 되풀이할 뿐이다.
#:   🟢 판정식 = **「그 버킷의 처방이 그 파일에 통하는가」로 분류하라** — 생성 여부가 아니라 **처방**이 축이다.
GEN = ('02_SILVER 스키마 컬럼 인벤토리', '02_gold 스키마 컬럼 인벤토리', '04_컬럼계보매핑',
       '05_지표GOLD매핑', '06_BRONZE노출감사', '08_SILVER→GOLD_보존율',
       '09_보고서필드_조립가능성', '09_섹션배너', '11_미해결이슈_요약',
       '07_코드체계_관문측정', '00_BRIEF.md', '92_실측필요_후속작업')
#: 🆕 🔴 [2026-09-16 O169 신설] **골든·측정 스냅샷** = 정본 텍스트를 그대로 복사한 파생물이고
#:   그 원문은 정본에서 **이미 병기돼 있다** ⇒ **소급 수정 대상이 아니다**(축3 과 같이 취급).
#:   🔴 손으로 고치지 마라(`R1-7-4`) · 🔴 재생성으로도 사라지지 않는다(위 GEN 주석 참조).
#:   🟢 이 파일들의 개명 반영은 **정본이 고쳐지면 다음 발행에서 따라온다**(감사 이력은 영구 보존).
SNAPSHOT = ('scripts/golden/', 'scripts/outputs.json', 'scripts/doc_headings.json',
            'scripts/index_rows.json')
#: 🟢 세션 근거철 = 발행 후 갱신하지 않는 정적 발행물 ⇒ 축3 과 같이 취급한다.
EVIDENCE = re.compile(r'/_o\d+[a-z]*_')

#: 🆕 🔴🔴 [2026-09-16 O166] **자기참조·픽스처 제외.** `scripts/` 를 분모에 넣으면 두 종류가
#:   구조적으로 오탐된다 — 둘 다 **옛 이름이 있어야 정상 동작**하는 파일이다:
#:   ㉠ **이 게이트 자신**(`RENAMES` 대응표의 키가 곧 옛 이름이다)
#:   ㉡ **음성 테스트**(옛 이름을 픽스처로 심어 검출을 단정한다 · 고치면 테스트가 무력해진다)
#:   🔴 이 제외는 `qualified()` 의 「병기」와 다른 축이다 — 줄 문맥이 아니라 **파일 역할**로 가른다
#:   (O165 `D5` 가 *"가르는 것은 파일의 역할이 아니라 줄 위치다"* 라고 정정한 것과 방향이 반대인데,
#:    그쪽은 **문서·주석 표기**를 가르는 문제였고 이쪽은 **파일의 존재 목적**이 옛 이름 보유다).
SELF_REF = ('scripts/rename_stale_gate.py', 'scripts/test_', 'scripts/_o166_rename_fix.py')

#: 🆕 🔴🔴 [2026-09-16 O166 분모 확장] `scripts/` 가 이 분모에 **없었다.**
#:   실해 = `gen_section_assembly.SRC_SYS` 등 **판정 등록부의 키**가 개명 전 이름이라
#:   `SRC_SYS.get()` 이 `?` 를 돌리고 `09_보고서필드_조립가능성` 의 **타원천 18건이 전건 오판**이었다
#:   (실측 = 타원천 18/18 이 `=?` 경유 · 개명 잔여 343건/51파일이 검사 밖).
#:   🔴 이것은 `R1-6-18 ④`(분모 편입)·O165 `D11` 과 **같은 형태의 재발**이다 —
#:   게이트가 없어서가 아니라 **분모가 좁아서** 조용했다.
#:   🔴 그리고 O165 `D5` 의 판정 *"축1 잔여는 전건 문서·주석 표기"* 는 **이 분모 상태의 판정**이었다
#:   ⇒ `scripts/` 를 넣으면 **실행 의미를 가진 코드**가 잔여에 포함된다(그 판정은 정정 대상).
SCAN_DIRS = ('30_output_share', '03_top-down_gold', '05_SV-Agent_ai', '10_dbt_pipeline',
             '04_silver_design', '20_issue', '99_NEXT_SESSION_조각', '00_guides',
             'cortex_project', '60_repeat_어카운트시작', '02_GN_DW_building', 'scripts')


#: 🆕 [2026-09-16 O168] 「`구이름` → `새이름`」 인접 = **병기의 정형**이다.
#:   🔴 왜 추가했나 = `30_설계_의사결정-016.md:81~83` 이 *"`DIM_GA_EVENT` → `DIM_BIGQUERY_EVENT`"* 로
#:   개명 자체를 선언하는 줄인데 축1 위반으로 셌다. 그 줄에서 옛 이름을 지우면 **결정 기록이 사라진다.**
#:   🔴 형태 = `O111 ㉢`(정상 병기 오탐)의 재발이고, `LINE_OK` 가 「개명」 관련 **문구 목록**이라
#:   *"(FK 및 컬럼명 개명)"* 같은 변형을 못 잡은 것이 원인이다 ⇒ **문구 목록이 아니라 구조로 판정한다.**
#:   🟢 좁은 판정 = 매치가 **자기 자신의 새 이름과** 화살표로 직접 이어져야 한다(창 12자).
#:   ⇒ 아무 화살표나 면제하지 않는다(`_o166_rename_fix` 의 O168 결함과 대칭으로 방지).
ARROW_PAIR = r'(?:→|⇒|->)'


def arrow_paired(line, name):
    """`name` 이 자신의 새 이름과 화살표로 직접 이어져 있는가(= 개명 선언 줄)."""
    new = RENAMES[name]
    return bool(re.search(r'%s.{0,12}?%s.{0,12}?%s' % (name, ARROW_PAIR, new), line)
                or re.search(r'%s.{0,12}?%s.{0,12}?%s' % (new, ARROW_PAIR, name), line))


def qualified(line, start, name=None):
    if any(k in line for k in LINE_OK):
        return True
    if name and arrow_paired(line, name):
        return True
    return any(k in line[max(0, start - 24):start] for k in NEAR)


def bucket(rel):
    if any(s in rel for s in SELF_REF):
        return 'HIST'
    if any(h in rel for h in HIST) or EVIDENCE.search('/' + rel):
        return 'HIST'
    # 🆕 [2026-09-16 O169] 골든·측정 스냅샷 = 정본 병기 문장의 복사물 ⇒ 소급 수정 대상 아님.
    #   🔴 `GEN` 보다 먼저 본다 — `scripts/golden/rename_stale_baseline.json` 처럼
    #   두 축에 다 걸릴 수 있는 경로에서 **처방이 통하는 쪽**을 택해야 한다.
    if any(s in rel for s in SNAPSHOT):
        return 'HIST'
    if any(g in rel for g in GEN):
        return 'GEN'
    return 'LIVE'


def scan():
    hits = {'LIVE': [], 'GEN': [], 'HIST': []}
    ok = scanned = 0
    for d in SCAN_DIRS:
        base = os.path.join(ROOT, d)
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [x for x in dirnames if x not in SKIP_DIR]
            for fn in filenames:
                if not fn.endswith(EXT):
                    continue
                path = os.path.join(dirpath, fn)
                scanned += 1
                try:
                    text = io.open(path, encoding='utf-8', errors='replace').read()
                except Exception:
                    continue
                if not RX.search(text):
                    continue
                rel = os.path.relpath(path, ROOT)
                b = bucket(rel)
                for i, line in enumerate(text.split('\n'), 1):
                    for m in RX.finditer(line):
                        if qualified(line, m.start(), m.group(1)):
                            ok += 1
                        else:
                            hits[b].append((rel, i, m.group(1)))
    return hits, ok, scanned


def load_baseline():
    if not os.path.exists(BASELINE):
        return None
    with io.open(BASELINE, encoding='utf-8') as fh:
        return json.load(fh)


def main():
    ap = argparse.ArgumentParser(prog='rename_stale_gate.py')
    ap.add_argument('--list', action='store_true', help='축1 위반 좌표를 전건 열거')
    ap.add_argument('--baseline', action='store_true',
                    help='현재 축1 건수를 기준선으로 발행(증가 감시 모드로 전환)')
    ap.add_argument('--reason', default='', help='기준선 발행 사유(필수 권장)')
    a = ap.parse_args()

    hits, ok, scanned = scan()
    live, gen, hist = hits['LIVE'], hits['GEN'], hits['HIST']
    lf = len({h[0] for h in live})

    print('[개명 잔여 게이트] 스캔 %d파일 · 개명 대응 %d종' % (scanned, len(RENAMES)))
    print('  🟢 병기(자격 있는 인용): %d건' % ok)
    print('  🔴 축1 살아있는 정본: %d건 / %d파일' % (len(live), lf))
    print('  🟠 축2 자동 생성 산출물(재생성으로 해소): %d건' % len(gen))
    print('  ⚪ 축3 이력·승계 절·근거철(소급 수정 대상 아님): %d건' % len(hist))

    if a.list:
        print('')
        print('  [축1 위반 좌표]')
        per = {}
        for rel, ln, name in live:
            per.setdefault(rel, []).append((ln, name))
        for rel in sorted(per, key=lambda r: -len(per[r])):
            print('    %s (%d건)' % (rel, len(per[rel])))
            for ln, name in per[rel][:6]:
                print('        :%d  %s → %s' % (ln, name, RENAMES[name]))
            if len(per[rel]) > 6:
                print('        … 외 %d건' % (len(per[rel]) - 6))

    if a.baseline:
        os.makedirs(os.path.dirname(BASELINE), exist_ok=True)
        files = {}
        for rel, ln, name in live:
            files[rel] = files.get(rel, 0) + 1
        with io.open(BASELINE, 'w', encoding='utf-8', newline='') as fh:
            json.dump({'axis1_total': len(live), 'axis1_files': len(files),
                       'per_file': files, 'reason': a.reason}, fh,
                      ensure_ascii=False, indent=1, sort_keys=True)
        print('')
        print('✅ 기준선 발행 — 축1 %d건 / %d파일 → %s'
              % (len(live), len(files), os.path.relpath(BASELINE, ROOT)))
        print('   사유 = %s' % (a.reason or '(미기재 · 🔴 다음에는 적어라)'))
        return 0

    base = load_baseline()
    print('')
    if base is None:
        print('🔴 FAIL — 기준선이 없다. `--baseline --reason "<사유>"` 로 현재 상태를 발행하라.')
        print('   ⚠️ 발행은 「해소」가 아니다 — **증가를 막는 장치**다(잔여는 백로그로 남는다).')
        return 1

    prev = base.get('axis1_total', 0)
    print('  기준선 축1 = %d건 · 현재 = %d건 (증감 %+d)' % (prev, len(live), len(live) - prev))
    if len(live) > prev:
        newf = {h[0] for h in live} - set(base.get('per_file', {}))
        print('')
        print('🔴 FAIL — 개명 전 이름이 **늘었다**(신규 파일 %d개).' % len(newf))
        for rel in sorted(newf)[:10]:
            print('     🔴 %s' % rel)
        print('   🟢 처방 = 그 자리에 현행명을 쓰거나 `(구 X)` 로 병기하라.')
        return 1

    if len(live):
        print('')
        print('🟡 통과(증가 0) — 🔴 그러나 축1 잔여 %d건은 **미해소 백로그**다.' % len(live))
        print('   🔴 「게이트 통과」를 「개명 반영 완료」로 읽지 마라(`O111 ㉠`).')
        print('   🟢 해소 진척은 `--baseline` 을 다시 발행해 기준선을 **내리는** 것으로 증명한다.')
        return 0

    print('🟢 PASS — 살아있는 정본 축1 잔여 0건')
    return 0


if __name__ == '__main__':
    sys.exit(main())
