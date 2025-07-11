variable "instance_type" {
  description = "EC2 instance type"
}
variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}
variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}
variable "key_name" {
  description = "SSH key pair name"
}
variable "target_group_arn" {
  description = "ALB target group ARN"
}

resource "aws_launch_template" "web" {
  name_prefix   = "web-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name
  user_data     = base64encode(<<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo amazon-linux-extras install nginx1 -y
    sudo systemctl start nginx
    sudo systemctl enable nginx
    sudo yum install -y gcc-c++ make
    curl -sL https://rpm.nodesource.com/setup_16.x | sudo bash -
    sudo yum install -y nodejs
    mkdir -p /home/ec2-user/app
    cat << 'NODEAPP' > /home/ec2-user/app/server.js
    const http = require('http');
    const port = 3000;
    const server = http.createServer((req, res) => {
      res.statusCode = 200;
      res.setHeader('Content-Type', 'text/plain');
      res.end('Hello from Node.js on Terraform!\n');
    });
    server.listen(port, () => {
      console.log('Server running at http://localhost:' + port + '/'); // Fixed syntax
    });
    NODEAPP
    cd /home/ec2-user/app
    npm init -y
    npm install
    node server.js &
    EOF
  )
  vpc_security_group_ids = var.security_group_ids
}

resource "aws_autoscaling_group" "web" {
  desired_capacity     = 2
  max_size             = 4
  min_size             = 1
  vpc_zone_identifier  = var.subnet_ids
  target_group_arns    = [var.target_group_arn]
  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "cpu-scaling"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 40.0
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