resource "aws_vpc" "cluster_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "cluster_public_subnet" {
  vpc_id                  = aws_vpc.cluster_vpc.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_internet_gateway" "cluster-igw" {
  vpc_id = aws_vpc.cluster_vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "cluster_public_rt" {
  vpc_id = aws_vpc.cluster_vpc.id

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "cluster_public_assoc" {
  subnet_id      = aws_subnet.cluster_public_subnet.id
  route_table_id = aws_route_table.cluster_public_rt.id
}

resource "aws_route" "route_to_igw" {
  route_table_id         = aws_route_table.cluster_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.cluster-igw.id
}
