#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""_o155_rename_scan.py — GOLD 개명 8종의 **옛 이름 잔여**를 전수 스캔한다.

[2026-09-10 O155 점검 · 11번 문서 §1-2 Phase 2 「같은 축의 다른 곳」 판정식]

🔴 왜 필요한가
--------------------------------------------------------------------------
O154-B 가 문서 17·18·20 의 개명 stale 13곳을 고쳤다. 그러나 `O117` 의 교훈
(*"축을 하나 고칠 때 같은 축의 다른 테이블 주석도 같이 고쳐라 — O116-B 가 5곳을 고치며
1곳을 빠뜨려 기각된 처방이 코드에 살아 있었다"*)이 정확히 이 상황을 경고한다.
⇒ **17/18/20 밖에 남은 옛 이름이 있는가**를 기계로 판정한다.

🔴 BusyBox grep 은 `--include` 가 없고 `_archive/` 는 분모가 커서 timeout 무성 0건
   함정(`R0-8`)에 빠진다 ⇒ 파이썬으로 확장자·경로를 직접 통제한다.

판정 축
--------------------------------------------------------------------------
* 축1 **무자격 잔여**(blocking) = 옛 이름이 나오는데 같은 줄에 **개명 병기 표시가 없다**.
* 축2 **자격 있는 병기**(관측) = 같은 줄에 `개명 전`·`옛 이름`·`→` 대응 표기가 있다.
🟢 `_archive/`·`__pycache__`·`.git` 은 제외한다(은퇴본은 소급 수정 대상이 아니다).
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

OLD = ['FACT_MEMBER_EVENT', 'FACT_SERVICE_EVENT', 'FACT_TARGET_DEV', 'FACT_TARGET_BIZ',
       'FACT_DEV_ACHIEVEMENT', 'FACT_EVENT_PARTICIPATION', 'FACT_MEMBER_SPONSOR_BIZ',
       'DIM_MEMBER_CURRENT']
#: 🔴 접두 경계를 둔다 — `FACT_TARGET_MEMBER_DEV` 가 `FACT_TARGET_DEV` 로 잡히면 안 되고
#:   `FACT_MEMBER_DEV_ACHIEVEMENT` 가 `FACT_DEV_ACHIEVEMENT` 로 잡히면 안 된다.
RX = re.compile(r'(?<![0-9A-Za-z_])(%s)(?![0-9A-Za-z_])' % '|'.join(OLD))

#: 🔴🔴 [O155 자기시정 2회차] 「병기」 판정은 **줄 전체 키워드**로 하면 안 된다.
#   1차 판정식은 줄에 `→`·`종전` 같은 토큰이 있으면 통과시켰는데, 그 토큰이 **다른 문맥**일 수 있다.
#   반대로 이 워크스페이스의 실제 병기 관례인 **`(구 FACT_SERVICE_EVENT)`** 는 목록에 없어
#   dbt 코드 4건이 전부 **오탐**으로 잡혔다(`dbt_project.yml`·`WIDE_MEMBER_FEE.sql` 등).
#   ⇒ 🟢 판정을 **매치 지점의 앞 문맥**으로 좁힌다(줄 전체가 아니라 직전 24자).
#     이것이 `O111 ㉢` 의 세 번째 실물이다 — **판정식은 매치의 이웃을 봐야 한다.**
NEAR = ('구 ', '구(', '개명 전', '개명전', '옛 이름', '옛이름', '구 이름', '종전', '이전 이름',
        '레거시', 'legacy', '폐기', '기각')
#: 줄 어디에 있어도 병기로 인정하는 것 = 그 줄 자체가 「대응표 행」인 경우.
LINE_OK = ('대응표', '변경작업 근거', '개명 사유', '→ **`', '개명 8종', '개명됐')


def qualified(line, start):
    """매치 위치 `start` 기준으로 **병기 여부**를 판정한다."""
    if any(k in line for k in LINE_OK):
        return True
    head = line[max(0, start - 24):start]
    return any(k in head for k in NEAR)


EXT = ('.md', '.sql', '.yml', '.yaml', '.py', '.json', '.csv', '.txt')
SKIP_DIR = ('_archive', '__pycache__', '.git', '.snowflake', 'logs', 'target',
            'dbt_packages', 'erd')


def walk(base):
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIR]
        for fn in filenames:
            if fn.endswith(EXT):
                yield os.path.join(dirpath, fn)


