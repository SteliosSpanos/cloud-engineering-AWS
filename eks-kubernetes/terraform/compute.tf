resource "aws_key_pair" "bastion" {
  key_name   = "${var.project_name}-key"
  public_key = file("${path.module}/.ssh/bastion.pub")

  tags = {
    Name = "${var.project_name}"
  }
}

resource "aws_iam_policy" "bastion_eks" {
  name        = "${var.project_name}-bastion-eks"
  description = "Allows bastion to generate a kubeconfig for the EKS cluster"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = aws_eks_cluster.this.arn
      }
    ]
  })
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.project_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.project_name}-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "bastion_eks" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.bastion_eks.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}


resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Bastion: SSH in from trusted IP, HTTPS out only"
  vpc_id      = aws_vpc.cluster_vpc.id

  ingress {
    description = "SSH from trusted IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${data.external.my_ip.result.ip}/32"]
  }

  egress {
    description = "HTTPS to AWS APIs and internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = aws_key_pair.bastion.key_name

  user_data                   = templatefile("${path.module}/templates/userdata.tpl", {})
  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-bastion"
  }
}
