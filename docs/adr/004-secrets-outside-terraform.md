# 004. 시크릿 값은 Terraform 밖에서 관리
Status : Accepted
Date : 2026-10 

## Context
서버의 DB 비밀번호, JWT 서명 키를 서버에서 직접 `.env`로 작성하고 있었다. 서버가 사라지면 값도 사라지고 변경 이력이 남지 않았다. Terraform으로 시크릿 값을 관리하면 **state 파일에 평문으로 저장된다.** CI의 plan 역할은 시크릿 조회가 차단되어 있어서 Terraform이 시크릿 파라미터를 읽으면 PR plan이 실패한다.

## Decision
시크릿은 SSM Parameter Store `/pv/backend/*` 에 SecureString으로 저장하고 등록 및 변경은 CLI로 한다. 시크릿이 아닌 인프라 값은 Terraform이 배포 문서에 주입한다. 배포할 때 SSM 배포 문서가 두 값을 합쳐 서버의 `.env` 를 생성한다. 파라미터를 읽지 못하면 기존 `.env` 를 덮어쓰지 않고 배포를 중단한다.

## Alternatives
대안 | 버린 이유
--- | ---
Terraform `aws_ssm_parameter` 로 값까지 관리 | state에 평문 저장. plan 역할의 시크릿 차단 정책과 충돌
서버에 수동 `.env` 유지 | 재현 불가, 변경 이력 없음

## Consequences
**얻은 것** : 시크릿이 코드/state/CI 로그에 남지 않음. 서버를 새로 만들어도 배포 한 번으로 `.env` 복원.

**감수한 것** : 
- 시크릿 등록은 CLI이라 문서화된 절차를 따라야 한다.
- 값을 바꾸면 다음 배포 때 반영된다. (즉시 반영은 아님)