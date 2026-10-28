# O266-C — 마케팅 Agent 현업 피드백 4문항 재현(개발계 · DATA_AGENT_RUN · 원문은 파일로 · 요약만 출력 J7)
import json
import os
import sys
import time

sys.path.insert(0, '/workspace/scripts')
sys.path.insert(0, '/workspace/12_agent개선과제/tools')
import sfconn
from agent_answer_report import parse  # noqa: E402  (답변 텍스트·표·SQL 추출 재사용)

OUT = '/workspace/tmp/o266/agent_test'
QS = [
    ('Q1', '2026년 9월 디지털 광고비를 매체별로 알려줘.'),
    ('Q2', '2026년 마케팅캠페인별 광고비, 개발건수, 제작비를 하나의 표로 보여줘.'),
    ('Q3', '2026년 9월 기준 마케팅캠페인별·마케팅채널별 활동율을 보여줘.'),
    ('Q4', '캠페인카테고리별 회원 LTV를 상한과 무기한 기준으로 표로 보여줘.'),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    cn = sfconn.conn()
    cur = cn.cursor()
    cur.execute('USE WAREHOUSE GN_DW_ANALYTICS_WH')
    for tag, q in QS:
        body = json.dumps({'messages': [{'role': 'user', 'content': [{'type': 'text', 'text': q}]}]}, ensure_ascii=False)
        t0 = time.time()
        try:
            cur.execute('SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)', ('GN_DW.SERVING.AGENT_MARKETING', body))
            raw = cur.fetchone()[0]
        except Exception as e:  # 실패를 답변으로 읽지 않는다
            raw = json.dumps({'error': str(e)})
        sec = round(time.time() - t0, 1)
        with open(f'{OUT}/{tag}.json', 'w', encoding='utf-8') as f:
            f.write(raw if isinstance(raw, str) else json.dumps(raw, ensure_ascii=False))
        d = parse(raw)
        with open(f'{OUT}/{tag}.txt', 'w', encoding='utf-8') as f:
            f.write(f'질문: {q}\n도구: {d.get("tools")} · SV {d.get("svs")} · 표 {d.get("tables")} · 오류 {d.get("errors")}\n\n{d.get("answer")}\n\n--- SQL ---\n{chr(10).join(d.get("sqls") or [])}\n')
        print(tag, sec, 's · 도구', d.get('tools'), '· 표', d.get('tables'), '· 오류', len(d.get('errors') or []), '· 답변', len(d.get('answer') or ''), '자')
    cn.close()


if __name__ == '__main__':
    main()
