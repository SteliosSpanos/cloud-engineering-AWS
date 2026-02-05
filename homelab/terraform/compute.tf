resource "tls_private_key" "homelab_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "homelab_key" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.homelab_key.public_key_openssh

  tags = {
    Name = "${var.project_name}-key"
  }
}

resource "local_file" "private_key" {
  content         = tls_private_key.homelab_key.private_key_pem
  filename        = "${path.module}/.ssh/${var.project_name}-key.pem"
  file_permission = "0400"
}

resource "aws_instance" "nat_instance" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_types.nat
  subnet_id              = aws_subnet.homelab_public_subnet.id
  vpc_security_group_ids = [aws_security_group.nat_instance.id]
  iam_instance_profile   = aws_iam_instance_profile.nat_instance.name
  key_name               = aws_key_pair.homelab_key.key_name

  source_dest_check = false

  user_data = templatefile("${path.module}/templates/userdata.tpl", {
    private_subnet_cidr = aws_subnet.homelab_private_subnet.cidr_block
  })

  tags = {
    Name = "${var.project_name}-nat-instance"
  }
}

resource "aws_eip" "nat_instance" {
  domain   = "vpc"
  instance = aws_instance.nat_instance.id

  depends_on = [aws_internet_gateway.homelab_igw]

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_instance" "jump_box" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_types.jump_box
  subnet_id              = aws_subnet.homelab_public_subnet.id
  vpc_security_group_ids = [aws_security_group.jump_box.id]
  iam_instance_profile   = aws_iam_instance_profile.jump_box.name
  key_name               = aws_key_pair.homelab_key.key_name

  tags = {
    Name = "${var.project_name}-jump-box"
  }
}

resource "aws_eip" "jump_box" {
  domain   = "vpc"
  instance = aws_instance.jump_box.id

  depends_on = [aws_internet_gateway.homelab_igw]

  tags = {
    Name = "${var.project_name}-jump-box-eip"
  }
}

resource "aws_instance" "main_vm" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_types.main_vm
  subnet_id              = aws_subnet.homelab_private_subnet.id
  vpc_security_group_ids = [aws_security_group.main_vm.id]
  iam_instance_profile   = aws_iam_instance_profile.main_vm.name
  key_name               = aws_key_pair.homelab_key.key_name

  tags = {
    Name = "${var.project_name}-main-vm"
  }
}

resource "local_file" "ssh_config" {
  content = <<-EOF
    # Usage: ssh -F .ssh/config jump-box

    Host jump-box
        HostName ${aws_eip.jump_box.public_ip}
        User ec2-user
        IdentityFile ${abspath("${path.module}/.ssh/${var.project_name}-key.pem")}
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null

    Host nat-instance
        HostName ${aws_instance.nat_instance.private_ip}
        User ec2-user
        IdentityFile ${abspath("${path.module}/.ssh/${var.project_name}-key.pem")}
        ProxyJump jump-box
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null

    Host main-vm
        HostName ${aws_instance.main_vm.private_ip}
        User ec2-user
        IdentityFile ${abspath("${path.module}/.ssh/${var.project_name}-key.pem")}
        ProxyJump jump-box
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
  EOF

  filename        = "${path.module}/.ssh/config"
  file_permission = "0600"
}