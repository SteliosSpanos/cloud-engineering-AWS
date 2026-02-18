resource "aws_vpc" "test_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "test_public_subnet" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_subnet" "test_private_subnet" {
  vpc_id            = aws_vpc.test_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-private-subnet"
  }
}

resource "aws_subnet" "test_private_subnet_backup" {
  vpc_id            = aws_vpc.test_vpc.id
  cidr_block        = var.private_subnet_cidr_backup
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.project_name}-private-subnet-backup"
  }
}

resource "aws_internet_gateway" "test_igw" {
  vpc_id = aws_vpc.test_vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "test_route_table" {
  vpc_id = aws_vpc.test_vpc.id

  tags = {
    Name = "${var.project_name}-rt"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.test_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.test_igw.id
}

resource "aws_route_table_association" "test_public_assoc" {
  subnet_id      = aws_subnet.test_public_subnet.id
  route_table_id = aws_route_table.test_route_table.id
}
