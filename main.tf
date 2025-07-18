# Define the AWS Provider
provider "aws" {
  region = "us-west-2"
}

terraform {
  backend "s3" {
    bucket = "my-terraform-state-mg6r2n9o"
    region = "us-west-2"
  }
}

# Define Variables
variable "public_key_source" {
  description = "Source of the public key (local or env)"
  type        = string
  default     = "local"
}

variable "public_key_path" {
  description = "Path to the local public key file"
  type        = string
  default     = "my-key-pair.pub"
}

variable "environment" {
  description = "Environment (e.g., default for Prod)"
  type        = string
  default     = "default"
}

variable "my_ip" {
  description = "Your public IP for SSH access"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "prod_db"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "prod_user"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidrs" {
  description = "List of subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24"]
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c", "us-west-2d"]
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

# Add this variable to accept the SSH public key from the environment
variable "ssh_public_key" {
  description = "SSH public key when source is env"
  type        = string
  default     = ""
}

# Enhanced local value with better error handling and debugging
locals {
  raw_public_key = var.public_key_source == "local" ? file(var.public_key_path) : (var.public_key_source == "env" ? var.ssh_public_key : "")
  # Clean the key: trim whitespace, remove any extra newlines
  cleaned_key = replace(trimspace(local.raw_public_key), "\n", "")
  # Validate key format
  is_valid_key = can(regex("^(ssh-rsa|ssh-dss|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) [A-Za-z0-9+/]+=*", local.cleaned_key))
}

# Debug output to help troubleshoot
output "debug_key_info" {
  value = {
    key_source     = var.public_key_source
    key_path       = var.public_key_path
    key_length     = length(local.cleaned_key)
    key_starts_with = substr(local.cleaned_key, 0, min(20, length(local.cleaned_key)))
    is_valid       = local.is_valid_key
  }
  sensitive = false
}

# Generate a random string for unique S3 bucket names
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Application S3 Bucket
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-unique-bucket-name-${random_string.bucket_suffix.result}"
  tags = {
    Name        = "MyBucket"
    Environment = "default"
  }
}

# VPC Module (moved up to be created first)
module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr           = var.vpc_cidr
  subnet_cidrs       = var.subnet_cidrs
  availability_zones = var.availability_zones
}

# Key pair resource with validation
resource "aws_key_pair" "my_key" {
  key_name   = "my-key-pair-${random_string.bucket_suffix.result}"  # Make unique
  public_key = local.cleaned_key
  
  # Add validation
  lifecycle {
    precondition {
      condition     = local.is_valid_key
      error_message = "The SSH public key must be in valid OpenSSH format (ssh-rsa, ssh-ed25519, etc.)"
    }
    create_before_destroy = true
  }
  
  tags = {
    Name        = "MyKeyPair"
    Environment = var.environment
  }
}

# Create Security Group
resource "aws_security_group" "allow_ssh_http_mysql" {
  name_prefix = "allow-ssh-http-mysql-"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip] # External access
    description = "SSH access from your IP"
  }
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # Internal access
    description = "SSH access from VPC"
  }
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }
  
  ingress {
    from_port   = 3000 # Allow Node.js app port
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Node.js application port"
  }
  
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "MySQL access from VPC"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }
  
  tags = {
    Name = "AllowSSH_HTTP_MySQL_Node"
    Environment = var.environment
  }
}

# Bastion Host
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = module.vpc.subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.allow_ssh_http_mysql.id]
  key_name                    = aws_key_pair.my_key.key_name
  associate_public_ip_address = true
  
  tags = {
    Name        = "Bastion-${var.environment}"
    Environment = var.environment
  }
  
  # Ensure key pair is created first
  depends_on = [aws_key_pair.my_key]
}

# Load Balancer Target Group (moved up to be created before autoscaling)
resource "aws_lb_target_group" "web" {
  name     = "web-tg-${var.environment}"
  port     = 3000 # Updated to Node.js port
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  
  tags = {
    Name        = "WebTargetGroup"
    Environment = var.environment
  }
}

# Load Balancer
resource "aws_lb" "web" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_ssh_http_mysql.id]
  subnets            = module.vpc.subnet_ids
  
  tags = {
    Name        = "WebALB"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = "3000" # Updated to Node.js port
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Auto-Scaling Module (with proper dependencies)
module "autoscaling" {
  source              = "./modules/autoscaling"
  instance_type       = var.instance_type
  subnet_ids          = module.vpc.subnet_ids
  security_group_ids  = [aws_security_group.allow_ssh_http_mysql.id]
  key_name            = aws_key_pair.my_key.key_name
  target_group_arn    = aws_lb_target_group.web.arn
  environment         = var.environment
  
  # Explicit dependencies to ensure proper creation order
  depends_on = [
    aws_key_pair.my_key,
    aws_lb_target_group.web
  ]
}

# RDS Module
module "rds" {
  source              = "./modules/rds"
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.subnet_ids
  security_group_ids  = [aws_security_group.allow_ssh_http_mysql.id]
  db_name             = var.db_name
  db_username         = var.db_username
  db_password         = var.db_password
}

# Data Source
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Outputs
output "s3_bucket_name" {
  value = aws_s3_bucket.my_bucket.bucket
}

output "alb_dns_name" {
  value = aws_lb.web.dns_name
}

output "db_endpoint" {
  value = module.rds.db_endpoint
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "key_pair_name" {
  value = aws_key_pair.my_key.key_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}