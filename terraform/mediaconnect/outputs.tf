output "private_subnet_id" {
  value = aws_subnet.mediaconnect_subnet.id
}

output "vpc_id" {
  value = aws_vpc.mediaconnect_vpc.id
}

output "security_group" {
  value = aws_security_group.mediaconnect.id
}

output "flow_arns" {
  value = aws_cloudformation_stack.mediaconnect[*].outputs
}