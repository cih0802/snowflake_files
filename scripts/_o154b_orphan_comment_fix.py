#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""_o154b_orphan_comment_fix.py — 「전량입고 후 제거」 폐기 문안을 일괄 정정한다.

[2026-09-10 O154-B · 승인 처리]

🔴 왜 스크립트인가
--------------------------------------------------------------------------
· `edit` 툴의 `replace_all` 이 이 파일에서 듣지 않았고(동일 문자열 6곳),
  대상 줄이 매우 길어 앵커 지정이 위험하다 ⇒ 지침 `R1-7-8` 이 명시한 예외 경로
  (*"행이 너무 길면 `edit` 대신 python 으로 줄 인덱스 지정 치환"*)를 쓴다.
· 🔴 `R1-7-9` 준수 = 본문을 **셸에 넣지 않는다.** 이 파일이 본문을 들고 있다.

🟢 안전 장치
--------------------------------------------------------------------------
① 치환 전 `snapshot_util` 로 스냅샷(단일 경로 · `R1-7-10`).
② **줄 번호가 아니라 「그 줄에 기대 문구가 실재하는가」로 판정**한다(좌표 드리프트 내성).
③ 기대 건수와 실제 건수가 다르면 **쓰지 않고 exit 1**.
④ 치환 후 되읽어 **폐기 문안 잔여 0** 을 단정한다.
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))

from snapshot_util import snapshot  # noqa: E402

LABEL = 'O154-B'
POLICY = ('🔴[2026-09-10 O154] 회원 마스터 고아 축 — **warn 영구 유지**(관측). '
          '종전 「전량입고 후 제거」는 폐기됐다: 입고 완료(1,763,065 3축 일치) 후에도 '
          '고아 7,658종/9,376행 잔존 · 전부 정상 형식 · 현업 「무시하고 파이프라인 구성」 지침. '
          '정본 = `_crm_schema.yml` 헤더 `MASTER-ORPHAN-POLICY`.')

#: (파일 상대경로, 찾을 문구, 바꿀 문구, 기대 건수)
#: 🔴 「찾을 문구」는 **주석 부분만** 잡는다 — `config:` 본체는 건드리지 않는다.
RULES = [
    ('10_dbt_pipeline/models/silver/crm/_crm_schema.yml',
     '# 순서9-B: 마스터 미완전 고아(warn). 전량입고 후 제거',
     '# ' + POLICY, 6),
    ('10_dbt_pipeline/models/silver/crm/_crm_schema.yml',
     '# 순서9-B: 마스터 미완전 고아 정책 일관(현재 고아 0, 예방적 warn). 전량입고 후 제거',
     '# ' + POLICY + ' ⚠️ 현재 고아 0 — 예방적 관측.', 2),
    ('10_dbt_pipeline/models/silver/crm/_crm_schema.yml',
     '# 순서9-B: 마스터 미완전 고아(warn, 고아 37). 전량입고 후 제거',
     '# ' + POLICY + ' ⚠️ 이 축 실측 고아 37.', 1),
    ('10_dbt_pipeline/models/silver/crm/_crm_schema.yml',
     '# 순서9-C: 발송요청 마스터 미완전(고아 9). warn. 전량입고 후 error 복귀.',
     '# 🔴[2026-09-10 O154] 발송요청 마스터 고아 9 — **warn 유지**. '
     '종전 「전량입고 후 error 복귀」는 회원 마스터 축 판정(헤더 `MASTER-ORPHAN-POLICY`)과 '
     '같은 이유로 **보류**한다: 회원 마스터가 전량입고돼도 고아가 남았다 ⇒ '
     '이 축도 입고만으로 0 이 된다고 단정할 수 없다. 🔴 승격 전 **재측정 필수**.', 1),
    ('10_dbt_pipeline/models/silver/crm/_crm_schema.yml',
     '# 회원→CRM_MEMBER relationships = severity:warn (마스터 미완전 고아, 순서9-B). '
     '마스터 전량입고 후 제거→error 복귀.',
     '# 회원→CRM_MEMBER relationships = severity:warn. '
     '🔴[2026-09-10 O154] 「마스터 전량입고 후 제거→error 복귀」 **폐기** — '
     '입고 완료 후에도 고아 잔존(정상 형식 · 비-cascade 삭제 잔번) · 현업 무시 지침. '
     '정본 = 헤더 `MASTER-ORPHAN-POLICY`.', 1),
    ('10_dbt_pipeline/models/silver/_silver_bridge_schema.yml',
     '# 순서9-B: 회원 마스터 미완전 고아 정책 일관(warn). 전량입고 후 제거→error 복귀',
     '# ' + POLICY, 1),
    ('10_dbt_pipeline/models/silver/bigquery/_bigquery_schema.yml',
     '# 순서9-B: 회원 마스터 미완전 고아 정책 일관(warn). 전량입고 후 제거',
     '# ' + POLICY, 1),
]

