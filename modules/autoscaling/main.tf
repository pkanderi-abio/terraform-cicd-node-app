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
    set -x # Enable debugging
    # Try yum update with fallback to skip if unavailable
    sudo yum update -y || sudo yum update -y --disablerepo=* --enablerepo=amzn2-core || echo "yum update skipped due to repository issue"
    sudo amazon-linux-extras install nginx1 -y || { echo "nginx install failed"; exit 1; }
    sudo systemctl start nginx || { echo "nginx start failed"; exit 1; }
    sudo systemctl enable nginx || { echo "nginx enable failed"; exit 1; }
    sudo yum install -y gcc-c++ make || { echo "dev tools install failed"; exit 1; }
    curl -sL https://rpm.nodesource.com/setup_16.x | sudo bash - || { echo "NodeSource setup failed"; exit 1; }
    sudo yum install -y nodejs || { echo "nodejs install failed"; exit 1; }
    mkdir -p /home/ec2-user/app || { echo "app dir creation failed"; exit 1; }
    cat << 'NODEAPP' > /home/ec2-user/app/server.js
    const http = require('http');
    const port = 3000;
    const server = http.createServer((req, res) => {
      res.statusCode = 200;
      res.setHeader('Content-Type', 'text/plain');
      res.end('Hello from Node.js on Terraform!\n');
    });
    server.listen(port, '0.0.0.0', () => {
      console.log('Server running at http://0.0.0.0:' + port + '/');
    });
    NODEAPP
    cd /home/ec2-user/app || { echo "app dir cd failed"; exit 1; }
    npm init -y || { echo "npm init failed"; exit 1; }
    npm install || { echo "npm install failed"; exit 1; }
    # Create systemd service
    cat << 'SYSTEMD' > /etc/systemd/system/node-app.service
    [Unit]
    Description=Node.js App
    After=network.target

    [Service]
    Type=simple
    User=ec2-user
    WorkingDirectory=/home/ec2-user/app
    ExecStart=/usr/bin/node /home/ec2-user/app/server.js
    Restart=always
    RestartSec=10

    [Install]
    WantedBy=multi-user.target
    SYSTEMD
    sudo chmod 644 /etc/systemd/system/node-app.service || { echo "chmod failed"; exit 1; }
    sudo systemctl daemon-reload || { echo "daemon-reload failed"; exit 1; }
    sudo systemctl enable node-app.service || { echo "enable failed"; exit 1; }
    sudo systemctl start node-app.service || { echo "start failed"; exit 1; }
    echo "User data script completed successfully" > /home/ec2-user/userdata-success.log
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