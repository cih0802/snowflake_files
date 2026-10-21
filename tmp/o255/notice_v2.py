#!/usr/bin/env python3
"""O255 · 현업 안내문 v1 → v2: 「8. 중단률 계산 기준 확인 요청」 절 추가(v1 무변경 보존).
스테이지 마운트 zip 쓰기 실패 이력(O252) ⇒ /tmp 에 저장한 뒤 shutil.copyfile 로 복사하고 해시를 대조한다.
"""
import hashlib
import shutil

import docx

SRC = "/workspace/30_output_share/O252_폐지부서_현재부서연결_안내_20261021_v1.docx"
DST = "/workspace/30_output_share/O252_폐지부서_현재부서연결_안내_20261021_v2.docx"
TMP = "/tmp/o255_notice_v2.docx"

d = docx.Document(SRC)
d.add_heading("8. 중단률 계산 기준 확인 요청 (추가 · 2026-10-21)", level=1)
d.add_paragraph(
    "중단건을 현재 부서-팀에 연결하면서 중단 쪽 부서 정의가 넓어졌습니다. "
    "부서별 중단률을 일정하게 보려면 분모(전월 말 활동 후원)도 같은 연결표로 현재 부서-팀에 맞춰야 합니다. "
    "DW 는 이 방향(분자·분모 같은 기준)을 권장하며, 현재 이 기준으로 반영해 두었습니다.")
d.add_paragraph("분모를 옛 부서 그대로 두고 분자만 옮기면, 폐지 부서를 넘겨받은 팀의 중단률이 2~3배로 부풀려집니다.")
rows = [
    ("현재 부서-팀", "같은 기준(권장)", "분자만 연결"),
    ("본부 > 회원실 > 회원서비스기획팀", "0.59%", "1.76%"),
    ("본부 > 회원실 > 회원참여팀", "2.58%", "3.55%"),
    ("국내 > 영남 > 대구사업본부", "1.41%", "4.02%"),
    ("국내 > 경기강원 > 경기남부사업본부", "1.52%", "3.21%"),
    ("전체", "1.47%", "—"),
]
t = d.add_table(rows=len(rows), cols=3)
t.style = "Table Grid"
for i, r in enumerate(rows):
    for j, v in enumerate(r):
        t.cell(i, j).text = v
d.add_paragraph(
    "※ 2026년 9월 · 약정 건수 기준(그 달 중단 약정 ÷ 8월 말 활동 약정) · 개발 환경 숫자입니다. "
    "회사 공식 중단율(금액 건 기준)과는 산식이 달라 값이 다릅니다.")
d.add_paragraph("확인 부탁드리는 것:")
d.add_paragraph("① 부서별 중단률의 분모도 현재 부서-팀 기준으로 맞추는 방향이 맞는지", style="List Bullet")
d.add_paragraph("② 분모는 당시 부서 그대로 두어야 하는 보고서가 있다면 어떤 것인지", style="List Bullet")
d.add_paragraph("회신 전까지는 권장안(같은 기준)으로 보입니다. 다른 기준으로 회신 주시면 그에 맞춰 바꾸겠습니다.")
d.save(TMP)
shutil.copyfile(TMP, DST)
h = lambda p: hashlib.sha256(open(p, "rb").read()).hexdigest()
print("hash_equal", h(TMP) == h(DST), "v1_kept", h(SRC)[:12])