DEAD = ('전량입고 후 제거', '전량입고 후 error 복귀', '전량입고 후 제거→error 복귀')


def main():
    apply = '--apply' in sys.argv
    total_hits = 0
    plan = {}

    for rel, old, new, expect in RULES:
        path = os.path.join(ROOT, rel)
        with io.open(path, encoding='utf-8') as fh:
            text = fh.read()
        hits = text.count(old)
        mark = '🟢' if hits == expect else '🔴'
        print('%s %s' % (mark, rel))
        print('   찾음 %d건 · 기대 %d건' % (hits, expect))
        if hits != expect:
            print('   🔴 건수 불일치 — 쓰지 않았다. 문구를 다시 확인하라.')
            return 1
        total_hits += hits
        plan.setdefault(rel, []).append((old, new))

    print('')
    print('치환 대상 총 %d건 / 파일 %d개' % (total_hits, len(plan)))

    if not apply:
        print('⚪ dry-run — 적용하려면 --apply 를 주라.')
        return 0

    for rel, pairs in plan.items():
        path = os.path.join(ROOT, rel)
        snap, status = snapshot(path, 'orphanpolicy', label=LABEL)
        print('   스냅샷(%s) = %s' % (status, snap))
        with io.open(path, encoding='utf-8') as fh:
            text = fh.read()
        for old, new in pairs:
            text = text.replace(old, new)
        with io.open(path, 'w', encoding='utf-8', newline='') as fh:
            fh.write(text)

    # ④ 되읽어 폐기 문안 잔여 0 을 단정한다.
    #   🔴🔴 [O154-B 자기시정] 첫 판본은 `'폐기' not in line and '보류' not in line` 만 제외해
    #     **4건을 오탐**했다 — ㉠ 정책 헤더가 폐기 문안을 **인용**하는 줄(설명이 다음 줄에 있어
    #     줄 단위 판정으로는 안 보인다) ㉡ O116-3 의 「**기각**된다」 ㉢ O117 의 「**오진 + 영구 미충족**」.
    #   ⇒ `O111 ㉢`(판정 문구가 세는 것 ≠ 사람이 읽는 뜻)의 재발이다. 판정식을 **처방 여부**로 좁힌다:
    #     「폐기·기각·보류·미충족·실행하지 마라」 중 하나가 같은 줄에 있으면 **설명**이고 처방이 아니다.
    ACQUIT = ('폐기', '기각', '보류', '미충족', '실행하지 마라', '오진')
    bad = []
    for rel in plan:
        path = os.path.join(ROOT, rel)
        with io.open(path, encoding='utf-8') as fh:
            text = fh.read()
        for line in text.split('\n'):
            if not any(d in line for d in DEAD):
                continue
            if any(a in line for a in ACQUIT):
                continue          # 설명·인용 — 처방이 아니다
            bad.append('%s | %s' % (rel, line.strip()[:120]))

    print('')
    if bad:
        print('🔴 폐기 문안이 처방으로 남아 있다 %d건:' % len(bad))
        for b in bad:
            print('   · %s' % b)
        return 1
    print('🟢 적용 완료 — 폐기 문안 처방 잔여 0건')
    return 0


if __name__ == '__main__':
    sys.exit(main())
