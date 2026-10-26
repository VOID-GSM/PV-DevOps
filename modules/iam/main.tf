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
      {
        Effect = "Allow",
        Action = "ssm:GetCommandInvocation",
      Resource = "*" },
      { # 프론트 정적 파일 업로드
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:PutObject", "s3:DeleteObject"]
        Resource = [var.web_bucket_arn, "${var.web_bucket_arn}/*"]
      },
      { # 배포 후 CloudFront 캐시 갱신
        Effect   = "Allow"
        Action   = "cloudfront:CreateInvalidation"
        Resource = var.web_distribution_arn
      },
    ]
  })
}

resource "aws_ssm_document" "deploy" {
  name            = "${var.name}-deploy"
  document_type   = "Command"
  document_format = "YAML"

  content = <<-YAML
    schemaVersion: "2.2"
    description: Pull backend image from ECR and restart with docker compose (rollback on failure)
    parameters:
      tag:
        type: String
        description: Image tag (git commit SHA)
        allowedPattern: "^[0-9a-f]{7,40}$"
    mainSteps:
      - action: aws:runShellScript
        name: deploy
        inputs:
          timeoutSeconds: "900"
          runCommand:
            - |
              set -euo pipefail
              export AWS_REGION=${data.aws_region.current.region}
              REGISTRY=${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com
              REPO="$REGISTRY/${var.name}-backend"
              cd /data/backend

              aws s3 cp "s3://${var.ops_bucket}/deploy/backend/docker-compose.yml" docker-compose.yml --only-show-errors
              aws ecr get-login-password | docker login -u AWS --password-stdin "$REGISTRY" > /dev/null
              prev="$(cat .backend_tag 2>/dev/null || true)"

              deploy() {
                export BACKEND_IMAGE="$REPO:$1"
                docker pull -q "$BACKEND_IMAGE"
                docker compose up -d --no-build --remove-orphans --wait --wait-timeout 300
              }

              if deploy "{{ tag }}"; then
                echo "{{ tag }}" > .backend_tag
                docker image prune -af --filter "until=72h" > /dev/null
                echo "deployed {{ tag }}"
                exit 0
              fi

              echo "!!! deploy failed: {{ tag }}" >&2
              docker compose logs --tail 80 backend || true
              if [ -n "$prev" ]; then
                deploy "$prev" && echo "rolled back to $prev" >&2
              fi
              exit 1
  YAML
}