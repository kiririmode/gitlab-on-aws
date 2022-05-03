variable "cidr_block" {
  description = "VPC の CIDR ブロック"
  type        = string
}

variable "availability_zone" {
  description = "リソースを配置するAZ"
  type        = string
}