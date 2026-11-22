output "deploy_document_name" {
  value = aws_ssm_document.deploy.name
}

output "deploy_document_arn" {
  value = aws_ssm_document.deploy.arn
}

output "patch_document_name" {
  value = aws_ssm_document.os_patch.name
}