resource "aws_msk_cluster" "this" {
  cluster_name           = "${var.env}-telstra-kafka"
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.number_of_broker_nodes

  broker_node_group_info {
    instance_type  = var.broker_instance_type
    client_subnets = var.subnet_ids
    storage_info {
      ebs_storage_info {
        volume_size = var.broker_volume_size
      }
    }
    security_groups = var.security_group_ids
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  tags = {
    Environment = var.env
    Project     = "telstra"
    ManagedBy   = "terraform"
  }
}
