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

variable "subnet_ids" {
  description = "List of subnet IDs for the ASG and ALB (should span multiple AZs)"
  type        = list(string)
}

variable "min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 1
}

variable "public_key" {
  description = "SSH public key material for the key pair"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH into the instance (restrict to your IP)"
  type        = string
}

variable "zone_id" {
  description = "Route 53 hosted zone ID for DNS validation and alias record"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the ACM certificate and Route 53 alias record"
  type        = string
}
