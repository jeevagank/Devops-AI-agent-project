# Configure the ArgoCD GitOps
resource "aws_instance" "argocd" {
  ami           = "ami-0c94855ba95c71c99"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.argocd.id]
}
