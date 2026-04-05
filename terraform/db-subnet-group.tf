# Create a DB subnet group
resource "aws_db_subnet_group" "this" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.private.id, aws_subnet.public.id]
}
