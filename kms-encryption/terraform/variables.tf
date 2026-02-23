variable "profile" {
  type        = string
  description = "AWS CLI profile"
}

variable "region" {
  type    = string
  default = "AWS region"
}

variable "project_name" {
  type        = string
  default     = "kms-encryption"
  description = "Project name for resource naming"
}

variable "test_user_name" {
  type        = string
  description = "Name of the IAM test user that gets DynamoDB access but no KMS access"
}
