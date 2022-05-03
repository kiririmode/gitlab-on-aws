resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "VPC for GitLab"
  }
}

resource "aws_subnet" "private" {
  for_each = { for idx, az in keys(var.availability_zones): az => idx }

  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 8, each.value)
  vpc_id            = aws_vpc.this.id
  availability_zone = each.key

  tags = {
    Name = "Private Subnet for GitLab"
  }
}

resource "aws_subnet" "public" {
  for_each = { for idx, az in keys(var.availability_zones): az => idx }

  availability_zone = each.key
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 8, each.value + 128)
  vpc_id            = aws_vpc.this.id

  tags = {
    Name = "Public Subnet for GitLab"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "Internet Gateway for GitLab"
  }
}

resource "aws_eip" "nat_gw" {
  vpc = true

  tags = {
    "Name" = "EIP For GitLab VPC"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "this" {
  for_each = local.gitlab_az

  allocation_id = aws_eip.nat_gw.id

  # GitLab が配置される AZ のみに NAT Gateway を配置する
  subnet_id = aws_subnet.public[each.key].id

  tags = {
    Name = "Nat Gateway for GitLab"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Public Subnetに対するルートテーブル
# 全ての AZ に対し、Internet Gateway へのルーティングを設定する
resource "aws_route_table" "public" {
  for_each = var.availability_zones

  vpc_id = aws_vpc.this.id

  # サブネット内で閉じる通信以外は、全て Internet Gateway へ向ける
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Route Table for Public Subnet"
  }
}


resource "aws_route_table_association" "public" {
  for_each = var.availability_zones

  route_table_id = aws_route_table.public[each.key].id
  subnet_id      = aws_subnet.public[each.key].id
}

# Private Subnetに対するルートテーブル
# NAT Gateway はコストを鑑み GitLab を作成する AZ にのみ配置する
resource "aws_route_table" "private" {
  # GitLab が配置される AZ 名が each.key に格納される
  for_each = local.gitlab_az

  vpc_id = aws_vpc.this.id

  # サブネット内で閉じる通信以外は、全て NAT ゲートウェイへ向ける
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[each.key].id
  }

  tags = {
    Name = "Route Table for Private Subnet"
  }
}

resource "aws_route_table_association" "private" {
  for_each = local.gitlab_az

  route_table_id = aws_route_table.private[each.key].id
  subnet_id      = aws_subnet.private[each.key].id
}

resource "aws_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "Security Group for GitLab"
  }
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.this.id
  cidr_blocks       = ["0.0.0.0/0"]

  description = "Outbound Open"
}