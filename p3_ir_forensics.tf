# =============================================================================
# Person 3 — Week 4 Incident Response Forensics
#   1. Encrypted, versioned S3 bucket for IR Evidence Collection Notes & hashes
#   2. On-demand Forensic EBS Snapshot of the compromised EC2 volume
#
# Usage during IR simulation:
#   terraform apply \
#     -var="p3_enable_ir_snapshot=true" \
#     -var="p3_compromised_volume_id=vol-xxxxxxxxxxxxxxxxx" \
#     -var="p3_ir_case_id=IR-SIM-001"
# =============================================================================

data "aws_caller_identity" "p3_current" {}

# -----------------------------------------------------------------------------
# Forensic Evidence Storage Bucket
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "p3_ir_evidence" {
  bucket = "${var.p3_project_prefix}-ir-evidence-${data.aws_caller_identity.p3_current.account_id}"

  tags = merge(var.p3_common_tags, {
    Name    = "${var.p3_project_prefix}-ir-evidence"
    Purpose = "IR-Forensics"
  })
}

resource "aws_s3_bucket_versioning" "p3_ir_evidence" {
  bucket = aws_s3_bucket.p3_ir_evidence.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "p3_ir_evidence" {
  bucket = aws_s3_bucket.p3_ir_evidence.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "p3_ir_evidence" {
  bucket                  = aws_s3_bucket.p3_ir_evidence.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# Forensic EBS Snapshot (Triggered after Person 2 isolates the instance)
# -----------------------------------------------------------------------------

resource "aws_ebs_snapshot" "p3_ir_evidence" {
  count       = var.p3_enable_ir_snapshot && var.p3_compromised_volume_id != "" ? 1 : 0
  volume_id   = var.p3_compromised_volume_id
  description = "Forensic snapshot for ${var.p3_ir_case_id} — preserved before remediation"

  tags = merge(var.p3_common_tags, {
    Name        = "${var.p3_project_prefix}-ir-snapshot-${var.p3_ir_case_id}"
    CaseID      = var.p3_ir_case_id
    Purpose     = "IR-Forensics"
    PreservedBy = "Person3"
  })
}
