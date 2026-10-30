#!/usr/bin/env python3
"""`sv_enum_newvalue_gate` 음성 테스트(`R3-2`) — 오염 축(잡아야 한다) + 역방향 오탐 축(잡으면 안 된다). rc = 실패 건수>0 ⇒ 1."""
import sys
sys.path.insert(0, '/workspace/scripts')
import sv_enum_newvalue_gate as g

fails = 0


def check(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(('✅' if ok else '❌'), name, '· got', got, '· want', want)


# 오염 축 — 반드시 잡는다
check('종수 잔존', g.stale_count("코드. 실제값 4종: ''A''"), True)
check('종수 공백 변형', g.stale_count('실제값 12 종'), True)
check('종수 변형(원값·실측 값)', g.stale_count('결의부서명(원값 55종).') and g.stale_count('실측 값 6종 = 가 · 나'), True)
check('종수 아님(값 뒤 다른 수)', g.stale_count("값 범위 1~8 · ''3''종류 아님"), False)
check('신규값 1건', g.new_values("''A''·''B''·''C''", ['A', 'B', 'C', 'D']), ['D'])
check('목록 낡음 다건', g.new_values("''신규''·''기존''", ['신규', '기존', '합계']), ['합계'])

# 역방향 오탐 축 — 잡으면 안 된다
check('종수 폐지 문구', g.stale_count('주요 값(늘거나 줄 수 있음 · 전체는 조회로 확인)'), False)
check('목록 완전 일치', g.new_values("''A''·''B''", ['A', 'B']), [])
check('예시 나열(커버 미달)', g.new_values("예: ''서울''", ['서울', '부산', '대구', '광주']), None)
check('고카디널리티 제외', g.new_values("''1''", [str(i) for i in range(g.MAX_LIVE + 1)]), None)
check('목록 없음', g.new_values('설명만 있음', ['A']), None)
check('NULL 무시', g.new_values("''A''", ['A', None]), [])
check('빈 문자열 무시(O273-A)', g.new_values("''A''", ['A', '', ' ']), [])
check('빌드 지문 무시(O273-A)', g.new_values("''Android''", ['Android', 'samsung/q4qksx/q4q:14/UP1A:user/release-keys']), [])
check('지문 옆 실제 신규값은 잡는다(O273-A)', g.new_values("''Android''", ['Android', 'Fuchsia', 'a/b']), ['Fuchsia'])

print('실패', fails)
sys.exit(1 if fails else 0)
