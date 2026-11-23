# VPC ID
output "vpc_id" {
  value = aws_vpc.main.id
}

# Public Subnets
output "public_subnet_ids" {
  value = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]
}

# Private Subnets
output "private_subnet_ids" {
  value = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]
}

# Application Load Balancer DNS
output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

# EC2 Private IP
output "ec2_private_ip" {
  value = aws_instance.app.private_ip
}

# RDS Endpoint
output "rds_endpoint" {
  value = aws_db_instance.main.endpoint
}