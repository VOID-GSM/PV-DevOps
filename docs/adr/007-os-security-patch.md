# 007. OS 보안 패치는 SSM으로 주 1회 자동 적용
Status : Accepted
Date : 2026-11

## Context
EC2는 `ignore_changes = [ami]`라서 AMI가 갱신돼도 인스턴스가 바뀌지 않는다. AL2023은 저장소가 AMI의 릴리스 버전에 고정되어 있어(deterministic upgrades) 서버 안에서 `dnf upgrade`를 해도 이후에 나온 보안 패치를 받지 못한다. 결과적으로 서버를 만든 시점의 패키지가 그대로 운영되고 있었다.

## Decision
SSM 문서 `pv-os-patch`를 State Manager association으로 **매주 일요일 05:00 KST**에 실행한다.
- `dnf upgrade --releasever=latest --security`로 **보안 업데이트만** 최신 릴리스에서 설치한다.
- `dnf needs-restarting -r`로 재부팅이 필요할 때만 재부팅한다.
- 매일 04:00 KST AWS Backup 이후로 잡는다. 백업 시작 허용 시간을 60분(`start_window`)으로 제한해서 05:00 전에 시작하지 못한 백업은 취소되고 백업 실패 알림이 온다. 즉 알림이 없으면 패치 직전 스냅샷이 있다.
- 재부팅 시 docker가 `/data` 마운트 이후에 시작되도록 systemd drop-in(`RequiresMountsFor=/data`)을 둔다. 마운트가 실패하면 docker가 뜨지 않아 빈 DB로 서비스되는 일이 없다.
- 실행 중인 명령이 끊기지 않도록 SSM Agent는 업그레이드 대상에서 제외한다.
- 실패(Failed·TimedOut·Canceled)하면 EventBridge → SNS → Discord로 알린다.

## Alternatives
대안 | 버린 이유
--- | ---
새 AMI로 인스턴스 교체 | 가장 깨끗하지만 단일 서버라 교체마다 수 분 중단 + 수동 작업. 자동화하려면 ASG나 Image Builder가 필요
Patch Manager(`AWS-RunPatchBaseline`) | 노드의 저장소 설정을 그대로 따르므로 릴리스가 고정된 AL2023에서는 새 보안 패치를 못 받음. 고정을 풀려면 `releasever=latest`를 영구 설정해야 하는데, 그러면 보안 외 모든 업데이트까지 따라감
수동 패치 | 1인 운영에서 잊어버림

## Consequences
**얻은 것** : 보안 패치가 최대 1주 안에 적용된다. 재부팅이 필요한 주에만 짧게 중단된다. 재부팅 후 DB까지 정상인지는 외부 헬스체크(`/api/actuator/health`, ADR 005)가 자동으로 확인한다.

**감수한 것** :
- **재부팅 중 1~3분 중단** : 일요일 새벽이라 사용자 영향이 작다고 판단. 헬스체크 알람은 15분 중 2회 실패해야 울리므로 정상 재부팅으로는 알림이 오지 않는다.
- **docker 패키지가 업데이트되면 재부팅이 없어도 컨테이너가 재시작**될 수 있다.
- **검증 없이 운영에 바로 적용** : 별도 검증 환경이 없다(ADR 001). 문제가 생기면 직전 EBS 스냅샷으로 복구한다.
- **SSM Agent는 이 문서로 갱신되지 않는다** : 별도 association(`AWS-UpdateSSMAgent`)으로 패치 30분 뒤에 갱신한다.

**다시 검토할 시점** : 인스턴스가 2대 이상이 되거나 무중단이 필요해질 때(새 AMI 기반 교체로 전환)