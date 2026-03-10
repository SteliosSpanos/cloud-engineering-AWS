output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "bastion_public_ip" {
  description = "Bastion EC2 public IP"
  value       = aws_instance.bastion.public_ip
}

output "kubeconfig_command" {
  description = "Run this on the bastion to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region ${var.region}"
}

output "ecr_repository_url" {
  description = "ECR repository URL for docker push"
  value       = aws_ecr_repository.app.repository_url
}

output "docker_push_commands" {
  description = "Commands to authenticate and push the image"
  value       = <<-EOT
    aws ecr get-login-password --profile ${var.profile} --region ${var.region} | docker login --username AWS --password-stdin ${aws_ecr_repository.app.repository_url}
    docker build -t ${aws_ecr_repository.app.repository_url}:latest ./nextwork-flask-backend
    docker push ${aws_ecr_repository.app.repository_url}:latest
  EOT
}
