variable "env_name" {
  description = "Environment name used for tagging (e.g. dev, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to deploy into"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs for the DB subnet group (should span multiple AZs)"
  type        = list(string)
}

variable "webserver_sg_id" {
  description = "Security group ID of the webserver — granted inbound access to the DB"
  type        = string
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
  default     = "app"
}

variable "db_username" {
  description = "Master username for the DB instance"
  type        = string
  default     = "appuser"
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GiB"
  type        = number
  default     = 20
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy (set false for prod)"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection (set true for prod)"
  type        = bool
  default     = false
}
