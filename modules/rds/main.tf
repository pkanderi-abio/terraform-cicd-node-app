variable "vpc_id" {
  description = "VPC ID"
}
variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}
variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}
variable "db_name" {
  description = "Database name"
}
variable "db_username" {
  description = "Database username"
}
variable "db_password" {
  description = "Database password"
  sensitive   = true
}

resource "aws_db_subnet_group" "main" {
  name       = "main-subnet-group"
  subnet_ids = var.subnet_ids
  tags = {
    Name = "MainDBSubnetGroup"
  }
}

resource "aws_db_instance" "main" {
  identifier           = "main-db"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  db_name             = var.db_name
  username            = var.db_username
  password            = var.db_password
  vpc_security_group_ids = var.security_group_ids
  db_subnet_group_name = aws_db_subnet_group.main.name
  skip_final_snapshot = true
  tags = {
    Name = "MainDB"
  }
}

output "db_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "db_instance_id" { 
  value = aws_db_instance.main.id 
}