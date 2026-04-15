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
