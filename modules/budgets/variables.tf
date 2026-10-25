variable "name" { type = string }
variable "alarm_topic_arn" { type = string }

variable "monthly_limit_usd" {
  type    = string
  default = "30"
}