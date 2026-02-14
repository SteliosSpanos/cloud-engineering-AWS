
resource "tls_private_key" "test-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "test-key" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.test-key.public_key_openssh

  tags = {
    Name = "${var.project_name}-key"
  }
}

resource "local_file" "private-key" {
  content         = tls_private_key.test-key.private_key_pem
  filename        = "${path.module}/.ssh/${var.project_name}-key.pem"
  file_permission = "0400"
}

resource "aws_instance" "test-instance" {
  instance_type          = var.instance_type
  ami                    = data.aws_ami.amazon_linux_2023.id
  key_name               = aws_key_pair.test-key.key_name
  vpc_security_group_ids = [aws_security_group.test-public-sg.id]
  subnet_id              = aws_subnet.test-subnet.id

  tags = {
    Name = "${var.project_name}-instance"
  }
}

resource "aws_eip" "test-instance" {
  domain   = "vpc"
  instance = aws_instance.test-instance.id

  depends_on = [aws_internet_gateway.test-igw]

  tags = {
    Name = "${var.project_name}-instance-eip"
  }
}
