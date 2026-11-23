# =============================================================================
# Person 3 — Site-to-Site VPN (Attached to Person 1's Transit Gateway)
# + Optional Simulated On-Premises VPC & Libreswan Router
#
# Shared Terraform addresses referenced:
#   - aws_ec2_transit_gateway.main
#   - aws_ec2_transit_gateway_route_table.main
#   - aws_vpc.main
# =============================================================================

data "aws_ami" "p3_al2023" {
  count       = var.p3_enable_simulated_onprem ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -----------------------------------------------------------------------------
# Simulated On-Premises Environment (Optional Lab Router)
# -----------------------------------------------------------------------------

resource "aws_vpc" "p3_onprem" {
  count                = var.p3_enable_simulated_onprem ? 1 : 0
  cidr_block           = var.p3_onprem_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.p3_common_tags, {
    Name = "${var.p3_project_prefix}-sim-onprem-vpc"
  })
}

resource "aws_internet_gateway" "p3_onprem" {
  count  = var.p3_enable_simulated_onprem ? 1 : 0
  vpc_id = aws_vpc.p3_onprem[0].id

  tags = merge(var.p3_common_tags, {
    Name = "${var.p3_project_prefix}-sim-onprem-igw"
  })
}

resource "aws_subnet" "p3_onprem_public" {
  count                   = var.p3_enable_simulated_onprem ? 1 : 0
  vpc_id                  = aws_vpc.p3_onprem[0].id
  cidr_block              = var.p3_onprem_subnet_cidr
  map_public_ip_on_launch = true

  tags = merge(var.p3_common_tags, {
    Name = "${var.p3_project_prefix}-sim-onprem-public-subnet"
  })
}

resource "aws_route_table" "p3_onprem_public" {
  count  = var.p3_enable_simulated_onprem ? 1 : 0
  vpc_id = aws_vpc.p3_onprem[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.p3_onprem[0].id
  }

  tags = merge(var.p3_common_tags, {
    Name = "${var.p3_project_prefix}-sim-onprem-rt"
  })
}

resource "aws_route_table_association" "p3_onprem_public" {
  count          = var.p3_enable_simulated_onprem ? 1 : 0
  subnet_id      = aws_subnet.p3_onprem_public[0].id
  route_table_id = aws_route_table.p3_onprem_public[0].id
}

resource "aws_security_group" "p3_onprem_router" {
  count       = var.p3_enable_simulated_onprem ? 1 : 0
  name        = "${var.p3_project_prefix}-sim-onprem-vpn-sg"
  description = "Allow IPsec (IKE/NAT-T/ESP) and lab management for simulated on-prem router"
  vpc_id      = aws_vpc.p3_onprem[0].id

  ingress {
    description = "IKE (IPsec)"
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "IPsec NAT-T"
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ICMP from AWS Main VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  ingress {
    description = "SSH from admin CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.p3_admin_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.p3_common_tags, {
    Name = "${var.p3_project_prefix}-sim-onprem-vpn-sg"
  })
}

resource "aws_eip" "p3_onprem_router" {
  count  = var.p3_enable_simulated_onprem ? 1 : 0
  domain = "vpc"

  tags = merge(var.p3_common_tags, {
    Name = "${var.p3_project_prefix}-sim-onprem-eip"
  })
}

resource "aws_instance" "p3_onprem_router" {
  count                       = var.p3_enable_simulated_onprem ? 1 : 0
  ami                         = data.aws_ami.p3_al2023[0].id
  instance_type               = var.p3_onprem_instance_type
  subnet_id                   = aws_subnet.p3_onprem_public[0].id
  vpc_security_group_ids      = [aws_security_group.p3_onprem_router[0].id]
  source_dest_check           = false
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    dnf update -y
    dnf install -y libreswan tcpdump nmap-ncat
    cat <<SYSCTL > /etc/sysctl.d/99-ipsec-router.conf
    net.ipv4.ip_forward = 1
    net.ipv4.conf.all.accept_redirects = 0
    net.ipv4.conf.all.send_redirects = 0
    SYSCTL
    sysctl --system
    systemctl enable --now ipsec
  EOF

  tags = merge(var.p3_common_tags, {
    Name = "${var.p3_project_prefix}-sim-onprem-router"
  })
}

resource "aws_eip_association" "p3_onprem_router" {
  count         = var.p3_enable_simulated_onprem ? 1 : 0
  instance_id   = aws_instance.p3_onprem_router[0].id
  allocation_id = aws_eip.p3_onprem_router[0].id
}

# -----------------------------------------------------------------------------
# AWS Customer Gateway & Site-to-Site VPN on Transit Gateway
# -----------------------------------------------------------------------------

locals {
  p3_cgw_ip = var.p3_enable_simulated_onprem ? aws_eip.p3_onprem_router[0].public_ip : var.p3_onprem_public_ip
}

resource "aws_cloudwatch_log_group" "p3_s2s_vpn_logs" {
  name              = "/aws/vpn/${var.p3_project_prefix}-site-to-site"
  retention_in_days = 14
  tags              = var.p3_common_tags
}

resource "aws_customer_gateway" "p3_onprem" {
  bgp_asn    = var.p3_onprem_bgp_asn
  ip_address = local.p3_cgw_ip
  type       = "ipsec.1"

  tags = merge(var.p3_common_tags, {
    Name = "${var.p3_project_prefix}-onprem-cgw"
  })
}

resource "aws_vpn_connection" "p3_onprem_to_tgw" {
  customer_gateway_id = aws_customer_gateway.p3_onprem.id
  transit_gateway_id  = aws_ec2_transit_gateway.main.id
  type                = "ipsec.1"
  static_routes_only  = var.p3_vpn_static_routes_only

  tunnel1_log_options {
    cloudwatch_log_options {
      log_enabled       = true
      log_group_arn     = aws_cloudwatch_log_group.p3_s2s_vpn_logs.arn
      log_output_format = "json"
    }
  }

  tunnel2_log_options {
    cloudwatch_log_options {
      log_enabled       = true
      log_group_arn     = aws_cloudwatch_log_group.p3_s2s_vpn_logs.arn
      log_output_format = "json"
    }
  }

  tags = merge(var.p3_common_tags, {
    Name = "${var.p3_project_prefix}-s2s-vpn-tgw"
  })
}

# Associate VPN attachment with Person 1's TGW route table (when default association is disabled)
resource "aws_ec2_transit_gateway_route_table_association" "p3_vpn" {
  count                          = var.p3_tgw_manage_vpn_association ? 1 : 0
  transit_gateway_attachment_id  = aws_vpn_connection.p3_onprem_to_tgw.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

# Propagate BGP routes when dynamic routing is used
resource "aws_ec2_transit_gateway_route_table_propagation" "p3_vpn" {
  count                          = var.p3_tgw_manage_vpn_association && !var.p3_vpn_static_routes_only ? 1 : 0
  transit_gateway_attachment_id  = aws_vpn_connection.p3_onprem_to_tgw.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

# Static TGW route to on-premises CIDR when static_routes_only = true
resource "aws_ec2_transit_gateway_route" "p3_to_onprem" {
  count                          = var.p3_vpn_static_routes_only ? 1 : 0
  destination_cidr_block         = var.p3_onprem_cidr
  transit_gateway_attachment_id  = aws_vpn_connection.p3_onprem_to_tgw.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}
