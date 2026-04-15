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
