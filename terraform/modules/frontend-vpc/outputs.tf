output "internal_alb_dns_name" {
  value = aws_lb.internal.dns_name
}

output "internal_alb_arn" {
  value = aws_lb.internal.arn
}

output "app_security_group_id" {
  value = aws_security_group.app.id
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.app.name
}
