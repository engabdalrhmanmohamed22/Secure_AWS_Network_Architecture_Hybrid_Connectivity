# خطة الشبكة من Person 1 (الـ IDs بتتلقى تلقائياً من الـ CIDR)
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}
variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "workload_sg_id" {
  description = "SG بتاع الـ EC2 اللي هيكلم الـ endpoints. لو فاضي بيتسمح من الـ private subnets CIDRs"
  type        = string
  default     = ""
}

# --- PrivateLink demo (اختياري) ---
variable "enable_privatelink_demo" {
  type    = bool
  default = false
}
variable "app_instance_id" {
  description = "EC2 بيشغل خدمة على بورت 80 (provider side)"
  type        = string
  default     = ""
}

# --- Traffic Mirroring (اختياري) ---
variable "enable_traffic_mirroring" {
  type    = bool
  default = false
}
variable "mirror_source_eni_id" {
  type    = string
  default = ""
}
variable "mirror_target_eni_id" {
  type    = string
  default = ""
}

variable "alarm_email" {
  type    = string
  default = ""
}
