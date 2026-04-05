# Create an ElastiCache subnet group
resource "aws_elasticache_subnet_group" "this" {
  name       = "my-redis-subnet-group"
  subnet_ids = [aws_subnet.private.id, aws_subnet.public.id]
}
