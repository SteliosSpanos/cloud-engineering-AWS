output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.test_vpc.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.test_public_subnet.id
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = aws_subnet.test_private_subnet.id
}

output "private_subnet_id_backup" {
  description = "Private subnet (backup) ID"
  value       = aws_subnet.test_private_subnet_backup.id
}

output "instance_public_ip" {
  description = "Instance public IP (Elastic IP)"
  value       = aws_eip.test_instance.public_ip
}

output "db_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "ssh_key_path" {
  description = "Path to the generated private key file"
  value       = local_file.private_key.filename
}

output "ssh_command" {
  description = "SSH command to access instance"
  value       = "ssh -i ${local_file.private_key.filename} ec2-user@${aws_eip.test_instance.public_ip}"
}
