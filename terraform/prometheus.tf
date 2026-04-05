# Create a Terraform module for the Prometheus and Grafana monitoring
module "prometheus" {
  source = file("./modules/prometheus")
}
