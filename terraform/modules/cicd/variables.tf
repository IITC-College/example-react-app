variable "github_org" {
  description = "GitHub organization/owner that owns the repo (e.g. \"IITC-College\")."
  type        = string
}

variable "github_repo" {
  description = "GitHub repo name (e.g. \"example-react-app\")."
  type        = string
}

variable "create_oidc_provider" {
  description = "Whether to create the GitHub Actions OIDC provider. An AWS account can only register token.actions.githubusercontent.com once — set this false if your account already has one, and the module will look it up instead."
  type        = bool
  default     = true
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs the deploy role may push images to."
  type        = list(string)
}

variable "ecs_service_arns" {
  description = "ECS service ARNs the deploy role may update."
  type        = list(string)
}

variable "task_role_arns" {
  description = "ECS task + execution role ARNs the deploy role needs iam:PassRole on to register new task definition revisions."
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
