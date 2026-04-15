variable "instance_type" {
  description = "Type of EC2 instance to provision"
  default     = "t3.nano"
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  default     = "webserver"
}

variable "vpc_id" {
  description = "ID of the VPC to deploy into"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet to deploy the EC2 instance into"
  type        = string
}

variable "public_key" {
  description = "SSH public key material for the key pair"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH into the instance (restrict to your IP)"
  type        = string
}
