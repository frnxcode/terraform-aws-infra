output "instance_ami" {
  description = "AMI used by the launch template"
  value       = data.aws_ami.app_ami.id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.webserver.dns_name
}
