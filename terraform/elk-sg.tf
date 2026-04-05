# Create a security group for ELK
resource "aws_security_group" "elk" {
  name        = "my-elk-sg"
  description = "ELK security group"
  vpc_id      = aws_vpc.this.id

  # Allow inbound traffic on port 22
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
