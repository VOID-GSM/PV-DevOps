variable "name" {
  type = string
}

variable "backup_retention_days" {
  type    = number
  default = 14
}

variable "cors_allowed_origins" {
  description = "업로드 버킷에 브라우저 접근을 허용할 Origin"
  type        = list(string)
}