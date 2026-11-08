output "instance_id" { value = aws_instance.this.id }
output "instance_arn" { value = aws_instance.this.arn }
output "public_ip" { value = aws_eip.this.public_ip }
output "public_dns" { value = aws_eip.this.public_dns }
output "log_group_name" { value = aws_cloudwatch_log_group.backend.name }