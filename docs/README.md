# Architecture Decision Records

인프라 설계에서 내린 주요 결정과 그 이유를 기록합니다.

 번호 | 결정 | 상태 
 --- | --- | --- 
 [001](adr/001-single-ec2-docker-compose.md) | 단일 EC2 + Docker Compose로 운영 | Accepted 
 [002](adr/002-cloudfront-path-routing.md) | NAT·ALB 없이 CloudFront 경로 라우팅 | Accepted 
 [003](adr/003-local-apply-ci-plan.md) | CI는 plan만, apply는 로컬에서 | Accepted 
 [004](adr/004-secrets-outside-terraform.md) | 시크릿 값은 Terraform 밖에서 관리 | Accepted 
 [005](adr/005-ecr-image-deploy.md) | 서버 빌드 대신 ECR 이미지 배포 + 자동 롤백 | Accepted 

새 ADR은 [ADR_TEMPLATE.md](adr/ADR_TEMPLATE.md)를 복사해 다음 번호로 작성합니다.