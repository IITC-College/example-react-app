output "internal_alb_dns_name" {
  value = aws_lb.internal.dns_name
}

output "internal_alb_arn" {
  value = aws_lb.internal.arn
}

output "app_security_group_id" {
  value = aws_security_group.app.id
}

output "docdb_cluster_endpoint" {
  value = aws_docdb_cluster.this.endpoint
}

output "docdb_secret_arn" {
  value = aws_secretsmanager_secret.docdb.arn
}

output "oracle_endpoint" {
  value = aws_db_instance.oracle.endpoint
}

output "oracle_secret_arn" {
  value = aws_secretsmanager_secret.oracle.arn
}

output "redis_primary_endpoint" {
  value = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "redis_reader_endpoint" {
  value = aws_elasticache_replication_group.this.reader_endpoint_address
}

output "redis_auth_secret_arn" {
  value = aws_secretsmanager_secret.redis.arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.this.repository_url
}

output "ecr_repository_arn" {
  value = aws_ecr_repository.this.arn
}

output "ecs_cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "ecs_service_arn" {
  value = aws_ecs_service.app.id
}

output "task_execution_role_arn" {
  value = aws_iam_role.execution.arn
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}
