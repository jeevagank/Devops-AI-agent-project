resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.env}-telstra-redis"
  description          = "Redis cluster for ${var.env}"

  node_type            = var.node_type
  num_cache_clusters   = var.num_cache_clusters
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = var.security_group_ids

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  automatic_failover_enabled = var.num_cache_clusters > 1 ? true : false

  tags = {
    Environment = var.env
    Project     = "telstra"
    ManagedBy   = "terraform"
  }
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.env}-telstra-redis-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Environment = var.env
    Project     = "telstra"
    ManagedBy   = "terraform"
  }
}
