# Define the AWS Provider
provider "aws" {
  region = "us-west-2"
}

terraform {
  backend "s3" {
    bucket       = "my-terraform-state-mg6r2n9o"
    key          = "terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
  }
}

# Define Variables
variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "my_ip" {
  description = "Your IP address for SSH access"
  type        = string
}

variable "db_name" {
  description = "Database name"
  default     = "mydb"
}

variable "db_username" {
  description = "Database username"
  default     = "admin"
}

variable "db_password" {
  description = "Database password"
  sensitive   = true
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
    Environment = "Dev"
  }
}

# Create an SSH Key Pair
resource "aws_key_pair" "my_key" {
  key_name   = "my-key-pair"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC91ceSwKNy3fyGycQ8R4aI1InGsHbI0yo/sgdXiMdzX5/F3/h4vdHAjZZ3+f+zyb7zuC/YvBh+0cYqN/bebsJFobtHibcVS8xQYCU9czH3U4aNy3A4akO38dtgwI6TCgkcO/Xd62gwh1mq8wemlItROYjL11xrC9y7VSlSslv/q1d71ViIlrNjW5fK/uVDTPoeH2nrs3ikNGYF7RxyS3iHcrSZKryTyYJZUms3ZN56ZFMC/XnFC7vV7HyPKGsf7/2jcRUK951em1JwLhAMySMA0VXWpUtPVoPF5IPJLV6/4xBDc6T54b3iCXUHLVoHZBSmSfsF79wapmn//kY49uT9 pkanderi@MacBookPro-2115.lan"
}

# VPC Module
module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr           = var.vpc_cidr
  subnet_cidrs       = ["10.0.1.0/24", "10.0.2.0/24"]
  availability_zones = ["us-west-2a", "us-west-2b"]
}

# Create Security Group
resource "aws_security_group" "allow_ssh_http_mysql" {
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000 # Allow Node.js app port
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "AllowSSH_HTTP_MySQL_Node"
  }
}

# Bastion Host
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = module.vpc.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.allow_ssh_http_mysql.id]
  key_name               = aws_key_pair.my_key.key_name
  associate_public_ip_address = true
  tags = {
    Name = "BastionHost"
  }
}

# Auto-Scaling Module
module "autoscaling" {
  source              = "./modules/autoscaling"
  instance_type       = var.instance_type
  subnet_ids          = module.vpc.subnet_ids
  security_group_ids  = [aws_security_group.allow_ssh_http_mysql.id]
  key_name            = aws_key_pair.my_key.key_name
  target_group_arn    = aws_lb_target_group.web.arn
}

# Load Balancer
resource "aws_lb" "web" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_ssh_http_mysql.id]
  subnets            = module.vpc.subnet_ids
  tags = {
    Name = "WebALB"
  }
}

resource "aws_lb_target_group" "web" {
  name     = "web-tg"
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
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 3000 # Updated to Node.js port
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
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