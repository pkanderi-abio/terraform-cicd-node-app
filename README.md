# terraform-cicd-node-app
CI/CD Pipeline with GitHub Actions
[![Terraform CI/CD](https://github.com/pkanderi-abio/terraform-cicd-node-app/actions/workflows/terraform.yml/badge.svg)](https://github.com/pkanderi-abio/terraform-cicd-node-app/actions/workflows/terraform.yml)


**# Project Overview**

## CI/CD Pipeline with GitHub Actions:
Automate terraform init, plan, and apply on code changes.
Store Terraform state in your existing S3 bucket (my-terraform-state-XXXXXXX) with DynamoDB locking.
Trigger on push to the main branch.

## Node.js Web Application:
Deploy a simple Node.js app (e.g., a “Hello World” HTTP server) to the EC2 instances.
Update user_data in the aws_launch_template to install Node.js, clone the app, and start it alongside Nginx.


## Step 1: Set Up GitHub Repository Variables and Secrets
Follow these steps exactly to add the variables and secrets. Variables are for non-sensitive data (visible in logs), secrets for sensitive (masked).

## Go to Repository Settings:
Open your GitHub repo > Click "Settings" (gear icon) > Scroll to "Secrets and variables" > Click "Actions".
Add Repository Variables (for non-sensitive):
Click "Variables" tab > "New repository variable".
## Add these for Prod:
`Name: PROD_MY_IP, Value: 47.234.254.82/32
Name: PROD_DB_NAME, Value: prod_db
Name: PROD_DB_USERNAME, Value: prod_user
Name: PROD_VPC_CIDR, Value: 10.0.0.0/16
Name: PROD_SUBNET_CIDRS, Value: ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24"]
Name: PROD_AVAILABILITY_ZONES, Value: ["us-west-2a", "us-west-2b", "us-west-2c", "us-west-2d"]
Name: PROD_INSTANCE_TYPE, Value: t2.micro`
## Add these for Dev (use your Dev values):
`Name: DEV_MY_IP, Value: 47.234.254.82/32 (or your Dev IP)
Name: DEV_DB_NAME, Value: dev_db
Name: DEV_DB_USERNAME, Value: dev_user
Name: DEV_VPC_CIDR, Value: 10.1.0.0/16
Name: DEV_SUBNET_CIDRS, Value: ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24", "10.1.4.0/24"]
Name: DEV_AVAILABILITY_ZONES, Value: ["us-west-2a", "us-west-2b", "us-west-2c", "us-west-2d"]
Name: DEV_INSTANCE_TYPE, Value: t2.micro`
## Add Repository Secrets (for sensitive):
### Click "Secrets" tab > "New repository secret".
`Name: PROD_DB_PASSWORD, Value: my_prod_password
Name: DEV_DB_PASSWORD, Value: my_dev_password
Name: SSH_PUBLIC_KEY, Value: (paste the full content of my-key-pair.pub, e.g., ssh-rsa AAAAB3N...)
Name: AWS_ACCESS_KEY_ID, Value: (your AWS key ID)
Name: AWS_SECRET_ACCESS_KEY, Value: (your AWS secret key)`


## How to Run Destroy in Actions
Go to your repo > "Actions" tab > Select "Terraform CI/CD" > Click "Run workflow" > Choose the branch and run.
The deploy job skips (since it's workflow_dispatch), and destroy runs.