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
          "token.actions.githubusercontent.com:sub" = [for r in var.github_repos : "repo:${r}:ref:refs/heads/main"]
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

# EC2에서 실행될 배포 명령. service와 tag는 허용된 값/형식만 받음
resource "aws_ssm_document" "deploy" {
  name            = "${var.name}-deploy"
  document_type   = "Command"
  document_format = "YAML"

  content = <<-YAML
    schemaVersion: "2.2"
    description: Sync deploy bundle from S3 and roll out the backend
    parameters:
      service:
        type: String
        allowedValues: [backend, bundle]
      tag:
        type: String
        default: "-"
        allowedPattern: "^[A-Za-z0-9._-]{1,128}$"
    mainSteps:
      - action: aws:runShellScript
        name: deploy
        inputs:
          timeoutSeconds: "900"
          runCommand:
            - set -euo pipefail
            - set -a; . /etc/teamops.env; set +a
            - aws s3 sync "s3://$OPS_BUCKET/deploy/" /opt/teamops/ --delete --only-show-errors
            - if [ "{{ service }}" = bundle ]; then bash /opt/teamops/scripts/deploy.sh up; else bash /opt/teamops/scripts/deploy.sh "{{ service }}" "{{ tag }}"; fi
  YAML
}