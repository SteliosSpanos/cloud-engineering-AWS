resource "aws_vpc" "test-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

resource "aws_subnet" "test-subnet" {
  vpc_id                  = aws_vpc.test-vpc.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "dev-public"
  }
}

resource "aws_internet_gateway" "test-igw" {
  vpc_id = aws_vpc.test-vpc.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_route_table" "test-route-table" {
  vpc_id = aws_vpc.test-vpc.id

  tags = {
    Name = "dev-public-rt"
  }
}

resource "aws_route" "default-route" {
  route_table_id         = aws_route_table.test-route-table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.test-igw.id
}

resource "aws_route_table_association" "test-public-assoc" {
  subnet_id      = aws_subnet.test-subnet.id
  route_table_id = aws_route_table.test-route-table.id
}
