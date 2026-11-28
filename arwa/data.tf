data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# بنلاقي موارد Person 1 بالـ CIDR
data "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

data "aws_subnet" "private" {
  for_each   = toset(var.private_subnet_cidrs)
  vpc_id     = data.aws_vpc.main.id
  cidr_block = each.value
}

data "aws_route_table" "private" {
  for_each  = data.aws_subnet.private
  subnet_id = each.value.id
}

locals {
  vpc_id                  = data.aws_vpc.main.id
  private_subnet_ids      = [for s in data.aws_subnet.private : s.id]
  private_route_table_ids = distinct([for rt in data.aws_route_table.private : rt.id])
}
