
resource "aws_key_pair" "test-auth" {
  key_name   = "dev-key"
  public_key = file("~/.ssh/dev-key.pub")
}

resource "aws_instance" "dev-node" {
  instance_type          = "t3.micro"
  ami                    = data.aws_ami.dev-ami.id
  key_name               = aws_key_pair.test-auth.id
  vpc_security_group_ids = [aws_security_group.test-public-sg.id]
  subnet_id              = aws_subnet.test-subnet.id
  user_data              = file("${path.module}/templates/userdata.tpl")

  root_block_device {
    volume_size = 10 # 10 GB (free tier eligible)
  }

  provisioner "local-exec" {
    command = templatefile("${path.module}/templates/${var.host_os}-ssh-config.tpl", {
      hostname     = self.public_ip,
      user         = "ubuntu",
      identityfile = pathexpand("~/.ssh/dev-key")
    })

    interpreter = var.host_os == "linux" ? ["bash", "-c"] : ["Powershell", "-Command"]
  }

  tags = {
    Name = "dev-node"
  }
}
