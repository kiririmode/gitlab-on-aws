# GitLabの最新版AMIの取得
# see: https://ap-northeast-1.console.aws.amazon.com/ec2/v2/home?region=ap-northeast-1#Images:visibility=public-images;ownerAlias=782774275127;search=GitLab%20CE;sort=desc:name
data "aws_ami" "gitlab" {
  most_recent = true
  owners      = ["782774275127"]
  name_regex  = "GitLab CE*"
}

# SSM エージェントを含む GitLabCE 用 EC2
resource "aws_instance" "gitlab" {

  # TODO: 固定化できるようにする
  ami = data.aws_ami.gitlab.id

  # ソフトウェアの要件は https://docs.gitlab.com/ee/install/requirements.html を参照
  # メモリ 4GB と価格から判断
  # GitLab の AMI のアーキテクチャは X86_64 であるため、ARM ベースの T4g は利用できない
  instance_type        = "t3.medium"
  iam_instance_profile = aws_iam_instance_profile.systems_manager.name

  # プライベートサブネットに配置する
  availability_zone           = var.availability_zone
  subnet_id                   = aws_subnet.private.id
  associate_public_ip_address = false

  vpc_security_group_ids = [
    aws_security_group.this.id
  ]

  # SSMエージェントを導入
  user_data = file("./install-ssm.sh")

  tags = {
    Name = "GitLab CE"
  }

  depends_on = [
    # NAT Gatewayが先に作成されないと、user_data 実行時に必要なインターネットリーチアビリティが確保されない
    aws_nat_gateway.this
  ]
}

# GitLab用インスタンスに与えるInstance Profile。
# SSMでアクセス可能にする
resource "aws_iam_instance_profile" "systems_manager" {
  name = "GitLabInstanceProfile"
  role = aws_iam_role.gitlab.name
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "gitlab" {
  name               = "GitLabServerRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy" "systems_manager" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "default" {
  role       = aws_iam_role.gitlab.name
  policy_arn = data.aws_iam_policy.systems_manager.arn
}

# 接続性の確認
resource "aws_ec2_network_insights_path" "gitlab" {
  source           = aws_instance.gitlab.id
  destination      = aws_internet_gateway.igw.id
  destination_port = 80
  protocol         = "tcp"

  tags = {
    Name = "GitLab to Internet Gateway"
  }
}