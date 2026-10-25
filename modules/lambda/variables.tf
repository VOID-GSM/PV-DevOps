variable "name" { type = string }

variable "source_file" {
  description = "파이썬 파일 경로. 파일 안에 handler(event, context) 함수가 있어야 함"
  type = string
}

variable "environment" {
  type = map(string)
  default = {}
}

variable "policy_statements" {
  description = "IAM 정책 Statement 목록 (함수에 필요한 추가 권한)"
  type = any
  default = []
}

variable "timeout" {
  type = number
  default = 10
}

variable "log_retention_days" {
  type = number
  default = 14
}