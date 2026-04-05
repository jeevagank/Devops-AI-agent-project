# Configure the Aurora PostgreSQL database
resource "aws_rds_cluster" "this" {
  cluster_identifier = "my-db-cluster"
  database_name       = "mydb"
  master_username    = "myuser"
  master_password    = "mypassword"
  port               = 5432

  # Use a multi-AZ deployment
  multi_az = true
}