def main():
    targets = sys.argv[1:] or ['30_output_share', '03_top-down_gold', '05_SV-Agent_ai',
                               '10_dbt_pipeline', '04_silver_design', '20_issue',
                               '99_NEXT_SESSION_조각', '00_guides', 'cortex_project',
                               '60_repeat_어카운트시작']
    bad, ok, scanned = [], 0, 0
    for t in targets:
        base = os.path.join(ROOT, t)
        if not os.path.isdir(base):
            print('⚪ 경로 없음 — %s' % t)
            continue
        for path in walk(base):
            scanned += 1
            try:
                text = io.open(path, encoding='utf-8', errors='replace').read()
            except OSError as exc:
                print('🔴 읽기 실패 %s — %s' % (path, exc))
                return 2
            if not RX.search(text):
                continue
            rel = os.path.relpath(path, ROOT)
            for i, line in enumerate(text.split('\n'), 1):
                for m in RX.finditer(line):
                    if qualified(line, m.start()):
                        ok += 1
                    else:
                        bad.append((rel, i, m.group(1), line.strip()[:110]))

    print('[GOLD 개명 잔여 스캔] 스캔 %d파일 · 대상 옛 이름 %d종' % (scanned, len(OLD)))
    print('  축2 병기(자격 있는 인용 · 관측): %d건' % ok)
    print('  축1 무자격 잔여(총): %d건' % len(bad))
    print('')

    # 🔴🔴 [O155 자기시정] 총건수는 판정이 아니다 — **성격별로 갈라야** 처방이 갈린다.
    #   ㉠ 살아있는 정본(수기 문서·코드·yml) = 🔴 **고쳐야 한다**
    #   ㉡ append형 이력·승계된 인수인계 절 = ⚪ **소급 수정 대상이 아니다**(`R1-3-6` 축)
    #   ㉢ 자동 생성 산출물(CSV·MD 인벤토리) = 🟠 **재생성으로 해소**한다(손으로 고치지 않는다)
    HIST = ('20_issue/01_세션이력', '99_NEXT_SESSION_조각', '20_issue/90_해소완료_로그',
            '20_issue/91_사고사례집', '60_repeat_어카운트시작')
    GENERATED = ('02_SILVER 스키마 컬럼 인벤토리', '02_gold 스키마 컬럼 인벤토리',
                 '04_컬럼계보매핑', '05_지표GOLD매핑', '06_BRONZE노출감사',
                 '08_SILVER→GOLD_보존율', '09_보고서필드_조립가능성', '09_섹션배너',
                 '11_미해결이슈_요약', '07_코드체계_관문측정')

    def bucket(rel):
        if any(h in rel for h in HIST):
            return 'HIST'
        if any(g in rel for g in GENERATED):
            return 'GEN'
        return 'LIVE'

    counts = {'LIVE': {}, 'GEN': {}, 'HIST': {}}
    for rel, ln, name, snip in bad:
        b = bucket(rel)
        counts[b][rel] = counts[b].get(rel, 0) + 1

    label = {'LIVE': '🔴 살아있는 정본 — 고쳐야 한다',
             'GEN': '🟠 자동 생성 산출물 — 재생성으로 해소',
             'HIST': '⚪ 이력·승계 절 — 소급 수정 대상 아님'}
    for b in ('LIVE', 'GEN', 'HIST'):
        tot = sum(counts[b].values())
        print('  %s : %d건 / %d파일' % (label[b], tot, len(counts[b])))
        for rel in sorted(counts[b], key=lambda r: -counts[b][r]):
            print('     %5d  %s' % (counts[b][rel], rel))
        print('')

    live = sum(counts['LIVE'].values())
    if live:
        print('🔴 FAIL — 살아있는 정본에 개명 전 이름이 병기 없이 남아 있다 %d건' % live)
        return 1
    print('🟢 PASS — 살아있는 정본 무자격 잔여 0건')
    return 0


if __name__ == '__main__':
    sys.exit(main())
