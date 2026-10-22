data "aws_region" "current" {}
data "aws_subnet" "this" {id = var.subnet_id}
data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_ebs_volume" "data" {
  availability_zone = data.aws_subnet.this.availability_zone
  type = "gp3"
  size = 10
  encrypted = true
  tags = {Name = "${var.name}-data", Backup = "daily"}
}

resource "aws_instance" "this" {
  ami = data.aws_ssm_parameter.ami.insecure_value
  instance_type = var.instance_type
  subnet_id = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile = aws_iam_instance_profile.this.name

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    data_volume = replace(aws_ebs_volume.data.id, "-", "")
    region = data.aws_region.current.region
    registry = var.registry_url
    ops_bucket = var.ops_bucket
    uploads_bucket = var.uploads_bucket
    ssm_path = var.ssm_path
  })

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_tokens = "required" 
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 16
    encrypted = true
  }

  tags = {Name = var.name}
  lifecycle {ignore_changes = [ami]}
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id = aws_ebs_volume.data.id
  instance_id = aws_instance.this.id
  stop_instance_before_detaching = true
}

resource "aws_eip" "this" {
  domain = "vpc"
  instance = aws_instance.this.id
}

resource "aws_iam_role" "this" {
  name = "${var.name}-app"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_instance_profile" "this" {
    name = "${var.name}-app"
    role = aws_iam_role.this.name
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",       # SSM 접속·명령 실행
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly", # ECR 이미지 pull
  ])
  
  role = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "app" {
  name = "app"
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { # 배포 번들 받기, DB 백업 올리기 (삭제 권한은 주지 않음)
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject"]
        Resource = ["arn:aws:s3:::${var.ops_bucket}", "arn:aws:s3:::${var.ops_bucket}/*"]
      },
      { # 과제 첨부파일
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${var.uploads_bucket}/*"
      },
      { # 앱 시크릿 
        Effect   = "Allow"
        Action   = "ssm:GetParametersByPath"
        Resource = "arn:aws:ssm:${data.aws_region.current.region}:*:parameter${trimsuffix(var.ssm_path, "/")}*"
      },
    ]
  })
}