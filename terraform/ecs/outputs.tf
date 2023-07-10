output "ECR_REPOSITORY" {
  value = aws_ecr_repository.flask-webapp.name
}

output "AWS_REGION" {
  value = data.aws_region.current
}

output "ECS_SERVICE" {
  value = aws_ecs_service.flask_webapp.name
}

output "ECS_CLUSTER" {
  value = aws_ecs_cluster.cluster.name
}

output "ECS_TASK_DEFINITION" {
  value = aws_ecs_task_definition.service.arn_without_revision
}

output "CONTAINER_NAME" {
  value = local.container_name
}