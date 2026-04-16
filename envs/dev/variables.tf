variable "public_key" {
  description = "SSH public key material for the webserver key pair"
  type        = string
}

variable "alarm_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
}
