# =============================================================================
# Person 3 — Outputs for Hybrid Connectivity Test Report & IR Evidence Notes
# =============================================================================

# -----------------------------------------------------------------------------
# Site-to-Site VPN Outputs
# -----------------------------------------------------------------------------

output "p3_sim_onprem_router_public_ip" {
  description = "Public EIP of the simulated on-premises Libreswan router."
  value       = var.p3_enable_simulated_onprem ? aws_eip.p3_onprem_router[0].public_ip : null
}

output "p3_s2s_vpn_connection_id" {
  description = "AWS Site-to-Site VPN Connection ID."
  value       = aws_vpn_connection.p3_onprem_to_tgw.id
}

output "p3_s2s_vpn_tgw_attachment_id" {
  description = "Transit Gateway attachment ID created for the Site-to-Site VPN."
  value       = aws_vpn_connection.p3_onprem_to_tgw.transit_gateway_attachment_id
}

output "p3_s2s_vpn_tunnel1_address" {
  description = "Outside public IP of AWS VPN Tunnel 1."
  value       = aws_vpn_connection.p3_onprem_to_tgw.tunnel1_address
}

output "p3_s2s_vpn_tunnel1_preshared_key" {
  description = "Pre-shared key for Tunnel 1 (run `terraform output -raw p3_s2s_vpn_tunnel1_preshared_key`)."
  value       = aws_vpn_connection.p3_onprem_to_tgw.tunnel1_preshared_key
  sensitive   = true
}

output "p3_s2s_vpn_tunnel2_address" {
  description = "Outside public IP of AWS VPN Tunnel 2."
  value       = aws_vpn_connection.p3_onprem_to_tgw.tunnel2_address
}

output "p3_s2s_vpn_tunnel2_preshared_key" {
  description = "Pre-shared key for Tunnel 2 (run `terraform output -raw p3_s2s_vpn_tunnel2_preshared_key`)."
  value       = aws_vpn_connection.p3_onprem_to_tgw.tunnel2_preshared_key
  sensitive   = true
}

# -----------------------------------------------------------------------------
# AWS Client VPN Outputs
# -----------------------------------------------------------------------------

output "p3_client_vpn_endpoint_id" {
  description = "AWS Client VPN Endpoint ID (use with `aws ec2 export-client-vpn-client-configuration`)."
  value       = var.p3_enable_client_vpn ? aws_ec2_client_vpn_endpoint.p3_main[0].id : null
}

output "p3_client_vpn_dns_name" {
  description = "DNS name of the AWS Client VPN Endpoint."
  value       = var.p3_enable_client_vpn ? aws_ec2_client_vpn_endpoint.p3_main[0].dns_name : null
}

output "p3_client_vpn_client_cert_pem" {
  description = "Auto-generated client certificate PEM to append inside <cert>...</cert> in your .ovpn file."
  value       = local.p3_generate_certs ? tls_locally_signed_cert.p3_vpn_client[0].cert_pem : null
  sensitive   = true
}

output "p3_client_vpn_client_key_pem" {
  description = "Auto-generated client private key PEM to append inside <key>...</key> in your .ovpn file."
  value       = local.p3_generate_certs ? tls_private_key.p3_vpn_client[0].private_key_pem : null
  sensitive   = true
}

# -----------------------------------------------------------------------------
# IR Forensics Outputs
# -----------------------------------------------------------------------------

output "p3_ir_evidence_bucket" {
  description = "S3 bucket storing IR Evidence Collection Notes and hashes."
  value       = aws_s3_bucket.p3_ir_evidence.bucket
}

output "p3_ir_snapshot_id" {
  description = "Forensic EBS Snapshot ID captured during the IR simulation."
  value       = length(aws_ebs_snapshot.p3_ir_evidence) > 0 ? aws_ebs_snapshot.p3_ir_evidence[0].id : null
}
