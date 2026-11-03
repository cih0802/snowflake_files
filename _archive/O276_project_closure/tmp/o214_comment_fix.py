#!/usr/bin/env python3
"""O214 — 7차(O213) 신설 COMMENT 의 규약 위반 시정 (05_0 COMMENT 규약 1·3·4).

대상 = 라이브 도달 문자열만(`--` 주석 줄 · VERIFIED_BY 줄 제외).
  ㉠ 규약4 세션 태그 = `🆕 [O213…] ` 접두 · `SV(🆕 O213…)` · SLRCLD 정정 경위 문장
  ㉡ 규약1·3 개수 표기 `N종` → 실측 원값 열거(저카디널리티) 또는 삭제
사용: python3 tmp/o214_comment_fix.py          # dry-run (변경 줄 수만)
      python3 tmp/o214_comment_fix.py --apply  # 파일 쓰기
Co-authored with CoCo
"""
import glob
import io
import re
import sys

FILES = (sorted(glob.glob('/workspace/05_SV-Agent_ai/05_*_SV_DDL_*.sql'))
         + ['/workspace/05_SV-Agent_ai/23_MSTR_SV_DDL.sql',
            '/workspace/03_top-down_gold/06_DDL.sql',
            '/workspace/04_silver_design/08_SILVER_테이블DDL_20260714.sql'])

TAG_PREFIX = re.compile(r'🆕 \[O213[^\]]*\] ?')
TAG_SV = re.compile(r' ?\(🆕 O213[^)]*\)')
SLRCLD = re.compile(r' 🔴 \[O213-D 정정\] 종전 「급여공제」는 오기였다\(BRONZE 원천 COMMENT = 양력음력코드 · CM029 라벨 실측\)\.')

# (줄에 있어야 하는 표지, 바꿀 토큰, 대체) — 원값은 2026-10-08 라이브 DISTINCT 실측(DIM_BUDGET_ITEM · ERP_EXPENSE_RESOLUTION)
COUNT_FIX = [
    ('「장」', '원값 4종', '원값 = 모금비·사업비·사회복지법인예산·일반관리비'),
    ('「관」', '원값 6종', '원값 = 국내사업비·나눔문화연구사업·모금비·사회복지법인예산·일반관리비·해외사업비'),
    ('「항」', '원값 9종', '원값 = 국내아동권리지원사업·기획및연수인력사업·나눔문화연구사업·모금관리비·'
                         '사무국운영사업·사회복지법인예산·해외기획사업·해외아동권리지원및지역개발사업·회원관리비'),
    ('재원명', '원값 8종', '원값 = 국내지정·법인전입·비지정일반·사회복지법인예산·이월국내지정·이월비지정일반·이자수익·잡수익'),
    ('출처구분명', '(6종 원값)', '(원값 = 가지급금정산서·구매품의·기안서·대체결의·외화출장품의서·품의서)'),
    ('결의부서명', '(55종 원값)', '(원값)'),
    ('재원명', '(26종 원값)', '(원값)'),
    ('환급사유명', 'PM042 라벨 11종', 'PM042 라벨'),
]


def fix_line(line):
    s = line.lstrip()
    if s.startswith('--') or 'VERIFIED_BY' in line or "COMMENT" not in line:
        return line
    new = TAG_PREFIX.sub('', line)
    new = TAG_SV.sub('', new)
    new = SLRCLD.sub('', new)
    for mark, tok, rep in COUNT_FIX:
        if mark in new and tok in new:
            new = new.replace(tok, rep)
    return new


def main():
    apply = '--apply' in sys.argv
    total = 0
    for f in FILES:
        src = io.open(f, encoding='utf-8').read()
        lines = src.split('\n')
        out = [fix_line(x) for x in lines]
        n = sum(1 for a, b in zip(lines, out) if a != b)
        if n:
            total += n
            print(f'{n:4d}  {f}')
            if apply:
                io.open(f, 'w', encoding='utf-8', newline='').write('\n'.join(out))
    print(f'변경 줄 합계 = {total} · {"APPLY" if apply else "DRY-RUN"}')


if __name__ == '__main__':
    main()
