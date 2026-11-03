#!/usr/bin/env python3
"""O255 · 05_SV-Agent_ai 배포순서 SQL 파일명에서 작업번호(O02xx)를 뺀다.
규칙 = NN_DEPLOY_<주제(영문)>.sql (05_NN_SV_DDL_<주제> 와 같은 「번호_유형_주제」 형태 · 번호 NN 유지)
기본 = dry-run · --apply 로 실행 · 각 파일 SHA256 을 변경 전후 대조한다(내용 무변경 이름만).
"""
import hashlib
import os
import sys

D = "/workspace/05_SV-Agent_ai"
MAP = [
    ("27_O237_산식대응_배포순서.sql",               "27_DEPLOY_FORMULA_ALIGN.sql"),
    ("28_O237C_G1해소_배포순서.sql",                "28_DEPLOY_G1_RESOLVE.sql"),
    ("29_O239_G1잔여_배포순서.sql",                 "29_DEPLOY_G1_REMAINDER.sql"),
    ("30_O240_실데이터이상치_배포순서.sql",          "30_DEPLOY_DATA_ANOMALY.sql"),
    ("32_O241_AB병기_SV배선_배포순서.sql",          "32_DEPLOY_AB_DUAL_SV_WIRING.sql"),
    ("33_O241C_O242_운영계반영_배포순서.sql",        "33_DEPLOY_PROD_ROUNDING_VQR.sql"),
    ("34_O246D_운영계반영_SV_ML_폴백각주.sql",       "34_DEPLOY_SV_ML_FALLBACK_NOTE.sql"),
    ("35_O249_SV_신설_광고비배분_개발사건코호트.sql", "35_DEPLOY_SV_AD_INFLOW_EVENT_COHORT.sql"),
    ("36_O250_ML예측_7축확장.sql",                  "36_DEPLOY_ML_PRED_7AXIS.sql"),
]


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def main():
    apply = "--apply" in sys.argv
    bad = 0
    for old, new in MAP:
        po, pn = os.path.join(D, old), os.path.join(D, new)
        if not os.path.exists(po):
            print("🔴 원본 없음", old); bad += 1; continue
        if os.path.exists(pn):
            print("🔴 대상 이미 있음", new); bad += 1; continue
        h = sha(po)
        if not apply:
            print("dry", old, "→", new, h[:12]); continue
        os.rename(po, pn)
        ok = os.path.exists(pn) and not os.path.exists(po) and sha(pn) == h
        print(("🟢" if ok else "🔴"), old, "→", new, h[:12])
        bad += 0 if ok else 1
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
