resource "aws_rds_cluster" "this" {
  cluster_identifier      = "${var.env}-jeevagan-aurora"
  engine                  = "aurora-postgresql"
  engine_version          = var.engine_version
  database_name           = var.database_name
  master_username         = var.master_username
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids

  backup_retention_period = var.backup_retention_period
  preferred_backup_window = "02:00-03:00"
  deletion_protection     = var.env == "prod" ? true : false

  storage_encrypted = true

  tags = {
    Environment = var.env
    Project     = "jeevagan"
    ManagedBy   = "terraform"
  }
}

resource "aws_rds_cluster_instance" "this" {
  count              = var.instance_count
  identifier         = "${var.env}-jeevagan-aurora-${count.index}"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  tags = {
    Environment = var.env
    Project     = "jeevagan"
    ManagedBy   = "terraform"
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.env}-jeevagan-aurora-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Environment = var.env
    Project     = "jeevagan"
    ManagedBy   = "terraform"
  }
}
