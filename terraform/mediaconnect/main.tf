# VPC
resource "aws_vpc" "mediaconnect_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "MediaConnect VPC"
  }
}

# Subnet
resource "aws_subnet" "mediaconnect_subnet" {
  vpc_id                  = aws_vpc.mediaconnect_vpc.id
  cidr_block              = var.private_subnet_cidr
  map_public_ip_on_launch = false

  tags = {
    Name = "MediaConnect private subnet"
  }
}

# Security Group
resource "aws_security_group" "mediaconnect" {
  name        = "mediaconnect-sg"
  description = "Mediaconnect security group"
  vpc_id      = aws_vpc.mediaconnect_vpc.id
}

resource "aws_security_group_rule" "ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.mediaconnect.id
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.mediaconnect.id
}

# Stack deployment
resource "aws_cloudformation_stack" "mediaconnect" {
  count = length(var.flows)
  name = var.flows[count.index].name

  parameters = {
    FlowName      = "FlowInterface"
    Subnet        = aws_subnet.mediaconnect_subnet.id
    Role          = var.mediaconnect_role
    SecurityGroup = aws_security_group.mediaconnect.id
    Az = aws_subnet.mediaconnect_subnet.availability_zone
  }
  template_body = file("${path.module}/mediaconnect.yaml")
}

# Accepter's side of the connection.
resource "aws_vpc_peering_connection_accepter" "peer" {
  count = var.spoke_region ? 1 : 0
  vpc_peering_connection_id = var.vpc_peer
  auto_accept               = true

  tags = {
    Side = "Accepter"
  }
}


# Set first region as hub and build peering connections to other regions
resource "aws_route_table" "route_remote" {
  count = var.spoke_region ? 1 : 0
  vpc_id = aws_vpc.mediaconnect_vpc.id

  route {
    cidr_block = var.hub_subnet_cidr
    vpc_peering_connection_id = var.vpc_peer
  }
}

resource "aws_route_table_association" "route_remote" {
  count = var.spoke_region ? 1 : 0
  subnet_id      = aws_subnet.mediaconnect_subnet.id
  route_table_id = aws_route_table.route_remote[count.index].id
}

