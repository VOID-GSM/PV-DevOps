variable "name" { type = string }
variable "instance_id" { type = string }
variable "alarm_topic_arn" { type = string }

variable "health_check_function_arn" { type = string }
variable "health_check_function_name" { type = string }

variable "health_check_targets" {
  description = "이름 → 확인할 URL (5xx·타임아웃이면 실패로 기록)"
  type        = map(string)
}

variable "health_check_namespace" {
  type    = string
  default = "PV/HealthCheck"
}