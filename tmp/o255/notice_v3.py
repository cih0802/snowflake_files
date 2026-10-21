#!/usr/bin/env python3
"""O255 · 현업 안내문 v2 → v3: 「9. 부서 기준 변경의 파급 안내 · 선택 요청」 절 추가(v1·v2 보존).
/tmp 저장 → shutil.copyfile → 해시 대조(스테이지 zip 쓰기 실패 이력 대응).
"""
import hashlib
import shutil

import docx

SRC = "/workspace/30_output_share/O252_폐지부서_현재부서연결_안내_20261021_v2.docx"
DST = "/workspace/30_output_share/O252_폐지부서_현재부서연결_안내_20261021_v3.docx"
TMP = "/tmp/o255_notice_v3.docx"


def table(doc, rows):
    t = doc.add_table(rows=len(rows), cols=len(rows[0]))
    t.style = "Table Grid"
    for i, r in enumerate(rows):
        for j, v in enumerate(r):
            t.cell(i, j).text = v


d = docx.Document(SRC)
d.add_heading("9. 부서 기준 변경의 파급 안내 · 선택 요청 (추가 · 2026-10-21)", level=1)
d.add_paragraph(
    "요청하신 「폐지 부서 중단건을 현재 부서-팀 KPI 에 합산」을 반영하면서, 같은 부서 기준을 쓰는 다른 지표도 함께 점검했습니다. "
    "중단만 현재 부서로 바꾸고 나머지를 옛 부서로 두면, 한 화면 안에서 지표마다 부서 기준이 달라져 비교가 어긋납니다. "
    "그래서 아래 지표도 같은 연결표로 현재 부서-팀 기준을 먼저 반영해 두었습니다.")
d.add_paragraph("원래(당시 부서) 기준 값은 지우지 않았습니다. 항목별로 되돌리실 수 있습니다.")
table(d, [
    ("지표", "반영 내용", "폐지 부서에 잡혀 있던 비중"),
    ("① 부서별 중단건", "중단건을 현재 부서-팀에 합산(요청 사항)", "2024 16.3% · 2025 12.7%"),
    ("② 부서별 중단률", "분모(전월 말 활동 후원)도 같은 기준(8번)", "분자와 동일"),
    ("③ 부서별 목표·실적·달성률", "목표와 실적을 함께 현재 부서-팀으로 이동", "목표 2024 22.5% · 2025 18.2%"),
    ("④ 부서별 개발 실적", "개발 실적을 현재 부서-팀에 합산", "2024년 이후 7.2%"),
])
d.add_paragraph("③ 달라지는 예(2025년 · 당시 부서 → 현재 부서 기준):")
table(d, [
    ("현재 부서-팀", "당시 부서 기준", "현재 부서 기준"),
    ("본부 > 회원실 > 회원참여팀", "목표 22,000 · 실적 23,534 · 45.0%", "목표 25,000 · 실적 34,408 · 78.0%"),
    ("국내(사복) > 서인권역본부(사복)", "달성률 없음(목표·실적 없음)", "목표 550 · 실적 541 · 76.4%"),
    ("국내(사복) > 충청권역본부(사복)", "달성률 없음", "목표 330 · 실적 357 · 79.7%"),
])
d.add_paragraph("※ 개발 환경 숫자입니다. 전체 합계(목표·실적·중단건)는 바뀌지 않고 부서 간 배분만 바뀝니다.")
d.add_paragraph("바꾸지 않은 것: 예산·사업목표(부서 구분이 거의 없음), 캠페인·문자 템플릿·결제계좌의 담당부서(관리 담당 정보라 실적 합산과 무관), 회원을 처음 데려온 부서(최근 연도 영향 6% 이하).")
d.add_heading("선택 부탁드립니다", level=2)
d.add_paragraph("A. 수정본 유지 — ①~④ 모두 현재 부서-팀 기준 (DW 권장)", style="List Bullet")
d.add_paragraph("B. 일부 되돌리기 — 되돌릴 번호를 알려 주세요(예: ③ 목표는 당시 부서 유지)", style="List Bullet")
d.add_paragraph("C. 전부 되돌리기 — 요청하신 ① 만 남기고 ②~④ 는 당시 부서 기준", style="List Bullet")
d.add_paragraph(
    "DW 는 A 를 권장합니다. 부서장이 본인 부서를 조회할 때 중단·중단률·목표·실적·달성률이 모두 같은 부서 범위로 나와야 "
    "숫자끼리 맞습니다. 특히 ③ 은 목표와 실적이 함께 움직이므로 달성률이 왜곡되지 않습니다. "
    "회신 전까지는 A(수정본)로 보입니다.")
d.save(TMP)
shutil.copyfile(TMP, DST)
h = lambda p: hashlib.sha256(open(p, "rb").read()).hexdigest()
print("hash_equal", h(TMP) == h(DST))
