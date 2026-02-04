output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.homelab_vpc.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.homelab_public_subnet.id
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = aws_subnet.homelab_private_subnet.id
}

output "jump_box_public_ip" {
  description = "Jump box public IP (Elastic IP)"
  value       = aws_eip.jump_box.public_ip
}

output "nat_instance_public_ip" {
  description = "NAT instance public IP (Elastic IP)"
  value       = aws_eip.nat_instance.public_ip
}

output "nat_instance_private_ip" {
  description = "NAT instance private IP"
  value       = aws_instance.nat_instance.private_ip
}

output "main_vm_private_ip" {
  description = "Main VM private IP"
  value       = aws_instance.main_vm.private_ip
}

output "jump_box_private_ip" {
  description = "Jump box private IP"
  value       = aws_instance.jump_box.private_ip
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.homelab.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.homelab.arn
}

output "ssh_commands" {
  description = "SSH connection commands"
  value = {
    jump_box = "ssh -A -i ${path.module}/.ssh/${var.project_name}-key.pem ec2-user@${aws_eip.jump_box.public_ip}"
    main_vm  = "From jump box: ssh ec2-user@${aws_instance.main_vm.private_ip}"
  }
}