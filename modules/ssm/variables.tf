variable "name" {
  description = "리소스 이름 접두사"
  type        = string
}

variable "ops_bucket" {
  description = "배포 파일(compose)이 올라가는 운영 버킷 이름"
  type        = string
}

variable "uploads_bucket" {
  description = "백엔드가 파일을 저장하는 업로드 버킷 이름"
  type        = string
}

variable "log_group" {
  description = "백엔드 컨테이너 로그를 보낼 CloudWatch Logs 그룹 이름"
  type        = string
}