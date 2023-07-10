output "private_subnet_id1" {
  value = module.mediaconnect-useast2.private_subnet_id
}

output "vpc_id1" {
  value = module.mediaconnect-useast2.vpc_id
}

output "security_group1" {
  value = module.mediaconnect-useast2.security_group
}

output "flow_arns1" {
  value = module.mediaconnect-useast2.flow_arns
}

output "private_subnet_id2" {
  value = module.mediaconnect-euwest2.private_subnet_id
}

output "vpc_id2" {
  value = module.mediaconnect-euwest2.vpc_id
}

output "security_group2" {
  value = module.mediaconnect-euwest2.security_group
}

output "flow_arns2" {
  value = module.mediaconnect-euwest2.flow_arns
}

output "role_arn" {
  value = aws_iam_role.mediaconnect.arn
}

output "srt_password" {
  value     = aws_secretsmanager_secret_version.srt-password.secret_string
  sensitive = true
}
