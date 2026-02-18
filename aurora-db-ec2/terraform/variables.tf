variable "profile" {
  type        = string
  description = "AWS CLI profile"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "project_name" {
  type        = string
  description = "Project name for resource naming"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC CIDR block"
}

variable "public_subnet_cidr" {
  type        = string
  default     = "10.0.1.0/24"
  description = "Public subnet CIDR"
}

variable "private_subnet_cidr" {
  type        = string
  default     = "10.0.2.0/24"
  description = "Private subnet CIDR"
}

variable "private_subnet_cidr_backup" {
  type        = string
  default     = "10.0.3.0/24"
  description = "Private subnet (backup) CIDR"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type"
}

variable "db_name" {
  type        = string
  description = "Name of the RDS database"
}

variable "db_username" {
  type        = string
  description = "Master username for RDS"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Master password for RDS"
}