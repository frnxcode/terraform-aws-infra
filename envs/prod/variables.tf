variable "public_key" {
  description = "SSH public key material for the webserver key pair"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH into the instance (e.g. your IP: \"1.2.3.4/32\")"
  type        = string
}

variable "alarm_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
}
