# 주 1회 OS 보안 패치 (ADR 007)
# AL2023은 저장소가 AMI 릴리스 버전에 고정돼 있어 그냥 dnf upgrade로는 이후에 나온 보안 패치를 받지 못한다.
# --releasever=latest --security 로 보안 업데이트만 최신 릴리스에서 받아 설치한다.
resource "aws_ssm_document" "os_patch" {
  name            = "${var.name}-os-patch"
  document_type   = "Command"
  document_format = "YAML"

  content = <<-YAML
    schemaVersion: "2.2"
    description: Install AL2023 security updates and reboot only if required
    mainSteps:
      - action: aws:runShellScript
        name: patch
        inputs:
          timeoutSeconds: "1800"
          runCommand:
            - |
              set -euo pipefail

              # 재부팅 후 /data 마운트보다 docker가 먼저 뜨면 PostgreSQL이 빈 디렉터리로 시작함 → 마운트 이후로 순서 고정
              dropin=/etc/systemd/system/docker.service.d/10-data-mount.conf
              if [ ! -f "$dropin" ]; then
                mkdir -p "$(dirname "$dropin")"
                printf '[Unit]\nRequiresMountsFor=/data\n' > "$dropin"
                systemctl daemon-reload
              fi
              mountpoint -q /data || { echo "/data is not mounted, abort" >&2; exit 1; }

              dnf install -y -q dnf-plugins-core   # needs-restarting
              echo "== security updates"
              dnf check-update --releasever=latest --security || true   # 업데이트가 있으면 exit 100
              # SSM Agent는 제외: 이 명령을 실행 중인 agent가 업그레이드로 재시작되면 실행 결과가 끊긴다
              dnf upgrade -y --releasever=latest --security --exclude=amazon-ssm-agent

              if dnf needs-restarting -r > /dev/null; then
                echo "no reboot required"
              else
                echo "core packages updated, rebooting in 1 minute"
                shutdown -r +1   # SSM이 성공을 보고할 시간을 주고 재부팅
              fi
  YAML
}

resource "aws_ssm_association" "os_patch" {
  name                        = aws_ssm_document.os_patch.name
  association_name            = "${var.name}-os-patch-weekly"
  document_version            = aws_ssm_document.os_patch.latest_version
  schedule_expression         = var.patch_schedule
  apply_only_at_cron_interval = true # 생성·변경 직후 바로 실행(=재부팅)되지 않게

  targets {
    key    = "InstanceIds"
    values = [var.instance_id]
  }
}

# 패치 실패 알림 (백업 실패 알림과 같은 방식: EventBridge → SNS → Discord)
# State Manager 실행 결과가 어느 이벤트로 오는지 문서상 명확하지 않아 두 이벤트를 모두 받는다
resource "aws_cloudwatch_event_rule" "os_patch_failed" {
  name = "${var.name}-os-patch-failed"
  event_pattern = jsonencode({
    source = ["aws.ssm"]
    "detail-type" = [
      "EC2 Command Invocation Status-change Notification",
      "EC2 State Manager Instance Association State Change",
    ]
    detail = {
      "document-name" = [aws_ssm_document.os_patch.name]
      status          = ["Failed", "TimedOut", "Canceled", "Cancelled"]
    }
  })
}

resource "aws_cloudwatch_event_target" "os_patch_failed" {
  rule = aws_cloudwatch_event_rule.os_patch_failed.name
  arn  = var.alarm_topic_arn

  input_transformer {
    input_paths = {
      status   = "$.detail.status"
      instance = "$.detail.instance-id"
    }
    input_template = <<-EOT
      {"title": "❌ OS 보안 패치 실패 (<status>)", "description": "Systems Manager → Run Command / State Manager에서 출력을 확인하세요", "instance": "<instance>"}
    EOT
  }
}