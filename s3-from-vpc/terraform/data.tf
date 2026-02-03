data "aws_availability_zones" "available" {
  state = "available"
}

data "external" "my_ip" {
  program = ["bash", "${path.module}/scripts/my_ip_json.sh"]
}

data "aws_ami" "dev-ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}