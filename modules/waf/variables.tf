variable "env_name" {
  description = "Environment name used for naming and tagging"
  type        = string
}

variable "alb_arn" {
  description = "ARN of the ALB to associate the Web ACL with"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain WAF logs in CloudWatch"
  type        = number
  default     = 30
}
