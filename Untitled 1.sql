-- 기존 secret 확인
SHOW SECRETS;

-- Secret 업데이트 (username과 새 PAT으로)
ALTER SECRET git_sec SET 
  USERNAME = 'cih0802'
  PASSWORD = '<새로운_PAT>';