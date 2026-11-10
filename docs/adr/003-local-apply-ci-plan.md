# 003. CI는 plan만하고 apply는 로컬에서
Status : Accepted
Date : 2026-10

## Context
apply에는 사실상 관리자 권한이 필요한데 CI에서 apply하려면 관리자 권한 역할을 GitHub Actions에 줘야 하고 머지 전 승인 절차가 필요하다. 

## Decision
PR마다 CI에서 `fmt` / `validate` / `tflint` / `trivy` / `plan` 을 실행하고 plan 결과를 PR 댓글로 남긴다. CI의 plan 역할은 읽기 전용이며 계정의 SSM 파라미터 값(이력 포함)과 Secrets Manager 값, 업로드 버킷의 사용자 파일 조회를 차단한다. apply는 머지 후 main 브랜치에서 로컬로 실행한다. 매일 drift 감지 워크플로로 코드와 실제 상태의 차이를 확인한다.

## Alternatives
대안 | 버린 이유
--- | ---
CI에서 자동 apply | GitHub Actions에 관리자 권한 필요. 1인 운영에서 자기 승인은 실효성이 낮음
Atlantis / HCP Terraform | 별도 서버나 유료 플랜 필요. 현재 규모에 비해 운영 부담이 큼

## Consequences
**얻은 것** : CI에는 읽기 전용 권한만 존재. PR 단계에서 변경 범위를 검토할 수 있음.

**감수한 것** : 
- **사람이 apply를 실행** : main이 아닌 브랜치에서 apply하면 코드와 실제 상태가 어긋날 수 있음 -> drift 감지 워크플로로 보완
- PR의 plan과 로컬 apply 결과가 다르면 apply하지 않는 규칙을 지켜야 한다.

**다시 검토할 시점** : 운영 인원이 2명 이상이 되어 리뷰/승인 체계를 갖출 수 있을 때(아마 없을 듯)