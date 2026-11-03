import io
L='/workspace/20_issue/00_INDEX_이슈원장_조각/00_INDEX_이슈원장-002.md'
t=io.open(L,encoding='utf-8').read()
a='🟠 잔여 = 실행순서 4종 본문 옛 경로(80 사본 정합 · 치환 여부 사용자 결정)'
b='실행순서 4종 본문 경로 새 배치 치환 233건(사용자 결정) · 🟠 잔여 = 80·85 사본 경로(재배치 완료 후)'
assert t.count(a)==1
t=t.replace(a,b).replace("`-B.md`·`-C.md` |","`-B.md`·`-C.md`·`-D.md` |",1)
io.open(L,'w',encoding='utf-8').write(t); assert io.open(L,encoding='utf-8').read()==t; print('ok')
