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
  default     = "eks-cluster"
  description = "Project name for resource naming"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC CIDR block"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.31"
  description = "EKS Kubernetes version"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type for the bastion host"
}

variable "node_instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type for EKS worker nodes"
}
