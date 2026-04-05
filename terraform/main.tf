# Configure the AWS Provider
provider "aws" {
  region = "ap-southeast-2"
}

# Create a VPC
resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
}

# Create a private subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-2a"
}

# Create a public subnet
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-2a"
}

# Create a NAT gateway
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.this.id
  subnet_id     = aws_subnet.public.id
}

# Create an EIP for the NAT gateway
resource "aws_eip" "this" {
  vpc = true
}
