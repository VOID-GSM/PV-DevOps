variable "name" { type = string }
variable "schedule" {
  description = "UTC 기준 cron. 기본값은 매일 04:00 KST"
  type        = string
  default     = "cron(0 19 * * ? *)"
}

variable "retention_days" {
  type    = number
  default = 7
}

variable "alarm_topic_arn" { type = string }