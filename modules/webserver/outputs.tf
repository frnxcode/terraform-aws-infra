output "instance_ami" {
  value = aws_instance.webserver.ami
}

output "instance_arn" {
  value = aws_instance.webserver.arn
}
