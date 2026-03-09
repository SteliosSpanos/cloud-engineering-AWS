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
