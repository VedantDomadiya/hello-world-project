output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}

output "ecs_task_definition_family" {
  description = "Family name of the ECS task definition"
  value       = aws_ecs_task_definition.app.family
}

output "ecs_tasks_sg_id" {
  description = "The ID of the security group created for the ECS tasks"
  value       = aws_security_group.ecs_tasks.id
}

# Useful for debugging / direct access without LB
output "ecs_task_public_ip_example_command" {
  description = "Example command to get the public IP of a running task (run after deployment)"
  value       = "aws ecs list-tasks --cluster ${aws_ecs_cluster.main.name} --service-name ${aws_ecs_service.app.name} --query 'taskArns[0]' --output text | xargs -I {} aws ecs describe-tasks --cluster ${aws_ecs_cluster.main.name} --tasks {} --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value | [0]' --output text | xargs -I {} aws ec2 describe-network-interfaces --network-interface-ids {} --query 'NetworkInterfaces[0].Association.PublicIp' --output text --region ${var.aws_region}"
}