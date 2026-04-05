# Configure the ALB with WAF
resource "aws_alb" "this" {
  name            = "my-alb"
  subnets         = [aws_subnet.public.id]
  security_groups = [aws_security_group.alb.id]
}

resource "aws_waf" "this" {
  name = "my-waf"
}
