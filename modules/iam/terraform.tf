resource "aws_iam_role" "terraform_plan" {
  name                 = "${var.name}-gha-terraform-plan"
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.infra_repo}:pull_request",
            "repo:${var.infra_repo}:ref:refs/heads/main",
          ]
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_plan" {
  role       = aws_iam_role.terraform_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "terraform_plan" {
  name = "state-and-deny-secrets"
  role = aws_iam_role.terraform_plan.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { # state 읽기
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetObject"]
        Resource = ["arn:aws:s3:::${var.state_bucket}", "arn:aws:s3:::${var.state_bucket}/*"]
      },
      { # 락 파일만 쓰기 (state 파일 자체는 수정 불가)
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${var.state_bucket}/*.tflock"
      },
      { # 우리 계정 파라미터 값 조회 차단 (계정 ID 없는 AWS 공개 파라미터는 허용 → AMI 조회 가능)
        # GetParameter* = GetParameter, GetParameters, GetParametersByPath, GetParameterHistory
        # GetParameterHistory도 --with-decryption으로 SecureString 평문을 돌려주므로 함께 막아야 함
        Effect   = "Deny"
        Action   = "ssm:GetParameter*"
        Resource = "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/*"
      },
      { # 업로드 버킷의 사용자 파일 읽기 차단 (ReadOnlyAccess에 s3:GetObject 포함, plan에는 불필요)
        Effect   = "Deny"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "arn:aws:s3:::${var.uploads_bucket}/*"
      },
      {
        Effect   = "Deny"
        Action   = "secretsmanager:GetSecretValue"
        Resource = "*"
      },
    ]
  })
}
data "aws_caller_identity" "current" {}
