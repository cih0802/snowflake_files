# -*- coding: utf-8 -*-
"""null_reason_registry_gate 음성 테스트 (negative tests)."""
import unittest
import sys
sys.path.insert(0, '/workspace/scripts')
from null_reason_registry_gate import validate_null_tag, VALID_NULL_REASONS

class TestNullReasonRegistryGate(unittest.TestCase):
    def test_valid_tags(self):
        for tag in VALID_NULL_REASONS:
            valid, res = validate_null_tag(f"설명 문안 {tag} 추가 설명")
            self.assertTrue(valid, f"Should be valid: {tag}")
            self.assertEqual(res, tag)

    def test_invalid_tag_name(self):
        valid, res = validate_null_tag("설명 문안 [NULL: 미상] 추가 설명")
        self.assertFalse(valid)
        self.assertIn("미정의 사유 코드", res)

    def test_missing_tag(self):
        valid, res = validate_null_tag("설명 문안만 있고 태그 없음")
        self.assertFalse(valid)

if __name__ == '__main__':
    unittest.main()
