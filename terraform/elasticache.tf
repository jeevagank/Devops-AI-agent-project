# Configure the ElastiCache Redis cluster
resource "aws_elasticache_cluster" "this" {
  cluster_id = "my-redis-cluster"
  engine     = "redis"
  node_type  = "cache.r5.large"
  port       = 6379

  # Use a multi-AZ deployment
  multi_az_enabled = true
}
