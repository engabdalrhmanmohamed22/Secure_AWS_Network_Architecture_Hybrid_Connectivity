# =============================================================================
# Person 3 — Hybrid Connectivity & Private Access: Input Variables
# Aligned with backend.tf (default_tags already sets Project = "depi-team-1"
# and ManagedBy = "terraform", so p3_common_tags only adds track-level tags).
# =============================================================================

variable "p3_project_prefix" {
  description = "Naming prefix applied to all Person 3 resources."
  type        = string
  default     = "depi-team-1"
}

variable "p3_common_tags" {
  description = "Track-specific tags merged onto Person 3 resources (Project and ManagedBy come from backend.tf default_tags)."
  type        = map(string)
  default = {
    Owner = "Person3"
    Track = "Hybrid-Connectivity"
  }
}

# -----------------------------------------------------------------------------
# Site-to-Site VPN & Simulated On-Premises
# -----------------------------------------------------------------------------

variable "p3_onprem_cidr" {
  description = "CIDR block of the on-premises (or simulated on-prem) network."
  type        = string
  default     = "192.168.0.0/16"
}

variable "p3_onprem_subnet_cidr" {
  description = "Public subnet CIDR inside the simulated on-premises VPC."
  type        = string
  default     = "192.168.1.0/24"
}

variable "p3_onprem_bgp_asn" {
  description = "BGP ASN for the Customer Gateway."
  type        = number
  default     = 65000
}

variable "p3_enable_simulated_onprem" {
  description = "Provision a simulated on-premises VPC and Libreswan EC2 router for lab testing."
  type        = bool
  default     = true
}

variable "p3_onprem_public_ip" {
  description = "Static public IP of an external Customer Gateway (used only when p3_enable_simulated_onprem = false)."
  type        = string
  default     = ""
}

variable "p3_onprem_instance_type" {
  description = "EC2 instance type for the simulated on-premises VPN router."
  type        = string
  default     = "t3.micro"
}

variable "p3_admin_cidr" {
  description = "Your public IP/32 allowed to SSH into the simulated on-premises router for troubleshooting."
  type        = string
  default     = "0.0.0.0/0"
}

variable "p3_vpn_static_routes_only" {
  description = "Use static routing on the Site-to-Site VPN (recommended for lab strongSwan/Libreswan setups)."
  type        = bool
  default     = true
}

variable "p3_tgw_manage_vpn_association" {
  description = "Set to true if Person 1 disabled default TGW route table association/propagation."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# AWS Client VPN
# -----------------------------------------------------------------------------

variable "p3_enable_client_vpn" {
  description = "Toggle AWS Client VPN Endpoint and subnet associations (set to false after testing to save hourly charges)."
  type        = bool
  default     = true
}

variable "p3_client_vpn_cidr" {
  description = "Client IPv4 CIDR block (/22 to /12) — must NOT overlap with aws_vpc.main (10.0.0.0/16) or p3_onprem_cidr."
  type        = string
  default     = "10.100.0.0/22"
}

variable "p3_client_vpn_server_cert_arn" {
  description = "Existing ACM server certificate ARN. Leave empty to auto-generate self-signed mutual TLS certs via Terraform."
  type        = string
  default     = ""
}

variable "p3_client_vpn_client_cert_arn" {
  description = "Existing ACM client/root certificate ARN. Leave empty to auto-generate via Terraform."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Week 4 — Incident Response Forensics (EBS Snapshot & Evidence Bucket)
# -----------------------------------------------------------------------------

variable "p3_enable_ir_snapshot" {
  description = "Set to true during the IR simulation once Person 2 isolates the compromised EC2 instance."
  type        = bool
  default     = false
}

variable "p3_compromised_volume_id" {
  description = "EBS Volume ID (e.g., vol-0123456789abcdef0) of the simulated compromised EC2 instance."
  type        = string
  default     = ""
}

variable "p3_ir_case_id" {
  description = "Incident Response case identifier applied to forensic snapshots and evidence logs."
  type        = string
  default     = "IR-SIM-001"
}