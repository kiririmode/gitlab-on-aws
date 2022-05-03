resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "VPC for GitLab"
  }
}

resource "aws_subnet" "private" {
  cidr_block = cidrsubnet(aws_vpc.this.cidr_block, 8, 1)
  vpc_id     = aws_vpc.this.id

  availability_zone = var.availability_zone

  tags = {
    Name = "Private Subnet for GitLab"
  }
}

resource "aws_subnet" "public" {
  cidr_block = cidrsubnet(aws_vpc.this.cidr_block, 8, 0)
  vpc_id     = aws_vpc.this.id

  availability_zone = "ap-northeast-1a"

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
  allocation_id = aws_eip.nat_gw.id

  subnet_id = aws_subnet.public.id

  tags = {
    Name = "Nat Gateway for GitLab"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Public Subnetに対するルートテーブル
resource "aws_route_table" "public" {
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
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public.id
}

# Private Subnetに対するルートテーブル
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  # サブネット内で閉じる通信以外は、全て NAT ゲートウェイへ向ける
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name = "Route Table for Private Subnet"
  }
}

resource "aws_route_table_association" "private" {
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private.id
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