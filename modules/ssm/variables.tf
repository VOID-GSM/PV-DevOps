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

variable "instance_id" {
  description = "OS 보안 패치를 적용할 인스턴스 ID"
  type        = string
}

variable "alarm_topic_arn" {
  description = "패치 실패 알림을 보낼 SNS 토픽 ARN"
  type        = string
}

variable "patch_schedule" {
  description = "UTC 기준. 기본값은 일요일 05:00 KST (매일 04:00 KST 백업 이후)"
  type        = string
  default     = "cron(0 20 ? * SAT *)"
}
