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

variable "alb_subnet_ids" {
  description = "List of public subnet IDs for the ALB (should span multiple AZs)"
  type        = list(string)
}

variable "subnet_ids" {
  description = "List of private subnet IDs for the ASG instances (should span multiple AZs)"
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

variable "cpu_scaling_target" {
  description = "Target average CPU utilization (%) that triggers scale out/in"
  type        = number
  default     = 50
}

variable "alb_request_scaling_target" {
  description = "Target number of ALB requests per instance that triggers scale out/in"
  type        = number
  default     = 1000
}

variable "alarm_email" {
  description = "Email address to receive CloudWatch alarm notifications"
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
