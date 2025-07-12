variable "vpc_cidr" {
  description = "CIDR block for the VPC"
}
variable "subnet_cidrs" {
  description = "List of subnet CIDR blocks"
  type        = list(string)
}
variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "MainVPC"
  }
}

resource "aws_subnet" "subnets" {
  count             = length(var.subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  map_public_ip_on_launch = true # Ensure public IPs for all instances
  tags = {
    Name = "Subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "MainIGW"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "MainRouteTable"
  }
}

resource "aws_route_table_association" "subnets" {
  count          = length(var.subnet_cidrs)
  subnet_id      = aws_subnet.subnets[count.index].id
  route_table_id = aws_route_table.main.id
}

output "vpc_id" {
  value = aws_vpc.main.id
}
output "subnet_ids" {
  value = aws_subnet.subnets[*].id
}