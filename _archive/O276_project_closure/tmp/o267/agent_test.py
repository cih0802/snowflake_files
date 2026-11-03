# O267 — 「질문 시 템플릿 정보」 방식 확인(개발계 · DATA_AGENT_RUN · 원문은 파일로 · 요약만 출력 J7)
import json
import os
import re
import sys
import time

sys.path.insert(0, '/workspace/scripts')
sys.path.insert(0, '/workspace/12_agent개선과제/tools')
import sfconn
from agent_answer_report import parse  # noqa: E402

OUT = '/workspace/tmp/o267/agent_test'
AGENT = os.environ.get('AGENT', 'GN_DW.SERVING.AGENT_MARKETING')
QS = [
    ('T1', '알림톡 템플릿 AT006040 을 받은 회원 중 수신 후 5일 이내에 그 템플릿 링크를 클릭한 회원 수를 알려줘.'),
    ('T2', '알림톡 링크 https://www.gni.kr/?utm_campaign=25acpi_om_gift 를 클릭한 회원 수를 수신 후 5일 이내 기준으로 알려줘.'),
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
            cur.execute('SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)', (AGENT, body))
            raw = cur.fetchone()[0]
        except Exception as e:  # 실패를 답변으로 읽지 않는다
            raw = json.dumps({'error': str(e)})
        sec = round(time.time() - t0, 1)
        with open(f'{OUT}/{tag}.json', 'w', encoding='utf-8') as f:
            f.write(raw if isinstance(raw, str) else json.dumps(raw, ensure_ascii=False))
        d = parse(raw)
        sqls = '\n'.join(d.get('sqls') or [])
        with open(f'{OUT}/{tag}.txt', 'w', encoding='utf-8') as f:
            f.write(f'질문: {q}\n도구: {d.get("tools")} · SV {d.get("svs")} · 표 {d.get("tables")} · 오류 {d.get("errors")}\n\n{d.get("answer")}\n\n--- SQL ---\n{sqls}\n')
        up = sqls.upper()
        print(tag, sec, 's · 도구', d.get('tools'), '· SV', d.get('svs'), '· 오류', len(d.get('errors') or []),
              '· SQL 에 AT_GA_CLICK', ('AT_GA_CLICK' in up or 'ATCLK' in up),
              '· AT006040', 'AT006040' in up, '· 25ACPI', '25ACPI_OM_GIFT' in up,
              '· 답변', len(d.get('answer') or ''), '자')
    cn.close()


if __name__ == '__main__':
    main()
