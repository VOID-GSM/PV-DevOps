# 006. CloudFront → EC2 요청을 비밀 헤더로 검증
Status : Accepted
Date : 2026-11

## Context
EC2 보안 그룹은 CloudFront origin-facing prefix list에서 오는 80번 포트만 허용한다(ADR 002). 하지만 이 prefix list는 **모든 AWS 고객의** CloudFront 대역이다. 누구든 자기 CloudFront 배포를 만들어 오리진에 우리 EC2 퍼블릭 DNS를 넣으면 보안 그룹을 그대로 통과한다. 이 경로로는 우리 배포의 HTTPS 강제와 보안 헤더 정책도 우회된다.

## Decision
- Terraform이 `random_password`로 값을 만들어 CloudFront API 오리진에 `X-Origin-Verify` 헤더로 붙인다. 뷰어가 같은 이름의 헤더를 보내도 CloudFront가 덮어쓴다.
- 같은 값을 CLI로 SSM `/pv/backend/ORIGIN_VERIFY_SECRET`에 저장하면, 배포 문서가 다른 시크릿과 함께 `.env`에 넣는다(ADR 004 절차 그대로).
- 백엔드 필터가 헤더 값을 비교해 다르면 403을 반환한다. 값이 비어 있으면(로컬 개발) 검사하지 않는다.

```bash
MSYS_NO_PATHCONV=1 aws ssm put-parameter --name /pv/backend/ORIGIN_VERIFY_SECRET \
  --type SecureString --value "$(terraform output -raw origin_verify_secret)" --overwrite
```

## Alternatives
대안 | 버린 이유
--- | ---
Terraform `aws_ssm_parameter`로 값까지 관리 | plan 역할은 SSM 값 조회가 차단돼 PR plan이 실패함(ADR 004와 같은 이유)
CLI로 만든 값을 Terraform 변수로 전달 | CI plan과 로컬 apply 양쪽에 값을 따로 넣어야 해서 관리 지점이 늘어남
CloudFront VPC Origin | 오리진을 private subnet에 둬야 하고, 인스턴스의 인터넷 출구로 NAT가 필요해짐(ADR 002에서 버린 비용)
WAF로 헤더 검사 | Web ACL 월 $5+, 결국 같은 헤더 방식

## Consequences
**얻은 것** : 우리 CloudFront를 거친 요청만 백엔드에 도달한다. 추가 비용 없음.

**감수한 것** :
- **값이 state와 CloudFront 설정에 남음** : CloudFront 설정(`GetDistributionConfig`)에 들어가는 이상 계정 읽기 권한이 있으면 볼 수 있는 값이라 state에 남는다고 노출 범위가 넓어지지 않는다고 판단. DB 비밀번호 같은 시크릿과는 등급이 다르다.
- **CloudFront → EC2 구간이 HTTP** : 헤더가 평문으로 전송된다(ADR 002). 이 헤더는 남의 CloudFront를 통한 우회를 막는 장치이지, 구간 도청까지 막지는 못한다. 완전한 해결은 origin TLS.
- **값 교체 시 짧은 불일치** : `terraform apply -replace=module.cloudfront.random_password.origin_verify` 후 SSM 갱신·백엔드 배포 사이에 API가 403을 반환한다. CloudFront 설정이 전 엣지에 퍼지는 데 수 분이 걸려 그동안 옛 값과 새 값이 섞여 오므로 순서를 맞춰도 이 구간은 없앨 수 없다. 무중단 교체가 필요해지면 백엔드가 두 값을 함께 허용하도록 바꾼다.
- **SSM 값이 없으면 배포 실패** : 운영에서 검사가 조용히 꺼지는 것을 막기 위해 배포 문서가 `.env` 생성 단계에서 값이 없으면 중단한다. 로컬 개발(값 없음)에서는 백엔드가 검사를 건너뛴다.

**다시 검토할 시점** : 커스텀 도메인 + origin TLS를 도입할 때 또는 private subnet으로 옮길 때