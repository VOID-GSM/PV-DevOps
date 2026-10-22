data "aws_region" "current" {}
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "deploy" {
  name = "${var.name}-gha-deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = flatten([for r in var.github_repos : [for b in var.deploy_branches : "repo:${r}:ref:refs/heads/${b}"]])
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "deploy" {
  name = "deploy"
  role = aws_iam_role.deploy.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "ecr:GetAuthorizationToken", Resource = "*" },
      { # 백엔드 이미지 push
        Effect   = "Allow"
        Action   = ["ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage"]
        Resource = var.ecr_repository_arns
      },
      { # 배포 번들(compose, nginx 설정, 스크립트) 업로드
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:PutObject", "s3:DeleteObject"]
        Resource = ["arn:aws:s3:::${var.ops_bucket}", "arn:aws:s3:::${var.ops_bucket}/deploy/*"]
      },
      { # 아래 배포 문서만 실행 가능 (임의 셸 명령은 불가)
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = [var.instance_arn, aws_ssm_document.deploy.arn]
      },
      { Effect = "Allow", Action = "ssm:GetCommandInvocation", Resource = "*" },
    ]
  })
}

# EC2에서 실행될 배포 명령: S3에 올라온 백엔드 소스를 받아 서버에서 빌드/재시작
resource "aws_ssm_document" "deploy" {
  name            = "${var.name}-deploy"
  document_type   = "Command"
  document_format = "YAML"

  content = <<-YAML
    schemaVersion: "2.2"
    description: Sync backend source from S3 and restart with docker compose
    mainSteps:
      - action: aws:runShellScript
        name: deploy
        inputs:
          timeoutSeconds: "1200"
          runCommand:
            - set -euo pipefail
            - export AWS_REGION=${data.aws_region.current.region}
            - "[ -x /usr/local/lib/docker/cli-plugins/docker-buildx ] || { curl -fsSL -o /usr/local/lib/docker/cli-plugins/docker-buildx https://github.com/docker/buildx/releases/download/v0.38.1/buildx-v0.38.1.linux-arm64 && chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx; }"
            - mkdir -p /data/backend && cd /data/backend
            - aws s3 sync "s3://${var.ops_bucket}/deploy/backend/" . --delete --exclude ".env" --only-show-errors
            - if [ -f gradlew ]; then chmod +x gradlew; fi
            - docker compose up -d --build --remove-orphans --wait --wait-timeout 300
            - docker image prune -f
            - docker compose ps
  YAML
}