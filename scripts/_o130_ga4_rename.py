#!/usr/bin/env python3
"""O130 1회용 — SILVER GA4_* -> BIGQUERY_* 리터럴 치환(DEC-48).
순서 중요: 긴 토큰(EVENT_DIM, TRAFFIC_SOURCE, IDENTITY, BASIC, DEVICE) 먼저,
남은 GA4_EVENT 는 마지막에 치환한다(부분문자열 충돌 방지).
"""
import sys

ORDER = [
    ("GA4_EVENT_DIM", "BIGQUERY_EVENT_DIM"),
    ("GA4_TRAFFIC_SOURCE", "BIGQUERY_TRAFFIC_SOURCE"),
    ("GA4_IDENTITY", "BIGQUERY_IDENTITY"),
    ("GA4_BASIC", "BIGQUERY_BASIC"),
    ("GA4_DEVICE", "BIGQUERY_DEVICE"),
    ("GA4_EVENT", "BIGQUERY_EVENT"),
]


def run(path):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    before_len = len(text)
    counts = {}
    for old, new in ORDER:
        counts[old] = text.count(old)
        text = text.replace(old, new)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    after_len = len(text)
    print(f"{path}")
    for old, new in ORDER:
        if counts[old]:
            print(f"  {old} -> {new} : {counts[old]}건")
    print(f"  길이 {before_len} -> {after_len}")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        run(p)
