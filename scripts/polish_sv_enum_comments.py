# -*- coding: utf-8 -*-
"""[2026-08-11 O59-B] 열거 삽입 후처리 — ① 문장 접합부 마침표 ② 오염값 고지.

① 기계 삽입은 기존 문장 끝에 그대로 이어붙는다 —
   `… 라벨은 MEMBER_STATUS_NAME(숫자 접두 없음) 실제값 12종: …` 처럼 문장이 붙는다.
   의미·파싱에는 영향이 없지만 COMMENT 는 **Analyst 가 읽는 문장**이므로 경계를 준다.
   ⚠️ 앞 문자가 이미 문장부호면 건드리지 않는다(중복 마침표 방지).

② 🔴 `CM_POSITION` 열거에 **오염값이 실려 나갔다** — 실측: 백틱 1문자(ASCII 96) **1행**.
   열거 자체는 사실이므로 지우지 않는다(문안이 거짓이 되면 ① 검사가 잡는다).
   대신 **오염값임을 명시**해 Analyst 가 정상 코드로 오인하지 않게 한다.
   ⚠️ 데이터 자체의 정정은 이 스크립트의 범위가 아니다(원장 등재 → 파이프라인 소관).
"""
import io, re, os, sys

ROOT = '/workspace/05_SV-Agent_ai'
FILES = [f'05_{i}_SV_DDL_{n}.sql' for i, n in [
    (1, 'MEMBER_MONTHLY'), (2, 'MEMBER_EVENT'), (3, 'MEMBER_COHORT'), (4, 'SERVICE'),
    (5, 'EVENT_PARTICIPATION'), (6, 'BUDGET'), (7, 'AD'), (8, 'DEV_ACHIEVEMENT'),
    (9, 'MEMBER_FEE')]]

# 앞 문자가 문장부호·공백·중점이 아니면 마침표를 넣는다.
JOIN = re.compile(r'([^\s.。!?:·、,])( 실제값 \d+종:)')

CONTAM_NOTE = ("·''`''(🔴 **오염값** — 백틱 1문자 1행 · 정상 CM 위치가 아니다. "
               "이 값으로 필터하지 말고, CM 위치별 집계 시 이 1행은 무의미하다)")


def main():
    apply = '--apply' in sys.argv
    tot_join, tot_contam = 0, 0
    for fn in FILES:
        p = os.path.join(ROOT, fn)
        src = io.open(p, encoding='utf-8').read()
        orig = src

        src, n = JOIN.subn(r'\1.\2', src)
        tot_join += n

        # ② 오염값 고지 — `CM_POSITION` 열거의 백틱 항목에 주석을 붙인다(이미 붙었으면 건너뜀).
        c = 0
        if "''`''" in src and '오염값' not in src.split('CM_POSITION')[-1][:400]:
            before = src
            src = src.replace("실제값 16종: ''`''", "실제값 16종: " + CONTAM_NOTE.lstrip('·'), 1)
            c = 1 if src != before else 0
        tot_contam += c

        if src != orig:
            print(f"  ✅ {fn}: 마침표 {n}건 · 오염고지 {c}건")
            if apply:
                io.open(p, 'w', encoding='utf-8').write(src)
        else:
            print(f"  ⚪ {fn}: 변경 없음")
    print(f"  ⇒ 마침표 {tot_join}건 · 오염고지 {tot_contam}건 · {'적용' if apply else 'DRY-RUN'}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
