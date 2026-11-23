variable "ec2_security_group_id" {
  description = "Security Group ID for the EC2 instance"
  type        = string
}

variable "alb_security_group_id" {
  description = "Security Group ID for the Application Load Balancer"
  type        = string
}
variable "db_security_group_id" {
  description = "Security Group ID for RDS"
  type        = string
}

variable "db_password" {
  description = "RDS database password"
  type        = string
  sensitive   = true
}