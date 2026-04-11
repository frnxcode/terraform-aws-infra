variable "instance_type" {
  description = "Type of EC2 instance to provision"
  default     = "t3.nano"
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  default     = "webserver"
}

variable "aws_region" {
  description = "AWS region to deploy into"
  default     = "us-west-2"
}
