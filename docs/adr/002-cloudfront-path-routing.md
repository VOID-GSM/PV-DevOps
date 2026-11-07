# 002. NAT/ALB 없이 CloudFront 경로 라우팅
Status : Accepted
Date : 2026-10

## Context
웹(React SPA)과 API(Spring Boot)를 HTTPS로 제공해야 하는데 웹과 API 도메인이 다르면 CORS 설정과 쿠키/토큰 처리가 복잡해진다. 그치만 NAT Gateway와 ALB는 이 규모에서 고정비 비중이 커진다.

## Decision
CloudFront 배포 하나에서 경로로 나눈다.     
`/*` → S3(웹 정적 파일, OAC로 비공개)   
`/api/*` → EC2(HTTP 80)

EC2는 public subnet에 두되 보안 그룹은 CloudFront origin-facing prefix list에서 오는 **80번 포트만 허용한다.**

## Alternatives
대안 | 버린 이유
--- | ---
ALB + private subnet + NAT | 월 $56 이상 고정비 추가. 인스턴스 한 대에 로드밸런서가 필요하지 않음
웹/API 도메인 분리 | API에 CORS 설정 필요. 프론트와 백엔드 모두 복잡해짐

## Consequences
**얻은 것** : 웹과 API가 같은 도메인이라 API에 CORS가 필요없다. HTTPS 인증서를 CloudFront 기본 인증서로 해결했다.

**감수한 것** : 
- **CloudFront → EC2 구간은 HTTP** : 보안그룹으로 CloudFront 외 접근은 막았지만 구간 암호화는 없다.
- **EC2에 퍼블릭 IP가 있음** : ingress는 CloudFront 대역만 허용. SSH 포트 없음(SSM Session Manager 사용)
- **커스텀 도메인 없음** : `.cloudfront.net` 주소를 그대로 사용함

**다시 검토할 시점** : 커스텀 도메인 도입 시(ACM 인증서 + origin TLS 적용), 인스턴스를 여러 대로 늘릴 때(ALB)