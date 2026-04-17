variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "database_name" {
  description = "Initial database name"
  type        = string
  default     = "jeevagandb"
}

variable "master_username" {
  description = "Master DB username"
  type        = string
  default     = "jeevaganadmin"
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.r6g.large"
}

variable "instance_count" {
  description = "Number of Aurora instances"
  type        = number
  default     = 2
}

variable "backup_retention_period" {
  description = "Days to retain backups"
  type        = number
  default     = 7
}
