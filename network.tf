#######################################
# Shared VPC and environment subnets
#######################################

resource "aws_vpc" "service" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name      = "devcloud-${var.request_id}"
    ManagedBy = "Terraform"
  }
}

resource "aws_internet_gateway" "service" {
  vpc_id = aws_vpc.service.id

  tags = {
    Name      = "devcloud-${var.request_id}"
    ManagedBy = "Terraform"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.service.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.service.id
  }

  tags = {
    Name      = "devcloud-public-${var.request_id}"
    ManagedBy = "Terraform"
  }
}

resource "aws_subnet" "environment" {
  for_each = var.environment_instances

  vpc_id                  = aws_vpc.service.id
  cidr_block              = each.value.subnet_cidr
  map_public_ip_on_launch = true

  tags = {
    Name        = each.key
    Environment = each.key
    ManagedBy   = "Terraform"
  }
}

resource "aws_route_table_association" "environment" {
  for_each = aws_subnet.environment

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
