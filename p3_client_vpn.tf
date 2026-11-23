# =============================================================================
# Person 3 — AWS Client VPN Endpoint (Mutual TLS Authentication)
#
# Shared Terraform addresses referenced:
#   - aws_vpc.main
#   - aws_subnet.private_1
#   - aws_subnet.private_2
#   - aws_security_group.client_vpn
#
# Note: Auto-generated self-signed certs use the `hashicorp/tls` provider.
#       Run `terraform init` to pull it automatically, or pass existing ACM ARNs
#       via `p3_client_vpn_server_cert_arn` and `p3_client_vpn_client_cert_arn`.
# =============================================================================

locals {
  p3_generate_certs = var.p3_enable_client_vpn && (
    var.p3_client_vpn_server_cert_arn == "" || var.p3_client_vpn_client_cert_arn == ""
  )
}

# -----------------------------------------------------------------------------
# Self-Signed Mutual TLS PKI (CA + Server + Client Certs imported into ACM)
# -----------------------------------------------------------------------------

resource "tls_private_key" "p3_vpn_ca" {
  count     = local.p3_generate_certs ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "p3_vpn_ca" {
  count           = local.p3_generate_certs ? 1 : 0
  private_key_pem = tls_private_key.p3_vpn_ca[0].private_key_pem

  subject {
    common_name  = "${var.p3_project_prefix}.vpn.ca"
    organization = "Project2-NetSec"
  }

  validity_period_hours = 8760
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

resource "tls_private_key" "p3_vpn_server" {
  count     = local.p3_generate_certs ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "p3_vpn_server" {
  count           = local.p3_generate_certs ? 1 : 0
  private_key_pem = tls_private_key.p3_vpn_server[0].private_key_pem

  subject {
    common_name  = "server.${var.p3_project_prefix}.vpn.local"
    organization = "Project2-NetSec"
  }
}

resource "tls_locally_signed_cert" "p3_vpn_server" {
  count                 = local.p3_generate_certs ? 1 : 0
  cert_request_pem      = tls_cert_request.p3_vpn_server[0].cert_request_pem
  ca_private_key_pem    = tls_private_key.p3_vpn_ca[0].private_key_pem
  ca_cert_pem           = tls_self_signed_cert.p3_vpn_ca[0].cert_pem
  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "tls_private_key" "p3_vpn_client" {
  count     = local.p3_generate_certs ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "p3_vpn_client" {
  count           = local.p3_generate_certs ? 1 : 0
  private_key_pem = tls_private_key.p3_vpn_client[0].private_key_pem

  subject {
    common_name  = "client1.${var.p3_project_prefix}.vpn.local"
    organization = "Project2-NetSec"
  }
}

resource "tls_locally_signed_cert" "p3_vpn_client" {
  count                 = local.p3_generate_certs ? 1 : 0
  cert_request_pem      = tls_cert_request.p3_vpn_client[0].cert_request_pem
  ca_private_key_pem    = tls_private_key.p3_vpn_ca[0].private_key_pem
  ca_cert_pem           = tls_self_signed_cert.p3_vpn_ca[0].cert_pem
  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

resource "aws_acm_certificate" "p3_vpn_server" {
  count             = local.p3_generate_certs ? 1 : 0
  private_key       = tls_private_key.p3_vpn_server[0].private_key_pem
  certificate_body  = tls_locally_signed_cert.p3_vpn_server[0].cert_pem
  certificate_chain = tls_self_signed_cert.p3_vpn_ca[0].cert_pem

  tags = merge(var.p3_common_tags, {
    Name = "${var.p3_project_prefix}-client-vpn-server-cert"
  })
}

resource "aws_acm_certificate" "p3_vpn_client" {
  count             = local.p3_generate_certs ? 1 : 0
  private_key       = tls_private_key.p3_vpn_client[0].private_key_pem
  certificate_body  = tls_locally_signed_cert.p3_vpn_client[0].cert_pem
  certificate_chain = tls_self_signed_cert.p3_vpn_ca[0].cert_pem

  tags = merge(var.p3_common_tags, {
    Name = "${var.p3_project_prefix}-client-vpn-client-cert"
  })
}

locals {
  p3_server_cert_arn = var.p3_client_vpn_server_cert_arn != "" ? var.p3_client_vpn_server_cert_arn : (
    local.p3_generate_certs ? aws_acm_certificate.p3_vpn_server[0].arn : ""
  )
  p3_client_cert_arn = var.p3_client_vpn_client_cert_arn != "" ? var.p3_client_vpn_client_cert_arn : (
    local.p3_generate_certs ? aws_acm_certificate.p3_vpn_client[0].arn : ""
  )
}

# -----------------------------------------------------------------------------
# Client VPN CloudWatch Logs
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "p3_client_vpn" {
  count             = var.p3_enable_client_vpn ? 1 : 0
  name              = "/aws/client-vpn/${var.p3_project_prefix}"
  retention_in_days = 14
  tags              = var.p3_common_tags
}

resource "aws_cloudwatch_log_stream" "p3_client_vpn" {
  count          = var.p3_enable_client_vpn ? 1 : 0
  name           = "connections"
  log_group_name = aws_cloudwatch_log_group.p3_client_vpn[0].name
}

# -----------------------------------------------------------------------------
# AWS Client VPN Endpoint, Subnet Associations & Authorization Rules
# -----------------------------------------------------------------------------

resource "aws_ec2_client_vpn_endpoint" "p3_main" {
  count                  = var.p3_enable_client_vpn ? 1 : 0
  description            = "${var.p3_project_prefix} Client VPN for private VPC access"
  server_certificate_arn = local.p3_server_cert_arn
  client_cidr_block      = var.p3_client_vpn_cidr
  vpc_id                 = aws_vpc.main.id
  security_group_ids     = [aws_security_group.client_vpn.id]
  split_tunnel           = true
  transport_protocol     = "udp"
  dns_servers            = [cidrhost(aws_vpc.main.cidr_block, 2)]

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = local.p3_client_cert_arn
  }

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.p3_client_vpn[0].name
    cloudwatch_log_stream = aws_cloudwatch_log_stream.p3_client_vpn[0].name
  }

  tags = merge(var.p3_common_tags, {
    Name = "${var.p3_project_prefix}-client-vpn"
  })
}

resource "aws_ec2_client_vpn_network_association" "p3_private_1" {
  count                  = var.p3_enable_client_vpn ? 1 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.p3_main[0].id
  subnet_id              = aws_subnet.private_1.id
}

resource "aws_ec2_client_vpn_network_association" "p3_private_2" {
  count                  = var.p3_enable_client_vpn ? 1 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.p3_main[0].id
  subnet_id              = aws_subnet.private_2.id
}

resource "aws_ec2_client_vpn_authorization_rule" "p3_vpc_access" {
  count                  = var.p3_enable_client_vpn ? 1 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.p3_main[0].id
  target_network_cidr    = aws_vpc.main.cidr_block
  authorize_all_groups   = true
  description            = "Allow Client VPN users to access the main VPC"
}

resource "aws_ec2_client_vpn_authorization_rule" "p3_onprem_access" {
  count                  = var.p3_enable_client_vpn ? 1 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.p3_main[0].id
  target_network_cidr    = var.p3_onprem_cidr
  authorize_all_groups   = true
  description            = "Allow Client VPN users to reach on-premises CIDR via Transit Gateway"
}

resource "aws_ec2_client_vpn_route" "p3_to_onprem_az1" {
  count                  = var.p3_enable_client_vpn ? 1 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.p3_main[0].id
  destination_cidr_block = var.p3_onprem_cidr
  target_vpc_subnet_id   = aws_ec2_client_vpn_network_association.p3_private_1[0].subnet_id
  description            = "Route on-premises CIDR through private subnet 1"
}

resource "aws_ec2_client_vpn_route" "p3_to_onprem_az2" {
  count                  = var.p3_enable_client_vpn ? 1 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.p3_main[0].id
  destination_cidr_block = var.p3_onprem_cidr
  target_vpc_subnet_id   = aws_ec2_client_vpn_network_association.p3_private_2[0].subnet_id
  description            = "Route on-premises CIDR through private subnet 2"
}
