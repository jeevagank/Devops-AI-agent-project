# Create a security group for the ALB
resource "aws_security_group" "alb" {
  name        = "my-alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.this.id

  # Allow inbound traffic on port 80
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
