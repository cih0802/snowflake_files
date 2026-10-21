# O249-C — 형제 단위(O249-A·B) 착수표에서 끝난 행 닫기(§1-1 취소선 관례 · 행 삭제 금지)
import io
D = '/workspace/99_NEXT_SESSION_조각/'
CLOSE = {
    'O0249-A': {
        '| ① |': ' ➔ 🟢 [O249-B] 사용자 build 완료 · 라이브 상한 80·9999 각 98행 · 중복 0',
        '| ② |': ' ➔ 🟢 [O249-B] ㉠ 사용자 확인 · ㉡ 생략(사용자) · ㉢㉤ 에이전트 확인 · A3 status 🟢',
        '| ④ |': ' ➔ 🟢 [O249-B] 사용자 결정 = ML 테이블 증가 없음 · 배분 추정으로 확정',
        '| ⑤ |': ' ➔ 🟢 [O249-B] 코드사전 결번(O116-B) · 문서20 기등재 · 라벨 창작 금지 ⇒ O249-B ③ 현업 대기로 이관',
        '| ③ |': ' ➔ 🟢 [O249-B] O249-B ③ 현업 항목으로 이관',
        '| ⑥ |': ' ➔ 🟢 [O249-B] O249-B ④(문서실행순서 20~25)로 이관',
    },
    'O0249-B': {
        '| ① |': ' ➔ 🟡 [O249-C] 템플릿·버튼 고아 0 · DIM_SEND_REQUEST 는 O249-C ① 로 이관',
        '| ② |': ' ➔ 🟢 [O249-C] O249-C ㉡ 백로그로 이관',
        '| ③ |': ' ➔ 🟢 [O249-C] O249-C ㉡ 백로그로 이관',
        '| ④ |': ' ➔ 🟢 [O249-C] O249-C ㉡ 백로그로 이관',
        '| ⑤ |': ' ➔ 🟢 [O249-C] O249-C ① ② 로 이관',
    },
}
for lab, rows in CLOSE.items():
    p = D + '99_NEXT_SESSION-%s.md' % lab
    t = io.open(p, encoding='utf-8').read()
    assert t == io.open(p, encoding='utf-8').read()
    sec = t.index('㉠ 잔여')
    end = t.index('### ▣', sec)
    head, body, tail = t[:sec], t[sec:end], t[end:]
    L = body.split('\n')
    n = 0
    for i, l in enumerate(L):
        for key, note in rows.items():
            if l.startswith(key):
                cells = l.split(' | ')
                num = key.strip('| ').strip()
                rest = l[len(key):].rstrip()
                assert rest.endswith('|')
                parts = [c.strip() for c in rest.strip('|').split('|')]
                L[i] = '| ~~%s~~ | ~~%s~~%s | %s |' % (num, parts[0], note, ' | '.join(parts[1:]))
                n += 1
    assert n == len(rows), (lab, n)
    io.open(p, 'w', encoding='utf-8').write(head + '\n'.join(L) + tail)
    print(lab, 'closed', n)
