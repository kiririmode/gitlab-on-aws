resource "aws_alb" "this" {
  name               = "gitlab-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.this.id]
  subnets            = [for az, subnet in aws_subnet.public: subnet.id]

  drop_invalid_header_fields = true

  # TODO:
  # access_logs {
  #   bucket = ""
  # }

  tags = {
    Name = "Load Balancer for GitLab"
  }
}

resource "aws_alb_target_group" "this" {
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.this.id

  health_check {
    enabled  = true
    path     = "/-/health"
    port     = 80
    protocol = "HTTP"
  }
}

resource "aws_alb_target_group_attachment" "this" {
  for_each = local.gitlab_az

  target_group_arn = aws_alb_target_group.this.id
  target_id        = aws_instance.gitlab[each.key].id

  # TODO: GitLab 側が 80 番で待ち受ける必要有り
  port = 80
}

resource "aws_alb_listener" "this" {
  load_balancer_arn = aws_alb.this.arn

  # TODO: HTTPS へ変更する
  port     = 80
  protocol = "HTTP"
  # ssl_policy = ""

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.this.arn
  }

  tags = {
    Name = "ALB Listener for GitLab"
  }
}

# TODO: /etc/gitlab/gitlab.rb の external_url を書き換える必要がある
# 参考:
# - https://www.cresco.co.jp/blog/entry/17576/
# - 