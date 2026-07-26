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
