#!/usr/bin/env python3
"""audit_ddl_rule7 음성 테스트 — 규칙7 수치 검출의 오탐/무력화를 양방향으로 단정한다.

🔴 왜 필요한가 (R3-2):
  O120 이 `WHITE` 에 서수형 라벨 접미(`유형1`·`타입2`)를 추가했다. 예외를 넓히는 편집은
  **무력화 위험**을 동반한다(`▣ZZZ6 ㉦`) ⇒ 「오탐이 사라졌다」와 「진짜 위반은 여전히 잡힌다」를
  **둘 다** 단정해야 한다. 정상 입력만으로는 어느 쪽도 검증되지 않는다.

🔴 이 테스트는 라이브에 접속하지 않는다 — `hits_for()` 순수 함수만 검사한다.
"""
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import audit_ddl_rule7 as G  # noqa: E402

FAIL = []
N = 0


def check(label, cmt, want_hit):
    """want_hit=True  ⇒ 위반으로 잡혀야 한다
       want_hit=False ⇒ 잡히지 않아야 한다"""
    global N
    N += 1
    hits = G.hits_for(cmt)
    got = bool(hits)
    if got != want_hit:
        FAIL.append(f"{label}: 기대 {'검출' if want_hit else '면제'} · 실제 "
                    f"{'검출' if got else '면제'} {hits} · 입력={cmt!r}")


print('=' * 74)
print('축1 — O120 이 제거한 오탐 2건 (서수형 라벨 접미)')
print('=' * 74)
# 실물 = SILVER.CRM_MEMBER_DEV 두 컬럼의 라이브 COMMENT 선두절
check('유형1명', '캠페인 유형1명 (MM295 라벨): 국내 / 통합 / 해외. CRM_CAMPAIGN 비정규화', False)
check('유형2명', '캠페인 유형2명 (MM296 라벨): 굿즈 / 기타 / 사례 / 사업. CRM_CAMPAIGN 비정규화', False)
check('타입1명', '타입1명 라벨', False)
print(f'  단정 {N}건')

_b = N
print()
print('=' * 74)
print('축2 — 무력화 아님 (예외를 넓혔지만 진짜 위반은 여전히 잡힌다)')
print('=' * 74)
# 🔴 단독 소규모 실측치
check('3명 단독', '대상 3명', True)
check('504행 단독', '정본 컬럼정의서 504행 현업 용어쌍', True)
check('366행', '적재 366행', True)
# 🔴 유형 뒤에 붙었더라도 **다른 수치**가 따로 있으면 잡혀야 한다
check('유형1 + 별도수치', '캠페인 유형1명. 적재 218,402행', True)
# 🔴 형제 패턴 회귀
check('천단위', '218,402행 적재', True)
check('백분율', '커버리지 89.7%', True)
check('배수', '팬아웃 181.6배', True)
print(f'  단정 {N - _b}건')

_b2 = N
print()
print('=' * 74)
print('축2-B — 🔴 선재 검출 공백을 **명시적으로 단정**한다 (O120 발견 · 미시정)')
print('=' * 74)
# 🔴🔴 [2026-08-29 O120 발견 · O120 편집과 무관한 선재 결함]
#   소규모 패턴이 `…(?:행|건|명|원)\b` 로 끝나는데 한글 조사(이·은·는·을·의·에)는
#   Python `\w` 에 속하므로 **단위어 뒤에 조사가 붙으면 `\b` 가 성립하지 않아 놓친다.**
#   ⇒ 「3건이」·「504행에」·「28건이」는 진짜 실측치인데도 검출되지 않는다.
#
#   🟢 영향 실측(O120 · 정본 DDL 2,741 COMMENT) = `\b` → `(?![0-9])` 로 바꾸면
#      검출 6 → 16(+10). 그 10곳의 내역 =
#        · 진짜 위반 5 = `499행`(smart tv) · `3건`(검출된 3건) · `8행`(미매칭)
#                        · `28건`(공동후원 쌍) · `6건`(신규사건)
#        · 신규 유형 오탐 5 = `1행사`(1행+사) · `3원천`(3원+천) · `2-2 원천`(절 참조)
#                            · `1명당`(grain 정의) — **신규 예외 4종이 필요하다**
#   🔴 그래서 O120 은 바꾸지 않았다 — 예외를 급히 넓히면 무력화 위험이 있다(`▣ZZZ6 ㉦`).
#   🔴 **아래 단정은 「이 동작이 옳다」가 아니라 「현재 이렇게 동작한다」다.**
#      고치는 세션은 이 축이 FAIL 하므로 **반드시 이 주석과 함께 갱신하게 된다**(공백의 비가시화 방지).
check('조사 붙은 건(현행 미검출)', '검출된 3건은 전부 편집주석', False)
check('조사 붙은 행(현행 미검출)', '미매칭 8행은 0 라벨', False)
check('조사 붙은 명(현행 미검출)', '대상 3명이 실재한다', False)
# 🟢 단 조사가 없으면(공백·문장끝·마침표) 정상 검출된다 — 공백이 완전하지 않다는 증거
check('공백 뒤 건(검출됨)', '검출된 3건 은 전부', True)
print(f'  단정 {N - _b2}건')


_c = N
print()
print('=' * 74)
print('축2-C — O120 이 제거한 오탐 1건 (월↔연 환산 상수) + 무력화 아님')
print('=' * 74)
# 🔴 실물 = FACT_BUDGET_YEARLY 테이블 COMMENT (달력 상수 · 적재량 무관)
check('SUM 이 12배(면제)', 'FACT_BUDGET 은 월 grain 이라 연 총액을 담으면 SUM 이 12배가 된다', False)
check('SUM 이 **12배**(면제)', '월 팩트에 채우면 SUM 이 **12배** 부푼다', False)
# 🔴 무력화 아님 — 문맥 없는 배수는 실측 팬아웃일 수 있으므로 여전히 잡힌다
check('맨 12배(검출)', '실측 팬아웃 12배', True)
check('다른 배수(검출)', '실측 팬아웃 181.6배', True)
print(f'  단정 {N - _c}건')


_d = N
print()
print('=' * 74)
print('축3 — 기지 예외 회귀 (NUM_EXEMPT 공유 · 적재량과 무관한 문안)')
print('=' * 74)
check('N종', '실제값 2종: 지출 / NULL', False)
check('grain 정의', 'grain = 1행=1회원', False)
check('논리 공집합', '이 값으로 필터하면 0행이 나온다', False)
check('100%', '채움 100%', False)
print(f'  단정 {N - _d}건')

_e = N
print()
print('=' * 74)
print('축4 — WHITE 기존 축 회귀 (코드값·지표번호·규약상수)')
print('=' * 74)
check('코드그룹', '라벨은 MM295 를 쓴다', False)
check('지표번호', '정본 공#38 감액', False)
check('규약상수', '감액(건) = 금액÷10,000', False)
check('연령대', '10대 미만이 최다', False)
check('타입선언', 'NUMBER(38,0) 컬럼', False)
check('절참조', '(정본 §3 건·명)', False)
print(f'  단정 {N - _e}건')

print()
print('=' * 74)
if FAIL:
    print(f'🔴 FAIL {len(FAIL)}건 / 단정 {N}건')
    for f in FAIL:
        print(f'   · {f}')
    sys.exit(1)
print(f'🟢 PASS — 단정 {N}건 전건 통과 (오탐 제거 + 무력화 아님 양방향 단정)')
