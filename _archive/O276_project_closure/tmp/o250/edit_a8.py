#!/usr/bin/env python3
"""O250-C · A8 미결이슈 csv 갱신: A8-29 해소 표기 + A8-30·31 추가(해시 2회 확인 · 앵커 1회 · 직후 되읽기)."""
import hashlib
import sys
import time
from pathlib import Path

p = Path("/workspace/85_실제 인수인계 문서/10_실무자_인수인계/A8_미결이슈_인계목록.csv")
h = hashlib.sha256(p.read_bytes()).hexdigest()
time.sleep(1)
if hashlib.sha256(p.read_bytes()).hexdigest() != h:
    sys.exit("🔴 해시 불안정")
t = p.read_text(encoding="utf-8")
old = "개발계 실측(N01 Q02) · 원인 미확인 · 해당 FK 의 dbt 테스트 유무 미확인"
new = ("🟢 해소 — O249-C(템플릿 버튼 21 → 0) · O249-D(SEND_REQUEST 3,001 → 0 · SK=0 unknown 멤버) · SR61467 2026-10-21 재조회 · "
       "운영계는 dbt build 후 같은 FK 고아 조회로 확인")
if t.count(old) != 1:
    sys.exit(f"🔴 A8-29 앵커 {t.count(old)}회")
t = t.replace(old, new, 1)
if "A8-30," not in t:
    if not t.endswith("\n"):
        t += "\n"
    t += ("A8-30,P2,현업 확인,ML 예측 7축의 본부지부 3분류(본부 = 본부·시도본부·시도본부 및 중앙·본부(사복) · 지부 = 지부·지부(사복) · 기타 = 협력시설·지부외)가 "
          "회원실 집계(본부/지부)와 같은 정의인가,O250 기본값 적용 · 원값 8종 컬럼 병기,현업(회원실),정의 회신 → 다르면 36_ 의 CASE 2곳 수정,O250-A\n")
    t += ("A8-31,P3,데이터 정합,회비 예측 7축 배분 불가 = 202609 예측의 24.7%(직전 12개월 매칭 납입 실적이 없는 카테고리 · 기존 축별 배분 27.6% 와 같은 축),"
          "배분 불가로 별도 표기 중,ML 담당,예측 카테고리 ↔ 약정 카테고리 코드 대응 확인,O250-A\n")
p.write_text(t, encoding="utf-8")
print("🟢" if p.read_text(encoding="utf-8") == t else "🔴", "A8 csv", t.count("\nA8-"))
