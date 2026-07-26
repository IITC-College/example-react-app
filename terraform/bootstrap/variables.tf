variable "region" {
  description = "AWS region for the state bucket and lock table."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name for Terraform remote state. Rename before use."
  type        = string
  default     = "CHANGEME-example-react-app-tfstate"
}

variable "lock_table_name" {
  description = "DynamoDB table name for Terraform state locking."
  type        = string
  default     = "example-react-app-tf-locks"
}

variable "tags" {
  description = "Common tags applied to bootstrap resources."
  type        = map(string)
  default = {
    Project   = "example-react-app"
    ManagedBy = "terraform"
    Component = "state-bootstrap"
  }
}
