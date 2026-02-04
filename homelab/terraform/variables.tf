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
  default     = "homelab"
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

variable "ssh_key_name" {
  type        = string
  description = "Name of EC2 key pair for SSH access"
}

variable "instance_types" {
  type = object({
    jump_box = string
    nat      = string
    main_vm  = string
  })
  default = {
    jump_box = "t3.micro"
    nat      = "t3.micro"
    main_vm  = "t3.micro"
  }
  description = "EC2 instance types for each instance"
}