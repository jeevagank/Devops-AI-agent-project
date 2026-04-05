# Create a secret for each microservice
resource "aws_secretsmanager_secret" "my-microservice" {
  name = "my-microservice-secret"
}
