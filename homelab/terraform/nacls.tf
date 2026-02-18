resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.homelab_vpc.id
  subnet_ids = [aws_subnet.homelab_public_subnet.id]

  tags = {
    Name = "${var.project_name}-public-nacl"
  }
}

resource "aws_network_acl_rule" "public_inbound_ssh" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "${data.external.my_ip.result.ip}/32"
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "public_inbound_http" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "public_inbound_https" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "public_inbound_ephemeral" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 130
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "public_inbound_icmp" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 140
  egress         = false
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  icmp_type      = -1
  icmp_code      = -1
}


resource "aws_network_acl_rule" "public_outbound_http" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "public_outbound_https" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "public_outbound_postgres_to_private" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 120
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_subnet.homelab_private_subnet.cidr_block
  from_port      = 5432
  to_port        = 5432
}

resource "aws_network_acl_rule" "public_outbound_ssh_to_private" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 130
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_subnet.homelab_private_subnet.cidr_block
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "public_outbound_ephemeral" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 140
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "public_outbound_icmp" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 150
  egress         = true
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  icmp_type      = -1
  icmp_code      = -1
}


resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.homelab_vpc.id
  subnet_ids = [aws_subnet.homelab_private_subnet.id]

  tags = {
    Name = "${var.project_name}-private-nacl"
  }
}

resource "aws_network_acl_rule" "private_inbound_postgres_from_public" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_subnet.homelab_public_subnet.cidr_block
  from_port      = 5432
  to_port        = 5432
}

resource "aws_network_acl_rule" "private_inbound_ssh_from_public" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_subnet.homelab_public_subnet.cidr_block
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "private_inbound_ephemeral_from_internet" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "private_inbound_icmp" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 130
  egress         = false
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  icmp_type      = -1
  icmp_code      = -1
}


resource "aws_network_acl_rule" "private_outbound_http" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "private_outbound_https" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "private_outbound_ephemeral" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 120
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "private_outbound_icmp" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 130
  egress         = true
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  icmp_type      = -1
  icmp_code      = -1
}