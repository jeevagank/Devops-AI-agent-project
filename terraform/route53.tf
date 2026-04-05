# Configure the Route53 zone
resource "aws_route53_zone" "this" {
  name = "example.com"
}
