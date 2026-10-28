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
        Resource = [var.instance_arn, var.deploy_document_arn]
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