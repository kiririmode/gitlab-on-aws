variable "cidr_block" {
  description = "VPC の CIDR ブロック"
  type        = string
}

variable "availability_zones" {
  description = "リソースを配置する Availability Zone (AZ) を示す map。実際に GitLab を配置する AZ の value を true にする"
  type        = map(bool)
}