output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.test-vpc.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.test-subnet.id
}

output "instance_public_ip" {
  description = "Instance public IP (Elastic IP)"
  value       = aws_eip.test-instance.public_ip
}
