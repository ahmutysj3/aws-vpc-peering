# builds VPCs based on var.vpcs inputs - default is 1 x Hub VPC and 3 x Spoke VPCs
resource "aws_vpc" "main" {
  for_each         = var.vpcs
  cidr_block       = each.value.cidr
  instance_tenancy = "default"

  tags = {
    Name = "${each.key}_vpc"
    type = each.value.type
  }
}

# local variables for the hub VPC cidr and id
locals {
  hub_id   = element([for vpck, vpc in aws_vpc.main : vpc.id if vpc.tags.type == "hub"], 0)
  hub_cidr = element([for vpck, vpc in aws_vpc.main : vpc.cidr_block if vpc.tags.type == "hub"], 0)
}

# builds 1 x IGW for the hub VPC
resource "aws_internet_gateway" "hub" {
  vpc_id = local.hub_id
  tags = {
    Name = "hub_igw"
  }
}

# builds a subnet for inside interface of firewall
resource "aws_subnet" "hub_trusted" {
  #availability_zone       = data.aws_availability_zones.available.names[0]
  vpc_id                  = local.hub_id
  cidr_block              = cidrsubnet(local.hub_cidr, 8, 0)
  map_public_ip_on_launch = false
  tags = {
    Name     = "hub_trusted_subnet"
    Security = "0"
    Type     = "hub"
  }
}

# builds a subnet for outside interface of firewall
resource "aws_subnet" "hub_untrusted" {
  #availability_zone       = data.aws_availability_zones.available.names[0]
  vpc_id                  = local.hub_id
  cidr_block              = cidrsubnet(local.hub_cidr, 8, 1)
  map_public_ip_on_launch = false
  tags = {
    Name     = "hub_untrusted_subnet"
    Security = "100"
    type     = "hub"
  }
}

# builds the spoke subnets based on inputs within var.spoke_subnets
resource "aws_subnet" "spoke" {
  for_each                = var.spoke_subnets
  vpc_id                  = aws_vpc.main[each.value.vpc_id].id
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = each.key == "dmz" || each.key == "hub" ? true : false
  tags = {
    type = "spoke"
    Name = "${each.key}_subnet"
  }
}

# peers each spoke VPC to the hub VPC
resource "aws_vpc_peering_connection" "main" {
  for_each = {
    for vpck, vpc in aws_vpc.main : vpck => vpc if vpc.tags.type == "spoke"
  }
  peer_vpc_id = aws_vpc.main[each.key].id
  vpc_id      = local.hub_id
  auto_accept = true

  tags = {
    Name = "${each.key}_vpc_peering"
  }
}

# builds a security group that allows all inbound and outbound traffic
resource "aws_security_group" "allow_all" {
  for_each    = aws_vpc.main
  name        = "allow_all_sg"
  description = "Allow all inbound/outbound traffic"
  vpc_id      = aws_vpc.main[each.key].id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# creates a default allow all out/allow ssh in nacl in each VPC
resource "aws_network_acl" "main" {
  for_each = aws_vpc.main
  vpc_id   = aws_vpc.main[each.key].id

  egress {
    protocol   = "all"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  tags = {
    Name = "${each.key}_main_acl"
  }
}

# associates the default VPC nacl to each subnet
resource "aws_network_acl_association" "main" {
  for_each       = var.spoke_subnets
  network_acl_id = aws_network_acl.main[each.value.vpc_id].id
  subnet_id      = aws_subnet.spoke[each.key].id
}

# creates a default route table for the hub VPC and populates routes pointing to each spoke VPC peering as well as to the IGW
resource "aws_default_route_table" "hub" {
  for_each = {
    for vpck, vpc in aws_vpc.main : vpck => vpc if vpc.tags.type == "hub"
  }
  default_route_table_id = aws_vpc.main[each.key].default_route_table_id

  dynamic "route" {
    iterator = vpc_rr

    for_each = [
      for vpck, vpc in aws_vpc.main :
      {
        cidr        = aws_vpc.main[vpck].cidr_block,
        vpc_peer_id = aws_vpc_peering_connection.main[vpck].id
      }
      if vpc.tags.type == "spoke"
    ]

    content {
      cidr_block                = vpc_rr.value.cidr
      vpc_peering_connection_id = vpc_rr.value.vpc_peer_id
    }
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hub.id
  }

  tags = {
    Name = "hub_main_rt"
  }
}

# creates a default route table in each spoke VPC and points all traffic to the peering w/ hub VPC
resource "aws_default_route_table" "spokes" {
  for_each = {
    for vpck, vpc in aws_vpc.main : vpck => vpc if vpc.tags.type == "spoke"
  }
  default_route_table_id = aws_vpc.main[each.key].default_route_table_id

  route {
    cidr_block                = "0.0.0.0/0"
    vpc_peering_connection_id = aws_vpc_peering_connection.main[each.key].id
  }

  tags = {
    Name = "spoke_${each.key}_main_rt"
  }
}



