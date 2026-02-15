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

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.test-bucket.id
}

output "ssh_key_path" {
  description = "Path to the generated private key file"
  value       = local_file.private-key.filename
}

output "ssh_command" {
  description = "SSH command to access instance"
  value       = "ssh -i ${local_file.private-key.filename} ec2-user@${aws_eip.test-instance.public_ip}"
}
