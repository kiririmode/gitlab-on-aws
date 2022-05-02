# GitLabの最新版AMIの取得
# see: https://ap-northeast-1.console.aws.amazon.com/ec2/v2/home?region=ap-northeast-1#Images:visibility=public-images;ownerAlias=782774275127;search=GitLab%20CE;sort=desc:name
data "aws_ami" "gitlab" {
  most_recent = true
  owners      = ["782774275127"]
  name_regex  = "GitLab CE*"
}

# SSM エージェントを含む GitLabCE 用 EC2
resource "aws_instance" "gitlab" {
  ami = data.aws_ami.gitlab.id

  # ソフトウェアの要件は https://docs.gitlab.com/ee/install/requirements.html を参照
  # メモリ 4GB と価格から判断
  # GitLab の AMI のアーキテクチャは X86_64 であるため、ARM ベースの T4g は利用できない
  instance_type        = "t3.medium"
  iam_instance_profile = aws_iam_instance_profile.systems_manager.name

  # SSMエージェントを導入
  user_data = file("./install-ssm.sh")
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

