# Configure the MSK Kafka cluster
resource "aws_msk_cluster" "this" {
  cluster_name = "my-kafka-cluster"
  kafka_version = "2.6.2"
  num_brokers = 3

  # Use a multi-AZ deployment
  broker_node_group_info {
    instance_type = "kafka.m5.large"
    client_subnets = [aws_subnet.private.id, aws_subnet.public.id]
  }
}
