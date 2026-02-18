resource "tls_private_key" "test_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "test_key_pair" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.test_key.public_key_openssh

  tags = {
    Name = "${var.project_name}-key"
  }
}

resource "local_file" "private_key" {
  content         = tls_private_key.test_key.private_key_pem
  filename        = "${path.module}/.ssh/${var.project_name}-key.pem"
  file_permission = "0400"
}

resource "aws_instance" "test_instance" {
  instance_type          = var.instance_type
  ami                    = data.aws_ami.amazon_linux_2023.id
  key_name               = aws_key_pair.test_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.test_instance_sg.id]
  subnet_id              = aws_subnet.test_public_subnet.id

  user_data = templatefile("${path.module}/templates/userdata.tpl", {
    db_address  = aws_db_instance.postgres.address
    db_username = var.db_username
    db_password = var.db_password
    db_name     = var.db_name
  })

  tags = {
    Name = "${var.project_name}-instance"
  }
}

resource "aws_eip" "test_instance" {
  domain   = "vpc"
  instance = aws_instance.test_instance.id

  depends_on = [aws_internet_gateway.test_igw]

  tags = {
    Name = "${var.project_name}-instance-eip"
  }
}
