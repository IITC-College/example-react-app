output "alb_dns_name" {
  description = "DNS name of the internet-facing ALB, for the Cloudflare CNAME target."
  value       = aws_lb.internet.dns_name
}

output "alb_zone_id" {
  value = aws_lb.internet.zone_id
}

output "alb_arn" {
  value = aws_lb.internet.arn
}

output "gwlb_arn" {
  value = aws_lb.gwlb.arn
}

output "fortigate_instance_ids" {
  value = { for k, v in aws_instance.fortigate : k => v.id }
}

output "fortigate_security_group_id" {
  value = aws_security_group.fortigate.id
}
