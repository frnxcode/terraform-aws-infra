output "instance_ami" {
  value = module.webserver.instance_ami
}

output "instance_arn" {
  value = module.webserver.instance_arn
}

output "public_ip" {
  value = module.webserver.public_ip
}

output "public_dns" {
  value = module.webserver.public_dns
}
