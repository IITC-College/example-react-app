output "deploy_role_arn" {
  description = "Copy this into the GitHub repo's Actions variables as AWS_DEPLOY_ROLE_ARN."
  value       = aws_iam_role.deploy.arn
}
