output "instance_ami" {
  value = aws_instance.webserver.ami
}

output "instance_arn" {
  value = aws_instance.webserver.arn
}

output "public_ip" {
  value = aws_instance.webserver.public_ip
}

output "public_dns" {
  value = aws_instance.webserver.public_dns
}
