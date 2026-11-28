############################################
# Week 4 - Flow Logs, CloudWatch, Athena, Traffic Mirroring
############################################

# ---------- S3 bucket للـ flow logs (Athena) ----------
resource "aws_s3_bucket" "flow" {
  bucket        = "depi-team-1-p4-flowlogs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "flow" {
  bucket                  = aws_s3_bucket.flow.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_flow_log" "to_s3" {
  vpc_id               = local.vpc_id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = aws_s3_bucket.flow.arn
  # الفورمات الافتراضي (v2) عشان جدول Athena يبقى بسيط
  max_aggregation_interval = 60
  tags                     = { Name = "p4-flowlog-s3" }
}

# ---------- CloudWatch Logs flow log (للـ alarms والـ detection) ----------
resource "aws_cloudwatch_log_group" "flow" {
  name              = "/depi/p4/vpc-flow-logs"
  retention_in_days = 30
}

data "aws_iam_policy_document" "flow_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow" {
  name               = "p4-flowlog-role"
  assume_role_policy = data.aws_iam_policy_document.flow_assume.json
}

data "aws_iam_policy_document" "flow_perm" {
  statement {
    actions = [
      "logs:CreateLogStream", "logs:PutLogEvents",
      "logs:DescribeLogGroups", "logs:DescribeLogStreams"
    ]
    resources = ["${aws_cloudwatch_log_group.flow.arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow" {
  role   = aws_iam_role.flow.id
  policy = data.aws_iam_policy_document.flow_perm.json
}

resource "aws_flow_log" "to_cw" {
  vpc_id          = local.vpc_id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow.arn
  log_destination = aws_cloudwatch_log_group.flow.arn
  tags            = { Name = "p4-flowlog-cw" }
}

# ---------- Detection: metric filters + alarms ----------
# 1) رفض SSH/RDP (محاولات scan)
resource "aws_cloudwatch_log_metric_filter" "rejected_admin" {
  name           = "p4-rejected-ssh-rdp"
  log_group_name = aws_cloudwatch_log_group.flow.name
  pattern        = "[version, account, eni, source, destination, srcport, destport=22 || destport=3389, protocol, packets, bytes, start, end, action=REJECT, status]"

  metric_transformation {
    name      = "RejectedAdminPortAttempts"
    namespace = "DEPI/P4"
    value     = "1"
  }
}

# 2) أي traffic REJECT عموماً
resource "aws_cloudwatch_log_metric_filter" "rejected_all" {
  name           = "p4-rejected-all"
  log_group_name = aws_cloudwatch_log_group.flow.name
  pattern        = "[version, account, eni, source, destination, srcport, destport, protocol, packets, bytes, start, end, action=REJECT, status]"

  metric_transformation {
    name      = "RejectedTraffic"
    namespace = "DEPI/P4"
    value     = "1"
  }
}

resource "aws_sns_topic" "alerts" {
  name = "p4-network-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "ssh_rdp_scan" {
  alarm_name          = "p4-ssh-rdp-rejected-spike"
  namespace           = "DEPI/P4"
  metric_name         = "RejectedAdminPortAttempts"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 20
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "reject_spike" {
  alarm_name          = "p4-rejected-traffic-spike"
  namespace           = "DEPI/P4"
  metric_name         = "RejectedTraffic"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 200
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

# ---------- Athena ----------
resource "aws_s3_bucket" "athena_results" {
  bucket        = "depi-team-1-p4-athena-results-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket                  = aws_s3_bucket.athena_results.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_athena_workgroup" "p4" {
  name          = "p4-network-analysis"
  force_destroy = true
  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/results/"
    }
  }
}

resource "aws_athena_database" "p4" {
  name   = "p4_network"
  bucket = aws_s3_bucket.athena_results.bucket
}

# جدول بـ partition projection: مفيش حاجة تعملها MSCK REPAIR
resource "aws_athena_named_query" "create_table" {
  name      = "00-create-vpc-flow-logs-table"
  workgroup = aws_athena_workgroup.p4.id
  database  = aws_athena_database.p4.name
  query     = <<-SQL
    CREATE EXTERNAL TABLE IF NOT EXISTS vpc_flow_logs (
      version int, account_id string, interface_id string,
      srcaddr string, dstaddr string, srcport int, dstport int,
      protocol bigint, packets bigint, bytes bigint,
      start bigint, `end` bigint, action string, log_status string
    )
    PARTITIONED BY (`date` string)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY ' '
    LOCATION 's3://${aws_s3_bucket.flow.bucket}/AWSLogs/${data.aws_caller_identity.current.account_id}/vpcflowlogs/${data.aws_region.current.region}/'
    TBLPROPERTIES (
      'skip.header.line.count'='1',
      'projection.enabled'='true',
      'projection.date.type'='date',
      'projection.date.range'='2026/01/01,NOW',
      'projection.date.format'='yyyy/MM/dd',
      'projection.date.interval'='1',
      'projection.date.interval.unit'='DAYS',
      'storage.location.template'='s3://${aws_s3_bucket.flow.bucket}/AWSLogs/${data.aws_caller_identity.current.account_id}/vpcflowlogs/${data.aws_region.current.region}/$${date}'
    );
  SQL
}

locals {
  athena_queries = {
    "01-top-rejected-sources"    = <<-SQL
      SELECT srcaddr, dstport, COUNT(*) AS rejects
      FROM vpc_flow_logs
      WHERE action = 'REJECT' AND "date" >= date_format(current_date - interval '1' day, '%Y/%m/%d')
      GROUP BY srcaddr, dstport ORDER BY rejects DESC LIMIT 20;
    SQL
    "02-ssh-rdp-attempts"        = <<-SQL
      SELECT srcaddr, dstaddr, dstport, action, COUNT(*) AS hits
      FROM vpc_flow_logs
      WHERE dstport IN (22, 3389)
      GROUP BY srcaddr, dstaddr, dstport, action ORDER BY hits DESC LIMIT 50;
    SQL
    "03-port-scan-detection"     = <<-SQL
      SELECT srcaddr, COUNT(DISTINCT dstport) AS distinct_ports, COUNT(*) AS flows
      FROM vpc_flow_logs
      GROUP BY srcaddr HAVING COUNT(DISTINCT dstport) > 15
      ORDER BY distinct_ports DESC;
    SQL
    "04-top-talkers-bytes"       = <<-SQL
      SELECT srcaddr, dstaddr, SUM(bytes) AS total_bytes
      FROM vpc_flow_logs
      GROUP BY srcaddr, dstaddr ORDER BY total_bytes DESC LIMIT 20;
    SQL
    "05-possible-exfiltration"   = <<-SQL
      -- داتا خارجة بكميات كبيرة لعناوين برا الـ VPC (عدّل الـ CIDR)
      SELECT srcaddr, dstaddr, SUM(bytes) AS out_bytes
      FROM vpc_flow_logs
      WHERE srcaddr LIKE '10.%' AND dstaddr NOT LIKE '10.%' AND action = 'ACCEPT'
      GROUP BY srcaddr, dstaddr HAVING SUM(bytes) > 104857600
      ORDER BY out_bytes DESC;
    SQL
    "06-compromised-instance-ir" = <<-SQL
      -- كل traffic الـ ENI المشتبه فيه (غيّر الـ interface_id)
      SELECT from_unixtime(start) AS ts, srcaddr, dstaddr, srcport, dstport, protocol, action, bytes
      FROM vpc_flow_logs
      WHERE interface_id = 'eni-REPLACE_ME'
      ORDER BY start DESC LIMIT 500;
    SQL
  }
}

resource "aws_athena_named_query" "queries" {
  for_each  = local.athena_queries
  name      = each.key
  workgroup = aws_athena_workgroup.p4.id
  database  = aws_athena_database.p4.name
  query     = each.value
}

# ---------- Traffic Mirroring ----------
resource "aws_ec2_traffic_mirror_filter" "all" {
  count            = var.enable_traffic_mirroring ? 1 : 0
  description      = "p4 mirror filter"
  network_services = ["amazon-dns"]
}

resource "aws_ec2_traffic_mirror_filter_rule" "in_all" {
  count                    = var.enable_traffic_mirroring ? 1 : 0
  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.all[0].id
  traffic_direction        = "ingress"
  rule_number              = 100
  rule_action              = "accept"
  source_cidr_block        = "0.0.0.0/0"
  destination_cidr_block   = "0.0.0.0/0"
}

resource "aws_ec2_traffic_mirror_filter_rule" "out_all" {
  count                    = var.enable_traffic_mirroring ? 1 : 0
  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.all[0].id
  traffic_direction        = "egress"
  rule_number              = 100
  rule_action              = "accept"
  source_cidr_block        = "0.0.0.0/0"
  destination_cidr_block   = "0.0.0.0/0"
}

resource "aws_ec2_traffic_mirror_target" "collector" {
  count                = var.enable_traffic_mirroring ? 1 : 0
  description          = "p4 collector"
  network_interface_id = var.mirror_target_eni_id
}

resource "aws_ec2_traffic_mirror_session" "s" {
  count                    = var.enable_traffic_mirroring ? 1 : 0
  description              = "p4 mirror session"
  network_interface_id     = var.mirror_source_eni_id
  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.all[0].id
  traffic_mirror_target_id = aws_ec2_traffic_mirror_target.collector[0].id
  session_number           = 1
}
