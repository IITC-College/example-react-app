output "state_bucket_name" {
  description = "S3 bucket name to use in ../backend.tf"
  value       = aws_s3_bucket.tf_state.id
}

output "lock_table_name" {
  description = "DynamoDB table name to use in ../backend.tf"
  value       = aws_dynamodb_table.tf_locks.name
}
