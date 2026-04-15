output "instance_ami" {
  value = module.webserver.instance_ami
}

output "alb_dns_name" {
  value = module.webserver.alb_dns_name
}

output "url" {
  value = module.webserver.domain_name
}

output "route53_nameservers" {
  description = "Update your domain registrar to use these nameservers"
  value       = aws_route53_zone.main.name_servers
}
