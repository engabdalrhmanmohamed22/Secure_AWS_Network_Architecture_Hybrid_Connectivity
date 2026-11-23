############################################
# Week 2 - VPC Endpoints & PrivateLink
############################################

# ---- SG للـ Interface endpoints: HTTPS من الـ workload بس (least privilege)
resource "aws_security_group" "endpoints" {
  name        = "p4-vpce-sg"
  description = "Allow HTTPS from workload SG to interface endpoints"
  vpc_id      = local.vpc_id

  ingress {
    description     = "HTTPS from workload"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = var.workload_sg_id == "" ? [] : [var.workload_sg_id]
    cidr_blocks     = var.workload_sg_id == "" ? var.private_subnet_cidrs : null
  }

  tags = { Name = "p4-vpce-sg" }
}

# ---- Gateway endpoint: S3 (مجاني، بيضيف route في الـ route tables)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = local.private_route_table_ids
  tags              = { Name = "p4-s3-gateway-endpoint" }
}

# ---- Interface endpoints: SSM (bastion-less access) + CloudWatch Logs
locals {
  interface_services = ["ssm", "ssmmessages", "ec2messages", "logs"]
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(local.interface_services)
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "p4-${each.key}-endpoint" }
}

# ---- PrivateLink: provider (NLB + Endpoint Service) و consumer (Interface endpoint)
resource "aws_lb" "pl_nlb" {
  count              = var.enable_privatelink_demo ? 1 : 0
  name               = "p4-privatelink-nlb"
  load_balancer_type = "network"
  internal           = true
  subnets            = local.private_subnet_ids
}

resource "aws_lb_target_group" "pl_tg" {
  count    = var.enable_privatelink_demo ? 1 : 0
  name     = "p4-privatelink-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = local.vpc_id
}

resource "aws_lb_target_group_attachment" "pl_app" {
  count            = var.enable_privatelink_demo ? 1 : 0
  target_group_arn = aws_lb_target_group.pl_tg[0].arn
  target_id        = var.app_instance_id
  port             = 80
}

resource "aws_lb_listener" "pl_listener" {
  count             = var.enable_privatelink_demo ? 1 : 0
  load_balancer_arn = aws_lb.pl_nlb[0].arn
  port              = 80
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.pl_tg[0].arn
  }
}

resource "aws_vpc_endpoint_service" "pl" {
  count                      = var.enable_privatelink_demo ? 1 : 0
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.pl_nlb[0].arn]
  tags                       = { Name = "p4-privatelink-service" }
}

resource "aws_security_group" "pl_consumer" {
  count       = var.enable_privatelink_demo ? 1 : 0
  name        = "p4-privatelink-consumer-sg"
  description = "HTTP from workload to PrivateLink endpoint"
  vpc_id      = local.vpc_id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = var.workload_sg_id == "" ? [] : [var.workload_sg_id]
    cidr_blocks     = var.workload_sg_id == "" ? var.private_subnet_cidrs : null
  }
}

resource "aws_vpc_endpoint" "pl_consumer" {
  count              = var.enable_privatelink_demo ? 1 : 0
  vpc_id             = local.vpc_id
  service_name       = aws_vpc_endpoint_service.pl[0].service_name
  vpc_endpoint_type  = "Interface"
  subnet_ids         = local.private_subnet_ids
  security_group_ids = [aws_security_group.pl_consumer[0].id]
  tags               = { Name = "p4-privatelink-consumer" }
}
