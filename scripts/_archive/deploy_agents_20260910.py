#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys
sys.path.insert(0, '/workspace/scripts')
import sfconn

def main():
    cn = sfconn.conn()
    cur = cn.cursor()
    
    print('[AGENT 배포] OPS 스테이지 확인 및 생성...')
    cur.execute('USE ROLE GN_DW_ADMIN')
    cur.execute('USE WAREHOUSE GN_DW_DEV_WH')
    cur.execute('CREATE SCHEMA IF NOT EXISTS GN_DW.OPS')
    cur.execute('CREATE STAGE IF NOT EXISTS GN_DW.OPS.AGENT_SPEC_STAGE DIRECTORY = (ENABLE = TRUE)')
    
    ws_uri = 'snow://workspace/USER$.PUBLIC."snowflake_files"/versions/live/cortex_project/agents'
    
    agents = ['AGENT_MEMBER', 'AGENT_EXECUTIVE', 'AGENT_MARKETING']
    for ag in agents:
        print(f'\n[AGENT 배포] {ag} 복사 및 배포...')
        copy_sql = f"""COPY FILES INTO @GN_DW.OPS.AGENT_SPEC_STAGE/{ag}/
FROM '{ws_uri}/{ag}/'
FILES = ('agent_spec.yaml')"""
        try:
            cur.execute(copy_sql)
            print(f'  ✅ COPY FILES 성공: {ag}')
        except Exception as e:
            print(f'  🔴 COPY FILES 실패: {ag} -> {e}')
            
        try:
            cur.execute(f'ALTER AGENT GN_DW.SERVING.{ag} COMMIT')
            print(f'  ✅ COMMIT 성공: {ag}')
        except Exception as e:
            print(f'  ℹ️ COMMIT 안내 ({ag}): {e}')

    comments = {
        'AGENT_MEMBER': (
            '굿네이버스 회원 분석 Agent. SV 11종:ML 3 포함. '
            '마케팅 보고서 5분석구분의 정본 Agent.'
        ),
        'AGENT_EXECUTIVE': (
            '굿네이버스 전사·재무 요약 분석 Agent. SV 8종: '
            '예산·광고실적·회원월실적·발송 + ML 예측 4종(개발금액·LTV예측·LTV스코어·기여요인).'
        ),
        'AGENT_MARKETING': (
            '굿네이버스 마케팅 분석 Agent. SV 7종: '
            '광고효율·개발목표달성·예산집행·전환회원·캠페인코호트·캠페인회비. '
            '마케팅 보고서 5분석구분의 정본 Agent.'
        )
    }

    for ag in agents:
        cmt = comments[ag].replace("'", "''")
        deploy_sql = f"""ALTER AGENT GN_DW.SERVING.{ag}
ADD VERSION FROM '@GN_DW.OPS.AGENT_SPEC_STAGE/{ag}'
COMMENT = '{cmt}'"""
        try:
            cur.execute(deploy_sql)
            print(f'  ✅ ADD VERSION 성공: {ag}')
        except Exception as e:
            print(f'  🔴 ADD VERSION 실패: {ag} -> {e}')
            
    # SHOW VERSIONS 검증
    for ag in agents:
        cur.execute(f'SHOW VERSIONS IN AGENT GN_DW.SERVING.{ag}')
        rows = cur.fetchall()
        print(f'\n[AGENT 버전 검증] {ag}:')
        for r in rows:
            print(f'  · {r[0]} | default={r[1]} | comment={r[2]}')

    cn.close()

if __name__ == '__main__':
    main()
