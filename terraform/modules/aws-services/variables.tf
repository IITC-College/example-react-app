variable "name" {
  description = "Prefix used for account-wide security service resource names."
  type        = string
  default     = "example-react-app"
}

variable "backup_schedule" {
  description = "Cron expression for the daily AWS Backup plan rule."
  type        = string
  default     = "cron(0 5 * * ? *)"
}

variable "backup_cold_storage_after_days" {
  type    = number
  default = 30
}

variable "backup_delete_after_days" {
  type    = number
  default = 120
}

variable "backup_tag_key" {
  description = "Resources tagged with this key/value are included in the AWS Backup plan."
  type        = string
  default     = "Backup"
}

variable "backup_tag_value" {
  type    = string
  default = "true"
}

variable "securityhub_standards_arn" {
  description = "Security Hub standard ARN to subscribe to. Leave null to use the AWS Foundational Security Best Practices standard for the current region."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
