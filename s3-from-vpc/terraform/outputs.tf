output "dev_ip" {
  value       = aws_instance.dev-node.public_ip
  description = "Public IP address of the dev EC2 instance"
}
