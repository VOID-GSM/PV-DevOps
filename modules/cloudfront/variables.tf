variable "name" { type = string }
variable "api_origin_domain" { type = string }
variable "uploads_bucket" {
  description = "presigned 업로드 대상 버킷 이름 (CSP connect-src/img-src 허용)"
  type        = string
}