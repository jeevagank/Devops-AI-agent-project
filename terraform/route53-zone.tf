# Create a Route53 zone
resource "aws_route53_zone" "this" {
  name = "my-domain.com"
}
