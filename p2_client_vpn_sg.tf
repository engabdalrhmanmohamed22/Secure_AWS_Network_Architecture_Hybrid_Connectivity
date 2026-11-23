# =============================================================================
# Minimal Person 2 Dependency Needed by Person 3 (AWS Client VPN)
# Only creates `aws_security_group.client_vpn` and its VPC/on-prem egress rules.
# =============================================================================

resource "aws_security_group" "client_vpn" {
  name        = "depi-team-1-client-vpn-sg"
  description = "Least-privilege SG applied to AWS Client VPN Endpoint"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name  = "depi-team-1-client-vpn-sg"
    Owner = "Person2"
  }
}

resource "aws_vpc_security_group_egress_rule" "client_vpn_to_vpc" {
  security_group_id = aws_security_group.client_vpn.id
  description       = "Allow Client VPN users to reach Main VPC"
  cidr_ipv4         = aws_vpc.main.cidr_block
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "client_vpn_to_onprem" {
  security_group_id = aws_security_group.client_vpn.id
  description       = "Allow Client VPN users to reach On-Premises CIDR via TGW"
  cidr_ipv4         = var.p3_onprem_cidr
  ip_protocol       = "-1"
}
