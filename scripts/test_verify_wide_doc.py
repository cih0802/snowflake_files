# -*- coding: utf-8 -*-
"""test_verify_wide_doc.py — WIDE VIEW 정의서 정합성 게이트 음성 회귀 테스트."""
import os
import sys
import subprocess

ROOT = '/workspace'

def main():
    print("=== test_verify_wide_doc: WIDE 정의서 정합성 검증 테스트 ===")
    
    # 1. 문서 헤더에 도구 명시 확인
    doc_path = os.path.join(ROOT, '03_top-down_gold', '09_빅테이블 VIEW.md')
    with open(doc_path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    assert 'generator: scripts/build_wide_doc.py' in content, "헤더에 build_wide_doc 생성기 명시 누락"
    assert 'validator: scripts/verify_wide_doc.py' in content, "헤더에 verify_wide_doc 검증기 명시 누락"
    assert 'scripts/verify_wide_doc.py' in content, "본문 안내에 verify_wide_doc 명시 누락"
    print("  🟢 축1: 09번 문서 내 생성기 및 검증 게이트 명시 확인 완료")
    
    # 2. 실제 검증기 실행 결과 rc=0 확인
    r = subprocess.run([sys.executable, os.path.join(ROOT, 'scripts', 'verify_wide_doc.py')],
                       capture_output=True, text=True, cwd=ROOT)
    assert r.returncode == 0, f"verify_wide_doc 실행 실패: {r.stderr or r.stdout}"
    assert "전수 100% 정합성 검증 완료" in r.stdout, "검증 통과 메시지 누락"
    print("  🟢 축2: verify_wide_doc.py 실행 100% 통과 실측 완료")
    
    print("\n🟢 ALL PASS — WIDE VIEW 정의서 검증 체계 정상")
    return 0

if __name__ == '__main__':
    sys.exit(main())
