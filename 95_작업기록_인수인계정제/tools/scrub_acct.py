"""이전 개발/트라이얼 계정 로케이터 제거(문장 안 구분자째 삭제, 불가하면 '이전 계정')."""
import re
ACC=('AD50130 BT97381 CK24285 CS94293 DV07626 HY04212 IJ48528 IQ36690 IW20760 JU93656 JW08094 KA98941 '
     'LK96056 LS82944 MN11232 MQ60369 NJ58180 NX55103 OC95308 OS09358 PW69582 RY53492 SR61467 UA91864 '
     'UA93987 WZ61282 XF98254 XH20001 YQ47212 THGVUIA YWCPUKJ '
     'UM80684').split()   # 🆕 [2026-10-25 O261] 새 개발계 UM80684 — 80 사본(02_dbt·문서실행순서 3종)에 계정 값 유입 실측 후 편입 · 재빌드 후 0
T=r'`?(?:'+'|'.join(ACC)+r')`?'
P=[(re.compile(r'(?:\s*(?:→|↔)\s*'+T+r')+',re.I),''),
   (re.compile(r'\s*·\s*(?:개발계\s*|계정\s*|trialadmin)?\(?'+T+r'\)?(?:\s*\(개발계\))?(?=[\s·),]|$)',re.I),''),
   (re.compile(r'(?:개발계\s*|계정\s*)?'+T+r'(?:\s*\(개발계\))?\s*·\s*',re.I),''),
   (re.compile(r'\((?:개발계\s*|계정\s*)?'+T+r'(?:\s*\(개발계\))?\)',re.I),''),
   (re.compile(r'(?:구\s*|다른\s*|개발계\s*)?계정\s*\(?'+T+r'\)?(?:\s*\(개발계\))?',re.I),'이전 계정'),
   (re.compile(T,re.I),'이전 계정')]
def scrub(s):
    for p,r in P: s=p.sub(r,s)
    return s
