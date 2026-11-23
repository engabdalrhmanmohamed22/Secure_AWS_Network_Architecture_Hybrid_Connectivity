# =============================================================================
# Minimal Person 1 Dependency Needed by Person 3 (Site-to-Site VPN)
# Only creates the Transit Gateway, its Route Table, the Main VPC Attachment,
# and the private route table return route to on-premises.
# =============================================================================

resource "aws_ec2_transit_gateway" "main" {
  description                     = "depi-team-1 hub Transit Gateway"
  amazon_side_asn                 = 64512
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  tags = {
    Name  = "depi-team-1-tgw"
    Owner = "Person1"
  }
}

resource "aws_ec2_transit_gateway_route_table" "main" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = {
    Name  = "depi-team-1-tgw-main-rt"
    Owner = "Person1"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  transit_gateway_id                              = aws_ec2_transit_gateway.main.id
  vpc_id                                          = aws_vpc.main.id
  subnet_ids                                      = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name  = "depi-team-1-tgw-main-vpc-attach"
    Owner = "Person1"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "main_vpc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "main_vpc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

resource "aws_route" "p1_private_to_onprem_tgw" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = var.p3_onprem_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.main]
}
