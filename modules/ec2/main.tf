variable "instance_type" {
  description = "EC2 instance type"
}
variable "subnet_ids" {
  description = "List of subnet IDs for EC2 instances"
  type        = list(string)
}
variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}
variable "key_name" {
  description = "SSH key pair name"
}
variable "user_data" {
  description = "User data script"
  default     = ""
}
variable "instance_names" {
  description = "List of instance names"
  type        = list(string)
  default     = ["Instance-1", "Instance-2"]
}

resource "aws_instance" "instance" {
  for_each                   = toset(var.instance_names)
  ami                        = data.aws_ami.amazon_linux.id
  instance_type              = var.instance_type
  subnet_id                  = var.subnet_ids[index(var.instance_names, each.value) % length(var.subnet_ids)]
  vpc_security_group_ids     = var.security_group_ids
  associate_public_ip_address = true
  key_name                   = var.key_name
  user_data                  = replace(var.user_data, "instance_name", each.value)
  tags = {
    Name = each.value
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

output "instance_ids" {
  value = [for instance in aws_instance.instance : instance.id]
}
output "public_ips" {
  value = [for instance in aws_instance.instance : instance.public_ip]
}
output "instance_names" {
  value = var.instance_names
}