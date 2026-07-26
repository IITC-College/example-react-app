output "cloudtrail_bucket_name" {
  value = aws_s3_bucket.cloudtrail.id
}

output "guardduty_detector_id" {
  value = aws_guardduty_detector.this.id
}

output "backup_vault_name" {
  value = aws_backup_vault.this.name
}

output "backup_plan_id" {
  value = aws_backup_plan.this.id
}
