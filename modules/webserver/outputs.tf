output "instance_ami" {
  description = "AMI used by the launch template"
  value       = data.aws_ami.app_ami.id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.webserver.dns_name
}

output "domain_name" {
  description = "Custom domain name serving the application over HTTPS"
  value       = "https://${var.domain_name}"
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.webserver.arn
}

output "iam_role_name" {
  description = "Name of the IAM role attached to the webserver instances"
  value       = aws_iam_role.webserver.name
}

output "webserver_sg_id" {
  description = "ID of the webserver security group"
  value       = aws_security_group.webserver.id
}
